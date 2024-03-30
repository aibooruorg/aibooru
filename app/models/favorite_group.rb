# frozen_string_literal: true

class FavoriteGroup < ApplicationRecord
  belongs_to :creator, class_name: "User"

  before_validation :normalize_name

  validates :name, visible_string: true
  validates :name, uniqueness: { case_sensitive: false, scope: :creator_id }
  validate :validate_name, if: :name_changed?
  validate :creator_can_create_favorite_groups, :on => :create
  validate :validate_number_of_posts
  validate :validate_posts

  array_attribute :post_ids, parse: /\d+/, cast: :to_i

  module SearchMethods
    def for_post(post_id)
      where_array_includes_any(:post_ids, [post_id])
    end

    def name_contains(name)
      name = normalize_name(name)
      name = "*#{name.escape_wildcards}*" unless name.include?("*")
      where_ilike(:name, name)
    end

    def search(params, current_user)
      q = search_attributes(params, [:id, :created_at, :updated_at, :name, :post_ids, :creator], current_user: current_user)

      if params[:name_contains].present?
        q = q.name_contains(params[:name_contains])
      end

      case params[:order]
      when "name"
        q = q.order(name: :asc, id: :desc)
      when "created_at"
        q = q.order(id: :desc)
      when "updated_at"
        q = q.order(updated_at: :desc)
      when "post_count"
        q = q.order(Arel.sql("cardinality(post_ids) desc")).order(id: :desc)
      else
        q = q.apply_default_order(params)
      end

      q
    end
  end

  extend SearchMethods

  def creator_can_create_favorite_groups
    if creator.favorite_groups.count >= creator.favorite_group_limit
      errors.add(:base, "You can only keep up to #{creator.favorite_group_limit} favorite groups.")
    end
  end

  def validate_number_of_posts
    if post_count > 10_000
      errors.add(:base, "Favorite groups can have up to 10,000 posts each")
    end
  end

  def validate_posts
    added_post_ids = post_ids - post_ids_was
    existing_post_ids = Post.where(id: added_post_ids).pluck(:id)
    nonexisting_post_ids = added_post_ids - existing_post_ids

    if nonexisting_post_ids.present?
      errors.add(:base, "Cannot add invalid post(s) to favgroup: #{nonexisting_post_ids.to_sentence}")
    end

    duplicate_post_ids = post_ids.group_by(&:itself).transform_values(&:size).select { |_id, count| count > 1 }.keys
    if duplicate_post_ids.present?
      errors.add(:base, "Favgroup already contains post #{duplicate_post_ids.to_sentence}")
    end
  end

  def validate_name
    case name
    when /\A(any|none)\z/i
      errors.add(:name, "cannot be '#{name}'")
    when /,/
      errors.add(:name, "cannot contain commas")
    when /\*/
      errors.add(:name, "cannot contain asterisks")
    when /\A_/
      errors.add(:name, "cannot begin with an underscore")
    when /_\z/
      errors.add(:name, "cannot end with an underscore")
    when /__/
      errors.add(:name, "cannot contain consecutive underscores")
    when /[^[:graph:]]/
      errors.add(:name, "cannot contain non-printable characters")
    when ""
      errors.add(:name, "cannot be blank")
    when /\A[0-9]+\z/
      errors.add(:name, "cannot contain only digits")
    end
  end

  def self.normalize_name(name)
    name.gsub(/[_[:space:]]+/, "_").gsub(/\A_|_\z/, "")
  end

  def normalize_name
    self.name = FavoriteGroup.normalize_name(name)
  end

  def self.name_or_id_matches(name, user)
    if name =~ /\A\d+\z/
      where(id: name)
    else
      where(creator: user).where_iequals(:name, normalize_name(name))
    end
  end

  def self.find_by_name_or_id(name, user)
    name_or_id_matches(name, user).first
  end

  def self.find_by_name_or_id!(name, user)
    find_by_name_or_id(name, user) or raise ActiveRecord::RecordNotFound
  end

  def pretty_name
    name&.tr("_", " ")
  end

  def posts
    favgroup_posts = FavoriteGroup.where(id: id).joins("CROSS JOIN unnest(favorite_groups.post_ids) WITH ORDINALITY AS row(post_id, favgroup_index)").select(:post_id, :favgroup_index)
    Post.joins("JOIN (#{favgroup_posts.to_sql}) favgroup_posts ON favgroup_posts.post_id = posts.id").order("favgroup_posts.favgroup_index ASC")
  end

  def add(post)
    with_lock do
      update(post_ids: post_ids + [post.id])
    end
  end

  def remove(post)
    with_lock do
      update(post_ids: post_ids - [post.id])
    end
  end

  def post_count
    post_ids.size
  end

  def first_post?(post_id)
    post_id == post_ids.first
  end

  def last_post?(post_id)
    post_id == post_ids.last
  end

  def previous_post_id(post_id)
    return nil if first_post?(post_id) || !contains?(post_id)

    n = post_ids.index(post_id) - 1
    post_ids[n]
  end

  def next_post_id(post_id)
    return nil if last_post?(post_id) || !contains?(post_id)

    n = post_ids.index(post_id) + 1
    post_ids[n]
  end

  def last_page
    (post_count / CurrentUser.user.per_page.to_f).ceil
  end

  def contains?(post_id)
    post_ids.include?(post_id)
  end

  def self.available_includes
    [:creator]
  end
end

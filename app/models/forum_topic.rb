# frozen_string_literal: true

class ForumTopic < ApplicationRecord
  CATEGORIES = {
    0 => "General",
    1 => "Tags",
    2 => "Bugs & Features",
  }

  MIN_LEVELS = {
    None: 0,
    Member: User::Levels::MEMBER,
    Gold: User::Levels::GOLD,
    Builder: User::Levels::BUILDER,
    Moderator: User::Levels::MODERATOR,
    Admin: User::Levels::ADMIN,
  }

  belongs_to :creator, class_name: "User"
  belongs_to_updater
  has_many :forum_posts, foreign_key: "topic_id", dependent: :destroy, inverse_of: :topic
  has_many :forum_topic_visits
  has_one :forum_topic_visit_by_current_user, -> { where(user_id: CurrentUser.id) }, class_name: "ForumTopicVisit"
  has_one :original_post, -> { order(id: :asc) }, class_name: "ForumPost", foreign_key: "topic_id", inverse_of: :topic
  has_many :bulk_update_requests
  has_many :tag_aliases
  has_many :tag_implications
  has_many :mod_actions, as: :subject, dependent: :destroy

  validates :title, visible_string: true, length: { maximum: 200 }, if: :title_changed?
  validates :category_id, inclusion: { in: CATEGORIES.keys }
  validates :min_level, inclusion: { in: MIN_LEVELS.values }

  accepts_nested_attributes_for :original_post

  after_update :update_posts_on_deletion_or_undeletion
  after_update :update_original_post
  after_save(:if => ->(rec) {rec.is_locked? && rec.saved_change_to_is_locked?}) do |rec|
    ModAction.log("locked forum topic ##{id} (title: #{title})", :forum_topic_lock, subject: self, user: CurrentUser.user)
  end

  deletable

  scope :public_only, -> { where(min_level: MIN_LEVELS[:None]) }
  scope :private_only, -> { where.not(min_level: MIN_LEVELS[:None]) }
  scope :pending, -> { where(id: BulkUpdateRequest.has_topic.pending.select(:forum_topic_id)) }
  scope :approved, -> { where(category_id: 1).where(id: BulkUpdateRequest.approved.has_topic.select(:forum_topic_id)).where.not(id: BulkUpdateRequest.has_topic.pending.or(BulkUpdateRequest.has_topic.rejected).select(:forum_topic_id)) }
  scope :rejected, -> { where(category_id: 1).where(id: BulkUpdateRequest.rejected.has_topic.select(:forum_topic_id)).where.not(id: BulkUpdateRequest.has_topic.pending.or(BulkUpdateRequest.has_topic.approved).select(:forum_topic_id)) }

  module CategoryMethods
    extend ActiveSupport::Concern

    module ClassMethods
      def categories
        CATEGORIES.values
      end

      def reverse_category_mapping
        @reverse_category_mapping ||= CATEGORIES.invert
      end
    end

    def category_name
      CATEGORIES[category_id]
    end
  end

  module SearchMethods
    def visible(user)
      where("min_level <= ?", user.level)
    end

    def read_by_user(user)
      last_forum_read_at = user.last_forum_read_at || "2000-01-01".to_time

      read_topics = user.visited_forum_topics.where("forum_topic_visits.last_read_at >= forum_topics.updated_at")
      old_topics = where("? >= forum_topics.updated_at", last_forum_read_at)

      where(id: read_topics).or(where(id: old_topics))
    end

    def unread_by_user(user)
      where.not(id: ForumTopic.read_by_user(user))
    end

    def sticky_first
      order(is_sticky: :desc, updated_at: :desc)
    end

    def default_order
      order(updated_at: :desc)
    end

    def search(params, current_user)
      q = search_attributes(params, [:id, :created_at, :updated_at, :is_sticky, :is_locked, :is_deleted, :category_id, :title, :response_count, :creator, :updater, :forum_posts, :bulk_update_requests, :tag_aliases, :tag_implications], current_user: current_user)

      if params[:is_private].to_s.truthy?
        q = q.private_only
      elsif params[:is_private].to_s.falsy?
        q = q.public_only
      end

      case params[:status]
      when "pending"
        q = q.pending
      when "approved"
        q = q.approved
      when "rejected"
        q = q.rejected
      end

      if params[:is_read].to_s.truthy?
        q = q.read_by_user(CurrentUser.user)
      elsif params[:is_read].to_s.falsy?
        q = q.unread_by_user(CurrentUser.user)
      end

      case params[:order]
      when "sticky"
        q = q.sticky_first
      when "id"
        q = q.order(id: :desc)
      else
        q = q.apply_default_order(params)
      end

      q
    end
  end

  module VisitMethods
    def mark_as_read!(user = CurrentUser.user)
      return if user.is_anonymous?

      visit = ForumTopicVisit.find_by(user_id: user.id, forum_topic_id: id)
      if visit
        visit.update!(last_read_at: updated_at)
      else
        ForumTopicVisit.create(:user_id => user.id, :forum_topic_id => id, :last_read_at => updated_at)
      end

      unread_topics = ForumTopic.visible(user).active.unread_by_user(user)

      if !unread_topics.exists?
        user.update!(last_forum_read_at: Time.zone.now)
        ForumTopicVisit.prune!(user)
      end
    end
  end

  extend SearchMethods
  include CategoryMethods
  include VisitMethods

  concerning :DiscordMethods do
    def discord_author
      Discordrb::Webhooks::EmbedAuthor.new(name: "@#{creator.name}", url: creator.discord_url)
    end

    def discord_title
      title
    end

    def discord_body
      DText.new(original_post.body, media_embeds: true).to_markdown.truncate(2000)
    end
  end

  # XXX forum_topic_visit_by_current_user is a hack to reduce queries on the forum index.
  def is_read?
    return true if CurrentUser.is_anonymous?
    return true if new_record?

    topic_last_read_at = forum_topic_visit_by_current_user&.last_read_at || "2000-01-01".to_time
    forum_last_read_at = CurrentUser.last_forum_read_at || "2000-01-01".to_time

    (topic_last_read_at >= updated_at) || (forum_last_read_at >= updated_at)
  end

  def is_private?
    min_level > MIN_LEVELS[:None]
  end

  def create_mod_action_for_delete
    ModAction.log("deleted forum topic ##{id} (title: #{title})", :forum_topic_delete, subject: self, user: CurrentUser.user)
  end

  def create_mod_action_for_undelete
    ModAction.log("undeleted forum topic ##{id} (title: #{title})", :forum_topic_undelete, subject: self, user: CurrentUser.user)
  end

  def page_for(post_id)
    (forum_posts.where("id < ?", post_id).count / CurrentUser.user.per_page.to_f).ceil
  end

  def last_page
    (response_count / CurrentUser.user.per_page.to_f).ceil
  end

  # Delete all posts when the topic is deleted. Undelete all posts when the topic is undeleted.
  def update_posts_on_deletion_or_undeletion
    if saved_change_to_is_deleted?
      forum_posts.update!(is_deleted: is_deleted) # XXX depends on current user
    end
  end

  def update_original_post
    original_post&.update_columns(:updater_id => updater.id, :updated_at => Time.now)
  end

  def pretty_title
    title.gsub(/\A\[APPROVED\]|\[REJECTED\]/, "")
  end

  def self.available_includes
    [:creator, :updater, :original_post]
  end
end

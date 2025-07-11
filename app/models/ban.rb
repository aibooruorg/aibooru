# frozen_string_literal: true

class Ban < ApplicationRecord
  attribute :duration, :interval
  attribute :delete_posts, :boolean
  attribute :post_deletion_reason, :string
  attribute :post_deletion_tags, :string
  attribute :post_deletion_tags_nuke, :boolean
  attribute :post_deletion_metadata_nuke, :boolean
  attribute :delete_forum_posts, :boolean
  attribute :delete_comments, :boolean
  attribute :delete_votes, :boolean

  dtext_attribute :reason, inline: true # defines :dtext_reason

  after_create :create_feedback
  after_create :create_dmail
  after_create :update_user_on_create
  after_create :create_ban_mod_action
  after_create :delete_user_data
  after_destroy :update_user_on_destroy
  after_destroy :create_unban_mod_action
  belongs_to :user
  belongs_to :banner, :class_name => "User"

  validates :duration, presence: true
  validates :duration, inclusion: { in: [1.day, 3.days, 1.week, 1.month, 3.months, 6.months, 1.year, 100.years], message: "%{value} is not a valid ban duration" }, if: :duration_changed?
  validates :reason, visible_string: true
  validate :user, :validate_user_is_bannable, on: :create
  validate :validate_deletions, on: :create

  scope :unexpired, -> { where("bans.created_at + bans.duration > ?", Time.zone.now) }
  scope :expired, -> { where("bans.created_at + bans.duration <= ?", Time.zone.now) }
  scope :active, -> { unexpired }

  def self.search(params, current_user)
    q = search_attributes(params, [:id, :created_at, :updated_at, :duration, :reason, :user, :banner], current_user: current_user)

    q = q.expired if params[:expired].to_s.truthy?
    q = q.unexpired if params[:expired].to_s.falsy?

    case params[:order]
    when "expires_at_desc"
      q = q.order(Arel.sql("bans.created_at + bans.duration DESC"))
    else
      q = q.apply_default_order(params)
    end

    q
  end

  def self.prune!
    expired.includes(:user).find_each do |ban|
      ban.user.unban! if ban.user.ban_expired?
    end
  end

  def validate_user_is_bannable
    errors.add(:user, "is already banned") if user&.is_banned?
  end

  def validate_deletions
    if delete_posts && !post_deletion_reason.present?
      errors.add(:post_deletion_reason, "is required")
    end

    if delete_votes && !Pundit.policy!(banner, PostVote.new).destroy?
      errors.add(:delete_votes, "is not allowed by #{banner.level_string}")
    end
  end

  def update_user_on_create
    user.update!(is_banned: true)
  end

  def update_user_on_destroy
    user.update!(is_banned: false)
  end

  def user_name
    user ? user.name : nil
  end

  def user_name=(username)
    self.user = User.find_by_name(username)
  end

  def expires_at
    created_at + duration
  end

  def humanized_duration
    if forever?
      "forever"
    elsif duration < 0
      # In production, the oldest bans have negative duration because in 2013 the database was migrated and the
      # created_at field was reset to 2013, which made their creation date come after their expiration date.
      "unknown"
    elsif duration < 1.month
      duration.in_days.round.days.inspect
    elsif duration < 1.year
      duration.in_months.round.months.inspect
    elsif duration < 100.years
      duration.in_years.round.years.inspect
    else
      duration.inspect
    end
  end

  def forever?
    duration.present? && duration >= 100.years
  end

  def expired?
    persisted? && expires_at < Time.zone.now
  end

  def create_feedback
    user.feedback.create!(creator: banner, category: "negative", body: "Banned #{humanized_duration}: #{reason}", disable_dmail_notification: true)
  end

  def create_dmail
    Dmail.create_automated(to: user, title: "You have been banned", body: "You have been banned #{forever? ? "forever" : "for #{humanized_duration}"}: #{reason}")
  end

  def create_ban_mod_action
    ModAction.log(%{banned <@#{user_name}> #{humanized_duration}: #{reason}}, :user_ban, subject: user, user: banner)
  end

  def create_unban_mod_action
    ModAction.log(%{unbanned <@#{user_name}>}, :user_unban, subject: user, user: CurrentUser.user)
  end

  def delete_user_data
    if delete_posts
      user.posts.pending.parallel_find_each do |post|
        if post_deletion_tags.present?
          if post_deletion_tags_nuke
            post.update!(tag_string: post_deletion_tags)
          else
            post.update!(tag_string: "#{post.tag_string} #{post_deletion_tags}".strip)
          end
        end
        post&.ai_metadata&.update!(prompt: "", negative_prompt: "", parameters: {}, updater: banner) if post_deletion_metadata_nuke
        post.delete!(post_deletion_reason)
      end
    end

    if delete_forum_posts
      user.forum_topics.undeleted.each(&:soft_delete!)
      user.forum_posts.undeleted.each(&:soft_delete!)
    end

    if delete_comments
      user.comments.undeleted.each(&:soft_delete!)
    end

    if delete_votes
      user.post_votes.undeleted.each(&:soft_delete!)
      user.comment_votes.undeleted.each do |vote|
        vote.updater = banner
        vote.soft_delete!
      end
    end
  end

  def self.available_includes
    [:user, :banner]
  end
end

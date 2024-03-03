# frozen_string_literal: true

class PostDisapprovalPolicy < ApplicationPolicy
  def create?
    user.is_approver? && unbanned?
  end

  def can_view_creator?
    user.is_moderator? || record.user_id == user.id
  end

  def can_search_creator?
    user.is_moderator?
  end

  def permitted_attributes_for_create
    [:post_id, :reason, :message]
  end

  def permitted_attributes_for_update
    [:reason, :message]
  end

  def edit?
    update?
  end

  def update?
    unbanned? && record.post.in_modqueue? && record.user_id == user.id
  end

  def api_attributes
    attributes = super
    attributes -= [:user_id] unless can_view_creator?
    attributes
  end

  def visible_for_search(disapprovals, attribute)
    case attribute
    in :user | :user_id if !can_search_creator?
      disapprovals.where(user: user)
    else
      disapprovals
    end
  end
end

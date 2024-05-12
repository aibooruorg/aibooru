# frozen_string_literal: true

class AIModelPolicy < ApplicationPolicy
  def create?
    user.is_builder?
  end

  def update?
    create?
  end

  def permitted_attributes
    [:name, :description, :model_hash, :sha_hash, :magnet]
  end
end

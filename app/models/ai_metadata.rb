# frozen_string_literal: true

class AIMetadata < ApplicationRecord
  include Versionable
  attr_accessor :updater

  def self.search(params, current_user)
    q = search_attributes(params, [:id], current_user: current_user)
    q.apply_default_order(params)
  end
end

# frozen_string_literal: true

class AIMetadataVersion < ApplicationRecord
  include VersionFor

  belongs_to :post
  version_for :ai_metadata

  alias previous previous_version

  def self.search(params, current_user)
    q = search_attributes(params, [:id, :post_id, :prompt, :negative_prompt, :sampler, :seed, :steps, :cfg_scale, :model_hash, :created_at, :updated_at, :version, :updater_id], current_user: current_user)

    q.apply_default_order(params)
  end

  def self.status_fields
    {
      prompt: "Prompt",
      negative_prompt: "NegPrompt",
      sampler: "Sampler",
      seed: "Seed",
      steps: "Steps",
      cfg_scale: "CfgScale",
      model_hash: "Hash",
    }
  end

  def self.available_includes
    [:post, :updater, :ai_metadata]
  end
end

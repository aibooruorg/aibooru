# frozen_string_literal: true

class AIModel < ApplicationRecord
  belongs_to_updater
  belongs_to :creator, class_name: "User"

  dtext_attribute :description, media_embeds: true # defines :dtext_description

  before_save :normalize_hashes
  validate :validate_magnet_uri, if: :magnet_changed?
  validate :validate_hashes, if: -> { sha_hash_changed? || model_hash_changed? }

  def self.search(params, current_user)
    q = search_attributes(params, [:id, :name, :description, :model_hash, :sha_hash, :magnet, :creator, :updater, :created_at, :updated_at], current_user: current_user)

    if params[:name_or_hash_matches].present?
      q = q.where(model_hash: params[:name_or_hash_matches]).or(where_like(:name, params[:name_or_hash_matches]))
    end

    q.apply_default_order(params)
  end

  def magnet_uri
    if magnet.present?
      uri = Addressable::URI.parse(magnet)
    end
  end

  concerning :ValidationMethods do
    def normalize_hashes
      self.sha_hash = self.sha_hash.downcase
      self.model_hash = self.model_hash.downcase
    end

    def validate_magnet_uri
      if magnet.present?
        uri = magnet_uri

        if uri.scheme != "magnet"
          errors.add(:magnet_uri, "is not a magnet URI")
        end

        if uri.query_values["xt"].blank?
          errors.add(:magnet_uri, "is missing the xt value")
        end
      end
    end

    def validate_hashes
      if !self.sha_hash.match?(/[a-z0-9]{64}/)
        errors.add(:sha_hash, "is invalid")
      end

      if !self.model_hash.match?(/\A[a-f0-9]+\Z/)
        errors.add(:model_hash, "is invalid")
      end
    end
  end
end

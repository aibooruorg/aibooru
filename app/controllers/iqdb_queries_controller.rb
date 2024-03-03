# frozen_string_literal: true

class IqdbQueriesController < ApplicationController
  respond_to :html, :json, :xml, :js

  def show
    # XXX allow bare search params for backwards compatibility.
    search_params.merge!(params.slice(:url, :hash, :image_url, :file_url, :post_id, :media_asset_id, :limit, :similarity, :high_similarity).permit!)

    iqdb_params = search_params.to_h.symbolize_keys
    @high_similarity_matches, @low_similarity_matches, @matches = IqdbClient.new.search(**iqdb_params)
    respond_with(@matches, template: "iqdb_queries/show", location: iqdb_queries_path)
  rescue IqdbClient::Error => error
    flash[:notice] = error.message
    @high_similarity_matches, @low_similarity_matches, @matches = [], [], []
    respond_with(@matches, template: "iqdb_queries/show", location: iqdb_queries_path)
  end

  alias create show
end

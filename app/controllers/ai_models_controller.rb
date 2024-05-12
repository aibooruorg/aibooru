# frozen_string_literal: true

class AIModelsController < ApplicationController
  respond_to :html, :json, :xml

  def index
    @ai_models = authorize AIModel.visible(CurrentUser.user).paginated_search(params)
    respond_with(@ai_models)
  end

  def show
    @ai_model = authorize AIModel.find(params[:id])
    respond_with(@ai_model)
  end

  def new
    @ai_model = authorize AIModel.new(creator: CurrentUser.user, **permitted_attributes(AIModel))
    respond_with(@ai_model)
  end

  def create
    @ai_model = authorize AIModel.new(creator: CurrentUser.user, **permitted_attributes(AIModel))
    @ai_model.save
    respond_with(@ai_model)
  end

  def edit
    @ai_model = authorize AIModel.find(params[:id])
    respond_with(@ai_model)
  end

  def update
    @ai_model = authorize AIModel.find(params[:id])
    @ai_model.update(permitted_attributes(@ai_model))
    respond_with(@ai_model)
  end

  def destroy
    @ai_model.destroy!
    respond_with(@ai_model)
  end
end

# frozen_string_literal: true

class ForumPostsController < ApplicationController
  respond_to :html, :xml, :json, :js

  rate_limit :create, rate: 1.0/1.minute, burst: 50

  def new
    @forum_post = authorize ForumPost.new_reply(params)
    respond_with(@forum_post)
  end

  def edit
    @forum_post = authorize ForumPost.find(params[:id])
    respond_with(@forum_post)
  end

  def index
    @forum_posts = authorize ForumPost.visible(CurrentUser.user).paginated_search(params)
    @forum_posts = @forum_posts.includes(:topic, :creator) if request.format.html?

    respond_with(@forum_posts)
  end

  def search
  end

  def show
    @forum_post = authorize ForumPost.find(params[:id])

    respond_with(@forum_post) do |format|
      format.html do
        page = @forum_post.forum_topic_page
        page = nil if page == 1
        redirect_to forum_topic_path(@forum_post.topic, page: page, anchor: "forum_post_#{@forum_post.id}")
      end
    end
  end

  def create
    @forum_post = authorize ForumPost.new(creator: CurrentUser.user, creator_ip_addr: request.remote_ip, topic_id: params.dig(:forum_post, :topic_id))
    @forum_post.update(permitted_attributes(@forum_post))

    page = @forum_post.topic.last_page if @forum_post.topic.last_page > 1
    respond_with(@forum_post, :location => forum_topic_path(@forum_post.topic, :page => page))
  end

  def update
    @forum_post = authorize ForumPost.find(params[:id])
    @forum_post.update(permitted_attributes(@forum_post))
    page = @forum_post.forum_topic_page if @forum_post.forum_topic_page > 1
    respond_with(@forum_post, :location => forum_topic_path(@forum_post.topic, :page => page, :anchor => "forum_post_#{@forum_post.id}"))
  end

  def destroy
    @forum_post = authorize ForumPost.find(params[:id])
    @forum_post.delete!

    flash[:notice] = @forum_post.errors.none? ? "Post deleted" : @forum_post.errors.full_messages.join("; ")
    respond_with(@forum_post)
  end

  def undelete
    @forum_post = authorize ForumPost.find(params[:id])
    @forum_post.undelete!

    flash[:notice] = @forum_post.errors.none? ? "Post undeleted" : @forum_post.errors.full_messages.join("; ")
    respond_with(@forum_post)
  end
end

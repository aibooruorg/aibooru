# frozen_string_literal: true

# A single tag or tree of subtags in a CategorizedTagListComponent. Used in app/views/posts/show.html.erb.
#
# This is a separate component because ViewComponent doesn't support partials.
class CategorizedTagListEntryComponent < ApplicationComponent
  # The tag is called `t` because `tag` is used by a Rails view helper method.
  attr_reader :t, :subtags, :show_extra_links, :current_query, :level

  delegate :humanized_number, to: :helpers

  # @param tag [Tag] The tag to render.
  # @param show_extra_links [Boolean] Whether to include +/- links.
  # @param subtags [Array<Tag, Array>] An optional tree of subtags to render beneath this tag.
  # @param level [Integer] The current nesting level for the tree of subtags.
  def initialize(tag, subtags = [], show_extra_links: false, current_query: nil, level: 0)
    @t = tag
    @subtags = subtags
    @show_extra_links = show_extra_links
    @current_query = current_query
    @level = level
  end

  def is_underused_tag?
    t.post_count <= 1 && t.general? && t.name !~ /_\((cosplay|style)\)\z/
  end
end

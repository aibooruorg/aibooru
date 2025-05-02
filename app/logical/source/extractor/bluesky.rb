# frozen_string_literal: true

# @see Source::URL::Bluesky
class Source::Extractor::Bluesky < Source::Extractor
  def self.enabled?
    Danbooru.config.bluesky_identifier.present? && Danbooru.config.bluesky_password.present?
  end

  def image_urls
    if parsed_url.image_url?
      [parsed_url.full_image_url]
    else
      image_urls_from_api
    end
  end

  def image_urls_from_api
    embed = api_response&.dig("thread", "post", "record", "embed").to_h

    if embed["$type"] == "app.bsky.embed.recordWithMedia"
      embed = embed["media"].to_h
    end

    blobs = case embed["$type"]
    when "app.bsky.embed.images"
      embed["images"].pluck("image")
    when "app.bsky.embed.video"
      [embed["video"]]
    else
      []
    end

    blobs.map do |blob|
      blob_cid = blob.dig("ref", "$link") || blob.dig("cid")
      "https://bsky.social/xrpc/com.atproto.sync.getBlob?did=#{user_did}&cid=#{blob_cid}"
    end
  end

  def page_url
    "#{account_url || profile_url}/post/#{post_id}" if post_id.present?
  end

  def profile_url
    "https://bsky.app/profile/#{user_handle}" if user_handle.present?
  end

  def account_url
    "https://bsky.app/profile/#{user_did}" if user_did.present?
  end

  def profile_urls
    [profile_url, account_url].compact
  end

  def username
    # ixy.bsky.social -> ixy
    user_handle.to_s.split(".").first
  end

  def display_name
    api_response&.dig("thread", "post", "author", "displayName")
  end

  def user_handle
    user_handle_from_api || user_handle_from_url
  end

  def user_handle_from_api
    api_response&.dig("thread", "post", "author", "handle")
  end

  def user_handle_from_url
    parsed_url.user_handle || parsed_referer&.user_handle
  end

  def user_did
    user_did_from_api || user_did_from_url
  end

  def user_did_from_url
    parsed_url.user_did || parsed_referer&.user_did
  end

  # https://www.docs.bsky.app/docs/api/com-atproto-identity-resolve-handle
  memoize def user_did_from_api
    return unless user_handle_from_url.present?

    response = http.cache(1.minute).parsed_get(
      "https://bsky.social/xrpc/com.atproto.identity.resolveHandle",
      params: { handle: user_handle_from_url }
    ) || {}
    response["did"]
  end

  def post_id
    parsed_url.post_id || parsed_referer&.post_id
  end

  def artist_commentary_desc
    api_response&.dig("thread", "post", "record", "text") || ""
  end

  def dtext_artist_commentary_desc
    DText.from_html(html_artist_commentary_desc, base_url: "https://bsky.app")
  end

  def html_artist_commentary_desc
    text = artist_commentary_desc.dup.force_encoding("ASCII-8BIT")

    api_response&.dig("thread", "post", "record", "facets").to_a.reverse.each do |facet|
      tag = facet["features"].to_a.find {|f| f["$type"] == "app.bsky.richtext.facet#tag"}
      next if tag.nil?

      tag_name = tag["tag"]
      byte_start = facet.dig("index", "byteStart")
      byte_end = facet.dig("index", "byteEnd")
      text[byte_start...byte_end] = %{<a href="https://bsky.app/hashtag/#{CGI.escapeHTML(Danbooru::URL.escape(tag_name))}">##{CGI.escapeHTML(tag_name)}</a>}.force_encoding("ASCII-8BIT")
    end

    text.force_encoding("UTF-8").gsub("\n", "<br>")
  end

  def tags
    api_response&.dig("thread", "post", "record", "facets").to_a.pluck("features").flatten.select do |f|
      f["$type"] == "app.bsky.richtext.facet#tag"
    end.pluck("tag").map do |tag|
      [tag, "https://bsky.app/hashtag/#{Danbooru::URL.escape(tag)}"]
    end
  end

  # https://www.docs.bsky.app/docs/api/app-bsky-feed-get-post-thread
  memoize def api_response
    return {} unless post_id.present?

    request(
      "https://bsky.social/xrpc/app.bsky.feed.getPostThread",
      uri: "at://#{user_did}/app.bsky.feed.post/#{post_id}",
      depth: 0,
      parentHeight: 0
    )
  end

  # https://www.docs.bsky.app/docs/api/com-atproto-server-create-session
  memoize def access_token
    response = http.parsed_post(
      "https://bsky.social/xrpc/com.atproto.server.createSession",
      json: { identifier: Danbooru.config.bluesky_identifier, password: Danbooru.config.bluesky_password }
    ).to_h

    if response["error"].present?
      DanbooruLogger.info("Bluesky login failed (#{response["message"]} #{response["message"]})")
      nil
    else
      response["accessJwt"]
    end
  end

  memoize def cached_access_token
    Cache.get("bluesky-access-token", 1.hour, skip_nil: true) do
      access_token
    end
  end

  def clear_cached_access_token!
    flush_cache # clear memoized access token
    Cache.delete("bluesky-access-token")
  end

  def request(url, **params)
    response = http.cache(1.minute).headers(Authorization: "Bearer #{cached_access_token}").get(url, params: params).parse

    if response["error"].in?(%w[InvalidToken ExpiredToken])
      DanbooruLogger.info("Bluesky access token stale; logging in again")
      clear_cached_access_token!
      response = http.cache(1.minute).headers(Authorization: "Bearer #{cached_access_token}").get(url, params: params).parse
    end

    response
  end
end

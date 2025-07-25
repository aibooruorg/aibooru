# frozen_string_literal: true

# @see Source::URL::Twitter
class Source::Extractor
  class Twitter < Source::Extractor
    # List of hashtag suffixes attached to tag other names
    # Ex: 西住みほ生誕祭2019 should be checked as 西住みほ
    # The regexes will not match if there is nothing preceding
    # the pattern to avoid creating empty strings.
    COMMON_TAG_REGEXES = [
      /(?<!\A)生誕祭(?:\d*)\z/,
      /(?<!\A)誕生祭(?:\d*)\z/,
      /(?<!\A)版もうひとつの深夜の真剣お絵描き60分一本勝負(?:_\d+)?\z/,
      /(?<!\A)版深夜の真剣お絵描き60分一本勝負(?:_\d+)?\z/,
      /(?<!\A)版深夜の真剣お絵かき60分一本勝負(?:_\d+)?\z/,
      /(?<!\A)深夜の真剣お絵描き60分一本勝負(?:_\d+)?\z/,
      /(?<!\A)版深夜のお絵描き60分一本勝負(?:_\d+)?\z/,
      /(?<!\A)版真剣お絵描き60分一本勝(?:_\d+)?\z/,
      /(?<!\A)版お絵描き60分一本勝負(?:_\d+)?\z/,
    ]

    def image_urls
      # https://pbs.twimg.com/media/EBGbJe_U8AA4Ekb.jpg:orig
      if parsed_url.full_image_url.present?
        [parsed_url.full_image_url]
      elsif parsed_url.image_url?
        [parsed_url.to_s]
      else
        graphql_tweet.dig(:legacy, :extended_entities, :media).to_a.map do |media|
          if media[:type] == "photo"
            media[:media_url_https] + ":orig"
          elsif media[:type].in?(["video", "animated_gif"])
            variants = media.dig(:video_info, :variants)
            videos = variants.select { |variant| variant[:content_type] == "video/mp4" }
            video = videos.max_by { |v| v[:bitrate].to_i }
            video[:url]
          end
        end
      end
    end

    def page_url
      "https://twitter.com/#{username}/status/#{status_id}" if status_id.present? && username.present?
    end

    def profile_url
      "https://twitter.com/#{username}" if username.present?
    end

    def intent_url
      return nil if user_id.blank?
      "https://twitter.com/intent/user?user_id=#{user_id}"
    end

    def profile_urls
      [profile_url, intent_url].compact.uniq
    end

    def user_id
      parsed_url.user_id || parsed_referer&.user_id || graphql_tweet.dig(:legacy, :user_id_str)
    end

    def username
      parsed_url.username || parsed_referer&.username || graphql_tweet.dig(:core, :user_results, :result, :legacy, :screen_name)
    end

    def display_name
      graphql_tweet.dig(:core, :user_results, :result, :legacy, :name)
    end

    def artist_commentary_desc
      graphql_tweet.dig(:note_tweet, :note_tweet_results, :result, :text) || graphql_tweet.dig(:legacy, :full_text)
    end

    def tags
      graphql_tweet.dig(:legacy, :entities, :hashtags).to_a.map do |hashtag|
        [hashtag[:text], "https://twitter.com/hashtag/#{hashtag[:text]}"]
      end
    end

    def normalize_tag(tag)
      COMMON_TAG_REGEXES.each do |rg|
        norm_tag = tag.gsub(rg, "")
        if norm_tag != tag
          return norm_tag
        end
      end
      tag
    end

    def dtext_artist_commentary_desc
      DText.from_html(html_artist_commentary_desc, base_url: "https://twitter.com")
    end

    def html_artist_commentary_desc
      return nil if artist_commentary_desc.blank?

      html = "".dup
      desc = artist_commentary_desc
      entities = []
      api_entities = graphql_tweet.dig(:note_tweet, :note_tweet_results, :result, :entity_set) || graphql_tweet.dig(:legacy, :entities)

      entities += api_entities[:hashtags].to_a.pluck(:indices, :text).map do |e|
        { first: e[0][0], last: e[0][1], text: e[1], html: %{<a href="https://twitter.com/hashtag/#{CGI.escapeHTML(Danbooru::URL.escape(e[1]))}">##{CGI.escapeHTML(e[1])}</a>} }
      end

      entities += api_entities[:urls].to_a.pluck(:indices, :expanded_url).map do |e|
        { first: e[0][0], last: e[0][1], text: e[1], html: %{<a href="#{CGI.escapeHTML(e[1])}">#{CGI.escapeHTML(e[1])}</a>} }
      end

      entities += api_entities[:user_mentions].to_a.pluck(:indices, :screen_name).map do |e|
        { first: e[0][0], last: e[0][1], text: e[1], html: %{<a href="https://twitter.com/#{CGI.escapeHTML(Danbooru::URL.escape(e[1]))}">@#{CGI.escapeHTML(e[1])}</a>} }
      end

      entities += api_entities[:symbols].to_a.pluck(:indices, :text).map do |e|
        { first: e[0][0], last: e[0][1], text: e[1], html: %{<a href="https://twitter.com/search?q=$#{CGI.escapeHTML(Danbooru::URL.escape(e[1]))}">$#{CGI.escapeHTML(e[1])}</a>} }
      end

      entities += api_entities[:media].to_a.pluck(:indices, :expanded_url).map do |e|
        { first: e[0][0], last: e[0][1], text: e[1], html: "" }
      end

      entities.sort_by! { _1[:first] }

      i = 0
      entities.each do |entity|
        # HTML characters in `desc` are already escaped by Twitter, so we don't have to escape them ourselves.
        html << desc[i..entity[:first] - 1].gsub("\n", "<br>") if i < entity[:first]
        html << entity[:html]
        i = entity[:last]
      end

      html << desc[i..desc.size].gsub("\n", "<br>")

      graphql_tweet.dig(:legacy, :entities, :media).to_a.pluck(:ext_alt_text).compact_blank.each do |alt_text|
        html << <<~EOS.chomp
          <blockquote>
          <h6>Image Description</h6>
          <p>#{CGI.escapeHTML(alt_text).gsub("\n", "<br>")}</p>
          </blockquote>
        EOS
      end

      html
    end

    memoize def syndication_api_response
      return {} if status_id.blank?

      # https://publish.twitter.com/?query=https%3A%2F%2Ftwitter.com%2Ftwotenky%2Fstatus%2F1577831592227000320
      # https://cdn.syndication.twimg.com/tweet-result?id=1577831592227000320
      http.cache(1.minute).parsed_get("https://cdn.syndication.twimg.com/tweet-result?id=#{status_id}") || {}
    end

    memoize def graphql_api_response
      return {} if status_id.blank?

      # These params are necessary for the GraphQL API. It will return an error if they're not all present.
      variables = {
        focalTweetId: status_id,
        with_rux_injections: false,
        rankingMode: "Relevance",
        includePromotedContent: true,
        withCommunity: true,
        withQuickPromoteEligibilityTweetFields: true,
        withBirdwatchNotes: true,
        withVoice: true
      }

      features = {
        rweb_video_screen_enabled: false,
        profile_label_improvements_pcf_label_in_post_enabled: true,
        rweb_tipjar_consumption_enabled: true,
        verified_phone_label_enabled: false,
        creator_subscriptions_tweet_preview_api_enabled: true,
        responsive_web_graphql_timeline_navigation_enabled: true,
        responsive_web_graphql_skip_user_profile_image_extensions_enabled: false,
        premium_content_api_read_enabled: false,
        communities_web_enable_tweet_community_results_fetch: true,
        c9s_tweet_anatomy_moderator_badge_enabled: true,
        responsive_web_grok_analyze_button_fetch_trends_enabled: false,
        responsive_web_grok_analyze_post_followups_enabled: true,
        responsive_web_jetfuel_frame: false,
        responsive_web_grok_share_attachment_enabled: true,
        articles_preview_enabled: true,
        responsive_web_edit_tweet_api_enabled: true,
        graphql_is_translatable_rweb_tweet_is_translatable_enabled: true,
        view_counts_everywhere_api_enabled: true,
        longform_notetweets_consumption_enabled: true,
        responsive_web_twitter_article_tweet_consumption_enabled: true,
        tweet_awards_web_tipping_enabled: false,
        responsive_web_grok_show_grok_translated_post: false,
        responsive_web_grok_analysis_button_from_backend: true,
        creator_subscriptions_quote_tweet_preview_enabled: false,
        freedom_of_speech_not_reach_fetch_enabled: true,
        standardized_nudges_misinfo: true,
        tweet_with_visibility_results_prefer_gql_limited_actions_policy_enabled: true,
        longform_notetweets_rich_text_read_enabled: true,
        longform_notetweets_inline_media_enabled: true,
        responsive_web_grok_image_annotation_enabled: true,
        responsive_web_enhance_cards_enabled: false
      }

      parsed_get("/i/api/graphql/_8aYOgEDz35BrBcBal1-_w/TweetDetail", variables: variables.to_json, features: features.to_json) || {}
    end

    memoize def graphql_tweet
      return {} if status_id.blank?

      instructions = graphql_api_response.dig("data", "threaded_conversation_with_injections_v2", "instructions").to_a
      entries = instructions.find { |instruction| instruction["type"] == "TimelineAddEntries" }&.dig("entries")
      entry = entries&.find { |entry| entry["entryId"] == "tweet-#{status_id}" }
      result = entry&.dig("content", "itemContent", "tweet_results", "result") || {}
      result["tweet"] || result
    end

    def http
      super.headers(
        authorization: "Bearer AAAAAAAAAAAAAAAAAAAAANRILgAAAAAAnNwIzUejRCOuH5E6I8xnZz4puTs%3D1Zv7ttfk8LF81IUq16cHjhLTvJu4FA33AGWWjCpTnA", # non-secret; used by the official client
        "x-csrf-token": Danbooru.config.twitter_csrf_token
      ).cookies(
        auth_token: Danbooru.config.twitter_auth_token,
        ct0: Danbooru.config.twitter_csrf_token
      )
    end

    def parsed_get(path, **params)
      headers = { "x-client-transaction-id": tid_generator.transaction_id(path) }
      response = http.cache(1.minute).headers(headers).get("https://x.com#{path}", params: params)
      # puts ({ status: response.status, **headers, time: tid_generator.time, xor_key: tid_generator.xor_key, key: tid_generator.twitter_site_verification_key, rate_limit: response.headers["x-rate-limit-remaining"] }).to_json
      response.parse if response.status.success?
    end

    memoize def tid_generator
      TwitterTransactionIdGenerator.new(http: Danbooru::Http.external)
    end

    def status_id
      parsed_url.status_id || parsed_referer&.status_id
    end
  end
end

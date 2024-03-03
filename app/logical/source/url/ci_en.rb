# frozen_string_literal: true

class Source::URL::CiEn < Source::URL
  attr_reader :creator_id, :article_id

  def self.match?(url)
    url.host.in?(%w[ci-en.jp ci-en.net ci-en.dlsite.com media.ci-en.jp])
  end

  def parse
    case host

    in ("ci-en.jp" | "ci-en.net" | "ci-en.dlsite.com")
      case [*path_segments]

      # https://ci-en.net/creator/11019/article/921762
      # https://ci-en.dlsite.com/creator/5290/article/998146
      in "creator", creator_id, "article", article_id, *rest
        @creator_id = creator_id
        @article_id = article_id

      # https://ci-en.net/creator/11019
      # https://ci-en.dlsite.com/creator/5290
      in "creator", creator_id, *rest
        @creator_id = creator_id

      else
        nil
      end

    else
      nil
    end
  end

  def site_name
    "Ci-En"
  end

  def image_url?
    host == "media.ci-en.jp"
  end

  def page_url
    if article_id.present?
      "#{profile_url}/article/#{article_id}"
    else
      profile_url
    end
  end

  # All-ages and R18 pages urls are interchangeable and will redirect to the correct site
  def profile_url
    if creator_id.present?
      "https://ci-en.net/creator/#{creator_id}"
    end
  end

  # Public profiles require a self-introduction article, so every profile url is also a page url
  def profile_url?
    profile_url.present? && page_url == profile_url && !image_url?
  end
end

# frozen_string_literal: true

# Unhandled:
#
# * https://pic01.nijie.info/nijie_picture/20120211210359.jpg
# * https://pic01.nijie.info/nijie_picture/2012021022424020120210.jpg
# * https://pic01.nijie.info/nijie_picture/diff/main/2012061023480525712_0.jpg
# * https://pic05.nijie.info/dojin_main/dojin_sam/1_2768_20180429004232.png
# * https://pic04.nijie.info/horne_picture/diff/main/56095_20160403221810_0.jpg
# * https://pic04.nijie.info/omata/4829_20161128012012.png (page: http://nijie.info/view_popup.php?id=33224#diff_3)

class Source::URL::Nijie < Source::URL
  attr_reader :work_id, :user_id

  def self.match?(url)
    url.domain.in?(%w[nijie.net nijie.info])
  end

  def parse
    case [domain, *path_segments]

    # https://nijie.info/view.php?id=167755 (deleted post)
    # https://nijie.info/view.php?id=218856
    # https://nijie.info/view_popup.php?id=218856
    # https://nijie.info/view_popup.php?id=218856#diff_1
    # https://www.nijie.info/view.php?id=218856
    # https://sp.nijie.info/view.php?id=218856
    in "nijie.info", ("view.php" | "view_popup.php") if params[:id].present?
      @work_id = params[:id]

    # https://nijie.info/members.php?id=236014
    # https://nijie.info/members_illust.php?id=236014
    in "nijie.info", ("members.php" | "members_illust.php") if params[:id].present?
      @user_id = params[:id]

    # https://pic.nijie.net/07/nijie/17/95/728995/illust/0_0_403fdd541191110c_c25585.jpg
    # https://pic.nijie.net/06/nijie/17/14/236014/illust/218856_1_7646cf57f6f1c695_f2ed81.png
    in _, /^\d{2}$/, "nijie", /^\d{2}$/, /^\d{2}$/, user_id, "illust", _ if image_url?
      @user_id = user_id
      parse_filename

    # https://pic01.nijie.info/nijie_picture/diff/main/218856_0_236014_20170620101329.png (page: http://nijie.info/view.php?id=218856)
    # https://pic01.nijie.info/nijie_picture/diff/main/218856_1_236014_20170620101330.png
    # https://pic05.nijie.info/nijie_picture/diff/main/559053_20180604023346_1.png (page: http://nijie.info/view_popup.php?id=265428#diff_2)
    # https://pic04.nijie.info/nijie_picture/diff/main/287736_161475_20181112032855_1.png (page: http://nijie.info/view_popup.php?id=287736#diff_2)
    # https://pic02.nijie.info/nijie_picture/diff/main/0_23473_141_20120913002158.jpg
    # https://pic03.nijie.info/nijie_picture/28310_20131101215959.jpg (page: https://www.nijie.info/view.php?id=64240)
    # https://pic03.nijie.info/nijie_picture/236014_20170620101426_0.png (page: https://www.nijie.info/view.php?id=218856)
    # https://pic.nijie.net/03/nijie_picture/236014_20170620101426_0.png (page: https://www.nijie.info/view.php?id=218856)
    # https://pic.nijie.net/01/nijie_picture/diff/main/196201_20150201033106_0.jpg
    in [*, "nijie_picture", *] if image_url?
      parse_filename

    # http://pic.nijie.net/01/dojin_main/dojin_sam/20120213044700コピー ～ 0011のコピー.jpg (NSFW)
    # http://pic.nijie.net/01/__rs_l120x120/dojin_main/dojin_sam/20120213044700コピー ～ 0011のコピー.jpg
    in _, /^\d+$/, *subdir, "dojin_main", "dojin_sam", file if image_url?
      nil

    else
      nil
    end
  end

  def parse_filename
    case filename.split("_")

    # 28310_20131101215959.jpg
    # 236014_20170620101426_0.png
    # 829001_20190620004513_0.mp4
    # 559053_20180604023346_1.png
    in /^\d+$/ => user_id, /^\d{14}$/ => timestamp, *rest
      @user_id = user_id

    # 0_23473_141_20120913002158.jpg
    # 218856_0_236014_20170620101329.png
    in /^\d+$/ => work_id, /^\d+$/, /^\d+$/ => user_id, /^\d{14}$/ => timestamp
      @work_id = work_id if work_id.to_i != 0
      @user_id = user_id

    # 287736_161475_20181112032855_1.png
    in /^\d+$/ => work_id, /^\d+$/ => user_id, /^\d{14}$/ => timestamp, /^\d+$/
      @work_id, @user_id = work_id, user_id

    # 0_0_403fdd541191110c_c25585.jpg
    # 218856_1_7646cf57f6f1c695_f2ed81.png
    in /^\d+$/ => work_id, /^\d+$/, /^\h+$/, /^\h+$/
      @work_id = work_id if work_id.to_i != 0

    else
      nil
    end
  end

  def image_url?
    subdomain.to_s.starts_with?("pic")
  end

  def full_image_url
    to_s.remove(%r{__rs_\w+/}i).gsub("http:", "https:") if image_url?
  end

  def page_url
    "https://nijie.info/view.php?id=#{work_id}" if work_id.present?
  end

  def profile_url
    "https://nijie.info/members.php?id=#{user_id}" if user_id.present?
  end
end

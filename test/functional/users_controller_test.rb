require 'test_helper'

class UsersControllerTest < ActionDispatch::IntegrationTest
  context "The users controller" do
    setup do
      @user = create(:user, name: "bob")
    end

    context "index action" do
      setup do
        @mod_user = create(:moderator_user, name: "yukari")
        @other_user = create(:contributor_user, inviter: @mod_user, created_at: 2.weeks.ago)
        @uploader = create(:user, created_at: 2.weeks.ago)
      end

      should "render" do
        get users_path
        assert_response :success
      end

      should "render for a sitemap" do
        get users_path(format: :sitemap)
        assert_response :success
        assert_equal(User.count, response.parsed_body.css("urlset url loc").size)
      end

      should "redirect to the user's profile for /users?name=<name>" do
        get users_path, params: { name: @user.name }
        assert_redirected_to(@user)
      end

      should "be case-insensitive when redirecting to the user's profile" do
        get users_path, params: { name: @user.name.capitalize }
        assert_redirected_to(@user)
      end

      should "raise error for /users?name=<nonexistent>" do
        get users_path, params: { name: "nobody" }
        assert_response 404
      end

      should respond_to_search({}).with { [@uploader, @other_user, @mod_user, @user, User.system] }
      should respond_to_search(min_level: User::Levels::BUILDER).with { [@other_user, @mod_user, User.system] }
      should respond_to_search(name_matches: "yukari").with { @mod_user }

      context "using includes" do
        setup do
          as (@uploader) { @post = create(:post, tag_string: "touhou", uploader: @uploader, is_flagged: true) }
          as (@user) do
            create(:note, post: @post)
            create(:artist_commentary, post: @post)
            create(:artist)
            create(:wiki_page)
            @forum = create(:forum_post, creator: @user, topic: build(:forum_topic, creator: @user))
          end
          as (@other_user) do
            @other_post = create(:post, rating: "e", uploader: @other_user)
            create(:post_appeal, creator: @other_user)
            create(:comment, creator: @other_user, post: @other_post)
            create(:forum_post_vote, creator: @other_user, forum_post: @forum)
            create(:tag_alias, creator: @other_user)
            create(:tag_implication, creator: @other_user)
          end
          as (@mod_user) do
            create(:post_approval, user: @mod_user, post: @post)
            create(:user_feedback, user: @other_user, creator: @mod_user)
            create(:ban, user: @other_user, banner: @mod_user)
          end
        end

        should respond_to_search(has_artist_versions: "true").with { @user }
        should respond_to_search(has_wiki_page_versions: "true").with { @user }
        should respond_to_search(has_forum_topics: "true").with { @user }
        should respond_to_search(has_forum_posts: "true").with { @user }
        should respond_to_search(has_forum_post_votes: "true").with { @other_user }
        should respond_to_search(has_feedback: "true").with { @other_user }
        should respond_to_search(has_tag_aliases: "true").with { @other_user }
        should respond_to_search(has_tag_implications: "true").with { @other_user }
        should respond_to_search(has_bans: "true").with { @other_user }
        should respond_to_search(has_artist_commentary_versions: "true").with { @user }
        should respond_to_search(has_comments: "true").with { @other_user }
        should respond_to_search(has_note_versions: "true").with { @user }
        should respond_to_search(has_post_appeals: "true").with { @other_user }
        should respond_to_search(has_post_approvals: "true").with { @mod_user }
        should respond_to_search(has_posts: "true").with { [@uploader, @other_user] }
        should respond_to_search(posts_tags_match: "touhou").with { @uploader }
        should respond_to_search(posts: {rating: "e"}).with { @other_user }
        should respond_to_search(inviter: {name: "yukari"}).with { @other_user }

        context "a user with private forum posts" do
          setup do
            as(@user) do
              @private_post = create(:forum_post, body: "private", creator: @user, topic: create(:mod_up_forum_topic))
              @public_post = create(:forum_post, body: "public", creator: @user)
            end
          end

          # should ignore the existence of private forum posts the current user doesn't have access to.
          should respond_to_search(forum_posts: { body: "private" }).with { [] }
          should respond_to_search(forum_posts: { body: "public" }).with { [@user] }
        end
      end
    end

    context "#deactivate action" do
      should "render /users/:id/deactivate for the current user" do
        get_auth deactivate_user_path(@user), @user
        assert_response :success
      end

      should "render /users/:id/deactivate for the Owner user" do
        get_auth deactivate_user_path(@user), create(:owner)
        assert_response :success
      end

      should "not render /users/:id/deactivate for a different user" do
        get_auth deactivate_user_path(@user), create(:user)
        assert_response 403
      end

      should "render /users/deactivate for a logged-in user" do
        get_auth deactivate_users_path, @user
        assert_response :success
      end

      should "not render /users/deactivate for a logged-out user" do
        get deactivate_users_path
        assert_response 403
      end

      should "redirect /maintenance/user/deletion to /users/deactivate" do
        get "/maintenance/user/deletion"
        assert_redirected_to deactivate_users_path
      end
    end

    context "#destroy action" do
      should "delete the user when given the correct password" do
        delete_auth user_path(@user), @user, params: { user: { password: "password" }}

        assert_redirected_to posts_path
        assert_equal(true, @user.reload.is_deleted?)
        assert_equal("Your account has been deactivated", flash[:notice])
        assert_nil(session[:user_id])
        assert_equal(true, @user.user_events.user_deletion.exists?)
      end

      should "not delete the user when given an incorrect password" do
        delete_auth user_path(@user), @user, params: { user: { password: "hunter2" }}

        assert_redirected_to deactivate_user_path(@user)
        assert_equal(false, @user.reload.is_deleted?)
        assert_equal("Password is incorrect", flash[:notice])
        assert_equal(@user.id, session[:user_id])
        assert_equal(false, @user.user_events.user_deletion.exists?)
      end

      should "allow the Owner to delete other users" do
        delete_auth user_path(@user), create(:owner)

        assert_redirected_to posts_path
        assert_equal(true, @user.reload.is_deleted?)
        assert_equal("Your account has been deactivated", flash[:notice])
        assert_equal(true, @user.user_events.user_deletion.exists?)
      end

      should "not allow users to delete other users" do
        delete_auth user_path(@user), create(:user), params: { user: { password: "password" }}

        assert_response 403
      end

      should "not allow logged-out users to delete other users" do
        delete user_path(@user), params: { user: { password: "password" }}

        assert_response 403
      end
    end

    context "custom_style action" do
      should "work" do
        @user.update!(custom_style: "span { color: red; }")
        get_auth custom_style_users_path(format: "css"), @user
        assert_response :success
      end
    end

    context "show action" do
      setup do
        # flesh out profile to get more test coverage of user presenter.
        @user = create(:approver, created_at: 2.weeks.ago)
        as(@user) do
          create(:saved_search, user: @user)
          create(:post, uploader: @user, tag_string: "fav:#{@user.name}")
        end
      end

      should "render" do
        get user_path(@user)
        assert_response :success
      end

      should "show hidden attributes to the owner" do
        get_auth user_path(@user), @user, as: :json

        assert_response :success
        assert_not_nil(response.parsed_body["last_logged_in_at"])
      end

      should "show the last_ip_addr to mods" do
        user = create(:user, last_ip_addr: "1.2.3.4")
        get_auth user_path(user), create(:mod_user), as: :json

        assert_response :success
        assert_equal("1.2.3.4", response.parsed_body["last_ip_addr"])
      end

      should "not show hidden attributes to others" do
        @another = create(:user)

        get_auth user_path(@another), @user, as: :json

        assert_response :success
        assert_nil(response.parsed_body["last_logged_in_at"])
        assert_nil(response.parsed_body["last_ip_addr"])
      end

      should "strip '?' from attributes" do
        get_auth user_path(@user), @user, params: {format: :xml}
        xml = Hash.from_xml(response.body)

        assert_response :success
        assert_equal(false, xml["user"]["enable_safe_mode"])
      end

      context "for a user with an email address" do
        setup do
          create(:email_address, user: @user)
        end

        should "show the email address to the user themselves" do
          get_auth user_path(@user), @user

          assert_response :success
          assert_select ".user-email-address", count: 1
        end

        should "show the email address to mods" do
          get_auth user_path(@user), create(:moderator_user)

          assert_response :success
          assert_select ".user-email-address", count: 1
        end

        should "not show the email address to other users" do
          get_auth user_path(@user), create(:user)

          assert_response :success
          assert_select ".user-email-address", count: 0
        end
      end

      context "for a tooltip" do
        setup do
          @banned = create(:banned_user)
          @admin = create(:admin_user)
          @member = create(:user)
          @feedback = create(:user_feedback, user: @member, category: :positive)
        end

        should "render for a banned user" do
          get_auth user_path(@banned, variant: "tooltip"), @user

          assert_response :success
        end

        should "render for a member" do
          get_auth user_path(@member, variant: "tooltip"), @user
          assert_response :success

          get_auth user_path(@member, variant: "tooltip"), @admin
          assert_response :success
        end

        should "render for an admin" do
          get_auth user_path(@admin, variant: "tooltip"), @user
          assert_response :success
        end
      end
    end

    context "profile action" do
      should "render the current user's profile" do
        get_auth profile_path, @user

        assert_response :success
        assert_select "#page h1", @user.name
      end

      should "render the current users's profile in json" do
        get_auth profile_path, @user, as: :json
        assert_response :success

        assert_equal(@user.comments.count, response.parsed_body["comment_count"])
      end

      should "redirect anonymous users to the sign in page" do
        get profile_path
        assert_redirected_to login_path(url: "/profile")
      end

      should "redirect `Accept: */*` requests to the sign in page" do
        get profile_path, headers: { Accept: "*/*" }
        assert_redirected_to login_path(url: "/profile")
      end

      should "return success for anonymous api calls" do
        get profile_path(format: :json)
        assert_response :success
      end
    end

    context "new action" do
      should "render" do
        get new_user_path
        assert_response :success
      end

      should "render for a logged in user" do
        get_auth new_user_path, @user
        assert_response :success
      end

      should "render when captchas are enabled" do
        Danbooru.config.unstub(:captcha_site_key)
        Danbooru.config.unstub(:captcha_secret_key)
        skip unless CaptchaService.new.enabled?

        get new_user_path
        assert_response :success
      end
    end

    context "create action" do
      should "create a user" do
        post users_path, params: { user: { name: "xxx", password: "xxxxx1", password_confirmation: "xxxxx1" }}

        assert_redirected_to User.last
        assert_equal("xxx", User.last.name)
        assert_equal(User::Levels::MEMBER, User.last.level)
        assert_equal(User.last, User.last.authenticate_password("xxxxx1"))
        assert_nil(User.last.email_address)
        assert_equal(true, User.last.user_events.user_creation.exists?)

        perform_enqueued_jobs
        assert_performed_jobs(1, only: MailDeliveryJob)
        # assert_enqueued_email_with UserMailer.with_request(request), :welcome_user, args: [User.last], queue: "default"
      end

      should "create a user with a valid email" do
        post users_path, params: { user: { name: "xxx", password: "xxxxx1", password_confirmation: "xxxxx1", email_address: "webmaster@danbooru.donmai.us" }}

        assert_redirected_to User.last
        assert_equal("xxx", User.last.name)
        assert_equal(User.last, User.last.authenticate_password("xxxxx1"))
        assert_equal("webmaster@danbooru.donmai.us", User.last.email_address.address)
        assert_equal(true, User.last.user_events.user_creation.exists?)

        perform_enqueued_jobs
        assert_performed_jobs(1, only: MailDeliveryJob)
        # assert_enqueued_email_with UserMailer.with_request(request), :welcome_user, args: [User.last], queue: "default"
      end

      should "not create a user with an invalid email" do
        assert_no_difference(["User.count", "EmailAddress.count"]) do
          post users_path, params: { user: { name: "xxx", password: "xxxxx1", password_confirmation: "xxxxx1", email_address: "test" }}

          assert_response :success
          assert_no_enqueued_emails
        end
      end

      should "not create a user with an undeliverable email address" do
        assert_no_difference(["User.count", "EmailAddress.count"]) do
          post users_path, params: { user: { name: "xxx", password: "xxxxx1", password_confirmation: "xxxxx1", email_address: "nobody@nothing.donmai.us" } }

          assert_response :success
          assert_no_enqueued_emails
        end
      end

      context "with a dummy captcha key" do
        should "not create a user if the captcha response is invalid" do
          # https://developers.cloudflare.com/turnstile/reference/testing/#dummy-sitekeys-and-secret-keys
          Danbooru.config.stubs(:captcha_site_key).returns("3x00000000000000000000FF") # forces an interactive challenge
          Danbooru.config.stubs(:captcha_secret_key).returns("2x0000000000000000000000000000000AA") # always fails

          assert_no_difference(["User.count"]) do
            post users_path, params: { user: { name: "xxx", password: "xxxxx1", password_confirmation: "xxxxx1" }, "cf-turnstile-response": "blah" }

            assert_response :success
          end
        end

        should "create a user if the captcha response is valid" do
          Danbooru.config.stubs(:captcha_site_key).returns("3x00000000000000000000FF") # forces an interactive challenge
          Danbooru.config.stubs(:captcha_secret_key).returns("1x0000000000000000000000000000000AA") # always passes

          post users_path, params: { user: { name: "xxx", password: "xxxxx1", password_confirmation: "xxxxx1" }, "cf-turnstile-response": "blah" }
          assert_redirected_to User.last
          assert_equal("xxx", User.last.name)
        end
      end

      context "with a live captcha key" do
        setup do
          Danbooru.config.unstub(:captcha_site_key, :captcha_secret_key)
          skip unless CaptchaService.new.enabled?
        end

        should "not create a user if the captcha response is missing" do
          assert_no_difference(["User.count"]) do
            post users_path, params: { user: { name: "xxx", password: "xxxxx1", password_confirmation: "xxxxx1" } }

            assert_response :success
          end
        end

        should "not create a user if the captcha response is invalid" do
          assert_no_difference(["User.count"]) do
            post users_path, params: { user: { name: "xxx", password: "xxxxx1", password_confirmation: "xxxxx1" }, "cf-turnstile-response": "blah" }

            assert_response :success
          end
        end
      end

      context "sockpuppet detection" do
        setup do
          @private_ip = "192.168.0.1"
          @valid_ip = "187.37.226.17" # a random valid, non-proxy public IP
          @valid_ipv6 = "2600:1700:6b0:a518::1"
          @proxy_ip = "51.15.128.1"
        end

        should "work for a public IPv6 address" do
          self.remote_addr = @valid_ipv6

          post users_path, params: { user: { name: "xxx", password: "xxxxx1", password_confirmation: "xxxxx1" }}

          assert_redirected_to User.last
          assert_equal(true, User.last.is_member?)
          assert_equal(false, User.last.is_restricted?)
          assert_equal(false, User.last.requires_verification)
          assert_equal(true, User.last.user_events.user_creation.exists?)
        end

        should "mark accounts created by already logged in users as restricted" do
          self.remote_addr = @valid_ip

          post_auth users_path, @user, params: { user: { name: "xxx", password: "xxxxx1", password_confirmation: "xxxxx1" }}

          assert_redirected_to User.last
          assert_equal(false, User.last.is_member?)
          assert_equal(true, User.last.is_restricted?)
          assert_equal(true, User.last.requires_verification)
          assert_equal(true, User.last.user_events.user_creation.exists?)
        end

        should "mark users signing up from proxies as restricted" do
          skip "IP Registry credentials not configured" unless IpLookup.enabled?
          self.remote_addr = @proxy_ip

          post users_path, params: { user: { name: "xxx", password: "xxxxx1", password_confirmation: "xxxxx1" }}

          assert_redirected_to User.last
          assert_equal(false, User.last.is_member?)
          assert_equal(true, User.last.is_restricted?)
          assert_equal(true, User.last.requires_verification)
          assert_equal(true, User.last.user_events.user_creation.exists?)
        end

        should "mark users signing up from a partial banned IP as restricted" do
          self.remote_addr = @valid_ip

          @ip_ban = create(:ip_ban, ip_addr: self.remote_addr, category: :partial)
          post users_path, params: { user: { name: "xxx", password: "xxxxx1", password_confirmation: "xxxxx1" }}

          assert_redirected_to User.last
          assert_equal(false, User.last.is_member?)
          assert_equal(true, User.last.is_restricted?)
          assert_equal(true, User.last.requires_verification)
          assert_equal(1, @ip_ban.reload.hit_count)
          assert(@ip_ban.last_hit_at > 1.minute.ago)
          assert_equal(true, User.last.user_events.user_creation.exists?)
        end

        should "not mark users signing up from non-proxies as restricted" do
          skip "IP Registry credentials not configured" unless IpLookup.enabled?
          self.remote_addr = @valid_ip

          post users_path, params: { user: { name: "xxx", password: "xxxxx1", password_confirmation: "xxxxx1" }}

          assert_redirected_to User.last
          assert_equal(true, User.last.is_member?)
          assert_equal(false, User.last.is_restricted?)
          assert_equal(false, User.last.requires_verification)
          assert_equal(true, User.last.user_events.user_creation.exists?)
        end

        should "mark accounts registered from an IPv4 address recently used for another account as restricted" do
          @user.update!(last_ip_addr: @valid_ip)
          self.remote_addr = @valid_ip

          post users_path, params: { user: { name: "dupe", password: "xxxxx1", password_confirmation: "xxxxx1" }}

          assert_redirected_to User.last
          assert_equal(false, User.last.is_member?)
          assert_equal(true, User.last.is_restricted?)
          assert_equal(true, User.last.requires_verification)
          assert_equal(true, User.last.user_events.user_creation.exists?)
        end

        should "not mark users signing up from localhost as restricted" do
          self.remote_addr = "127.0.0.1"

          post users_path, params: { user: { name: "xxx", password: "xxxxx1", password_confirmation: "xxxxx1" }}

          assert_redirected_to User.last
          assert_equal(true, User.last.is_member?)
          assert_equal(false, User.last.is_restricted?)
          assert_equal(false, User.last.requires_verification)
          assert_equal(true, User.last.user_events.user_creation.exists?)
        end
      end
    end

    context "edit action" do
      should "render" do
        get_auth edit_user_path(@user), @user
        assert_response :success
      end
    end

    context "settings action" do
      should "render" do
        get_auth settings_path, @user

        assert_response :success
        assert_select "#page h1", "Settings"
      end

      should "redirect anonymous users to the sign in page" do
        get settings_path
        assert_redirected_to login_path(url: "/settings")
      end
    end

    context "update action" do
      should "update a user" do
        put_auth user_path(@user), @user, params: {:user => {:favorite_tags => "xyz"}}
        @user.reload
        assert_equal("xyz", @user.favorite_tags)
      end

      context "changing the level" do
        should "not work" do
          @owner = create(:owner_user)
          put_auth user_path(@user), @owner, params: { user: { level: User::Levels::BUILDER }}

          assert_response 403
          assert_equal(User::Levels::MEMBER, @user.reload.level)
        end
      end

      context "for a banned user" do
        should "allow the user to edit their settings" do
          @user = create(:banned_user)
          put_auth user_path(@user), @user, params: {:user => {:favorite_tags => "xyz"}}

          assert_equal("xyz", @user.reload.favorite_tags)
        end
      end
    end
  end
end

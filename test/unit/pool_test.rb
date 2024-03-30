require 'test_helper'

class PoolTest < ActiveSupport::TestCase
  setup do
    travel_to(1.month.ago) do
      @user = FactoryBot.create(:user)
      CurrentUser.user = @user
    end
  end

  teardown do
    CurrentUser.user = nil
  end

  context "Searching pools" do
    should "find pools by name" do
      @pool = FactoryBot.create(:pool, name: "Test Pool")
      @pool2 = create(:pool, name: "Yuru_Yuri_-_\\\\Akarin!!//")

      assert_equal(@pool.id, Pool.find_by_name("test pool").id)

      assert_search_equals(@pool, name_contains: "test pool")
      assert_search_equals(@pool, name_contains: "tes")
      assert_search_equals(@pool, name_matches: "test pool")
      assert_search_equals(@pool, name_matches: "testing pool")
      assert_search_equals([], name_matches: "tes")

      assert_search_equals(@pool2, name_contains: "Yuru_Yuri_-_\\\\Akarin!!//")
      assert_search_equals(@pool2, name_matches: "Yuru_Yuri_-_\\\\Akarin!!//")
    end

    should "find pools by post id" do
      @pool1 = create(:pool, name: "pool1")
      @pool2 = create(:pool, name: "pool2")
      @post1 = create(:post, tag_string: "pool:pool1")
      @post2 = create(:post, tag_string: "pool:pool2")

      assert_search_equals(@pool1, post_ids_include_any: @post1.id)
      assert_search_equals([@pool2, @pool1], post_ids_include_any: "#{@post1.id} #{@post2.id}")
    end

    should "find pools by post id count" do
      @pool1 = create(:pool, name: "pool1")
      @pool2 = create(:pool, name: "pool2")
      @post1 = create(:post, tag_string: "pool:pool1")
      @post2 = create(:post, tag_string: "pool:pool1")

      assert_search_equals(@pool1, post_id_count: 2)
    end

    should "find pools by post tags" do
      @pool1 = create(:pool, name: "pool1")
      @pool2 = create(:pool, name: "pool2")
      @post1 = create(:post, tag_string: "pool:pool1 bkub")
      @post2 = create(:post, tag_string: "pool:pool1 fumimi")
      @post3 = create(:post, tag_string: "pool:pool2 bkub fumimi")

      assert_search_equals([@pool2, @pool1], post_tags_match: "bkub")
      assert_search_equals([@pool2, @pool1], post_tags_match: "fumimi")
      assert_search_equals(@pool2, post_tags_match: "bkub fumimi")

      assert_equal(2, Pool.search({ post_tags_match: "bkub" }, current_user: User.anonymous).count)
      assert_equal(2, Pool.search({ post_tags_match: "fumimi" }, current_user: User.anonymous).count)
      assert_equal(1, Pool.search({ post_tags_match: "bkub fumimi" }, current_user: User.anonymous).count)
    end
  end

  context "Creating a pool" do
    setup do
      @posts = FactoryBot.create_list(:post, 5)
      @pool = FactoryBot.create(:pool, post_ids: @posts.map(&:id))
    end

    should "initialize the post count" do
      assert_equal(@posts.size, @pool.post_count)
    end
  end

  context "Reverting a pool" do
    setup do
      @p1 = create(:post)
      @p2 = create(:post)
      @u1 = create(:user, created_at: 1.month.ago)
      @u2 = create(:user, created_at: 1.month.ago)

      @pool = create(:pool)
      as(@u1) { @pool.add!(@p1) }
      as(@u2) { @pool.add!(@p2) }
    end

    should "have the correct versions" do
      assert_equal(3, @pool.reload.versions.size)
      assert_equal([], @pool.versions[0].post_ids)
      assert_equal([@p1.id], @pool.versions[1].post_ids)
      assert_equal([@p1.id, @p2.id], @pool.versions[2].post_ids)
      assert_equal([@p1.id, @p2.id], @pool.reload.post_ids)
    end

    should "update its post_ids" do
      @pool.revert_to!(@pool.versions[1])
      assert_equal([@p1.id], @pool.post_ids)

      @pool.revert_to!(@pool.versions[0])
      assert_equal([], @pool.reload.post_ids)
    end
  end

  context "Updating a pool" do
    setup do
      @pool = FactoryBot.create(:pool, category: "series")
      @p1 = FactoryBot.create(:post)
      @p2 = FactoryBot.create(:post)
    end

    context "by adding a new post" do
      setup do
        @pool.add!(@p1)
      end

      context "by #attributes=" do
        setup do
          @pool.attributes = {post_ids: [@p1.id, @p2.id]}
          @pool.save
        end

        should "initialize the post count" do
          assert_equal(2, @pool.post_count)
        end
      end

      should "add the post to the pool" do
        assert_equal([@p1.id], @pool.post_ids)
      end

      should "increment the post count" do
        assert_equal(1, @pool.post_count)
      end

      context "to a pool that already has the post" do
        setup do
          @pool.add!(@p1)
        end

        should "not double add the post to the pool" do
          assert_equal([@p1.id], @pool.post_ids)
        end

        should "not double increment the post count" do
          assert_equal(1, @pool.post_count)
        end
      end

      context "to a deleted pool" do
        setup do
          # must be a builder to update deleted pools.
          CurrentUser.user = FactoryBot.create(:builder_user)

          @pool.update_attribute(:is_deleted, true)
          @pool.post_ids += [@p2.id]
          @pool.save
          @pool.reload
          @p2.reload
        end

        should "add the post to the pool" do
          assert_equal([@p1.id, @p2.id], @pool.post_ids)
        end

        should "increment the post count" do
          assert_equal(2, @pool.post_count)
        end
      end
    end

    context "by removing a post" do
      setup do
        @pool.add!(@p1)
      end

      context "that is in the pool" do
        setup do
          @pool.remove!(@p1)
        end

        should "remove the post from the pool" do
          assert_equal([], @pool.post_ids)
        end

        should "update the post count" do
          assert_equal(0, @pool.post_count)
        end
      end

      context "that is not in the pool" do
        setup do
          @pool.remove!(@p2)
        end

        should "not affect the pool" do
          assert_equal([@p1.id], @pool.post_ids)
        end

        should "not affect the post count" do
          assert_equal(1, @pool.post_count)
        end
      end
    end

    should "create new versions for each distinct user" do
      assert_equal(1, @pool.versions.size)

      user2 = create(:user)
      as(user2) { @pool.update!(post_ids: [@p1.id]) }
      assert_equal(2, @pool.reload.versions.size)
      assert_equal(user2.id, @pool.versions.last.updater_id)

      user3 = create(:user)
      as(user3) { @pool.update!(post_ids: [@p1.id, @p2.id]) }
      assert_equal(3, @pool.reload.versions.size)
      assert_equal(user3.id, @pool.versions.last.updater_id)
    end

    should "should create a version if the name changes" do
      as(create(:user)) { @pool.update!(name: "blah") }
      assert_equal("blah", @pool.versions.last.name)
      assert_equal(2, @pool.versions.size)
    end

    should "know what its post ids were previously" do
      @pool.post_ids = [@p1.id]
      assert_equal([], @pool.post_ids_was)
    end

    should "normalize its name" do
      @pool.update(:name => "  A  B  ")
      assert_equal("A_B", @pool.name)

      @pool.update(:name => "__A__B__")
      assert_equal("A_B", @pool.name)
    end

    should "not allow duplicate posts" do
      @pool.update(category: "collection", post_ids: [1, 2, 2, 3, 1])
      assert_equal([1, 2, 3], @pool.post_ids)

      @pool.update(category: "series", post_ids: [1, 2, 2, 3, 1])
      assert_equal([1, 2, 3], @pool.post_ids)
    end

    context "when validating names" do
      should_not allow_value("foo,bar").for(:name)
      should_not allow_value("foo*bar").for(:name)
      should_not allow_value("123").for(:name)
      should_not allow_value("any").for(:name)
      should_not allow_value("none").for(:name)
      should_not allow_value("series").for(:name)
      should_not allow_value("collection").for(:name)
      should_not allow_value("___").for(:name)
      should_not allow_value("   ").for(:name)
      should_not allow_value("\u200B").for(:name)
      should_not allow_value("").for(:name)
    end
  end

  context "An existing pool" do
    setup do
      @pool = FactoryBot.create(:pool)
      @p1 = FactoryBot.create(:post)
      @p2 = FactoryBot.create(:post)
      @p3 = FactoryBot.create(:post)
      @pool.add!(@p1)
      @pool.add!(@p2)
      @pool.add!(@p3)
    end

    should "find the neighbors for the first post" do
      assert_nil(@pool.previous_post_id(@p1.id))
      assert_equal(@p2.id, @pool.next_post_id(@p1.id))
    end

    should "find the neighbors for the middle post" do
      assert_equal(@p1.id, @pool.previous_post_id(@p2.id))
      assert_equal(@p3.id, @pool.next_post_id(@p2.id))
    end

    should "find the neighbors for the last post" do
      assert_equal(@p2.id, @pool.previous_post_id(@p3.id))
      assert_nil(@pool.next_post_id(@p3.id))
    end
  end
end

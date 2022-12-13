# frozen_string_literal: true

module Discord
  module Events
    def self.respond(name, regex, &block)
      @@messages ||= []
      @@messages << [name, regex]

      define_method(:"do_#{name}") do |event|
        matches = event.text.scan(/(?<!`)#{regex}(?!`)/)

        matches.each do |match|
          instance_exec(event, match, &block)
        end

        nil
      end
    end

    def self.respond_to_id(model, shortlink = nil)
      shortlink ||= model.name.to_s.split("::").last.underscore
      respond(:"#{shortlink}_id", /#{shortlink.tr("_", " ")} #[0-9]+/i) do |event, text|
        subject = model.find_by_id(text[/[0-9]+/].to_i)
        subject.send_embed(event.channel) if subject.present?
      end
    end

    respond_to_id Post
    respond_to_id ForumTopic, "topic"
    respond_to_id ForumPost, "forum"

    respond(:wiki_link, /\[\[ [^\]]+ \]\]/x) do |event, text|
      title = text[/[^\[\]]+/]

      event.channel.start_typing
      WikiPage.find_by_title(title).send_embed(event.channel)
    end

    respond(:search_link, /{{ [^\}]+ }}/x) do |event, text|
      search = text[/[^{}]+/]

      event.channel.start_typing
      posts = Post.anon_tag_match(search).limit(3)

      posts.each do |post|
        post.send_embed(event.channel)
      end
    end

    def do_eval(event, *args)
      return unless event.user.id == event.bot.bot_application.owner.id

      code = args.join(" ")
      result = instance_eval(code)
      event << "```\n#{result.inspect}```"
    end
  end

  class Bot
    include Discord::Events

    attr_reader :initiate_shutdown

    def initialize(bot_token = Danbooru.config.discord_bot_token, client_id = Danbooru.config.discord_application_client_id, guild_id = Danbooru.config.discord_guild_id)
      @guild_id = guild_id
      @bot = Discordrb::Commands::CommandBot.new(
        name: "AIBooru",
        token: bot_token,
        client_id: client_id,
        prefix: "!",
      )

      register_commands
    end

    def register_commands
      @bot.command(:eval, &method(:do_eval))

      @@messages.each do |name, regex|
        @bot.message(contains: regex, &method(:"do_#{name}"))
      end
    end

    def run
      @bot.run(:async)

      loop do
        shutdown! if initiate_shutdown
        sleep 1
      end
    end
  end
end

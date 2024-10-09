require "securerandom"

User.create(
  name: Danbooru.config.system_user,
  password: SecureRandom.base64(32),
  level: User::Levels::MODERATOR,
  show_niche_posts: true,
  show_deleted_posts: true,
)

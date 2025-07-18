# Be sure to restart your server when you modify this file.

# Add new inflection rules using the following format. Inflections
# are locale specific, and you may define rules for as many different
# locales as you wish. All of these examples are active by default:
ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.uncountable "general"
  inflect.acronym "FFmpeg"
  inflect.acronym "URL"
  inflect.acronym "URLs"
  inflect.acronym "AST"
  inflect.acronym "AI"
  inflect.acronym "SFTP"
  inflect.acronym "TOTP"
  inflect.acronym "VAE"
  inflect.acronym "UI"
  inflect.acronym "RNG"
  inflect.acronym "JSON"
  inflect.uncountable ["totp"]
#   inflect.plural /^(ox)$/i, '\1en'
#   inflect.singular /^(ox)en/i, '\1'
#   inflect.irregular 'person', 'people'
#   inflect.uncountable %w( fish sheep )
end

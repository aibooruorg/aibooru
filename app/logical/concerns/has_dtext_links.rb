# frozen_string_literal: true

module HasDtextLinks
  extend ActiveSupport::Concern

  class_methods do
    # Declare a field that has DText links. Any wiki links or external links
    # contained in this field will be saved in the dtext_links table whenever
    # the field is updated. This allows finding wiki pages, forum posts, and
    # pool descriptions linking to a given tag.
    #
    # @param attribute [Symbol] the name of the DText field.
    def has_dtext_links(attribute)
      has_many :dtext_links, as: :model, dependent: :destroy
      before_save :update_dtext_links, if: :dtext_links_changed?

      define_method(:dtext_links_changed?) do
        old_dtext = DText.new(self[attribute])
        new_dtext = DText.new(attribute_was(attribute))

        attribute_changed?(attribute) && old_dtext.links_differ?(new_dtext)
      end

      define_method(:update_dtext_links) do
        self.dtext_links = DtextLink.new_from_dtext(self[attribute])
      end
    end

    # Return pages (e.g. wikis, forum posts, pool descriptions) that link to the given wiki page.
    def linked_to(title)
      where(dtext_links: DtextLink.where(model_type: name).wiki_link.where(link_target: WikiPage.normalize_title(title)))
    end

    # Return pages that don't link to the given wiki page.
    def not_linked_to(title)
      where.not(dtext_links: DtextLink.where(model_type: name).wiki_link.where(link_target: WikiPage.normalize_title(title)))
    end
  end
end

class ChangeDefaultAccentAndBimPrimaryColor < ActiveRecord::Migration[7.1]
  class MigrationDesignColor < ApplicationRecord
    self.table_name = "design_colors"
  end

  def up
    # The default Bim value was forgotten in previous migrations
    primary_button_color = MigrationDesignColor.find_by(variable: "primary-button-color")
    if primary_button_color&.hexcode == OpenProject::CustomStyles::ColorThemes::DEPRECATED_BIM_ALTERNATIVE_COLOR
      primary_button_color.update(hexcode: OpenProject::CustomStyles::ColorThemes::PRIMER_PRIMARY_BUTTON_COLOR)
    end

    # When merging the old "primary" and "link" color into the new "accent" color,
    # it was forgotten to use the value of "primary" for it.
    accent_color = MigrationDesignColor.find_by(variable: "accent-color")
    if accent_color&.hexcode == OpenProject::CustomStyles::ColorThemes::DEPRECATED_LINK_COLOR
      accent_color.update(hexcode: OpenProject::CustomStyles::ColorThemes::DEPRECATED_PRIMARY_COLOR)
    end
  end

  def down
    primary_button_color = MigrationDesignColor.find_by(variable: "primary-button-color")
    if primary_button_color&.hexcode == OpenProject::CustomStyles::ColorThemes::PRIMER_PRIMARY_BUTTON_COLOR
      primary_button_color.update(hexcode: OpenProject::CustomStyles::ColorThemes::DEPRECATED_BIM_ALTERNATIVE_COLOR)
    end

    accent_color = MigrationDesignColor.find_by(variable: "accent-color")
    if accent_color&.hexcode == OpenProject::CustomStyles::ColorThemes::DEPRECATED_PRIMARY_COLOR
      accent_color.update(hexcode: OpenProject::CustomStyles::ColorThemes::DEPRECATED_LINK_COLOR)
    end
  end
end

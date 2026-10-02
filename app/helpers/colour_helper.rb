module ColourHelper
  def colour(colour_name)
    Colourable.colour_variable_of(colour_name)
  end

  def colour_bg(colour_name)
    Colourable.colour_bg_variable_of(colour_name)
  end

  def collection_tint_style(collection)
    return if collection.colour.blank?

    %( style="--collection-color: #{colour(collection.colour)}; --collection-bg: #{colour_bg(collection.colour)};").html_safe
  end
end

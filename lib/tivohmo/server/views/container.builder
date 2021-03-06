xml.TiVoContainer do

  paginated_children = children[item_start, item_count]

  xml.ItemStart item_start
  xml.ItemCount paginated_children.size

  xml.Details do
    xml.Title container.title_path
    xml.ContentType "x-tivo-container/folder"
    xml.SourceFormat "x-tivo-container/folder"
    xml.TotalItems children.size
    xml.UniqueId format_uuid(container.uuid)
  end

  paginated_children.each do |child|
    if child.is_a?(TivoHMO::API::Container)
      builder :_container, layout: false, locals: { xml: xml, container: child }
    elsif child.is_a?(TivoHMO::API::Item)
      builder :_item, layout: false, locals: { xml: xml, item: child }
    else
      raise "Invalid child, needs to be item or container"
    end
  end

end

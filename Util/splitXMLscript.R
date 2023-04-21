library(XML)

# Read in the large XML file
xml_file <- "pubmedXML.xml"
doc <- xmlParse(xml_file)

# Find all elements of a certain type (e.g., articles)
article_nodes <- getNodeSet(doc, "//Article")

# Split the nodes into chunks of a specified size
chunk_size <- 1000
chunks <- split(article_nodes, ceiling(seq_along(article_nodes) / chunk_size))

# Write each chunk to a new file
for (i in seq_along(chunks)) {
  chunk <- chunks[[i]]
  output_file <- paste0("xml_chunk_", i, ".xml")
  
  # Create a new XML document for the chunk
  chunk_doc <- newXMLDoc()
  root_node <- newXMLNode("Publications", doc = chunk_doc)
  
  # Add the nodes in the chunk to the new document
  for (node in chunk) {
    addChildren(root_node, node)
  }
  
  # Save the new document
  saveXML(chunk_doc, file = output_file)
}

split_xml_file <- function(xml_dir, xml_file, element_type, chunk_size) {
  # Concatenate the directory path and XML filename
  xml_path <- file.path(xml_dir, xml_file)
  
  # Read in the large XML file
  doc <- xmlParse(xml_path)
  
  # Find all elements of a certain type
  nodes <- getNodeSet(doc, element_type)
  
  # Split the nodes into chunks of a specified size
  chunks <- split(nodes, ceiling(seq_along(nodes) / chunk_size))
  
  # Write each chunk to a new file
  for (i in seq_along(chunks)) {
    chunk <- chunks[[i]]
    output_file <- paste0("xml_chunk_", i, ".xml")
    
    # Create a new XML document for the chunk
    chunk_doc <- newXMLDoc()
    root_node <- newXMLNode("Publications", doc = chunk_doc)
    
    # Add the nodes in the chunk to the new document
    for (node in chunk) {
      addChildren(root_node, node)
    }
    
    # Save the new document
    saveXML(chunk_doc, file.path(xml_dir, output_file))
  }
}

library(XML)

split_xml_file <- function(base_dir, xml_file, element_type, chunk_size) {
  # Read in the large XML file
  doc <- xmlParse(xml_file)
  
  # Find all elements of a certain type
  nodes <- getNodeSet(doc, element_type)
  
  # Split the nodes into chunks of a specified size
  chunks <- split(nodes, ceiling(seq_along(nodes) / chunk_size))
  
  # Create the Chunks directory if it doesn't exist
  chunks_dir <- file.path(base_dir, "Chunks")
  if (!dir.exists(chunks_dir)) {
    dir.create(chunks_dir)
  }
  
  # Create a progress bar
  total_chunks <- length(chunks)
  pb <- txtProgressBar(min = 0, max = total_chunks, style = 3)
  
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
    saveXML(chunk_doc, file.path(chunks_dir, output_file))
    
    # Update the progress bar
    setTxtProgressBar(pb, i)
  }
  
  # Close the progress bar
  close(pb)
}

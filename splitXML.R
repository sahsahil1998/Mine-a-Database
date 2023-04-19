library(xml2)

# Read in the large XML file
xml_file <- "large_xml_file.xml"
doc <- read_xml(xml_file)

# Find all elements of a certain type (e.g., articles)
article_nodes <- xml_find_all(doc, "//article")

# Split the nodes into chunks of a specified size
chunk_size <- 1000
chunks <- split(article_nodes, ceiling(seq_along(article_nodes) / chunk_size))

# Write each chunk to a new file
for (i in seq_along(chunks)) {
  chunk <- chunks[[i]]
  output_file <- paste0("xml_chunk_", i, ".xml")
  write_xml(chunk, output_file)
}

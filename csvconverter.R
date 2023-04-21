
# UTILS 
#################################START##########################################

# Install and load required packages
packages <- c("xml2", "dplyr", "readr")
for (pkg in packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    install.packages(pkg)
  }
  library(pkg, character.only = TRUE)
}

#################################END############################################


# Convert XML into CSV for easier processing
#################################START##########################################


# Function to parse articles
parse_article <- function(article) {
  pmid <- xml_attr(article, "PMID")
  pub_details <- xml_find_first(article, ".//PubDetails")
  
  journal <- xml_find_first(pub_details, ".//Journal")
  issn <- xml_text(xml_find_first(journal, ".//ISSN"))
  title <- xml_text(xml_find_first(journal, ".//Title"))
  iso_abbreviation <- xml_text(xml_find_first(journal, ".//ISOAbbreviation"))
  
  article_title <- xml_text(xml_find_first(pub_details, ".//ArticleTitle"))
  
  author_list <- xml_find_first(pub_details, ".//AuthorList")
  authors <- xml_find_all(author_list, ".//Author")
  author_data <- lapply(authors, function(author) {
    last_name <- xml_text(xml_find_first(author, ".//LastName"))
    fore_name <- xml_text(xml_find_first(author, ".//ForeName"))
    initials <- xml_text(xml_find_first(author, ".//Initials"))
    paste(last_name, fore_name, initials, sep = ", ")
  })
  
  pub_date <- xml_find_first(journal, ".//PubDate")
  year <- xml_text(xml_find_first(pub_date, ".//Year"))
  season <- xml_text(xml_find_first(pub_date, ".//Season"))
  month <- xml_text(xml_find_first(pub_date, ".//Month"))
  day <- xml_text(xml_find_first(pub_date, ".//Day"))
  
  data.frame(PMID = pmid,
             ISSN = issn,
             JournalTitle = title,
             ISOAbbreviation = iso_abbreviation,
             ArticleTitle = article_title,
             Authors = paste(author_data, collapse = "; "),
             Year = year,
             Month = month,
             Day = day,
             stringsAsFactors = FALSE)
}

# Function to parse an XML file into a data.frame
parse_xml_file <- function(xml_file) {
  xml_data <- read_xml(xml_file)
  articles <- xml_find_all(xml_data, ".//Article")
  do.call(rbind, lapply(articles, parse_article))
}



# Function to write the parsed XML data to a CSV file
write_article_csv <- function(output_file, xml_files) {
  # Remove the output file if it already exists
  if (file.exists(output_file)) {
    file.remove(output_file)
  }
  
  for (i in seq_along(xml_files)) {
    chunk <- parse_xml_file(xml_files[i])
    write_csv(chunk, output_file, append = i > 1)
  }
}

#################################END############################################




# UTILS 
#################################START##########################################
install.packages("xml2")
install.packages("dplyr")
install.packages("readr")
install.packages("pbapply")
install.packages("tidyr")
install.packages("RSQLite")


library(tidyr)
library(xml2)
library(dplyr)
library(readr)
library(pbapply)
library(RSQLite)
#################################END############################################


# Convert XML into CSV for easier processing
#################################START##########################################

# Define a function to parse a single XML file and return the result as a data.frame
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


# Define a function to write the parsed XML data to a CSV file
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

# Generate the file paths for the XML chunks
base_path <- "C:/Users/vknya/OneDrive/Documents/School/Northeastern/CS 5200/Practicum 2/Mine-a-Database/chunks/"
xml_files <- paste0(base_path, "xml_chunk_", 1:30, ".xml")

# Write to a single CSV file
output_file <- "combined_articles.csv"

# Write the parsed XML data to a CSV file
write_article_csv(output_file, xml_files)
#################################END############################################




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


# Extract date function to get date or medline of article
extract_date <- function(pub_date_node) {
  year <- xml2::xml_find_first(pub_date_node, ".//Year") %>% xml2::xml_text(trim = TRUE)
  month <- xml2::xml_find_first(pub_date_node, ".//Month") %>% xml2::xml_text(trim = TRUE)
  day <- xml2::xml_find_first(pub_date_node, ".//Day") %>% xml2::xml_text(trim = TRUE)
  medline_date <- xml2::xml_find_first(pub_date_node, ".//MedlineDate") %>% xml2::xml_text(trim = TRUE)
  
  if (is.na(medline_date) || medline_date == "") {
    date_string <- paste(year, month, day, sep = "-")
  } else {
    date_string <- medline_date
  }
  
  return(date_string)
}


# Function to parse articles
parse_article <- function(article) {
  pmid <- xml_attr(article, "PMID")
  pub_details <- xml_find_first(article, ".//PubDetails")
  
  journal <- xml_find_first(pub_details, ".//Journal")
  issn_node <- xml_find_first(journal, ".//ISSN")
  issn <- xml_text(issn_node)
  issn_type <- xml_attr(issn_node, "IssnType")
  title <- xml_text(xml_find_first(journal, ".//Title"))
  iso_abbreviation <- xml_text(xml_find_first(journal, ".//ISOAbbreviation"))
  
  author_list <- xml_find_first(pub_details, ".//AuthorList")
  authors <- xml_find_all(author_list, ".//Author")
  author_data <- lapply(authors, function(author) {
    last_name <- xml_text(xml_find_first(author, ".//LastName"))
    fore_name <- xml_text(xml_find_first(author, ".//ForeName"))
    initials <- xml_text(xml_find_first(author, ".//Initials"))
    suffix <- xml_text(xml_find_first(author, ".//Suffix"))
    paste(last_name, fore_name, initials, suffix, sep = ", ")
  })
  
  journal_issue <- xml_find_first(journal, ".//JournalIssue")
  volume <- xml_text(xml_find_first(journal_issue, ".//Volume"))
  issue <- xml_text(xml_find_first(journal_issue, ".//Issue"))
  
  pub_date <- xml_find_first(journal, ".//PubDate")
  year <- xml_text(xml_find_first(pub_date, ".//Year"))
  season <- xml_text(xml_find_first(pub_date, ".//Season"))
  month <- xml_text(xml_find_first(pub_date, ".//Month"))
  day <- xml_text(xml_find_first(pub_date, ".//Day"))
  
  # Check if year is empty or NA, then parse MedlineDate
  if (is.na(year) || year == "") {
    medline_date <- xml_text(xml_find_first(pub_date, ".//MedlineDate"))
    if (medline_date != "") {
      medline_date_parts <- strsplit(medline_date, " ")[[1]]
      year <- medline_date_parts[1]
      if (length(medline_date_parts) > 2) {
        month <- medline_date_parts[2]
      } else if (grepl("-", year)) {
        year_parts <- strsplit(year, "-")[[1]]
        year <- year_parts[1]
      }
    }
  }
  
  data.frame(PMID = pmid,
             ISSN = issn,
             IssnType = issn_type,
             JournalTitle = title,
             ISOAbbreviation = iso_abbreviation,
             ArticleTitle = article_title,
             Authors = paste(author_data, collapse = "; "),
             Year = year,
             Month = month,
             Day = day,
             Volume = volume,
             Issue = issue,
             stringsAsFactors = FALSE)
}



# Define a function to parse an XML file into a data.frame
parse_xml_file <- function(xml_file) {
  xml_data <- read_xml(xml_file)
  articles <- xml_find_all(xml_data, ".//Article")
  
  result <- do.call(rbind, lapply(articles, parse_article))
  
  return(result)
}

# Function to write the parsed XML data to a CSV file
write_article_csv <- function(output_file, xml_files) {
  # Remove the output file if it already exists
  if (file.exists(output_file)) {
    file.remove(output_file)
  }
  
  # Create a progress bar for XML documents
  total_xml_files <- length(xml_files)
  pb_xml_files <- txtProgressBar(min = 0, max = total_xml_files, style = 3)
  
  for (i in seq_along(xml_files)) {
    start_time <- Sys.time()
    chunk <- parse_xml_file(xml_files[i])
    end_time <- Sys.time()
    
    write_csv(chunk, output_file, append = i > 1)
    
    # Update the progress bar for XML documents
    setTxtProgressBar(pb_xml_files, i)
    flush.console() # Force flush the buffer
    
    # Display the time taken for processing the current XML document
    cat(sprintf("XML file %d processed in %d seconds\n", i, as.integer(end_time - start_time)))
  }
  
  # Close the progress bar for XML documents
  close(pb_xml_files)
}
#################################END############################################



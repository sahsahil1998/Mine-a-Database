# ----------------------------------------------------------------------------
# Author: Sahil Sah, Veniamin Knyazev
# Course: CS5200 - Practicum 2
# Description: Script to fetch, parse, and store XML data into SQLite tables
# ----------------------------------------------------------------------------


# List of required packages
packages <- c("XML", "httr", "RSQLite", "DBI", "xml2", "readr", "curl")

# Install missing packages
install_packages <- function(pkg) {
  new_packages <- pkg[!(pkg %in% installed.packages()[, "Package"])]
  if (length(new_packages)) {
    install.packages(new_packages, dependencies = TRUE)
  }
}
install_packages(packages)

# Load the required packages
lapply(packages, requireNamespace, quietly = TRUE)
library(RSQLite)
library(xml2)
library(readr)
library(httr)
library(DBI)
library(XML)
library(curl)

# Create a new SQLite connection
con <- dbConnect(RSQLite::SQLite(), "pubmed.db")

# Dropping tables if it exists
dbExecute(con, "DROP TABLE IF EXISTS Journals")
dbExecute(con, "DROP TABLE IF EXISTS Articles")
dbExecute(con, "DROP TABLE IF EXISTS Authors")
dbExecute(con, "DROP TABLE IF EXISTS Journal")
dbExecute(con, "DROP TABLE IF EXISTS Article")
dbExecute(con, "DROP TABLE IF EXISTS Article_author")

create_tables <- function(con) {
  # Create the Journals table
  dbExecute(con, "
  CREATE TABLE Journals (
    journal_id INTEGER PRIMARY KEY AUTOINCREMENT,
    ISSN TEXT NOT NULL,
    issn_type TEXT,
    title TEXT,
    iso_abbreviation TEXT
  )")
  
  # Create the Articles table
  dbExecute(con, "
  CREATE TABLE Articles (
    pmid INTEGER PRIMARY KEY,
    journal_id INTEGER NOT NULL,
    article_title TEXT,
    cited_medium TEXT,
    journal_volume TEXT,
    journal_issue TEXT,
    publication_year INTEGER,
    publication_month INTEGER,
    publication_day INTEGER,
    publication_season TEXT,
    medline_date TEXT,
    FOREIGN KEY (journal_id) REFERENCES journal(journal_id)
  )")
  
  # Create the Authors table
  dbExecute(con, "
  CREATE TABLE Authors (
    author_id INTEGER PRIMARY KEY AUTOINCREMENT,
    last_name TEXT,
    fore_name TEXT,
    initials TEXT,
    suffix TEXT,
    collective_name TEXT,
    affiliation TEXT
  )")
  
  # Author to Article Link
  dbExecute(con, "
  CREATE TABLE Article_author (
    pmid INTEGER NOT NULL,
    author_id INTEGER NOT NULL,
    FOREIGN KEY (pmid) REFERENCES Articles(pmid),
    FOREIGN KEY (author_id) REFERENCES Authors(author_id)
  )")
}

fetch_xml_data <- function(xml_url, dtd_url) {
  # Fetch the XML content
  xml_content <- read_xml(xml_url)
  
  # Fetch the DTD content
  dtd_content <- read_lines(dtd_url, skip_empty = TRUE)
  
  # Combine the DTD content with the XML content
  dtd_declaration <- paste0("<!DOCTYPE ", xml_name(xml_content), " [\n", paste(dtd_content, collapse = "\n"), "\n]>")
  combined_content <- paste0(dtd_declaration, "\n", as.character(xml_content))
  
  # Remove any extra whitespace or characters before the XML declaration
  combined_content <- gsub("^\\s*", "", combined_content)
  
  # Parse the combined content
  xml_obj <- XML::xmlParse(combined_content, asText = TRUE)
  
  return(xml_obj)
}







# Function to convert PubDate into a list with year, month, and day
convert_pubdate <- function(pubdate_node) {
  year <- as.integer(xmlValue(pubdate_node[["Year"]]))
  month <- xmlValue(pubdate_node[["Month"]])
  day <- as.integer(xmlValue(pubdate_node[["Day"]]))
  return(list(year = year, month = month, day = day))
}



# Main script
dtd_url <- "https://raw.githubusercontent.com/sahsahil1998/Mine-a-Database/main/XML/pubmedXML.dtd"
xml_url <- "https://raw.githubusercontent.com/sahsahil1998/Mine-a-Database/main/chunksOfChunks/xml_chunk_1.xml"

                    
create_tables(con)
xml_root <- fetch_xml_data(xml_url, dtd_url)

# Get the count
count <- xmlSize(xml_root)
print(count)

articles <- xml2::xml_find_all(xml_root, ".//Article")


for (article in articles) {
  pmid <- as.integer(xmlGetAttr(article, "PMID"))
  
  # Extract Journal information
  journal_node <- getNodeSet(article, ".//Journal")
  issn <- xmlValue(journal_node[[1]][["ISSN"]])
  issn_type <- xmlGetAttr(journal_node[[1]][["ISSN"]], "IssnType")
  title <- xmlValue(journal_node[[1]][["Title"]])
  iso_abbreviation <- xmlValue(journal_node[[1]][["ISOAbbreviation"]])
  
  # Extract Article information
  article_title <- xmlValue(getNodeSet(article, ".//ArticleTitle")[[1]])
  cited_medium <- xmlGetAttr(getNodeSet(article, ".//JournalIssue")[[1]], "CitedMedium")
  journal_volume <- xmlValue(getNodeSet(article, ".//JournalIssue/Volume")[[1]])
  journal_issue <- xmlValue(getNodeSet(article, ".//JournalIssue/Issue")[[1]])
  pubdate <- convert_pubdate(getNodeSet(article, ".//PubDate")[[1]])
  
  # Extract Authors information
  author_nodes <- getNodeSet(article, ".//Author")
  authors <- lapply(author_nodes, function(author_node) {
    last_name <- xmlValue(author_node[["LastName"]])
    fore_name <- xmlValue(author_node[["ForeName"]])
    initials <- xmlValue(author_node[["Initials"]])
    return(list(last_name = last_name, fore_name = fore_name, initials = initials))
  })
  
  # Insert data into the respective tables
  # Insert Journal data
  dbExecute(con, "INSERT OR IGNORE INTO Journals (ISSN, issn_type, title, iso_abbreviation) VALUES (?, ?, ?, ?)", 
            list(issn, issn_type, title, iso_abbreviation))
  
  # Get the journal_id
  journal_id <- dbGetQuery(con, "SELECT journal_id FROM Journals WHERE ISSN = ?", list(issn))$journal_id
  
  # Insert Article data
  dbExecute(con, "INSERT OR IGNORE INTO Articles (pmid, journal_id, article_title, cited_medium, journal_volume, journal_issue, 
            publication_year, publication_month, publication_day) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)", 
            list(pmid, journal_id, article_title, cited_medium, journal_volume, journal_issue, pubdate$year, pubdate$month, pubdate$day))
  
  # Insert Authors and Article_author data
  for (author in authors) {
    # Insert Author data
    dbExecute(con, "INSERT OR IGNORE INTO Authors (last_name, fore_name, initials) VALUES (?, ?, ?)", 
              list(author$last_name, author$fore_name, author$initials))
    
    # Get the author_id
    author_id <- dbGetQuery(con, "SELECT author_id FROM Authors WHERE last_name = ? AND fore_name = ? AND initials = ?", 
                            list(author$last_name, author$fore_name, author$initials))$author_id
    
    # Insert Article_author data
    dbExecute(con, "INSERT OR IGNORE INTO Article_author (pmid, author_id) VALUES (?, ?)", list(pmid, author_id))
  }
}

parsed_data <- parse_xml_data(xml_root)
process_data(con, parsed_data)




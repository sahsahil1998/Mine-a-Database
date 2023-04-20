
#UTIL
#################################START##########################################
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

#################################END############################################



# Connect to DB and create tables
#################################START##########################################
# Connect to the SQLite database
con <- dbConnect(RSQLite::SQLite(), "pubmed2.db")


# Dropping tables if it exists
dbExecute(con, "DROP TABLE IF EXISTS Journals")
dbExecute(con, "DROP TABLE IF EXISTS Articles")
dbExecute(con, "DROP TABLE IF EXISTS Authors")
dbExecute(con, "DROP TABLE IF EXISTS Affiliations")
dbExecute(con, "DROP TABLE IF EXISTS Author_Affiliation")
dbExecute(con, "DROP TABLE IF EXISTS Article_author")

# Define the SQL statements to create the tables
create_articles <- "CREATE TABLE IF NOT EXISTS Articles (
                     ArticleID INTEGER PRIMARY KEY,
                     PMID TEXT NOT NULL,
                     Title TEXT,
                     JournalID INTEGER,
                     Volume TEXT,
                     Issue TEXT,
                     PubDate TEXT,
                     FOREIGN KEY (JournalID) REFERENCES Journals(JournalID)
                   )"

create_journals <- "CREATE TABLE IF NOT EXISTS Journals (
                     JournalID INTEGER PRIMARY KEY,
                     ISSN TEXT,
                     Title TEXT,
                     ISOAbbreviation TEXT
                   )"


create_authors <- "CREATE TABLE IF NOT EXISTS Authors (
                    AuthorID INTEGER PRIMARY KEY,
                    LastName TEXT,
                    ForeName TEXT,
                    Initials TEXT,
                    Suffix TEXT,
                    CollectiveName TEXT,
                    ValidYN TEXT
                  )"

create_affiliations <- "CREATE TABLE IF NOT EXISTS Affiliations (
                         AffiliationID INTEGER PRIMARY KEY,
                         Affiliation TEXT
                       )"

create_author_affiliation <- "CREATE TABLE IF NOT EXISTS Author_Affiliation (
                               AuthorID INTEGER,
                               AffiliationID INTEGER,
                               PRIMARY KEY (AuthorID, AffiliationID),
                               FOREIGN KEY (AuthorID) REFERENCES Authors(AuthorID),
                               FOREIGN KEY (AffiliationID) REFERENCES Affiliations(AffiliationID)
                             )"

create_article_author <- "CREATE TABLE IF NOT EXISTS Article_Author (
                           ArticleID INTEGER,
                           AuthorID INTEGER,
                           PRIMARY KEY (ArticleID, AuthorID),
                           FOREIGN KEY (ArticleID) REFERENCES Articles(ArticleID),
                           FOREIGN KEY (AuthorID) REFERENCES Authors(AuthorID)
                         )"

# Execute the SQL statements to create the tables in the SQLite database
dbExecute(con, create_articles)
dbExecute(con, create_journals)
dbExecute(con, create_authors)
dbExecute(con, create_affiliations)
dbExecute(con, create_author_affiliation)
dbExecute(con, create_article_author)

# Close the database connection
dbDisconnect(con)
#################################END############################################




# Download XML and DTD from URL and then validate XML using DTD
#################################START##########################################
# Download the XML and DTD files from GitHub
xml_file_url <- "https://raw.githubusercontent.com/sahsahil1998/Mine-a-Database/main/chunksOfChunks/xml_chunk_1.xml"
dtd_file_url <- "https://raw.githubusercontent.com/sahsahil1998/Mine-a-Database/main/pubmed-tfm-xml/pubmedXML.dtd"
xml_file_path <- tempfile()
dtd_file_path <- tempfile()
curl::curl_download(xml_file_url, xml_file_path)
curl::curl_download(dtd_file_url, dtd_file_path)

# Read the XML file and replace the DTD reference with the local DTD file path
xml_content <- readLines(xml_file_path)
xml_content <- gsub("pubmedXML.dtd", dtd_file_path, xml_content, fixed = TRUE)
writeLines(xml_content, xml_file_path)

# Read and validate the XML file
#xml_data <- XML::xmlParse(xml_file_path)

xml_data <- xml2::read_xml(xml_file_path)


# Check if the XML data is an object of class "XMLInternalDocument"
if (inherits(xml_data, "XMLInternalDocument")) {
  cat("XML validation successful!\n")
} else {
  cat("XML validation failed.\n")
}
#################################END############################################




# LOAD XML into database
#################################START##########################################

## Define helper functions


library(xml2)
xml_file <- "C:/Users/vknya/OneDrive/Documents/School/Northeastern/CS 5200/Practicum 2/Mine-a-Database/chunks/xml_chunk_1.xml"
xml_data <- read_xml(xml_file)



# Function to get text content from a node
get_text <- function(node, tag) {
  target_node <- xml2::xml_find_first(node, tag)
  if (!is.null(target_node)) {
    return(xml2::xml_text(target_node))
  } else {
    return(NA)
  }
}


# Function to extract journal information
extract_journal <- function(journal_node) {
  journal <- list(
    ISSN = get_text(journal_node, ".//ISSN"),
    Title = get_text(journal_node, ".//Title"),
    ISOAbbreviation = get_text(journal_node, ".//ISOAbbreviation")
  )
  print(paste("journal_data:", toString(journal)))
  
  return(journal)
}

# Function to extract journal issue information
extract_journal_issue <- function(journal_issue_node) {
  journal_issue <- list(
    Volume = get_text(journal_issue_node, ".//Volume"),
    Issue = get_text(journal_issue_node, ".//Issue")
  )
  print(paste("journal_issue_data:", toString(journal_issue)))
  
  return(journal_issue)
}

# Function to extract author information
extract_author <- function(author_node) {
  last_name <- get_text(author_node, ".//LastName")
  fore_name <- get_text(author_node, ".//ForeName")
  last_name_escaped <- escape_xml_chars(last_name)
  fore_name_escaped <- escape_xml_chars(fore_name)
  
  author <- list(
    LastName = last_name_escaped,
    ForeName = fore_name_escaped,
    Initials = get_text(author_node, ".//Initials"),
    Suffix = get_text(author_node, ".//Suffix"),
    CollectiveName = get_text(author_node, ".//CollectiveName"),
    ValidYN = xml2::xml_attr(author_node, "ValidYN")
  )
  print(paste("author_data:", toString(author)))
  
  return(author)
}


# Function to extract date information as a string
extract_date <- function(date_node) {
  year_node <- xml2::xml_find_first(date_node, ".//Year")
  month_node <- xml2::xml_find_first(date_node, ".//Month")
  day_node <- xml2::xml_find_first(date_node, ".//Day")
  
  year <- ifelse(!is.null(year_node), xml2::xml_text(year_node), "")
  month <- ifelse(!is.null(month_node), xml2::xml_text(month_node), "")
  day <- ifelse(!is.null(day_node), xml2::xml_text(day_node), "")
  
  # Concatenate year, month, and day with hyphens to form date string
  date <- paste(year, month, day, sep = "-")
  
  return(date)
}





# Function to help escape special chars that interfere with XML processing
escape_xml_chars <- function(text) {
  text <- gsub("&", "&amp;", text)
  text <- gsub("<", "&lt;", text)
  text <- gsub(">", "&gt;", text)
  text <- gsub("'", "&apos;", text)
  text <- gsub("\"", "&quot;", text)
  return(text)
}


## END of Helper functions

# Connect to the SQLite database
con <- dbConnect(RSQLite::SQLite(), "pubmed2.db")

# Iterate through top-level nodes
articles <- xml2::xml_find_all(xml_data, "//Article")

for (article in articles) {
  # Extract journal information
  journal_node <- xml2::xml_find_first(article, ".//Journal")
  journal <- extract_journal(journal_node)
  
  # Extract journal issue information
  journal_issue_node <- xml2::xml_find_first(article, ".//JournalIssue")
  journal_issue <- extract_journal_issue(journal_issue_node)
  
  # Insert journal into the database if not already present
  journal_id <- dbGetQuery(con, paste0("SELECT JournalID FROM Journals WHERE ISSN = '", journal$ISSN, "'"))
  if (nrow(journal_id) == 0) {
    dbExecute(con, "INSERT INTO Journals (ISSN, Title, ISOAbbreviation) VALUES (:ISSN, :Title, :ISOAbbreviation)", journal)
    journal_id <- dbGetQuery(con, paste0("SELECT JournalID FROM Journals WHERE ISSN = '", journal$ISSN, "'"))
  }
  
  # Extract article information
  article_title <- get_text(article, ".//ArticleTitle")
  pub_date <- extract_date(xml2::xml_find_first(article, ".//PubDate"))
  pmid <- xml2::xml_attr(article, "PMID")
  
  # DEBUG
  print(paste("article_title:", article_title))
  print(paste("pub_date:", pub_date))
  print(paste("pmid:", pmid))
  # DEBUG
  
  # Insert article into the database
  if (length(journal_id$JournalID) > 0) {
    article_data <- list(PMID = pmid, Title = article_title, JournalID = journal_id$JournalID, Volume = journal_issue$Volume, Issue = journal_issue$Issue, PubDate = pub_date)
    print(paste("article_data:", toString(article_data)))
    dbExecute(con, "INSERT INTO Articles (PMID, Title, JournalID, Volume, Issue, PubDate) VALUES (:PMID, :Title, :JournalID, :Volume, :Issue, :PubDate)", article_data)
  } else {
    print("Error: JournalID not found for the article")
  }
  
  # Extract author information
  author_nodes <- xml2::xml_find_all(article, ".//Author")
  for (author_node in author_nodes) {
    # Extract author information
    author <- extract_author(author_node)
    
    # DEBUG
    print(paste("author_node:", toString(author_node)))
    # DEBUG 
    
    # Insert author into the database if not already present
    author_id <- dbGetQuery(con, paste0("SELECT AuthorID FROM Authors WHERE LastName = '", author$LastName, "' AND ForeName = '", author$ForeName, "' AND Initials = '", author$Initials, "'"))
    if (nrow(author_id) == 0) {
      dbExecute(con, "INSERT INTO Authors (LastName, ForeName, Initials, Suffix, CollectiveName, ValidYN) VALUES (:LastName, :ForeName, :Initials, :Suffix, :CollectiveName, :ValidYN)", author)
      author_id <- dbGetQuery(con, paste0("SELECT AuthorID FROM Authors WHERE LastName = '", author$LastName, "' AND ForeName = '", author$ForeName, "' AND Initials = '", author$Initials, "'"))
    }
    
    # Insert the relationship between the article and the author
    article_id <- dbGetQuery(con, paste0("SELECT ArticleID FROM Articles WHERE PMID = '", pmid, "'"))
    dbExecute(con, "INSERT OR IGNORE INTO Article_Author (ArticleID, AuthorID) VALUES (:ArticleID, :AuthorID)", list(ArticleID = article_id$ArticleID, AuthorID = author_id$AuthorID))
    
    # Extract and process affiliations
    affiliation_nodes <- xml2::xml_find_all(author_node, ".//Affiliation")
    for (affiliation_node in affiliation_nodes) {
      affiliation_text <- xml2::xml_text(affiliation_node)
      
      # DEBUG
      print(paste("affiliation_text:", affiliation_text))
      # DEBUG
      
      # Insert affiliation into the database if not already present
      affiliation_id <- dbGetQuery(con, paste0("SELECT AffiliationID FROM Affiliations WHERE Affiliation = '", affiliation_text, "'"))
      if (nrow(affiliation_id) == 0) {
        dbExecute(con, "INSERT INTO Affiliations (Affiliation) VALUES (:Affiliation)", list(Affiliation = affiliation_text))
        affiliation_id <- dbGetQuery(con, paste0("SELECT AffiliationID FROM Affiliations WHERE Affiliation = '", affiliation_text, "'"))
      }
      
      # Insert the relationship between the author and the affiliation
      dbExecute(con, "INSERT OR IGNORE INTO Author_Affiliation (AuthorID, AffiliationID) VALUES (:AuthorID, :AffiliationID)", list(AuthorID = author_id$AuthorID, AffiliationID = affiliation_id$AffiliationID))
    }
  }
}

# Close the database connection
dbDisconnect(con)


  
  


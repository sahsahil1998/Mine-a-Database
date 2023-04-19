
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
                     PubDate TEXT,
                     FOREIGN KEY (JournalID) REFERENCES Journals(JournalID)
                   )"

create_journals <- "CREATE TABLE IF NOT EXISTS Journals (
                     JournalID INTEGER PRIMARY KEY,
                     ISSN TEXT,
                     Title TEXT,
                     ISOAbbreviation TEXT,
                     Volume TEXT,
                     Issue TEXT
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
xml_data <- XML::xmlParse(xml_file_path)

# Check if the XML data is an object of class "XMLInternalDocument"
if (inherits(xml_data, "XMLInternalDocument")) {
  cat("XML validation successful!\n")
} else {
  cat("XML validation failed.\n")
}
#################################END############################################



# LOAD XML into database
#################################START##########################################
# Connect to the SQLite database
con <- dbConnect(RSQLite::SQLite(), "pubmed2.db")




# Close the database connection
dbDisconnect(con)
#################################END############################################


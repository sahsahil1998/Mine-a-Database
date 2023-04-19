


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

# Dropping tables if it exists
dbExecute(con, "DROP TABLE IF EXISTS Journals")
dbExecute(con, "DROP TABLE IF EXISTS Articles")
dbExecute(con, "DROP TABLE IF EXISTS Authors")
dbExecute(con, "DROP TABLE IF EXISTS Affiliations")
dbExecute(con, "DROP TABLE IF EXISTS Author_Affiliation")
dbExecute(con, "DROP TABLE IF EXISTS Article_author")

# Load the required packages
lapply(packages, requireNamespace, quietly = TRUE)
library(RSQLite)
library(xml2)
library(readr)
library(httr)
library(DBI)
library(XML)
library(curl)


# Connect to the SQLite database (this will create a new file named "pubmed.sqlite" if it does not exist)
con <- dbConnect(RSQLite::SQLite(), "pubmed2.db")

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


# Load required libraries
library(xml2)
library(xmlvalidator)

# Replace these with the paths/URLs to your XML and DTD files
xml_file_path <- "https://github.com/sahsahil1998/Mine-a-Database/blob/main/pubmed-tfm-xml/pubmedXML.xml"
dtd_file_path <- "https://github.com/sahsahil1998/Mine-a-Database/blob/main/pubmed-tfm-xml/pubmedXML.dtd"

# Read the XML file
xml_data <- xml2::read_xml(xml_file_path)

# Read the DTD file
dtd <- system.file("extdata", dtd_file_path, package = "XML")

# Validate the XML file using the DTD
validation_result <- XML::validXMLDoc(xml_data, dtd)

# Check if the validation was successful
if (validation_result) {
  cat("XML validation successful!\n")
} else {
  cat("XML validation failed.\n")
}
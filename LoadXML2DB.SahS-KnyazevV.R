# STEP 1: Install and Load all applicable libraries
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

# Step 2: Validate XML Externally
#################################START##########################################


library(xml2)

# Replace the URL with the actual URL of your XML file hosted on GitHub
xml_url <- "https://raw.githubusercontent.com/sahsahil1998/Mine-a-Database/main/pubmed-tfm-xml/pubmedXML1.xml"

xml_data <- read_xml(xml_url, options = "NOBLANKS")




#################################END############################################


# Step 3: Validate XML Externally
#################################START##########################################


library(xml2)

# Replace the URL with the actual URL of your XML file hosted on GitHub
xml_url <- "https://raw.githubusercontent.com/sahsahil1998/Mine-a-Database/main/pubmed-tfm-xml/pubmedXML1.xml"

xml_data <- read_xml(xml_url, options = "NOBLANKS")




#################################END############################################



# STEP 4: CONVERT

# Convert XML chunks into CSV for easier processing
#################################START##########################################

source("C:/Users/vknya/OneDrive/Documents/School/Northeastern/CS 5200/Practicum 2/Mine-a-Database/Util/splitXMLscript.R")



xml_file <- "C:/Users/vknya/OneDrive/Documents/School/Northeastern/CS 5200/Practicum 2/Mine-a-Database/pubmed-tfm-xml/pubmedXML.xml"
element_type <- "//Article"
chunk_size <- 1000

split_xml_file(xml_file, element_type, chunk_size)




#################################END############################################


# STEP 2: CREATE TABLES IN DB

# Connect to DB and create tables
#################################START##########################################

create_tables <- function() {
  
  # Connect to DB and create tables
  
  # Create a new SQLite connection
  con <- dbConnect(RSQLite::SQLite(), "pubmed.db")
  
  # Dropping tables if it exists
  dbExecute(con, "DROP TABLE IF EXISTS Authors")
  dbExecute(con, "DROP TABLE IF EXISTS Journals")
  dbExecute(con, "DROP TABLE IF EXISTS Articles")
  dbExecute(con, "DROP TABLE IF EXISTS Article_author")
  
  # Create the Journals table
  dbExecute(con, "
  CREATE TABLE Journals (
    journal_id INTEGER PRIMARY KEY AUTOINCREMENT,
    ISSN TEXT NOT NULL,
    title TEXT,
    iso_abbreviation TEXT
  )")
  
  # Create the Articles table
  dbExecute(con, "
  CREATE TABLE Articles (
    PMID INTEGER PRIMARY KEY,
    journal_id INTEGER NOT NULL,
    article_title TEXT,
    publication_year INTEGER,
    publication_month INTEGER,
    publication_day INTEGER,
    FOREIGN KEY (journal_id) REFERENCES Journals(journal_id)
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
    PMID INTEGER NOT NULL,
    author_id INTEGER NOT NULL,
    FOREIGN KEY (PMID) REFERENCES Articles(PMID),
    FOREIGN KEY (author_id) REFERENCES Authors(author_id)
  )")
 
  # Close the database connection
  dbDisconnect(con) 
  
}

create_tables()

#################################END############################################


# STEP 3: POPULATE DB

# Import data from CSV into SQlite DB 
#################################START##########################################

# Load libraries
library(readr)
library(dplyr)
library(RSQLite)
library(tidyr)

# Read the CSV file
csv_data <- read_csv("combined_articles.csv")

# Connect to the SQLite database
con <- dbConnect(RSQLite::SQLite(), "pubmed.db")

# Insert Journals data
csv_data %>%
  select(ISSN, JournalTitle, ISOAbbreviation) %>%
  filter(!is.na(ISSN) & ISSN != "") %>%
  distinct(ISSN, .keep_all = TRUE) %>%
  rename(title = JournalTitle, iso_abbreviation = ISOAbbreviation) %>%
  dbWriteTable(con, "Journals", ., append = TRUE, row.names = FALSE)

# Map ISSN to journal_id
journal_id_map <- dbGetQuery(con, "SELECT journal_id, ISSN FROM Journals")
csv_data <- csv_data %>%
  left_join(journal_id_map, by = "ISSN")

# Separate Authors data from the CSV file
authors_data <- csv_data %>%
  mutate(pmid = row_number()) %>%
  separate_rows(Authors, sep = "\\|") %>%
  separate(Authors, c("last_name", "fore_name", "initials"), sep = ",", extra = "merge") %>%
  mutate(last_name = trimws(last_name),
         fore_name = trimws(fore_name),
         initials = trimws(initials)) %>%
  distinct(pmid, last_name, fore_name, initials)

# Insert Authors data
authors_data %>%
  select(last_name, fore_name, initials) %>%
  distinct() %>%
  dbWriteTable(con, "Authors", ., append = TRUE, row.names = FALSE)

# Map authors in csv_data to author_ids in the Authors table
author_id_map <- dbGetQuery(con, "SELECT author_id, last_name, fore_name, initials FROM Authors")
author_id_map <- authors_data %>%
  left_join(author_id_map, by = c("last_name", "fore_name", "initials")) %>%
  select(pmid, author_id)

# Insert Articles data
csv_data %>%
  filter(!is.na(journal_id)) %>%
  select(PMID, article_title = ArticleTitle, journal_id, Year, Month, Day) %>%
  distinct() %>%
  mutate(Year = as.integer(Year),
         Month = as.integer(Month),
         Day = as.integer(Day),
         publication_year = replace_na(Year, NA_integer_),
         publication_month = replace_na(Month, NA_integer_),
         publication_day = replace_na(Day, NA_integer_)) %>%
  select(PMID, article_title, journal_id, publication_year, publication_month, publication_day) %>%
  dbWriteTable(con, "Articles", ., append = TRUE, row.names = FALSE)


# Insert Article_author data
author_id_map %>%
  filter(!is.na(pmid) & !is.na(author_id)) %>%
  distinct() %>%
  dbWriteTable(con, "Article_author", ., append = TRUE, row.names = FALSE)


# Close the database connection
dbDisconnect(con)


#################################END############################################

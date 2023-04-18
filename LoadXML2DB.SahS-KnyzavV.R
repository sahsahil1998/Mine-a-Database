# List of required packages
packages <- c("xml2", "httr", "RSQLite")

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

# Create a new SQLite connection
con <- dbConnect(RSQLite::SQLite(), ":memory:")

# Dropping tables if it exists
dbExecute(dbcon, "DROP TABLE IF EXISTS Author")
dbExecute(dbcon, "DROP TABLE IF EXISTS Journal")
dbExecute(dbcon, "DROP TABLE IF EXISTS Article")
dbExecute(dbcon, "DROP TABLE IF EXISTS Article_author")

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
  affiliation TEXT,
)")

# Author to Article Link
dbExecute(con, "
CREATE TABLE Article_author (
  pmid INTEGER NOT NULL,
  author_id INTEGER NOT NULL,
  FOREIGN KEY (pmid) REFERENCES Articles(pmid),
  FOREIGN KEY (author_id) REFERENCES Authors(author_id)
)")


# Load the XML content from the URL (or a local file)
url <- "https://www.dropbox.com/s/ciokgebld9hr55h/pubmed-tfm-xml.xml?dl=0"
xml_content <- read_xml(url)

# Parse the XML content
articles <- xml_find_all(xml_content, "//Article")

# Loop through the articles and insert data into the tables
for (article in articles) {
  pmid <- as.integer(xml_attr(article, "PMID"))
  journal <- xml_find_first(article, ".//Journal")
  
  # Insert journal data if not exists
  issn <- xml_text(xml_find_first(journal, ".//ISSN"))
  issn_type <- xml_attr(xml_find_first(journal, ".//ISSN"), "IssnType")
  title <- xml_text(xml_find_first(journal, ".//Title"))
  iso_abbreviation <- xml_text(xml_find_first(journal, ".//ISOAbbreviation"))
  
  journal_id <- dbGetQuery(con, paste0("SELECT journal_id FROM Journals WHERE ISSN = '", issn, "'"))
  
  if (nrow(journal_id) == 0) {
    dbExecute(con, "INSERT INTO Journals (ISSN, issn_type, title, iso_abbreviation) VALUES (?, ?, ?, ?)", 
              params = list(issn, issn_type, title, iso_abbreviation))
    journal_id <- dbGetQuery(con, paste0("SELECT journal_id FROM Journals WHERE ISSN = '", issn, "'"))
  }
  
  # Insert article data
  article_title <- xml_text(xml_find_first(article, ".//ArticleTitle"))
  journal_issue <- xml_find_first(article, ".//JournalIssue")
  cited_medium <- xml_attr(journal_issue, "CitedMedium")
  volume <- xml_text(xml_find_first(journal_issue, ".//Volume"))
  issue <- xml_text(xml_find_first(journal_issue, ".//Issue"))
  pub_date <- xml_find_first(journal_issue, ".//PubDate")
  year <- as.integer(xml_text(xml_find_first(pub_date, ".//Year")))
  month <- xml_text(xml_find_first(pub_date, ".//Month"))
  month <- xml_text(xml_find_first(pub_date, ".//Month"))
  day <- xml_text(xml_find_first(pub_date, ".//Day"))
  
  dbExecute(con, "INSERT INTO Articles (pmid, journal_id, article_title, cited_medium, journal_volume, journal_issue, publication_year, publication_month, publication_day) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            params = list(pmid, journal_id$journal_id, article_title, cited_medium, volume, issue, year, month, day))
  
  # Insert author data
  author_list <- xml_find_first(article, ".//AuthorList")
  authors <- xml_find_all(author_list, ".//Author")
  
  for (author in authors) {
    last_name <- xml_text(xml_find_first(author, ".//LastName"))
    fore_name <- xml_text(xml_find_first(author, ".//ForeName"))
    initials <- xml_text(xml_find_first(author, ".//Initials"))
    suffix <- xml_text(xml_find_first(author, ".//Suffix"))
    
    # Check if author exists in the Authors table
    author_id <- dbGetQuery(con, paste0("SELECT author_id FROM Authors WHERE last_name = '", last_name, "' AND fore_name = '", fore_name, "' AND initials = '", initials, "'"))
    
    if (nrow(author_id) == 0) {
      dbExecute(con, "INSERT INTO Authors (last_name, fore_name, initials, suffix) VALUES (?, ?, ?, ?)",
                params = list(last_name, fore_name, initials, suffix))
      author_id <- dbGetQuery(con, paste0("SELECT author_id FROM Authors WHERE last_name = '", last_name, "' AND fore_name = '", fore_name, "' AND initials = '", initials, "'"))
    }
    
    # Insert data into the Article_author table
    dbExecute(con, "INSERT INTO Article_author (pmid, author_id) VALUES (?, ?)",
              params = list(pmid, author_id$author_id))
  }
}

                    





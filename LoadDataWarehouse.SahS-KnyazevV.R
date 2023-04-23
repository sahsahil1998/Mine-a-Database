# ----------------------------------------------------------------------------
# Author: Sahil Sah, Veniamin Knyazev
# Course: CS5200 - Practicum 2
# Description: This script migrates data from an SQLite database (pubmed.db)
#              to a MySQL database (pubmedDB) and creates a star schema. The
#              schema consists of a Journal Dimension table (Journal_Dim) and
#              a Journal Facts table (Journal_Facts). It then performs
#              analytical queries on the data and prints the results.
# ----------------------------------------------------------------------------

#loading the libraries
library(RMySQL)
library(RSQLite)
library(sqldf)

#Settings for AWS instance
#Instance identifier - Practicum2
#Initial DB name - pubmedDB
db_user <- 'admin'
db_password <- 'tik12tik'
db_name <- 'pubmedDB'
db_host <- 'practicum2.cxdn8klm55ui.us-east-1.rds.amazonaws.com'
db_port <- 3306
# Establish connection
mysqlCon <- dbConnect(MySQL(), user = db_user, password = db_password,
                      dbname = db_name, host = db_host, port = db_port)

# Dropping database if exists
dbExecute(mysqlCon, "DROP DATABASE IF EXISTS pubmedDB")
dbGetQuery(mysqlCon, "SHOW DATABASES")

# Create a new database
dbExecute(mysqlCon, "CREATE DATABASE pubmedDB")
dbGetQuery(mysqlCon, "SHOW DATABASES")

# Select the newly created database
dbExecute(mysqlCon, "USE pubmedDB")

# Create the Journal Dimension table
dbExecute(mysqlCon, "CREATE TABLE Journal_Dim (
  journal_id INTEGER PRIMARY KEY,
  title VARCHAR(255) NOT NULL
) ENGINE=InnoDB")

dbExecute(mysqlCon, "CREATE TABLE Journal_Facts (
  journal_fact_id INTEGER AUTO_INCREMENT PRIMARY KEY,
  journal_id INTEGER,
  publication_year INTEGER,
  publication_quarter INTEGER,
  publication_month INTEGER,
  articles_count INTEGER,
  unique_authors_count INTEGER,
  FOREIGN KEY (journal_id) REFERENCES Journal_Dim(journal_id)
) ENGINE=InnoDB")


# SQLite connection
sqliteCon <- dbConnect(SQLite(), "pubmed.db")


#total_articles_sqlite <- dbGetQuery(sqliteCon, "SELECT COUNT(*) as total_articles FROM Articles")
#print(total_articles_sqlite)

#total_authors_sqlite <- dbGetQuery(sqliteCon, "SELECT COUNT(DISTINCT author_id) as total_authors FROM Article_author")
#print(total_authors_sqlite)

#articles_by_year_sqlite <- dbGetQuery(sqliteCon, "SELECT publication_year, COUNT(*) as total_articles FROM Articles WHERE publication_year BETWEEN 1975 AND 1979 GROUP BY publication_year")
#print(articles_by_year_sqlite)


# Extract data from the SQLite database for the Journal Dimension table
journal_data <- dbGetQuery(sqliteCon, "SELECT DISTINCT journal_id, title FROM Journals")

# Populate the Journal Dimension table
dbWriteTable(mysqlCon, "Journal_Dim", journal_data, append = TRUE, row.names = FALSE)

journal_facts_data <- dbGetQuery(sqliteCon, "
  SELECT j.journal_id, a.publication_year, 
         a.publication_month,
         (a.publication_month - 1) / 3 + 1 AS publication_quarter,
         COUNT(DISTINCT a.pmid) AS articles_count, 
         COUNT(DISTINCT aa.author_id) AS unique_authors_count
  FROM Articles a
  JOIN Journals j ON a.journal_id = j.journal_id
  JOIN Article_author aa ON a.pmid = aa.pmid
  GROUP BY j.journal_id, a.publication_year, publication_quarter, publication_month
")


dbExecute(mysqlCon, "TRUNCATE TABLE Journal_Facts")

# Define a function to create an INSERT statement for a single row
create_insert_statement <- function(row) {
  sprintf("INSERT INTO Journal_Facts (journal_id, publication_year, articles_count, unique_authors_count)
           VALUES (%d, %d, %d, %d)",
          row$journal_id, row$publication_year, row$articles_count, row$unique_authors_count)
}

# Insert the entire DataFrame into the MySQL table
dbWriteTable(mysqlCon, "Journal_Facts", journal_facts_data, append = TRUE, row.names = FALSE)



for (i in 1:nrow(journal_facts_data)) {
  insert_statement <- create_insert_statement(journal_facts_data[i,])
  dbExecute(mysqlCon, insert_statement)
}




factTab <- dbGetQuery(mysqlCon, "SELECT * FROM Journal_Facts LIMIT 20")
print(factTab)
factDim <- dbGetQuery(mysqlCon, "SELECT * FROM Journal_Dim LIMIT 20")
print(factDim)

# Check MySQL Journal_Dim table
journal_dim_check <- dbGetQuery(mysqlCon, "SELECT * FROM Journal_Dim")
print(journal_dim_check)

# Check MySQL Journal_Facts table
journal_facts_check <- dbGetQuery(mysqlCon, "SELECT * FROM Journal_Facts")
print(journal_facts_check)


# Query 1 Find the top 10 journals with the highest number of articles published in 1975.
query1 <- "
SELECT jd.title AS journal_title, SUM(jf.articles_count) AS total_articles
FROM Journal_Facts jf
JOIN Journal_Dim jd ON jf.journal_id = jd.journal_id
WHERE jf.publication_year = 1975
GROUP BY jd.title
ORDER BY total_articles DESC
LIMIT 10
"
result1 <- dbGetQuery(mysqlCon, query1)
print(result1)


# Query 2 Find the top 10 journals with the highest average number of articles published per year between 1975 and 1979.
query2 <- "
SELECT jd.title AS journal_title, AVG(jf.articles_count) AS average_articles_per_year
FROM Journal_Facts jf
JOIN Journal_Dim jd ON jf.journal_id = jd.journal_id
WHERE jf.publication_year BETWEEN 1975 AND 1979
GROUP BY jd.title
ORDER BY average_articles_per_year DESC
LIMIT 10
"
result2 <- dbGetQuery(mysqlCon, query2)
print(result2)


# Query 3 Find  total number of articles published for each year between 1975 and 1979, regardless of the journal.
query3 <- "
SELECT CAST(publication_year AS SIGNED) AS publication_year, SUM(articles_count) AS total_articles
FROM Journal_Facts
GROUP BY publication_year
"
result3 <- dbGetQuery(mysqlCon, query3)
print(result3)

# Query 4 Find  total number of unique authors for each year between 1975 and 1979, regardless of the journal.
query4 <- "
SELECT CAST(publication_year AS SIGNED) AS publication_year, SUM(unique_authors_count) AS total_unique_authors
FROM Journal_Facts
GROUP BY publication_year
"
result4 <- dbGetQuery(mysqlCon, query4)
print(result4)



# Close SQLite connection and MySQL connection
dbDisconnect(sqliteCon)
dbDisconnect(mysqlCon)


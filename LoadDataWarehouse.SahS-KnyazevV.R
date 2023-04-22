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
#Establish connection
mysqlCon <-  dbConnect(MySQL(), user = db_user, password = db_password,
                       dbname = db_name, host = db_host, port = db_port)

# Dropping database if exists
dbExecute(mysqlCon,"DROP DATABASE IF EXISTS pubmedDB")
dbGetQuery(mysqlCon,"SHOW DATABASES")
# Create a new database
dbExecute(mysqlCon, "CREATE DATABASE pubmedDB")
dbGetQuery(mysqlCon, "SHOW DATABASES")
# Select the newly created database
dbExecute(mysqlCon, "USE pubmedDB")

# Create the Journal Dimension table
dbExecute(mysqlCon, "CREATE TABLE Journal_Dim (
  journal_id INTEGER PRIMARY KEY,
  title VARCHAR(255) NOT NULL
)")

# Create the Fact table for Journal facts
dbExecute(mysqlCon, "CREATE TABLE Journal_Facts (
  journal_fact_id INTEGER PRIMARY KEY AUTO_INCREMENT,
  journal_id INTEGER,
  year INTEGER,
  quarter INTEGER,
  month INTEGER,
  articles_count INTEGER,
  unique_authors_count INTEGER,
  FOREIGN KEY (journal_id) REFERENCES Journal_Dim(journal_id)
)")

# SQLite connection
sqliteCon <- dbConnect(SQLite(), "pubmed.db")

# Extract data from the SQLite database for the Journal Dimension table
journal_data <- dbGetQuery(sqliteCon, "SELECT DISTINCT journal_id, title FROM Journals")

# Populate the Journal Dimension table
dbWriteTable(mysqlCon, "Journal_Dim", journal_data, append = TRUE, row.names = FALSE)

# Extract data from the SQLite database for the Journal Facts table
journal_facts_data <- dbGetQuery(sqliteCon, "
  SELECT j.journal_id, strftime('%Y', a.publication_year) AS year, 
         (strftime('%m', a.publication_month) - 1) / 3 + 1 AS quarter, 
         strftime('%m', a.publication_month) AS month,
         COUNT(DISTINCT a.pmid) AS articles_count,
         COUNT(DISTINCT aa.author_id) AS unique_authors_count
  FROM Articles a
  JOIN Journals j ON a.journal_id = j.journal_id
  JOIN Article_author aa ON a.pmid = aa.pmid
  GROUP BY j.journal_id, year, quarter, month
")

# Populate the Journal Facts table
dbWriteTable(mysqlCon, "Journal_Facts", journal_facts_data, append = TRUE, row.names = FALSE)

# Check the data in the Journal_Dim table (top 10 rows)
mysql_journal_dim_data <- dbGetQuery(mysqlCon, "SELECT * FROM Journal_Dim LIMIT 10")
print(mysql_journal_dim_data)

# Check the data in the Journal_Facts table (top 10 rows)
mysql_journal_facts_data <- dbGetQuery(mysqlCon, "SELECT * FROM Journal_Facts LIMIT 10")
print(mysql_journal_facts_data)


## Query 1: What the are number of articles published in every journal in 2012 and 2013?
query1 <- "
SELECT jd.title AS journal_title, SUM(jf.articles_count) AS total_articles
FROM Journal_Facts jf
JOIN Journal_Dim jd ON jf.journal_id = jd.journal_id
WHERE jf.year IN (2012, 2013)
GROUP BY jd.title
"
result1 <- dbGetQuery(mysqlCon, query1)
print(result1)

## Query 2: What is the number of articles published in every journal in each quarter of 2012 through 2015?
query2 <- "
SELECT jd.title AS journal_title, jf.year, jf.quarter, SUM(jf.articles_count) AS total_articles
FROM Journal_Facts jf
JOIN Journal_Dim jd ON jf.journal_id = jd.journal_id
WHERE jf.year BETWEEN 2012 AND 2015
GROUP BY jd.title, jf.year, jf.quarter
"
result2 <- dbGetQuery(mysqlCon, query2)
print(result2)

## Query 3: How many articles were published each quarter (across all years)?
query3 <- "
SELECT year, quarter, SUM(articles_count) AS total_articles
FROM Journal_Facts
GROUP BY year, quarter
"
result3 <- dbGetQuery(mysqlCon, query3)
print(result3)

## Query 4: How many unique authors published articles in each year for which there is data?
query4 <- "
SELECT year, SUM(unique_authors_count) AS total_unique_authors
FROM Journal_Facts
GROUP BY year
"
result4 <- dbGetQuery(mysqlCon, query4)
print(result4)

# Close SQLite connection and MySQL connection
dbDisconnect(sqliteCon)
dbDisconnect(mysqlCon)
             
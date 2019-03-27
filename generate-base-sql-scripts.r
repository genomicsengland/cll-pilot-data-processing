#-- 
rm(list = objects())
options(stringsAsFactors = FALSE,
	scipen = 200)
library(wrangleR)
library(tidyverse)
library(RPostgreSQL)
p <- getprofile("indx_con")
drv <- dbDriver("PostgreSQL")
con <- dbConnect(drv,
             dbname = "cohorts",
             host = p$host,
             port = p$port,
             user = p$user,
             password = p$password)

SCHEMA = "admire_v2"
TGT_DIR = "~/Documents/Projects/cll-pilot-data-processing/admire/sql-scripts"

#-- get list of tables and columns in the schema
d <- dbGetQuery(con, paste0("select table_name, column_name from information_schema.columns where table_schema = '", SCHEMA, "';"))

#-- create the folder if doesn't exist
dir.create(file.path(TGT_DIR), showWarnings = FALSE)

#-- function to generate select script with all tables expressly included
generate_select_script <- function(schema, table, cols){
	paste("select",
		  paste(cols, collapse = ",\n    "),
		  "\nfrom",
		  paste0(schema, ".", table, ";")
		  )
}
#-- function to write out script to appropriate file
write_out_script <- function(txt, fn){
	writeLines(txt, paste0(TGT_DIR, "/", fn, ".sql"))
}

#-- split data by table then generate the sql scripts to select each of the columns
d_sp <- split(d, d$table_name)
txt <- lapply(names(d_sp), function(x) generate_select_script(SCHEMA, x, d_sp[[x]]$column_name))
names(txt) <- names(d_sp)
lapply(names(txt), function(x) write_out_script(txt[[x]], x))

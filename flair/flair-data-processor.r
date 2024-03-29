#-- script to process the flair clinical data and create the cohort
#-- uses the consent manifest as the determinant of which participants
#-- make it into the final cohort
#-- setup
rm(list = objects())
options(stringsAsFactors = F,
	scipen = 200)
library(wrangleR)
library(RPostgreSQL)
library(tidyverse)
drv <- dbDriver("PostgreSQL")
indx.con <- dbConnect(drv,
             dbname = "cohorts",
             host = "localhost",
             port = 5441,
             user = "sthompson",
             password = "password")

#-- get trialno table, consent manifest, and sequencing manifest
trialno <- dbGetQuery(indx.con, "select * from flair_v2.trialno;")
consent_manifest <- dbGetQuery(indx.con, "select * from cll_common.consent_manifest where trial in ('CLLFlair', 'CLLFlair/CLLClear');")

#-- get list of sql files which make research tables and read them into memory
sql_scripts <- list.files(path = "./sql-scripts", pattern = "*.sql", full.names = T)
d <- lapply(sql_scripts, function(x) dbGetQuery(indx.con, paste(readLines(x), collapse = " ")))
names(d) <- gsub(".sql", "", basename(sql_scripts))

#-- disconnect from dbs
dbdisconnectall()

#-- select participants to take forward
#-- have valid consent or are died and don't have any outstanding queries
consent_manifest$export_to_research <- (consent_manifest$valid_consent | 
					consent_manifest$patient_deceased) &
					!consent_manifest$outstanding_consent_query
cohort_trialno <- consent_manifest$trialno[consent_manifest$export_to_research &
					   !is.na(consent_manifest$trialno)]
cohort_patno <- trialno$patno[trialno$trialno %in% cohort_trialno]


#-- select genomes to include, any genome associated with a valid trialno
cohort_patientid <- consent_manifest$patientid[consent_manifest$export_to_research &
					       !is.na(consent_manifest$patientid)] 

#-- do some checks before proceeding
if(any(duplicated(cohort_trialno))){
	stop("duplicated trialnos in cohort (duplicated entries in consent manifest)")
}
if(any(duplicated(cohort_patientid))){
	stop("duplicated patientids in cohort (duplicated entries in consent manifest)")
}
if(any(duplicated(cohort_patno))){
	stop("duplicated patnos in cohort (duplicated entries in trialno table)")
}
if(any(!sapply(d, function(x) "patno" %in% colnames(x)))){
	stop("patno not in every table")
}
if(any(sapply(d[!names(d) %in% "genomes"], function(x) any(is.na(x$patno))))){
	stop("missing values in patno")
}

#-- go through and remove non-valid patnos from non-genomes tables
d_exp <- lapply(d[!names(d) %in% "genomes"], function(x) x[x$patno %in% cohort_patno,])

#-- remove rows from genomes by trialno (dont' have to clinical data to be in this table)
d_exp[["genomes"]] <- d[["genomes"]] %>% filter(patientid %in% cohort_patientid & !is.na(patientid))

#-- function to write out files
writefile <- function(df, filename, separator = "\t"){
	write.table(df,
		    sep = separator,
		    paste0(filename, ".txt"),
		    row.names = F,
		    quote = F,
		    na= "")
	cat(paste("--", filename, "written\n"))
}

#-- write out tables for research
dir.create("research-data")
dir.create(file.path("research-data", Sys.Date()))
for(i in names(d_exp)){
	writefile(d_exp[[i]], file.path("research-data", Sys.Date(), i))
}

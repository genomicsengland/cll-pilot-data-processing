#-- script to refresh the admire dataset given new data tables
#-- setup
rm(list = objects())
options(stringsAsFactors = F,
	scipen = 200)
library(wrangleR)
library(tidyverse)
library(lubridate)
library(digest)
library(RPostgreSQL)
drv <- dbDriver("PostgreSQL")
indx.con <- dbConnect(drv,
             dbname = "testing",
             host = "localhost",
             port = 5432,
             user = "simon",
             password = "postgres")

#-- FUNCTIONS
#-- function to read in the file as a dataframe
readfile <- function(filename){
	read.table(filename,
		      na.strings = c("", "NA"),
		      comment.char = "",
		      sep = "|",
		      header = T
		      )
}

#-- function to write out files
writefile <- function(df, filename, separator = "\t"){
	write.table(df,
		    sep = separator,
		    paste0(filename, ".txt"),
		    row.names = F,
		    quote = F,
		    na= "")
}

#-- function to get table from admire db
gettable <- function(tablename){
	x <- dbGetQuery(indx.con, paste0("select * from admire.", tablename, ";"))
	# identify date columns in df
	is_date_col <- sapply(colnames(x), FUN = function(y) is.Date(x[[y]]) | is.POSIXt(x[[y]]))
	# convert date cols to characters	
	for(i in 1:ncol(x)){
		if(is_date_col[i]){
			x[,i] <- as.character(x[,i], format = "%Y/%m/%d")
		}
	}
	return(x)
}

#-- function to gather together different versions of the same df and remove duplicate rows
#-- across dataframes but not within dataframes
mosaic_dfs <- function(df_ls){
	require(digest)
	x <- lapply(df_ls, function(x){
					# hash each row (will be duplicates if duplicate rows)
					x$row_hash <- apply(x, 1, digest)
					# create row_id per duplicate row
					y <- x %>% group_by(row_hash) %>%
						mutate(row_id = row_number())
					return(as.data.frame(y))
					})
	#--     apply a source id value, which is the number of the dataframe in the list of dfs
	x <- lapply(1:length(x), function(y){
					x[[y]]$source_id <- c(y)
					return(x[[y]])
					})
	# rbind them together and make hash of all columns, excluding row_hash
	# this gives us unique identifier for each row (and duplicate of the row) that will be the same across
	# sources. Need to happen after rbind so that formats are the same
	y <- do.call("rbind", x)
	y$row_id_hash <- apply(y[,!colnames(y) %in% c("row_hash", "source_id")], 1, digest)
	# sort them by source_id desc and remove any duplicate rows (based on duplicates in row_id_hash)
	y <- y[order(y$source_id, decreasing = T),]
	return(y[!duplicated(y$row_id_hash), !colnames(y) %in% c("row_hash", "row_id", "row_id_hash")])
}

#-- PROCESS CLINICAL DATA FILES
#-- get list of txt files in the cll210 directory
files <- list.files(path = "~/Downloads/admire", pattern = "txt$", full.names = T) 

#-- for each of the files, read them in
dfs <- lapply(files, function(x) readfile(x))

#-- make tidier names and those that match tables on db
names(dfs) <- gsub(".txt", "", tolower(basename(files)))
dfs <- lapply(dfs, function(x) setNames(x, tolower(names(x))))

#-- COMPARE PREVIOUS DB TABLES AND COLS TO NEW
curr_db_tables_cols <- dbGetQuery(indx.con, "select table_name, column_name
							 from information_schema.columns
							 where table_schema = 'admire';"
							 )

#-- curr_db_tables_cols$in_previous <- TRUE
#-- new_tables_cols <- lapply(names(dfs), function(x) data.frame("table_name" = c(x),
#--                                                              "column_name" = tolower(colnames(dfs[[x]])),
#--                                                              "in_new" = c(TRUE)))
#-- new_tables_cols <- do.call("rbind", new_tables_cols)
#-- tabl_indx <- merge(curr_db_tables_cols, new_tables_cols, by = c("table_name", "column_name"), all = T)
#-- dtv(tabl_indx[is.na(tabl_indx$in_previous) | is.na(tabl_indx$in_new),])

#-- CONCATENATE OLD AND NEW DATA PER TABLE AND SPOT DIFFERENT ROWS
#-- get table names present in both old and new then create list with previous and new for each table
tables_in_old_and_new <- unique(names(dfs)[names(dfs) %in% curr_db_tables_cols$table_name])
concat_dfs <- lapply(tables_in_old_and_new, function(x){
						 out <- list()
						 out[["old"]] <- gettable(x)
						 out[["new"]] <- dfs[[x]]
						 return(out)
							 })

test <- lapply(concat_dfs, function(x){
				   mosaic_dfs(x)
							 })

names(test) <- tables_in_old_and_new

trialno <- gettable("trialno")
consent_manifest$export_to_research <- (consent_manifest$valid_consent | 
					consent_manifest$patient_deceased) &
					!consent_manifest$outstanding_consent_query
cohort_trialno <- consent_manifest$trialno[consent_manifest$export_to_research &
					   !is.na(consent_manifest$trialno)]
cohort_patno <- trialno$patno[trialno$trialno %in% cohort_trialno]

### BELOW IS TOSS
#-- got to add in tables that were in old not in new and vice versa
all_pat_nos_in_new <- unique(unlist(lapply(dfs, function(x) x$patno)))
olds_patnos <- unique(gettable("trialno")$patno)

all_patnos <- unique(c(all_pat_nos_in_new, olds_patnos))
comp <- data.frame("patno" = all_patnos,
				   "in_new" = all_patnos %in% all_pat_nos_in_new,
				   "in_old" = all_patnos %in% olds_patnos,
				   "in_cohort" = all_patnos %in% cohort_patno)

indx.con <- dbConnect(drv,
             dbname = "cohorts",
             host = "localhost",
             port = 5441,
             user = "sthompson",
             password = "password")

consent_manifest <- dbGetQuery(indx.con, "select * from cll_common.consent_manifest where trial in ('Admire');")
rand <- dfs[["rand"]]

#-- make summary of what is in waht
summ <- lapply(concat_dfs, function(x){
				   data.frame("nrow_old" = nrow(x[["prev"]]),
				   			  "nrow_new" = nrow(x[["new"]]),
				   			  "n_pat_in_old_not_new" = sum(!unique(x[["prev"]]$patno) %in% x[["new"]]$patno),
				   			  "n_pat_in_new_not_old" = sum(!unique(x[["new"]]$patno) %in% x[["prev"]]$patno)
				   			  )
							 })
summ <- do.call("rbind", summ)
summ$table_name <- names(concat_dfs)

#-- ADD BACK IN TABLES NOT FOUND

#-- COHORT SELECTION
#-- read in Excel consent manifest file, then drop the unnecessaries
consent.manifest <- read.xls("../CLL consent spreadsheet_MASTER.xlsx", stringsAsFactors = F)
consent.manifest <- dropnrename(consent.manifest,
				c("Row.ID"
				  , "Trial.Name"
	,"BiobankPatientID"
	,"Trial.Number."
	,"Valid.Consent"
	,"Outstanding.consent.query"
	,"Patient.deceased"
	,"Partial.consent"),
	c("consent.id"
	  ,"Trial"
	,"PatientID"
	,"TrialNo"
	,"Valid.consent"
	,"Outstanding.consent.query"
	,"Patient.deceased"
	,"Partial.consent")
	)

#-- read in the genome manifest file
#-- assembled from https://my.huddle.net/workspace/29344763/files/#/folder/43829733/list
#-- processed by cllrialto-genome-sample-manifest-processor.r
genome.manifest <- readRDS("../cll-genomes-manifest.rds")

#-- only interested in the CLL210 participants at this point
consent.manifest <- consent.manifest[consent.manifest$Trial == "Admire",]

#-- read in the file that links TrialNo to PatNo, provided by Fabrizio
participant.manifest <- read.table("../received-clinical-datasets/admire/trialnos.csv", sep = "|", header = T)

#-- need to convert date of birth to year of birth
#-- two fields are relevant:
#-- dbo_R_RIALtO_frmQOL_eortc.QL30Birthdate
#-- dbo_R_RIALtO_Registration1.REGDOB
#-- function to make year from a date
to.year.fun <- function(x){
	as.numeric(format(as.Date(x), "%Y"))
}

#-- apply it to the fields
dfs[["rand"]]$YOBF03 <- to.year.fun(dfs[["rand"]]$DOBF03)

#-- remove the original fields
dfs[["rand"]] <- dfs[["rand"]][,!colnames(dfs[["rand"]]) %in% "DOBF03"]

#-- merge in the details from consent manifest
participant.manifest <- merge(participant.manifest,
			      consent.manifest,
			      by = "TrialNo",
			      all = T)

#-- flag those who have a genome
participant.manifest$in.genome.manifest <- participant.manifest$PatientID %in% genome.manifest$PatientID

#-- select participants to take forward
#-- have a genome AND (got valid consent OR are deceased) AND don't have an outstanding consent query AND have a PersonID
participant.manifest$export.to.research  <- ( participant.manifest$Valid.consent | participant.manifest$Patient.deceased ) & !participant.manifest$Outstanding.consent.query

#-- write out the participant manifest
write.table(participant.manifest, "admire-participant-manifest.txt", row.names = F, sep = "\t")

ids.to.include <- participant.manifest$PatNo[participant.manifest$export.to.research]

#-- columns to EXCLUDE
cols.to.remove <- readLines("admire-drop-fields.txt")

#-- check that all columns actually feature in the datasets
stopifnot(all(cols.to.remove %in% unlist(field.names)))

#-- merge in trialNo to each table, using PersonId as the thing to merge on
dfs <- lapply(dfs, function(x)
	      merge(x, participant.manifest[,c("TrialNo", "PatNo")], by = "PatNo", all.x = T))


#-- make new list of dataframes that only have those participants we want to include, and don't have cols to remove
dfs.export <- lapply(dfs, function(x) x[x$PatNo %in% ids.to.include , !names(x) %in% cols.to.remove])

#-- add in genomes table using genome.manifest
#-- filter for valid PatientID
dfs.export[["genomes"]] <- genome.manifest[genome.manifest$PatientID %in% participant.manifest$PatientID[which(participant.manifest$export.to.research)],]
#-- merge in relevant columns from participant.manifest
dfs.export[["genomes"]] <- merge(dfs.export[["genomes"]],
				 participant.manifest[,c("TrialNo", "PatNo", "PatientID"),],
				 by = "PatientID",
				 all.x = T)

#-- write out to rd file
saveRDS(dfs.export, "admire-research-data.rds")

#-- make list of dimenstions to check that have written correctly
dims.export.ls <- lapply(dfs.export, function(x) c(nrow(x), ncol(x)))
dims.export.df <- as.data.frame(do.call(rbind, dims.export.ls))
names(dims.export.df) <- c("nrows", "ncols")

#-- write out each of dfs in dfs.export
lapply(seq_along(dfs.export), function(i) writefile(dfs.export[[i]], paste0("../research-datasets/admire/", names(dfs.export)[i])))

#-- CHECKS
#-- get list of exported files
exportedfiles <- list.files("../research-datasets/admire", full.names = T)

#-- get line and column counts of each exported file
exported.dims.ls <- lapply(exportedfiles, function(x) c(linecount(x) - 1, colcount(x)))
exported.dims.df <- as.data.frame(do.call(rbind, exported.dims.ls)) 
row.names(exported.dims.df) <- gsub(".csv", "", basename(exportedfiles))

#-- are there any differences
dims.export.df[order(rownames(dims.export.df)),] == exported.dims.df[order(rownames(exported.dims.df)),]


dbdisconnectall()

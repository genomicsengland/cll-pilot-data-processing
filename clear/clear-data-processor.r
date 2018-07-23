#-- script to process the clear clinical data and create the cohort
#-- uses the consent manifest as the determinant of which participants
#-- make it into the final cohort
#-- the consent manifest lives at https://my.huddle.net/workspace/38658629/files/#/59413080

ONLY A TEMPLATE UNTIL WE RECEIVE CLINICAL DATA

#-- setup
rm(list = objects())
options(stringsAsFactors = F,
	scipen = 200)
library(wrangleR)

#-- for reading excel files
library(gdata)

#-- FUNCTIONS
#-- function to read in the file as a dataframe
readfile <- function(filename){
	read.table(paste0("../received-clinical-datasets/clear/", filename),
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

#-- function to get how many columns (separators) in file?
#-- essentially get awk to count number of separators per line (deleting nulls first), then do sort and uniq
colcount <- function(file, separator = "|"){
	numcols <- as.numeric(strsplit(system(paste0("cat ", file, " | tr -d '\\000' | awk -F'", separator, "' '{print NF}' | sort | uniq"), intern = T), " "))
	stopifnot(length(numcols) == 1)
	return(numcols)
}

#-- function to get linecount of a file
linecount <- function(file){
	as.numeric(strsplit(trimws(system(paste("wc -l", file), intern = T)), " ")[[1]][1])
}

#-- PROCESS CLINICAL DATA FILES
#-- get list of txt files in the cll210 directory
files <- list.files(path = "../received-clinical-datasets/clear", pattern = "txt$") 

#-- for each of the files, read them in
dfs <- lapply(files, function(x) readfile(x))

#-- make tidier names
names(dfs) <- gsub(".txt", "", basename(files))

#-- make number of rows and cols for each
#-- dims.ls <- lapply(dfs, function(x) c(nrow(x), ncol(x)))
#-- dims.df <- as.data.frame(do.call(rbind, dims.ls))
#-- names(dims.df) <- c("nrows", "ncols")

#-- write out the dimensions
#-- write.table(dims.df, file = "clear_tabledims.txt", sep = "\t", row.names = F)

#-- get the column headings per table, and number of NAs
#-- field.names <- lapply(dfs, function(x) names(x))
#-- n.missing <- lapply(dfs, function(x) apply(x, 2, function(y) sum(is.na(y))))
#-- n.rows <- lapply(dfs, function(x) apply(x, 2, function(y) length(y)))

#-- convert to data.frame then writeout
#-- n.missing.df <- as.data.frame(unlist(n.missing))
#-- n.rows.df <- as.data.frame(unlist(n.rows))
#-- cll210.summ <- setNames(cbind(n.missing.df, n.rows.df), c("n.missing", "n.rows"))
#-- write.table(cll210.summ, file = "clear_data_summary.txt", sep = "\t")

#-- COHORT SELECTION
#-- read in Excel consent manifest file, then drop the unnecessaries
consent.manifest <- read.xls("../CLL consent spreadsheet_MASTER.xlsx", stringsAsFactors = F)
consent.manifest <- dropnrename(consent.manifest,
	c("Row.ID"
	  ,"Trial.Name"
	,"BiobankPatientID"
	,"Trial.Number."
	,"Valid.Consent"
	,"Outstanding.consent.query"
	,"Patient.deceased"
	,"Partial.consent"),
	c("Trial"
	  ,"consent.id"
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
consent.manifest <- consent.manifest[consent.manifest$Trial == "CLLClear",]

#-- read in the file that links TrialNo to PatNo, provided by Fabrizio
#-- participant.manifest <- read.table("../received-clinical-datasets/clear/trialnos.csv", sep = "|", header = T)

#-- need to convert date of birth to year of birth
#-- function to make year from a date
#-- to.year.fun <- function(x){
#--         as.numeric(format(as.Date(x), "%Y"))
#-- }

#-- apply it to the fields
#-- dfs[["rand"]]$YOBF03 <- to.year.fun(dfs[["rand"]]$DOBF03)

#-- remove the original fields
#-- dfs[["rand"]] <- dfs[["rand"]][,!colnames(dfs[["rand"]]) %in% "DOBF03"]

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
write.table(participant.manifest, "clear-participant-manifest.txt", row.names = F, sep = "\t")

ids.to.include <- participant.manifest$PatNo[participant.manifest$export.to.research]

#-- columns to EXCLUDE
cols.to.remove <- readLines("clear-drop-fields.txt")

#-- check that all columns actually feature in the datasets
stopifnot(all(cols.to.remove %in% unlist(field.names)))

#-- merge in trialNo to each table, using PatNo as the thing to merge on
#-- not all tables have PatNo though so only apply to those with that data, need to put names back in afterwards
gotpatno <- sapply(dfs, function(x) "PatNo" %in% colnames(x))
n <- names(dfs)
dfs[gotpatno] <- lapply(dfs[gotpatno], function(x)
	      merge(x, participant.manifest[,c("TrialNo", "PatNo")], by = "PatNo", all.x = T))

#-- make new list of dataframes that only have those participants we want to include, and don't have cols to remove
dfs.export <- dfs
dfs.export[gotpatno] <- lapply(dfs.export[gotpatno], function(x) x[x$PatNo %in% ids.to.include , !names(x) %in% cols.to.remove])
names(dfs) <- n

#-- add in genomes table using genome.manifest
#-- filter for valid PatientID
dfs.export[["genomes"]] <- genome.manifest[genome.manifest$PatientID %in% participant.manifest$PatientID[which(participant.manifest$export.to.research)],]
#-- merge in relevant columns from participant.manifest
dfs.export[["genomes"]] <- merge(dfs.export[["genomes"]],
				 participant.manifest[,c("TrialNo", "PatNo", "PatientID"),],
				 by = "PatientID",
				 all.x = T)

#-- write out to rd file
saveRDS(dfs.export, "clear-research-data.rds")

#-- make list of dimenstions to check that have written correctly
dims.export.ls <- lapply(dfs.export, function(x) c(nrow(x), ncol(x)))
dims.export.df <- as.data.frame(do.call(rbind, dims.export.ls))
names(dims.export.df) <- c("nrows", "ncols")

#-- write out each of dfs in dfs.export
lapply(seq_along(dfs.export), function(i) writefile(dfs.export[[i]], paste0("../research-datasets/clear/", names(dfs.export)[i])))

#-- CHECKS
#-- get list of exported files
exportedfiles <- list.files("../research-datasets/clear", full.names = T)

#-- get line and column counts of each exported file
exported.dims.ls <- lapply(exportedfiles, function(x) c(linecount(x) - 1, colcount(x)))
exported.dims.df <- as.data.frame(do.call(rbind, exported.dims.ls)) 
row.names(exported.dims.df) <- gsub(".csv", "", basename(exportedfiles))

#-- are there any differences
dims.export.df[order(rownames(dims.export.df)),] == exported.dims.df[order(rownames(exported.dims.df)),]

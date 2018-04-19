#-- script to process the cll210 clinical data and create the cohort
#-- uses the consent manifest as the determinant of which participants
#-- make it into the final cohort
#-- the consent manifest lives at https://my.huddle.net/workspace/38658629/files/#/59413080

#-- TODO: check that all platekeys in the old cll210 are in my genome.manifest
#-- TODO: download new consent manifest

#-- setup
rm(list = objects())
library(wrangleR)

#-- for reading excel files
library(gdata)

#-- FUNCTIONS
#-- function to read in the file as a dataframe
readfile <- function(filename){
	read.table(paste0("./data/cll210/", filename),
		      na.strings = c("", "NA"),
		      comment.char = "",
		      sep = "|",
		      header = T,
		      stringsAsFactors = F
		      )
}

#-- function to write out files
writefile <- function(df, filename, separator = "|"){
	write.table(df,
		    sep = separator,
		    paste0(filename, ".csv"),
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
files <- list.files(path = "./data/cll210", pattern = "txt$") 

#-- for each of the files, read them in
dfs <- lapply(files, function(x) readfile(x))

#-- make tidier names
names(dfs) <- gsub(".txt", "", basename(files))

#-- make number of rows and cols for each
dims.ls <- lapply(dfs, function(x) c(nrow(x), ncol(x)))
dims.df <- as.data.frame(do.call(rbind, dims.ls))
names(dims.df) <- c("nrows", "ncols")

#-- write out the dimensions
write.table(dims.df, file = "cll210_tabledims.txt", sep = "\t", row.names = F)

#-- get the column headings per table, and number of NAs
field.names <- lapply(dfs, function(x) names(x))
n.missing <- lapply(dfs, function(x) apply(x, 2, function(y) sum(is.na(y))))
n.rows <- lapply(dfs, function(x) apply(x, 2, function(y) length(y)))

#-- convert to data.frame then writeout
n.missing.df <- as.data.frame(unlist(n.missing))
n.rows.df <- as.data.frame(unlist(n.rows))
cll210.summ <- setNames(cbind(n.missing.df, n.rows.df), c("n.missing", "n.rows"))
write.table(cll210.summ, file = "cll210_data_summary.txt", sep = "\t")

#-- COHORT SELECTION
#-- read in Excel consent manifest file, then drop the unnecessaries
consent.manifest <- read.xls("CLL consent spreadsheet_MASTER.xlsx", stringsAsFactors = F)
consent.manifest <- dropnrename(consent.manifest,
	c("Trial.Name"
	,"BiobankPatientID"
	,"Trial.Number."
	,"Valid.Consent"
	,"Outstanding.consent.query"
	,"Patient.deceased"
	,"Partial.consent"),
	c("Trial"
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
genome.manifest <- readRDS("cll-genomes-manifest.rds")

#-- only interested in the CLL210 participants at this point
consent.manifest <- consent.manifest[consent.manifest$Trial == "CLL210",]

#-- PersonID is the key to select rows from each of the tables
#-- problem is that no single table has all PersonIds present in the dataset and also has PatientNo (which is needed to make the TrialNo).
#-- so need to make a meta list of all PersonId:PatientNo:HospitalSite combinations
#-- first need to change REGTrialNo in Registration1 to PatientNo as in other tables 
colnames(dfs[["dbo_R_CLL210_Registration1"]])[colnames(dfs[["dbo_R_CLL210_Registration1"]]) == "REGTrialNo"] <- "PatientNo"

#-- get vector for presence of PatientNo
got.patient.no <- unlist(lapply(dfs, function(x) all(c("PersonId", "PatientNo") %in% colnames(x))))

#-- the PatientNo are not in a decent format, need a function to correct them
maketrialnum <- function(x){
	sapply(x,
	       function(y) ifelse(is.na(y),
		      NA,
		      paste0(formatC(as.numeric(substr(y, 1, nchar(y) - 4)), width = 3, flag = 0), "-", substr(y, nchar(y) - 3, nchar(y)))
		      )
	       )
}

#-- use the function on all the relevant dataframes, renaming PatientNo > TrialNo in the process
for(i in names(dfs)[got.patient.no]){
	dfs[[i]]$TrialNo <- maketrialnum(dfs[[i]]$PatientNo)
	dfs[[i]] <- dfs[[i]][,!colnames(dfs[[i]]) %in% "PatientNo"]
}

#-- extract necessary columns
participant.manifest <- lapply(dfs[got.patient.no],
				function(x) x[, c("PersonId", "TrialNo")])

#-- collapse it down
participant.manifest <- do.call(rbind, participant.manifest)

#-- need complete.cases for it to be useful, and only unique rows
participant.manifest <- unique(participant.manifest[complete.cases(participant.manifest),])

#-- need to convert date of birth to year of birth
#-- only features in dbo_R_CLL210_Registration1
#-- function to make year from a date
to.year.fun <- function(x){
	as.numeric(format(as.Date(x), "%Y"))
}

#-- apply it to the fields
dfs[["dbo_R_CLL210_Registration1"]]$REGYOB <- to.year.fun(dfs[["dbo_R_CLL210_Registration1"]]$REGDOB)

#-- remove the original fields
dfs[["dbo_R_CLL210_Registration1"]] <- dfs[["dbo_R_CLL210_Registration1"]][,
					!colnames(dfs[["dbo_R_CLL210_Registration1"]]) %in% "REGDOB"]

#-- merge in the details from consent manifest to the participant manifest
participant.manifest <- merge(participant.manifest,
			      consent.manifest,
			      by = "TrialNo",
			      all.x = T)

#-- flag those who have a genome
participant.manifest$in.genome.manifest <- participant.manifest$PatientID %in% genome.manifest$PatientID

#-- select participants to take forward
#-- have a genome AND (got valid consent OR are deceased) AND don't have an outstanding consent query AND have a PersonID
participant.manifest$export.to.research  <- participant.manifest$in.genome.manifest &
				( participant.manifest$Valid.consent | participant.manifest$Patient.deceased ) &
				!participant.manifest$Outstanding.consent.query &
				!is.na(participant.manifest$PersonId)

#-- write out the participant manifest
write.table(participant.manifest, "cll210-participant-manifest.txt", row.names = F, sep = "\t")

ids.to.include <- participant.manifest$PersonId[participant.manifest$export.to.research]

#-- columns to EXCLUDE
cols.to.remove <- readLines("cll210-drop-fields.txt")

#-- check that all columns actually feature in the datasets
stopifnot(all(cols.to.remove %in% unlist(field.names)))

#-- merge in trialNo to each table, except those tables that have already got it
for(i in names(dfs)){
	      if(!got.patient.no[i]){
		     dfs[[i]] <- merge(dfs[[i]], participant.manifest[,c("TrialNo", "PersonId")], by = "PersonId", all.x = T)
	      }
	      }

#-- make new list of dataframes that only have those participants we want to include, and don't have cols to remove
dfs.export <- lapply(dfs, function(x) x[x$PersonId %in% ids.to.include , !names(x) %in% cols.to.remove])

#-- add in genomes table using genome.manifest
#-- filter for valid PatientID
dfs.export[["genomes"]] <- genome.manifest[genome.manifest$PatientID %in% participant.manifest$PatientID[which(participant.manifest$export.to.research)],]
#-- merge in relevant columns from participant.manifest
dfs.export[["genomes"]] <- merge(dfs.export[["genomes"]],
				 participant.manifest[,c("TrialNo", "PersonId", "PatientID"),],
				 by = "PatientID",
				 all.x = T)

#-- write out to rd file
saveRDS(dfs.export, "cll210-research-data.rds")

#-- make list of dimenstions to check that have written correctly
dims.export.ls <- lapply(dfs.export, function(x) c(nrow(x), ncol(x)))
dims.export.df <- as.data.frame(do.call(rbind, dims.export.ls))
names(dims.export.df) <- c("nrows", "ncols")

#-- write out each of dfs in dfs.export
lapply(seq_along(dfs.export), function(i) writefile(dfs.export[[i]], paste0("./researchdata/cll210/", names(dfs.export)[i])))

#-- CHECKS
#-- get list of exported files
exportedfiles <- list.files("./researchdata/cll210", full.names = T)

#-- get line and column counts of each exported file
exported.dims.ls <- lapply(exportedfiles, function(x) c(linecount(x) - 1, colcount(x)))
exported.dims.df <- as.data.frame(do.call(rbind, exported.dims.ls)) 
row.names(exported.dims.df) <- gsub(".csv", "", basename(exportedfiles))

#-- are there any differences
dims.export.df[order(rownames(dims.export.df)),] == exported.dims.df[order(rownames(exported.dims.df)),]

#-- some columns that are free text which might contain some dodgy data
ftcols <- c("Comments",
	"Comments2",
	"CT_Node_Spec",
	"CT_Oth_Spec",
	"DemCLLSiteSpec",
	"EOSReasonOther",
	"TRSWdrawRsnOthr",
	"MHOther",
	"OSTOther")
#-- go through and get all data in those columns to check for anything of concern, need to check through this
ft <- lapply(dfs.export, function(x) unique(x[,colnames(x) %in% ftcols]))

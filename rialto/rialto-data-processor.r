#-- script to process the rialto clinical data and create the cohort
#-- uses the consent manifest as the determinant of which participants
#-- make it into the final cohort
#-- the consent manifest lives at https://my.huddle.net/workspace/38658629/files/#/59413080
#-- it gets updated and edited using data generated from cllrialto-genome-sample-manifest-processor.r

#TODO: remove consent related fields?

#-- setup
rm(list = objects())
library(wrangleR)

#-- for reading excel files
library(gdata)

#-- FUNCTIONS
#-- function to read in the file as a dataframe
readfile <- function(filename){
	read.table(paste0("../received-clinical-datasets/rialto/", filename),
		      na.strings = c("", "NA"),
		      comment.char = "",
		      sep = "|",
		      header = T,
		      stringsAsFactors = F
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
colcount <- function(file, separator = "\t"){
	numcols <- as.numeric(strsplit(system(paste0("cat ", file, " | tr -d '\\000' | awk -F'", separator, "' '{print NF}' | sort | uniq"), intern = T), " "))
	stopifnot(length(numcols) == 1)
	return(numcols)
}

#-- function to get linecount of a file
linecount <- function(file){
	as.numeric(strsplit(trimws(system(paste("wc -l", file), intern = T)), " ")[[1]][1])
}

#-- PROCESS CLINICAL DATA FILES
#-- get list of xlsx files in the rialto directory
files <- list.files(path = "../received-clinical-datasets/rialto", pattern = "txt$") 

#-- for each of the files, read them in
dfs <- lapply(files, function(x) readfile(x))

#-- make tidier names
names(dfs) <- gsub(".txt", "", basename(files))

#-- make number of rows and cols for each
dims.ls <- lapply(dfs, function(x) c(nrow(x), ncol(x)))
dims.df <- as.data.frame(do.call(rbind, dims.ls))
names(dims.df) <- c("nrows", "ncols")

#-- write out the dimensions
write.table(dims.df, file = "rialto_tabledims.txt", sep = "\t", row.names = F)

#-- get the column headings per table, and number of NAs
field.names <- lapply(dfs, function(x) names(x))
n.missing <- lapply(dfs, function(x) apply(x, 2, function(y) sum(is.na(y))))
n.rows <- lapply(dfs, function(x) apply(x, 2, function(y) length(y)))

#-- convert to data.frame
n.missing.df <- as.data.frame(unlist(n.missing))
n.rows.df <- as.data.frame(unlist(n.rows))

#-- bind those together
cllrialto.summ <- cbind(n.missing.df, n.rows.df)

#-- correct column names
names(cllrialto.summ) <- c("n.missing", "n.rows")

#-- write out the table
write.table(cllrialto.summ, file = "rialto_data_summary.txt", sep = "\t")

#-- COHORT SELECTION
#-- read in Excel consent manifest file, then drop the unnecessaries
consent.manifest <- read.xls("../CLL consent spreadsheet_MASTER.xlsx", stringsAsFactors = F)
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
genome.manifest <- readRDS("../cll-genomes-manifest.rds")

#-- only interested in the Rialto participants at this point
consent.manifest <- consent.manifest[consent.manifest$Trial == "Rialto",]

#-- PersonID is the key to select rows from each of the tables
#-- problem is that no single table has all PersonIds present in the dataset and also has PatientNo (which is needed to make the TrialNo).
#-- so need to make a meta list of all PersonId:PatientNo:HospitalSite combinations
#-- get vector for presence of PatientNo
got.patient.id <- unlist(lapply(dfs, function(x) "PatientNo" %in% colnames(x)))

#-- extract necessary columns
participant.manifest <- lapply(dfs[got.patient.id],
				function(x) x[, c("PersonId", "PatientNo", "HospitalSite")])

#-- collapse it down
participant.manifest <- do.call(rbind, participant.manifest)

#-- need complete.cases for it to be useful, and only unique rows
participant.manifest <- unique(participant.manifest[complete.cases(participant.manifest),])


#-- need to convert date of birth to year of birth
#-- two fields are relevant:
#-- dbo_R_RIALtO_frmQOL_eortc.QL30Birthdate
#-- dbo_R_RIALtO_Registration1.REGDOB
#-- function to make year from a date
to.year.fun <- function(x){
	as.numeric(format(as.Date(x), "%Y"))
}

#-- apply it to the fields
dfs[["dbo_R_RIALtO_Registration1"]]$REGYOB <- to.year.fun(dfs[["dbo_R_RIALtO_Registration1"]]$REGDOB)
dfs[["dbo_R_RIALtO_frmQOL_eortc"]]$QL30Birthyear <- to.year.fun(dfs[["dbo_R_RIALtO_frmQOL_eortc"]]$QL30Birthdate)

#-- remove the original fields
dfs[["dbo_R_RIALtO_Registration1"]] <- dfs[["dbo_R_RIALtO_Registration1"]][,
					!colnames(dfs[["dbo_R_RIALtO_Registration1"]]) %in% "REGDOB"]
dfs[["dbo_R_RIALtO_frmQOL_eortc"]] <- dfs[["dbo_R_RIALtO_frmQOL_eortc"]][,
					!colnames(dfs[["dbo_R_RIALtO_frmQOL_eortc"]]) %in% "QL30Birthdate"]

#-- make the trial numbers
participant.manifest$TrialNo <- paste0(sprintf("%03d", participant.manifest$HospitalSite),
			   "-",
			   sprintf("%04d", participant.manifest$PatientNo))

#-- merge in the details from consent manifest
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
write.table(participant.manifest, "rialto-participant-manifest.txt", row.names = F, sep = "\t")

ids.to.include <- participant.manifest$PersonId[participant.manifest$export.to.research]

#-- columns to EXCLUDE
cols.to.remove <- readLines("rialto-drop-fields.txt")

#-- check that all columns actually feature in the datasets
stopifnot(all(cols.to.remove %in% unlist(field.names)))

#-- merge in trialNo to each table, using PersonId as the thing to merge on
dfs <- lapply(dfs, function(x)
	      merge(x, participant.manifest[,c("TrialNo", "PersonId")], by = "PersonId", all.x = T))


#-- make new list of dataframes that only have those participants we want to include, and don't have cols to remove
dfs.export <- lapply(dfs, function(x) x[x$PersonId %in% ids.to.include , !names(x) %in% cols.to.remove])

#-- add in genomes table using genome.manifest
#-- filter for valid PatientID
dfs.export[["genomes"]] <- genome.manifest[genome.manifest$PatientID %in% participant.manifest$PatientID[which(participant.manifest$export.to.research)],]
#-- merge in relevant columns from participant.manifest
dfs.export[["genomes"]] <- merge(dfs.export[["genomes"]],
				 participant.manifest[,c("TrialNo", "PersonId", "PatientNo", "HospitalSite", "PatientID"),],
				 by = "PatientID",
				 all.x = T)

#-- write out to rd file
saveRDS(dfs.export, "rialto-research-data.rds")

#-- make list of dimenstions to check that have written correctly
dims.export.ls <- lapply(dfs.export, function(x) c(nrow(x), ncol(x)))
dims.export.df <- as.data.frame(do.call(rbind, dims.export.ls))
names(dims.export.df) <- c("nrows", "ncols")

#-- write out each of dfs in dfs.export
lapply(seq_along(dfs.export), function(i) writefile(dfs.export[[i]], paste0("../research-datasets/rialto/", names(dfs.export)[i])))

#-- CHECKS
#-- get list of exported files
exportedfiles <- list.files("../research-datasets/rialto", full.names = T)

#-- get line and column counts of each exported file
exported.dims.ls <- lapply(exportedfiles, function(x) c(linecount(x) - 1, colcount(x)))
exported.dims.df <- as.data.frame(do.call(rbind, exported.dims.ls)) 
row.names(exported.dims.df) <- gsub(".txt", "", basename(exportedfiles))

#-- are there any differences
dims.export.df[order(rownames(dims.export.df)),] == exported.dims.df[order(rownames(exported.dims.df)),]

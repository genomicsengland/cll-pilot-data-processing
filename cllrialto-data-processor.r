#-- script to process the rialto clinical data and create the cohort

#-- run the sample and genome manifest process
source("cllrialto-genome-sample-manifest-processor.r")

#-- clear the slate (we read the manifests in lates)
rm(list = objects())

#-- for reading excel files
library(gdata)

#-- FUNCTIONS
#-- get list of xlsx files in the cll210 directory
files <- list.files(path = "./data/rialto", pattern = "txt$") 

#-- function to read in the xlsx file as a dataframe
readfile <- function(filename){
	#-- make our object name
	read.table(paste0("./data/rialto/", filename),
		      na.strings = c("", "NA"),
		      comment.char = "",
		      sep = "|",
		      header = T)
}

#-- function to write out files
writefile <- function(df, filename, separator = "|"){
	write.table(df,
		    sep = separator,
		    paste0(filename, ".csv"),
		    row.names = F,
		    quote = F)
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
#-- for each of the files, read them in
dfs <- lapply(files, function(x) readfile(x))

#-- make tidier names
names(dfs) <- gsub(".txt", "", basename(files))

#-- write out dfs so that don't have to read it in each time during development
# saveRDS(dfs, file = "cllrialtodata.rds")
# dfs <- readRDS("cllrialtodata.rds")

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
sample.manifest <- readRDS("cll210-rialto-sample-manifest.rds")
consent.manifest <- read.xls("./data/consentmanifest.xlsx", stringsAsFactors = F)
genome.manifest <- readRDS("cll-genomes-manifest.rds")

#-- select only Rialto consent records
TrialNo.consented <- consent.manifest$Trial.Number.[consent.manifest$Trial.Name. == "Rialto"]

#-- ids to include, select PersonIds for those people whose trial no is in the sample manifest, and they have a genome in the sample.manifest
#-- problem is that no single table has all PersonIds present in the dataset, and laso has PatientNo (which is needed to make the TrialNo).
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

#-- make the trial numbers
participant.manifest$TrialNo <- paste0(sprintf("%03d", participant.manifest$HospitalSite),
			   "-",
			   sprintf("%04d", participant.manifest$PatientNo))

#-- bring in PatientID from sample.manifest
participant.manifest <- merge(participant.manifest,
			      unique(sample.manifest[,c("PatientID", "TrialNo")]),
			      by = "TrialNo",
			      all.x = T)

#-- flag those who have a genome
participant.manifest$in.genome.manifest <- participant.manifest$PatientID %in% genome.manifest$PatientID

#-- flag those in the consent manifest
participant.manifest$in.consent.manifest <- participant.manifest$TrialNo %in% consent.manifest$Trial.Number.

#-- flag those that have 100KGP consent according to registration1 table
personids.genomes.proj.consent <- dfs[["dbo_R_RIALtO_Registration1"]]$PersonId[which(dfs[["dbo_R_RIALtO_Registration1"]]$REGgenomecons == 1)]
participant.manifest$genomes.proj.consent <- participant.manifest$PersonId %in% personids.genomes.proj.consent

#-- select participants to take forward
participant.manifest$export.to.research  <- participant.manifest$in.genome.manifest & participant.manifest$in.consent.manifest & participant.manifest$genomes.proj.consent

#-- write out the participant manifest
write.table(participant.manifest, "rialto-participant-manifest.txt", row.names = F, sep = "\t")

ids.to.include <- participant.manifest$PersonId[participant.manifest$export.to.research]

#-- columns to EXCLUDE
cols.to.remove <- readLines("rialto-drop-fields.txt")

#-- check that all columns actually feature in the datasets
stopifnot(all(cols.to.remove %in% unlist(field.names)))

#-- make new list of datamframes that only have those participants we want to include, and don't have cols to remove
dfs.export <- lapply(dfs, function(x) x[x$PersonId %in% ids.to.include , !names(x) %in% cols.to.remove])

#-- write out to rd file
# saveRDS(dfs.export, "rialto-research-data.rds")

#-- make list of dimenstions to check that have written correctly
dims.export.ls <- lapply(dfs.export, function(x) c(nrow(x), ncol(x)))
dims.export.df <- as.data.frame(do.call(rbind, dims.export.ls))
names(dims.export.df) <- c("nrows", "ncols")


#-- write out each of dfs in dfs.export
lapply(seq_along(dfs.export), function(i) writefile(dfs.export[[i]], paste0("./researchdata/rialto/", names(dfs.export)[i])))

#-- CHECKS
exportedfiles <- list.files("./researchdata/rialto", full.names = T)

exported.dims.ls <- lapply(exportedfiles, function(x) c(linecount(x) - 1, colcount(x)))
exported.dims.df <- as.data.frame(do.call(rbind, exported.dims.ls)) 
row.names(exported.dims.df) <- gsub(".csv", "", basename(exportedfiles))

#-- are there any differences
dims.export.df[order(rownames(dims.export.df)),] == exported.dims.df[order(rownames(exported.dims.df)),]

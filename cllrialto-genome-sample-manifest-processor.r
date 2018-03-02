#-- script to process the genome manifest files found at https://my.huddle.net/workspace/29344763/files/#/folder/43829733/list and the sample manifests received from Liverpool
rm(list = objects())
library(gdata)
library(RCurl)
library(wrangleR)

#-- GENOME MANIFESTS
#-- get list of files
files <- list.files(path = "./data/manifests", pattern = ".csv$", full.names = T)
filenames <- gsub(".csv", "", basename(files))

#-- function to reead in the manifest files
readmanifest <- function(file){
	read.csv(file, header = T, stringsAsFactors = F, skip = 6, na.strings = c(NA, ""))
}

#-- read in the files
dfs <- lapply(files, function(x) readmanifest(x))

#-- make that last file have equivalent column names as others
colnames(dfs[[1]]) <- c("Sample.ID", "Sample.Well", "Unknown4", "Volume..ul.", "Unknown1", "Unknown2", "Unknown3")

#-- make new list that contains only the columns of interest (Sample.ID and Sample.Well)
dfs.slim <- lapply(dfs, function(x) x[,colnames(x) %in% c("Sample.ID", "Sample.Well")])

#-- rbind that down to a dataframe - this gives us all CLL samples that have genomes and they matching Platwell ID, there are some files that have loads of empty rows so need to just select complete.cases
cll.genomes.df <- as.data.frame(do.call(rbind, dfs.slim))
cll.genomes.df <- cll.genomes.df[!is.na(cll.genomes.df),]

#-- make PatientID from the Sample.ID
cll.genomes.df$PatientID <- gsub("^([A-Z]{1})([0-9]{5})([A-Z])_(.+)", "\\1\\2\\3", cll.genomes.df$Sample.ID)
cll.genomes.df$PatientID[!grepl("^([A-Z]{1})([0-9]{5})([A-Z])_(.+)", cll.genomes.df$Sample.ID)] <- NA

#-- remove anything that isn't relevant
cll.genomes.df <- cll.genomes.df[!is.na(cll.genomes.df$PatientID),]

#-- read in the upload report
seqrep <- getURL('https://upload-reports.gel.zone/upload_report.latest.txt')
sequencing_report <- read.table(textConnection(seqrep),
				     stringsAsFactors = F,
				     sep = "\t",
				     col.names = c("No", "Type", "Platekey", "DeliveryID", "Delivery Date", "Path", "BAM Date", "BAM Size", "Status", "Delivery Version"),
				     comment.char = "#"
				     )

#-- remove some columns from sequencing report that are not needed
sequencing_report <- sequencing_report[,!colnames(sequencing_report) %in% c("No", "Type")]

#-- merge the upload report into the genomes manifest by Platekey
cll.genomes.df <- merge(cll.genomes.df, sequencing_report, by.x = "Sample.Well", by.y = "Platekey", all.x = T)

#-- make a build column that says whether genome is b37 or b38, reinstate NAs afterwards
cll.genomes.df$Build <- ifelse(cll.genomes.df$Delivery.Version %in% c("V1", "V2", "V3"), "b37", "b38")
cll.genomes.df$Build[is.na(cll.genomes.df$Delivery.Version)] <- NA

#-- write that out
saveRDS(cll.genomes.df, file = "cll-genomes-manifest.rds")

#-- BIOBANK MANIFESTS
#-- function to read in the xlsx file as a dataframe
readxlsx <- function(filename){
	#-- make our object name
	a <- read.xls(filename,
		      na.strings = c("", "NA"),
		      comment.char = "",
		      stringsAsFactors = F)
	#-- add origin
	a$origin <- filename
	return(a)
}

#-- get list of biobank manifests
files <- list.files(path = "./data/biobankmanifests", pattern = ".xlsx$", full.names = T)
filenames <- gsub(".xlsx", "", basename(files))

#-- read the files in
dfs <- lapply(files, function(x) readxlsx(x))
names(dfs) <- filenames

#-- only interested in Rialto and CLL210 for the moment, and only TiralNo and Patient ID, so just extract that
cll210.rialto <- rbind(dfs[["CLL210Samples"]][c("PatientID", "TrialNo", "origin")],
		       dfs[["RialtoSamples"]][c("PatientID", "TrialNo", "origin")],
		       dfs[["ExtraRialtoSamples"]][c("PatientID", "TrialNo", "origin")])

#-- need to look at this, there is one PatientID that has (CLL210) after it so remove that
cll210.rialto$PatientID <- gsub(" (CLL210)", "", cll210.rialto$PatientID, fixed = T)

#-- write that file out
saveRDS(cll210.rialto, file = "cll210-rialto-sample-manifest.rds")

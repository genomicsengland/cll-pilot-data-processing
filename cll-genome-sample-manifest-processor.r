#-- script to process the genome manifest files found at https://my.huddle.net/workspace/29344763/files/#/folder/43829733/list and the sample manifests received from Liverpool
rm(list = objects())
library(gdata)
library(RCurl)
library(wrangleR)

#-- GENOME MANIFESTS
#-- get list of files
files <- list.files(path = "received-clinical-datasets/manifests", pattern = ".csv$", full.names = T)
filenames <- gsub(".csv", "", basename(files))

#-- function to reead in the manifest files
readmanifest <- function(file){
	read.csv(file, header = T, stringsAsFactors = F, skip = 6, na.strings = c(NA, ""))
}

#-- read in the files
dfs <- lapply(files, function(x) readmanifest(x))
names(dfs) <- gsub(".csv", "", basename(files))

#-- make weird first file have equivalent column names as others
colnames(dfs[[1]]) <- c("Sample.ID", "Sample.Well", "Unknown4", "Volume..ul.", "Unknown1", "Unknown2", "Unknown3")

#-- sample wells in LP3000* are in wrong format, need to correct
dfs[["LP3000701-T1.new"]]$Sample.Well <- gsub("_DNA", "-DNA", dfs[["LP3000701-T1.new"]]$Sample.Well)
dfs[["LP3000702-GL.new"]]$Sample.Well <- gsub("_DNA", "-DNA", dfs[["LP3000702-GL.new"]]$Sample.Well)

#-- make new list that contains only the columns of interest (Sample.ID and Sample.Well)
dfs.slim <- lapply(dfs, function(x) x[,colnames(x) %in% c("Sample.ID", "Sample.Well")])

#-- rbind that down to a dataframe - this gives us all CLL samples that have genomes and they matching Platwell ID, there are some files that have loads of empty rows so need to just select complete.cases
cll.genomes.df <- as.data.frame(do.call(rbind, dfs.slim))
cll.genomes.df <- cll.genomes.df[!is.na(cll.genomes.df),]

#-- make PatientID from the Sample.ID, Sample.IDs are a bit of a mess, think the best way to do this is to just remove the _GL and _T1
cll.genomes.df$PatientID <- cll.genomes.df$Sample.ID
cll.genomes.df$PatientID <- gsub("_GL$|_T1$|_T2$|_CLL$|_T1_REPEAT1$", "", cll.genomes.df$PatientID)

#-- remove empty rows
cll.genomes.df <- cll.genomes.df[!is.na(cll.genomes.df$Sample.Well),]

#-- read in the upload report
seqrep <- getur()

#-- remove some columns from sequencing report that are not needed
seqrep <- seqrep[,!colnames(seqrep) %in% c("No", "Type")]

#-- merge the upload report into the genomes manifest by Platekey
cll.genomes.df <- merge(cll.genomes.df, seqrep, by.x = "Sample.Well", by.y = "Platekey", all.x = T)

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
files <- list.files(path = "received-clinical-datasets/biobankmanifests", pattern = ".xlsx$", full.names = T)
filenames <- gsub(".xlsx", "", basename(files))

#-- read the files in
dfs <- lapply(files, function(x) readxlsx(x))
names(dfs) <- filenames

#-- rbind down each of the dataframes, only including PatientID, TrialNo, and origin.
biobank_manifest <- do.call(rbind, lapply(dfs, subset, select=c("PatientID", "TrialNo", "origin")))
biobank_manifest$PatientID <- gsub(" (CLL210)", "", biobank_manifest$PatientID, fixed = T)

#-- got a lot of trial numbers with / instead of - separating the two numbers. Easier if everything in the same format so change it
biobank_manifest$TrialNo <- gsub("/", "-", biobank_manifest$TrialNo)

#-- write that file out
saveRDS(biobank_manifest, file = "cll-sample-manifest.rds")

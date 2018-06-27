#-- script to generate the genome table as a stop-gap for Flair
rm(list = objects())
options(stringsAsFactors = FALSE,
	scipen = 200)
library(wrangleR)

#-- for reading excel files
library(gdata)

#-- function to write out files
writefile <- function(df, filename, separator = "\t"){
	write.table(df,
		    sep = separator,
		    paste0(filename, ".txt"),
		    row.names = F,
		    quote = F,
		    na= "")
}

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

#-- only interested in the CLLFlair participants at this point
consent.manifest <- consent.manifest[consent.manifest$Trial == "CLLFlair",]

#-- flag those who have a genome
consent.manifest$in.genome.manifest <- consent.manifest$PatientID %in% genome.manifest$PatientID

#-- select participants to take forward
#-- got a genome AND (got valid consent OR are deceased) AND don't have an outstanding consent query AND have a PatientID
consent.manifest$export.to.research  <- consent.manifest$in.genome.manifest &
				( consent.manifest$Valid.consent | consent.manifest$Patient.deceased ) &
				!consent.manifest$Outstanding.consent.query &
				!is.na(consent.manifest$PatientID)

#-- merge in the genomes table
genomes.table <- merge(consent.manifest, genome.manifest, by = "PatientID", all.x = T)
#-- sort out column order to match other genomes tables
colorder <- c("PatientID", "Sample.Well", "Sample.ID", "DeliveryID", "Delivery.Date", "Path", "BAM.Date", "BAM.Size", "Status", "Delivery.Version", "Build", "TrialNo")
genomes.table <- genomes.table[genomes.table$export.to.research, colorder]

#-- write out the files
writefile(genomes.table, "flair-interim-genomes-table.txt")
writefile(consent.manifest, "flair-interim-participant-manifest.txt")

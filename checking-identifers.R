#-- script to try and make sense of all the different identifiers and make consent manifest the single source of truth
#-- consists of reading in various different identifiers and trying to assign individuals to groups based on
#-- what identifiers we have and what matches with what, can then target where to look for whom to correct any errors
rm(list = objects())
options(stringsAsFactors = FALSE,
	scipen = 200)
library(wrangleR)
library(gdata)

#-- COHORT SELECTION
#-- read in Excel consent manifest file, then drop the unnecessaries
con <- read.xls("CLL consent spreadsheet_MASTER.xlsx", stringsAsFactors = F)
con <- dropnrename(con,
				c("Row.ID"
				  , "Trial.Name"
	,"BiobankPatientID"
	,"Trial.Number."
	,"Valid.Consent"
	,"Outstanding.consent.query"
	,"Patient.deceased"
	,"Partial.consent"),
	c("consent.id",
	  "Trial"
	,"PatientID"
	,"TrialNo"
	,"Valid.consent"
	,"Outstanding.consent.query"
	,"Patient.deceased"
	,"Partial.consent")
	)


#-- read in sample and consent manifest files
sam <- readRDS("cll-sample-manifest.rds")
gen <- readRDS("cll-genomes-manifest.rds")

#-- flags for whether patient id and trial num match up
con$patient.id.in.biobank.manifest <- con$PatientID %in% sam$PatientID
con$trial.no.in.biobank.manifest <- con$TrialNo %in% sam$TrialNo
con$patient.id.in.genome.manifest <- con$PatientID %in% gen$PatientID

#-- collect together trial numbers from clinical data
gettn <- function(dir, field){
	files <- list.files(dir, full.names = T)
	tabs <- lapply(files, FUN = function(x){
			       a <- read.table(x, sep = "\t", header = T, stringsAsFactors = F, quote = "")
			       return(a[[field]])
		})
	out <- unique(unlist(tabs))
	return(out[out != ""])
}
arctic.trialnos <- gettn("research-datasets/arctic", "TrialNo")
admire.trialnos <- gettn("research-datasets/admire", "TrialNo")
cll210.trialnos <- gettn("research-datasets/cll210", "TrialNo")
rialto.trialnos <- gettn("research-datasets/rialto", "TrialNo")

#-- flag whether trialno in clinical data
con$trialno.in.arctic.cd <- con$TrialNo %in% arctic.trialnos
con$trialno.in.admire.cd <- con$TrialNo %in% admire.trialnos
con$trialno.in.cll210.cd <- con$TrialNo %in% cll210.trialnos
con$trialno.in.rialto.cd <- con$TrialNo %in% rialto.trialnos
con$trialno.in.any.cd <- con$TrialNo %in% c(arctic.trialnos, admire.trialnos, cll210.trialnos, rialto.trialnos)

con$category <- NA
con$category[!con$trialno.in.any.cd & con$patient.id.in.genome.manifest & con$patient.id.in.biobank.manifest & !con$trial.no.in.biobank.manifest] <- "trial no in consent manifest might be wrong, check biobank manifest"
con$category[con$trialno.in.any.cd & con$trial.no.in.biobank.manifest & !con$patient.id.in.genome.manifest & !con$patient.id.in.biobank.manifest] <- "patient id in consent manifest might be wrong, check biobank manifest"
con$category[!con$trialno.in.any.cd & con$patient.id.in.biobank.manifest & con$trial.no.in.biobank.manifest] <- "consent manifest agrees with biobank manifest, prob no cd sent but check trialNo is normal format"
con$category[con$trialno.in.any.cd & con$patient.id.in.biobank.manifest & con$trial.no.in.biobank.manifest & con$patient.id.in.genome.manifest] <- "everything agrees woohoo!"
con$category[!con$trialno.in.any.cd & !con$patient.id.in.biobank.manifest & !con$trial.no.in.biobank.manifest & !con$patient.id.in.genome.manifest] <- "no external record of this person"
con$category[!con$trialno.in.any.cd & !con$patient.id.in.biobank.manifest & !con$trial.no.in.biobank.manifest & con$patient.id.in.genome.manifest] <- "sample sequenced but no link to the person"
con$category[con$trialno.in.any.cd & (!con$patient.id.in.biobank.manifest | !con$trial.no.in.biobank.manifest) & con$patient.id.in.genome.manifest] <- "we can link this person but doesn't agree with what biobank has"
con$category[is.na(con$category) & (con$patient.id.in.biobank.manifest | con$trial.no.in.biobank.manifest)] <- "biobank manifest matches on either patient id or trial no"

#-- merge in trial number from biobank into con
con <- merge(con, unique(sam[,c("PatientID", "TrialNo")]), by = "PatientID", suffixes = c("", ".biobank"), all.x = T)
con <- merge(con, unique(sam[,c("PatientID", "TrialNo")]), by = "TrialNo", suffixes = c("", ".biobank"), all.x = T)

write.table(con, "~/scratch/con.txt", sep = "\t",  row.names = F)

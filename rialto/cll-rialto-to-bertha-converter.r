#-- script to convert the cll rialto research tables into Bertha-digestible form
rm(list = objects())

#-- read in the research tables
d <- readRDS("rialto-research-data.rds")

#-- create indices in genomes table for germline and tumour samples
germ <- which(grepl("_GL", d[["genomes"]]$Sample.ID)) 
tum <- which(!grepl("_GL", d[["genomes"]]$Sample.ID))

#-- assemble the tables to export
o <- list(
	  "participant" = data.frame(
		"individualId" = d[["dbo_R_RIALtO_Registration1"]]$TrialNo,
		"center" = "RTH",
		"sex" = d[["dbo_R_RIALtO_Registration1"]]$REGSex,
		"yearOfBirth" = d[["dbo_R_RIALtO_Registration1"]]$REGYOB,
		"primaryFindingConsent" = TRUE,
		"programmeConsent" = TRUE,
		"carrierStatusConsent" = TRUE,
		"secondaryFindingConsent" = TRUE,
		stringsAsFactors = F
				     ),
	  "germlineSamples" = data.frame(
		"individualId" = d[["genomes"]]$TrialNo[germ],
		"sampleId" = d[["genomes"]]$Sample.Well[germ],
		"labSampleId" = d[["genomes"]]$Sample.ID[germ],
		"LDPCode" = "RTH",
		"source" = "SALIVA",
		"preparationMethod" = "ORAGENE",
		"product" = "DNA",
		"programmePhase" = "CLL",
		stringsAsFactors = F
					 ),
	  "tumourSamples" = data.frame(
		"individualId" = d[["genomes"]]$TrialNo[tum],
		"sampleId" = d[["genomes"]]$Sample.Well[tum],
		"labSampleId" = d[["genomes"]]$Sample.ID[tum],
		"LDPCode" = "RTH",
		"tumourId" = d[["genomes"]]$Sample.ID[tum],
		"programmePhase" = "CLL",
		"diseaseType" = "HAEMONC",
		"diseaseSubType" = "CHRONIC_LYMPHOCYTIC_LEUKAEMIA",
		"tumourType" = "PRIMARY",
		"source" = "BLOOD",
		"preparationMethod" = "EDTA",
		"tissueSource" = "NA",
		stringsAsFactors = F
				      )
	  )

#-- merge in Baseline2.sample_sal_date into the germlineSamples table
o[["germlineSamples"]] <- merge(o[["germlineSamples"]],
				d[["dbo_R_RIALtO_Baseline2"]][,c("TrialNo", "sample_sal_date")],
				by.x = "individualId",
				by.y = "TrialNo",
				all.x = T)

#-- change column name to clinicSampleDateTime
colnames(o[["germlineSamples"]])[colnames(o[["germlineSamples"]]) == "sample_sal_date"] <- "clinicSampleDateTime"

#-- merge in Baseline2.sample_40_date and BMT_CLLCells into the tumourSample table
o[["tumourSamples"]] <- merge(o[["tumourSamples"]],
			      d[["dbo_R_RIALtO_Baseline2"]][,c("TrialNo", "sample_40_date", "BMT_CLLCells")],
			      by.x = "individualId",
			      by.y = "TrialNo",
			      all.x = T)

#-- change BMT_CLLCells column name to tumourContent and sample_40_date to clinicSampleDateTime
colnames(o[["tumourSamples"]])[colnames(o[["tumourSamples"]]) == "BMT_CLLCells"] <- "tumourContent"
colnames(o[["tumourSamples"]])[colnames(o[["tumourSamples"]]) == "sample_40_date"] <- "clinicSampleDateTime"

#-- make the matchedSamples table, basically merge two separate slices of the genomes table,
#-- the germline samples and the tumour samples, by TrialNo
o[["matchedSamples"]] <- merge(d[["genomes"]][germ, c("TrialNo", "Sample.Well")],
			       d[["genomes"]][tum, c("TrialNo", "Sample.Well")],
			       by = "TrialNo",
			       suffixes = c(".germ", ".tum"),
			       all = T
			       )

#-- tidy up the column names
colnames(o[["matchedSamples"]]) <- c("individualId", "germlineSampleId", "tumourSampleId")

#-- write out the list as an rds
saveRDS(o, "rialto-bertha-tables.rds")

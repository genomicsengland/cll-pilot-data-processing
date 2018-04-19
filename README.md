# CLL Data Processing

[GitHub repo](https://github.com/genomicsengland/cll-pilot-data-processing)

# Identifiers

There are various identifiers used in the CLL datasets:

* `PersonId` - is an incrementing integer

* `PatientNo` - is an incrementing integer, though often it looks like `PersonId` and `PatientNo` are the same, that is not always the case.

* `TrialNo` - is a combination of `HospitalSite` and `PatientNo`. It is `HospitalSite` as three digits, a hyphen, then `PatientNo` as four digits. e.g. `011-0675`

* `PatientID` - is assigned at the liverpool biobank and is an alphanumeric code where the first and last character are the first and last initials of the participant. As far as I can tell the numeric bit in the middle is not based on any other identifier.

* `Sample.ID` - is `PatientID` with suffix of generally either `_GL` or `_T1` based on whether that sample is a germline or somatic sample. There are other somatic suffixes.

* `Sample.Well` - is the standard platekey that identifies the plate and well that was used during sequencing e.g. `LP1234567-DNA_A01`.

## Admire and Arctic

Fabrizio has sent file spreadsheet that links trial number (in Admire and Arctic is in 000/00000 format where first digits are hospital site and second set are PatNo). Change / in trialNo to - to match other trials. Use this file to link consent manifest to patient clinical data. Convert this into another text file, trialnos.csv, becomes the starting point for the participant manifest.

# Data files

We get clinical data in a number of Excel spreadsheets for the CLL trials. There is also a Schema within each archive. The Schema doesn't match (in terms of tables) 100% with what we receive, some tables are named differently and we don't seem to receive all the tables cited in the Schema. However in terms of column names these seem to match what we get.

Bahareh occassionally receives files from the Liverpool biobank (via [Melanie Oates](M.Oates@liverpool.ac.uk)) which give the `PatientID` that have been generated for the participants.

Illumina send GEL the genome manifests that link the `PatientID` to the `Sample.Well`. These individual manifests are  [available on Huddle](https://my.huddle.net/workspace/29344763/files/#/folder/43829733/list).

Dina has been through all the consents manually and generated a manifest of completed consent forms. This file attempts to assign TrialNo and PatientID to each consent form. [This file](https://my.huddle.net/workspace/38658629/files/#/59413080) is now the central manifest for cohort selection, and has been incrementally updated as new TrialNo:PatientID:consent pairings are discovered.

## Manual changes to data

1. The genome manifests are not all in exactly the same format, the most common format is to have 6 header rows before the data starts. Files that don't have those 6 rows are:

	* `LP2000773-GL.new.csv`

	* `LP2000778-T1.new.csv`

	* `LP2000294-GL-comp.csv`

    So for the sake of convenience I altered these csvs after downloading them so that they have 6 rows before the data header (it doesn't matter what is in those header rows, they get skipped when reading them in, they just need to exist). N.B. `LP2000294-GL-comp.csv` doesn't have the same column headings as the other files, so these are altered in the script.

2. In order to ensure that the new set of data includes all data that was previously released to the Research Environment I created an extra biobank manifest called `ExtraRialtoSamples.xlsx` which contains four individuals that were in the Rialto data currently available in the Research Environment, in the clinical data, in the genome manifests, but were not in the biobank manifests, likely because we received the last files from Liverpool several months before processing.

3. The platekeys in LP2000295-T1-comp.csv are not correctly formatted, the well coordinates are lacking the leading zero (i.e. `LP2000295-DNA_A1` should be `LP2000295-DNA_A01`) so do not match the upload report. They were manually changed in the source csv file.

# PID fields

After looking through the data fields, the following fields were removed from the Rialto clinical data prior to release to the research environment:

* `CompBy` - the full name of the person completing the data;
	 
* `PatInitials` - the initials of the patient (though this is available through `PatientId` if researchers are aware of how it is constructed);
	 
* `INVName` - the full name of the investigator;
	 
* `REGConsultant` - the consultant's name;
	 
* `REGCurrentSite` - code for the registration hospital;
	
* `REGHospitalSite` - code for the registration hospital site if different to randomising site;
	
* `RandCheckedBy` - code to full name of the person checking randomisation;

* `RandomisedBy` - code to full name of person doing randomising;

* `DTHInfSrc_Other` - free text providing other death details;

* `QL30Initials` - another instance of patient initials;

* `NHSNo` - patient NHS number.

Some of these fields are present across multiple tables, all instances of the field names are removed.

There are numerous comments fields throughout the data that have not been removed.

## CLL210

The only addition to these columns in CLL210 (not all of the above are present in the CLL210 data however) is `DTHCauseOthr`.

# Consent check / Cohort selection

Bahareh has been receiving the hard copies of the consent forms and Dina has been through each of the received consent forms to establish whether they are valid and to which individual they belong. The assignment of consent form to individual is done using `PatientID` and `TrialNo`, with the consent manifest file being updated accordingly. Often times the `TrialNo` noted on the consent form is invalid (usually due to too few digits), in which case the correct `TrialNo` is confirmed by checking patient initials and date of birth within the clinical data. The final cohort is comprised of individuals who: (have valid consent OR are deceased) AND have been sequenced AND do not have any outstanding consent queries AND have a valid TrialNo. 

# Processing steps

## Clinical Data

1. I elected to convert the xlsx to pipe-delimited files before importing them into R, it speeds things up greatly and there were weird characters that gdata didn't like. For this I installed gnumeric and then used the ssconvert command-line tool. On Mac you can install gnumeric with `brew install gnumeric`. The following shell script will convert the extracted xlsx files:

```bash
#!/bin/bash
for file in *.xlsx
do ssconvert -O 'separator=|' $file ${file%.xlsx}.txt
done
```

2. These pipe-delimited files are read into a list and summary files of the dimensions of each table and the n of records and n missing for each field are produced.

3. `TrialNo` is made as described above.

4. PID columns are removed from each dataframe.

5. The list of valid `PersonId`s is made using the cohort definition above.

6. Invalid participants are removed from the dataframes.

7. Each dataframe is written out as a pipe-delimited csv file.

8. The number of lines and columns in those exported files are checked against the matching dataframe within the R environment.

These steps are covered in `cllrialto-data-processor.r`

## Genome manifests

1. Each of the genome manifests are read in as elements in an list;

2. Extraneous columns are removed so just `Sample.ID` and `Sample.Well` remain.

3. The slim list is rbind'ed down into a dataframe.

4. `PatientID` is made from `Sample.ID` using the following which seems to account for some variation in the exact pattern of `Sample.ID`:

	```
	
	cll.genomes.df$PatientID <- gsub("^([A-Z]{1})([0-9]{5})([A-Z])_(.+)", "\\1\\2\\3", cll.genomes.df$Sample.ID)
	cll.genomes.df$PatientID[!grepl("^([A-Z]{1})([0-9]{5})([A-Z])_(.+)", cll.genomes.df$Sample.ID)] <- NA
	
	```

5. Anything that doesn't have a PatientID is removed.

## Biobank manifests

1. Each of the biobank manifests (including the extra rialto samples) are read into a list using gdata.

2. Anything but CLL210 and Rialto samples are removed, and the remaining are rbind'ed down into a data.frame;

3. There is a patient that has (CLL210) after their PatientID, this is removed. This listing at this point should be checked for similar issues.

Both genome manifests and biobank manifests are processed in `cllrialto-genome-sample-manifest-processor.r`. With the creation of the consent manifest, the biobank sample manifest is no longer a crucial file, but was used as another source of potential TrialNo:PatientID pairings.

# Preparing data for Bertha ingestion

CLL data has also been used by Bioinformatics to test their Haemonc interpretation pipeline, `cll-rialto-bertha-processor.r` script subsets data from the processed research dataset and pulls it into a set of tables ready for ingestion into Bertha.

The mapping of fields from the Rialto data model to the Bertha data model was agreed upon by Angela Hamblin (as someone familiar with the Rialto eligibility and trial protocol) and Alona Sosinsky (as someone familiar with the Bertha data model). The final structure was:

* `participant`
	* `center` – RTH (this is the Oxford ODS code)
	* `sex` – `registration1.regSEX`
	* `yearOfBirth` – generate from `registration1.regDOB`
	* `individualId` - `TrialNo`
* `consentStatus`
	* `primaryFindingConsent` - TRUE 
	* `programmeConsent` - TRUE
	* `carrierStatusConsent` - FALSE
	* `secondaryFindingConsent` - FALSE
* `germlineSamples`
	* `sampleId` – `Sample.Well` for all germline samples
	* `labSampleId` - `Sample.ID` for all germline samples
	* `LDPCode` – RTH (see `center` above)
	* `source` – SALIVA (germline samples come from saliva)
	* `preparationMethod` - ORAGENE
	* `product` – DNA
	* `programmePhase` - CLL
	* `clinicalSampleDateTime` – `Baseline2.sample_sal_date`
* `tumourSamples`
	* `sampleId` - `Sample.Well` for all somatic samples
	* `labSampleId` - `Sample.ID` for all somatic samples
	* `LDPCode` – RTH
	* `tumourId` - `Sample.ID` for all somatic samples
	* `programmePhase` - CLL
	* `diseaseType` – HAEMONC
	* `diseaseSubType` - CHRONIC_LYMPHOCYTIC_LEUKAEMIA
	* `clinicalSampleDateTime` – `Baseline2.sample_40_date` 
	* `tumourType` – PRIMARY
	* `tumourContent` – `Baseline2.BBMT_CLLCells`
	* `source` – BLOOD
	* `preparationMethod` - EDTA (the actual preparation method, LiHep, is not a valid Bertha option)
	* `tissueSource` – NA (since none of the available options were relevants)
* `matchedSamples`
	* `germlineSampleId` – `SampleID` for the germline:somatic pair
	* `tumourSampleId` – `SampleID` for the germline:somatic pair

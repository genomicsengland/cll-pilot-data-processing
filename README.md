# CLL Data Processing

[GitHub repo](https://github.com/genomicsengland/cll-pilot-data-processing)

[cohort db schema info](https://cnfl.extge.co.uk/display/CDT/Index+databases+%3E+schemas)

# Identifiers

There are various identifiers used in the CLL datasets:

* `PersonId` - is an incrementing integer
* `PatientNo` or `PatNo` - is an incrementing integer, though often it looks like `PersonId` and `PatientNo` are the same, that is not always the case.
* `TrialNo` - is a combination of `HospitalSite` and `PatientNo`. It is `HospitalSite` as three digits, a hyphen, then `PatientNo` as four digits. e.g. `011-0675`
* `PatientID` - is assigned at the liverpool biobank and is an alphanumeric code where the first and last character are the first and last initials of the participant. As far as I can tell the numeric bit in the middle is not based on any other identifier.
* `Sample.ID` - is `PatientID` with suffix of generally either `_GL` or `_T1` based on whether that sample is a germline or somatic sample. There are other somatic suffixes.
* `Sample.Well` - is the standard platekey that identifies the plate and well that was used during sequencing e.g. `LP1234567-DNA_A01`.

In short the following tables provide the various linkages:

* `<study>.trialno` - provides the link between `TrialNo` and `PatientNo`, `PersonId`, or `PatNo` depending on the identifier used in the clinical data;
* `cll_common.consent_manifest` - provides the link between `TrialNo` and `PatientID`;
* `cll_common.sequencing_manifest` - provides the link between `PatientID`, `Sample.ID`, and `Sample.Well`.

## Flair

In the data sent at the beginning of January 2019, there was no link between `TrialNo` and `PatNo`, though the consent manifest has `TrialNo` for Flair participants.
After discussions with Jamie Oughton (the trial manager) he suggested that for each of the Flair participants the second half of the `TrialNo` should uniquely match to the `PatNo` entries given in the received clinical data.
Therefore the `flair.trialno` tables is composed of inferred linkages between `TrialNo` and `PatNo` based on the what was found for both identifiers in the cosnent manifest and clinical data.

# Data files

We get clinical data in a number of Excel spreadsheets for the CLL trials.
There is also a Schema within each archive.
The Schema doesn't match (in terms of tables) 100% with what we receive, some tables are named differently and we don't seem to receive all the tables cited in the Schema.
However in terms of column names these seem to match what we get.

Bahareh occassionally receives files from the Liverpool biobank (via [Melanie Oates](M.Oates@liverpool.ac.uk)) which give the `PatientID` that have been generated for the participants.
The pairings of `TrialNo`:`PatientID` have been incorporated into the consent manifest, therefore these files are not used in dataset generation.

Illumina send GEL the genome manifests that link the `PatientID` to the `Sample.Well`.
These individual manifests are  [available on Huddle](https://my.huddle.net/workspace/29344763/files/#/folder/43829733/list) and have been ingested into `cll_common.sequencing_manifest`.

The `cll-genome-sample-manifest-processor.r` script processing both the genome manifests and sample manifests to generate amalgamated, cleaned versions ready for upload.

Dina went through all the consents manually and generated a manifest of completed consent forms.
This file is available [on Huddle](https://my.huddle.net/workspace/38658629/files/#/59413080) but has been since moved to `cll_common.consent_manifest` so should be considered out of date.
Any updates should be made to this table.

## Original data

The original data files sent for each installment of clinical data, alongside the genome and sample manifests, are stored [on Huddle](https://my.huddle.net/workspace/38643292/files/#/folder/45575695/list).

## Manual changes to data

1. The genome manifests are not all in exactly the same format, the most common format is to have 6 header rows before the data starts. Files that don't have those 6 rows are:

	* `LP2000773-GL.new.csv`
	* `LP2000778-T1.new.csv`
	* `LP2000294-GL-comp.csv`

    So for the sake of convenience I altered these csvs after downloading them so that they have 6 rows before the data header (it doesn't matter what is in those header rows, they get skipped when reading them in, they just need to exist). N.B. `LP2000294-GL-comp.csv` doesn't have the same column headings as the other files, so these are altered in the script.

1. In order to ensure that the new set of data includes all data that was previously released to the Research Environment I created an extra biobank manifest called `ExtraRialtoSamples.xlsx` which contains four individuals that were in the Rialto data currently available in the Research Environment, in the clinical data, in the genome manifests, but were not in the biobank manifests, likely because we received the last files from Liverpool several months before processing.

1. The platekeys in LP2000295-T1-comp.csv are not correctly formatted, the well coordinates are lacking the leading zero (i.e. `LP2000295-DNA_A1` should be `LP2000295-DNA_A01`) so do not match the upload report. They were manually changed in the source csv file.

# PID fields

## Rialto

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

## Flair

The Flair clinical data includes `NHSF04` which is removed for the research release, and `DOBF04` which is converted to year of birth for the research release.

# Consent check / Cohort selection

Bahareh has been receiving the hard copies of the consent forms and Dina has been through each of the received consent forms to establish whether they are valid and to which individual they belong.
The assignment of consent form to individual is done using `PatientID` and `TrialNo`, with the consent manifest file being updated accordingly.
Often times the `TrialNo` noted on the consent form is invalid (usually due to too few digits), in which case the correct `TrialNo` is confirmed by checking patient initials and date of birth within the clinical data.
The final cohort is comprised of individuals who: (have valid consent OR are deceased) AND have been sequenced AND do not have any outstanding consent queries.

# Processing steps

## Upload to `cohorts` db

1. The original Excel files were converted to pipe-separated text files (see below) and then uploaded to the relevant schema on `cohorts` database using ddl-genie.
1. The `trialno` table was constructed for each study.
1. For each table a separate SQL script specifies which fields (and any transformations needed) are read from each table.
1. The processor script for each study executes these SQL scripts, generates the cohort, filters out invalid participant's data from each table and writes out the final tables.

```bash
#!/bin/bash
for file in *.xlsx
do ssconvert -O 'separator=|' $file ${file%.xlsx}.txt
done
```
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

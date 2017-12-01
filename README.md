CLL Data Processing

# Identifiers

There are various identifiers used in the CLL datasets:

* `PersonId` - is an incrementing integer

* `PatientNo` - is an incrementing integer

* `TrialNo` - is a combination of `HospitalSite` and `PatientNo`. It is `HospitalSite` as three digits, a hyphen, then `PatientNo` as four digits. e.g. `011-0675`

* `PatientID` - is assigned at the liverpool biobank and is an alphanumeric code where the first and last character are the first and last initials of the participant. As far as I can tell the numeric bit in the middle is not based on any other identifier.

* `Sample.ID` - is `PatientID` with suffix of either `_GL` or `_T1` based on whether that sample is a germline or somatic sample.

* `Sample.Well` - is the standard platekey that identifies the plate and well that was used during sequencing e.g. `LP1234567-DNA_A01`.

# Data files

We get clinical data in a number of Excel spreadsheets for the CLL trials. There is also a Schema within each archive. The Schema doesn't match (in terms of tables) 100% with what we receive, some tables are named differently and we don't seem to receive all the tables cited in the Schema. However in terms of column names these seem to match what we get.

Bahareh occassionally receives files from the Liverpool biobank (via [Melanie Oates](M.Oates@liverpool.ac.uk)) which give the `PatientID` that has been generated for which participants.

Illumina send GEL the genome manifests that link the `PatientID` to the `Sample.Well`. These individual manifests are  [available on Huddle](https://my.huddle.net/workspace/29344763/files/#/folder/43829733/list).

## Manual changes to data

1. The genome manifests are not all in exactly the same format, the most common format is to have 6 header rows before the data starts. Files that don't have those 6 rows are:

	* `LP2000773-GL.new.csv`

	* `LP2000778-T1.new.csv`

	* `LP2000294-GL-comp.csv`

    So for the sake of convenience I altered these csvs after downloading them so that they have 6 rows before the data header (it doesn't matter what is in those header rows, they get skipped when reading them in, they just need to exist). N.B. `LP200294-GL-comp.csv` also doesn't have same column headings, so these are altered in the script.

2. In order to ensure that the new set of data includes all data that was previously released to the Research Environment I created an extra biobank manifest called `ExtraRialtoSamples.xlsx` which contains four individuals that were in the Rialto data currently available in the Research Environment, in the clinical data, in the genome manifests, but were not in the biobank manifests, likely because we received the last files from Liverpool several months before processing.

# PID fields

After looking through the data fields, the following fields were removed from the clinical data prior to release to the research environment:

* `CompBy` - the full name of the person completing the data;
	 
* `PatInitials` - the initials of the patient (though this is available through `PatientId` if researchers are aware of how it is constructed);
	 
* `INVName` - the fulle name of the investigator;
	 
* `REGConsultant` - the consultant's name;
	 
* `REGCurrentSite` - code for the registration hospital;
	
* `REGHospitalSite` - code for the registration hospital site if different to randomising site;
	
* `RandCheckedBy` - code to full name of the person checking randomisation;

* `RandomisedBy` - code to full name of person doing randomising;

* `DTHInfSrc_Other` - free text providing other death details.

Some of these fields are present across multiple tables, all instances of the field names are removed.

> We need to check this, are we ok to include Date of Birth?

# Consent check / Cohort selection

Bahareh has been receiving the hard copies of the consent forms. The list of individuals to include in the cohort is based on them having a genome (i.e.  being listed in the genome manifests), and present within a list of individuals for which Bahareh has received a consent form and has not raised any queries regarding it.

# Processing steps

## Clinical Data

1. I elected to convert the xlsx to pipe-delimited files before importing them into R, it speeds things up greatly and there were weird characters that gdata didn't like. For this I installed gnumeric and then used the ssconvert command-line tool. On Mac you can install gnumeric with `brew install gnumeric`. The following shell script will convert the extracted xlsx files:

```bash
#!/bin/bash
for file in *.xlsx
do ssconvert -O 'separator=|' $file ${file%.xlsx}.txt
done
```

2. These pipe-delimited are read into a list and summary files of the dimensions of each table and the n of records and n missing for each field are produced.

3. `TrialNo` is made as described above.

4. PID columns are removed from each dataframe.

5. The list of valid `PersonId`s is made by selecting only those participants whose `TrialNo` is present in the sample manifest (construction described below).

6. Invalid participants are removed from the dataframes.

7. Each dataframe is written out as a pipe-delimited csv file.

8. The number of lines and columns in those exported files are checked against the matching dataframe within the R environment.

These steps are covered in `cllrialto-data-processor.r`

## Genome manifests

1. Each of the genome manifests are read in as elements in an list;

2. Extraneous columns are removed so just `Sample.ID` and `Sample.Well` remain.

3. The slim list is rbind'ed down into a dataframe.

4. `PatientID` is made from `Sample.ID` using the following which seems to account some variation in the exact pattern of `Sample.ID`:

	```
	cll.genomes.df$PatientID <- gsub("^([A-Z]{1})([0-9]{5})([A-Z])_(.+)", "\\1\\2\\3", cll.genomes.df$Sample.ID)
	cll.genomes.df$PatientID[!grepl("^([A-Z]{1})([0-9]{5})([A-Z])_(.+)", cll.genomes.df$Sample.ID)] <- NA`
	```

5. Anything that doesn't have a PatientID is removed.

## Biobank manifests

1. Each of the biobank manifests (including the extra rialto samples) are read into a list using gdata.

2. Anything but CLL210 and Rialto samples are removed, and the remaining are rbind'ed down into a data.frame;

3. There is a patient that has (CLL210) after their PatientID, this is removed. This listing at this point should be checked for similar issues.

Both genome manifests and biobank manifests are processed in `cllrialto-genome-sample-manifest-processor.r`.

## Participant manifest

During the processing of the clinical data, the genome manifest, consent manifest and biobank manifest are read in and used to make a participant manifest that gives flags for each participants in the clinical data - whether they have been sequenced, whether we have seen a consent form, whether they have project consent according to the REGgenomescon field in Registration1 table. This then determines the cohort exported to the research environment.

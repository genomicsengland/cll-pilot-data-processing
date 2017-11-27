#-- script to process the cll rialto data
rm(list = objects())

#-- to read in xlsx files
library('gdata')

#-- get list of xlsx files in the cll210 directory
files <- list.files(path = "./data/rialto", pattern = "xlsx$") 

#-- function to read in the xlsx file as a dataframe
readxlsx <- function(filename){
	#-- make our object name
	a <- read.xls(paste0("./data/rialto/", filename),
		      na.strings = c("", "NA"),
		      comment.char = "")
	#-- assign the dataframe to an object which is filename without xlsx extension
	assign(gsub(".xlsx", "", filename), a, envir = .GlobalEnv)
}

#-- for each of the files, read them in
for(i in files){
	readxlsx(i)
}

#-- make list of all the dataframes
dfs <- Filter(function(x) is(x, "data.frame"), mget(ls()))

#-- make number of rows and cols for each
dims.ls <- lapply(dfs, function(x) c(nrow(x), ncol(x)))
dims.df <- data.frame("data" = "", "nrows" = "", "ncols" = "", stringsAsFactors = F)
for(i in 1:length(dims.ls)){
	dims.df[i,] <- c(names(dims.ls)[i], dims.ls[[i]][1], dims.ls[[i]][2])
}

#-- write out the dimensions
write.table(dims.df, file = "cllrialto_tabledims.txt", sep = "\t", row.names = F)

#-- get the column headings per table, and number of NAs
field.names <- lapply(dfs, function(x) names(x))
n.missing <- lapply(dfs, function(x) apply(x, 2, function(y) sum(is.na(y))))
n.rows <- lapply(dfs, function(x) apply(x, 2, function(y) length(y)))

#-- convert to data.frame
field.names.df <- as.data.frame(unlist(field.names))
n.missing.df <- as.data.frame(unlist(n.missing))
n.rows.df <- as.data.frame(unlist(n.rows))

#-- bind those together
rialto.summ <- cbind(field.names.df, n.missing.df, n.rows.df)
#-- correct column names
names(rialto.summ) <- c("field.name", "n.missing", "n.rows")
#-- write out the table
write.table(rialto.summ, file = "rialto_data_summary.txt", sep = "\t")

#-- read PersonID from each dataframe
ids <- lapply(dfs, function(x) unique(x$PersonId))

#-- the collapse that down
uniq.person.ids <- sort(
			unique(
				unlist(ids)
			       )
			)

#-- ids to include
ids.to.include <- c(6,9,12,14)

#-- make new list of datamframes that only have those participants we want to include
dfs.export <- lapply(dfs, function(x) x[x$PersonId %in% ids.to.include,])

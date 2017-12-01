#!/bin/bash
for file in data/rialto/*.xlsx
do ssconvert -O 'separator=|' $file ${file%.xlsx}.txt
done

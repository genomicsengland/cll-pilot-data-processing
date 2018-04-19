#!/bin/bash
for file in data/arctic/*.xlsx
do ssconvert -O 'separator=|' $file ${file%.xlsx}.txt
done

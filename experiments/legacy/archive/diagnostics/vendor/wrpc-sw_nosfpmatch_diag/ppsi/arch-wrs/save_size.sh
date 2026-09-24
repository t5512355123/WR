#!/bin/bash

set -e

if ! [ -n "$size_info_file" ]; then
	echo "save_size.sh: 'size_info_file' is empty"
    exit 0
fi

# separate calling commands and filling DB
SIZES=`$1 $2 | grep $2`
#GIT_HASH=`git log --format=format:%H -1`

#echo -n "$GIT_HASH " >> "$size_info_file"
#echo -n "$DEFCONFIG_NAME ">> "$size_info_file"
#echo $SIZES >> "$size_info_file"

echo -n `date -u "+%m/%d/%y_%H:%M:%S"`>> "$size_info_file"
echo -n " $DEFCONFIG_NAME ">> "$size_info_file"
echo -n $SIZES >> "$size_info_file"
echo " Opt=\"$CFLAGS_OPTIMIZATION\"" >> "$size_info_file"
# update file, keeping only non redundant lines
tac "$size_info_file" | awk '!x[$1]++ { print $0 }' | tac >> tmp.txt
mv tmp.txt $size_info_file
rm -f tmp.txt

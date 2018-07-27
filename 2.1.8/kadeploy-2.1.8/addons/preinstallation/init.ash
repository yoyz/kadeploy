#!/bin/ash

REFORMAT_TMP=$1

# source generic variables
. /rambin/preinstall.conf

# Load modules for the harddrive
echo "Loading required modules" > ${TTYS}
for m in $MODULES; do
	echo "Loading ${m}" > ${TTYS}
	modprobe $m
done

# Prepare the disk
. /rambin/partition.ash

echo "Preinstall done\n"
# Duke

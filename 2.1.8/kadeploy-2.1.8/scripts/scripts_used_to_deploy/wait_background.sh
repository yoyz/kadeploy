#!/bin/sh

FILE_LOCK=$1

while [ -f ${FILE_LOCK} ]; do
	sleep 1
done

#
# Harddrive preparation script
#

# Format the harddrive
if [ $DO_FDISK -eq 1 ] ; then
	echo "Partitioning ${HARDDRIVE}" > ${TTYS}
	cat  ${FDISKFILE}  | fdisk ${HARDDRIVE}
fi

# Manage swap partition
if  [ $SWAP_FORMAT -eq 1 ]; then
	echo "Formating swap on partition ${SWAP_PART}" > ${TTYS}
	mkswap ${SWAP_PART}
fi

# Manage /tmp
if [ $REFORMAT_TMP -eq 1 ]; then
	echo "Formatting /tmp on device ${TMP_DEV} with fs ${TMP_FSTYPE}" > ${TTYS}
	mkfs -t ${TMP_FSTYPE} ${TMP_FSTYPE_OPTIONS} ${TMP_PART}
	mount ${TMP_PART} /mnt/tmp
	# deactivate mount count at mount
	tune2fs -c 0 ${TMP_PART}
	# add stickybit on tmp
	chmod 1777 /mnt/tmp
	umount /mnt/tmp
fi

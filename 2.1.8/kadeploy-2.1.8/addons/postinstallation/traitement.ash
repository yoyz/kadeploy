#!/bin/ash

# the directory where the postinstallation is decompressed
TAR_REPOSITORY=$1
# directory where the target partition is mounted when the postinstallation is launched
# it will be the '/' directory on the deployed system
DEST_DIR="/mnt/dest"

###
# fstab nodifications
###
cat ${TAR_REPOSITORY}/fstab > /mnt/dest/etc/fstab
# root device and filesystem
mount | grep mnt\/dest | sed 's/on.*type/   \/   /' | sed 's/(.*/   errors=remount-ro   0   0/' >> ${DEST_DIR}/etc/fstab

###
# modify ssh root access to allow user deploy to log as root without any password
# (to reboot the compute nodes)
###
cat ${TAR_REPOSITORY}/authorized_keys > ${DEST_DIR}/root/.ssh/authorized_keys

###
# Host key modification
# (so that every node always keep the same ssh host key)
###
if [ -d ${DEST_DIR}/etc/ssh ]; then
        echo "ssh directory found, updating host keys" > ${TTYS}
        # DSA
        cat ${TAR_REPOSITORY}/etc/ssh_host_keys/ssh_host_dsa_key > ${DEST_DIR}/etc/ssh/ssh_host_dsa_key
        cat ${TAR_REPOSITORY}/etc/ssh_host_keys/ssh_host_dsa_key.pub > ${DEST_DIR}/etc/ssh/ssh_host_dsa_key.pub
        # RSA
        cat ${TAR_REPOSITORY}/etc/ssh_host_keys/ssh_host_rsa_key > ${DEST_DIR}/etc/ssh/ssh_host_rsa_key
        cat ${TAR_REPOSITORY}/etc/ssh_host_keys/ssh_host_rsa_key.pub > ${DEST_DIR}/etc/ssh/ssh_host_rsa_key.pub
fi

###
# modify some default behaviours of the system
###
#
# debian
#	modify default rcS to a less interactive one
cat ${TAR_REPOSITORY}/rcS > ${DEST_DIR}/etc/default/rcS
###

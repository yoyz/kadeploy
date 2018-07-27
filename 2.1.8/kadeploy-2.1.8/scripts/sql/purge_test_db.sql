##########################################################
# 
# For testing purpose : purge the development/test DB from
# previously inserted records.
#
#########################################################


USE SUBSTmydeploydbtestSUBST;

# Removes records from disk, environment, node, partition and rights tables.
DELETE FROM disk;
DELETE FROM environment;
DELETE FROM node;
DELETE FROM partition;
DELETE FROM rights;





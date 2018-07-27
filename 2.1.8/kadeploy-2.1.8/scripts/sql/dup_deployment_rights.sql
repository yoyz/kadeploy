##########################################################
# 
# For testing purpose : duplicate deployment rights given 
# by a oarsub command to the Kadeploy test DB. 
#
#########################################################


# Removes previously inserted right records
DELETE FROM SUBSTmydeploydbtestSUBST.rights;

# Inserts new deployment rights
INSERT INTO SUBSTmydeploydbtestSUBST.rights (user,node,part) select * from SUBSTmydeploydbSUBST.rights;



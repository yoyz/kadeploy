##########################################################
# 
# For testing purpose : duplicate production DB into 
# the development DB of Kadeploy.
#
#########################################################


# Kadeploy data : disk, environment, node and partition
INSERT INTO SUBSTmydeploydbtestSUBST.disk (id,size,device) select * from SUBSTmydeploydbSUBST.disk;
INSERT INTO SUBSTmydeploydbtestSUBST.environment (id,name,version,description,author,filebase,filesite,size,initrdpath,kernelpath,kernelparam,fdisktype,filesystem,siteid,optsupport,user) select * from SUBSTmydeploydbSUBST.environment;
INSERT INTO SUBSTmydeploydbtestSUBST.node (id,name,macaddr,ipaddr) select * from SUBSTmydeploydbSUBST.node;
INSERT INTO SUBSTmydeploydbtestSUBST.partition (id,pnumber,size) select * from SUBSTmydeploydbSUBST.partition;
INSERT INTO SUBSTmydeploydbtestSUBST.deployed (envid,diskid,partid,nodeid,deployid,state,error_description) select * from SUBSTmydeploydbSUBST.deployed;
INSERT INTO SUBSTmydeploydbtestSUBST.deployment (id,state,startdate,enddate) select * from SUBSTmydeploydbSUBST.deployment;





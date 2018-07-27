###########################
#
# Remove the Deploy DB user 
#
###########################

#-------------
# Use mysql DB
#-------------

USE mysql;


#------------------------------------
# Remove Deploy DB user 
# from mysql.db and mysql.user tables
#------------------------------------

DELETE FROM db WHERE user = 'SUBSTmydeployloginSUBST';
DELETE FROM user WHERE user = 'SUBSTmydeployloginSUBST';


#------------------
# Update privileges
#------------------

FLUSH PRIVILEGES;




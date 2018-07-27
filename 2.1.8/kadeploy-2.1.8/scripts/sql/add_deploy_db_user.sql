########################
# 
# Add the Deploy DB user 
#
########################


#-------------------------------------------------------
# In case of the Deploy DB have not already been created
#-------------------------------------------------------
CREATE DATABASE IF NOT EXISTS SUBSTmydeploydbSUBST;

#-------------
# Use mysql DB
#-------------

USE mysql;

#-----------------------
# Add the Deploy DB user
#-----------------------

INSERT INTO user (Host, User, Password) VALUES('localhost','SUBSTmydeployloginSUBST',PASSWORD('SUBSTmydeploypasswordSUBST'));
INSERT INTO user (Host, User, Password) VALUES('%','SUBSTmydeployloginSUBST',PASSWORD('SUBSTmydeploypasswordSUBST'));


#---------------------------------
# Add privileges to Deploy DB user
# From localhost and any host
#---------------------------------

INSERT INTO db (Host, Db, User, Select_priv, Insert_priv, Update_priv, Delete_priv, Create_priv, Drop_priv, Create_tmp_table_priv, Lock_tables_priv, Alter_priv) \
  VALUES ('localhost','SUBSTmydeploydbSUBST','SUBSTmydeployloginSUBST','Y','Y','Y','Y','Y','Y','Y','Y','Y');
INSERT INTO db (Host, Db, User, Select_priv, Insert_priv, Update_priv, Delete_priv, Create_priv, Drop_priv, Create_tmp_table_priv, Lock_tables_priv, Alter_priv) \
  VALUES ('%','SUBSTmydeploydbSUBST','SUBSTmydeployloginSUBST','Y','Y','Y','Y','Y','Y','Y','Y','Y');


#-------------------------------
# Start using the new privileges
#-------------------------------

FLUSH PRIVILEGES;

# GRANT ALL ON SUBSTmydeploydbSUBST.* TO SUBSTmydeployloginSUBST@localhost;
# GRANT ALL ON SUBSTmydeploydbSUBST.* TO SUBSTmydeployloginSUBST@'%';

# FLUSH PRIVILEGES;



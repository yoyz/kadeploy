# --------------------------------------------------------
# 
# Database : `SUBSTmydeploydbSUBST`
# 
CREATE DATABASE IF NOT EXISTS SUBSTmydeploydbSUBST;

# --------------------------------------------------------
# 
# Users creation
# 

CONNECT mysql;

# Administrator
INSERT INTO user (Host,User,Password) VALUES('localhost','SUBSTmydeployloginSUBST',PASSWORD('SUBSTmydeploypasswordSUBST'));
INSERT INTO db (Host,Db,User,Select_priv,Insert_priv,Update_priv,Delete_priv, Create_priv,Drop_priv) VALUES ('localhost','SUBSTmydeploydbSUBST','SUBSTmydeployloginSUBST','Y','Y','Y','Y','Y','Y');
FLUSH PRIVILEGES;

GRANT ALL ON SUBSTmydeploydbSUBST.* TO SUBSTmydeployloginSUBST@localhost;
FLUSH PRIVILEGES;


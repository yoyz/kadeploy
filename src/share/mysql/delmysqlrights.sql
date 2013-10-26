CONNECT mysql;

DELETE FROM db WHERE user = 'SUBSTmydeployloginSUBST';
DELETE FROM user WHERE user = 'SUBSTmydeployloginSUBST';
FLUSH PRIVILEGES;



CONNECT SUBSTmydeploydbSUBST;

alter table disk add `nodeid` int(10) unsigned NOT NULL default '0';
alter table disk add `dnumber` int(10) unsigned NOT NULL default '1';
alter table disk drop device;
alter table disk add `interface` char(10) NOT NULL default '';
alter table partition add `parttype` char(10) NOT NULL default '';
alter table partition add `diskid` int(10) unsigned NOT NULL default '0';
alter table partition add `label` char(20) NOT NULL default '';
alter table partition add `fs` char(10) NOT NULL default 'ext3';
alter table partition add `mkfs` char(10) NOT NULL default 'no';


drop table rights;
CREATE TABLE IF NOT EXISTS rights (
   `user`   VARCHAR(155) NOT NULL default '',
   `node`   VARCHAR(155) NOT NULL default '',
   `rights` VARCHAR(155) NOT NULL default '',
   PRIMARY KEY (user,node,rights)
   );

drop table environment;
CREATE TABLE IF NOT EXISTS environment 
( 
`id` int(10) unsigned NOT NULL auto_increment,
`name` VARCHAR(255) NOT NULL default '',
`user` VARCHAR(255) NOT NULL default '',
`descriptionfile` VARCHAR(255) NOT NULL default '',
PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS nodestate 
( 
`nodeid` int(10) unsigned NOT NULL, 
`service` VARCHAR(255) NOT NULL default '', 
`state` VARCHAR(255) NOT NULL default '', 
PRIMARY KEY (nodeid,service) 
);


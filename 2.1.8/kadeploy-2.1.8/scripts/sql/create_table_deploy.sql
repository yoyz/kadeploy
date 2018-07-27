# --------------------------------------------------------
#
# Table structure for table `deployed`
#

CREATE TABLE IF NOT EXISTS `deployed` (
  `envid` int(10) unsigned NOT NULL default '0',
  `diskid` int(10) unsigned NOT NULL default '0',
  `partid` int(10) unsigned NOT NULL default '0',
  `nodeid` int(10) unsigned NOT NULL default '0',
  `deployid` int(10) unsigned NOT NULL default '0',
  `state` enum('deployed','to_deploy','deploying','error') NOT NULL default 'deployed',
  `error_description` varchar(255) default NULL,
  PRIMARY KEY  (`envid`,`diskid`,`partid`,`nodeid`,`deployid`)
) TYPE=MyISAM;

# --------------------------------------------------------
#
# Table structure for table `deployment`
#

CREATE TABLE IF NOT EXISTS `deployment` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `state` enum('waiting','running','terminated','error') NOT NULL default 'waiting',
  `startdate` datetime NOT NULL default '0000-00-00 00:00:00',
  `enddate` datetime NOT NULL default '0000-00-00 00:00:00',
  PRIMARY KEY  (`id`)
) TYPE=MyISAM AUTO_INCREMENT=1 ;

# --------------------------------------------------------
#
# Table structure for table `disk`
#

CREATE TABLE IF NOT EXISTS `disk` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `size` int(10) unsigned NOT NULL default '0',
  `device` varchar(255) NOT NULL default '',
  PRIMARY KEY  (`id`)
) TYPE=MyISAM AUTO_INCREMENT=1 ;

# --------------------------------------------------------
#
# Table structure for table `environment`
#

CREATE TABLE IF NOT EXISTS `environment` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `name` varchar(255) NOT NULL default '',
  `version` int(10) unsigned NOT NULL default '0',
  `description` text,
  `author` varchar(56) NOT NULL default '',
  `filebase` varchar(255) NOT NULL default '',
  `filesite` varchar(255) NOT NULL default '',
  `size` int(10) unsigned NOT NULL default '0',
  `initrdpath` varchar(255) NOT NULL default '',
  `kernelpath` varchar(255) NOT NULL default '',
  `kernelparam` varchar(255) NOT NULL default '',
  `fdisktype` int(10) unsigned default NULL,
  `filesystem` varchar(9) default NULL,
  `siteid` int(10) unsigned NOT NULL default '0',
  PRIMARY KEY  (`id`)
) TYPE=MyISAM AUTO_INCREMENT=5 ;

# default values
INSERT INTO `environment` VALUES (1, 'undefined', 1, 'undefined environment', '', '', '', '', '', 0, '', 82, 'undefined', 0);
INSERT INTO `environment` VALUES (2, 'swap', 1, 'swap partition', '', '', '', '', '', 0, '', 82, 'swap', 0);
INSERT INTO `environment` VALUES (3, 'tmp', 1, 'tmp partition', '', '', '', '', '', 0, '', 82, 'ext2', 0);
INSERT INTO `environment` VALUES (4, 'empty', 1, NULL, '', '', '', '', '', 0, '', NULL, '', 0);

# --------------------------------------------------------
#
# Table structure for table `node`
#

CREATE TABLE IF NOT EXISTS `node` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `name` varchar(255) NOT NULL default '',
  `macaddr` varchar(17) NOT NULL default '',
  `ipaddr` varchar(15) NOT NULL default '',
  PRIMARY KEY  (`id`)
) TYPE=MyISAM AUTO_INCREMENT=1 ;

# --------------------------------------------------------
#
# Table structure for table `partition`
#

CREATE TABLE IF NOT EXISTS `partition` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `pnumber` varchar(10) unsigned NOT NULL default '0',
  `size` int(10) unsigned NOT NULL default '0',
  PRIMARY KEY  (`id`)
) TYPE=MyISAM AUTO_INCREMENT=1 ;

# --------------------------------------------------------
#
# Table structure for table `site`
#

CREATE TABLE IF NOT EXISTS `site` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `name` varchar(255) NOT NULL default '',
   #sitefilepath VARCHAR(255) NOT NULL,
   #rootpubkey VARCHAR(255) NOT NULL,
  PRIMARY KEY  (`id`)
) TYPE=MyISAM AUTO_INCREMENT=1 ;

# --------------------------------------------------------
#
# Table structure for table `rights`
#

CREATE TABLE IF NOT EXISTS rights (
   `user` VARCHAR(30) NOT NULL default '',
   `node` VARCHAR(30) NOT NULL default '',
   `part` VARCHAR(5) NOT NULL default '',
  PRIMARY KEY (user,node,part)
);

#
# hex patch previously in patch-kadeploy-2.1.sql
#

update environment set fdisktype = 130 where filesystem='swap';
update environment set fdisktype = 131 where filesystem='ext2';
update environment set fdisktype = 131 where filesystem='ext3';
alter table environment add `optsupport` int(10) unsigned NOT NULL default '0';

#
#Environment linked to a user previously in patch-kadeploy-2.1.1.sql
#

alter table `environment` add user varchar(255) default 'nobody';
update environment set user='deploy' where name='grid5000';
update environment set user='deploy' where name='debian4all';

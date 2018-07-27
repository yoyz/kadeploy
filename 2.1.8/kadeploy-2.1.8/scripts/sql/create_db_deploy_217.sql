-- MySQL dump 10.11
--
-- Host: localhost    Database: deploy
-- ------------------------------------------------------
-- Server version	5.0.45-Debian_1ubuntu3-log

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Current Database: `SUBSTmydeploydbSUBST`
--

CREATE DATABASE /*!32312 IF NOT EXISTS*/ `SUBSTmydeploydbSUBST` /*!40100 DEFAULT CHARACTER SET latin1 */;

USE `SUBSTmydeploydbSUBST`;

--
-- Table structure for table `deployed`
--

DROP TABLE IF EXISTS `deployed`;
CREATE TABLE `deployed` (
  `envid` int(10) unsigned NOT NULL default '0',
  `diskid` int(10) unsigned NOT NULL default '0',
  `partid` int(10) unsigned NOT NULL default '0',
  `nodeid` int(10) unsigned NOT NULL default '0',
  `deployid` int(10) unsigned NOT NULL default '0',
  `state` enum('deployed','to_deploy','deploying','error') NOT NULL default 'deployed',
  `error_description` varchar(255) default NULL,
  PRIMARY KEY  (`envid`,`diskid`,`partid`,`nodeid`,`deployid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `deployment`
--

DROP TABLE IF EXISTS `deployment`;
CREATE TABLE `deployment` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `state` enum('waiting','running','terminated','error') NOT NULL default 'waiting',
  `startdate` datetime NOT NULL default '0000-00-00 00:00:00',
  `enddate` datetime NOT NULL default '0000-00-00 00:00:00',
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=106 DEFAULT CHARSET=latin1;

--
-- Table structure for table `disk`
--

DROP TABLE IF EXISTS `disk`;
CREATE TABLE `disk` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `size` int(10) unsigned NOT NULL default '0',
  `device` varchar(255) NOT NULL,
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=2 DEFAULT CHARSET=latin1;

--
-- Table structure for table `environment`
--

DROP TABLE IF EXISTS `environment`;
CREATE TABLE `environment` (
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
  `optsupport` int(10) unsigned NOT NULL default '0',
  `user` varchar(255) default 'nobody',
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=7 DEFAULT CHARSET=latin1;

--
-- Table structure for table `node`
--

DROP TABLE IF EXISTS `node`;
CREATE TABLE `node` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `name` varchar(255) NOT NULL default '',
  `macaddr` varchar(17) NOT NULL default '',
  `ipaddr` varchar(15) NOT NULL default '',
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=13 DEFAULT CHARSET=latin1;

--
-- Table structure for table `partition`
--

DROP TABLE IF EXISTS `partition`;
CREATE TABLE `partition` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `pnumber` varchar(10) NOT NULL default '3',
  `size` int(10) unsigned NOT NULL default '0',
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=25 DEFAULT CHARSET=latin1;

--
-- Table structure for table `rights`
--

DROP TABLE IF EXISTS `rights`;
CREATE TABLE `rights` (
  `user` varchar(30) NOT NULL default '',
  `node` varchar(255) NOT NULL default '',
  `part` varchar(5) NOT NULL default '',
  PRIMARY KEY  (`user`,`node`,`part`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `site`
--

DROP TABLE IF EXISTS `site`;
CREATE TABLE `site` (
  `id` int(10) unsigned NOT NULL auto_increment,
  `name` varchar(255) NOT NULL default '',
  PRIMARY KEY  (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2008-01-25 15:00:54

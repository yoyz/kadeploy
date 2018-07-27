# --------------------------------------------------------
#
# Table structure for table `deployed`
#


# --------------------------------------------------------
#
# Table structure for table `rights`
#

CREATE TABLE IF NOT EXISTS rights (
   `user` VARCHAR(30) NOT NULL default '',
   `node` VARCHAR(60) NOT NULL default '',
   `vlan` VARCHAR(10) NOT NULL default '',
  PRIMARY KEY (user,node,vlan)
);

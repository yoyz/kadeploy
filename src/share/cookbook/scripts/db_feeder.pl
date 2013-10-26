#! /usr/bin/perl

BEGIN{
    unshift(@INC, ".");
}

use strict;

use db_feeder;

db_feeder::node_data("/home/peaquin/Garbage/dhcpd.conf");
db_feeder::deployed_data();

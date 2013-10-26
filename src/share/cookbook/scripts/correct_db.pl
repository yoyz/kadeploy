#!/usr/bin/perl

use Getopt::Long;
use lib::deploy_iolib;
use lib::rights_iolib;
use lib::conflib;
use strict;

if (@ARGV){
    print "Usage : correct_db.p\n";
    exit 0;
}


my $base = deploy_iolib::connect();
print "Correcting database consistence... ";
deploy_iolib::correct_db_consistence($base);
print "Done.\n";
deploy_iolib::disconnect($base);

1;

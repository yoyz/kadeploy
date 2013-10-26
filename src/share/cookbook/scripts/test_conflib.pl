#!/usr/bin/perl

use strict;
use lib::deploy_iolib;
use lib::rights_iolib;
use Data::Dumper;

conflib::check_conf("/etc/kadeploy/deploy.conf");
my %cmd = conflib::check_cmd("/etc/kadeploy/deploy_cmd.conf");

#print Dumper %cmd;

print "TEST $cmd{\"idpot1\"}{\"deployboot\"}\n";
print "TEST $cmd{\"idpot1\"}{\"softboot\"}\n";
print "TEST $cmd{\"idpot1\"}{\"hardboot\"}\n";
print "TEST $cmd{\"idpot1\"}{\"console\"}\n";

print "Configuration successfully checked...\n";

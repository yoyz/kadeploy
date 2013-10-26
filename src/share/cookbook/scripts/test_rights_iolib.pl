#!/usr/bin/perl

BEGIN{
    unshift(@INC, ".");
}

use strict;
use KaBD::conflib;
use rights_iolib;

if(!(conflib::init_conf("/home/peaquin/cvs/KaDeployv2/KaDeploy/conf_file.txt") == 1)){
    print "ERROR : configuration file loading failed\n";
    exit 0;
}

my $base = rights_iolib::connect();

rights_iolib::adduser($base,"gats","","hda1");

rights_iolib::disconnect($base);

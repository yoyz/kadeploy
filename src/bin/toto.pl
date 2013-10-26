#!/usr/bin/perl
use libkadeploy2::time;
use strict;
use warnings;

my $time=libkadeploy2::time::new();
$time->start();
sleep(1);
print $time->get_elapsed();


#!/usr/bin/perl

use Fcntl; 

my $sudoers = "/etc/sudoers";
my $sudoerstmp = "/etc/sudoers.tmp"; 
my $kadeploy_tag="### KADEPLOY_217_TAG ###"; 
my $struct=pack("ssll", F_WRLCK, SEEK_CUR, 0, 0);

my $bindir="@ARGV/bin/";
my $sbindir="@ARGV/sbin/";

sysopen (SUDOERS, $sudoers, O_RDWR|O_CREAT, 0440) or die "sysopen $sudoers: $!"; 
fcntl(SUDOERS, F_SETLK, $struct) or die "fcntl: $!";
sysopen (SUDOERSTMP, "$sudoerstmp", O_RDWR|O_CREAT, 0440) or die "sysopen $sudoerstmp: $!"; 
print SUDOERSTMP grep (!/$kadeploy_tag/, <SUDOERS>); 
close SUDOERSTMP or die "close $sudoerstmp: $!";
rename "/etc/sudoers.tmp", "/etc/sudoers" or die "rename: $!"; 
close SUDOERS or die "close $$sudoers: $!";


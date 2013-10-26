#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;

my $menu_offset=616;
my $menu_length=2;
my $windowsversion="5.1";

my $source;
my $dest;
my $menulst;

GetOptions(
	   's=s'                  => \$source,
	   'd=s'                  => \$dest,
	   'm=s'                  => \$menulst,
	   );

if (! $source)  { exit 1; }
if (! $dest)    { exit 1; }
if (! $menulst) { exit 1; }



print STDERR "Patching windows floppy ( NTLDR $windowsversion )\n";
system("cp $source $dest");
system("dd if=$menulst of=$dest bs=512 seek=$menu_offset count=$menu_length conv=notrunc");
exit 0;

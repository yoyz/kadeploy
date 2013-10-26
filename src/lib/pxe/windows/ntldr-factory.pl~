#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;

my $menu_offset=718;
my $menu_length=2;
my $grubversion="0.97";

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



print STDERR "Patching grub floppy ( GNU GRUB $grubversion )\n";
system("cp $source $dest");
system("dd if=$menulst of=$dest bs=512 seek=$menu_offset count=$menu_length conv=notrunc");
exit 0;

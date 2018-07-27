#!/usr/bin/perl -w


my $fileName=$ARGV[0];
my $prefixName=$ARGV[1];
my $firstPort=$ARGV[2];
my $lastPort=$ARGV[3];
my $switchName=$ARGV[4];
if(not defined $fileName or not defined $prefixName or not defined $firstPort or not defined $lastPort or not defined $switchName){
	print "$0 <fileName> <prefixName> <firstPort> <lastPort> <switchName>\n";
	exit(1);
}

open(FILE,">>",$fileName);

for(my $i=$firstPort;$i<($lastPort+1);$i++){

	print FILE "$prefixName$i $i $switchName\n";

}

close(FILE);

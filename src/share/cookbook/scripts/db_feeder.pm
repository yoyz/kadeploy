# This module enables to fill in the database 
# (actually only the node and deployed tables for the moment)
# gathering information from the dhcp configuration file given in parameter

package db_feeder;
require Exporter;

use strict;

sub node_data($);
sub deployed_data();

sub node_data($){
    my $dhcp_conf_file_name = shift;
    my @hosts;
    my $key;
    my $value;
    my $i = 1;

    open(DHCP,$dhcp_conf_file_name);
    open(NODE,">nodes.txt");
    while (<DHCP>){
	if (/^host\s*\t*(.\w+)/){
	    $key=$1;
	}
	if (!/^#/ && /\s*\t*hardware ethernet\s*\t*(.\S*)/){
	    $value = $1;
	    chop $value;
	    push @hosts, {$key => $value};
	}
    }
    for $value (@hosts){
	for $key (sort keys %$value){
		print NODE "\\N\t$key\t$value->{$key}\t192.168.10.",$i++,"\n";
	}
    }
    close(DHCP);
    close(NODE);
}

sub deployed_data(){
    my $i;
    my $line = 1;
    open(NODE,"<nodes.txt");
    open(PART,">partition.txt");

    while (<NODE> && $line<=46){
	print PART "1\t1\t5\t$line\t\\N\tdeployed\n";
	print PART "2\t1\t1\t$line\t\\N\tdeployed\n";
	print PART "3\t1\t2\t$line\t\\N\tdeployed\n";
	print PART "5\t1\t3\t$line\t\\N\tdeployed\n";
	for ($i=6;$i<=13;$i++){
	    print PART "4\t1\t$i\t$line\t\\N\tdeployed\n";
	}
	$line++;
    }

    close(NODE);
    close(PART);
}

# END OF THE MODULE
return 1;

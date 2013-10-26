package libkadeploy2::conf;

use strict;
use warnings;
use libkadeploy2::message;

my @listfiletowrapuser=(
			"kaconsole",
			"kadeploy",
			"kadeployenv",
			"kareboot",
			"kaenv",
			);			

my @listfiletowraproot=(
			"karights",
			"kanodes",
			"kadatabase",
			"kasetup",
			"kachecknodes",
			"kamigration",
			);




sub chmodconf()
{
    my $self=shift;

    my $kadeployuser=$self->get("deploy_user");
    my $kadeploydir=$self->get("kadeploy2_directory");

    my $kasudowrapperfile="$kadeploydir/bin/kasudowrapper.sh";
    if ($ENV{USER} eq "root")
    {
	system("chmod 400 $deployconf");
	system("chmod 400 $partitionfile");
	system("chmod 400 $nodesfile");
	
	system("chmod 700 $kadeployconfdir");
	system("chown $kadeployuser $kadeployconfdir");   # la conf appartient a deploy
	
	system("chmod 755 $kasudowrapperfile");           # le wrapper doit pouvoir etre ecris par deploy
	system("chown $kadeployuser $kasudowrapperfile"); 
	
	print STDERR "chmod configuration file done\n";
    }
    else
    {
	print STDERR "You must be root ( user : $ENV{USER} )\n";
	exit 1;
    }
}

sub sudowrapping()
{
    
    my $kadeploy2_directory;
    my $file;
    my $command;
    my $pathfile;
    $kadeploy2_directory=libkadeploy2::conflib::get_conf("kadeploy2_directory");
        
    foreach $file (@listfiletowrapuser)
    {
	$pathfile="/usr/local/bin/$file";
	if ( ! -e $pathfile)
	{
	    $command="ln -s $kadeploy2_directory/bin/kasudowrapper.sh $pathfile";
	    print STDERR "Exec : $command\n";
	    system($command);
	}
	else
	{
	    print STDERR "$pathfile exist\n";
	}
    }

    foreach $file (@listfiletowraproot)
    {
	$pathfile="/usr/local/sbin/$file";
	if ( ! -e $pathfile)
	{
	    $command="ln -s $kadeploy2_directory/bin/kasudowrapper.sh $pathfile";
	    print STDERR "Exec : $command\n";
	    system($command);
	}
	else
	{
	    print STDERR "$pathfile exist\n";
	}
    }


    $command="$kadeploy2_directory/sbin/kasetup -exportenv";
    print "Exec : $command\n";
    system($command);
}



sub printvalidsudoers()
{
    my $kadeploydir=libkadeploy2::conflib::get_conf("kadeploy2_directory");
    my $kadeployuser=libkadeploy2::conflib::get_conf("deploy_user");
    my $tmpcmd;
    my $i;
    print "
Cmnd_Alias DEPLOYCMDUSER = ";
    for ($i=0; $i<=$#listfiletowrapuser; $i++)
    {
	print "$kadeploydir/bin/$listfiletowrapuser[$i]";
	if ($i!=$#listfiletowrapuser) { print ", "; }
    }    
    print ",$kadeploydir/sbin/setup_pxe.pl";
    print "\n";


    print "
Cmnd_Alias DEPLOYCMDROOT = ";
    for ($i=0; $i<=$#listfiletowraproot; $i++)
    {
	print "$kadeploydir/sbin/$listfiletowraproot[$i]";
	if ($i!=$#listfiletowraproot) { print ", "; }
    }    
    print "\n";

    print "
ALL ALL=($kadeployuser) NOPASSWD: DEPLOYCMDUSER
root ALL = (ALL) ALL
\n";

}

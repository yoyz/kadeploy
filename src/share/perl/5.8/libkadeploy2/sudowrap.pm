package libkadeploy2::sudowrap;

my $conf=libkadeploy2::deployconf::new();
if (! $conf->load()) { exit 1; }
my $message=libkadeploy2::message::new();

my $kasudowrapper=$conf->getpath_cmd("kasudowrapper");
my $kasetup=$conf->getpath_cmd("kasetup");

my @listfiletowrapuser=(
			"kaconsole",
			"kadeploy",
			"kadeployenv",
			"kareboot",
			"kaenv",
			"kapxe",
			);			

my @listfiletowraproot=(
			"karights",
			"kanodes",
			"kadatabase",
			"kasetup",
			"kachecknodes",
			"kamigration",
			);




sub checksudoers()
{
    my $sudoers="/etc/sudoers";
    my $ok=1;

    if ( -e $sudoers)
    {
	$message->message(-1,"sudoers $sudoers exist");
    }
    else
    {
	$message->filenotfound(2,"$sudoers");
	$ok=0;
    }
    return $ok;
}



sub sudowrapping()
{
    
    my $kadeploy2_directory;
    my $file;
    my $command;
    my $pathfile;
    $kadeploy2_directory=$conf->get("kadeploy2_directory");
        
    foreach $file (@listfiletowrapuser)
    {
	$pathfile="/usr/local/bin/$file";
	if ( ! -e $pathfile)
	{
	    $command="ln -s $kasudowrapper $pathfile";
	    $message->message(0,"Exec : $command");
	    system($command);
	}
	else
	{
	    $message->message(1,"$pathfile already exist. check it...");
	}
    }

    foreach $file (@listfiletowraproot)
    {
	$pathfile="/usr/local/sbin/$file";
	if ( ! -e $pathfile)
	{
	    $command="ln -s $kasudowrapper $pathfile";
	    $message->message(0,"Exec : $command");
	    system($command);
	}
	else
	{
	    $message->message(1,"$pathfile already exist. check it...");
	}
    }


    $command="$kasetup -exportenv";
    $message->message(0,"Exec : $command");
    system($command);
}



sub printvalidsudoers()
{
    my $kadeploydir=$conf->get("kadeploy2_directory");
    my $kadeployuser=$conf->get("deploy_user");
    my $tmpcmd;
    my $i;
    print "
Cmnd_Alias DEPLOYCMDUSER = ";
    for ($i=0; $i<=$#listfiletowrapuser; $i++)
    {
	print "$kadeploydir/bin/$listfiletowrapuser[$i]";
	if ($i!=$#listfiletowrapuser) { print ", "; }
    }    


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

1;

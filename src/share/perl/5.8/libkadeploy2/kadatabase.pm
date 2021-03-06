package libkadeploy2::kadatabase;

use Getopt::Long;
use Term::ReadKey;
use IPC::Open2;
use IO::Handle;
use libkadeploy2::deployconf;
use libkadeploy2::sudo;
use warnings;
use strict;

sub usage();
sub mygetlogin();
sub mygetpassword();
sub mysqlload($);

my $message=libkadeploy2::message::new();
my $conf=libkadeploy2::deployconf::new();
if (! $conf->loadcheck()) { exit 1; }
my $kadeploydir=$conf->get("kadeploy2_directory");


my $create;
my $drop;
my $clean;
my $testconf;
my $help;
my $addmysqlrights;
my $delmysqlrights;
my $create_db_deploy;
my $create_table_deploy;
my $drop_db_deploy;
my $clean_db_deploy;
my $patch21;
my $patch211;
my $patch22;
my $login;
my $password;
my $ok=0;
my $host=$conf->get("deploy_db_host");
my $mysqlschemapath=$conf->get("kadeploy2_directory")."/share/mysql/";

my $deploy_db_name=$conf->get("deploy_db_name");
my $deploy_db_login=$conf->get("deploy_db_login");
my $deploy_db_password=$conf->get("deploy_db_psswd");

my $sudo_user=libkadeploy2::sudo::get_sudo_user();

################################################################################

sub run()
{
    if ($clean_db_deploy)
    {
	$login=$deploy_db_login;
	$password=$deploy_db_password;
	mysqlload("clean_db_deploy");
	$ok=1;
    }
    
    if ($addmysqlrights        || 
	$delmysqlrights        ||
	$drop_db_deploy        ||
	$create_db_deploy      ||
	$create_table_deploy   ||
	$patch21               ||
	$patch211              ||
	$patch22
	) 
    {
	print "!!! Warning it required Mysql administrator right !!!\n";
	$login    = mygetlogin();
	$password = mygetpassword();
    }
    


    if ($delmysqlrights)         { mysqlload("delmysqlrights"); $ok=1; }
    if ($addmysqlrights)         { mysqlload("addmysqlrights"); $ok=1; }
    if ($drop_db_deploy)         { mysqlload("drop_db_deploy"); $ok=1; }
    if ($create_db_deploy)       { mysqlload("create_db_deploy"); $ok=1;}
    if ($create_table_deploy)    { mysqlload("create_table_deploy"); $ok=1;}
    if ($patch21)                { mysqlload("patch-kadeploy-2.1"); $ok=1;}
    if ($patch211)               { mysqlload("patch-kadeploy-2.1.1"); $ok=1;}
    if ($patch22)                { mysqlload("patch-kadeploy-2.2"); $ok=1;}
    
    if ($ok==0 ||
	$help) 
    { 
	$message->kadatabase_help(); 
    }    
}


sub get_options_cmdline()
{
    GetOptions('addmysqlrights'        => \$addmysqlrights,
	       'delmysqlrights'        => \$delmysqlrights,
	       'create_db_deploy'      => \$create_db_deploy,
	       'create_table_deploy'   => \$create_table_deploy,
	       'drop_db_deploy'        => \$drop_db_deploy,
	       'clean_db_deploy'       => \$clean_db_deploy,
	       'patch21'               => \$patch21,
	       'patch211'              => \$patch211,
	       'patch22'               => \$patch22,
	       'h!'                    => \$help,
	       'help!'                 => \$help,
	       );
}

sub check_options()
{
    if ($help) { $message->kadatabase_help(); return 0; }
}

sub mygetlogin()
{
    my $login;
    print("login:");
    $login=<STDIN>;
    chomp($login);
    return $login;
}

sub mygetpassword()
{
    my $password;
    print("password:"); 
    ReadMode('noecho');
    $password = ReadLine(0);
    chomp($password);
    ReadMode('normal');
    print "\n";
    return $password;
}

sub mysqlload($)
{
    my $func=shift;
    my $ret;
    my $line;
    my $modifiedfile;
    my $filetoopen="$mysqlschemapath/$func.sql";

    open(FH,$filetoopen) or die "can't open $filetoopen";
    while ($line=<FH>)
    {
	$line=~s/SUBSTmydeploypasswordSUBST/$deploy_db_password/g;
	$line=~s/SUBSTmydeployloginSUBST/$deploy_db_login/g;
	$line=~s/SUBSTmydeploydbSUBST/$deploy_db_name/g;
	$modifiedfile.=$line;
    }
    
    close(FH);
    open(MYSQL,"|mysql -u $login --password=$password --host=$host");
    print MYSQL $modifiedfile;
    if (close(MYSQL)) { $ret=0; } else { $ret=1; }
    
    if ($ret==0)
    {
	print("$func Done !!!\n");
    }
    else
    {
	print("Something Wrong occured...");
    }
    return $ret;
}


1;

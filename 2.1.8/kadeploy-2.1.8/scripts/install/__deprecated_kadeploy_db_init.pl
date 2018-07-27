#!/usr/bin/perl
#
#This program is derived from oar project's sources (http//:oar.imag.fr)
#

use strict;
use warnings;
use DBI;
use lib './';
use kadeploy_conflib qw(init_conf get_conf is_conf);
use File::Basename;
use Getopt::Long;

Getopt::Long::Configure ("gnu_getopt");
my $usage;
GetOptions ("help|h"  => \$usage);

if ($usage){
    print <<EOS;
Usage: $0 [-h|--help]
Setup the database used by Kadeploy
Options:
 -h, --help        show this help screen
EOS
    exit(0);
}

my $mysqlFile = './create_table_deploy.sql';
print "Using $mysqlFile for the database creation\n";
( -r $mysqlFile ) or die "[ERROR] Initialization SQL file not found ($mysqlFile)\n";

init_conf("deploy.conf");
my $dbHost = get_conf("deploy_db_host");
my $dbName = get_conf("deploy_db_name");
my $dbUserName = get_conf("deploy_db_login");
my $dbUserPassword = get_conf("deploy_db_psswd");

print "## Initializing Kadeploy MySQL database ##\n";
print "Retrieving Kadeploy base configuration for Kadeploy configuration file:\n";
print "\tMySQL server hostname: $dbHost\n";
print "\tKadeploy base name: $dbName\n";
print "\tKadeploy base login: $dbUserName\n";

$| = 1;
# DataBase login
print "Please enter MySQL admin login information:\n";
print "\tAdmin login: ";
my $dbLogin = <STDIN>;
chomp $dbLogin;
# DataBase password or the dbLogin
$| = 1;
print "\tAdmin password:";
system("stty -echo");
my $dbPassword = <STDIN>;
chomp $dbPassword;
system("stty echo");
print "\n";

# Connect to the database.
my $dbh = DBI->connect("DBI:mysql:database=mysql;host=$dbHost", $dbLogin, $dbPassword, {'RaiseError' => 0});
my $query;
$query = $dbh->prepare("CREATE DATABASE IF NOT EXISTS $dbName") or die $dbh->errstr;
$query->execute();
# Add deploy user
# Test if this user already exists
$query = $dbh->prepare("SELECT * FROM user WHERE User=\"".$dbUserName."\" and (Host=\"localhost\" or Host=\"%\")");
$query->execute();

if (! $query->fetchrow_hashref()){
        $query = $dbh->prepare("INSERT INTO user (Host,User,Password) VALUES('localhost','".$dbUserName."',PASSWORD('".$dbUserPassword."'))") or die $dbh->errstr;
        $query->execute();

        $query = $dbh->prepare("INSERT INTO user (Host,User,Password) VALUES('%','".$dbUserName."',PASSWORD('".$dbUserPassword."'))") or die $dbh->errstr;
        $query->execute();

        my $rightError = 0;

        $dbh->do("INSERT INTO db (Host,Db,User,Select_priv,Insert_priv,Update_priv,Delete_priv, Create_priv,Drop_priv,Create_tmp_table_priv,Lock_tables_priv,Alter_priv) VALUES ('localhost','".$dbName."','".$dbUserName."','Y','Y','Y','Y','Y','Y','Y','Y','Y')") or $rightError = 1;

        if ($rightError == 1){
                print("--- not enough rights; it is not a bug, it is a feature ---\n");
                # the properties  Create_tmp_table_priv and Lock_tables_priv dose not exist
                	$dbh->do("INSERT INTO db (Host,Db,User,Select_priv,Insert_priv,Update_priv,Delete_priv, Create_priv,Drop_priv,Alter_priv) VALUES ('localhost','".$dbName."','".$dbUserName."','Y','Y','Y','Y','Y','Y','Y')") or die $dbh->errstr;
                        $dbh->do("INSERT INTO db (Host,Db,User,Select_priv,Insert_priv,Update_priv,Delete_priv, Create_priv,Drop_priv,Alter_priv) VALUES ('%','".$dbName."','".$dbUserName."','Y','Y','Y','Y','Y','Y','Y')") or die $dbh->errstr;
       	}else{
        	        $dbh->do("INSERT INTO db (Host,Db,User,Select_priv,Insert_priv,Update_priv,Delete_priv, Create_priv,Drop_priv,Create_tmp_table_priv,Lock_tables_priv, Alter_priv) VALUES ('%','".$dbName."','".$dbUserName."','Y','Y','Y','Y','Y','Y','Y','Y','Y')") or $rightError = 1;
        }
       
	 $query = $dbh->prepare("FLUSH PRIVILEGES") or die $dbh->errstr;
         $query->execute();
         }else{
         print("Warning: the database user is already created.\n");
         }

$dbh->disconnect();

# Connection to the kadeploy database with deploy user
$dbh = DBI->connect("DBI:mysql:database=$dbName;host=$dbHost", $dbUserName, $dbUserPassword, {'RaiseError' => 1});

if (-r $mysqlFile){
	system("mysql -u$dbUserName --password=$dbUserPassword -h$dbHost -D$dbName < $mysqlFile");
        if ($? != 0){
        	die("[ERROR] this command aborted : mysql -u$dbUserName --password=***** -h$dbHost -D$dbName < $mysqlFile; \$?=$?, $! \n");
        }
}else{
       	die("[ERROR] Database installation : can't open $mysqlFile \n");
}
$dbh->disconnect();
print "done.\n";

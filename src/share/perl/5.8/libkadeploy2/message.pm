package libkadeploy2::message;
use strict;
use warnings;
use Sys::Syslog;

sub new()
{
    my $self;
    openlog("kadeploy", 'cons,pid', 'user');
    $self ={};
    bless $self;
    return $self;
}

sub severity($)
{
    my $self=shift;
    my $severity=shift;
    my $str;
    


    if ($severity<0)
    {
	$str="INFO     : ";
    }
    elsif ($severity==0)
    {
	$str="NOTICE   : ";
    }
    elsif($severity==1)
    {
	$str="WARNING  : ";
    }
    elsif($severity==2)
    {
	$str="ERROR    : ";
    }
    elsif($severity>2)
    {
	$str="ERROR    : ";
    }

    return $str;
}

sub missing_node_cmdline($)
{
    my $self=shift;
    my $severity=shift;
    my $msg="Missing nodename";
    print STDERR $self->severity($severity).$msg."\n";
}

sub missing_login_cmdline($)
{
    my $self=shift;
    my $severity=shift;
    my $msg="Missing login";
    print STDERR $self->severity($severity).$msg."\n";
}

sub missing_envname_cmdline($)
{
    my $self=shift;
    my $severity=shift;
    my $msg="Missing envname";
    print STDERR $self->severity($severity).$msg."\n";
}


sub missing_rights_cmdline($)
{
    my $self=shift;
    my $severity=shift;
    my $msg="Missing rights";
    print STDERR $self->severity($severity).$msg."\n";
}

sub missing_flags_cmdline($)
{
    my $self=shift;
    my $severity=shift;
    my $msg="Missing flags";
    print STDERR $self->severity($severity).$msg."\n";
}

sub missing_cmdline($$)
{
    my $self=shift;
    my $severity=shift;
    my $cmdline=shift;
    my $msg="Missing $cmdline";
    print STDERR $self->severity($severity).$msg."\n";

}

sub missing_type_cmdline($$)
{
    my $self=shift;
    my $severity=shift;
    my $type=shift;
    my $msg="Type not found $type";
    print STDERR $self->severity($severity).$msg."\n";    

    if ($severity>=0) { syslog('info', $msg); }
}


sub unknowerror($$)
{
    my $self=shift;
    my $severity=shift;
    my $specialmsg=shift;
    my $msg="Unknow error on ( $specialmsg )";
    print STDERR $self->severity($severity).$msg."\n";
    if ($severity>=0) { syslog('info', $msg); }
}


sub message($$)
{
    my $self=shift;
    my $severity=shift;
    my $msg=shift;
    print STDERR $self->severity($severity).$msg."\n";
    if ($severity>=0) { syslog('info', $msg); }
}

sub missing_node_db($)
{
    my $self=shift;
    my $severity=shift;
    my $nodename=shift;
    my $msg="$nodename doesn't exist in db";
    print STDERR $self->severity($severity).$msg."\n";

    if ($severity>=0) { syslog('info', $msg); }
}

sub missing_env_db($)
{
    my $self=shift;
    my $severity=shift;
    my $nodename=shift;
    my $msg="There is no environments in db";
    print STDERR $self->severity($severity).$msg."\n";

    if ($severity>=0) { syslog('info', $msg); }
}


sub notenough_right($$)
{
    my $self=shift;
    my $severity=shift;
    my $right=shift;
    my $msg="Not enough rights => ".$right;
    print STDERR $self->severity($severity).$msg."\n";

    if ($severity>=0) { syslog('info', $msg); }
}

sub missing_rights_db($)
{
    my $self=shift;
    my $severity=shift;
    my $msg="There is no rights in db";
    print STDERR $self->severity($severity).$msg."\n";

    if ($severity>=0) { syslog('info', $msg); }
}


sub missing_disk_db($)
{
    my $self=shift;
    my $severity=shift;
    my $nodename=shift;
    my $msg="Disk not found for node $nodename in db";
    print STDERR $self->severity($severity).$msg."\n";    

    if ($severity>=0) { syslog('info', $msg); }
}



sub osnotsupported($)
{
    my $self=shift;
    my $severity=shift;
    my $osname=shift;
    my $msg="$osname operating system is not supported yet";
    print STDERR $self->severity($severity).$msg."\n";

    if ($severity>=0) { syslog('info', $msg); }

}

sub dirnotfound($$)
{
    my $self=shift;
    my $severity=shift;
    my $dirname=shift;
    my $msg="Directory $dirname doesn't exist";
    print STDERR $self->severity($severity).$msg."\n";

    if ($severity>=0) { syslog('info', $msg); }
}

sub filenotfound($$)
{
    my $self=shift;
    my $severity=shift;
    my $filename=shift;
    my $msg="$filename doesn't exist";
    print STDERR $self->severity($severity).$msg."\n";

    if ($severity>=0) { syslog('info', $msg); }
}

sub erroropeningfile($$)
{
    my $self=shift;
    my $severity=shift;
    my $filename=shift;
    my $msg="Can't open $filename";
    print STDERR $self->severity($severity).$msg."\n";

    if ($severity>=0) { syslog('info', $msg); }
}

sub statfile($$)
{
    my $self=shift;
    my $severity=shift;
    my $filename=shift;
    my $msg="Stating file $filename";
    print STDERR $self->severity($severity).$msg."\n";

    if ($severity>=0) { syslog('info', $msg); }
}

sub loadingfile($$)
{
    my $self=shift;
    my $severity=shift;
    my $filename=shift;
    my $msg="Loading $filename";
    print STDERR $self->severity($severity).$msg."\n";

    if ($severity>=0) { syslog('info', $msg); }
}

sub loadingfileDone($$)
{
    my $self=shift;
    my $severity=shift;
    my $filename=shift;
    my $msg="Loading $filename finished.";
    print STDERR $self->severity($severity).$msg."\n";

    if ($severity>=0) { syslog('info', $msg); }
}

sub loadingfilefailed($$)
{
    my $self=shift;
    my $severity=shift;
    my $filename=shift;
    my $msg="Loading $filename failed";
    print STDERR $self->severity($severity).$msg."\n";

    if ($severity>=0) { syslog('info', $msg); }
}

sub loadingfileyoumust($)
{
    my $self=shift;
    my $severity=shift;
    my $msg="you have to load a file first";
    print STDERR $self->severity($severity).$msg."\n";

    if ($severity>=0) { syslog('info', $msg); }
}

sub commandnodenamefailed($$$)
{
    my $self=shift;
    my $severity=shift;
    my $commandname=shift;
    my $nodename=shift;
    my $msg="$commandname failed for node $nodename";
    print STDERR $self->severity($severity).$msg."\n";

    if ($severity>=0) { syslog('info', $msg); }
}

sub checkingdb($)
{
    my $self=shift;
    my $severity=shift;
    my $msg="Checking database access...";
    print STDERR $self->severity($severity).$msg."\n";

    if ($severity>=0) { syslog('info', $msg); }
}

########################################HELP########################################

my $addnode_flags=          "--add                                add nodes";
my $delnode_flags=          "--del                                delete specified hostname";

my $addenv_flags=           "--add                                add environment to db";
my $delenv_flags=           "--del                                delete environemnt to db";

my $addright_flags=         "--add                                add a right";
my $delright_flags=         "--del                                remove a right";


my $listenv_flags=          "--list                               list environment";
my $listright_flags=        "--list                               list right";

my $help_flags=             "-h|--help                            this help message";
my $verbose_flags=          "-v|--verbose                         verbose mode";

my $confcommand_flags=      "--confcommand                        execute a configuration command on a set of node";
my $nodecommand_flags=      "--nodecommand                        execute a command on a set of node";
my $checknode_flags=        "--check                              check some nodes";

my $listresult_flags=       "--list                               show result from a check";
my $listnode_flags=         "--listnode                           list node from db";
my $listpartition_flags=    "--listpartition                      list partition from db";

my $softboot_flags=         "--soft                               softboot command";
my $hardboot_flags=         "--hard                               hardboot";
my $deployboot_flags=       "--deploy                             deploy";

my $fromdisk_flags=         "--fromdisk                           read kernel, module, initrd from disk";
my $fromtftp_flags=         "--fromtftp                           read kernel, module, initrd from tftp";


my $checkdeployconf_flags=  "--checkdeployconf                    check deployconf";
my $checksudoers_flags=     "--checksudoers                       print a valid sudoers";
my $sudowrapping_flags=     "--sudowrapping                       wrap files with kasudowrapper.sh";
my $printvalidsudoers_flags="--printvalidsudoers                  generate a sudoers from deploy.conf";
my $createtftp_flags=       "--createtftp                         create the kadeploy tftp/pxe system";
my $exportenv_flags=        "--exportenv                          configure sudowrapping (this is done after sudowrapping)";
my $chmodconf_flags=        "--chmodconf                          put correct write on configuration files";

my $printfdisk_flags=       "--printfdisk                         print a fdisk file from";
my $printfstab_flags=       "--printfstab                         print a fstab file from a clusterpartition";


my $partitionf_params=      "--partitionfile     partionfile      load a custom partition file";

my $machine_params=         "-m, --machine       node             nodename";
my $machinefile_params=     "-f                  hostfile         node file";
my $tcpport_params=         "-p, --port          port             tcp port";
my $connector_params=       "--connector         connector        rsh or ssh";
my $login_params=           "-l, --login         login            username";

my $timeoutcmd_params=      "-t, --timeout       timeout          timeout for command in s";
my $timeoutpxe_params=      "--timeout                            pxe loader timeout in second";

my $retry_params=           "--retry             count            blocking time in 's'";
my $environmentname_params= "-e|--environment    environmentname  name of the environment";
my $environmentdsc_params = "-f|--envfile        envdsc           environment description file";
my $right_params=           "-r|--rights         right            right you want to add or del";

my $check_type_params=      "--type              checktype        choose a check type [ICMP|SSH|MCAT]";
my $pxeloadertype_params=   "--type              pxeloader        choose from pxelinux, pxegrub, pxegrubfloppy, pxewindowsfloppy";
my $recordtype_params=      "--type              recordtype       choose from linux, dd";
my $ostype_params=          "--type              ostype           only linux (currently)";


my $kernel_params=          "--kernel            kernel           path to kernel";
my $initrd_params=          "--initrd            initrd           path to initrd";
my $module_params=          "--module            module           path to module";
my $kernelparams_params=    "--kernelparams      kernel_params    kernel parameters";

my $disknumber_params=      "-d|--disknumber     disknumber       disk number      (begin at 1)";
my $partnumber_params=      "-p|--partnumber     partnumber       partition number (begin at 1)";
my $slice_params=           "-s|--slice          slice            slice            (a-z)";

my $serialport_params=      "--serialport        serialportnumber serial port number";
my $serialportspeed_params= "--serialspeed       serialportspeed  serial port speed";


my $command_params=         "-c, --command       \"distcmd\"        command to exec on a set of node";
my $servercmd_params=       "--servercommand     \"localcmd\"       command on server";
my $clientcmd_params=       "--clientcommand     \"distcmd\"        command on client";

sub kanodes_help()
{
    my $self=shift;
    my $help="kanodes
\t$help_flags

\t$addnode_flags
\t$delnode_flags

\t$listnode_flags
\t$listpartition_flags


\t$machine_params

\t$partitionf_params

";

    print $help;
}

sub kadatabase_help()
{
    my $self=shift;
    my $help="kadatabase
\t$help_flags

\t--addmysqlrights             # create the \"deploy\" user for the db
\t--delmysqlrights             # delete this user from the db

\t--create_db_deploy           # create database
\t--create_table_deploy        # create table
\t--drop_db_deploy             # drop database
\t--clean_db_deploy            # clean deployed and deployement table

\t--patch21                    # patch db 2.0   -> 2.1
\t--patch211                   # patch db 2.1   -> 2.1.X
\t--patch22                    # patch db 2.1.X -> 2.2

";

    print $help;
}


sub kamcat_help()
{
    my $self=shift;
    my $help="kamcat
\t$help_flags


\t$machine_params

\t$tcpport_params
\t$connector_params

\t$login_params

\t$servercmd_params
\t$clientcmd_params

";

    print $help;
}

sub kaexec_help()
{
    my $self=shift;
    my $help="kaexec
\t$help_flags
\t$verbose_flags

\t$confcommand_flags
\t$nodecommand_flags


\t$machine_params
\t$machinefile_params

\t$command_params

\t$connector_params
\t$login_params
\t$timeoutcmd_params

";

    print $help;
}


sub kaenv_help()
{
    my $self=shift;
    my $help="kaenv
\t$help_flags

\t$addenv_flags
\t$delenv_flags
\t$listenv_flags


\t$environmentname_params

\t$login_params

\t$environmentdsc_params

";

    print $help;
}




sub kaconsole_help()
{
    my $self=shift;
    my $help="kaconsole
\t$help_flags


\t$machine_params

";

    print $help;
}

sub kachecknodes_help()
{
    my $self=shift;
    my $help="kachecknodes
\t$help_flags
\t$verbose_flags

\t$checknode_flags
\t$listresult_flags


\t$check_type_params
\t$retry_params

\t$machine_params

";

    print $help;
}



sub kareboot_help()
{
    my $self=shift;
    my $help="kareboot
\t$help_flags

\t$verbose_flags

\t$softboot_flags
\t$hardboot_flags
\t$deployboot_flags


\t$machine_params
\t$machinefile_params

\t$environmentname_params
\t$partnumber_params
\t$disknumber_params

";

    print $help;
}


sub karights_help()
{
    my $self=shift;
    my $help="karights
\t$help_flags

\t$addright_flags
\t$delright_flags
\t$listright_flags


\t$machine_params
\t$machinefile_params

\t$right_params
\t$login_params

";

    print $help;
}

sub kapxe_help()
{
    my $self=shift;
    my $help="kapxe
\t$help_flags

\t$fromdisk_flags
\t$fromtftp_flags


\t$machine_params

\t$pxeloadertype_params

\t$kernel_params
\t$initrd_params
\t$module_params
\t$kernelparams_params

\t$disknumber_params
\t$partnumber_params
\t$slice_params

\t$serialport_params
\t$serialportspeed_params
\t$timeoutpxe_params

";

    print $help;
}

sub karecordenv_help()
{
    my $self=shift;
    my $help="karecordenv
\t$help_flags

\t$verbose_flags

\t$machine_params

\t$recordtype_params

\t$disknumber_params
\t$partnumber_params

";

    print $help;
}


sub kadeploy_help()
{
    my $self=shift;
    my $help="kadeploy
\t$help_flags

\t$verbose_flags


\t$machine_params
\t$machinefile_params

\t$disknumber_params
\t$partnumber_params

\t$environmentname_params
\t$login_params

";
    print $help;
}

sub kasetup_help()
{
    my $self=shift;
    my $help="kasetup
\t$help_flags

\t$checkdeployconf_flags
\t$checksudoers_flags
\t$sudowrapping_flags
\t$printvalidsudoers_flags
\t$createtftp_flags
\t$exportenv_flags
\t$chmodconf_flags

";
    print $help;
}


sub kadeployenv_help()
{
    my $self=shift;
    my $help="kadeployenv
\t$help_flags

\t$verbose_flags


\t$machine_params
\t$machinefile_params

\t$disknumber_params
\t$partnumber_params

\t$environmentname_params
\t$login_params

";
    print $help;
}

sub kareset_help()
{
    my $self=shift;
    my $help="kareset
\t$help_flags

\t$machine_params

";
    print $help;
}



sub kapart_help()
{
    my $self=shift;
    my $help="kapart
\t$help_flags

\t$verbose_flags

\t$printfdisk_flags
\t$printfstab_flags
\t$partitionf_params

\t$machine_params
\t$machinefile_params

\t$partitionf_params

\t$disknumber_params
\t$partnumber_params

\t$ostype_params

";
    print $help;
}


1;

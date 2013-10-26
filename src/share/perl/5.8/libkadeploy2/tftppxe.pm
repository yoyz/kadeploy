package libkadeploy2::tftppxe;

use libkadeploy2::deployconf;
use strict;
use warnings;

sub createtftp($)
{
    my $conf=shift; # configuration object

    my $kadeployuser;
    my $kadeploydir; 
    my $tftpdir;
    my $pxedir;
    my $tftpbootdir;
    my $pxelinux;
    my $memdisk;
    my $deployx86;
    my $deployx8664;

    $kadeployuser=$conf->get("deploy_user");
    $kadeploydir=$conf->get("kadeploy2_directory");
    $tftpdir=$conf->get("tftp_repository");
    $pxedir=$tftpdir."/".$conf->get("pxe_rep");
    $tftpbootdir=$tftpdir."/".$conf->get("tftp_relative_path");
    $pxelinux="$kadeploydir/lib/pxelinux/pxelinux.0";
    $memdisk="$kadeploydir/lib/pxelinux/memdisk";
    $deployx86="$kadeploydir/lib/deployment_kernel/x86/";
    $deployx8664="$kadeploydir/lib/deployment_kernel/x86_64/";


    mkdir("$tftpdir",0755);
    mkdir("$pxedir",0755);

    system("chown -R $kadeployuser $tftpdir");
    print("Done !!!!\n");
}

1;

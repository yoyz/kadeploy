package libkadeploy2::kapxe;

use File::Copy;
use Getopt::Long;
use libkadeploy2::deployconf;
use libkadeploy2::rights_iolib;
use libkadeploy2::cmdline;
use libkadeploy2::message;
use libkadeploy2::device;
use libkadeploy2::hexlib;
use libkadeploy2::grub;
use libkadeploy2::tftppxe;
use libkadeploy2::sudo;
use libkadeploy2::karights;
use libkadeploy2::disks;

use libkadeploy2::pxelinux;
use libkadeploy2::grub;
use libkadeploy2::ntldr;
use strict;
use warnings;


sub check_options();
sub generate_pxelinuxcfg_file($$$$$$$);
sub writepxelinuxcfg($);
sub generate_grub_menu_linux($$$$$$$$$);

sub writegrubdisk($$);
sub writepxegrub($$);

sub readpxelinuxcfg($);
sub readgrubcfg($);

sub display_pxetype($);

sub set_pxeloadertype();

sub clean_tftpnodes($);
sub copy_kernel_modules_tftpnodes($);
sub setup_pxebootloader($$);
sub generate_bootini_file();
sub writewindowsdisk($);
sub check_right($);

my $conf=libkadeploy2::deployconf::new();
if (! $conf->loadcheck()) { exit 1; }


my @node_list;

my $hostfile;
my $environment;
my $timeout=10;

my $partnumber;
my $partnumbercmdline; 
my $disknumber;
my $disknumbercmdline;
my $slice;
my $slicecmdline;

my $verbose;
my $type="";

my $serialport;
my $first_serial_speed;
my $second_serial_speed;
my $kernel="";
my $initrd="";
my $module="";

my $kernelparams;
my $conffiledata;
my $nodelist;
my $help;
my $menulst;
my $fromdisk=0;
my $fromtftp=0;
my $bootloadername;
my $kerneltftp;
my $initrdtftp;
my $moduletftp;

my $keneltftpnode;
my $initrdtftpnode;
my $moduletftpnode;

my $disktype;
my $disks;
my $sudo_user=libkadeploy2::sudo::get_sudo_user();
if (! $sudo_user) { $sudo_user=libkadeploy2::sudo::get_user(); }

my $kadeploydir=$conf->get("kadeploy2_directory");
my $kadeploylibpxelinux=$kadeploydir."/lib/pxe/pxelinux/";
my $kadeploylibpxegrub=$kadeploydir."/lib/pxe/pxegrub/";
my $kadeploylibpxeopenbsd=$kadeploydir."/lib/pxe/pxeopenbsd/";

my $tftproot=$conf->get("tftp_repository");
my $message=libkadeploy2::message::new();

my $pxelinuxpath="$kadeploylibpxelinux/pxelinux.0";
my $pxegrubpath="$kadeploylibpxegrub/pxegrub";
my $memdiskpath ="$kadeploylibpxelinux/memdisk";
my $pxeopenbsdpath="$kadeploylibpxeopenbsd/pxeboot";


my $sourcegrubfloppy="$kadeploydir/lib/floppy/grub/grub.img";
my $sourcewindowsfloppy="$kadeploydir/lib/floppy/windows/ntldr.img";

my $windowsdirectory;






my $righttocheck="PXE";

if ($conf->is_conf("first_serial_speed"))  { $first_serial_speed=$conf->get("first_serial_speed"); } else { $first_serial_speed=9600; }
if ($conf->is_conf("second_serial_speed")) { $second_serial_speed=$conf->get("second_serial_speed"); } else { $second_serial_speed=9600; }

############################################################

sub run()
{
    my $pxelinuxtftp;
    my $pxegrubtftp;
    my $pxentldr;

    if (! check_options()) { return 1; }

    if (! check_right($righttocheck)) { $message->message(2,"$sudo_user not allowed to $righttocheck ".$nodelist->get_str()); exit 1; }
       
    if (! -d $tftproot)  { libkadeploy2::tftppxe::createtftp($conf); }


    #PREPARE TFTP-NODES CONFIGURATION
    if ($type eq "pxelinux")
    { 
	$pxelinuxtftp=libkadeploy2::pxelinuxtftp::new(); 
	$pxelinuxtftp->set_nodelist($nodelist);

	if ($kernel)
	{
	    $pxelinuxtftp->set_kernel($kernel);
	    $pxelinuxtftp->set_initrd($initrd);
	    $pxelinuxtftp->set_kernelparams($kernelparams);
	    $pxelinuxtftp->set_partnumber($partnumber);
	    $pxelinuxtftp->set_disknumber($disknumber);
	    $pxelinuxtftp->writepxelinuxcfg();
	}
    }
    elsif ($type =~ /pxegrub.*/)
    {
	$pxegrubtftp=libkadeploy2::pxegrubtftp::new();
	$pxegrubtftp->set_nodelist($nodelist);
	$pxelinuxtftp=libkadeploy2::pxelinuxtftp::new();
	$pxelinuxtftp->set_nodelist($nodelist);

	$pxegrubtftp->set_kernel($kernel);
	$pxegrubtftp->set_initrd($initrd);
	$pxegrubtftp->set_module($module);
	$pxegrubtftp->set_kernelparams($kernelparams);
	$pxegrubtftp->set_disktype($disktype);
	$pxegrubtftp->set_disknumber($disknumber);
	$pxegrubtftp->set_partnumber($partnumber);
	$pxegrubtftp->set_slice($slice);
	if ($fromtftp) { $pxegrubtftp->set_networkroot(); }
    }
    elsif ($type eq "pxewindowsfloppy")
    {
	$pxelinuxtftp=libkadeploy2::pxelinuxtftp::new();
	$pxelinuxtftp->set_nodelist($nodelist);

	$pxentldr=libkadeploy2::ntldr::new();
	$pxentldr->set_nodelist($nodelist);
	$pxentldr->set_partnumber($partnumber);
	$pxentldr->set_disknumber($disknumber);
	$pxentldr->set_windowsdirectory($windowsdirectory);
    }


    #LIST CONFIGURATION
    if (! $partnumber && ( ! $kernel))
    {
	my $ok=0;
	if ($type eq "pxelinux")
	{
	    $pxelinuxtftp->set_nodelist($nodelist);
	    $pxelinuxtftp->readpxelinuxcfg();
	    $ok=1;
	}
	elsif ($type =~ /pxegrub.*/)
	{
	    if ($type eq "pxegrubfloppy") { $pxegrubtftp->set_pxefloppy(); }	   
	    if ($type eq "pxegrub")       { $pxegrubtftp->set_pxe();       }
	    $pxegrubtftp->readgrubcfg();
	    $ok=1;
	}
	elsif ($type eq "pxewindowsfloppy")	    
	{
	    $pxentldr->readbootinicfg();
	    $ok=1;
	}
	if ($ok) { return 0; } else { return 1; }
    }




    #WRITE TFTP CONFIGURATION
    if ($type eq "pxegrub"          ||
	$type eq "pxelinux"         ||
	$type eq "pxeopenbsd"       ||
	$type eq "pxegrubfloppy"    ||
	$type eq "pxewindowsfloppy" 
	)
    {
	clean_tftpnodes($nodelist);
	if (! setup_pxebootloader($nodelist,$type)) 
	{
	    $message->message(2,"Can't put $type in tftp for nodes => ".$nodelist->get_str());
	    exit 1;
	}
	set_pxeloadertype();
    }


    if (! ($type) || (! $nodelist))
    {
	$message->message(2,"pxetype or nodelist not set...");
	return 1;
    }
    else
    {
	if (($type eq "pxelinux") &&
	    $kernel
	    ) 
	{	
	    if (! copy_kernel_initrd_modules_tftpnodes($nodelist))  
	    { $message->message(2,"Something wrong setting up bootloader ".$nodelist->get_str()); return 1;     }
	    return 0;
	}

	elsif ($type eq "pxegrub" &&
	       $kernel)
	{	    
	    if (! ($fromtftp || $fromdisk)) {  $message->message(2,"fromdisk or fromtftp needed..."); exit 1; }
	    
	    if ($fromtftp)
	    {
		if (! copy_kernel_initrd_modules_tftpnodes($nodelist))  
		{ $message->message(2,"Something wrong setting up bootloader ".$nodelist->get_str()); return 1;     }
		$pxegrubtftp->writepxegrubcfg($nodelist);
	    }
	    $pxegrubtftp->writepxegrubcfg($nodelist);
	    return 0;
	}	
	elsif ($type eq "pxegrubfloppy" &&
	       $kernel)
	{    
	    $menulst=$pxegrubtftp->generate_grub_menu_linux();

	    $pxelinuxtftp->set_kernel($memdiskpath);
	    $pxelinuxtftp->set_initrd($sourcegrubfloppy);
	    $pxelinuxtftp->writepxelinuxcfg();	    

	    if (! copy_kernel_initrd_modules_tftpnodes($nodelist))  
	    { $message->message(2,"Something wrong setting up bootloader ".$nodelist->get_str()); return 1;     }
	    
	    $pxegrubtftp->writepxegrubfloppy($menulst); #initrd;		
	    $pxelinuxtftp->writepxelinuxcfg($nodelist);
	    return 0;
	}

	elsif ($type eq "pxeopenbsd" &&
	       $kernel)
	{	 
	    if (! copy_kernel_initrd_modules_tftpnodes($nodelist))
	    { 
		$message->message(2,"Something wrong setting up bootloader ".$nodelist->get_str()); 
		return 1;     
	    }
	    return 0;
	}
	elsif ($type eq "pxewindowsfloppy")
	{
	    $kernel=$memdiskpath;
	    $initrd=$sourcewindowsfloppy;
	    $pxelinuxtftp->set_kernel($memdiskpath);
	    $pxelinuxtftp->set_initrd($sourcewindowsfloppy);
	    if (! copy_kernel_initrd_modules_tftpnodes($nodelist)) { exit 1; }
	    $pxentldr->writepxewindowsfloppy();
	    $pxelinuxtftp->writepxelinuxcfg();
	    exit 0;
	}
	$message->message(2,"Something wrong occured... (kapxe::run())");
	exit 1;
    }

}

################################################################################
sub get_options_cmdline()
{
    GetOptions(
	       'm=s'            => \@node_list,
	       'machine=s'      => \@node_list,
	       
	       'f=s'            => \$hostfile,
	       'e=s'            => \$environment,
	       
	       'verbose'        => \$verbose,
	       'v'              => \$verbose,
	       
	       'type=s'         => \$type,
	       'kernel=s'       => \$kernel,
	       'initrd=s'       => \$initrd,
	       'module=s'       => \$module,
	       'kernelparams=s' => \$kernelparams,
	       'windowsdirectory=s'=> \$windowsdirectory,
	       'environment=s'  => \$environment,
	       'timeout=s'      => \$timeout,
	       
	       'fromdisk!'      => \$fromdisk,
	       'fromtftp!'      => \$fromtftp,

	       'disknumber=s'   => \$disknumbercmdline,
	       'partnumber=s'   => \$partnumbercmdline,
	       'slice=s'        => \$slicecmdline,
	       's=s'            => \$slicecmdline,
	       
	       'h!'             => \$help,
	       'help!'          => \$help,
	       );
}

sub check_options()
{
    
    if ($help) { $message->kapxe_help(); exit 0; }

    if (@node_list)     { $nodelist=libkadeploy2::nodelist::new(); $nodelist->loadlist(\@node_list);  }
    else { $message->missing_node_cmdline(2); return 0; }

    if (! $nodelist) { $message->missing_node_cmdline(2); return 0; }

    if ((! $type) && (!$kernel))
    {	display_pxetype($nodelist); 	exit 0;     }
    
    if ($type eq "pxegrubfloppy")  { $fromdisk=1; }
    if ($fromdisk && $fromtftp)     { $message->message(2,"fromdisk and fromtftp excluded..."); exit 1; }
    if ($fromdisk)        { $fromtftp=0;  }
    if ($fromtftp)        { $fromdisk=0;  }
    
    if ($partnumbercmdline) { $partnumber=$partnumbercmdline;}
    if ($disknumbercmdline) { $disknumber=$disknumbercmdline;}
    if ($slicecmdline)      { $slice=$slicecmdline; }

    if ($partnumbercmdline && (! $disknumbercmdline)) { $disknumber=1; }

    if ( (! ($type =~ /^pxe.+/)) && (! $partnumber))
    { $message->missing_cmdline(2,"partnumber needed"); return 1;   }   

    if ($partnumbercmdline)
    {
	$disks=libkadeploy2::disks::new($nodelist);
	if (! $disks->check_disk_type($disknumber)) { return 0; }
	$disktype=$disks->get_disk_type($disknumber);
    }        
    return 1;
}

sub display_pxetype($)
{
    my $nodelist=shift;
    my $ref_node_list;
    my @node_list;
    my $nodename;
    my $line;
    my $node;
   
    $ref_node_list=$nodelist->get_nodes();
    @node_list=@$ref_node_list;

    foreach $node (@node_list)
    {
	$nodename=$node->get_name();
	open(PXETYPE,"$tftproot/$nodename/pxetype") or die "Can't open \"$tftproot/$nodename/pxetype\"";
	while ($line=<PXETYPE>) { print "$nodename : $line\n"; }
	close(PXETYPE);
    }
}


sub check_right($)
{
    my $righttocheck=shift;
    return libkadeploy2::karights::check_rights($nodelist,$righttocheck);
}

sub setup_pxebootloader($$)
{
    my $nodelist=shift;
    my $pxebootloader=shift;
    my $pxeloaderpath;
    my $ref_node_list;
    my @node_list;
    my $node_name;
    my $node;
    my $ok=1;

    $ref_node_list=$nodelist->get_nodes();
    @node_list=@$ref_node_list;

    if ($pxebootloader eq "pxegrub")
    {
	$pxeloaderpath=$pxegrubpath;
	$bootloadername="pxegrub";
    }
    elsif ($pxebootloader eq "pxelinux")
    {
	$pxeloaderpath=$pxelinuxpath;
	$bootloadername="pxelinux";
    }
    elsif ($pxebootloader eq "pxeopenbsd")
    {
	$pxeloaderpath=$pxeopenbsdpath;
	$bootloadername="pxeopenbsd";
    }
    elsif ($pxebootloader eq "pxegrubfloppy")
    {
	$pxeloaderpath=$pxelinuxpath;
	$bootloadername="'pxelinux (pxelinux-memdisk-grub.img)'";
    }
    elsif ($pxebootloader eq "pxewindowsfloppy")
    {
	$pxeloaderpath=$pxelinuxpath;
	$bootloadername="'pxelinux (pxelinux-memdisk-ntldr.img)'";
    }

    foreach $node (@node_list)
    {
	$node_name=$node->get_name();
	copy("$pxeloaderpath","$tftproot/pxeloader-$node_name") or $ok=0;
    }
    return $ok;    
}

sub set_pxeloadertype()
{
    my $ref_node_list;
    my @node_list;
    my $node_name;
    my $node;
    my $ok;

    $ref_node_list=$nodelist->get_nodes();
    @node_list=@$ref_node_list;
    foreach $node (@node_list)
    {
	$node_name=$node->get_name();
	system ("echo $bootloadername > $tftproot/$node_name/pxetype") or $ok=0;
    }

}



sub clean_tftpnodes($)
{
    my $nodelist=shift;
    my $ref_node_list;
    my @node_list;
    my $node_name;
    my $node;

    $ref_node_list=$nodelist->get_nodes();
    @node_list=@$ref_node_list;

    foreach $node (@node_list)
    {
	$node_name=$node->get_name();
	system("rm -f $tftproot/$node_name/*");
    }
}

sub copy_kernel_initrd_modules_tftpnodes($)
{
    my $nodelist=shift;
    my $ok=1;
    if (! -f $kernel) { $message->filenotfound(2,$kernel); $ok=0; }
    else { $ok=copy_bootfile_tftpnodes($nodelist,$kernel); }
    if ($initrd && $ok)
	{
	    if (! -f $initrd) { $message->filenotfound(2,$initrd); $ok=0; }
	    else { $ok=copy_bootfile_tftpnodes($nodelist,$initrd); }
	}
    if ($module && $ok)
    {
	if (! -f $module) { $message->filenotfound(2,$module); $ok=0; }
	else { $ok=copy_bootfile_tftpnodes($nodelist,$module); }
    }
    return $ok;
}

sub copy_bootfile_tftpnodes($$)
{
    my $nodelist=shift;
    my $bootfile=shift;
    my $ref_node_list;
    my @node_list;
    my $node_name;
    my $node;
    my $ok=1;

    $ref_node_list=$nodelist->get_nodes();
    @node_list=@$ref_node_list;


    foreach $node (@node_list)
    {
	$node_name=$node->get_name();
	mkdir("$tftproot/$node_name",0755);	
	if (! copy_tftpnode($bootfile,$node_name)) { $ok=0; }
	chmod(0755,"$tftproot/$node_name/");    
	chmod(0755,"$tftproot/$node_name/$bootfile");    
    }
    return $ok;
}

sub copy_tftpnode($$)
{
    my $source=shift;
    my $node_name=shift;
    my $ok=1;
    if ( -r "$source")
    { 
	$message->message(-1,"copying $source to $tftproot/$node_name");
	copy("$source","$tftproot/$node_name/");
    }
    else
    { 
	$message->message(2,"Can't copy $source to $tftproot/$node_name"); 
	$ok=0; 
    }       
    return $ok;
}




1;

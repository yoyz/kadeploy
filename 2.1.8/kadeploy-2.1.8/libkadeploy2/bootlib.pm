package libkadeploy2::bootlib;

use strict;
use warnings;

use File::Copy;
use libkadeploy2::conflib;
use libkadeploy2::hexlib;
use libkadeploy2::debug;
use libkadeploy2::cache;
use libkadeploy2::pathlib;

# for the reboot...
use POSIX qw(:signal_h :errno_h :sys_wait_h);

# if(!(libkadeploy2::conflib::check_cmd_exist() == 1)){
#    print "ERROR : command configuration file loading failed\n";
#    exit 0;
#}

## prototypes
sub setup_grub_pxe($$$);
sub manage_grub_pxe($$$);
sub generate_grub_files($$$$$$$$);
sub generate_nogrub_files($$$$$$$);
sub setup_pxe($$$$$);
sub reboot($$$$);

## global variables declaration
my $cachedir = "/var/cache/kadeploy";

## module configuration
my $configuration;

sub register_conf {
	$configuration = shift;
}



## function definition


## setup_grub_pxe
## wrapper kadeploy - manage_grub_pxe
## parameters : base, deployment identifier
## return value : -1 in case of error, 1 otherwise
sub setup_grub_pxe($$$){
    my $dbh = shift;
    my $deploy_id = shift;
    my $user_request_grub = shift;
    
    my @env_info = libkadeploy2::deploy_iolib::deploy_id_to_env_info($dbh,$deploy_id);
    my %node_info = libkadeploy2::deploy_iolib::deploy_id_to_node_info($dbh,$deploy_id);
    my $ret = manage_grub_pxe(\%node_info,\@env_info, $user_request_grub);
    return $ret;
}

## manage_grub_pxe
## setups grub and pxe 
## parameters : base, ref to host info, ref to env info
## return value : 1 if successful
sub manage_grub_pxe($$$){
    my $ref_to_node_info = shift;
    my $ref_to_env_info  = shift;
    my $user_request_grub = shift;
    
    my %node_info = %{$ref_to_node_info};
    my @env_info  = @{$ref_to_env_info};
    
    my $env = $env_info[0];
    my $kernel_path = $env_info[1];
    my $kernel_param = $env_info[2];
    my $initrd_path = $env_info[3];
    my $env_id = $env_info[4];
    my $env_archive = $env_info[5];
    my $env_fdisktype = $env_info[6];
    $env_archive = substr($env_archive,6);

    my $custom_kernel_parameters = $configuration->get_conf("custom_kernel_parameters");
    libkadeploy2::debug::debugl(3, "GRUB request : ".$user_request_grub."\n");
    my $nogrub = 1;
    $nogrub = $configuration->get_conf("use_nogrub");
    if ($nogrub) {
	libkadeploy2::debug::debugl(3, "GRUB not available.\n");
    } else {
	libkadeploy2::debug::debugl(3, "GRUB available.\n");	
    }
    if (!$nogrub) {
      # Check whether user has requested GRUB usage ; otherwise do not use GRUB (nogrub = 1)
      if ($user_request_grub) {
	# Use GRUB : available and user requested
        $nogrub = 0;
      } else {
	# Do NOT use GRUB : available but NOT requested
	$nogrub = 1;
      }
    }
    if ($nogrub) { 
	libkadeploy2::debug::debugl(3, "GRUB won't be used.\n");    
    } else { 
	libkadeploy2::debug::debugl(3, "GRUB will be used.\n");    
    }
    
    my $clustername = $configuration->get_clustername();
    my $filename_append = "-" . $clustername;
    if ($clustername eq "") { # smooth transition from mono to multi cluster names
	    $filename_append = "";
    }
    
    my %devices = ();

    if (! $kernel_param) { 
	# Take default parameters if any
	libkadeploy2::debug::debugl(3, "No kernel parameter, taking default ones defined in the configuration file\n");
	$kernel_param = $configuration->get_conf("kernel_param");
    }
    if (!$custom_kernel_parameters eq "") { 
	# User-defined kernel parameters
	libkadeploy2::debug::debugl(3, "using custom kernel parameters: " . $custom_kernel_parameters . "\n");
	# Compute basic checksum
	my $checksum = 0;
	my $ascval;
	foreach $ascval (unpack("C*", $custom_kernel_parameters)) {
            $checksum += $ascval;
	}
	$filename_append = $filename_append . $checksum;
	$kernel_param = $custom_kernel_parameters;
    }
    
    my $tftp_destination_folder = $configuration->get_conf("tftp_repository") . $configuration->get_conf("tftp_relative_path");
    libkadeploy2::cache::init_cache($tftp_destination_folder);
    
    my $pxe_kernel_parameters;
    my @pxe_ips;
    my @pxe_kernels;
    my @pxe_initrds;

    my $gen_grub_entry = 0; # grub entry should be generated everytime a new (dev, part) is used
    my $gen_pxe_entry = 1; # PXE entry should be generated only once

    my $grub_boot_img_name;
    my $grub_menu_file_name;
    my $firstipx;
    my $firstnode = 1;
    my $iphexalized = "AABBCCDD";
    
    ## Global loop in case differents node would be associated to different devices and partitions
    ## (it should be the case in futur development steps)
    foreach my $ip (keys %node_info){

	my $multiboot = 0;
	my $dev = $node_info{$ip}[0];
	my $part = $node_info{$ip}[1];

	$gen_grub_entry = 0;
	if (!exists $devices{$dev.$part}) {
	    $gen_grub_entry = 1;
	    $devices{$dev.$part} = 1;
	}

	my $current_kernel = "";
	my $current_initrd = "";
	my $ret = 0;
	$iphexalized = libkadeploy2::hexlib::gethostipx($ip);
	# Generate PXE environment folder for current node
	if ( $nogrub ) { 
	    # -------------
            # PXE boot mode
	    # -------------
	    # For PXE generated files
	    my $pxe_tftp_relative_folder = $iphexalized . "/"; 
	    my $pxe_dest_folder = $tftp_destination_folder . "/" . $pxe_tftp_relative_folder;

	    if ( $gen_pxe_entry ) {
		$firstipx=$iphexalized;
		libkadeploy2::debug::debugl(3, "Generating PXE conf for [1st node] : $ip, kernel_path = $kernel_path, initrd_path = $initrd_path\n");
		generate_nogrub_files($env_archive, $kernel_path, $initrd_path, $pxe_dest_folder, $firstipx, $firstnode, $env_id);
		$gen_pxe_entry = 0; # generated once
		$firstnode = 0;     # next processing different as for 1st node
	    } else {
		libkadeploy2::debug::debugl(3, "Generating PXE conf for [Other nodes] : $ip, kernel_path = $kernel_path, initrd_path = $initrd_path\n");
		generate_nogrub_files($env_archive, $kernel_path, $initrd_path, $pxe_dest_folder, $firstipx, $firstnode, $env_id);
	    }

	    $pxe_kernel_parameters = " root=/dev/" . $dev . $part . " " . $kernel_param;
	    
	    # Strip leading directories from kernel and initrd filenames for PXE setup configuration
	    $current_kernel = libkadeploy2::pathlib::strip_leading_dirs($kernel_path);
	    if (libkadeploy2::pathlib::check_multiboot($current_kernel)) {
		$multiboot = 1;
	    } else {
		$multiboot = 0;
	    }
	    if (!$multiboot) {
		$current_initrd = libkadeploy2::pathlib::strip_leading_dirs($initrd_path);
	    } else {
		$current_initrd = $initrd_path;
	    }
	    # Prepare the PXE setup
	    push(@pxe_ips, $ip);
	    if (!$multiboot) {
		push(@pxe_kernels, $pxe_tftp_relative_folder.$current_kernel);
		push(@pxe_initrds, $pxe_tftp_relative_folder.$current_initrd.$pxe_kernel_parameters);
	    } else {
		push(@pxe_kernels, $current_kernel);
		push(@pxe_initrds, $current_initrd);
	    }

	} else { 
	    # --------------
	    # GRUB boot mode
	    # --------------
	    if ($kernel_path =~ /^chainload$/) {	
		# Since deployed bootloader is used, generated file does not depend of clustername
		$grub_boot_img_name = "grub_img_chainload_env".$iphexalized."_".$dev.$part;
		$grub_menu_file_name = "grub_menu_chainload_env".$iphexalized."_".$dev.$part;
		
		$ret = libkadeploy2::bootlib::generate_grub_files_chainload($grub_boot_img_name,$grub_menu_file_name,"rebootchainload","$dev$part",$env_fdisktype);
		if ($ret != 1) {return -1};
		copy("/tmp/$grub_boot_img_name", "$tftp_destination_folder");
		$tftp_destination_folder = $configuration->get_conf("tftp_repository") . $configuration->get_conf("tftp_relative_path");
		copy("/tmp/$grub_boot_img_name", "$tftp_destination_folder");	       
	    } else {
		# File generated here depends of cluster configuration
		$grub_boot_img_name = "grub_img_env".$env_id."_".$dev.$part.$filename_append;
		$grub_menu_file_name = "grub_menu_env".$env_id."_".$dev.$part.$filename_append;
		
		if ( $gen_grub_entry ) { 
		    # Generate with every unknown device
		    $ret = libkadeploy2::bootlib::generate_grub_files($grub_boot_img_name, $grub_menu_file_name, "reboot", "$dev$part", $kernel_path, $kernel_param, $initrd_path,$env_fdisktype);
		    if ($ret != 1) {return -1};
		    copy("/tmp/$grub_boot_img_name", "$tftp_destination_folder");
		    $tftp_destination_folder = $configuration->get_conf("tftp_repository") . $configuration->get_conf("tftp_relative_path");
		    copy("/tmp/$grub_boot_img_name", "$tftp_destination_folder");
		}
	    }

	    # setups PXE
	    # host_name/host-range:memdisk:$grub_boot_img_name
	    push(@pxe_ips, $ip);
	    push(@pxe_kernels, "memdisk");
	    push(@pxe_initrds, $grub_boot_img_name);
	}
    }
    # sends grub image on the appropriate server
    libkadeploy2::bootlib::setup_pxe(\@pxe_ips, \@pxe_kernels, \@pxe_initrds, $pxe_kernel_parameters, $user_request_grub);

    return 1;
}



## generate_nogrub_files
## generate_nogrub_files generates required files for a nogrub boot
## parameters : env_archive, kernel_path, initrd_path, destination folder, 
## first IP of the deployment, boolean value on first node
## return value : 1 if successful
sub generate_nogrub_files($$$$$$$)
{
    my $env_archive = shift;
    my $kernel_path = shift;
    my $initrd_path = shift;
    my $dest_folder = shift;
    my $firstipx    = shift;
    my $firstnode   = shift;
    my $env_id      = shift;
    
    if (-d $dest_folder ) 
    {
	# discard last folder content
	libkadeploy2::debug::system_wrapper("/bin/rm -rf $dest_folder");
    } 
    # create $dest_folder
    libkadeploy2::debug::system_wrapper("/bin/mkdir $dest_folder");
    my $files;
    my $file1 = $kernel_path;
    my $file2;
    my $file3;
    my $file4;
    
    # Test if we are in multiboot case ($kernel_path = mboot.c32)
    my $multiboot = libkadeploy2::pathlib::check_multiboot($file1);
    if ($multiboot) {
	# Retrieve each part between --- separator
	my @mbfiles = split /-{3}/, $initrd_path;
	$file2 = shift(@mbfiles); # Xen Hypervisor
	$file3 = shift(@mbfiles); # Kernel
	$file4 = shift(@mbfiles); # Ramdisk
	
	# Retrieve only the filename part
	my @tfile2 = split /\s+/, $file2;
	if (libkadeploy2::pathlib::is_valid($tfile2[0])) {
	    $file2 = $tfile2[0];
	    $file2 =~ s/^\s*//;
	} else {
	    $file2 = $tfile2[1];
	    $file2 =~ s/^\s*//;
	}
	my @tfile3 = split /\s+/, $file3;
	if (libkadeploy2::pathlib::is_valid($tfile3[0])) {
	    $file3 = $tfile3[0];
	    $file3 =~ s/^\s*//;
        } else {
	    $file3 = $tfile3[1];
	    $file3 =~ s/^\s*//;
	}
	if (libkadeploy2::pathlib::is_valid($file4)) {
	    my @tfile4 = split(/\s+/,$file4);
	    if (libkadeploy2::pathlib::is_valid($tfile4[0])) {
		$file4 = $tfile4[0];
		$file4 =~ s/^\s*//;
	    } else {
		$file4 = $tfile4[1];
		$file4 =~ s/^\s*//;
	    }
        }
    } elsif ($initrd_path) { 
	$file2 = $initrd_path; 
    }
      
    if ($firstnode) 
    {
	# =======================================================
	# For 1st node of the deployment :
	# 1) Put securely files in cache.
	#   --> if file is already in cache, not extracted again.
	# 2) Make links to those cached files.
	# =======================================================
	
	my @files;
	# Strip leading / from filenames 	
	# Do not add mboot.c32 at files to extract from archive in case of multiboot mode.
	if (!$multiboot) {
	    $file1 = libkadeploy2::pathlib::strip_leading_slash($file1);
	    push(@files, $file1);
	}
	if (($file2) && (libkadeploy2::pathlib::is_valid($file2))) {
	    $file2 = libkadeploy2::pathlib::strip_leading_slash($file2);
	    push(@files, $file2);
	}
	if ($multiboot) {
	    if (libkadeploy2::pathlib::is_valid($file3)) {
	      $file3 = libkadeploy2::pathlib::strip_leading_slash($file3);
	      push(@files, $file3);
	    }
	    if (libkadeploy2::pathlib::is_valid($file4)) {
	      $file4 = libkadeploy2::pathlib::strip_leading_slash($file4);
	      push(@files, $file4);
	    }
	}
       
	libkadeploy2::cache::put_in_cache_from_archive(\@files, $env_archive, 1, $env_id);
        
        # Retrieve relative path to cache from PXE destinatation directory
	my $tftprelative = libkadeploy2::cache::get_cache_directory_tftprelative(1);
	
        # Strip leading directories from filenames
	if (!$multiboot) {
	    $file1 = libkadeploy2::pathlib::strip_leading_dirs($file1);
	    libkadeploy2::debug::system_wrapper("cd $dest_folder && ln -s $tftprelative/$file1.$env_id $file1");
	}

	if (libkadeploy2::pathlib::is_valid($file2)) {
	    $file2 = libkadeploy2::pathlib::strip_leading_dirs($file2);
	    libkadeploy2::debug::system_wrapper("cd $dest_folder && ln -s $tftprelative/$file2.$env_id $file2");
	}

	if ($multiboot) {
	    if (libkadeploy2::pathlib::is_valid($file3)) {
	      $file3 = libkadeploy2::pathlib::strip_leading_dirs($file3);
	      libkadeploy2::debug::system_wrapper("cd $dest_folder && ln -s $tftprelative/$file3.$env_id $file3");
	    }
	    if (libkadeploy2::pathlib::is_valid($file4)) {
	      $file4 = libkadeploy2::pathlib::strip_leading_dirs($file4);
	      libkadeploy2::debug::system_wrapper("cd $dest_folder && ln -s $tftprelative/$file4.$env_id $file4");
	    }
	}
   }
   else 
   {
       # ===================================================================
       # For other nodes of the deployment : 
       # 1) Make symbolic links to the previously extracted kernel + initrd.
       # 2) Strip current machine directory from TFTP path.
       # ===================================================================
       
       my $tftp_dir = $dest_folder;
       $tftp_dir =~ s/\/[^\/]+\/??$//;

       # Strip leading directories from kernel and initrd filenames
       # and make link to original file
       if (!$multiboot) {
	   $file1 = libkadeploy2::pathlib::strip_leading_dirs($file1);
	   libkadeploy2::debug::system_wrapper("cd $dest_folder && ln -s ../$firstipx/$file1 $file1");
       }

       if (libkadeploy2::pathlib::is_valid($file2)) {
	   $file2 = libkadeploy2::pathlib::strip_leading_dirs($file2);
	   libkadeploy2::debug::system_wrapper("cd $dest_folder && ln -s ../$firstipx/$file2 $file2");
       }

       if ($multiboot) {
	   if (libkadeploy2::pathlib::is_valid($file3)) {
	       $file3 = libkadeploy2::pathlib::strip_leading_dirs($file3);
	       libkadeploy2::debug::system_wrapper("cd $dest_folder && ln -s ../$firstipx/$file3 $file3");
	   }
	   if (libkadeploy2::pathlib::is_valid($file4)) {
	       $file4 = libkadeploy2::pathlib::strip_leading_dirs($file4);
	       libkadeploy2::debug::system_wrapper("cd $dest_folder && ln -s ../$firstipx/$file4 $file4");
	   }
       }
   }
   return 1;
}



## added by yoyz
## generate_grub_files
## generate_grub_files to chainload
## return value : 1 if successful
sub generate_grub_files_chainload($$$$){
    my $output = shift;
    my $menu   = shift;
    my $title  = shift;
    my $root   = shift;
    my $fdisktype = shift;

    ## "hard-coded" options
    my $grub_dir = $configuration->get_conf("kadeploy2_directory") . "/grub";    
    my $floppy_blks = 720;
    my $default = 0;
    my $fallback = 1;
    my $timeout = 1;
    my $serial_speed = 38400;
    my $timeout_conf = $configuration->get_conf("grub_timeout");
    my $hexfdisktype;


  if($timeout_conf){
     $timeout = $timeout_conf;
  }

    ## let's put the generated files in the /tmp/ directory
    $output = "/tmp/".$output;
    $menu = "/tmp/".$menu;
	       
    my $base_grub_image="$grub_dir/grub.img"; # a grub 360ko floppy image
    if (!-e $base_grub_image) {
	libkadeploy2::debug::debugl(0, "ERROR : file $base_grub_image does not exist or path is incorrect\n");
	return -1;
    }
    my $menu_len=2;
    my $menu_offset=718;
	       
    my $i = 0;
    open(MENU,">$menu");
    # print MENU "#autogen grub conf file\nserial --unit=0 --speed=$serial_speed\nterminal --timeout=0 serial\ntimeout $timeout\ncolor black/red yellow/red\ndefault $default\nfallback $fallback\n";
    print MENU "timeout $timeout\ncolor black/red yellow/red\ndefault $default\nfallback $fallback\n";
    my $dev = substr($root, 0, 3);
    my @nb = split(/$dev/, $root);
    my $part = $nb[1] - 1;
    my $letter = chop($dev);
	
	       

    # to be improved...
    if ($letter eq "a"){
	$letter = "0";
    }elsif ($letter eq "b"){
	$letter = "1";
    }

   $hexfdisktype=libkadeploy2::hexlib::hexalize($fdisktype);

	 

    print MENU "\ntitle $title\nparttype (hd$letter,$part) 0x$hexfdisktype\nrootnoverify (hd$letter,$part)\nmakeactive\nchainloader +1\nboot\n";
    
    close MENU;
	       
    libkadeploy2::debug::debugl(3, "* Copying grub base image\n");
    libkadeploy2::debug::system_wrapper("cp $base_grub_image $output");
    libkadeploy2::debug::debugl(3, "* Modifying grub menu at block $menu_offset\n");
    libkadeploy2::debug::system_wrapper("dd if=$menu of=$output bs=512 seek=$menu_offset count=$menu_len conv=notrunc");
    libkadeploy2::debug::debugl(3, "$output has been generated.\n");
    return 1;
}




## simplified and corrected by Jul'
## generate_grub_files
## generate_grub_files generates grub image and menu
## parameters : image_output_name, menu_name, title, root, kernel, param
## return value : 1 if successful
sub generate_grub_files($$$$$$$$){
    my $output = shift;
    my $menu   = shift;
    my $title  = shift;
    my $root   = shift;
    my $kernel = shift;
    my $param  = shift;
    my $initrd_path = shift;
    my $fdisktype = shift;

    # debug print
    # print "OUT = $output ; MENU = $menu ; TITLE = $title ; ROOT = $root ; KER = $kernel ; PARAM = $param\n";

    ## "hard-coded" options
    my $grub_dir = $configuration->get_conf("kadeploy2_directory") . "/grub";    
    my $floppy_blks = 720;
    my $default = 0;
    my $fallback = 1;
    my $timeout = 1;
    my $serial_speed = 38400;
    my $hexfdisktype;

    my $timeout_conf = $configuration->get_conf("grub_timeout");
    if($timeout_conf){
	$timeout = $timeout_conf;
    }

    $hexfdisktype=libkadeploy2::hexlib::hexalize($fdisktype);

    ## let's put the generated files in the /tmp/ directory
    $output = "/tmp/".$output;
    $menu = "/tmp/".$menu;
	       
    my $base_grub_image="$grub_dir/grub.img"; # a grub 360ko floppy image
    if (!-e $base_grub_image) {
	libkadeploy2::debug::debugl(0, "ERROR : file $base_grub_image does not exist or path is incorrect\n");
	return -1;
    }
    my $menu_len=2;
    my $menu_offset=718;
	       
    my $i = 0;
    open(MENU,">$menu");
    # print MENU "#autogen grub conf file\nserial --unit=0 --speed=$serial_speed\nterminal --timeout=0 serial\ntimeout $timeout\ncolor black/red yellow/red\ndefault $default\nfallback $fallback\n";
    print MENU "timeout $timeout\ncolor black/red yellow/red\ndefault $default\nfallback $fallback\n";
    my $dev = substr($root, 0, 3);
    my @nb = split(/$dev/, $root);
    my $part = $nb[1] - 1;
    my $letter = chop($dev);
	
    # to be improved...
    if ($letter eq "a"){
	$letter = "0";
    }elsif ($letter eq "b"){
	$letter = "1";
    }

    if (!$param){
	print MENU "\ntitle $title\nparttype (hd$letter,$part) 0x$hexfdisktype\nroot (hd$letter,$part)\nkernel $kernel root=/dev/$root\n";
    }else{
	print MENU "\ntitle $title\nparttype (hd$letter,$part) 0x$hexfdisktype\nroot (hd$letter,$part)\nkernel $kernel root=/dev/$root $param\n";
    }
    if ($initrd_path){
	print MENU "initrd $initrd_path\n";
    }
    close MENU;

    libkadeploy2::debug::debugl(3, "* Copying grub base image\n");
    libkadeploy2::debug::system_wrapper("cp $base_grub_image $output");
    libkadeploy2::debug::debugl(3, "* Modifying grub menu at block $menu_offset\n");
    libkadeploy2::debug::system_wrapper("dd if=$menu of=$output bs=512 seek=$menu_offset count=$menu_len conv=notrunc");
    libkadeploy2::debug::debugl(3, "$output has been generated.\n");

    return 1;
}


## setup_pxe
## setup_pxe generate files for the tftp/dhcp server
## parameters : ips, kernels, initrds in arrays
## return value : 1 if successful
sub setup_pxe($$$$$){
    my $ref_to_reboot = shift;
    my $ref_to_kernel = shift;
    my $ref_to_initrd = shift;
    my $pxe_kernel_parameters = shift;
    my $user_request_grub = shift;
    
    my @to_reboot = @{$ref_to_reboot};
    my @kernels = @{$ref_to_kernel};
    my @initrds = @{$ref_to_initrd};

    my $PROMPT = 1;
    my $DISPLAY = "messages";
    my $TIMEOUT = 50;
    my $nogrub = 1;

    # Gets appropriate parameters from configuration file
    # my $network = conflibkadeploy2::get_conf("network");
    my $tftp_repository = $configuration->get_conf("tftp_repository");
    my $pxe_rep = $tftp_repository . $configuration->get_conf("pxe_rep");
    my $tftp_relative_path = $configuration->get_conf("tftp_relative_path");
    
    my $images_repository = $tftp_repository . $tftp_relative_path;    
    
    my @hexnetworks;
    
    my $template_default_content="PROMPT $PROMPT\nDEFAULT bootlabel\nDISPLAY $DISPLAY\nTIMEOUT $TIMEOUT\n\nlabel bootlabel\n";
    
    my $kernel;
    my $append="";
    $nogrub = $configuration->get_conf("use_nogrub");
    if ($nogrub) {
      libkadeploy2::debug::debugl(3, "GRUB not available.\n");
    } else {
      libkadeploy2::debug::debugl(3, "GRUB available.\n");
    }
    if (!$nogrub) {
    # Check whether user has requested GRUB usage ; otherwise do not use GRUB (nogrub = 1)
      if ($user_request_grub) {
      # Use GRUB : available and user requested
        $nogrub = 0;
      } else {
      # Do NOT use GRUB : available but NOT requested
        $nogrub = 1;
      }
    }
    if ($nogrub) {
      libkadeploy2::debug::debugl(3, "GRUB won't be used.\n");
    } else {
      libkadeploy2::debug::debugl(3, "GRUB will be used.\n");
    }
    
    # Generate files in PXE directories and overwrite old ones
    # Note : loops on kernels and IPs.
    for (my $i=0; $i<scalar(@kernels); $i++) 
    {
	libkadeploy2::debug::debugl(3, "PXE files generation for current kernel = $kernels[$i], current initrd = $initrds[$i]\n");
	my $current_kernel = $kernels[$i];
	my $current_initrd = $initrds[$i];
	my $multiboot = 0;
	
	if (libkadeploy2::pathlib::check_multiboot($current_kernel)) {
	    # Case we are NOT in multi-boot mode
	    $multiboot = 1;
	    libkadeploy2::debug::debugl(3, "--- Multiboot usecase detected\n");
	} else {
	    $multiboot = 0;
	    $current_kernel = libkadeploy2::pathlib::strip_leading_dirs($current_kernel);
	    $current_initrd =~ s/^[a-fA-F0-9]{8}\/(.*)$/$1/;
	    libkadeploy2::debug::debugl(3, "Standard boot usecase selected\n");
	}
	
	foreach my $ip (@to_reboot) {
	    
	    my $hex_ip = libkadeploy2::hexlib::gethostipx($ip);
	    my $destination=$pxe_rep.$hex_ip;
	    
	    if ($nogrub) {
		# -------------
		# PXE boot mode
		# -------------
		if (!$multiboot) {
		    # Case we are NOT in multiboot mode
		    $kernel = $tftp_relative_path."/".$hex_ip."/".$current_kernel;
		    $append = "initrd=".$tftp_relative_path."/".$hex_ip."/".$current_initrd;
		} else {
		    # Case we are in multiboot mode
		    # Get each multiboot item 

		    my @mbfiles = split /-{3}/,$current_initrd;
		    my $a=1;
		    $append = "";
		    foreach my $f (@mbfiles) {
			# Foreach multiboot item :
			# 1) Translate leading path into local PXE dirs
			# 2) Keep local parameters
			$f =~ s/^\s*//;
			my @tf = split /\s+/, $f;
			my $tff;
			if (libkadeploy2::pathlib::is_valid($tf[0])) {
			    $tff = $tf[0];
			} else {
			    $tff = $tf[1];
			}
			$tff = libkadeploy2::pathlib::strip_leading_dirs($tff);
			$tff = $tftp_relative_path."/".$hex_ip."/".$tff;
			$append = $append.$tff." ";

			if ( $a == 2 ) {
			    # Kernel item slot ; put PXE kernel parameters here
			    $append = $append.$pxe_kernel_parameters." ";
			}
			if ( $a < scalar(@mbfiles) ) {
			    # End of multiboot item : put a --- separator
			    $append = $append."--- ";
			}
			$a++;
		    }
		    # In multiboot mode : kernel = mboot.c32
		    $kernel = libkadeploy2::pathlib::strip_leading_dirs($current_kernel);
		}
            } else {
		# --------------
		# GRUB boot mode
		# --------------
                $kernel = $tftp_relative_path . "/" . $current_kernel;
		$append = "initrd=" . $tftp_relative_path . "/" . $current_initrd;
            }
	    libkadeploy2::debug::debugl(3, "Building PXE boot conf : $append\n");
	    
	    open(DEST, "> $destination") or die "Couldn't open $destination for writing: $!\n";
	    print DEST "$template_default_content\tKERNEL $kernel\n\tAPPEND $append";
	    close(DEST);
	}
    }

    return 1;
}

## reboot
## reboots the given nodes according to the appropriate method
## parameters : ref to host list, soft, hard, deploy
## return value : 1 if successful
sub reboot($$$$){
    my $ref_to_host_list = shift;
    my $soft = shift;
    my $hard = shift;
    my $deploy = shift;
    my $reboot = "";
    
    my @host_list = @{$ref_to_host_list};


    # defines correct reboot type
    if ($deploy){
	$reboot = "deployboot";
    }elsif ($soft){
	$reboot = "softboot";
    }elsif ($hard){
	$reboot = "hardboot";
    }else{
	print "ERROR : this case should never happen... you are in big trouble...\n";
	exit 0;
    }
    ## Available variables are :
    ## - @host_list - list of hosts to reboot
    ## - $reboot    - type of reboot

    my %cmd = $configuration->check_cmd();

    my $child_pid;
    my %child_pids = ();
    
    foreach my $host (@host_list){
	if(!$cmd{$host}{$reboot}) {
	    libkadeploy2::debug::debugl(3, "WARNING : no $reboot command found for $host !\n");
	} else {
	    # debug print
	    # print "to be executed : $host -> $cmd{$host}{$reboot}\n";
	    if (!defined($child_pid = fork())) {
                die "cannot fork: $!";
	    } elsif ($child_pid) {
                # I'm the parent
                print "Forking child $child_pid\n";
                $child_pids{$host} = $child_pid;
	    } else {
                print "child\n";
		# set the deployboot if necessary
		if ($deploy) {
		    libkadeploy2::debug::system_wrapper("$cmd{$host}{$reboot}");
		}
		if ($hard) 
		{		    
		    libkadeploy2::debug::exec_wrapper("$cmd{$host}{\"hardboot\"}") or die "Couldn't execute hardboot $host $cmd{$host}{\"hardboot\"}: $!\n";
		} 
		else 
		{
		    libkadeploy2::debug::exec_wrapper("$cmd{$host}{\"softboot\"}") or die "Couldn't execute softboot $host $cmd{$host}{\"softboot\"}: $!\n";
		}
	    }
	}
    }
    # wait and kill hanged jobs
    sleep(10);
    foreach my $key (sort keys %child_pids) {
        my $jobtokill = $child_pids{$key};
	my $test = kill(9, $jobtokill);
	if ($test == 1) { # means that kill effectively signaled 1 job
	    if ($hard) {
		libkadeploy2::debug::debugl(3, "Warning: node $key did not hard reboot properly\n");
	    } 
#	    else {
#		print "Warning: node $key did not soft reboot properly\n";
#	    }
	}
    }
   
    return 1;
}

1;


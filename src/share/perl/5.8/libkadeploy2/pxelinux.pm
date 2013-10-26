package libkadeploy2::pxelinux_label;

use strict;
use warnings;
use libkadeploy2::message;
my $message=libkadeploy2::message::new();


sub new()
{
    my $self;
    $self=
    {
	name   => "",
	kernel => "",
	initrd => "",
	append => "",
    };
    bless $self;
    return $self;
}

sub set_name($)
{
    my $self=shift;
    my $name=shift;
    $self->{name}=$name;
}

sub set_kernel($)
{
    my $self=shift;
    my $kernel=shift;
    $self->{kernel}=$kernel;
}

sub set_initrd($)
{
    my $self=shift;
    my $initrd=shift;
    $self->{initrd}=$initrd;
}

sub set_append($)
{
    my $self=shift;
    my $append=shift;
    $self->{append}=$append;
}

sub get()
{
    my $self=shift;
    my $name=$self->{name};
    my $kernel=$self->{kernel};
    my $initrd=$self->{initrd};
    my $append=$self->{append};

    if (! $name || 
	! $kernel)
    {
	$message->message(2,"name or kernel not set !!!!");
	exit 1;	
    }

    my $label="
label $name
      kernel $kernel    
";
    if ($initrd && $append)
    {
	$label.="      append initrd=$initrd $append\n\n";
    }
    elsif ($append)
    {
	$label.="      append $append\n\n";
    }
    elsif ($initrd)
    {
	$label.="      append initrd=$initrd\n\n";	
    }

    return $label;
}

1;



package libkadeploy2::pxelinux;

use strict;
use warnings;

sub new()
{
    my $self;
    my %labellist=();
    my $reflabellist=\%labellist;
    
    $self=
    {
	timeout               => 5,
	defaultlabel          => "linux",
	message               => 0,
	label_list            => $reflabellist,
	firstserialportspeed  => 9600,
	secondserialportspeed => 9600,
    };
    bless $self;
    return $self;
}

sub set_serialspeed($$)
{
    my $self=shift;
    my $serialport=shift;
    my $serialportspeed=shift;

    if ($serialport==1)
    {
	$self->{firstserialportspeed}=$serialportspeed;
    }
    if ($serialport==2)
    {
	$self->{secondserialportspeed}=$serialportspeed;
    }
}

sub add($$$$)
{
    my $self=shift;

    my $name=shift;
    my $kernel=shift;
    my $initrd=shift;
    my $append=shift;

    my $label=libkadeploy2::pxelinux_label::new();
    my $ref_label_list=$self->{label_list};
    my %label_list=%$ref_label_list;


    $label->set_name($name);
    $label->set_kernel($kernel);
    $label->set_initrd($initrd);
    $label->set_append($append);
    $label_list{$name}=$label;

    $ref_label_list=\%label_list;
    $self->{label_list}=$ref_label_list;
}

sub set_default($)
{
    my $self=shift;
    
    my $defaultlabel=shift;
    $self->{defaultlabel}=$defaultlabel;
}

sub get()
{
    my $self=shift;

    my $ref_label_list=$self->{label_list};
    my %label_list=%$ref_label_list;
    my $key;
    my $defaultconf;
    my $labelentry;
    my $menu;
    my $defaultlabel;

    my $timeout=$self->{timeout};
    my $firstserialportspeed=$self->{firstserialportspeed};
    my $secondserialportspeed=$self->{secondserialportspeed};
    $defaultconf="serial 0 $firstserialportspeed
serial 1 $secondserialportspeed
prompt 1
timeout $timeout
";

    if ($self->{defaultlabel})
    {
	$defaultlabel=$self->{defaultlabel};
	$defaultconf.="
default $defaultlabel
";

    }



    foreach $key (keys %label_list)
    {
	my $label=$label_list{$key};
	my $str=$label->get();
	$labelentry.=$str;
    }
    
    $menu.=$defaultconf.$labelentry;

    return $menu;
}

1;

package libkadeploy2::pxelinuxtftp;

use strict;
use warnings;
use libkadeploy2::deployconf;


my $conf=libkadeploy2::deployconf::new();
if (! $conf->loadcheck()) { exit 1; }
my $tftproot=$conf->get("tftp_repository");
my $first_serial_speed;
my $second_serial_speed;
if ($conf->is_conf("first_serial_speed"))  { $first_serial_speed=$conf->get("first_serial_speed"); } else { $first_serial_speed=9600; }
if ($conf->is_conf("second_serial_speed")) { $second_serial_speed=$conf->get("second_serial_speed"); } else { $second_serial_speed=9600; }
my $sudo_user=libkadeploy2::sudo::get_sudo_user();
if (! $sudo_user) { $sudo_user=libkadeploy2::sudo::get_user(); }



sub new()
{
    my $self;
    $self=
    {
	nodelist     => 0,
	kernel       => "",
	initrd       => "",
	module       => "",
	kernelparams => "",
	disknumber   => "",
	partnumber   => "",
	slice        => "",
    };
    bless $self;
    return $self;
}


sub set_nodelist($)      { my $self=shift; $self->{nodelist}=shift; }
sub set_kernel($)        { my $self=shift; $self->{kernel}=shift; }
sub set_initrd($)        { my $self=shift; $self->{initrd}=shift; }
sub set_module($)        { my $self=shift; $self->{module}=shift; }
sub set_kernelparams($)  { my $self=shift; $self->{kernelparams}=shift; }

sub set_disknumber($)    { my $self=shift; $self->{disknumber}=shift; }
sub set_partnumber($)    { my $self=shift; $self->{partnumber}=shift;  }
sub set_slice($)         { my $self=shift; $self->{slice}=shift; }


sub readpxelinuxcfg()
{
    my $self=shift;
    my $nodelist=$self->{nodelist};
    my $node;
    my $ref_node_list;
    my @node_list;
    my $node_name;
    my $node_hexip;
    my $line;
    
    $ref_node_list=$nodelist->get_nodes();
    @node_list=@$ref_node_list;

    foreach $node (@node_list)
    {
	$node_name=$node->get_name();
	$node_hexip=libkadeploy2::hexlib::hexalizeip($node->get_ip());
	$message->message(-1,"show pxe for $node_name");
	$message->message(-1,"file path : $tftproot/pxelinux.cfg/$node_hexip");
	open(PXELINUXCFG,"$tftproot/pxelinux.cfg/$node_hexip") or die "Can't open $tftproot/pxelinux.cfg/$node_hexip";
	while ($line=<PXELINUXCFG>) { print $line; }
	close(PXELINUXCFG);
    }
}

sub generate_kernel_initrd_module_tftpnodes()
{
    my $self=shift;

    my @pathtokernel;
    my @pathtoinitrd;
    my @pathtomodule;

    @pathtokernel=split(/\//,$self->{kernel});
    $self->{kerneltftp}=$pathtokernel[$#pathtokernel];
    if ($self->{initrd})
    {
	my @pathtoinitrd=split(/\//,$self->{initrd});
	$self->{initrdtftp}=$pathtoinitrd[$#pathtoinitrd];
    }
    if ($self->{module})
    {
	my @pathtomodule=split(/\//,$self->{module});
	$self->{moduletftp}=$pathtomodule[$#pathtomodule];
    } 
}


sub writepxelinuxcfg()
{
    my $self=shift;
    my $nodelist=$self->{nodelist};
    my $node;
    my $ref_node_list;
    my @node_list;
    my $node_name;
    my $node_hexip;
    my $kerneltftpnode;
    my $initrdtftpnode;
    my $conffiledata;


    $self->generate_kernel_initrd_module_tftpnodes();

    $ref_node_list=$nodelist->get_nodes();
    @node_list=@$ref_node_list;

    foreach $node (@node_list)
    {
	$node_name=$node->get_name();
	if ($self->{kernel}) { $kerneltftpnode="$node_name/".$self->{kernel}; }
	if ($self->{initrd}) { $initrdtftpnode="$node_name/".$self->{initrd}; }

	$conffiledata=$self->generate_pxelinuxcfg_file($node_name,
						       "pxelinux-$node_name"
						       );

	$node_hexip=libkadeploy2::hexlib::hexalizeip($node->get_ip());
	$message->message(0,"$sudo_user setting up pxe for $node_name");
	mkdir("$tftproot/pxelinux.cfg",0755);
	open(PXELINUXCFG,"> $tftproot/pxelinux.cfg/$node_hexip") or 
	    die "Can't open $tftproot/pxelinux.cfg/$node_hexip";
	print PXELINUXCFG $conffiledata;
	close(PXELINUXCFG);
    }
}


sub generate_pxelinuxcfg_file($$$)
{
    my $self=shift;
    my $node_name=shift;
    my $title_name=shift;
    my $timeout=$self->{timeout};


    my $firstserialspeed;
    my $secondserialspeed;

    my $kerneltftp=$self->{kerneltftp};
    my $initrdtftp=$self->{initrdtftp};
    my $kernelparams=$self->{kernelparams};

    my $partnumber=$self->{partnumber};
    my $disknumber=$self->{disknumber};

    my $device;
    my $linuxdevice;
    my $conffile;
    my $disktype;
    my $disk;
    my $pxelinuxconf=libkadeploy2::pxelinux::new();

    if ($conf->is_conf("first_serial_speed"))  { $first_serial_speed=$conf->get("first_serial_speed"); } else { $first_serial_speed=9600; }
    if ($conf->is_conf("second_serial_speed")) { $second_serial_speed=$conf->get("second_serial_speed"); } else { $second_serial_speed=9600; }


    if (! $kernelparams) { $kernelparams=""; }

    if ($partnumber)
    {
	$disk=libkadeploy2::disk::new();
	$disk->get_fromdb($node_name,$disknumber);

    	$device=libkadeploy2::device::new($disk->get_interface(),$disknumber,$partnumber);
	$linuxdevice=$device->get("linux");
    }
    else
    {
	$linuxdevice="ram0";
    }

    $kernelparams=" root=/dev/$linuxdevice ".$kernelparams;

    if (! $kerneltftp) { $kerneltftp=""; } else { $kerneltftp="$node_name/$kerneltftp"; } 
    if (! $initrdtftp) { $initrdtftp=""; } else { $initrdtftp="$node_name/$initrdtftp"; }

    
    $pxelinuxconf->add("$title_name","$kerneltftp","$initrdtftp","$kernelparams");

    $pxelinuxconf->set_default("$title_name");
    $pxelinuxconf->set_serialspeed(1,$first_serial_speed);
    $pxelinuxconf->set_serialspeed(2,$second_serial_speed);
    $conffile=$pxelinuxconf->get();

    return $conffile;
}

1;

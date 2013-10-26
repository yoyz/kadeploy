package libkadeploy2::grub_label;
use strict;
use warnings;
use libkadeploy2::message;

my $message=libkadeploy2::message::new();

sub new()
{
    my $self;
    $self=
    {
	label   => "",
	kernel => "",
	initrd => "",
	module => "",
	append => "",



	disknumber => "",
	partnumber => "",
	slice      => "",

	fdisktype  => "",

	makeactive => "",
	chainload  => "",
	rootnoverify => "",
	networkroot => "",
    };
    bless $self;
    return $self;
}

sub set_label($)
{
    my $self=shift;
    my $label=shift;
    $self->{label}=$label;
}

sub set_kernel($)
{
    my $self=shift;
    my $kernel=shift;
    $self->{kernel}=$kernel;
}

sub set_disknumber($)
{
    my $self=shift;
    my $disknumber=shift;
    $self->{disknumber}=$disknumber;
}

sub set_partnumber($)
{
    my $self=shift;
    my $partnumber=shift;
    $self->{partnumber}=$partnumber;
}

sub set_slice($)
{
    my $self=shift;
    my $slice=shift;
    $self->{slice}=$slice;
}

sub set_fdisktype($)
{
    my $self=shift;
    my $fdisktype=shift;
    $self->{fdisktype}=$fdisktype;
}


sub set_initrd($)
{
    my $self=shift;
    my $initrd=shift;
    $self->{initrd}=$initrd;
}



sub set_module($)
{
    my $self=shift;
    my $module=shift;
    $self->{module}=$module;
}

sub set_append($)
{
    my $self=shift;
    my $append=shift;
    $self->{append}=$append;
}

sub set_rootnoverify()
{
    my $self=shift;
    $self->{rootnoverify}=1;
}

sub set_networkroot()
{
    my $self=shift;
    $self->{networkroot}=1;
}

sub set_chainload()
{
    my $self=shift;
    $self->{chainload}=1;
}

sub set_makeactive()
{
    my $self=shift;
    $self->{makeactive}=1;
}


sub get()
{
    my $self=shift;
    my $label=$self->{label};
    my $kernel=$self->{kernel};
    my $initrd=$self->{initrd};
    my $module=$self->{module};
    my $append=$self->{append};

    my $disknumber=$self->{disknumber};
    my $partnumber=$self->{partnumber};
    my $slice=$self->{slice};
    my $rootnoverify=$self->{rootnoverify};
    my $makeactive=$self->{makeactive};
    my $networkroot=$self->{networkroot};
    my $fdisktype=$self->{fdisktype};
    my $chainload=$self->{chainload};
    my $menulabel;

    if (($initrd || $module)  &&  ( ! $kernel) )
    { $message->message(2,"kernel  without initrd  (grub.pm)");	exit 1;} 
    if ( $chainload && $networkroot)
    { $message->message(2,"chainload with networkroot (grub.pm)"); exit 1; }

    $menulabel="title $label\n";

    if ($disknumber || $partnumber || $networkroot)
    {
	if ($rootnoverify)
	{ $menulabel.="rootnoverify ";  }
	else
	{ $menulabel.="root "; }
    }

    if ($networkroot)
    { 
	$menulabel.="(nd)";
    }
    elsif ($disknumber && $partnumber && $slice)
    { 
	$menulabel.="(hd".($disknumber-1).",".($partnumber-1).",".$slice.")";
    }
    elsif ($disknumber && $partnumber)
    { 
	$menulabel.="(hd".($disknumber-1).",".($partnumber-1).")";
    }
    $menulabel.="\n";

    if ($fdisktype && $disknumber && $partnumber)  
    { $menulabel.="parttype (hd".($disknumber-1).",".($partnumber-1).") 0x".$fdisktype."\n"; }
    if ($makeactive) { $menulabel.="makeactive\n"; }
    if ($chainload)  { $menulabel.="chainloader +1\n";  }

    else
    {
	if ($kernel)
	{
	    $menulabel.="kernel $kernel";
	    if ($append)
	    {
		$menulabel.=" $append";
	    }
	    $menulabel.="\n";
	}
	if ($initrd)
	{
	    $menulabel.="initrd $initrd\n";
	}
	elsif ($module)
	{
	    $menulabel.="module $module\n";
	}
    }    
    return $menulabel;   
}

1;

package libkadeploy2::grub;

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
	defaultlabel          => 0,
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

sub set_timeout($)
{
    my $self=shift;
    my $timeout=shift;
    $self->{timeout}=$timeout;
}


sub add($$$$$$$$$)
{
    my $self=shift;

    my $label=shift;
    my $kernel=shift;
    my $initrd=shift;
    my $module=shift;
    my $append=shift;

    my $networkroot=shift;
    my $disknumber=shift;
    my $partnumber=shift;
    my $slice=shift;

    my $grublabel=libkadeploy2::grub_label::new();
    my $ref_label_list=$self->{label_list};
    my %label_list=%$ref_label_list;


    $grublabel->set_label($label);
    $grublabel->set_kernel($kernel);
    $grublabel->set_initrd($initrd);
    $grublabel->set_module($module);
    $grublabel->set_append($append);
    if ($kernel eq "chainload") { $grublabel->set_chainload(); }
    
    if ($networkroot==1) { $grublabel->set_networkroot(); }
    $grublabel->set_disknumber($disknumber);
    $grublabel->set_partnumber($partnumber);
    $grublabel->set_slice($slice);
    
    $label_list{$label}=$grublabel;

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

    my $timeout=$self->{timeout};
    my $firstserialportspeed=$self->{firstserialportspeed};
    my $secondserialportspeed=$self->{secondserialportspeed};
    my $defaultlabel=$self->{defaultlabel};
    my $title="grub bootloader";
    my $key;
    my $labelentry;
    my $menu;

    my $defaultconf="
default 0
timeout $timeout
color cyan/blue white/blue
";

     foreach $key (keys %label_list)
     {
	 my $label=$label_list{$key};
	 my $str=$label->get();
	 $labelentry.=$str;
	 if ($label->{label} eq $defaultlabel)
	 {
	     $labelentry.="savedefault\n";
	 }
     }
    $menu.=$defaultconf.$labelentry."\nboot\n";

    return $menu;
}


package libkadeploy2::pxegrubtftp;

use strict;
use warnings;
use libkadeploy2::message;

#my $message=libkadeploy2::message::new();
my $conf=libkadeploy2::deployconf::new();
if (! $conf->loadcheck()) { exit 1; }
my $tftproot=$conf->get("tftp_repository");
my $first_serial_speed;
my $second_serial_speed;
if ($conf->is_conf("first_serial_speed"))  { $first_serial_speed=$conf->get("first_serial_speed"); } else { $first_serial_speed=9600; }
if ($conf->is_conf("second_serial_speed")) { $second_serial_speed=$conf->get("second_serial_speed"); } else { $second_serial_speed=9600; }
my $sudo_user=libkadeploy2::sudo::get_sudo_user();
if (! $sudo_user) { $sudo_user=libkadeploy2::sudo::get_user(); }


my $kadeploydir=$conf->get("kadeploy2_directory");
my $sourcegrubfloppy="$kadeploydir/lib/floppy/grub/grub.img";
my $grubfloppyname="grub.img";
my $grubfactory=$conf->getpath_cmd("factory_grub");

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
	pxe          => 0,
	pxefloppy    => 0,
	networkroot  => 0,
	diskroot     => 1,
    };
    bless $self;
    return $self;
}

sub set_nodelist($)      { my $self=shift; $self->{nodelist}=shift; }
sub set_kernel($)        { my $self=shift; $self->{kernel}=shift; }
sub set_initrd($)        { my $self=shift; $self->{initrd}=shift; }
sub set_module($)        { my $self=shift; $self->{module}=shift; }
sub set_kernelparams($)  { my $self=shift; $self->{kernelparams}=shift; }

sub set_disktype($)      { my $self=shift; $self->{disktype}=shift; }
sub set_disknumber($)    { my $self=shift; $self->{disknumber}=shift; }
sub set_partnumber($)    { my $self=shift; $self->{partnumber}=shift;  }
sub set_slice($)         { my $self=shift; $self->{slice}=shift; }

sub set_pxefloppy($)     { my $self=shift; $self->{pxefloppy}=1; $self->{pxe}=0; }
sub set_pxe($)           { my $self=shift; $self->{pxe}=1;       $self->{pxefloppy}=0;}

sub set_networkroot()    { my $self=shift; $self->{networkroot}=1; $self->{diskroot}=0; }
sub set_diskroot()       { my $self=shift; $self->{diskroot}=1;    $self->{networkroot}=0;  }


sub readgrubcfg()
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
	$message->message(-1,"show grub menu.lst for $node_name");
	open(MENULST,"$tftproot/$node_name/menu.lst") 
	    or die "can't open $tftproot/$node_name/menu.lst";
	while ($line=<MENULST>) { print $line; }
	close(MENULST);
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


sub writepxegrubcfg($)
{
    my $self=shift;
    my $nodelist=$self->{nodelist};
    my $node;
    my $ref_node_list;
    my @node_list;
    my $menulst;

    $self->generate_kernel_initrd_module_tftpnodes();

    $ref_node_list=$nodelist->get_nodes();
    @node_list=@$ref_node_list;

    foreach $node (@node_list)
    {
	my $node_name=$node->get_name();

	$self->{node_name}=$node_name;
	$menulst=$self->generate_grub_menu_linux();	
	$self->writepxegrub($node,$menulst);
    }
}

## return value : 1 if successful
sub generate_grub_menu_linux()
{
    my $self=shift;
    
    my $kernel       = $self->{kernel};
    my $initrd       = $self->{initrd};
    my $module       = $self->{module};
    my $kernelparams = $self->{kernelparams};

    my $networkroot  = $self->{networkroot};
    my $disktype     = $self->{disktype};
    my $disknumber   = $self->{disknumber};
    my $partnumber   = $self->{partnumber};
    my $slice        = $self->{slice};

    my $title;

    if ($self->{networkroot})
    {
	if ($self->{kerneltftp})    { $kernel=$self->{node_name}."/".$self->{kerneltftp}; }
	if ($self->{initrdtftp})    { $initrd=$self->{node_name}."/".$self->{initrdtftp}; }
	if ($self->{moduletftp})    { $module=$self->{node_name}."/".$self->{moduletftp}; }
    }

    $title="grub boot";
    if ($disktype)   { $title.=" interface=$disktype"; }
    if ($disknumber) { $title.=" disknum=$disknumber"; }
    if ($partnumber) { $title.=" partnum=$partnumber"; }
    if ($slice)      { $title.=" slice=$slice"; }

    my $menulst;

    ## "hard-coded" options
    my $default = 0;
    my $fallback = 1;    
    my $hexfdisktype;
    my $linuxdevice;
    my $linuxdisktype;
    my $linuxdisknumber;
    my $device;
    my $grub;

    if (! $networkroot) {if (! $disknumber) { $message->missing_cmdline(2,"disknumber or networkroot error"); exit 1; }     }


    $grub=libkadeploy2::grub::new();

    $grub->add($title,
	       $kernel,
	       $initrd,
	       $module,
	       $kernelparams,
	       $networkroot,
	       $disknumber,
	       $partnumber,
	       $slice
	       );

	       
    return $grub->get();
}


sub writepxegrubfloppy($)
{
    my $self=shift;
    my $menulst=shift;

    my $nodelist=$self->{nodelist};
    my $node;
    my $ref_node_list;
    my @node_list;
    my $dest;
    my $node_name;
    my $line;
    my $menudest;
    my $destfloppy;

    $ref_node_list=$nodelist->get_nodes();
    @node_list=@$ref_node_list;
    foreach $node (@node_list)
    {
	$node_name=$node->get_name();
	$destfloppy="$tftproot/$node_name/$grubfloppyname";
	$menudest="$tftproot/$node_name/menu.lst";

	$message->message(0,"tftp boot modified for $node_name");
	system("echo \"$menulst\" > $menudest");
	chmod(755,"$grubfactory");
	system("$grubfactory -s $sourcegrubfloppy -d $destfloppy -m $menudest");
    }
}

sub writepxegrub($$)
{
    my $self=shift;
    my $node=shift;
    my $menulst=shift;
    my $ref_node_list;
    my @node_list;
    my $dest;
    my $node_name;
    my $line;
    my $menudest;
    my $destmenulst;
    my $mac=$node->get_mac();
    my @maclist;
    my $macstr;
    @maclist=split(/:/,$mac);
    foreach $mac (@maclist)
    {
	$macstr.=$mac;
    }

    $destmenulst="menu.lst.01".uc($macstr);
    $node_name=$node->get_name();
    $menudest="$tftproot/$node_name/menu.lst";
    
    $message->message(0,"tftp boot modified for $node_name");
    system("echo \"$menulst\" > $menudest");
    system("echo \"$menulst\" > $tftproot/$destmenulst");
    system("echo \"\" > $tftproot/$node_name/WARNING-$destmenulst");
}





1;

###############################################################################
##  *** ConfLib: *** 
##
## Description: module de gestion du fichier de conf de DEPLOY
##
###############################################################################
package libkadeploy2::conflib;

use strict;
use warnings;
#require Exporter;

use libkadeploy2::message;
#our (@ISA,@EXPORT,@EXPORT_OK);
#@ISA = qw(Exporter);
#@EXPORT_OK = qw(init_conf get_conf is_conf dump_conf reset_conf);

## prototypes
sub new($$);  #(conffile,critic)
sub check_conf;
sub check_cmd;
sub check_cmd_exist;
sub check_db_access;
sub get($);
sub set($$);
sub is_set($);
sub dump_conf();
sub reset_conf();




my $message=libkadeploy2::message::new();



## regex pour une ligne valide du fichier de conf.
my $regex = qr{^\s*([^#=\s]+)\s*=\s*([^#]*)}; #

	    



sub new($$)
{
    my $conffile = shift; ## configuration  file
    my $critic = shift; 
    my $self;
    my %params = ();  ## parameters container
    my $refparams=\%params;
    $self = 
    {
	params => $refparams,
	loaded => 0,
	conffile => $conffile,
	critic  => $critic,
    };
    bless $self;
    return $self;
}



sub load()
{
    my $self=shift;
    my $conf;
    my %params;
    my $refparams;
    my $ok=1;


    $conf=$self->{conffile};

    #$message->loadingfile(0,$conf);
    open(CONF,$conf) or die "Can't open $conf";
    if (! $ok) { $message->erroropeningfile(2,$conf); exit 1; }

    foreach my $line (<CONF>)
    {
	if ($line =~ $regex) 
	{
	    my ($key,$val) = ($1,$2);
	    $val =~ s/\s*$//;
	    if(!exists($params{$key}))
	    {
                $params{$key}=$val;
            }
	    else
	    {
		$message->message(2,"variable $key is defined twice");
                $ok=0;
            }
	}
    }
    close(CONF);
    $refparams=\%params;
    $self->{params}=$refparams;
    $self->{loaded}=1;
    return $ok;
}



## check_conf
## checks the configuration file
## parameters : /
## return value : 1 if conf file actually loaded, else 0.



#######                   legende                    ########
#   nb  type de donnee                     - action a realisee
# -----------------------------------------------------------
#   1 = nombre ou options ou simple chaine - 1 pas de check
#   2 = /path/                             - 2 check "/" debut & "/" fin
#   3 = /path/cmd ou /path/archive.tgz     - 3 check "/" debut & ! "/" fin
#   4 = chemin/                            - 4 check ! "/" debut & "/" fin
#   5 = machinchose                        - 5 check ! "/" debut et fin
#   6 = /truc                              - 6 check "/" debut 
#   7 = yes                                - 7 check "yes" | "no"
##############################################################


sub check()
{
    my $self=shift;
    my $refcritic;
    my %already_defined = ();

    my %params;
    my $refparams;
    $refparams=$self->{params};
    %params=%$refparams;


    my $undefined = 0;
    my $missing = 0;
    my $criticref;
    my %critic;

    $criticref=$self->{critic};
    %critic=%$criticref;


    if ($self->{loaded}==0) 
    {
	$message->loadingfileyoumust(2);
	exit 1;
    }



    # checks if the critic variables are defined 
#    print STDERR "Checking variable definition...\n";
    foreach my $var (keys %critic)
    {	
	if(!exists($params{$var}))
	{
	    $message->message(2,"critic variable $var is missing");
	    $missing++;
	}
	else
	{# critic variable is defined

	    my $type = $critic{$var};
	    my $valid = 0;
	    if ($type == 2) { # check / debut & fin
		if (!($params{$var} =~ /^\/.*\/$/)){
		    $message->message(2,"$var variable should start and end with an / \n");
		    $missing++;
		}
	    }elsif($type == 3){ # check / debut & pas / fin
		if ((!($params{$var} =~ /^\/.*/)) || ($params{$var} =~ /.*\/$/)){
		    $message->message(2,"$var variable should start with an / and end without\n");
		    $missing++;
		}
	    }elsif($type == 4){ # check / fin & pas / debut
		if (($params{$var} =~ /^\/.*/) || (!($params{$var} =~ /.*\/$/))){
		    $message->message("$var variable should end with an / and start without\n");
		    $missing++;
		}
	    }elsif($type ==5){ # check pas de / ni debut ni fin
		if (($params{$var} =~ /^\/.*/) || ($params{$var} =~ /.*\/$/)){
		    $message->message(2,"$var variable should not start neither end with an / \n");
		    $missing++;
		}
	    }elsif($type == 6){ # check / debut & peu importe fin
		if (!($params{$var} =~ /^\/.*/)){
		    $message->message(2,"$var variable should start with an /\n");
		    $missing++;
		}
	    }elsif($type == 7){
		if (!(
		      ($params{$var} =~ /yes/) ||
		      ($params{$var} =~ /no/)
		      )
		    )
		{
		    $message->message(2,"$var should be yes or no\n");
		    $missing++;
		}		    	
	    }else{ # pas de check
		;
	    }
	}
    }

    if ($missing){
	$message->message(2,"$missing argument missing. please check your configuration file\n");
	return 0;
    }

    #checks if the values of the critic variables are correct (when possible) ?
    #print "Checking variables values...\n";
    return 1;
}







sub is_set($)
{
    my $self=shift;
    my $key = shift;
    my $ok=1;

    my %params;
    my $refparams;
    $refparams=$self->{params};
    %params=%$refparams;


    (defined $key) or $ok=0;
    if ($ok==0)
    { 	$message->message(2,"get expects a parameter !!! \n"); 	exit 1;     }

    if (!exists $params{$key})
    {
	$ok=0;
    }
    return $ok;
}


# recupere un parametre
sub get($) 
{
    my $self=shift;
    my $key = shift;
    my $ok=1;

    my %params;
    my $refparams;
    $refparams=$self->{params};
    %params=%$refparams;


    (defined $key && $key) or $ok=0;
    if ($ok==0)
    { 	$message->message(2,"get expects a parameter !!! \n"); 	exit 1;     }

    if (!exists $params{$key})
    {
	$message->message(1,"$key=.... doesn't exist in your configuration.");
    }

    return $params{$key};
}

sub set($$)
{
    my $self=shift;
    my $val = shift;
    my $key = shift;

    my %params;
    my $refparams;
    $refparams=$self->{params};
    %params=%$refparams;
    
    $params{$val}=$key;
    $refparams=\%params;
    $self->{params}=$refparams;
}

# debug: dump les parametres
sub print() 
{
    my $self=shift;

    my %params;
    my $refparams;
    $refparams=$self->{params};
    %params=%$refparams;

    print "Config_file = ".$self->{conffile}."\n";
    while (my ($key,$val) = each %params) 
    {
	print $key." = ".$val."\n";
    }
    return 1;
}

# reset the module state
sub reset() 
{
    my $self=shift;
    my %params;
    my $refparams;
    %params = ();
    $refparams=\%params;
    $self->{params}=$refparams;
    return 1;
}

1;

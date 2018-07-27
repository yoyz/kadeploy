###############################################################################
##  *** ConfLib: *** 
##
## Description: module de gestion du fichier de conf de DEPLOY
##
## Une ligne du fichier de conf est de la forme:
##  > truc = 45 machin chose bidule 23 # un commentaire
##
## Vous pouvez commencer des lignes de commentaires par "#", elles seront
## ignorees de meme d'ailleurs que toutes les lignes non conformes a
## l'expression reguliere definissant une ligne valide...:)
##
## Apres initialisation du modules a l'aide de la fonction check_conf(),
## la recuperation d'un parametre se fait avec la fonction get_conf("truc").
## La fonction is_conf quant à elle permet de savoir si un parametre est defini.
##
## - Exemple d'utilisation:
##  > use ConfLib qw(init_conf get_conf is_conf);
##  > init_conf();
##  > print "toto = ".get_conf("toto")."\n" if is_conf("toto");
##
###############################################################################
package libkadeploy2::conflib;

use strict;
use warnings;
use libkadeploy2::debug;
use libkadeploy2::confroot;

require Exporter;



## prototypes
sub check_conf;
sub check_cmd;
sub check_nodes_conf;
sub check_cmd_exist;
sub set_conf;
sub get_conf;
sub is_conf;
sub dump_conf;

## regex pour une ligne valide du fichier de conf.
my $regex = qr{^\s*([^#=\s]+)\s*=\s*([^#]*)};

#------------------------------------
# Default pathnames for config files
#------------------------------------
my $kadeploy_config_dir;
my $default_clusterconf;
my $default_deployconf;
my $default_deploycmdconf;
# reserved name for default configuration files
my $default_clustername = "default"; 


sub new
{
  my ($class) = @_;
  my $self = {};
  
  $kadeploy_config_dir = libkadeploy2::confroot::get_conf_rootdir();
  libkadeploy2::confroot::info();
  $default_clusterconf = $kadeploy_config_dir."/"."deploy_cluster.conf";
  $default_deployconf = $kadeploy_config_dir."/"."deploy.conf";
  $default_deploycmdconf = $kadeploy_config_dir."/"."deploy_cmd.conf";
  
  $self->{clusterconf} = $default_clusterconf;
  $self->{deployconf} = $default_deployconf;
  $self->{deploycmdconf} = $default_deploycmdconf;
  $self->{checked_conf} = 0; # initialy unread
  $self->{checked_cmd} = 0; # initialy unread
  $self->{cluster} =();
  $self->{params} = ();
  $self->{commands} = ();
  bless ($self, $class);
  return $self;
}


## usefull to generate bootfiles
sub get_clustername {
  my $self = shift;
  my $result = "default";

  if ($self->{deployconf} eq $default_deployconf) {
    # no default value to avoid bugs
    return "";
  }
  if ($self->{deployconf} =~ /^$kadeploy_config_dir\/deploy-(.*).conf$/) {
    $result = $1;
  }
  return $result;
}

# usefull to manage commands without nodes file
sub set_clustername {
    my $self = shift;
    my $clustername = shift;
    # configuration files must be re-read 
    $self->{checked_conf} = 0;
    $self->{checked_cmd} = 0;
    if (($clustername eq "") || ($clustername eq $default_clustername)) { # use default configuration file
	    $self->{deployconf} = $default_deployconf;
            $self->{deploycmdconf} = $default_deploycmdconf;
	    return 1;
    }
    $self->{deployconf} = $kadeploy_config_dir."/"."deploy-".$clustername.".conf";
    $self->{deploycmdconf} = $kadeploy_config_dir."/"."deploy_cmd-".$clustername.".conf";
    return 1;
}


## check_conf
## checks the configuration file
## parameters : /
## return value : 1 if conf file actually loaded, else 0.
sub check_conf {
    my $config = shift;

    if ($config->{checked_conf} == 1) {
        return 1;
    }

    my $deployconf = $config->{deployconf};
	
    if ($deployconf eq "") {
	print "ERROR: kadeploy configuration file not defined\n";
	return 0;
    }

    my %critic = (
		  #######                   legende                    ########
                  #   nb  type de data                   - action realisee
		  # -----------------------------------------------------------
                  #   1 = nombre ou options ou simple chaine - 1 pas de check
                  #   2 = /path/                             - 2 check / debut & / fin
		  #   3 = /path/cmd ou /path/archive.tgz     - 3 check / debut & pas / fin
		  #   4                                      - 4 check pas / debut mais / fin
		  #   5                                      - 5 check pas de / ni debut ni fin
		  #   6                                      - 6 check / debut & peu importe fin
		  #"remote_sentinelle_rsh" => 3,
		  #"remote_sentinelle_rsh_default_args" => 1,
		  #"remote_mcat" => 3,
		  # ce ne sont pas des variables critiques
		  #"use_internal_parallel_command" => 7,
		  #"do_fdisk_on_deploy" => 7,
		  
		  "kadeploy2_directory" => 6,
		  "first_check_timeout" => 1,
		  "last_check_timeout" => 1,
		  "enable_nmap" => 1,
		  "nmap_cmd" => 3,

		  "deploy_rcmd" => 1,
		  "prod_rcmd" => 1,

		  "deploy_db_host" => 1,
		  "deploy_db_name" => 1,
		  "deploy_db_login" => 1,
		  "deploy_db_psswd" => 1,

		  "pre_install_archive" => 3,
		  "pre_install_script" => 5,
		  "post_install_script" => 5,
		  "tftp_repository" => 2,
		  "pxe_rep" => 4,
		  "tftp_relative_path" => 5,
	          "use_kexec_by_default" => 1,
		  #############################
		  );

    my %already_defined = ();

    my $twice = 0;
    my $missing = 0;

    if(!(-e $deployconf)){
	print "ERROR : variable configuration file: " . $deployconf . " does not exist\n";
	return 0;
    }

    #libkadeploy2::debug::debugl(3, "Checking variable definition...\n");

    open(DEPLOYCONF,$deployconf) or die "Can't open $deployconf, maybe you are not allowed to open this file\n";

    foreach my $line (<DEPLOYCONF>){
	if ($line =~ $regex) {
	    my ($key,$val) = ($1,$2);
	    $val =~ s/\s*$//;
	    if(!exists($already_defined{$key})){
		$already_defined{$key} = $val;
                $config->{params}{$key} = $val;
            }else{
		libkadeploy2::debug::debugl(0, "ERROR : variable $key is defined twice in configuration file:" . $deployconf . "\n");
                $twice = 1;
            }
	}
    }
    close(DEPLOYCONF);

    # checks if the critic variables are defined 
    foreach my $var (keys %critic){
	if(!exists($config->{params}{$var})){
	    libkadeploy2::debug::debugl(0, "ERROR : critic variable $var is missing\n");
	    $missing = 1;
	}else{# critic variable is defined

	    my $type = $critic{$var};
	    my $valid = 0;
	    if ($type == 2) { # check / debut & fin
		if (!($config->{params}{$var} =~ /^\/.*\/$/)){
		    libkadeploy2::debug::debugl(0, "ERROR : $var variable should start and end with an / \n");
		    $missing = 1;
		}
	    }elsif($type == 3){ # check / debut & pas / fin
		if ((!($config->{params}{$var} =~ /^\/.*/)) || ($config->{params}{$var} =~ /.*\/$/)){
		    libkadeploy2::debug::debugl(0, "ERROR : $var variable should start with an / and end without\n");
		    $missing = 1;
		}
	    }elsif($type == 4){ # check / fin & pas / debut
		if (($config->{params}{$var} =~ /^\/.*/) || (!($config->{params}{$var} =~ /.*\/$/))){
		    libkadeploy2::debug::debugl(0, "ERROR : $var variable should end with an / and start without\n");
		    $missing = 1;
		}
	    }elsif($type ==5){ # check pas de / ni debut ni fin
		if (($config->{params}{$var} =~ /^\/.*/) || ($config->{params}{$var} =~ /.*\/$/)){
		    libkadeploy2::debug::debugl(0, "ERROR : $var variable should not start neither end with an / \n");
		    $missing = 1;
		}
	    }elsif($type == 6){ # check / debut & peu importe fin
		if (!($config->{params}{$var} =~ /^\/.*/)){
		    libkadeploy2::debug::debugl(0, "ERROR : $var variable should start with an /\n");
		    $missing = 1;
		}
	    }elsif($type == 7){
		if (!(
		      ($config->{params}{$var} =~ /yes/) ||
		      ($config->{params}{$var} =~ /no/)
		      )
		    )
		{
		    libkadeploy2::debug::debugl(0, "ERROR :$var should be yes or no\n");
		    $missing = 1;
		}		    	
	    }else{ # pas de check
		;
	    }
	}
    }

    if ($twice || $missing){
	libkadeploy2::debug::debugl(0, "ERROR : please check your configuration file\n");
	return 0;
    }
    $config->{checked_conf} = 1;

    return 1;
}

##
#  check_clusterconf
#  checks the cluster configuration file
#  parameters : /
#  return value: 1 or 
##
sub check_clusterconf {
    my $config = shift;
    if(!(-e $config->{clusterconf})){
        return 1;
    }
    if(!(-r $config->{clusterconf})){
        print STDERR "ERROR : cluster configuration file cannot be read\n";
        exit 1;
    }

    libkadeploy2::debug::debugl(3, "Checking clusters definitions...\n");

    open(CLUSTERCONF, $config->{clusterconf});

    foreach my $line (<CLUSTERCONF>){
        chomp($line);
        # checks if the line exists
        if($line){
            # checks if it is a commentary
            if($line !~ /^\s*#.*/){
               # parses line info
               if ($line =~ /^\s*([^\s]+)\s+([^\s]+)\s*$/) {
                       $config->{cluster}{$1} = $2;
               }
           }
        }
    }
    close(CLUSTERCONF);
    
    return 1;
}




## check_cmd
## checks the command configuration file
## parameters : /
## return value : hash of hash as follow hostname => cmd_type => cmd 
sub check_cmd {
    my $config = shift;
    if ($config->{checked_cmd} == 1) {
	return %{$config->{commands}};
    }

    if(!(-e $config->{deploycmdconf})){
	print STDERR "ERROR : command configuration file does not exist\n";
	exit 1;
    }
    if(!(-r $config->{deploycmdconf})){
        print STDERR "ERROR : command configuration file cannot be read\n";
        exit 1;
    }

    libkadeploy2::debug::debugl(3, "Checking command definition...\n");
    
    open(DEPLOYCMD, $config->{deploycmdconf});
    
    foreach my $line (<DEPLOYCMD>){
	chomp($line);
	# checks if the line exists
	if($line){
	    # checks if it is a commentary
	    if($line !~ /^\s*#.*/){
	       # parses line infoi
	       if ($line =~ /^\s*([^\s]+)\s+([^\s]+)\s+(.*)$/) {
		       $config->{commands}{$1}{$2} = $3;
	       }
	   }
	}
    }
    close(DEPLOYCMD);
    $config->{checked_cmd} = 1;
    
    return %{$config->{commands}};
}


sub check_nodes_conf {
    my $config = shift;
    my $nodes_list_ref = shift;
    my @nodes_list = @{$nodes_list_ref};
    my $main_cluster = "";

    $config->check_clusterconf();

    my $loop_cluster; 
    # retrieve main configuration file name
    foreach my $node (@nodes_list) {
        if (!exists($config->{cluster}{$node})) {
                $loop_cluster = $default_clustername;
        } else {
                $loop_cluster = $config->{cluster}{$node};
        }
	if (($main_cluster ne "") && ($loop_cluster ne $main_cluster )) {
                print "ERROR: all the node are not from the same cluster, please check again the specified nodes\n";
                return 0;
        }
        $main_cluster = $loop_cluster;
    }

    $config->set_clustername($main_cluster);

    return 1;
}


## check_cmd_exist
## checks if the command configuration file exists
## parameters : /
## return value : 1 if conf file actually loaded, else 0.
sub check_cmd_exist {
    my $config = shift;
    
    if (!-r $config->{deploycmdconf} ) {
	print "ERROR : command configuration file does not exist\n";
	exit 0;
    }
    
    return 1;
}


# set a parameter to currently loaded configuration
# to overwrite a defaut value, or add a new one
sub set_conf {
  my $config = shift;
  my $key = shift;
  my $value = shift;
  (defined $key) or print "WARNING : set_conf expects a parameter \n";
   $config->{params}{$key} = $value;
   return 1;
}


# recupere un parametre
sub get_conf {
  my $config = shift;
  my $key = shift;
  (defined $key) or print "WARNING : get_conf expects a parameter \n";
  return $config->{params}{$key};
}


# teste si un parametre est defini
sub is_conf {
  my $config = shift;
  my $key = shift;
  (defined $key) or print "WARNING : is_conf expects a parameter\n";
  return exists $config->{params}{$key};
}


# debug: dump les parametres
sub dump_conf {
  my $config = shift;
  print "Config file is: ".$config->{deployconf}."\n";
  while (my ($key,$val) = each %{$config->{params}}) {
    print " ".$key." = ".$val."\n";
  }
  return 1;
}


return 1;

package libkadeploy2::confroot;

use libkadeploy2::debug;
use Env qw($KADEPLOY_CONFIG_DIR);
use strict;
use warnings;

my $default_config_dir="/etc/kadeploy";
my $kadeploy_config_dir="";
my $kaenv="KADEPLOY_CONFIG_DIR";

sub get_conf_rootdir()
{
  if (!$ENV{$kaenv} eq "") {
    $kadeploy_config_dir = $ENV{$kaenv};
  }
  elsif ($kadeploy_config_dir eq "") {
    $kadeploy_config_dir = $default_config_dir;
  }
  return $kadeploy_config_dir;
}

sub set_conf_rootdir($)
{
  my $rootdir = shift;

  $ENV{$kaenv} = $rootdir;
  $kadeploy_config_dir = $rootdir;
}

sub info()
{
  libkadeploy2::debug::debugl(3, "[I] Configuration used : ".$kadeploy_config_dir."\n");
}

1;



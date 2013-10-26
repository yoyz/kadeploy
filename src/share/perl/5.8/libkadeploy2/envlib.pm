###############################################################################
##  *** EnvLib: from ***
##
## - Description:
##   Home brewed module managing environment file for Kadeploy
##
## - Usage: init_conf(<filename>);
##   Read the first file matching <filename> in
##   . current directory
##
## - Environment file format:
## A line of the configuration file looks like that:
## > truc = 45 machin chose bidule 23 # any comment
## "truc" is a configuration entry being assigned "45 machin chose bidule 23"
## Anything placed after a dash (#) is ignored i
## (for instance lines begining with a dash are comment lines then ignored)
## Any line not matching the regexp defined below are also ignored
##
## Module must be initialized using init_env(<filename>), then
## any entry is retrieved using get_env(<entry>).
## is_env(<entry>) may be used to check if any entry actually exists.
##
## - Example:
##  > use EnvLib qw(init_env get_env is_env);
##  > init_env("debian.dsc");
##  > print "toto = ".get_env("toto")."\n" if if_env("toto");
##
###############################################################################
package libkadeploy2::envlib;

use strict;
use warnings;
require Exporter;
our (@ISA,@EXPORT,@EXPORT_OK);
@ISA = qw(Exporter);
@EXPORT_OK = qw(init_env get_env is_env dump_env reset_env);

## the environment file.
my $file = undef;
## parameters container...
my %params;
## environment file regexp (one line).
my $regex = qr{^\s*([^#=\s]+)\s*=\s*([^#]*)};

## Initialization of the environment
# param: environment file pathname
# Result: 0 if env was already loaded
#         1 if env was actually loaded
#         2 if env was not found
sub init_env ($){
  # If file already loaded, exit immediately
  (defined $file) and return 0;
  $file = shift;
  (defined $file) or return 2;
  unless ( -r $file ) {
      warn "Enviguration file not found.";
      $file = undef;
      return 2;
  }
  open ENV, $file or die "Open environment description file";
  %params = ();
  foreach my $line (<ENV>) {
      if ($line =~ $regex) {
          my ($key,$val) = ($1,$2);
        $val =~ s/\s*$//;
        $params{$key}=$val;
        }
  }
  close ENV;
  return 1;
}

## retrieve a parameter
sub get_env ( $ ) {
    my $key = shift;
    (defined $key) or die "missing a key!";
    return $params{$key};
}

## check if a parameter is defined
sub is_env ( $ ) {
    my $key = shift;
    (defined $key) or die "missing a key!";
    return exists $params{$key};
}

## debug: dump parameters
sub dump_env () {
    print "Environment file is: ".$file."\n";
    while (my ($key,$val) = each %params) {
        print " ".$key." = ".$val."\n";
    }
    return 1;
}

## reset the module state
sub reset_env () {
    $file = undef;
    %params = ();
    return 1;
}

return 1;

package libkadeploy2::cache;

# use strict;
# use warnings;

use Cwd;
use File::Copy;
use File::Path;
use File::chdir;
use libkadeploy2::pathlib;
use libkadeploy2::debug;

## ================
## Global variables
## ================
## Tftp chroot
my $_tftpdirectory;
## Directory path of Kadeploy environment files cache
my $_cachedirectory;
my $_subcachedir = "__sub";
## days count after which files are removed from cache
my $_expirydelay    = 30;
## Array of files in cache
my @_filesincache   = ();


## =========
## Functions
## =========

## Returns true if cache is empty
sub empty_cache()
{
   if ( ! @_filesincache ) { return 1; }
   else { return 0; }
}

## Returns the directory path used for cached files
sub get_cache_directory()
{
    return $_cachedirectory;      
}

## Returns cache directory path relative to n subdirectories from tftpdirectory
sub get_cache_directory_tftprelative($)
{
    my $nsubdirs = shift;
    
    my $relativepath = $_cachedirectory;
    $relativepath =~ s:^$_tftpdirectory/::;
    
    for (my $a = 1; $a <= $nsubdirs; $a++)
    {
	$relativepath = "../" . $relativepath;
    }
    return $relativepath;
}

## Initialize the cache : get TFTP root path + check cache directory
sub init_cache($)
{
    $_tftpdirectory = shift;
    ## Strip tailing /
    $_tftpdirectory =~ s/\/$//;
    $_cachedirectory = $_tftpdirectory . "/" . "cache";
    
    if ( ! libkadeploy2::cache::test_cache_directory() ) { return 0; }
    return 1;
}

## Test if cache directory exists 
## and create it if needed
sub test_cache_directory()
{
    if ( ! -e $_cachedirectory ) 
    { 
        if ( mkdir $_cachedirectory, 0755 ) { return 1; }
        else {
	  libkadeploy2::debug::debugl(3, "$0: mkdir failed on $_cachedirectory\n");
	  return 0;
	}
    }
    elsif ( ! -r $_cachedirectory || ! -w $_cachedirectory || ! -x $_cachedirectory ) 
    {
	@failed = grep !(chmod 0755, $_), $_cachedirectory;
	if ( @failed )
	{
	    libkadeploy2::debug::debugl(3, "$0 : chmod failed on $_cachedirectory\n");
	    exit 0;
	}
	else { return 1; }
    }
    else { return 1; }
}

## Read cache directory and returns files list
sub read_files_in_cache()
{
    # print "cache::read_files_in_cache() \n";
    my $succes = opendir CACHEHANDLE, $_cachedirectory;
    if ( ! $succes )
    {
	libkadeploy2::debug::debugl(3, "$0 : opendir failed on $_cachedirectory\n");
	exit 0;
    }
    
    @_filesincache = grep !/^\.\.?$/, readdir CACHEHANDLE;
    closedir CACHEHANDLE;
    return 1;
}

## Search a file in cache
sub already_in_cache($)
{
    if ( empty_cache() ) { return 0; }
    
    my $searchedfile = shift;
    # print "cache::already_in_cache : _filesincache = @_filesincache\n";
    
    if ( grep /$searchedfile/, "@_filesincache" ) { return 1; }
    else { return 0; }
}

sub check_files($)
{
    my $f = shift;
    my @arr_files = @{$f};
   
    my $count=@arr_files;
    my @res;
    my $a=0;
    while ($a < $count) {
	if ( libkadeploy2::pathlib::is_valid($arr_files[$a]) && (defined($arr_files[$a])) ) {
	    push(@res, $arr_files[$a]);
	}
	$a++;
    }
    return (@res);
}

## Put files in cache if they're not already in
sub put_in_cache_from_archive($$$$)
{
    my $ref_files = shift;
    my $archive   = shift;
    my $strip     = shift;
    my $env_id    = shift;
    my @files     = @{$ref_files};
    my $cachemodified = 0;
    my $agearchive    = 0;
    my $agecachefile  = 0;
    my $original_file;
    $strip=0;

    $_subcachedir = $_subcachedir.".".$env_id;
    
    if ( empty_cache() ) { read_files_in_cache(); }
    
    ## Clean cache from oldest files
    libkadeploy2::cache::clean_cache();
    
    ## Checks whether some filenames are fake (space/empty strings and so on)
    @files = libkadeploy2::cache::check_files(\@files);
    
    # To prevent bug with directory in 711 : error cannot fetch initial working directory
    local $old_cwd = cwd();
    chdir $_cachedirectory;
    
    ## Add eventually new files with caution
    ## If files are links => follow them 
    foreach my $archivefile ( @files )
    {
	# print "current archivefile = ".$archivefile."\n";
	$cachefile = libkadeploy2::pathlib::strip_leading_dirs($archivefile);
	$cachefileid = $cachefile.".".$env_id;
	$original_file = $cachefile;
	$archiveprefix = libkadeploy2::pathlib::get_leading_dirs($archivefile);
	$agearchive = ( -M $archive );
	$agecachefile = ( -C $_cachedirectory."/".$cachefileid );
        # print "Archive : ".$archive." (age =  ".$agearchive." )\n";
	# print "cache file : ".$_cachedirectory."/".$cachefile." (age = ".$agecachefile." )\n";
	if ( ( $agearchive < $agecachefile ) || ( ! already_in_cache($cachefileid) ) )
	{
	    if (! -d $_cachedirectory."/".$_subcachedir) {
		mkdir $_cachedirectory."/".$_subcachedir, 0755;
	    }
	    # print "cache::put_in_cache_from_archive :  adding " . $archivefile . "\n";
	    my $still_a_link = 1;
	    while ($still_a_link) 
	    {
		my $prev_archivefile = $archivefile;
		# print "===> tar -C ".$_cachedirectory." --strip ".$strip." -xvzf ".$archive." ".$archivefile."\n";
		libkadeploy2::debug::system_wrapper("tar -C $_cachedirectory/$_subcachedir --strip $strip -xvzf $archive $archivefile 2>&1 >/dev/null");
		# print "??? we are doing readlink of ".$archivefile."\n";
		$file = readlink $_cachedirectory."/".$_subcachedir."/".$archivefile;
		# print "??? readlink result = ".$file."\n";
		if ($file) { 
		  $still_a_link = 1;
		  my $firstchar = $file;
		  $firstchar =~ s/^(.{1}).*$/$1/;
		    if ($firstchar eq "/") { 
		    # dereferenced link is an absolute path
		    # print "### ABSOLUTE link\n";
		    $archivefile = libkadeploy2::pathlib::strip_leading_slash($file);
		  } elsif ($firstchar eq ".") {
		    # dereferenced link is a relative link
		    # print "### RELATIVE link\n";
		    $archivefile = libkadeploy2::pathlib::strip_dotdot($file);
		  } else {
		    # dereferenced link is a direct filename
		    # print "### DIRECT link\n";
		    # print "archiveprefix = ".$archiveprefix."\n";
		    if ($archiveprefix =~ m/^$/) {
			$archivefile = $file;
		    } else {
			$archivefile = $archiveprefix."/".$file;
		    }
		  }
		  # remove currently extracted file in cache because it's a link
		  $rootdir = libkadeploy2::pathlib::get_subdir_root($prev_archivefile);
		  rmtree($_cachedirectory."/".$_subcachedir."/".$rootdir, 0, 1);  
		} else {
		  # current $archivefile is a true file
		  $still_a_link = 0;
		}
	    }
	    copy($_cachedirectory."/".$_subcachedir."/".$archivefile, $_cachedirectory."/".$original_file.".".$env_id);
	    $rootdir = libkadeploy2::pathlib::get_subdir_root($archivefile);
	    rmtree($_cachedirectory."/".$_subcachedir."/".$rootdir, 0, 1);
	    $cachemodified = 1;
	}
	if (-d $_cachedirectory."/".$_subcachedir) {
	    rmtree($_cachedirectory."/".$_subcachedir, 0, 1);
        }
    }
    
    ## If cache modified, reload it
    if ( $cachemodified ) 
    { 
	## print "cache::put_in_cache_from_archive : reload cache\n";
	read_files_in_cache();
	$cachemodified = 0;
    }
    chdir $old_cwd;    
    return 1;
}

## Remove oldest files from cache
sub clean_cache()
{
    my $cachemodified = 0;
    
    foreach my $currentfile ( @_filesincache )
    {
	my $f = $_cachedirectory . "/" . $currentfile;
	my $ageoffile = ( -A $f );
	# print "cache::clean_cache() : currentfile = " . $currentfile . " -A = " . $ageoffile . "\n";	
	if ( $ageoffile > $_expirydelay )
	{
	    libkadeploy2::debug::system_wrapper("rm -f $_cachedirectory/$currentfile");
	    $cachemodified = 1;
	}
    }
    
    if ( $cachemodified ) 
    { 
	read_files_in_cache();
	$cachemodified = 0;
    }
    
    return 1;
}

## Remove all files from cache
sub purge_cache()
{
    libkadeploy2::debug::system_wrapper("rm -rf $_cachedirectory/*");
    read_files_in_cache();

    return 1;
}

1;

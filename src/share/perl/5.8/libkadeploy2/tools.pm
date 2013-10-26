package libkadeploy2::tools;

use libkadeploy2::deploy_iolib;



sub returnvalidhostsfile()
{
    my $db=libkadeploy2::deploy_iolib::new();
    $db->connect();
    my $refnodehash;
    my %nodehash;
    my $key;
    my $strret;
    $refnodehash=$db->get_node();
    %nodehash=%$refnodehash;
    $strret="127.0.0.1 localhost\n";
    foreach $key (keys(%nodehash))
    {
	$strret.="$nodehash{$key} $key\n";
    }
    $db->disconnect();
    return $strret;
}


sub translate_to_megabyte($)
{ 
    my $size=shift;
    my $Msize=0;

    if ($size =~ /\d+/) { $Msize=$size; }
    if ($size =~ /b$/i)  { $size =~ s/b//i; $Msize=$size/1000/1000;  }
    if ($size =~ /k$/i)  { $size =~ s/k//i; $Msize =$size/1000;  }
    if ($size =~ /m$/i)  { $size =~ s/m//i; $Msize =$size;  }
    if ($size =~ /g$/i)  { $size =~ s/t//i; $Msize =$size*1000;  }
    if ($size =~ /t$/i)  { $size =~ s/t//i; $Msize =$size*1000*1000;  }

    if ($bytesize) { $self->{size}=$bytesize; }
    return $Msize;
}


1;

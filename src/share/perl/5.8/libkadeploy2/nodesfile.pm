package libkadeploy2::nodesfile;


sub addnodetodb($)
{
    my $file = shift;
    my $ok=0;
    open(DESC,$file);    
    my $db = libkadeploy2::deploy_iolib::new();
    $db->connect();
    foreach my $line (<DESC>)
    {
	# checks if it is a commentary
	chomp($line);
	if($line)
	{
	    #check line 
	    #node1 11:22:33:44:55:66 192.168.0.1
	    if($line =~ /^([a-z0-9\-\.]+)[\t\s]+(..:..:..:..:..:..)[\t\s]+([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)[\t\s]*$/)
	       {
		   # nodes description
		   my ($name,$ether,$ip)=($1,$2,$3);
		   my @info = ($name,$ether,$ip);
		   my $node_id = $db->add_node(\@info);
		   push(@host_id_list, $node_id);
		   print "Registring $name\n";
		   $ok=1;
	       }	       
	}	    
    }   

    close(DESC);
    $db->disconnect();    
   if ($ok)
    {
	print "Nodes Registration completed.\n";    
    }
    else
    {
	print "Nodes Registration failed.\n";    
    }
    return $ok;
}

sub loadnodesfile($)
{
    my $file = shift;
    my $ok=0;
    open(DESC,$file);    
    foreach my $line (<DESC>)
    {
	# checks if it is a commentary
	chomp($line);
	if($line)
	{
	    #check line 
	    #node1 11:22:33:44:55:66 192.168.0.1
	    if($line =~ /^([a-z0-9\-\.]+)[\t\s]+(..:..:..:..:..:..)[\t\s]+([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)[\t\s]*$/)
	       {
		   # nodes description
		   my ($name,$ether,$ip)=($1,$2,$3);
		   my @info = ($name,$ether,$ip);
		   push(@host_id_list, $node_id);
		   $ok=1;
	       }	       
	}	    
    }   
    close(DESC);
   if ($ok)
    {
	print "Nodes loaded.\n";    
    }
    else
    {
	print "Nodes load failed.\n";    
    }
    return $ok;
}


1;

# This is the iolib, which manages the layer between the modules and the
# database. This is the only base-dependent layer.
# When adding a new function, we recommend to :
# - give the name of the function
# - start with a short description of the function
# - list the parameters it expects
# - list the return values
# - list the side effects

package libkadeploy2::deploy_iolib;

use DBI;
#use libkadeploy2::conflib;
use libkadeploy2::deployconf;
use Time::Local;
use warnings;
use strict;

##############
# PROTOTYPES #
##############

sub new();                          #create object 

# database connectors #
sub connect();                      #connect to db
sub disconnect();                   #disconnect from db

#BEGIN NEW API###############################################################################
sub node_name_exist($);             #(name)
sub node_name_to_id($);             #(name) fqdn or not
sub node_name_to_ip($);             #(name) fqdn or not

sub node_id_to_name($);             #(nodeid)
sub node_id_to_ip($);               #(nodeid)
sub node_id_to_mac($);              #(nodeid)

sub node_ip_to_name($);             #(ip)

sub nodename_disknumber_to_diskid($$); #(nodename,disknumber)

sub add_node($);                    #(hostname)
sub del_node($);                    #(hostname)

sub add_disk($);                    #(\(disknumber,interface,size,nodeid))
sub del_disk_from_id($);                   #(diskid)

sub add_partition($); #(\(pnumber,size,parttype,disk_id))

sub get_diskid_from_nodeid_disknumber($$); #(nodeid,disknumber)
sub get_diskinfo_from_diskid($);           #(diskid)
sub get_partitioninfo_from_partitionid($); #(partitionid)

sub diskidpartnumber_to_partitionid($$);   #(diskid,partnumber) => partitionid
sub del_partition_from_diskid($);          #(diskid)

sub list_node($);
sub get_node_nameip();                     #

sub part_id_to_nb($);                      #(partid)
sub part_id_to_size($);

sub add_rights_user_nodename_rights($$$);  #(username,nodename,rights)
sub del_rights_user_nodename_rights($$$);  #(username,nodename,rights)
sub check_rights($$$);
sub get_rights();

sub add_env($$$);
sub del_env($$$);

sub get_environments();                             #() get all environemnts
sub get_environment_descriptionfile($$);

sub update_nodestate($$$);
sub get_nodestate($$);
#sub get_diskid_from_nodeid($);            #(dbh,nodename)

#END NEW API#####################################

# deployment action tools #
sub prepare_deployment($);
sub run_deployment($$);
sub end_deployment($$);
sub cancel_deployment($$);

# deployment partition selection tools #
sub get_partition_status($$@);
sub get_deploy_id($$$$);
sub search_deployed_env($$$);
sub autochoose_partition($%);

# database accessors #
#sub env_name_ver_to_id($$$);
#sub env_name_to_last_ver_id($$);
#sub env_name_to_versions($$);

sub env_name_user_to_last_ver_id($$$);

sub env_id_to_name($$);
sub env_id_to_size($$);
sub env_id_to_version($$);
sub env_id_to_kernel($$);
sub env_id_to_filebase($$);
sub env_id_to_filesite($$);
sub env_id_to_filesystem($$);

sub env_undefined_to_id($);



sub disk_id_to_dev($$);
#sub disk_dev_to_id($$$);

#sub part_nb_to_id($$$);









sub deploy_id_to_env_info($$);
sub deploy_id_to_node_info($$);

# kanode tools #



sub add_deploy($$$$);








sub add_environment($$$$$$$$$$$$$$$$);


sub list_partition_from_nodename($$);     #(dbh,nodename)

# deployment tools #
sub report_state($$$$$);
sub is_node_free($$$);
sub add_node_to_deployment($$$$$$);
sub set_deployment_features($$$$$$);

# print and debug

sub debug_print($$);

# deployment time
sub set_time($$);
sub get_time($$);

# other tools #
sub correct_db_consistence($);
sub correct_deployment_consistence($$);
sub erase_partition($%);

#####################
# END OF PROTOTYPES #
#####################
my $message=libkadeploy2::message::new();
my $conf=libkadeploy2::deployconf::new();
if (! $conf->loadcheck()) { exit 1; }


sub new()
{


    my $host = $conf->get("deploy_db_host");
    my $name = $conf->get("deploy_db_name");
    my $user = $conf->get("deploy_db_login");
    my $pwd  = $conf->get("deploy_db_psswd");

    my $self=
    {
	"deploy_db_host"  =>  $host,
	"deploy_db_name"  =>  $name,
	"deploy_db_login" =>  $user,
	"deploy_db_psswd" =>  $pwd,
	"dbh"             =>  0,
    };
    bless $self;
    return $self;
}

###########################
### database connectors ###

# connect
# connects to database and returns the base identifier
# parameters : /
# return value : base
sub connect() 
{
    my $self=shift;

    my $status = 1;
    
    my $host = $self->{deploy_db_host};
    my $name = $self->{deploy_db_name};
    my $user = $self->{deploy_db_login};
    my $pwd  = $self->{deploy_db_psswd};

    my $dbh = DBI->connect("DBI:mysql:database=$name;host=$host",$user,$pwd,{'PrintError'=>0,'InactiveDestroy'=>1}) or $status = 0;
    
    if($status == 0)
    {
	print "ERROR : connection to database $name failed\n";
	print "ERROR : please check your configuration file\n";
    }
    else
    {
	$self->{dbh}=$dbh;
    }
    return $status;
}

# disconnect
# disconnect from database
# parameters : base
# return value : /
sub disconnect() 
{
    my $self = shift;
    my $dbh = $self->{dbh};
    my $ok=0;
    # Disconnect from the database.
    if ($dbh->disconnect())
    {
	$ok=1;
    }
    else
    {
	$ok=0;
    }
    return $ok;
}

## check_db_access
## tries to connect to databases 
## parameters : /
## return value : 1 if ok
sub check_db_access()
{
    my $self = shift;
    $message->checkingdb();

    if ($self->connect())
    {
	$self->disconnect();
    }
    return 1;
}



### database connectors end ###
###############################


# node_name_to_id
# gets the id of the node
# parameters : name (FQDN or simple name)
# return value : nodeid or 0 if it dose not exist in the database
sub node_name_to_id($)
{
    my $self = shift;
    my $name = shift;

    my $dbh=$self->{dbh};

    my $sth;
    my $ref;
    my $nbresult=0;
    my $id=0;


    $sth = $dbh->prepare("
SELECT node.id 
FROM 
node 
WHERE 
node.name = \"$name\"
"); 
    $sth->execute(); 
    while ($ref = $sth->fetchrow_hashref())
    {
	$id = $ref->{'id'};
	$nbresult++;
    }
    $sth->finish();

    if ($nbresult!=1)    
    {
	$nbresult=0;
	$sth = $dbh->prepare("
SELECT node.id 
FROM 
node 
WHERE 
node.name like \"$name.%\"
"); 
	$sth->execute(); 
	while ($ref = $sth->fetchrow_hashref())
	{
	    $id = $ref->{'id'};
	    $nbresult++;
	}
	$sth->finish();
    }
    if($nbresult!=1)
    {
	return 0;
    }    
    return $id;
}

# node_name_to_id
# gets the id of the node
# parameters : name (FQDN or simple name)
# return value : nodeid or 0 if it dose not exist in the database
sub node_name_to_ip($)
{
    my $self = shift;
    my $name = shift;

    my $dbh=$self->{dbh};

    my $sth;
    my $ref;
    my $nbresult=0;
    my $ip;

    if ($name=~/\./)
    {
	$sth = $dbh->prepare("
SELECT node.ipaddr
FROM 
node 
WHERE 
node.name = \"$name\"
"); 
    }
    else #find the fqdn name
    {
	$sth = $dbh->prepare("
SELECT node.ipaddr
FROM 
node 
WHERE 
node.name like \"$name%\"
"); 
    }
    $sth->execute(); 
    while ($ref = $sth->fetchrow_hashref())
    {
	$ip = $ref->{'ipaddr'};
	$nbresult++;
    }
    $sth->finish();

    if(!$ip || $nbresult!=1)
    {
	return 0;
    }
    return $ip;
}


# node_ip_to_name
# gets the name of the node whose ip address is given in parameter
# parameters : ip
# return value : name or 0 if it does not exist in the database
sub node_ip_to_name($)
{
    my $self=shift;
    my $ip = shift;
    
    my $dbh = $self->{dbh};

    my $sth = $dbh->prepare("
SELECT node.name 
FROM 
node 
WHERE 
node.ipaddr = \"$ip\"
"); 
    $sth->execute(); 
    my $ref = $sth->fetchrow_hashref(); 
    my $name = $ref->{'name'}; 
    $sth->finish();

    if(!$name){
	return 0;
    }
    return $name;
}




# node_id_to_name
# gets the name of the node
# parameters : id
# return value : node name or 0 if it dose not exist in the database
sub node_id_to_name($)
{
    my $self=shift;
    my $id = shift;

    my $dbh = $self->{dbh};

    my $sth = $dbh->prepare("
SELECT node.name 
FROM 
node 
WHERE node.id = $id
"); 
    $sth->execute(); 
    my $ref = $sth->fetchrow_hashref(); 
    my $name = $ref->{'name'}; 
    $sth->finish();

    if(!$name){
	return 0;
    }
    return $name;
}


# node_id_to_ip
# gets the ip of the node
# parameters : id
# return value : ip or 0 if it dose not exist in the database
sub node_id_to_ip($)
{
    my $self=shift;
    my $id = shift;

    my $dbh = $self->{dbh};

    my $sth = $dbh->prepare("
SELECT node.ipaddr
FROM 
node 
WHERE node.id = $id
"); 
    $sth->execute(); 
    my $ref = $sth->fetchrow_hashref(); 
    my $ip = $ref->{'ipaddr'}; 
    $sth->finish();

    if(!$ip){
	return 0;
    }
    return $ip;
}

# node_id_to_mac
# gets the mac of the node
# parameters : id
# return value : mac or 0 if it dose not exist in the database
sub node_id_to_mac($)
{
    my $self=shift;
    my $id = shift;

    my $dbh = $self->{dbh};

    my $sth = $dbh->prepare("
SELECT node.macaddr
FROM 
node 
WHERE node.id = $id
"); 
    $sth->execute(); 
    my $ref = $sth->fetchrow_hashref(); 
    my $mac = $ref->{'macaddr'}; 
    $sth->finish();

    if(!$mac){
	return 0;
    }
    return $mac;
}



sub add_env($$$)
{
    my $self=shift;
    my $name=shift;
    my $user=shift;
    my $descriptionfile=shift;
    my $dbh = $self->{dbh};
    my $sth;
    my $row;
    my $id;
    my $ok=0;
    my $sqldel="DELETE FROM environment 
WHERE
environment.name = \"$name\" AND
environment.user = \"$user\"
";
    my $sqltest="
SELECT environment.id
FROM environment
WHERE 
environment.name = \"$name\" AND
environment.user = \"$user\"
";
    my $sqlput="
INSERT INTO environment 
(name,user,descriptionfile) 
VALUES 
(\"$name\",\"$user\",\"$descriptionfile\")";
    $sth = $dbh->prepare($sqltest);
    $sth->execute();
    $row =$sth->fetchrow_hashref();
    $id=$row->{id};
    if ($id)
    {
       $sth = $dbh->prepare($sqldel);
       $sth->execute();
       $sth = $dbh->prepare($sqlput);
       $sth->execute();
       $ok=1;
    }
    else
    {
       $sth = $dbh->prepare($sqlput);
       if ($sth->execute()) { $ok=1; }
    }
    return $ok;
}

sub del_env($$$)
{
    my $self=shift;
    my $name=shift;
    my $user=shift;
    my $descriptionfile=shift;
    my $dbh = $self->{dbh};
    my $sth;
    my $row;
    my $id;
    my $ok=0;
    my $sqltest="
SELECT environment.id
FROM environment
WHERE 
environment.name = \"$name\" AND
environment.user = \"$user\" AND
environment.descriptionfile=\"$descriptionfile\"
";
    my $sqlput="
DELETE FROM environment 
WHERE
environment.name = \"$name\" AND
environment.user = \"$user\" AND
environment.descriptionfile=\"$descriptionfile\"
";
    $sth = $dbh->prepare($sqltest);
    $sth->execute();
    $row =$sth->fetchrow_hashref();
    $id=$row->{id};
    if (! $id)
    {
	$ok=1;
    }
    else
    {
       $sth = $dbh->prepare($sqlput);
       if ($sth->execute()) { $ok=1; }
    }
    return $ok;
}


sub get_environments()
{
    my $self=shift;

    my $dbh=$self->{dbh};
    my $sth;
    my $ref_array_env;
    my @array_env;
    my $user;
    my $envname;
    my $descriptionfile;
    my $h;
    my $ok=0;
    my $rights;
    my $sqlquery="
SELECT *
FROM 
environment
";
    $sth = $dbh->prepare($sqlquery);
    $sth->execute();
    while ($h=$sth->fetchrow_hashref())
    {
	$envname=$h->{'name'};
	$user=$h->{'user'};
	$descriptionfile=$h->{'descriptionfile'};
	my @line=($envname,$user,$descriptionfile);
	
	@array_env=(@array_env,\@line);
	$ok=1;
    }
    $ref_array_env=\@array_env;
    if (! $ok) { $ref_array_env=0; }
    return $ref_array_env;
}


sub get_environment_descriptionfile($$)
{
    my $self=shift;

    my $name=shift;
    my $user=shift;

    my $dbh=$self->{dbh};
    my $sth;
    my $ref_array_env;
    my @array_env;
    my $envname;
    my $descriptionfile;
    my $h;
    my $ok=0;
    my $rights;
    my $id=0;
    my $sqltest="
SELECT *
FROM 
environment
WHERE
environment.name = \"$name\" AND
environment.user = \"$user\"
";

    my $sqlquery = "
SELECT environment.descriptionfile
FROM
environment
WHERE
environment.name = \"$name\" AND
environment.user = \"$user\"
";
    $sth = $dbh->prepare($sqltest);
    $sth->execute();
    $h=$sth->fetchrow_hashref();
    $id=$h->{id};
    if ($id)
    {
	$sth=$dbh->prepare($sqlquery);
	$sth->execute();
	$h=$sth->fetchrow_hashref();
	$descriptionfile=$h->{descriptionfile};
    }
    if ($descriptionfile)
    {
	return $descriptionfile;
    }
    else
    {
	return 0;
    }
}




sub update_nodestate($$$)
{
    my $self=shift;

    my $nodename=shift;
    my $service=shift;
    my $state=shift;

    my $nodeid;
    my $dbh = $self->{dbh};
    my $sth;
    my $row;
    my $id;
    my $ok=0;
    
    $nodeid=$self->node_name_to_id($nodename);
    if (! $nodeid) { exit 255; }

    my $sqltest="
SELECT nodestate.nodeid
FROM nodestate,node
WHERE 
node.name=\"$nodename\" AND
node.id=nodestate.nodeid AND
nodestate.service=\"$service\"
";
    my $sqlput="
INSERT INTO nodestate
(nodeid,service,state) 
VALUES 
(\"$nodeid\",\"$service\",\"$state\")";

    my $sqlupdate="
update nodestate
set state=\"$state\"
where
nodeid=\"$nodeid\" AND
service=\"$service\"
    ";
    $sth = $dbh->prepare($sqltest);
    $sth->execute();
    $row =$sth->fetchrow_hashref();
    $id=$row->{nodeid};
    if ($id)
    {
       $sth = $dbh->prepare($sqlupdate);
       $sth->execute();
       $ok=1;
    }
    else
    {
       $sth = $dbh->prepare($sqlput);
       if ($sth->execute()) { $ok=1; }
    }
    return $ok;
}

sub get_nodestate($$)
{
    my $self=shift;

    my $nodename=shift;
    my $service=shift;

    my $nodeid;
    my $dbh = $self->{dbh};
    my $sth;
    my $row;
    my $id;
    my $ret;
    my $ok=0;
    
    $nodeid=$self->node_name_to_id($nodename);
    if (! $nodeid) { exit 255; }

    my $sqltest="
SELECT nodestate.nodeid,nodestate.state
FROM nodestate,node
WHERE 
node.name=\"$nodename\" AND
node.id=nodestate.nodeid AND
nodestate.service=\"$service\"
";
    $sth = $dbh->prepare($sqltest);
    $sth->execute();
    $row =$sth->fetchrow_hashref();
    $id=$row->{nodeid};
    if ($id)
    {
	$ret=$row->{state};
    }
    else
    {
	$ret="UNKNOW";
    }
    return $ret;
}


######################################
### kaaddnode/kadelnode tools ###

# add_node
# registers a new node into the database
# parameters : node_description=(name, macaddr, ipaddr)
# return value : nodeid
sub add_node($)
{
    my $self=shift;
    my $ref_node = shift;

    my $dbh = $self->{dbh};
    my $node_id;
    my $sth;
    
    # TODO : faire des vérifications !
    
    # debug print
    # print "VALUES = $$ref_node[0] ; $$ref_node[1] ; $$ref_node[2]\n";
    
    # checks if node already exists
    $sth = $dbh->prepare("SELECT node.id FROM node WHERE node.name = \"$$ref_node[0]\"");
    $sth->execute();
    $node_id = $sth->fetchrow_hashref(); 
    $node_id = $node_id->{'id'}; 
    $sth->finish();
    
    if(!$node_id){
	# enregistrer le nouveau noeud
	$sth = $dbh->do("INSERT node (name, macaddr, ipaddr)
                         VALUES (\"$$ref_node[0]\",\"$$ref_node[1]\",\"$$ref_node[2]\")");
	
	$sth = $dbh->prepare("SELECT node.id FROM node WHERE node.name = \"$$ref_node[0]\"");
	$sth->execute();
	$node_id = $sth->fetchrow_hashref(); 
	$node_id = $node_id->{'id'}; 
	$sth->finish();

    }
    return $node_id;    
}


# del_node
# delete a node from the database
# parameters : node
# return value : 
sub del_node($)
{
    my $self= shift;
    my $hostname = shift;

    my $dbh = $self->{dbh};

    my $sth;
    
    $sth = $dbh->prepare("SELECT node.id FROM node WHERE node.name = \"$hostname\"");
    $sth->execute();
    my $node_id = $sth->fetchrow_hashref(); 
    $node_id = $node_id->{'id'}; 
    $sth->finish();
    
    if(!$node_id){
	print "WARNING : node $hostname to delete is not registered\n";
    }else{
	$sth = $dbh->do("DELETE FROM deployed WHERE deployed.nodeid = $node_id");
	$sth = $dbh->do("DELETE FROM node WHERE node.id = $node_id");
    }
}

### kaaddnode/kadelnode operations end ###
##########################################












# clean_previous_deployments
# remove the previously crashed deployments according to a timeout in the deploy.conf file
# by default, bigger than 2 * first_check_timeout + 2 * last_check_timeout
# since deployment time should be less than last_check_timeout
sub clean_previous_deployments ($) {
    my $dbh = shift;
    my $deployment_validity_timeout = libkadeploy2::conflib::get_conf("deployment_validity_timeout");
    if ((!$deployment_validity_timeout) || ($deployment_validity_timeout < 400)) {
    	# set default value
    	$deployment_validity_timeout = 1000;
    }
print "invalidating deployments older than $deployment_validity_timeout\n";

    my $rows_affected = $dbh->do("UPDATE deployment
                                  SET deployment.state = 'error', deployment.enddate=deployment.startdate
                                  WHERE (deployment.state!='terminated' and deployment.state!='error') and DATE_SUB(now(),INTERVAL $deployment_validity_timeout SECOND) > deployment.startdate;");
    if($rows_affected == 0){ return 1; }

     print "Warning $rows_affected deployment have been corrected automatically\n";
     return 0;
}


# prepare_deployment
# checks if there is already a waiting deployment
# if not, creates a new one (waiting,startdate,enddate)
# parameters : base
# return value : 
#  - deployment id if the new deployment has been successfully created
#  -      0        if not i.e. if there is already a waiting deployment
sub prepare_deployment($){
    my $dbh = shift;
    my $i = 0;
    my $nb=1;
    my $maxretry=50;
    my $sth;
    # invalidate previously problematic deployments
    clean_previous_deployments ($dbh);
    
    while ($i<$maxretry &&
	   $nb==1
	   )
    {
	$dbh->do("LOCK TABLES deployment WRITE");
	
	$sth = $dbh->prepare("SELECT IFNULL(COUNT(deployment.id),0) as id
                             FROM deployment
                             WHERE deployment.state = 'waiting'");
	$sth->execute();
	$nb = $sth->fetchrow_hashref(); $nb = $nb->{'id'};
	$sth->finish();
	if ($nb==1)
	{
	    $i++;
	    print "retry $i/$maxretry : Waiting... Another deployment is running ; retry in $i s\n";
	    $dbh->do("UNLOCK TABLES");
	    sleep($i);
	}
    }

    # $nb should be 0 or 1
    if($nb == 0)
    {

	# create new deployment, set state to waiting and start_date to current mysql server date
	$sth = $dbh->do("INSERT deployment (state, startdate, enddate)
                         VALUES ('waiting', NOW(), NOW())");

	$sth = $dbh->prepare("SELECT deployment.id FROM deployment WHERE deployment.state = 'waiting'");
	$sth->execute();
	my $deploy_id = $sth->fetchrow_hashref();
	$deploy_id = $deploy_id->{'id'};
	$sth->finish();
	
	$dbh->do("UNLOCK TABLES");
	return $deploy_id;
    }
    elsif($nb == 1)
    {
	print "ERROR : another deployment is already waiting ; please retry later\n";
	$dbh->do("UNLOCK TABLES");
	return 0;
    }
    else
    {
	print "ERROR : unexpected number of waiting deployment \"$nb\"\n";
	return 0;
    }
}

# run_deployment
# sets running deployment state
# prerequisite : begin_deployment
# parameters : base, deploy_id
# return value : 1 if successful, 0 if failed
sub run_deployment($$){
    my $dbh = shift;
    my $deploy_id = shift;

    # set current state to deploying
    my $rows_affected = $dbh->do("UPDATE deployment
                                  SET deployment.state = 'running'
                                  WHERE deployment.state = 'waiting'");
    if($rows_affected == 1){
	return 1;
    }else{
	print "unexpected number of waiting deployment\n";
	return 0;
    }
}

# end_deployment
# sets end deployment state i.e.
# - end state in deployment table
# - end state in depoyed table
# prerequisite : begin_deployment call
# parameters : base, deploy_id
# return value : 1 if all nodes are deployed, else 0
sub end_deployment($$){
    my $dbh = shift;
    my $deploy_id = shift;
    my $failure = 0;
    my @node = ();
    my $result = 1;

    $dbh->do("UPDATE deployed SET deployed.state = 'deployed'
              WHERE deployed.deployid = $deploy_id
              AND deployed.state = 'deploying'");

    my $sth = $dbh->prepare("SELECT count(deployed.nodeid) AS nb FROM deployed
                             WHERE deployed.deployid = $deploy_id
                             AND deployed.state <> 'deployed'");
    $sth->execute();
    my $undeployed = $sth->fetchrow_hashref();
    $undeployed = $undeployed->{'nb'};
    $sth->finish();

    if($undeployed){
	print "The deployment failed on some (maybe not all) nodes\n";
	$result = 0;
    }
    # deployment is terminated
    $sth = $dbh->do("UPDATE deployment
                     SET deployment.state = 'terminated', deployment.enddate = NOW()
                     WHERE deployment.id = $deploy_id");

    return $result;
}

# cancel_deployment
# sets error state in deployed and deployment tables
# prerequisite : prepare_deployment call
# parameters : base, deploy_id
# return value : /
sub cancel_deployment($$){
    my $dbh = shift;
    my $deploy_id = shift;

    # set deployed state to error
    my $sth = $dbh->do("UPDATE deployed 
                        SET deployed.state = 'error' 
                        WHERE deployed.deployid = $deploy_id");

     libkadeploy2::deploy_iolib::end_deployment($dbh,$deploy_id);
}

############################################
### deployment partition selection tools ###

# get_partition_status
# gets the number and content of partitions on the specified node 
# whose size is higher than the one given in parameter
# parameters : base, minimal size, array of ip addresses
# return value : ip address, disk id, partition id, environment id
#                in a hash of arrays as decribed below :
#                %res = (
#                     ip_addr1 => ( 
#                                   [disk id, part id, env id],
#                                   [disk id, part id, env id],
#                                   [disk id, part id, env id]
#                                 );
#                     ip_addr2 => ( 
#                                   [disk id, part id, env id],
#                                   [disk id, part id, env id],
#                                   [disk id, part id, env id]
#                                 );
#                       ...
#                       );
sub get_partition_status($$@) {
    my $dbh = shift;
    my $size = shift;
    my @ip_addr = @_;
    
    my %res;
    my @res;

    foreach my $ip_addr (@ip_addr){
	my $sth = $dbh->prepare("SELECT deployed.diskid, deployed.partid, deployed.envid
	    		         FROM deployed, node, partition
	    		         WHERE node.ipaddr = \"$ip_addr\"
                                 AND partition.size >= $size
                                 AND node.id = deployed.nodeid
                                 AND partition.id = deployed.partid");
	$sth->execute();
	@res = ();
	
	while (my $ref = $sth->fetchrow_hashref()) {
	    push(@res, [$ref->{diskid}, $ref->{partid}, $ref->{envid}]);
	}
	$sth->finish();

	# warning
	if (!@res) {print "WARNING : $ip_addr has no suitable partition for requested size\n"}

	$res{$ip_addr} = [@res];
    }
    
    return %res;
}

# get_deploy_id
# returns the deploy_id for the specified partition if in an appropriate state
# parameters : base, node name, device, partition
# return value : deploy_id if state = 'deployed' else 0
#sub get_deploy_id($$$$)
#{
#    my $dbh  = shift;
#    my $node = shift;
#    my $dev  = shift;
#    my $part = shift;
#    my $max_id;
#    my $state;
#
#    my $nodeid = node_name_to_id($dbh,$node);
#    my $diskid = disk_dev_to_id($dbh,$dev);
#    my $partid = part_nb_to_id($dbh,$part,$nodeid);
#
#    # recuperation du deployid max
#    my $sth = $dbh->prepare("SELECT MAX(deployed.deployid) as maxid
#                             FROM deployed
#                             WHERE deployed.nodeid = \"$nodeid\" 
#                             AND deployed.diskid = \"$diskid\"
#                             AND deployed.partid = \"$partid\"");
#
#    $sth->execute();
#    my $ref = $sth->fetchrow_hashref();
#    $max_id = $ref->{'maxid'};
#    $sth->finish();
#
#    # recuperation de l etat associe
#    $sth = $dbh->prepare("SELECT deployed.state
#                             FROM deployed
#                             WHERE deployed.nodeid = \"$nodeid\" 
#                             AND deployed.diskid = \"$diskid\"
#                             AND deployed.partid = \"$partid\"
#                             AND deployed.deployid = \"$max_id\"");
#    $sth->execute();
#    $ref = $sth->fetchrow_hashref();
#    $state = ($ref->{'state'});
#    $sth->finish();

    # debug print
    # print "NODEID = $nodeid ; DISKID = $diskid ; PARTID = $partid ; MAX = $max_id ; STATE = $state\n";

#    if($state eq "deployed"){
#	return $max_id;
#    }else{
#	print "ERROR: last deployment on $node $dev$part failed\n";
#	return 0;
#    }
#}

# search_deployed_env
# looks for partitions with a given deployed environment on the given node
# parameters : base, environment name, node name
# return value : partition and matching environment version (if any)
#                in an array as described below :
#                @res = ([disk_id1, part_id1, env_version],
#                        [disk_id2, part_id2, env_version],
#                        ...)
sub search_deployed_env($$$){
    my $dbh = shift;
    my $env_name = shift;
    my $node_name = shift;
    my @max_ids=();
    my @res=();

    # debug print
    # print "ENV = $env_name ; NODE = $node_name\n";
    
    # recuperation du deployid max
    my $sth = $dbh->prepare("SELECT MAX(deployed.deployid) as maxid
                             FROM node, deployed
                             WHERE deployed.nodeid = node.id
                             AND node.name = \"$node_name\"
                             GROUP BY deployed.partid");
    $sth->execute();
    while (my $ref = $sth->fetchrow_hashref()) {
	push(@max_ids,$ref->{'maxid'});
    }
    $sth->finish();

    foreach my $max_id (@max_ids){
	$sth = $dbh->prepare("SELECT deployed.diskid, deployed.partid, environment.version
                             FROM node, deployed, environment
                             WHERE deployed.nodeid = node.id
                             AND deployed.state = 'deployed'
                             AND deployed.envid = environment.id
                             AND environment.name = \"$env_name\" 
                             AND node.name = \"$node_name\"
                             AND deployed.deployid = \"$max_id\"");
	$sth->execute();
	
	while (my $ref = $sth->fetchrow_hashref()) {
	    my @deployed = ($ref->{'diskid'},$ref->{'partid'},$ref->{'version'});
	    push(@res,[@deployed]);
	}
	
    }
    if(!scalar(@res)){
	print "WARNING : node $node_name has no partition with environment $env_name deployed on\n";
    }
    
    $sth->finish();

    return @res;
}

# autochoose_partition
# automatically chooses the first free partition on each node
# prerequisite : get_partition_status
# parameters : ip address, disk, partition, environment
#              in a hash of arrays as described below :
#              %param = (
#                     ip_addr1 => ( 
#                                   [disk id, part id, env id],
#                                   [disk id, part id, env id],
#                                              ...
#                                 );
#                     ip_addr2 => ( 
#                                   [disk id, part id, env id],
#                                   [disk id, part id, env id],
#                                              ...
#                                 );
#                       ...
#                       );
# return value : ip address, disk, partition
#                in a hash of arrays as described below :
#                %res = (
#                     ip_addr1 => ("disk id, part id");
#                     ip_addr2 => ("disk id, part id");
#                       ...
#                       );
sub autochoose_partition($%){
    my $dbh = shift;
    my %ip_addr = @_;
    my @candidate = ();
    my %res;

    # gets empty environment id
    my $sth = $dbh->prepare("SELECT environment.id FROM environment WHERE environment.name = 'empty'"); 
    $sth->execute();
    my $ref = $sth->fetchrow_hashref();
    my $empty_env_id = $ref->{'id'};
    $sth->finish();

    for my $ip_addr (keys %ip_addr){
	my $i =0; 
	my $bsup = $#{$ip_addr{$ip_addr}};
	my $found = 0;
	while ($i <= $bsup && !$found){
	    if ($ip_addr{$ip_addr}[$i][2] == $empty_env_id){
		pop(@{$ip_addr{$ip_addr}[$i]});
		$res{$ip_addr} = $ip_addr{$ip_addr}[$i];
		$found = 1;
	    }
	    $i++;
	}
	if (!$found){
	    print "WARNING : no free partition found on node \"$ip_addr\"\n";
	}
    }
    return %res;
}

### deployment partition selection tools end ###
################################################



sub env_name_user_to_last_ver_id($$$)
{
    my $dbh = shift;
    my $name = shift;
    my $user = shift;
    my $sth = $dbh->prepare("
SELECT MAX(environment.version) as max_version
FROM environment 
WHERE environment.name = \"$name\"
AND   environment.user = \"$user\"
");
    $sth->execute();
    my $version = $sth->fetchrow_hashref();
    $version = $version->{'max_version'};
    $sth->finish();

    if(!$version){
	print "WARNING : there is no environment named $name with user $user\n";
	return 0;
    }else{
	my $sth = $dbh->prepare("
SELECT environment.id
FROM environment 
WHERE environment.name = \"$name\" 
AND environment.version = \"$version\"
AND environment.user = \"$user\"
");
	$sth->execute();
	my $id = $sth->fetchrow_hashref();
	$id = $id->{'id'};
	$sth->finish();
	return $id;
    }

}


# env_undefined_to_id
# gets the id of the special 'undefined' environment
# parameters : base
# return value : undefined environment id
sub env_undefined_to_id($){
    my $dbh = shift;
    my $name = shift;

    my $sth = $dbh->prepare("SELECT environment.id
                             FROM environment 
                             WHERE environment.name = 'undefined'");
    $sth->execute();
    my $id = $sth->fetchrow_hashref();
    $id = $id->{'id'};
    $sth->finish();

    if(!$id){
	print "ERROR : there is no undefined environment\n";
	print "ERROR : this shouldn't happen\n";
	return 0;
    }else{
	return $id;
    }
}


# env_id_to_name
# gets the name matching the id environment
# parameters : base, environment id
# return value : environment name
sub env_id_to_name($$){
    my $dbh = shift;
    my $id = shift;



    my $sth = $dbh->prepare("SELECT environment.name
                             FROM environment 
                             WHERE environment.id = \"$id\"");
    $sth->execute();
    my $ref = $sth->fetchrow_hashref();
    my $name = $ref->{'name'};
    $sth->finish();
    
    if (!$name){
	print "WARNING : there is no environment of id $id\n";
	return 0;
    }

    return $name;
}

# env_id_to_size
# gets the size matching the id environment
# parameters : base, environment id
# return value : environment size
sub env_id_to_size($$){
    my $dbh = shift;
    my $id = shift;

    my $sth = $dbh->prepare("SELECT environment.size
                             FROM environment 
                             WHERE environment.id = \"$id\"");
    $sth->execute();
    my $ref = $sth->fetchrow_hashref();
    my $size = $ref->{'size'};
    $sth->finish();
    
    if (!$sth){
	print "WARNING : there is no environment of id $id\n";
	return 0;
    }

    return $size;
}


# env_id_to_version
# gets the version matching the id environment
# parameters : base, environment id
# return value : environment version
sub env_id_to_version($$){
    my $dbh = shift;
    my $id = shift;

    my $sth = $dbh->prepare("SELECT environment.version FROM environment WHERE environment.id=\"$id\"");

    $sth->execute();
    my $ref = $sth->fetchrow_hashref();
    my $version = $ref->{'version'};
    $sth->finish();
    
    if (!$sth){
	print "WARNING : there is no environment of id $id\n";
	return 0;
    }

    return $version;
}


# env_id_to_kernel
# gets the kernel path matching the id environment
# parameters : base, environment id
# return value : kernel path
sub env_id_to_kernel($$){
    my $dbh = shift;
    my $id = shift;

    my $sth = $dbh->prepare("SELECT environment.kernelpath FROM environment WHERE environment.id=\"$id\"");

    $sth->execute();
    my $ref = $sth->fetchrow_hashref();
    my $kernelpath = $ref->{'kernelpath'};
    $sth->finish();
    
    if (!$sth){
	print "WARNING : there is no environment of id $id\n";
	return 0;
    }
    return $kernelpath;
}


# env_id_to_filesite
# gets the postinstall matching the id environment
# parameters : base, environment id
# return value : filesite
sub env_id_to_filesite($$){
    my $dbh = shift;
    my $id = shift;

    my $sth = $dbh->prepare("SELECT environment.filesite FROM environment WHERE environment.id=\"$id\"");

    $sth->execute();
    my $ref = $sth->fetchrow_hashref();
    my $filesite = $ref->{'filesite'};
    $sth->finish();
    
    if (!$sth){
	print "WARNING : there is no environment of id $id\n";
	return 0;
    }
    return $filesite;
}

# env_id_to_filebase
# gets the filebase matching the id environment
# parameters : base, environment id
# return value : filebase
sub env_id_to_filebase($$){
    my $dbh = shift;
    my $id = shift;

    my $sth = $dbh->prepare("SELECT environment.filebase FROM environment WHERE environment.id=\"$id\"");

    $sth->execute();
    my $ref = $sth->fetchrow_hashref();
    my $filebase = $ref->{'filebase'};
    $sth->finish();
    
    if (!$sth){
	print "WARNING : there is no environment of id $id\n";
	return 0;
    }
    return $filebase;
}



# env_id_to_filesystem
# gets the filesystem matching the id environment
# parameters : base, environment id
# return value : filesystem
sub env_id_to_filesystem($$){
    my $dbh = shift;
    my $id = shift;

    my $sth = $dbh->prepare("SELECT environment.filesystem FROM environment WHERE environment.id=\"$id\"");

    $sth->execute();
    my $ref = $sth->fetchrow_hashref();
    my $filesystem = $ref->{'filesystem'};
    $sth->finish();
    
    if (!$sth){
	print "WARNING : there is no environment of id $id\n";
	return 0;
    }
    return $filesystem;
}



# env_name_to_filesystem
# gets the filesystem  for last ver of given env
# parameters : base, environment name
# return value : file system
sub env_name_to_filesystem($$){
    my $dbh = shift;
    my $name = shift;

    my $sth = $dbh->prepare("SELECT MAX(environment.version) as max_version
                             FROM environment 
                             WHERE environment.name = \"$name\"");
    $sth->execute();
    my $version = $sth->fetchrow_hashref();
    $version = $version->{'max_version'};
    $sth->finish();

    if(!$version){
	print "WARNING : there is no environment named $name\n";
	return 0;
    }else{
	my $sth = $dbh->prepare("SELECT environment.filesystem
                                FROM environment
                                WHERE environment.name = \"$name\" 
                                AND environment.version = \"$version\"");
	$sth->execute();
	my $kernel = $sth->fetchrow_hashref();
	$kernel = $kernel->{'filesystem'};
	$sth->finish();
	return $kernel;
    }
}

# env_name_to_kernel
# gets the environment kernel path for last ver of given env
# parameters : base, environment name
# return value : kernel path
sub env_name_to_kernel($$){
    my $dbh = shift;
    my $name = shift;

    my $sth = $dbh->prepare("SELECT MAX(environment.version) as max_version
                             FROM environment 
                             WHERE environment.name = \"$name\"");
    $sth->execute();
    my $version = $sth->fetchrow_hashref();
    $version = $version->{'max_version'};
    $sth->finish();

    if(!$version){
	print "WARNING : there is no environment named $name\n";
	return 0;
    }else{
	my $sth = $dbh->prepare("SELECT environment.kernelpath
                                FROM environment
                                WHERE environment.name = \"$name\" 
                                AND environment.version = \"$version\"");
	$sth->execute();
	my $kernel = $sth->fetchrow_hashref();
	$kernel = $kernel->{'kernelpath'};
	$sth->finish();
	return $kernel;
    }
}

# env_name_to_filebase
# gets the filebase path for last ver of given env
# parameters : base, environment name
# return value : filebase path
sub env_name_to_filebase($$){
    my $dbh = shift;
    my $name = shift;

    my $sth = $dbh->prepare("SELECT MAX(environment.version) as max_version
                             FROM environment 
                             WHERE environment.name = \"$name\"");
    $sth->execute();
    my $version = $sth->fetchrow_hashref();
    $version = $version->{'max_version'};
    $sth->finish();

    if(!$version){
	print "WARNING : there is no environment named $name\n";
	return 0;
    }else{
	my $sth = $dbh->prepare("SELECT environment.filebase
                                 FROM environment
                                 WHERE environment.name = \"$name\" 
                                 AND environment.version = \"$version\"");
	$sth->execute();
	my $filebase = $sth->fetchrow_hashref();
	$filebase = $filebase->{'filebase'};
	$sth->finish();
	return $filebase;
    }
}

# env_name_to_size
# gets the size of the last ver of given env
# parameters : base, environment name
# return value : size
sub env_name_to_size($$){
    my $dbh = shift;
    my $name = shift;

    my $sth = $dbh->prepare("SELECT MAX(environment.version) as max_version
                             FROM environment 
                             WHERE environment.name = \"$name\"");
    $sth->execute();
    my $version = $sth->fetchrow_hashref();
    $version = $version->{'max_version'};
    $sth->finish();

    if(!$version){
	print "WARNING : there is no environment named $name\n";
	return 0;
    }else{
	my $sth = $dbh->prepare("SELECT environment.size
                                 FROM environment
                                 WHERE environment.name = \"$name\" 
                                 AND environment.version = \"$version\"");
	$sth->execute();
	my $size = $sth->fetchrow_hashref();
	$size = $size->{'size'};
	$sth->finish();
	return $size;
    }
}

# env_name_to_filesite
# gets the filesite path for last ver of given env
# parameters : base, environment name
# return value : filesite path
sub env_name_to_filesite($$){
    my $dbh = shift;
    my $name = shift;

    my $sth = $dbh->prepare("SELECT MAX(environment.version) as max_version
                             FROM environment 
                             WHERE environment.name = \"$name\"");
    $sth->execute();
    my $version = $sth->fetchrow_hashref();
    $version = $version->{'max_version'};
    $sth->finish();

    if(!$version){
	print "WARNING : there is no environment named $name\n";
	return 0;
    }else{
	my $stg = $dbh->prepare("SELECT environment.filesite
                                 FROM environment
                                 WHERE environment.name = \"$name\" 
                                 AND environment.version = \"$version\"");
	$stg->execute();
	my $filesite = $stg->fetchrow_hashref();
	$filesite = $filesite->{'filesite'};
	$stg->finish();
	return $filesite;
    }
}
# env_name_to_optsupport
# gets the deployment method support option for last ver of given env
# 0 supports no optimisation method (default)
# 1 supports optimisation methods
# parameters : base, environment name
# return value : deployment method
sub env_name_to_optsupport($$){
    my $dbh = shift;
    my $name = shift;

    my $sth = $dbh->prepare("SELECT MAX(environment.version) as max_version
                             FROM environment 
                             WHERE environment.name = \"$name\"");
    $sth->execute();
    my $version = $sth->fetchrow_hashref();
    $version = $version->{'max_version'};
    $sth->finish();
    if(!$version){
         print "WARNING : there is no environment named $name\n";
         return 0;
     }else{
        my $stg = $dbh->prepare("SELECT environment.optsupport
                                 FROM environment
                                 WHERE environment.name = \"$name\" 
                                 AND environment.version = \"$version\"");
        $stg->execute();
        my $optsupport = $stg->fetchrow_hashref();
        $optsupport = $optsupport->{'optsupport'};
        $stg->finish();
        return $optsupport;
     }
}
	

# disk_dev_to_id
# gets the id of the device dev
# parameters : base, device
# return value : disk id
sub disk_dev_to_id($$){
    my $dbh = shift;
    my $dev = shift;

    my $sth = $dbh->prepare("SELECT disk.id
                             FROM disk
                             WHERE disk.device = \"$dev\"");
    $sth->execute();
    my $ref = $sth->fetchrow_hashref();
    my $id = $ref->{'id'};
    $sth->finish();
    
    if (!$id){
	print "WARNING : there is no device $dev\n";
	return 0;
    }

    return $id;
}

# disk_id_to_dev
# gets the device matching the id
# parameters : base, disk id
# return value : device
#sub disk_id_to_dev($$){
#    my $dbh = shift;
#    my $id = shift;
#
#    my $sth = $dbh->prepare("SELECT disk.device
#                             FROM disk
#                             WHERE disk.id = \"$id\"");
#    $sth->execute();
#    my $ref = $sth->fetchrow_hashref();
#    my $dev = $ref->{'device'};
#    $sth->finish();
#    
#    if (!$dev){
#	print "WARNING : there is no disk of id $id\n";
#	return 0;
#    }
#
#    return $dev;
#}

# part_nb_to_id
# gets the id of the partition nb
# parameters : base, partition nb, nodeid
# return value : partition id
sub part_nb_to_id($$$){
    my $dbh = shift;
    my $nb = shift;
    my $nodeid = shift;

    # Recuperation du deployid max
#    my $sth = $dbh->prepare("SELECT MAX(deployed.deployid) as maxid
#                             FROM partition, deployed
#                             WHERE partition.pnumber = \"$nb\" 
#                             AND partition.id = deployed.partid 
#                             AND deployed.nodeid = \"$nodeid\"");
#    $sth->execute();
#    my $max_id = $sth->fetchrow_hashref();
#    $max_id = $max_id->{'maxid'};
#    $sth->finish();

#    my $sth = $dbh->prepare("SELECT partition.id 
#                             FROM partition, deployed 
#                             WHERE partition.pnumber = \"$nb\" 
#                             AND partition.id = deployed.partid 
#                             AND deployed.nodeid = \"$nodeid\"
#                             AND deployed.deployid = \"$max_id\"");
    
    my $sth = $dbh->prepare("SELECT partition.id 
                             FROM partition
                             WHERE partition.pnumber = \"$nb\" ");

    $sth->execute();
    my $ref = $sth->fetchrow_hashref();
    my $id = $ref->{'id'};
    $sth->finish();
    
    if (!$id){
	print "WARNING : there is no partition $nb\n";
	return 0;
    }

    return $id;
}

# part_nb_to_size
# gets the size of the partition nb
# parameters : base, partition nb
# return value : partition size
sub part_nb_to_size($$){
    my $dbh = shift;
    my $nb = shift;

    # print "This function (part_nb_to_size) should not be used\n";
    # print "The mysql query won't be correct for clusters with more than one hard disk\n";
    my $sth = $dbh->prepare("SELECT partition.size FROM partition WHERE partition.pnumber = \"$nb\"");
    $sth->execute();
    my $ref = $sth->fetchrow_hashref();
    my $size = $ref->{'size'};
    $sth->finish();
    
    if (!$size){
	print "WARNING : there is no partition $nb\n";
	return 0;
    }

    return $size;
}

# part_id_to_size
# gets the partition size of partition id id
# parameters : base, partition id
# return value : partition size
sub part_id_to_size($)
{
    my $self=shift;
    my $id = shift;
    my $dbh = $self->{dbh};

    my $sth = $dbh->prepare("SELECT partition.size FROM partition WHERE partition.id = $id");
    $sth->execute();
    my $ref = $sth->fetchrow_hashref();
    my $size = $ref->{'size'};
    $sth->finish();
    
    if (!$size){
	print "WARNING : there is no partition of id $id\n";
	return 0;
    }

    return $size;
}

# part_id_to_nb
# gets the partition nb of partition id id
# parameters : base, partition id
# return value : partition nb
sub part_id_to_nb($) #(partid)
{
    my $self=shift;
    my $id = shift;
    my $dbh = $self->{dbh};

    my $sth = $dbh->prepare("SELECT partition.pnumber FROM partition WHERE partition.id = \"$id\"");
    $sth->execute();
    my $ref = $sth->fetchrow_hashref();
    my $nb = $ref->{'pnumber'};
    $sth->finish();
    
    if (!$nb){
	print "WARNING : there is no partition of id $id\n";
	return 0;
    }

    return $nb;
}


#node_last_dep
#find the last deployed partition of a node
#parameters : base, hostname
#return value: partition nb
sub node_last_dep($$){
        my $dbh = shift;
        my $hostname = shift;

	my $sth = $dbh->prepare("SELECT MAX(deployed.deployid) as maxid
                                 FROM deployed, node
                                 WHERE deployed.nodeid = node.id
				 AND deployed.state = 'deployed'
                                 AND node.name = \"$hostname\"");
        $sth->execute();
        my $max_id = $sth->fetchrow_hashref();
        $max_id = $max_id->{'maxid'};
        $sth->finish();

	$sth = $dbh->prepare("SELECT partition.pnumber
                                 FROM partition, deployed, node 
                                 WHERE partition.id = deployed.partid 
                                 AND deployed.nodeid = node.id
                                 AND deployed.deployid = \"$max_id\"");

	$sth->execute();
        my $ref = $sth->fetchrow_hashref();
        my $pn = $ref->{'pnumber'};
        $sth->finish();
                                                                                                                                                                                                                   r r return $pn;
}

#node_last_dep_env_optsupport
#find the optimisation support of the last deployed environment of the partition of a node
#parameters: base, hostname
#return : optimisation support nb 

sub node_last_dep_env_optsupport($$)
{
    my $dbh = shift;
    my $hostname = shift;
    
    my $sth = $dbh->prepare("
SELECT MAX(deployed.deployid) as maxid
                            FROM deployed, node
                            WHERE deployed.nodeid = node.id
                            AND node.name = \"$hostname\"");
    $sth->execute();
    my $max_id = $sth->fetchrow_hashref();
    $max_id = $max_id->{'maxid'};
    $sth->finish();
    $sth = $dbh->prepare("
SELECT environment.optsupport
                                FROM environment, deployed, node 
                                WHERE environment.id = deployed.envid 
                                AND deployed.nodeid = node.id
                                AND deployed.deployid = \"$max_id\"");
    
    $sth->execute();
    my $ref = $sth->fetchrow_hashref();
    my $pn = $ref->{'optsupport'};
    $sth->finish();
    
    return $pn;
}

#node_last_dep_env
#find the environment name of the last deployed environment of the partition of a node
#parameters: base, hostname
#return : environment name

sub node_last_dep_env($$){
   my $dbh = shift;
   my $hostname = shift;
   my $sth = $dbh->prepare("
SELECT MAX(deployed.deployid) as maxid
                            FROM deployed, node
                            WHERE deployed.nodeid = node.id
                            AND node.name = \"$hostname\"");
   
   $sth->execute();
   my $max_id = $sth->fetchrow_hashref();
   $max_id = $max_id->{'maxid'};
   $sth->finish();
   $sth = $dbh->prepare("
SELECT environment.name
                                 FROM environment, deployed, node 
                                 WHERE environment.id = deployed.envid 
                                 AND deployed.nodeid = node.id
                                 AND deployed.deployid = \"$max_id\"");
   $sth->execute();
   my $ref = $sth->fetchrow_hashref();
   my $pn = $ref->{'name'};
   $sth->finish();
   return $pn;
}                                                       

#node_last_dep_dev
##find the device of the last deployed environment of the partition of a node
##parameters: base, hostname
##return :disk dev 

sub node_last_dep_dev($$){
   my $dbh = shift;
   my $hostname = shift;
   my $sth = $dbh->prepare("
SELECT MAX(deployed.deployid) as maxid
                            FROM deployed, node
                            WHERE deployed.nodeid = node.id
                            AND node.name = \"$hostname\"");
   
   $sth->execute();
   my $max_id = $sth->fetchrow_hashref();
   $max_id = $max_id->{'maxid'};
   $sth->finish();
   
   $sth = $dbh->prepare("SELECT disk.device
	                         FROM disk, deployed, node 
	                         WHERE disk.id = deployed.diskid 
	                         AND deployed.nodeid = node.id
	                         AND deployed.deployid = \"$max_id\"");
   $sth->execute();
   my $ref = $sth->fetchrow_hashref();
   my $pn = $ref->{'device'};
   $sth->finish();
   return $pn;   
}                    

#node_last_envid
##find the envid of the last deployed environment of the partition of a node
##parameters: base, hostname
##return :envid 

sub node_last_envid($$){
   my $dbh = shift;
   my $hostname = shift;
   my $sth = $dbh->prepare("
SELECT MAX(deployed.deployid) as maxid
                            FROM deployed, node
                            WHERE deployed.nodeid = node.id
                            AND node.name = \"$hostname\"");
   
   $sth->execute();
   my $max_id = $sth->fetchrow_hashref();
   $max_id = $max_id->{'maxid'};
   $sth->finish();
   
   $sth = $dbh->prepare("
SELECT MAX(envid) as envid 
FROM deployed 
WHERE deployid=\"$max_id\"
	                        ");
   $sth->execute();
   my $ref = $sth->fetchrow_hashref();
   my $pn = $ref->{'envid'};
   $sth->finish();
   return $pn;   
}                    








# node_name_to_name
# checks if the node exists
# parameters : base, node name
# return value : node name or 0 if it does not exist in the database
sub node_name_exist($)
{
    my $self=shift;
    my $name = shift;
    return $self->node_name_to_id($name);
}

sub nodename_disknumber_to_diskid($$) #(nodename,disknumber)
{
    my $self=shift;
    my $name = shift;
    my $disknumber = shift;
    my $dbh = $self->{dbh};
    my $sqlquery=
"
SELECT disk.id 
FROM disk,node 
WHERE node.name = \"$name\"
AND   node.id = disk.nodeid
AND   disk.dnumber=\"$disknumber\"
";
   my $sth = $dbh->prepare($sqlquery);
   $sth->execute();
   my $ref = $sth->fetchrow_hashref(); 
   my $id = $ref->{'id'}; 
   $sth->finish();
   return $id;
}


# deploy_id_to_env_info
# returns 
# parameters : base, deploy id
# return value : name and kernel path of env to be deployed in an array (name, kernelpath)
sub deploy_id_to_env_info($$){
    my $dbh = shift;
    my $deploy_id = shift;

    my $sth = $dbh->prepare("SELECT environment.id, environment.name, environment.kernelpath, environment.kernelparam, environment.initrdpath, environment.filebase, environment.fdisktype FROM deployed, environment 
                             WHERE deployed.envid = environment.id AND deployed.deployid = \"$deploy_id\"");
    $sth->execute();
    my $ref = $sth->fetchrow_hashref();
    my @env_info = ($ref->{'name'},
		    $ref->{'kernelpath'}, 
		    $ref->{'kernelparam'}, 
		    $ref->{'initrdpath'}, 
		    $ref->{'id'}, 
		    $ref->{'filebase'}, 
		    $ref->{'fdisktype'}); 
    $sth->finish();

    return @env_info;
}

# deploy_id_to_node_info
# returns 
# parameters : base, deploy id
# return value : 
sub deploy_id_to_node_info($$){
    my $dbh = shift;
    my $deploy_id = shift;
    my %node_info;

    my $sth = $dbh->prepare("SELECT node.ipaddr, disk.device, partition.pnumber FROM deployed, node, disk, partition
                             WHERE deployed.nodeid = node.id AND deployed.diskid = disk.id AND deployed.partid = partition.id AND deployed.deployid = \"$deploy_id\"");
    $sth->execute();
    while (my $ref = $sth->fetchrow_hashref()){
        $node_info{$ref->{'ipaddr'}} = [$ref->{'device'},$ref->{'pnumber'}];
    }
    $sth->finish();

    return %node_info;
}

### database accessors end ###
##############################


# add_deploy
# used by kaaddnode
# registers a deployment state
# parameters : base, reference to (part,env), disk id, host id
# return value : /
sub add_deploy($$$$){
    my $dbh = shift;
    my $ref_part_env = shift;
    my $disk_id = shift;
    my $host = shift;

    # debug print
    # print "REF : ($$$ref_part_env[0];$$$ref_part_env[1]) ; DID = $disk_id ; HOST = $host\n";

    my $sth = $dbh->do("INSERT deployed (envid, diskid, partid, nodeid, deployid, state)
                        VALUES ($$$ref_part_env[1],$disk_id,$$$ref_part_env[0],$host,0,'deployed')");
}

# add_partition
# registers partition
# parameters : base, partition_info, disk id
# return value : partition id
sub add_partition($) #(\(pnumber,size,parttype,disk_id,label))
{
    my $self=shift;
    my $disk_id=shift;
    my $ref_part = shift;

    my $dbh = $self->{dbh};
   
    my $pnumber=$ref_part->{number};
    my $size=$ref_part->{size};
    my $parttype=$ref_part->{type};
    my $label=$ref_part->{label};
    my $ostype=$ref_part->{ostype};
    my $fdisktype=$ref_part->{fdisktype};
    my $fs=$ref_part->{fs};
    my $mkfs=$ref_part->{mkfs};

    my $part_id;
    my $sqlupdate;
    my $sqlinsert;
    # TODO : faire des vérifications !

    # debug print
    #print "VALUES = $$ref_part[0] ; $$ref_part[1] ; $$ref_part[2] ; $$ref_part[3]";

    # checks if partition type already exists
    my $sqltest="SELECT partition.id FROM partition,disk
                             WHERE partition.pnumber = \"$pnumber\"
                             AND partition.diskid = \"$disk_id\"";

    my $sth = $dbh->prepare($sqltest);
    $sth->execute();

    $part_id = $sth->fetchrow_hashref(); 
    $part_id = $part_id->{'id'}; 
    $sth->finish();   

    if(!$part_id){
	$sqlinsert="
INSERT partition (pnumber,     size,     diskid,      parttype,     label,     fs,     mkfs,     ostype     ,fdisktype) 
VALUES           (\"$pnumber\",\"$size\",\"$disk_id\",\"$parttype\",\"$label\",\"$fs\",\"$mkfs\",\"$ostype\",\"$fdisktype\")";
	$sth = $dbh->do($sqlinsert);

        $sth = $dbh->prepare($sqltest);
	$sth->execute();
	$part_id = $sth->fetchrow_hashref(); 
	$part_id = $part_id->{'id'}; 
	$sth->finish();
    }
    else
    {
	$sqlupdate="
UPDATE partition 
SET 
size = \"$size\",
parttype  = \"$parttype\",
pnumber   = \"$pnumber\",
label     = \"$label\",
fs        = \"$fs\",
mkfs      = \"$mkfs\",
ostype    = \"$ostype\",
fdisktype = \"$fdisktype\"
WHERE
id=\"$part_id\"";

	$sth = $dbh->do($sqlupdate);
	if (!$sth) { $part_id=0; }
    }
    return $part_id;
}





sub get_partition_from_nodename($$)
{
    my $dbh = shift;
    my $nodename = shift;
    my @partitionsize;
    # TODO : faire des vérifications !
    my $sth = $dbh->prepare("
select 
disk.dnumber,
partition.pnumber,
partition.size,
partition.parttype
from partition,disk,node
where
node.name = \"$nodename\" AND
node.id   = disk.nodeid   AND
disk.id   = partition.diskid
");
    $sth->execute();
    while (my $row = $sth->fetchrow_hashref()) 
    {
#        push(@partitionsize, $row->{'size'});
	
	print "$nodename : ".
	    $row->{'dnumber'}." ".
	    $row->{'pnumber'}." ".
	    $row->{'size'}." ".
	    $row->{'parttype'}."\n";
    }
    $sth->finish();
    return @partitionsize;
}

# add_disk
# registers disk
# parameters : base, disk_info(disknumber,interface,size,nodeid)
# return value : disk id
sub add_disk($)
{
    my $self=shift;
    my $ref_disk = shift;
    my $dbh = $self->{dbh};

    my $id;

    my $disknumber=$$ref_disk[0];
    my $interface=$$ref_disk[1];
    my $size=$$ref_disk[2];
    my $nodeid=$$ref_disk[3];

    # TODO : faire des vérifications !

    # debug print
    #print "VALUES = $$ref_disk[0] ; $$ref_disk[1]\n";

    # checks if disk type already exists

    my $sqltest="SELECT 
disk.id FROM disk,node
WHERE 
nodeid = \"$nodeid\" 
AND 
dnumber = \"$disknumber\"
";
    my $sqlupdate="
UPDATE  disk
SET 
size=\"$size\",
interface=\"$interface\"
WHERE
nodeid= \"$nodeid\" AND
dnumber = \"$disknumber\"
";
    my $sth = $dbh->prepare($sqltest);
    $sth->execute();
    $id = $sth->fetchrow_hashref(); 
    $id = $id->{'id'}; 
    $sth->finish();

    if ($id)
    {
	$sth = $dbh->do($sqlupdate);
    }

    if(!$id)
    {
	
	$sth = $dbh->do("INSERT disk (interface,size,nodeid,dnumber)
                         VALUES (\"$interface\",\"$size\",\"$nodeid\",\"$disknumber\" )");
	$sth = $dbh->prepare($sqltest);
	$sth->execute();
	$id = $sth->fetchrow_hashref(); 
	$id = $id->{'id'}; 
	$sth->finish();
    }    
    return $id;
}

sub del_disk_from_id($)
{
    my $self=shift;
    my $disk_id = shift;

    my $dbh = $self->{dbh};

    my $id;
    my $sth;
    my $sqltest="
SELECT 
disk.id FROM disk
WHERE 
disk.id = \"$disk_id\"  
";
    $sth = $dbh->prepare($sqltest);
    $sth->execute();
    $id = $sth->fetchrow_hashref(); 
    $id = $id->{'id'};     
    $sth->finish();
    if ($id)
    {
	my $sqldel="
DELETE FROM disk 
WHERE
disk.id=\"$id\"
";
	$sth = $dbh->prepare($sqldel);
	$sth->execute();
	$sth->finish();
    }
    return $id;    
}

sub del_partition_from_diskid($)
{
    my $self=shift;
    my $disk_id = shift;
    my $dbh = $self->{dbh};
    my $id;
    my $sth;
    my $sqltest="
SELECT 
partition.id FROM disk,partition
WHERE 
disk.id          = \"$disk_id\" AND
partition.diskid = \"$disk_id\"
";
    $sth = $dbh->prepare($sqltest);
    $sth->execute();
    $id = $sth->fetchrow_hashref(); 
    $id = $id->{'id'};     
    $sth->finish();
    if ($id)
    {
	my $sqldel="
DELETE FROM partition
WHERE
partition.diskid=\"$disk_id\"
";
	$sth = $dbh->prepare($sqldel);
	$sth->execute();
	$sth->finish();
    }
    return $id;    

}

#sub get_diskid_from_nodeid($)
#{
#    my $self=shift;
#    my $nodeid = shift;
#    my $dbh = $self->{dbh};
#    my $id;
#    my @listid;
#    my $reflistid;
#    my $sth;
#    my $sqltest="
#SELECT disk.id 
#FROM 
#node,disk 
#WHERE 
#node.id=\"$nodeid\" AND 
#disk.nodeid=node.id
#";
#    
#    $sth = $dbh->prepare($sqltest);
#    $sth->execute();
#    while ($id = $sth->fetchrow_hashref())
#    {
#	@listid = (@listid, $id->{'id'});
#    }
#    $sth->finish();
#    $reflistid=\@listid;
#    return $reflistid;
#}


sub get_diskid_from_nodeid_disknumber($$)
{
    my $self=shift;
    my $nodeid = shift;
    my $disknumber = shift;
    my $dbh = $self->{dbh};
    my $id;
    my $ref;
    my @listid;
    my $reflistid;
    my $sth;
    my $sqltest="
SELECT disk.id 
FROM 
node,disk 
WHERE 
node.id=\"$nodeid\" AND 
disk.nodeid=node.id AND
disk.dnumber=\"$disknumber\"
";
    
    $sth = $dbh->prepare($sqltest);
    $sth->execute();
    $ref = $sth->fetchrow_hashref();
    $id=$ref->{'id'};
    $sth->finish();
    return $id;
}


sub get_diskinfo_from_diskid($)         #(diskid)
{
    my $self=shift;
    my $diskid=shift;
    my $dbh=$self->{dbh};
    my $sth;
    my $id;
    my $ref;
    my $info;
    my $refinfo;
    my $sqlquery="
SELECT 
disk.size,disk.interface 
FROM 
node,disk 
WHERE 
disk.id=\"$diskid\"
";
    $sth = $dbh->prepare($sqlquery);
    $sth->execute();
    $ref = $sth->fetchrow_hashref();
    $info=
    {
	interface => $ref->{interface},
	size      => $ref->{size},
    };
    return $info;
}

sub get_partitioninfo_from_partitionid($)         #(partitionid)
{
    my $self=shift;
    my $partitionid=shift;
    my $dbh=$self->{dbh};
    my $sth;
    my $id;
    my $ref;
    my $info;
    my $refinfo;
    my $sqlquery="
SELECT 
pnumber, 
size, 
parttype, 
label,
fs,
mkfs,
fdisktype,
ostype
FROM 
partition 
WHERE 
partition.id=\"$partitionid\"     
";
    $sth = $dbh->prepare($sqlquery);
    $sth->execute();
    $ref = $sth->fetchrow_hashref();
    $info=
    {
	pnumber   => $ref->{pnumber},
	size      => $ref->{size},
	parttype  => $ref->{parttype},
	label     => $ref->{label},
	fs        => $ref->{fs},
	mkfs      => $ref->{mkfs},
	fdisktype => $ref->{fdisktype},
	ostype    => $ref->{ostype}
    };
    return $info;
}

sub diskidpartnumber_to_partitionid($$)    #(diskid,partnumber) => partitionid
{
    my $self=shift;
    my $diskid=shift;
    my $partnumber=shift;
    my $dbh=$self->{dbh};
    my $partitionid=0;
    my $sth;
    my $id;
    my @listid;
    my $reflistid;
    my $ref;
    my $info;
    my $refinfo;
    my $sqlquery="
SELECT partition.id
FROM 
disk,partition 
WHERE 
partition.diskid=disk.id AND
disk.id=\"$diskid\"      AND
partition.pnumber=\"$partnumber\"
";

    $sth = $dbh->prepare($sqlquery);
    $sth->execute();
    while ( my $ref = $sth->fetchrow_hashref())
    {
	$partitionid=$ref->{id};
    }

    return $partitionid;
}

sub get_listpartitionid_from_diskid($)    #(diskid) => (partitionid1,...,partitionidn)
{
    my $self=shift;
    my $diskid=shift;
    my $dbh=$self->{dbh};
    my $partitionid=0;
    my $sth;
    my $id;
    my @listid;
    my $reflistid;
    my $ref;
    my $info;
    my $refinfo;
    my $sqlquery="
SELECT partition.id
FROM 
partition 
WHERE 
partition.diskid=\"$diskid\"
";

    $sth = $dbh->prepare($sqlquery);
    $sth->execute();
    while ( my $ref = $sth->fetchrow_hashref())
    {
	@listid=(@listid,$ref->{id});
    }
    $reflistid=\@listid;
    return $reflistid;
}




# add_environment
# registers a new environment into the database
# parameters : base, name, version, description, author, filebase, filesite, size, initrdpath, kernelpath, kernelparam, fdisktype, filesystem, site id
# return value : 1 if successful, 0 otherwise
sub add_environment($$$$$$$$$$$$$$$$){
    my $dbh = shift;
    my $name = shift;
    my $version = shift;
    my $description = shift;
    my $author = shift;
    my $filebase = shift;
    my $filesite = shift;
    my $size = shift;
    my $initrdpath = shift;
    my $kernelpath = shift;
    my $kernelparam = shift;
    my $fdisktype = shift;
    my $filesystem = shift;
    my $siteid = shift;
    my $optsupport = shift;
    my $user = shift;

    # debug print
    #print "$name , $version , $description , $author , $filebase , $filesite , $size , $initrdpath , $kernelpath , $kernelparam , $fdisktype , $filesystem , $siteid\n";
    
    my $sth = $dbh->do("
SELECT 
environment.name, 
environment.version 
FROM environment
WHERE 
environment.name = \"$name\" 
AND environment.version = $version
AND environment.user = \"$user\"");

    if($sth == 1){
	print "ERROR : environment $name version $version already exists\n";
	return 0;
    }else{
	my $successful = 0;
	$successful = $dbh->do("
INSERT environment 
(name,version,description,author,filebase,filesite,size,initrdpath,kernelpath,kernelparam,fdisktype,filesystem,siteid,optsupport,user) 
VALUES 
(\"$name\",\"$version\",\"$description\",\"$author\",\"$filebase\",\"$filesite\",$size,\"$initrdpath\",\"$kernelpath\",\"$kernelparam\",\"$fdisktype\",\"$filesystem\",$siteid,$optsupport,\"$user\")");
	return $successful;
    }

}


#######################
### print and debug ###

# list_node
# gets the list of all node.
# parameters : base
# return value : list of hostnames
# side effects : /
sub list_node($) 
{
    my $self=shift;
    my $dbh = $self->{dbh};
    my $sth = $dbh->prepare("SELECT * FROM node");
    $sth->execute();
    my @res = ();

    while (my $ref = $sth->fetchrow_hashref()) {
        push(@res, $ref->{'name'});
    }
    $sth->finish();
    return @res;
}

# get_node
# get the nodename->ip of all node.
# return value : hash of hostnames->ip
sub get_node($) 
{
    my $self=shift;    
    my $refhash;
    my $name;
    my $ipaddr;
    my $dbh = $self->{dbh};
    my $sth = $dbh->prepare("SELECT * FROM node");    
    $sth->execute();
    my %res;

    while (my $ref = $sth->fetchrow_hashref()) 
    {
	$name=$ref->{name};
	$ipaddr=$ref->{ipaddr};	
	$res{$name}=$ipaddr;	
#	$res{a}=1;
    }
    $sth->finish();
    $refhash=\%res;
    return $refhash;
}



sub get_disk_from_nodeid($$)     #(dbh,nodename)
{
    my $dbh    = shift;
    my $nodeid = shift;



    my $sth = $dbh->prepare("
SELECT disk.dnumber,disk.size,disk.interface,partition.pnumber, partition.size, partition.parttype
FROM node,disk,partition
WHERE
node.id=\"$nodeid\" AND
disk.nodeid=node.id AND
partition.diskid=disk.id
");
    $sth->execute();
    while (my $ref = $sth->fetchrow_hashref()) 
    {
    	
    }
    $sth->finish();
}


sub add_rights_user_nodename_rights($$$) #(username,nodename,rights)
{
    my $self=shift;

    my $username=shift;
    my $nodename=shift;
    my $rights=shift;

    my $row;
    my $sth;
    my $tofetch;
    my $dbh=$self->{dbh};
    my $ok=0;
    my $sqlput="
INSERT rights
(user,node,rights) 
VALUES 
(\"$username\",\"$nodename\",\"$rights\")
";

    my $sqltest="
SELECT 
rights.rights FROM rights
WHERE 
rights.user = \"$username\"
AND
rights.node = \"$nodename\"
AND
rights.rights = \"$rights\"
";

    $sth = $dbh->prepare($sqltest);
    $sth->execute();
    $row = $sth->fetchrow_hashref(); 
    $tofetch = $row->{'rights'};     
    $sth->finish();
    if (! $tofetch)
    {      
       $sth = $dbh->prepare($sqlput);
       if ($sth->execute()) { $ok=1; }
       $sth->finish();
    }
    else
    {
       $ok=1;
    }
    return $ok; 
}


sub del_rights_user_nodename_rights($$$) #(username,nodename,rights)
{
    my $self=shift;

    my $username=shift;
    my $nodename=shift;
    my $rights=shift;

    my $row;
    my $sth;
    my $tofetch;
    my $dbh=$self->{dbh};
    my $ok=0;
    my $sqlput="
DELETE FROM rights 
WHERE 
user=\"$username\"  AND
node=\"$nodename\" AND 
rights=\"$rights\"
";
    my $sqltest="
SELECT 
rights.rights FROM rights
WHERE 
rights.user = \"$username\"
AND
rights.node = \"$nodename\"
AND
rights.rights = \"$rights\"
";
    $sth = $dbh->prepare($sqltest);
    $sth->execute();
    $row = $sth->fetchrow_hashref(); 
    $tofetch = $row->{'rights'};     
    $sth->finish();
    if ($tofetch)
    {      
       $sth = $dbh->prepare($sqlput);
       if ($sth->execute()) { $ok=1; }
       $sth->finish();
    }
    else
    {
       $ok=1;
    }
    return $ok; 
}

sub check_rights($$$)
{
    my $self=shift;

    my $user = shift;
    my $node = shift;
    my $rights = shift;

    my $dbh = $self->{dbh};
    my $ok=0;
    my $sth;
    my $tmp;
    my $sqltest="
SELECT rights.user FROM rights
WHERE 
user = \"$user\"  AND 
node = \"$node\"  AND 
rights = \"$rights\"
";
#    print $sqltest;
    $sth = $dbh->prepare($sqltest);
    $sth->execute();
    $tmp = $sth->fetchrow_hashref();
    $tmp = $tmp->{'user'};
    $sth->finish();
    if($tmp)    { 	$ok=1;     }
    else        { 	$ok=0;     }   
    return $ok;
}


sub get_rights()
{
    my $self=shift;

    my $dbh=$self->{dbh};
    my $sth;
    my $ref_array_rights;
    my @array_rights;
    my $user;
    my $node;
    my $h;
    my $ok=0;
    my $rights;
    my $sqlquery="
SELECT *
FROM 
rights
";
    $sth = $dbh->prepare($sqlquery);
    $sth->execute();
    while ($h=$sth->fetchrow_hashref())
    {
	$user=$h->{'user'};
	$node=$h->{'node'};
	$rights=$h->{'rights'};
	my @line=($user,$node,$rights);
	@array_rights=(@array_rights,\@line);
	$ok=1;
    }
    $ref_array_rights=\@array_rights;
    if (! $ok) { $ref_array_rights=0; }
    return $ref_array_rights;
}



# debug_print
# prints database state 
# parameters : base, deploy_id
# return value : /
sub debug_print($$)
{
    my $dbh = shift;
    my $deploy_id = shift;
    my %res;
    my $ref;
    # gets interesting information

    # from deployed table
    my $sth = $dbh->prepare("SELECT node.name, deployed.state, deployed.error_description
    FROM deployed,node WHERE deployed.deployid = \"$deploy_id\" and node.id=deployed.nodeid");
    $sth->execute();
    while ( $ref = $sth->fetchrow_hashref()) {
    	$res{$ref->{'name'}} = [$ref->{'state'},$ref->{'error_description'}];
    }
    $sth->finish();

    # from deployment table
    $sth = $dbh->prepare("SELECT deployment.id, deployment.state 
                          FROM deployment 
                          WHERE deployment.id = \"$deploy_id\"");
    $sth->execute();
    $ref = $sth->fetchrow_hashref();
    my @depl = ($ref->{'id'},$ref->{'state'});
    $sth->finish();

    # prints information
    print "\nDeploy\tState\n";
    print "------\t-----\n";
    print "$depl[0]\t$depl[1]\n";

    print "\nNode\tState\t\tError Description (if any)\n";
    print "----\t-----\t\t--------------------------\n";
    foreach my $res (keys %res){
	if ($res{$res}[0] eq 'error'){
	    print "$res\t$res{$res}[0]\t\t$res{$res}[1]\n";
	}else{
	    print "$res\t$res{$res}[0]\t\n";
	}
    }
    print "\n";
}

### print and debug end ###
###########################

#######################
### deployment time ###

# set_time
# sets end deployment time to current date
# parameters : base, deployment id
# return value : /
sub set_time($$){
    my $dbh = shift;
    my $id = shift;
    my $sth;

    $sth = $dbh->do("UPDATE deployment 
                     SET deployment.enddate = NOW() 
                     WHERE deployment.id = $id");
}

# get_time
# returns time difference between current date and end deployment date
# parameter : base, deployment id
# return value : time difference between current date and end date
sub get_time($$){
    my $dbh = shift;
    my $id = shift;
    my $sth;

    $sth = $dbh->prepare("SELECT (TIME_TO_SEC(NOW()) - TIME_TO_SEC(enddate)) AS diff
                          FROM deployment WHERE deployment.id = $id");
    $sth->execute();
    my $diff = $sth->fetchrow_hashref();
    $diff = $diff->{'diff'};
    $sth->finish();

    return $diff;
}

### deployment time end ###
###########################

# report_state
# report the state of the node into the database after a check
# parameters : base, deployment, name, state, error status
# return value : /
sub report_state($$$$$){
    my $dbh = shift;
    my $deploy_id = shift;
    my $name = shift;
    my $state = shift;
    my $error_status = shift;
    
    my $sth = $dbh->prepare("SELECT node.id FROM node WHERE node.name = \"$name\"");
    $sth->execute();
    my $ref = $sth->fetchrow_hashref(); 
    my $id = $ref->{'id'}; 
    $sth->finish();
    $sth = $dbh->do("UPDATE deployed 
                     SET deployed.state = \"$state\", deployed.error_description = \"$error_status\"
                     WHERE deployed.nodeid = $id AND deployed.deployid = $deploy_id");
}

# is_node_free
# checks if the node is free for deployment
# parameters : base, node id, deployment id
# return value : 1 if node is free, otherwise 0 
#sub is_node_free($$$){
#    my $dbh = shift;
#    my $node_id = shift;
#    my $deploy_id = shift;
#    my $sth;

    # debug print
    # print "NODEID = $node_id ; DEPLOYID = $deploy_id\n";

    # checks if node is already involved in another running deployment
#    $sth = $dbh->prepare("SELECT IFNULL(COUNT(deployed.nodeid),0) as id
#	                  FROM deployed, deployment
#	                  WHERE deployed.nodeid = $node_id
#                          AND deployment.id = deployed.deployid
#		          AND deployment.state = 'running'");
#    $sth->execute();
#    my $nb = $sth->fetchrow_hashref(); 
#    $nb = $nb->{'id'};
#    $sth->finish();
#    if($nb == 0){
#	# node is free
#	return 1;
#    }elsif($nb == 1){
#	my $node = libkadeploy2::deploy_iolib::node_id_to_name($dbh,$node_id);
#	print "WARNING : node $node is already involved in another deployment\n";
#	return 0;
#    }else{
#	print "ERROR : unexpected number of partition involved in deployment for node ($nb)\n";
#	return 0;
#    }
#}

# add_node_to_deployment
# performs several checks and do db appropriate modifications
# parameters : base, hostname, deploy id, env name, disk dev, part nb
# return value : 1 if successful, 0 if failed
#sub add_node_to_deployment($$$$$$){
#    my $dbh = shift;
#    my $hostname = shift;
#    my $deploy_id = shift;
#    my $env_name = shift;
#    my $disk_dev = shift;
#    my $part_nb = shift;
#
#    my $node_id = libkadeploy2::deploy_iolib::node_name_to_id($dbh,$hostname);
#    my $disk_id = libkadeploy2::deploy_iolib::disk_dev_to_id($dbh,$disk_dev);
#    my $part_id = libkadeploy2::deploy_iolib::part_nb_to_id($dbh,$part_nb,$node_id);
#    my $env_id  = libkadeploy2::deploy_iolib::env_name_to_last_ver_id($dbh,$env_name);
    
    # performs cheks
#    if((!$node_id) || (!$disk_id) || (!$part_id) || (!$env_id)){
#	return 0;
#    }

    # ! debug print !
    # print "DEBUG : NODE = $node_id ; DISK = $disk_id ; PART = $partition_id ; ENV = $env_id\n";
    
#    my $is_free = libkadeploy2::deploy_iolib::is_node_free($dbh,$node_id,$deploy_id);
#    if($is_free){
#	my $env_size  = libkadeploy2::deploy_iolib::env_id_to_size($dbh,$env_id);
#	my $part_size = libkadeploy2::deploy_iolib::part_id_to_size($dbh,$part_id);
#	if($env_size < $part_size){
#	    libkadeploy2::deploy_iolib::set_deployment_features($dbh,$node_id,$deploy_id,$env_id,$disk_id,$part_id);
#	}else{
#	    print "Environment too large for the partition\n";
#	    return 0;
#	}
#    }else{
#	print "Node isn't free\n";
#	return 0;
#    }
#    return 1;
#
#}

# set_deployment_features
# sets deployment id in deployed table
# parameters : base, node id, deploy id, env id, disk id, part id
# return value : 1 if successful
sub set_deployment_features($$$$$$)
{
    my $dbh = shift;
    my $node_id = shift;
    my $deploy_id = shift;
    my $env_id = shift;
    my $disk_id = shift;
    my $part_id= shift;

    my $sth = $dbh->do("INSERT deployed
                     SET deployed.envid = $env_id,
                         deployed.state = 'deploying',
                         deployed.deployid = $deploy_id,
                         deployed.nodeid = $node_id,
                         deployed.diskid = $disk_id,
                         deployed.partid = $part_id");

    return 1;
}	  

###################
### other tools ###

# correct_db_consistence
# corrects the db in case it would be left in a inconsistent state
# parameters : base
# return value : /
# NB : first version very basic ; to be improved... ?
#      mustn't be used concurrently to deployment pocedures
sub correct_db_consistence($)
{
    my $dbh = shift;
    
    my $sth = $dbh->do("UPDATE deployed 
                        SET deployed.state='error', 
                            deployed.error_description='Auto-modified by Correct_db_consistence function' 
                        WHERE deployed.state='deploying' 
                        OR deployed.state='to_deploy'");
    $sth = $dbh->do("UPDATE deployment 
                     SET deployment.state='error', 
                         deployment.enddate=NOW() 
                     WHERE deployment.state='waiting' 
                     OR deployment.state='running'");
}

# correct_deployment_consistence
# corrects the db in case the deployment would be left in a inconsistent state 
# parameters : base, deployment
# return value : /
sub correct_deployment_consistence($$){
    my $dbh = shift;
    my $deploy_id = shift;
    
    my $sth = $dbh->do("UPDATE deployed 
                        SET deployed.state='error', 
                            deployed.error_description='Auto-modified by Correct_db_consistence function' 
                        WHERE deployed.deployid=$deploy_id
                        AND (deployed.state='deploying' OR deployed.state='to_deploy')");

    $sth = $dbh->do("UPDATE deployment 
                     SET deployment.state='error', 
                         deployment.enddate=NOW() 
                     WHERE deployment.id=$deploy_id
                     AND (deployment.state='waiting' OR deployment.state='running')");
}

# erase_partition
# changes deployed environment to empty on specified partition
# N.B. : it is also directly possible to deployed over a partition
# that already contains an environment via add_deployment_partition
# that will overwrite exisiting data
# parameters : base, ip and partition in a hash
#              structure of hash is described below :
#              %param = (
#                   ip_addr1 => ("disk id, part id");
#                   ip_addr2 => ("disk id, part id");
#                           ....
#                     );
# return value : /
sub erase_partition($%){
    my $dbh = shift;
    my %hash = @_;

    for my $to_erase (keys %hash){
	# gets node id
	my $sth = $dbh->prepare("SELECT node.id FROM node WHERE node.ipaddr = \"$to_erase\"");
	$sth->execute();    
	my $node_id = $sth->fetchrow_hashref();
	$node_id = $node_id->{'id'};
	$sth->finish();

	# gets empty environment id
	$sth = $dbh->prepare("SELECT environment.id FROM environment WHERE environment.name='empty'"); 
	$sth->execute();
	my $empty_env_id = $sth->fetchrow_hashref();
	$empty_env_id = $empty_env_id->{'id'};
	$sth->finish();

	$sth = $dbh->do("UPDATE deployed
                         SET deployed.envid = \"$empty_env_id\",
                             deployed.state = 'deployed',
                             deployed.deployid = '0'
                         WHERE deployed.nodeid = $node_id
                         AND deployed.diskid = $hash{$to_erase}[0]
                         AND deployed.partid = $hash{$to_erase}[1]");
    }
}

### other tools end ###
#######################

# END OF THE MODULE
return 1;

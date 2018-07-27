package KaVLAN::RightsMgt;

use DBI;
use strict;
use const;


# CONNECTION

# add_user
# grants user deployment rights
# parameters : base, login, node, vlan
# return value :
sub add_user{
    my $dbh  = shift;
    my $user = shift;
    my $node = shift;
    my $vlan = shift;

    &const::debug("LOGIN = $user ; HOST = $node ; VLAN = $vlan");

    my $sth = $dbh->do("INSERT rights (user,node,vlan)
                         VALUES (\"$user\",\"$node\",\"$vlan\")");
}

# del_user
# revokes user deployment rights
# parameters : user, node, part
# return value : 
sub del_user{
    my $dbh  = shift;
    my $user = shift;
    my $node = shift;
    my $vlan = shift;

    &const::debug("USER = $user ; HOST = $node ; DEV = $vlan");

    if($user eq "*"){
        if($node eq "*"){
            # node undefined
            if($vlan eq "*"){
                # vlan undefined 
                print "ERROR : this case should never happen ?!!??!\n";
            }else{
                # vlan defined
                my $sth = $dbh->do("DELETE FROM rights
                                    WHERE vlan = \"$vlan\"");
            }
        }else{
            # node defined
            if($vlan eq "*"){
                # vlan undefined
                my $sth = $dbh->do("DELETE FROM rights
                                WHERE node = \"$node\"");
            } else {
                # vlan defined
                my $sth = $dbh->do("DELETE FROM rights
                                WHERE node = \"$node\"
                                AND vlan = \"$vlan\"");
            }
        }
    } else {
        if ($node eq "*") {
            # node undefined
            if ($vlan eq "*") {
                # vlan undefined 
                my $sth = $dbh->do("DELETE FROM rights
                                     WHERE user = \"$user\"");
            } else {
                # vlan defined
                my $sth = $dbh->do("DELETE FROM rights
                                WHERE user = \"$user\"
                                AND vlan = \"$vlan\"");
            }
        } else {
            # node defined
            if ($vlan eq "*") {
                # vlan undefined
                my $sth = $dbh->do("DELETE FROM rights
                                WHERE user = \"$user\"
                                AND node = \"$node\"");
            } else {
                # vlan defined
                my $sth = $dbh->do("DELETE FROM rights
                                WHERE user = \"$user\"
                                AND node = \"$node\"
                                AND vlan = \"$vlan\"");
            }
        }
    }
}

# Unfinished yet
# clean_db
# cleans the database to suppress right redondancy
# parameter : base
# return value :
sub clean_db($){
    my $dbh = shift;
    my $sth;

    # gets all user names
    $sth = $dbh->prepare("SELECT DISTINCT user FROM rights");
    $sth->execute();
    my @user = ();
    while (my $ref = $sth->fetchrow_hashref()) {
        push(@user, $ref->{'user'});
    }
    $sth->finish();

    foreach my $user (@user){
        # print "USER = $user\n";
        $sth = $dbh->prepare("SELECT DISTINCT node
                              FROM rights
                              WHERE user = \"$user\"");
        $sth->execute();
        my @node = ();
        while (my $ref = $sth->fetchrow_hashref()) {
            push(@node, $ref->{'user'});
        }
        $sth->finish();
    }
}

# get_node_rights
# returns the allowed vlanitions for the user
sub get_node_rights {
    my $dbh      = shift;
    my $user     = shift;
    my $nodename = shift;

    my $res = "";

    my $sth = $dbh->prepare("SELECT * FROM rights
                             WHERE (user = \"$user\" OR user = '*')
                             AND (node = '*' OR node = \"$nodename\")");
    $sth->execute();
    my @res_array;
    if ($sth >= 1) {
        while (my $ref = $sth->fetchrow_hashref()) {
            if ($ref->{vlan} eq "*") {
                return "*";
            } else {
                push (@res_array, $ref->{vlan})
            }
        }
        $res = join (" ", @res_array);
    }
    return $res;
}

# check_node_rights
# checks if the given user has appropriate rights for requested node
# parameters : base, user name, node, target vlan number
# return value : 1 if he has, 0 if not
sub check_node_rights {
    my $dbh      = shift;
    my $user     = shift;
    my $nodename = shift;
    my $vlan     = shift;

    my $sth = $dbh->do("SELECT * FROM rights
                        WHERE (user = \"$user\" OR user = '*')
                        AND (node = '*' OR node = \"$nodename\")
                        AND (vlan = '*' OR vlan = \"$vlan\")");

    if($sth >= 1) { # right OK
        return 1;
    }
    # right not granted on this node
    return 0;
}


# check_rights_nodelist
# checks if the given user has appropriate rights for requested vlan
# parameters : base, user name, node, target vlan number
# return value : 1 if he has, 0 if not
sub check_rights_nodelist{
    my $dbh      = shift;
    my $user     = shift;
    my $ref_host = shift;
    my $vlan     = shift;

    my $result;

    &const::debug("LOG = $user ; VLAN = $vlan ; ");

    my @host_list = @{$ref_host};
    foreach my $host (@host_list){
        $result = check_node_rights($dbh, $user, $host, $vlan);

        if ($result == 0) {
            print("WARNING : \"$user\" does not have kavlan rights on $host using VLAN $vlan\n");
            return 0;
        }
    }

    return 1;
}


# check_node_lazy_rights
# checks if the given user has appropriate rights for requested deployment
# parameters : base, user name, node
# return value : 1 if he has, 0 if not
sub check_node_lazy_rights{
    my $dbh      = shift;
    my $user     = shift;
    my $nodename = shift;

    my $sth = $dbh->do("SELECT * FROM rights
                        WHERE (user = \"$user\" OR user = '*')
                        AND (node = '*' OR node = \"$nodename\")");

    if($sth >= 1) { # right OK
        return 1;
    }
    # right not granted on this node
    return 0;
}

# check_lazy_rights_nodelist
# checks if the given user has appropriate rights for requested deployment
# parameters : base, user name, node
# return value : 1 if he has, 0 if not
sub check_lazy_rights_nodelist{
    my $dbh      = shift;
    my $user     = shift;
    my $hostref = shift;

    my $result;

    &const::debug("LOG = $user ; ref_host = $hostref ; ");
    my @host_list = @{$hostref};
    foreach my $host (@host_list){
        $result = check_node_lazy_rights($dbh, $user, $host);

        if($result == 0){
            print("WARNING : \"$user\" does not have vlan rights on $host (node excluded)\n");
            return 0;
        }
    }

    return 1;
}

# connects to database and returns the base identifier
# parameters : /
# return value : base
sub connect {
    my $host = shift;
    my $name = shift;
    my $user = shift;
    my $pwd  = shift;

    my $status = 1;

    my $dbh = DBI->connect("DBI:mysql:database=$name;host=$host",
                           $user,$pwd,{'PrintError'=>0,'InactiveDestroy'=>1}) or $status = 0;

    if ($status == 0) {
        print STDERR "ERROR : connection to database $name failed: $DBI::errstr\n";
        print STDERR "ERROR : please check your configuration file\n";
        exit 1;
    }
    return $dbh;
}

# disconnect from database
# parameters : base
# return value : /
sub disconnect {
    my $dbh = shift;

    # Disconnect from the database.
    $dbh->disconnect();
}

# END OF THE MODULE
return 1;

package libkadeploy2::rights_iolib;

use DBI;
use libkadeploy2::conflib qw(init_conf get_conf is_conf);
use strict;

sub add_user($$$$);
sub del_user($$$$);
sub check_rights_kadeploy($$$$);
sub check_lazy_rights_kadeploy($$$);
# Unfinished
sub clean_db($);        # will clean db in order to suppress redondancy

# CONNECTION

# add_user
# grants user deployment rights
# parameters : base, login, node, part
# return value : 
sub add_user($$$$){
    my $dbh = shift;
    my $user = shift;
    my $node = shift;
    my $part = shift;

    # debug print
    # print "LOGIN = $user ; HOST = $node ; PART = $part\n";

    my $sth = $dbh->do("INSERT rights (user,node,part)
                         VALUES (\"$user\",\"$node\",\"$part\")");
}

# del_user
# revokes user deployment rights
# parameters : user, node, part
# return value : 
sub del_user($$$$){
    my $dbh = shift;
    my $user = shift;
    my $node = shift;
    my $part = shift;

    # debug print
    # print "USER = $user ; HOST = $node ; DEV = $part\n";
    
    if($user eq "*"){
	if($node eq "*"){
	    # node undefined
	    if($part eq "*"){
		# part undefined 
		print "ERROR : this case should never happen ?!!??!\n";
	    }else{
		# part defined
		my $sth = $dbh->do("DELETE FROM rights
                                    WHERE part = \"$part\"");
	    }
	}else{
	    # node defined
	    if($part eq "*"){
		# part undefined
		my $sth = $dbh->do("DELETE FROM rights
                                WHERE node = \"$node\"");
	    }else{
		# part defined
		my $sth = $dbh->do("DELETE FROM rights
                                WHERE node = \"$node\"
                                AND part = \"$part\"");
	    }
	}
    }else{
	if($node eq "*"){
	    # node undefined
	    if($part eq "*"){
		# part undefined 
		my $sth = $dbh->do("DELETE FROM rights
                                     WHERE user = \"$user\"");
	    }else{
		# part defined
		my $sth = $dbh->do("DELETE FROM rights
                                WHERE user = \"$user\"
                                AND part = \"$part\"");
	    }
	}else{
	    # node defined
	    if($part eq "*"){
		# part undefined
		my $sth = $dbh->do("DELETE FROM rights
                                WHERE user = \"$user\"
                                AND node = \"$node\"");
	    }else{
		# part defined
		my $sth = $dbh->do("DELETE FROM rights
                                WHERE user = \"$user\"
                                AND node = \"$node\"
                                AND part = \"$part\"");
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

# check_rights_kadeploy
# checks if the given user has appropriate rights for requested deployment
# parameters : base, user name, node, target part number
# return value : 1 if he has, 0 if not
sub check_rights_kadeploy($$$$){
    my $dbh = shift;
    my $user = shift;
    my $ref_host = shift;
    my $device = shift;

    my @granted_host = ();

    # debug print
    # print "LOG = $user ; PART = $device ; ";

    my @host_list = @{$ref_host};
    foreach my $host (@host_list){
	my $sth = $dbh->do("SELECT * FROM rights
                            WHERE (user = \"$user\" OR user = '*')
                            AND (node = '*' OR node = \"$host\")
                            AND (part = '*' OR part = \"$device\")");

	if($sth >= 1){
	    push(@granted_host, $host);
	}else{
	    print("WARNING : \"$user\" does not have deployment rights on $host $device (node excluded)\n");
	    return 0;
	}
    }

    return 1;
}

# check_lazy_rights_kadeploy
# checks if the given user has appropriate rights for requested deployment
# parameters : base, user name, node
# return value : 1 if he has, 0 if not
sub check_lazy_rights_kadeploy($$$){
    my $dbh = shift;
    my $user = shift;
    my $ref_host = shift;

    my @granted_host = ();

    # debug print
    # print "LOG = $user ; PART = $device ; ";

    my @host_list = @{$ref_host};
    foreach my $host (@host_list){
	my $sth = $dbh->do("SELECT * FROM rights
                            WHERE (user = \"$user\" OR user = '*')
                            AND (node = '*' OR node = \"$host\")");

	if($sth >= 1){
	    push(@granted_host, $host);
	}else{
	    print("WARNING : \"$user\" does not have rights on $host\n");
	    return 0;
	}
    }

    return 1;
}


# END OF THE MODULE
return 1;

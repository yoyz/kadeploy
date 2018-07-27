#!/bin/bash

#===================
# Globals variables
#===================
PATH=/bin:/sbin:/usr/bin:/usr/sbin

TSTAMP=$( date +%Y%m%d-%H%M-%N )
ROOT_HOMEDIR=""
KADEPLOY_USER_DIR=".kadeploy"
NODES_LIST="__nodes_list"
TEMP_FILES_DIR="/tmp"
NL_FNAME=""
CLUSTER_NAME=""
CLUSTER_FILES=""
TMP_USED=0
OAR_UID=$(getent passwd oar|cut -d: -f3)
ROOT_UID=0

# Makefile Substituted variables
DEPLOYCONFDIR=__SUBST__
DEPLOYDIR=__SUBST__
DEPLOYBINDIR=__SUBST__
DEPLOYUSER=__SUBST__
PERL5LIBDEPLOY=__SUBST__

export DEPLOYDIR
export PERL5LIB=${PERL5LIBDEPLOY}/:$PERL5LIB
PREPEND=""
NL_APPEND=""

#===========
# Functions
#===========

function die()
{
  echo -e "Fatal : $1\nexiting.\n" && exit 1
}

function warn()
{
  echo -e "Warning : $1.\n"
}

#_______________________________
# split nodes for multi-cluster
function kadeploy_split_nodes()
{
    local nodeslist=$1

    for node in $(cat $nodeslist); do
      # Induce cluster name from node hostname
      cluster=$(echo $node | cut -f1 -d"." | sed s/[-]*[0-9]*//g)
      # Induce cluster name from conf file ; access right issue !
      # cluster=$(sudo -u $DEPLOYUSER  grep "^${node}" ${DEPLOYCONFDIR}/deploy_cluster.conf|cut -d' ' -f2)
      echo $node >> ${NL_FNAME}.${cluster}.${TSTAMP}
    done
}

#___________________________
# Check if directory exists
check_dir_exists()
{
  local dir=$1
  if [ ! -d "$dir" ]; then
    ( mkdir ${dir} || die "failed to create ${dir}" )
  fi
  check_access $dir
  if [ "$?" -ne 0 -a "$EUID" -ne "$OAR_UID" -a "$EUID" -ne "$ROOT_UID" ]; then
    ( chmod 755 ${dir} || die "failed to chmod ${dir}" )
  fi
}

#______________________________________
# Check if directory is open to others
check_access()
{
  local dir=$1
  or=$(stat ${dir} -c "%A"|sed -e 's/^.......//g')
  if [ "$or" == "r-x" -o "$or" == "rwx" ]; then
    return 0
  else
    return 1
  fi	    
} 

#__________________________________________________________________
# Check if Kadeploy user's directory is accessible for deploy user
check_kudir_access()
{
  check_access ${ROOT_HOMEDIR}
  if [ "$?" -eq 0 ]; then
    check_access ${ROOT_HOMEDIR}/${KADEPLOY_USER_DIR}
    if [ "$?" -eq 0 ]; then
      return 0
    fi
  fi
  return 1
}

#___________________________________________
# Check if kadeploy User's directory exists
function check_kadeploy_user_dir()
{
  local $kudir
  
  if [ "$USER" == "root" -o "$UID" -eq 0 ]; then
    ROOT_HOMEDIR="/root"
  else
    ROOT_HOMEDIR=$(getent passwd "${USER}"|cut -d: -f6)
  fi
  if [ -n "$ROOT_HOMEDIR" ]; then
    kudir="$ROOT_HOMEDIR/$KADEPLOY_USER_DIR"
  else
    die "Non-existent home directory"
  fi
  check_dir_exists ${kudir}
}

#____________________________________
# Some checks before Kadeploy's call
function check_kadeploy_call()
{
  if [ $(basename $0) == "kadeploy" ]; then
    if $(tty -s) 
    then
      PREPEND=""
    else
      PREPEND="screen -D -m "
      echo -e "Kadeploy not launched from a tty\nDetached in a screen\n "
    fi
  fi
}

#_________________________________________________________________
# Extract cluster name from nodes list sorted by cluster filename
function get_cluster_name()
{
  local file=$(basename $1)
  CLUSTER_NAME=$(echo $file|sed -e 's/^.*\.\([a-zA-Z0-9]*\)\..*$/\1/g')      
}

#________________________________________________________________
# Retrieve all filenames containing nodes list sorted by cluster
function get_list_of_cluster_files()
{
  CLUSTER_FILES=$(ls ${NL_FNAME}.*.${TSTAMP})
}

#_________________________________________________
# Remove temporary files generated for deployment
function clean_tmp_files()
{
  ( rm -f ${NL_FNAME}.*.${TSTAMP} || \
  warn "failed to remove temporary files in ${ROOT_HOMEDIR}/${KADEPLOY_USER_DIR}" )
  sudo -u $DEPLOYUSER $DEPLOYDIR/bin/kadeploy --rmnodefilesintmp $USER -x $NL_APPEND
  if [ "$TMP_USED" -eq 1 ]; then
    rm -rf ${TEMP_FILES_DIR}/${KADEPLOY_USER_DIR}_${USER}
  fi
}


#=============
# Entry point
#=============

check_kadeploy_call

check_kadeploy_user_dir

if [ -x $DEPLOYDIR/sbin/`basename $0` ]
then
    ( ( sudo -u $DEPLOYUSER $DEPLOYDIR/sbin/$(basename $0) "$@" ) || \
      ( die "bad configuration" ) )
elif [ -x $DEPLOYDIR/bin/`basename $0` ]; then 
    if [ "`basename $0`" != "kadeploy" ]; then
      ( ( ${PREPEND} sudo -u $DEPLOYUSER $DEPLOYDIR/bin/$(basename $0) "$@" ) || \
	( die "bad configuration" ) )
    else
      remaining_args=""
      node_list=""
      filename=""
      script=""
      while [ -n "$1" ]; do
        case "$1" in
	  -m|--machine)
	    node_list="$node_list $2"
	    shift
	    shift;;
	  -f|--filename)
	    filename="$2"
	    shift
	    shift;;
	  -k|--keys)
	    keys=1
	    shift;;
	  -s|--script)
	    script="$2"
	    shift
	    shift;;
	  -a|--append)
	    NL_APPEND="$2"
	    shift
	    shift;;
	  -h|--help)
	    ${PREPEND} sudo -u $DEPLOYUSER $DEPLOYDIR/bin/$(basename $0) "--help"
	    exit 0;;
          --version)
	    ${PREPEND} sudo -u $DEPLOYUSER $DEPLOYDIR/bin/$(basename $0) "--version"
	    exit 0;;	      
          *)
	    remaining_args="$remaining_args $1"
	    shift;;
	esac
      done

      if [ -z "$NL_APPEND" ]; then
        NL_APPEND=$TSTAMP
      fi
	# split nodes into many lists as clusters implied in deployment
	# Check cases whether nodes are provided by a file or a parameter's list
	check_kudir_access
	if [ "$?" -eq 0 ]; then
	  NL_FNAME="${ROOT_HOMEDIR}/${KADEPLOY_USER_DIR}/${NODES_LIST}"
	else
	  # Kadeploy user's directory not accessible to deploy user
	  # -> switch to /tmp for nodes list file
	  tmp_kudir="${TEMP_FILES_DIR}/${KADEPLOY_USER_DIR}_${USER}"
	  check_dir_exists ${tmp_kudir}
	  NL_FNAME="${tmp_kudir}/${NODES_LIST}"
	  TMP_USED=1
	fi
	NLIST="${NL_FNAME}.${TSTAMP}"
	if [ -n "$filename" ]; then
	  cat ${filename}|sort -n|uniq > ${NLIST}
	elif [ -n "$node_list" ]; then
	  echo ${node_list}|tr ' ' '\n'|sort -n|uniq > ${NLIST}
	fi
	if [ -s "$NLIST" ]; then
	  kadeploy_split_nodes ${NLIST} && rm -f ${NLIST}
	else
	  die "Kadeploy called on empty node list"
	fi

	# Call Kadeploy for each cluster found
	get_list_of_cluster_files
	for file in $CLUSTER_FILES; do
	  if [ -f "$file" -a -s "$file" ]; then
	    get_cluster_name $file
	    cluster=$CLUSTER_NAME
	    echo -e "\n==> Launching Kadeploy on $cluster nodes\n"
	    cmd_args="$remaining_args -f ${NL_FNAME}.${cluster}.${TSTAMP} -z $cluster -x $NL_APPEND"
	    set -- $cmd_args 
	    ${PREPEND} sudo -u $DEPLOYUSER $DEPLOYDIR/bin/$(basename $0) "$@" &
	  fi
	done

	#waiting all instances of kadeploy
	wait

	#copy ssh keys in root's authorized_keys
	get_list_of_cluster_files
	for file in $CLUSTER_FILES; do 
	  if [ -f "$file" -a -s "$file" ]; then
	    get_cluster_name $file
	    cluster=$CLUSTER_NAME
	    # Beware to keep same file name between kasudowrapper and kadeploy:582
	    nlist_ok="${TEMP_FILES_DIR}/kadeploy-${USER}-${cluster}-nodes_ok.out.${NL_APPEND}"
	    nlist_nok="${TEMP_FILES_DIR}/kadeploy-${USER}-${cluster}-nodes_nok.out.${NL_APPEND}"
	    #copy nodes files in the current directory
	    cp $nlist_ok "${ROOT_HOMEDIR}/${KADEPLOY_USER_DIR}/" 2>/dev/null
	    cp $nlist_nok "${ROOT_HOMEDIR}/${KADEPLOY_USER_DIR}/" 2>/dev/null
	    if [ $keys ]; then
	      if [ -f ~/.ssh/id_rsa.pub ]; then
		${DEPLOYBINDIR}/kaaddkeys -f ${nlist_ok} -C ${DEPLOYCONFDIR} -k ~/.ssh/id_rsa.pub
	      elif [ -f ~/.ssh/id_dsa.pub ]; then
		${DEPLOYBINDIR}/kaaddkeys -f ${nlist_ok} -C ${DEPLOYCONFDIR} -k ~/.ssh/id_dsa.pub
	      fi
	    fi
	  fi
	done
	
	# Purge temporary generated files
	clean_tmp_files
	
	# Launch a script after the deployment
	if [ "$script" ]; then 
	  ( [ -e "$script" -a -x "$script" ] && $script ) || \
	  warn "$script not found or not executable"
        fi
    fi
fi

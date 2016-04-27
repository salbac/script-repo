#!/bin/sh
###############################################################################
# $Id: common_subs_func.sh,v 1.12 2014/10/17 08:40:54 cvsuladzimir Exp $'
###############################################################################
#
# common_subs_func.sh
# Common functions for subs scanners
#

# Version="23.04"
# 14/03/14 - US - remove all possible round brackets in the end of OS_VERSION string for Linux
# 17/06/14 - US - "whick mktemp" and "which uuencode" -x check
# 18/06/14 - US - support for VIO servers is added
# 24/06/14 - US - OS version empty log fix for VIO
# 09/07/14 - DK - bin/sh - > /bin/sh

DEBUG_MODE=${DEBUG_MODE:=false}
DEBUG_MESSAGES=${DEBUG_MESSAGES:=false}
[ "$DEBUG_MODE" = "true" ] && set -x
set +u
LANG=C; export LANG
export DEBUG_MODE;
export DEBUG_MESSAGES;
exec < /dev/null

SCANNER_VERSION="v$Version"

#----------------------------------------------------------------------
# reseting all variables that used for outputing to log
# and mif files
#----------------------------------------------------------------------
Reset_Vars() {
    [ "$DEBUG_MODE" = "true" ] && set -x
    COMPUTER_SYS_ID=""; CUST_ID=""; SYST_ID=""
    SUBSYSTEM_INSTANCE=""; SUBSYSTEM_TYPE=""
    MW_VERSION=""; MW_EDITION=""; FIXPACK=""
    INSTANCE_PATH=""; DB_NAME=""; SAP_INSTALLED=""
    SAP_CVERS=""; INSTANCE_PORT=""
    NB_TABLES=""; NB_INDEXES=""; ALLOC_DB=""
    USED_DB=""; ALLOC_LOG=""; USED_LOG=""
    DB_PART=""; TABLE_PART=""; INDEX_PART=""
    SERVER_TYPE=$UOS; DB_TYPE=""; DBMS_TYPE=""
    SDC=""; DB_USAGE=""; SVC_OFFERED=""
    HC_REQUIRED=""; MW_INST_ID=""; MW_MODULE=""
    MW_NB_EAR=""; MW_NB_USERS=""; MW_NB_MNDTS=""
    SW_BUNDLE=""
}
#----------------------------------------------------------------------
# Creating empty logfile
#----------------------------------------------------------------------
Create_Empty_Log() {
    # Parameter:
    #  $1 -- log file
    #  $2 -- subsystem type
    [ "$DEBUG_MODE" = "true" ] && set -x

    ostype=$UOS
    osver=$OS_VERSION
    if [ -n "$IS_ESX" ]; then
        ostype="VMWARE"
        osver=$ESX_VERSION
    fi
    if [ -n "$IS_VIO" ]; then
        ostype="VIO"
        osver=$VIO_VERSION
    fi

    echo "COMPUTER_SYS_ID=;CUST_ID=;SYST_ID=;HOSTNAME=$HOSTNAME;SUBSYSTEM_INSTANCE=NO;SUBSYSTEM_TYPE=$2;MW_VERSION=;MW_EDITION=;FIXPACK=;INSTANCE_PATH=;DB_NAME=;SCAN_TIME=$SCAN_TIME;SAP_INSTALLED=;SAP_CVERS=;OS_VERSION=$osver;INSTANCE_PORT=;NB_TABLES=;NB_INDEXES=;ALLOC_DB=;USED_DB=;ALLOC_LOG=;USED_LOG=;DB_PART=;TABLE_PART=;INDEX_PART=;SERVER_TYPE=$ostype;DB_TYPE=;DBMS_TYPE=;SDC=;DB_USAGE=;SVC_OFFERED=;HC_REQUIRED=;MW_INST_ID=;MW_MODULE=;MW_NB_EAR=;MW_NB_USERS=;MW_NB_MNDTS=;SW_BUNDLE=;SCANNER_VERSION=$SCANNER_VERSION;" > $1
}

#----------------------------------------------------------------------
# Creating empty logfile
#----------------------------------------------------------------------
Create_NotSupported_Log() {
    # Parameter:
    #  $1 -- log file
    #  $2 -- subsystem type
    [ "$DEBUG_MODE" = "true" ] && set -x

    ostype=$UOS
    osver=$OS_VERSION
    if [ -n "$IS_ESX" ]; then
        ostype="VMWARE"
        osver=$ESX_VERSION
    fi
    if [ -n "$IS_VIO" ]; then
        ostype="VIO"
        osver=$VIO_VERSION
    fi
    echo "COMPUTER_SYS_ID=;CUST_ID=;SYST_ID=;HOSTNAME=$HOSTNAME;SUBSYSTEM_INSTANCE=NO;SUBSYSTEM_TYPE=$2;MW_VERSION=;MW_EDITION=O.S. Not supported;FIXPACK=;INSTANCE_PATH=;DB_NAME=;SCAN_TIME=$SCAN_TIME;SAP_INSTALLED=;SAP_CVERS=;OS_VERSION=$osver;INSTANCE_PORT=;NB_TABLES=;NB_INDEXES=;ALLOC_DB=;USED_DB=;ALLOC_LOG=;USED_LOG=;DB_PART=;TABLE_PART=;INDEX_PART=;SERVER_TYPE=$ostype;DB_TYPE=;DBMS_TYPE=;SDC=;DB_USAGE=;SVC_OFFERED=;HC_REQUIRED=;MW_INST_ID=;MW_MODULE=;MW_NB_EAR=;MW_NB_USERS=;MW_NB_MNDTS=;SW_BUNDLE=;SCANNER_VERSION=$SCANNER_VERSION;" > $1
}

MIF_FIELDS="CUST_ID:12
SYST_ID:8
HOSTNAME:64
SUBSYSTEM_INSTANCE:128
SUBSYSTEM_TYPE:16
MW_VERSION:16
MW_EDITION:64
FIXPACK:80
INSTANCE_PATH:254
DB_NAME:64
SAP_INSTALLED:2
SAP_CVERS:64
OS_VERSION:40
INSTANCE_PORT:64
NB_TABLES:16
NB_INDEXES:16
ALLOC_DB:16
USED_DB:16
ALLOC_LOG:16
USED_LOG:16
DB_PART:16
TABLE_PART:16
INDEX_PART:16
SERVER_TYPE:16
DB_TYPE:16
DBMS_TYPE:512
SDC:16
DB_USAGE:16
SVC_OFFERED:16
HC_REQUIRED:24
MW_INST_ID:24
MW_MODULE:16
MW_NB_EAR:16
MW_NB_USERS:16
MW_NB_MNDTS:16
SW_BUNDLE:16
SCANNER_VERSION:16"

#----------------------------------------------------------------------
# Generating resulting MIF file from log file
#----------------------------------------------------------------------
Create_MIF() {
	# Parameter:
    #  $1 -- MW tag
    #  $2 -- log file
    #  $3 -- MIF file

    set +x
    echo "Generating resulting MIF file"

    _TAG=$1
    _MIF=$3
    echo "START COMPONENT
NAME = \"DB MIF FILE\"
DESCRIPTION = \"Script to automatically list the instances of various subsystems on $UOS servers\"

        START GROUP
                NAME = \"SUBS_${_TAG}_INV\"
                CLASS = \"DMTF|SUBS_${_TAG}_INV|1.0\"" > $_MIF
    echo "$MIF_FIELDS" | awk ' BEGIN {FS=":"; id=1}
{
  print "                START ATTRIBUTE"
  print "                        NAME = \"" $1 "\""
  print "                        ID = " id
  print "                        ACCESS = READ-ONLY"
  print "                        TYPE = STRING(" $2 ")"
  print "                        VALUE = \"\""
  print "                END ATTRIBUTE"
  id++;
}' >> $_MIF
    echo "                KEY = 1
        END GROUP

        START TABLE
        NAME = \"SUBS_${_TAG}_INV\"
        ID = 1
        CLASS = \"DMTF|SUBS_${_TAG}_INV|1.0\"
" >> $_MIF

    IFS=";"

    awk '
BEGIN { ORS="" }
{
  for (i in fields) delete fields[i];
  split($0, tmp, ";");
  for (i in tmp) {
    split(tmp[i], fld, "=");
    fields[fld[1]]=fld[2];
  }
  print "{\""
  print fields["CUST_ID"] "\",\""
  print fields["SYST_ID"] "\",\""
  print fields["HOSTNAME"] "\",\""
  print fields["SUBSYSTEM_INSTANCE"] "\",\""
  print fields["SUBSYSTEM_TYPE"] "\",\""
  print fields["MW_VERSION"] "\",\""
  print fields["MW_EDITION"] "\",\""
  print fields["FIXPACK"] "\",\""
  print fields["INSTANCE_PATH"] "\",\""
  print fields["DB_NAME"] "\",\""
  print fields["SAP_INSTALLED"] "\",\""
  print fields["SAP_CVERS"] "\",\""
  print fields["OS_VERSION"] "\",\""
  print fields["INSTANCE_PORT"] "\",\""
  print fields["NB_TABLES"] "\",\""
  print fields["NB_INDEXES"] "\",\""
  print fields["ALLOC_DB"] "\",\""
  print fields["USED_DB"] "\",\""
  print fields["ALLOC_LOG"] "\",\""
  print fields["USED_LOG"] "\",\""
  print fields["DB_PART"] "\",\""
  print fields["TABLE_PART"] "\",\""
  print fields["INDEX_PART"] "\",\""
  print fields["SERVER_TYPE"] "\",\""
  print fields["DB_TYPE"] "\",\""
  print fields["DBMS_TYPE"] "\",\""
  print fields["SDC"] "\",\""
  print fields["DB_USAGE"] "\",\""
  print fields["SVC_OFFERED"] "\",\""
  print fields["HC_REQUIRED"] "\",\""
  print fields["MW_INST_ID"] "\",\""
  print fields["MW_MODULE"] "\",\""
  print fields["MW_NB_EAR"] "\",\""
  print fields["MW_NB_USERS"] "\",\""
  print fields["MW_NB_MNDTS"] "\",\""
  print fields["SW_BUNDLE"] "\",\""
  print fields["SCANNER_VERSION"]
  print "\"}\n\n"
}
' < $2 >> $_MIF

    myData="     END TABLE:END COMPONENT:"
    echo $myData | tr ':' '\n' >> $_MIF
    Reset_Vars
    [ "$DEBUG_MODE" = "true" ] && set -x
}
#----------------------------------------------------------------------
# Write info to log file
#----------------------------------------------------------------------
Write_Info_To_Log() {
    # Parameters:
    #  $1 -- logfile name

    LOG_FIELDS="COMPUTER_SYS_ID
CUST_ID
SYST_ID
HOSTNAME
SUBSYSTEM_INSTANCE
SUBSYSTEM_TYPE
MW_VERSION
MW_EDITION
FIXPACK
INSTANCE_PATH
DB_NAME
SCAN_TIME
SAP_INSTALLED
SAP_CVERS
OS_VERSION
INSTANCE_PORT
NB_TABLES
NB_INDEXES
ALLOC_DB
USED_DB
ALLOC_LOG
USED_LOG
DB_PART
TABLE_PART
INDEX_PART
SERVER_TYPE
DB_TYPE
DBMS_TYPE
SDC
DB_USAGE
SVC_OFFERED
HC_REQUIRED
MW_INST_ID
MW_MODULE
MW_NB_EAR
MW_NB_USERS
MW_NB_MNDTS
SW_BUNDLE
SCANNER_VERSION"

[ "$DEBUG_MODE" = "true" ] && set -x
    O=""
    # adding gathered data to log file
    for f in $LOG_FIELDS; do
		set +x
        len=`echo "$MIF_FIELDS" | grep $f | cut -f2 -d':'`

        eval "VAR=\${$f}"
        [ -n "$IS_ESX" -a $f = 'SERVER_TYPE' ] && VAR="VMWARE"
        [ -n "$IS_ESX" -a $f = 'OS_VERSION' ] && VAR="$ESX_VERSION"
        [ -n "$IS_VIO" -a $f = 'SERVER_TYPE' ] && VAR="VIO"
        [ -n "$IS_VIO" -a $f = 'OS_VERSION' ] && VAR="$VIO_VERSION"
        if [ -n "$len" ]; then
            VAR=`echo $VAR | cut -c1-$len`
        fi
        O="$O""$f=$VAR;"
    done
    echo $O | sed 's/[[:space:]]*;/;/g'| sed 's/=[[:space:]]*/=/g' >> $1
    [ "$DEBUG_MODE" = "true" ] && Dump_Temp_Files	
   # Reset_Vars  - # if exist place call of Reset_Vars after calling Write_Info_To_Log
	[ "$DEBUG_MODE" = "true" ] && set -x









}

#----------------------------------------------------------------------
# Create new or update existing env. file
#----------------------------------------------------------------------
Create_Or_Update_Env_File() {
    # Parameter:
    #  $1 -- env. file
    #  $2 -- Unique instance id

    [ "$DEBUG_MODE" = "true" ] && set -x

    ENV_FILE=$1
    INSTANCE_ID=$2

    #remove env file if exists
    FLAG=`echo "$ENV_FILE" | grep '*'`
    if [ -f "$ENV_FILE" -a -z "$FLAG" ]; then
        rm "$ENV_FILE"
    fi

    if [ "$ENV_SAVED" = "true" ]; then
		Get_Env_Parameters $1 $2
    else
		ENV_SAVED="true"
		if [ -z "$SW_BUNDLE" ]; then
			SW_BUNDLE=N
		fi 
        #SW_BUNDLE=N

        if [ -z "$INSTANCE_NAME" ]; then
            INSTANCE_NAME="$INSTANCE_ID"
        fi

        # Updating hostname in env. file
        if [ -f /opt/Tivoli/lcf/inv/SCAN/sdist.nfo ]; then
            sdistnfo="/opt/Tivoli/lcf/inv/SCAN/sdist.nfo"
            COMPUTER_SYS_ID=`grep UNIX_SYS_PARAMS.COMPUTER_SYS_ID $sdistnfo | awk -F= '{ print $2 }'| sed 's/^[[:space:]]*//'`
        fi		

		if [ -f /etc/tlmagent.ini ]; then
			agent_version=`cat /etc/tlmagent.ini | grep "agent_version" | grep -v -E "^#" | sed 's/.*[[:space:]]*=[[:space:]]*\([0-9^ ]*\)*/\1/'`
			[ -z "$agent_version" ] && agent_version="0"
			if [ `echo "$agent_version" | cut -f1 -d'.'` -ge 7 ]; then
				SYST_ID=`cat /etc/tlmagent.ini | grep userdata3 | awk -F= '{ print $2 }'| sed 's/^[[:space:]]*//'`
			else
				SYST_ID=`cat /etc/tlmagent.ini | grep userdata1 | awk -F= '{ print $2 }'| sed 's/^[[:space:]]*//'`
			fi
        fi
    fi

    COPY_SERVER_TYPE=$SERVER_TYPE
    COPY_DB_TYPE=$DB_TYPE
    COPY_SDC=$SDC
    COPY_DB_USAGE=$DB_USAGE
    COPY_SVC_OFFERED=$SVC_OFFERED
    COPY_CUST_ID=$CUST_ID
    COPY_DBMS_TYPE=$DBMS_TYPE
    COPY_SYST_ID=$SYST_ID
    COPY_HC_REQUIRED=$HC_REQUIRED
    COPY_COMPUTER_SYS_ID=$COMPUTER_SYS_ID
    COPY_SW_BUNDLE=$SW_BUNDLE
    COPY_HOSTNAME=$HOSTNAME
}

#----------------------------------------------------------------------
# Get parameters from env. file
#----------------------------------------------------------------------
Get_Env_Parameters() {
    # Parameter:
    #  $1 -- env. file
    #  $2 -- Unique instance id

    [ "$DEBUG_MODE" = "true" ] && set -x


    ENV_FILE=$1
    INSTANCE_ID=$2

    if [ "$ENV_SAVED" = "true" ]; then
	SERVER_TYPE=$COPY_SERVER_TYPE
	DB_TYPE=$COPY_DB_TYPE
	SDC=$COPY_SDC
	DB_USAGE=$COPY_DB_USAGE
	SVC_OFFERED=$COPY_SVC_OFFERED
	CUST_ID=$COPY_CUST_ID
	SYST_ID=$COPY_SYST_ID
	HC_REQUIRED=$COPY_HC_REQUIRED
	COMPUTER_SYS_ID=$COPY_COMPUTER_SYS_ID
	SW_BUNDLE=$COPY_SW_BUNDLE
	HOSTNAME=$COPY_HOSTNAME

        if [ -z "$DBMS_TYPE" ]; then
	    DBMS_TYPE=$COPY_DBMS_TYPE
        fi

        if [ -z "$INSTANCE_NAME" ]; then
            INSTANCE_NAME="$INSTANCE_ID"
        fi
    fi
}

#----------------------------------------------------------------------
# Gathereing basic OS information:
# like hostname, os type, os version
# path to temporary files and current path
#----------------------------------------------------------------------
Detect_Host_Parameters() {
    [ "$DEBUG_MODE" = "true" ] && set -x


    HOSTNAME=`hostname`
    TMPSUBDIR=$HOSTNAME
    if [ ! -z "$LCF_INSTANCE" ]; then
        echo "LCF_INSTANCE defined."
        TMPSUBDIR="$TMPSUBDIR$LCF_INSTANCE"
        echo "Using '$TMPSUBDIR' as directory for temporary files"
    fi

    OS=`uname`
    UOS="`uname|tr '[a-z]' '[A-Z]'`"
    SERVER_TYPE=$UOS
    UNAME="`uname -a`"
    IS_ESX=""
    ESX_VERSION=""
    PSARGSWO=""
    IS_VIO=""

    # detecting basic information
    if [ $UOS = 'LINUX' ]; then
        #OS_VERSION=`uname -a|cut -f3 -d" "`
        OS_VERSION=

	# SUSE_SLES, openSLES, 
	which_str=`which yast 2> /dev/null`
	if [ -n "$which_str" ]; then
		OS_VERSION=`cat /etc/products.d/SUSE_SLES.prod 2> /dev/null | awk -F "[><]" '/version/{ if ($2 ~ /^version$/) {print $3}}'`
		OS_NAME=`cat /etc/products.d/SUSE_SLES.prod 2> /dev/null | awk -F "[><]" '/name/{ if ($2 ~ /^name$/) {print $3}}'`
		if [ -z "$OS_VERSION" ]; then
			OS_VERSION=`cat /etc/products.d/openSUSE.prod 2> /dev/null | awk -F "[><]" '/version/{ if ($2 ~ /^version$/) {print $3}}'`
			OS_NAME=`cat /etc/products.d/openSUSE.prod 2> /dev/null | awk -F "[><]" '/name/{ if ($2 ~ /^name$/) {print $3}}'`
		fi
		OS_VERSION=$OS_NAME" $OS_VERSION"
	fi

	# CentOS, RHEL, Oracle Linux, Fedora
	which_str=`which yum 2> /dev/null`
	if [ -n "$which_str" ]; then
		for file in /etc/system-release /etc/centos-release /etc/fedora-release /etc/redhat-release; do
		    if [ -f "$file" ]; then
			OS_NAME=`awk '/ release / {split($0,a," release "); print a[1];};' "$file"`
			OS_VERSION=`awk 'BEGIN{k=0;}/ release / {for (i=0; i<=NF;i++) { if ($i~/release/) {k=i}; if (($i~/[0-9]+/)&&(i>k)) {m=m $i "."; } }; m=substr(m, 1, length(m)-1); print m; };' "$file"`
			OS_VERSION=$OS_NAME" $OS_VERSION"
		    fi
		done
	fi

	# Debian, Ubuntu
	which_str=`which apt-get 2> /dev/null`
	if [ -n "$which_str" ]; then
		OS_VERSION=`cat /etc/os-release 2> /dev/null | awk '/^VERSION_ID=/ {print $0;}' | cut -f2 -d"\""`
		OS_NAME=`cat /etc/os-release 2> /dev/null | awk '/^NAME=/ {print $1;}' | cut -f2 -d"\""`
		# As possibility
		#OS_NAME="U"
		if [ -z "$OS_VERSION" ]; then
			OS_VERSION=`cat /etc/debian_version 2> /dev/null`
			OS_NAME=`cat /etc/issue 2> /dev/null | head -1 | cut -f1 -d" "`
			# As possibility
			#OS_NAME="DEBIAN"
		fi
		OS_VERSION=$OS_NAME" $OS_VERSION"
	fi

	[ -z "$OS_VERSION" ] && OS_VERSION=`uname -a|cut -f3 -d" "`
	
	# remove all possible round brackets in the end of string
	OS_VERSION=`echo "$OS_VERSION" | sed 's/)*$//'`

	#echo "OS_VERSION: $OS_VERSION"

        PSARGS="axo"
        CURRENT_UID=`id -u`
        # check if host is VMWare ESX
        if [ -x /usr/bin/vmware -a ! -L /usr/bin/vmware -a -O /usr/bin/vmware ]; then
            if [ ! -f /etc/SuSE-release -a ! -f /etc/debian_version ]; then
                vmwarev=`/usr/bin/vmware -v`
                if `echo $vmwarev | grep -i ESX > /dev/null 2>&1`; then
                    # ok. seems it vmware esx server. extracting version and set is_esx to true
                    IS_ESX='true'
                    ESX_VERSION=`echo $vmwarev | sed 's/vmware esx //i; s/server //i' | awk '{print $1}'`
                fi
            fi
        fi
    elif [ $UOS = 'AIX' ]; then
	if [ -x /usr/ios/cli/ioscli ]; then
		# VIO
		VIO_VERSION=`/usr/ios/cli/ioscli ioslevel`
		IS_VIO='true'
	else
	        OS_VERSION=`oslevel`
	        is_version=`awk 'BEGIN {if(match("'$OS_VERSION'", "^[0-9]")) {print "yes";}}' < /dev/null`;
	        if [ -z "$is_version" ]; then
	            unamea=`uname -a`
	            OS_VERSION=`echo $unamea | awk '{print $4"."$3}'`;
	        fi
	fi
	OS_BITS=`getconf KERNEL_BITMODE 2> /dev/null`
	[ -z "$OS_BITS" ] && OS_BITS=32
        PSARGS="-ef -o"
        CURRENT_UID=`id -u`
    elif [ $UOS = 'SUNOS' ]; then
        OS_VERSION=`uname -a|cut -f3 -d" "`
		OS_BITS=32
		[ -n "`isainfo -kv | grep '64-bit' 2> /dev/null`" ] && OS_BITS=64
        PSARGS="-ef -o"
        CURRENT_UID=`id | cut -f2 -d"="|cut -f1 -d "("`
        PATH=/usr/xpg4/bin/:$PATH
        #check if zones are supported
        if `pkginfo -q SUNWzoneu`; then
	    ZONENAME=`zonename 2>/dev/null`
	    if [ -z "${ZONENAME}" ]; then
		zonename_exe=`pkgchk -l SUNWzoneu |\
		     sed -e '/^Pathname\:[[:space:]]*.*\/zonename$/ !d' \
		        -e 's/^Pathname\:[[:space:]]*\(\/.*\)/\1/g'`
		if [ -n "$zonename_exe" -a -f "$zonename_exe" -a -x "$zonename_exe" ]; then
		    ZONENAME=`${zonename_exe} 2>/dev/null` 
		fi
	    fi
	    if [ -n "$ZONENAME" ]; then
		#ps -e overrides -z flag
		if `ps -f -o pid,ppid -z "${ZONENAME}" >/dev/null 2>&1`; then
		    PSARGS=" -z ${ZONENAME} -f -o"
		elif `ps -f -o pid,ppid -z global >/dev/null 2>&1`; then
		    PSARGS=" -z global -f -o"
		fi
	    fi
	fi
    elif [ $UOS = 'HP-UX' ]; then
        UNIX95=true
        export UNIX95
        OS_VERSION=`uname -a|cut -f3 -d" "`
        export PS_CMD_BASENAME=255
        _ps_test=`ps -efx 2>&1 | grep "illegal option -- x" | grep -v grep`
        if [ -z "$_ps_test" ]; then
    	    PSARGS="-efx"
    	    ps_x_option=" -x"
    	else
    	    PSARGS="-ef"
    	fi
    	_ps_test=`ps "$PSARGS" -o pid 2>&1 | grep "illegal option -- o" | grep -v grep`
    	if [ -z "$_ps_test" ]; then
    	    PSARGS="$PSARGS -o"
    	else
    	    PSARGSWO="$PSARGS"
    	fi    
        CURRENT_UID=`id -u`
    else
        echo "Unknown OS $UOS detected."
    fi
    CURRENT_DIR=`pwd`
    SCAN_TIME=`date +"%d%m%Y"`
}

#----------------------------------------------------------------------
# Check Temp Dir
#----------------------------------------------------------------------
Check_TEMPDIR(){
    [ "$DEBUG_MODE" = "true" ] && set -x

    for item in $TEMPDIR; do
	for_check=$item
	break
    done

    if [ -z "$for_check" ]; then
	echo "ERROR: unexcpected temporary dir (TEMPDIR) value!"
	[ -f "${SCRIPT_LOG_FILE}" ] && rm "${SCRIPT_LOG_FILE}"
	exit 1
    fi

    for item in / /etc /bin /sbin /dev /usr /root /export /lib /opt /var /boot /home /lib32 /lib64 /proc /run /srv /sys; do
	if [ "$item" = "$for_check" ]; then
            echo "ERROR: unexcpected temporary dir (TEMPDIR) value!"
            [ -f "${SCRIPT_LOG_FILE}" ] && rm "${SCRIPT_LOG_FILE}"
	    exit 1
        fi
    done
}

#----------------------------------------------------------------------
# Creates temporary dir for temp. files
# should set variable TEMPDIR to some location
#----------------------------------------------------------------------
Create_Temporary_Dir() {
    # Parameters:
    #  $1 - SUBSYSTEM_TYPE
    [ "$DEBUG_MODE" = "true" ] && set -x

    #IFS=" \t\n"
    IFS=' 	
'

    tmp_location="$TMP"
    if [ -z "${tmp_location}" ]; then
        tmp_location="${CSTMPDIR}"
    fi
    if [ -z "${tmp_location}" ]; then
        tmp_location="/tmp"
    fi

    # creating required dir for temporary files
    Create_Temporary_Dir_umask=`umask`
    umask 022
    mkdir -p "${tmp_location}/cscans/$1/${TMPSUBDIR}" > /dev/null 2>&1
    case $UOS in
	SUNOS|LINUX)
		#if `which mktemp > /dev/null 2>&1`; then
		if [ -x "`which mktemp 2>&1`" ]; then
			TEMPDIR=`mktemp -p "${tmp_location}/cscans/$1/${TMPSUBDIR}" -d`
			[ ! -d "$TEMPDIR" ] && TEMPDIR=''
		fi
	;;
	HP-UX) TEMPDIR=`mktemp -d "${tmp_location}/cscans/$1/${TMPSUBDIR}" 2>/dev/null`
		if [ -n "${TEMPDIR}" ]; then
			mkdir -p "${TEMPDIR}" > /dev/null 2>&1
		fi
	;;
	AIX) TEMPDIR="${tmp_location}/cscans/$1/${TMPSUBDIR}/tmp.${$}-`od -N4 -tx /dev/random | awk 'NR==1 {print $2}'`"
		if [ "${TEMPDIR}" != "${tmp_location}/cscans/$1/${TMPSUBDIR}/tmp.$$-" ]; then
			mkdir -p "${TEMPDIR}" > /dev/null 2>&1
		else
			TEMPDIR=''
		fi
    esac
    if [ -z "${TEMPDIR}" -o ! -d "$TEMPDIR" ]; then
	TEMPDIR="${tmp_location}/cscans/$1/${TMPSUBDIR}/$$"
	mkdir -p "${TEMPDIR}" > /dev/null 2>&1
    fi
	

    Check_TEMPDIR

    umask $Create_Temporary_Dir_umask
    [ -d "${tmp_location}/cscans" ] && chmod 755 "${tmp_location}/cscans"
    [ -d "${tmp_location}/cscans/$1" ] 	&& chmod 755 "${tmp_location}/cscans/$1"
    [ -d "${tmp_location}/cscans/$1/${TMPSUBDIR}" ] && chmod 755 "${tmp_location}/cscans/$1/${TMPSUBDIR}"
    [ -d "${TEMPDIR}" ] && chmod 755 "${TEMPDIR}"
#    info_echo "`ls -ld ${TEMPDIR}`"
    # cleaning this dir
    [ -n "${TEMPDIR}" -a -d "$TEMPDIR" ] && rm -r "${TEMPDIR}/*" > /dev/null 2>&1
}

#----------------------------------------------------------------------
# dump all files in temp dir, created during scanning, to stderr
# temp dir tarred gzipped and uuencoded.
#----------------------------------------------------------------------
Dump_Temp_Files() {
    [ "$DEBUG_MODE" != "true" ] && return
   

    Check_TEMPDIR

    Dump_Temp_Files_umask=`umask`
    umask 066

    if [ -x "`which uuencode 2>&1`" ]; then
        dumpname=`date +"%d%m%Y_%H%M%S"`
        set +x
        echo ">>> DUMP STARTS" 1>&2
	if [ "$UOS" = "HP-UX" ]; then
            find $TEMPDIR  -name '*' -type f -print 2> /dev/null | grep -v swlist 2> /dev/null | xargs tar cf - 2> /dev/null |  gzip | uuencode ${dumpname}.tar.gz 1>&2
        	#tar cf - $TEMPDIR 2> /dev/null | gzip | uuencode ${dumpname}.tar.gz 1>&2
	else
        	tar cf - $TEMPDIR 2> /dev/null | gzip | uuencode -m ${dumpname}.tar.gz 1>&2
	fi
        echo ">>> DUMP ENDS" 1>&2
        set -x
    else
        echo "No uuencode found."
    fi
    umask $Dump_Temp_Files_umask
}

#----------------------------------------------------------------------
# Clean directory with temporary files
# should set variable TEMPDIR to some location
#----------------------------------------------------------------------
Clean_Temporary_Dir() {
    [ "$DEBUG_MODE" = "true" ] && set -x

    Check_TEMPDIR
    rm -r "$TEMPDIR" > /dev/null 2>&1
}
#----------------------------------------------------------------------
# Dedug functions
#----------------------------------------------------------------------
escape_debug() {
set +x
echo "$@" | sed -e 's/%/%%/g' -e 's#\\#\\\\#g'
[ "$DEBUG_MODE" = "true" ] && set -x
}

debug_printf() {
set +x
[ "$DEBUG_MODE" = "true" -o "$DEBUG_MESSAGES" = "true" ] && printf "$@"
[ "$DEBUG_MODE" = "true" ] && set -x
}

info_printf() {
set +x
debug_printf "I: $@"
[ "$DEBUG_MODE" = "true" ] && set -x
}

info_echo() {
set +x
info_printf "`escape_debug ${@}`""\n"
[ "$DEBUG_MODE" = "true" ] && set -x
}

warning_printf() {
set +x
debug_printf "W: $@"
[ "$DEBUG_MODE" = "true" ] && set -x
}

error_printf() {
set +x
debug_printf "E: $@"
[ "$DEBUG_MODE" = "true" ] && set -x
}

debug_start_func() {
set +x
info_printf "********** %-30s **********\n" "$1"
[ "$DEBUG_MODE" = "true" ] && set -x
}

debug_end_func() {
set +x
info_printf "---------- %-30s ----------\n" "$1"
[ "$DEBUG_MODE" = "true" ] && set -x
}



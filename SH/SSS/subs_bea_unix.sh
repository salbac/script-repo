#!/bin/sh

###############################################################################
CVSID='$Id: subs_bea_unix.sh,v 1.40 2014/07/10 08:59:59 cvsmaksim Exp $'
###############################################################################
# weblogic server
Version="26.00"
PLATFORMS="AIX LINUX SUNOS HP-UX"
# 28.08.2009    KK    First draft version of scanner
# 02.09.2009    KK    Different mods in regexp and ps
# 03.09.2009    KK    Different mods in folder locations
# 07.09.2009    MD    SunOS support, xml parser, and nice code corrections
# 08.09.2009    KK    Added port value
# 10.09.2009    KK    Updates from original unix template
# 10.09.2009    KK    Corrected inventory entry
# 10.09.2009    MD    Xml corrections in cmd
# 16.09.2009    KK    Small version change and corrections in port
# 16.09.2009    MD    Corrections in port
# 17.09.2009    KK    INSTANCE_NAME and MIF filename correction
# 01/10/09 - SC - extract osversion from uname output if oslevel fails
# 20/10/09 - SC - PHASE 12 started
# 2010-02-15 - MD - restrict java processes to process leaders
# 25/03/10 - SC - PHASE 13 started
# 19/04/10 - SC - Added set +u
# 2010-05-31 - MD - fix cosmetic error in process selection
# 01/02/11 - SC - Added exec < /dev/null
# 14/02/11 - SC - Report VMWARE as SERVER_TYPE and VMWARE version as OS_VERSION
#                 if started on ESX host.
# 22/02/11 - SC - Fixed ESX host detection
# 16/05/11 - KK - Version changed (new wave)
# 09/06/11 - KK - MW_VERSION is 0.0.0 by default (155054)
# 31/01/12 - US - PHASE 16
# 02/05/12 - US - Env file removed
# 14/08/12 - US - Env file is deleted if exists
# 04/10/12 - US - Solaris zones support is added; umask is used for Temp dirs
# 04/10/12 - DK - Implemented [36403] - Symbolic links for java executable
# 14/02/13 - US - Env file is removed from ${INSTANCE_PATH}
# 04/07/13 - US - userdata1/userdata3 [#63918]
# 06/08/13 - US - protection for "rm" command is added
# 07/08/13 - DF - wrap up path with "" and  check if directory exists before chmod 755 command
# 09/08/13 - US - temporary files are deleted completely
# 25/09/13 - US - `which mktemp` for SUNOUS/LINUX
# 26/09/13 - US - chmod for ${TMPSUBDIR} is added
# 19/12/13 - DF - Added ps -ef output in debug mode
# 14/02/14 - DF - Common functions moved into shared library script
# 19/02/15 - US - PHASE 24
# 28/05/15 - US - PHASE 25
# 29/05/15 - US - Show_PS_Output function call is added
##############################################################################

#######################################################
# SCANNING ROUTINES. PLACE YOUR CODE HERE.
#######################################################

Scan_Running_Instances() {
    # code for detecting running instances goes here
    # we need to assign variable RUNNING_INSTANCE to
    # list of discovered instances.

    Show_PS_Output

#    RUNNING_INSTANCES=`ps $PSARGS pid,ppid,comm | awk '
#{
#    if($3 ~ /(^|\/)java$/) { pidlist=pidlist "|" $1; parents[$1]=$2; }
#}
#END {
#  pidlist=substr(pidlist, 2)
#  for (pid in parents) {
#     if (parents[pid] !~ "^(" pidlist ")$") print pid;
#  }
#}
#' | sort -u`

    if [ "$UOS" = 'SUNOS' ]; then
        Scan_Running_Instances_umask=`umask`
        umask 066

        ps $PSARGS pid,ppid |
        awk '{print $1,$2 }'> "${TEMPDIR}/pids.txt" 

        /usr/ucb/ps agxwww |
        awk '{$2=$3=$4="";print}' >\
            "${TEMPDIR}/ps_out.txt" 

        awk 'FNR==NR{a[$1]=$2; next}(a[$1]){ print a[$1], $0}'\
            "${TEMPDIR}/pids.txt" "${TEMPDIR}/ps_out.txt" >\
            "${TEMPDIR}/process_list.txt"
        #cat "${TEMPDIR}/process_list.txt" 

        RUNNING_INSTANCES=`cat "${TEMPDIR}/process_list.txt" | awk '
        {
            if(($3 ~ /(^|\/)java$/) ||\
              ($NF == "weblogic.Server") ||\
              ($0 ~ /[[:space:]]+-Dweblogic\.Name=/)) { pidlist=pidlist "|" $2; parents[$2]=$1; }
        }
        END {
          pidlist=substr(pidlist, 2)
          for (pid in parents) {
         if (parents[pid] !~ "^(" pidlist ")$") print pid;
          }
        }
        ' | sort -u`
        umask $Scan_Running_Instances_umask
    elif [ -z "$PSARGSWO" ]; then
        RUNNING_INSTANCES=`ps $PSARGS pid,ppid,args | awk '
	{
	    if(($3 ~ /(^|\/)java$/) ||\
              ($NF == "weblogic.Server") ||\
              ($0 ~ /[[:space:]]+-Dweblogic\.Name=/)) { pidlist=pidlist "|" $1; parents[$1]=$2; }
	}
	END {
	  pidlist=substr(pidlist, 2)
	  for (pid in parents) {
	 if (parents[pid] !~ "^(" pidlist ")$") print pid;
	  }
	}
	' | sort -u`
    else
	#HP-UX only
        RUNNING_INSTANCES=`ps $PSARGSWO | awk '
	{ 
	    if($($5~/:/?8:9) ~ /(^|\/)java[[:space:]]+/)||\
              ($NF == "weblogic.Server") ||\
              ($0 ~ /[[:space:]]+-Dweblogic\.Name=/)) { pidlist=pidlist "|" $2; parents[$2]=$3; }
	}
	END {
	  pidlist=substr(pidlist, 2)
	  for (pid in parents) {
	 if (parents[pid] !~ "^(" pidlist ")$") print pid;
	  }
	}
	' | sort -u`
    fi  
}

Scan_Loop_Dir() {
    (
#        oldIFS="$IFS"
        IFS=:
        ls -1 $1 2>/dev/null | while read i; do
            _pid=`fuser $i 2>/dev/null`
            (
        IFS=' 	
'
                for j in $_pid; do
                    if [ "$j" = "$2" ]; then
                        echo "$i"
                    fi
                done
            )
        done
    )
}

# poor man's xml parser
# CAUTION: these are no complete, all-purpose XML parsers. They just
# reformat XML files to allow them to be parsed with shell tools.
# Both will fail on CDATA sections.
# parse_xml will replace newlines by spaces in text nodes
# parse_xml_attr will report only attributes with values enclosed in double
# quotes
# Both should be sufficient to handle Weblogic's config.xml file.
parse_xml() {
    grep -v '^.?xml' $1 | tr -d '\015' | tr '\012' ' ' |\
    tr '<' '\012' | tr '>' '\012' |\
    awk 'BEGIN{n=0}/^!--/{n=2}(n==0){print}(n==1){n=0}(/--$/){n=1}' |\
    awk '
BEGIN{lv=0}
(NR%2==0){
  if($0~/^\//){lv--};
  if($0~/^[^\/]/){a[lv]=$1;lv++};
  if($0~/\/$/){lv--};
}
(NR%2==1){
  for(i=0;i<lv;i++){printf("%s/", a[i])};
  printf(">%s\n", $0);
}'
}

parse_xml_attr() {
    _s=`printf " \t"`
    grep -v '^.?xml' $1 | tr -d '\015' | tr '\012' ' ' |\
    tr '<' '\012' | tr '>' '\012' |\
    awk 'BEGIN{n=0}/^!--/{n=2}(n==0){print}(n==1){n=0}(/--$/){n=1}' |\
    awk '
BEGIN{lv=0}
(NR%2==0){
  if($0~/^\//){lv--};
  if($0~/^[^\/]/){a[lv]=$1;lv++};
  for(i=0;i<lv;i++){printf("%s/", a[i])};
  if($0~/\/$/){lv--};
  printf(">>\n%s\n", $0);
}' | tr '"' '\012' |\
  awk -F\> '
NF==3{print; p=NR}
NF==1{printf("%s", $1); if ((NR-p)%2==1){printf(">")}; printf("\n")}' |\
    sed 's#^.*['"${_s}"']\([^'"${_s}"']*\)=>$#\1>#'|\
  awk -F\> '
NF==3{t=$1}
NF==2{k=$1}
NF==1{printf("%s@%s>%s\n", t, k, $1)}'
}

Readlink() {
     # $1  - symlink
    [ "$DEBUG_MODE" = "true" ] && set -x
    READLINK=`which readlink 2>/dev/null`
    if [ -n "$READLINK" -a -x "$READLINK" ]; then
        readlink -ne "$1"
        return 0
    fi
    file="$1"
    s=`ls -ld $file`
    [ $? -ne 0 ] && return 1
    i=0
    while [ $i -lt 10 ] && ( echo "$s" | grep '^l' >/dev/null ); do
        i=`expr $i + 1`
        link=`echo "$s"|sed 's/^.*-> //'`
        if echo "$link" | grep '^/' >/dev/null; then
            file="$link"
        else
            file=`dirname "$file"`/"$link"
        fi
        s=`ls -ld $_num $file`
        [ $? -ne 0 ] && return 1
    done
    if  echo "$s" | grep '^l' >/dev/null; then
        # possible link loop... or more than 10 chained links
        return 1
    else
        echo "$s" | awk '{print $NF}'
    fi
}

Scan_Instance() {
    # Parameters:
    #  $1 -- instance to scan
    [ "$DEBUG_MODE" = "true" ] && set -x

    SUBSYSTEM_TYPE='BEA'

    _args=""

#    if [ "$UOS" = "SUNOS" ]; then
#        _args=`pargs $1 | awk 'NR>1' | sed 's/^[^ ][^ ]*  *//'`
#
#        if [ $? -ne 0 ]; then
#            _args=`/usr/ucb/ps -axwww $1 | awk 'NR==2' | sed 's/^ *[^ ][^ ]*  *[^ ][^ ]*  *[^ ][^ ]*  *[^ ][^ ]*  *//' | tr ' ' '\012'`
#        fi
#    else
#        if [ -f "/proc/$1/cmdline" ]; then
#            _args=`tr '\000' '\012' < /proc/$1/cmdline`
#        else
#            _args=`ps -f -p $1 | awk 'NR==2{for (i=($5~/:/?8:9); i<=NF; i++){print $i}}'`
#        fi
#    fi

    if [ "$UOS" = "SUNOS" ]; then
	_args=`awk '($2=='"$1"'){for (i=3; i<=NF; i++){print $i}}' "$TEMPDIR/process_list.txt"` 
    else
        if [ -f "/proc/$1/cmdline" ]; then
            _args=`tr '\000' '\012' < /proc/$1/cmdline`
        else
	    #_args=`ps -f -p $1 | awk 'NR==2{for (i=($5~/:/?8:9); i<=NF; i++){print $i}}'`
            _args=`ps $ps_x_option -f -p $1 | awk 'NR==2{for (i=($5~/:/?8:9); i<=NF; i++){print $i}}'`
        fi
    fi

    if [ -z "$_args" ]; then
        return 0
    fi
   
    _exe="`Readlink \"\`echo \\"${_args}\\" | awk ' (NR==1) {print $1}'\`\" | awk '/(^|\/)java$/ {print $0}'`"
    [ -z "${_exe}" ] && return 0

    _args=`echo "$_args" | awk 'BEGIN{sk=1}/^-classpath/ || /^-cp/{sk=2}{if (sk==0){print}else{sk--}}'`

    _root=`echo "$_args" | awk -F= '$1=="-Dweblogic.RootDirectory"{print $2}'`

    if [ ! -d "$_root" ]; then
        _root=''
    fi

    _jclass=`echo "$_args" | grep '^[^-/][^/]*\.[^/]*' | head -1`
    if [ `echo "$_jclass" |\
        awk '{print index("weblogic.Server", $0)}'` -ne 1 ]; then
        return 0
    fi

    _platform_home=`echo "$_args" | awk -F= '$1=="-Dplatform.home"{print $2}'`
    [ ! -d "$_platform_home" ] && _platform_home=''

    _weblogic_home=`echo "$_args" | awk -F= '$1=="-Dweblogic.home"{print $2}'`
    [ ! -d "$_weblogic_home" ] && _weblogic_home=''

    _wls_home=`echo "$_args" | awk -F= '$1=="-Dwls.home"{print $2}'`
    [ ! -d "$_wls_home" ] && _wls_home=''

    _domain=`echo "$_args" | awk -F= '$1=="-Dweblogic.Domain"{print $2}'`

    _name=`echo "$_args" | awk -F= '$1=="-Dweblogic.Name"{print $2}'`

scan_lock_files(){
    #  $1 -- pid
    #  $2 -- domain
    #  $3 -- name
    #  $4 -- cwd
    _cwd="${4}"
    [ "$DEBUG_MODE" = "true" ] && set -x
    _dm="${2}"
     if [ -z "$_dm" ]; then
        _dm='*'
     fi
    _nm="${3}"
     if [ -z "$_nm" ]; then
        _nm='*'
     fi
     _lockfiles="\
${_cwd}/servers/${_nm}/tmp/${_nm}.lok:\
${_cwd}/${_nm}/ldap/ldapfiles/EmbeddedLDAP.lok:\
${_cwd}/servers/${_nm}/data/ldap/ldapfiles/EmbeddedLDAP.lok:\
${_cwd}/config/${_dm}/${_nm}/ldap/ldapfiles/EmbeddedLDAP.lok"

        # using awk 'NR==1' to select only the first line. "head -1"
        # terminates after the first line, which generates "Broken Pipe"
        # errors if more lines are expected.
        r=`Scan_Loop_Dir "$_lockfiles" $1 | awk 'NR==1'`

        if [ ! -z "$r" ]; then
            if echo "$r" |\
                grep '^'"${_cwd}"'/config/[^/]*/[^/]*/ldap' >/dev/null; then
                _root=`echo "$r" | sed 's:^\('"${_cwd}"'/config/[^/]*\)/.*$:\1:'`
                if [ -z "$_domain" ]; then
                    _domain=`basename "$_root"`
                fi
            else
                _root="$_cwd"
            fi
            r=`echo "$r" | sed 's:^'"${_root}"'/::'`
            if [ -z "$_name" ]; then
                if echo "$r" | grep '^servers/[^/]*/tmp/' >/dev/null; then
                    _name=`echo "$r" | sed 's:^servers/\([^/]*\)/.*$:\1:'`
                elif echo "$r" | grep '^servers/[^/]*/data/' >/dev/null; then
                    _name=`echo "$r" | sed 's:^servers/\([^/]*\)/.*$:\1:'`
                elif echo "$r" | grep '^[^/]*/ldap/' >/dev/null; then
                    _name=`echo "$r" | sed 's:^\([^/]*\)/.*$:\1:'`
                fi
            fi
            return 0
        else
            return 1
        fi
}

    if [ -z "$_domain" ] || [ -z "$_name" ] || [ -z "$_root" ]; then
        _cwd=''
        if [ "$UOS" = "SUNOS" ]; then
            _cwd=`pwdx $1 | tr '\011' ' ' | sed 's/^[^ ][^ ]*  *//'`
            if [ -z "$_cwd" ]; then
                return 0
            fi
            scan_lock_files "$1" "${_domain}" "${_name}" "${_cwd}"
            [ $? -ne 0 ] && return 0
        elif [ "$UOS" = "HP-UX" ]; then
            for _mw_dir in "$_platform_home" "$_weblogic_home" "$_wls_home"; do
                if [ -n "$_mw_dir" ]; then
                    _mw_home=`dirname "$_mw_dir"`
                    if [ -f "${_mw_home}/domain-registry.xml" ]; then
                         break;
                    fi
                    _mw_home=`dirname "$_mw_home"`
                    if [ -f "${_mw_home}/domain-registry.xml" ]; then
                         break;
                    else
                        _mw_home=''
                    fi
                fi
            done
            if [ -n "$_mw_home" ]; then
                for _domain_dir in `parse_xml_attr "${_mw_home}/domain-registry.xml" |\
                         awk -F\> '$1=="domain-registry/domain/@location"{print $2}'`; do
                          scan_lock_files "$1" "${_domain}" "${_name}" "${_domain_dir}"
                          [ $? -eq 0 ] && break
                done
            fi
        else
            _cwd=`ls -l /proc/$1/cwd | sed 's/^.*-> //' | sed 's#/$##'`
            if [ -z "$_cwd" ]; then
                return 0
            fi
            scan_lock_files "$1" "${_domain}" "${_name}" "${_cwd}"
            [ $? -ne 0 ] && return 0
        fi
    fi

    if [ ! -d "$_root" ]; then
        return 0
    fi

    _cpath="$_root/config.xml"
    _version=""

    if [ ! -f "$_cpath" ]; then
        _cpath="$_root/config/config.xml"
    fi

    if [ -f "$_cpath" ]; then
        # last chance to set the domain name
        # version 8
        if [ -z "$_domain" ]; then
            _domain=`parse_xml_attr "$_cpath" |\
                awk -F\> '$1=="Domain/@Name"{print $2}'`
        fi
        # version 9+10
        if [ -z "$_domain" ]; then
            _domain=`parse_xml "$_cpath" |\
                awk -F\> '$1=="domain/name/"{print $2}'`
        fi

        # set version
        # version 8
        _version=`parse_xml_attr "$_cpath" |\
            awk -F\> '$1=="Domain/@ConfigurationVersion"{print $2}'`
        # version 9+10
        if [ -z "$_version" ]; then
            _version=`parse_xml "$_cpath" |\
                awk -F\> '$1=="domain/domain-version/"{print $2}'`
        fi

        # port for version 8
        _port=`parse_xml_attr "$_cpath" |\
             awk -F\> '$1=="Domain/Server/@Name" {s=$2}
                  $1=="Domain/Server/@ListenPort" {p=$2}
                  $1~/^Domain\/Server\/[^@]/ && s=="'"${_name}"'" {print p; exit}'`

        if [ -z "$_port" ]; then
            # port value for versions 9+10
            _port=`parse_xml "$_cpath" |\
                awk -F\> '$1=="domain/server/name/" {s=$2}
                  $1=="domain/server/listen-port/" {p=$2}
                  $1=="domain/" && s=="'"${_name}"'" {print p; exit}'`
        fi

        if [ -z "$_port" ]; then
            # check properties file for the port
            _prop_path="${_root}/init-info/tokenValue.properties"

            if [ -f "$_prop_path" ]; then
                _port=`awk -F= '$1=="@SERVER_PORT"{print $2}' $_prop_path`
            fi
        fi
    else
        return 0
    fi

    if [ -z "$_version" ]; then
        _version="0.0.0"
    fi

#   echo "$_platform_home" >> bea_home
#   echo "$_weblogic_home" >> bea_home
#   echo "$_wls_home" >> bea_home

    MW_VERSION="$_version"
    MW_EDITION="BEA Weblogic"
    INSTANCE_PATH="$_root"
    INSTANCE_PORT="$_port"
    SUBSYSTEM_INSTANCE="$_domain/$_name"

    INSTANCE_NAME="$SUBSYSTEM_INSTANCE"

    if [ -d "$INSTANCE_PATH" ]; then
        Create_Or_Update_Env_File "${INSTANCE_PATH}/.subscan_inventory_bea" "$INSTANCE_NAME"
    else
        Create_Or_Update_Env_File "/etc/cs/.subscan_inventory_bea" "$INSTANCE_NAME"
    fi

    Write_Info_To_Log "${SCRIPT_LOG_FILE}"
	Reset_Vars
}

#######################################################
# MAIN PART
#######################################################

echo "***********************************************"
echo "COLLECTING INFORMATION OF THE BOX (ver. $Version)"
[ "$DEBUG_MODE" = "true" ] && echo $CVSID
echo "***********************************************"

SCRIPT_LOG_FILE=subs.bea.log
SCRIPT_MIF_FILE=SUBS_BEA_INV.mif
SCRIPT_SUBSYSTEM_TYPE=BEA
COMMON_FUNC_SHARED_LIB=common_subs_func.sh

if [ -n "$SUBS_HOME" ]; then
  if [ -f "$SUBS_HOME/${COMMON_FUNC_SHARED_LIB}" ] ; then
    . "$SUBS_HOME/${COMMON_FUNC_SHARED_LIB}"
  else
    echo "Shared library file: ${COMMON_FUNC_SHARED_LIB} not found!"
    exit 0
  fi	
else
  if [ -f "${COMMON_FUNC_SHARED_LIB}" ] ; then
    . ./${COMMON_FUNC_SHARED_LIB}
  else
    echo "Shared library file: ${COMMON_FUNC_SHARED_LIB} not found!"
    exit 0
  fi	
fi

Detect_Host_Parameters

if [ $CURRENT_UID -ne 0 ]; then
    echo "Script should be executed with root privileges."
    exit 0
fi

if `echo $PLATFORMS | grep $UOS > /dev/null`; then
    Create_Temporary_Dir ${SCRIPT_SUBSYSTEM_TYPE}
    rm ${SCRIPT_LOG_FILE} 2> /dev/null
#    rm bea_home 2> /dev/null

    Scan_Running_Instances
    if [ ! -z "$RUNNING_INSTANCES" ]; then
        for INSTANCE in $RUNNING_INSTANCES; do
            Scan_Instance "$INSTANCE"
        done
    fi

    if [ ! -f "${SCRIPT_LOG_FILE}" ]; then
        Create_Empty_Log ${SCRIPT_LOG_FILE} ${SCRIPT_SUBSYSTEM_TYPE}
		[ "$DEBUG_MODE" = "true" ] && Dump_Temp_Files
    fi
    Clean_Temporary_Dir
else
    Create_NotSupported_Log ${SCRIPT_LOG_FILE} ${SCRIPT_SUBSYSTEM_TYPE}
fi

Create_MIF ${SCRIPT_SUBSYSTEM_TYPE} ${SCRIPT_LOG_FILE} ${SCRIPT_MIF_FILE} 

exit 0

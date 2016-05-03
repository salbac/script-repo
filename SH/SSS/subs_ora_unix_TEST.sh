#!/bin/sh

set -a

###############################################################################
CVSID='$Id: subs_ora_unix.sh,v 1.75 2014/10/23 10:32:11 cvsdzmitry Exp $'
###############################################################################
# DB scanners
Version="27.00"
PLATFORMS="AIX LINUX HP-UX SUNOS"
# 27/05/09 - SC - Using other way for finding oracle_home
# 28/05/09 - SC - Renamed ORACLE to ORA everywhere.
#                 Removed debug output. Converted output to GB. Detecting Oracle
#                 using _pmon_ processes instead of _smon_
# 29/05/09 - PB - Using find instead of ncheck (ncheck out of core)
# 31/05/09 - PB - Using  proc/../cwd for Oracle_home
# 04/06/09 - SC - GB -> MB
# 04/06/09 - PB - Removed CONNECT_STR
# 08/06/09 - SC - SUBSYSTEM_TYPE = ORA
# 26/06/09 - PB - Chnanged to V10
# 02/07/09 - PB - Shorted FIXPACK
# 10/07/09 - SC - Workaround for csh
# 16/07/09 - SC - Update INSTANCE_NAME, removed setting of DB_TYPE
# 20/07/09 - PB - Added check ORAVERS using SQLPLUS version and skip DM
# 22/07/09 - PB - Added check for ORACLE_HOME if on SYM-link (idle instance)
# 11/08/09 - SC - Changed check for ORAVERS
# 25/08/09 - SC - Updated version for phase 11
# 01/09/09 - SC - Added PLATFORMS checking
# 24/09/09 - SC - Added changes proposed by PvB
# 25/09/09 - SC - Small fixes for version checking
# 01/10/09 - SC - extract osversion from uname output if oslevel fails
# 20/10/09 - SC - PHASE 12 started
# 19/03/10 - SC - Scan only ora_pmon_ processes
# 25/03/10 - SC - PHASE 13 started
# 05/04/10 - SC - Updated Get_Exe_By_Pid
# 16/04/10 - SC - Adapted changed to Get_Exe_By_Pid from PvB
# 19/04/10 - SC - Added set +u
# 06/05/10 - SC - Several small fixes
# 09.08.10 - SC - Fixed typo LD_LIBRAR_PATH -> LD_LIBRARY_PATH
# 01/02/11 - SC - Added exec < /dev/null
# 14/02/11 - SC - Report VMWARE as SERVER_TYPE and VMWARE version as OS_VERSION
#                 if started on ESX host.
# 22/02/11 - SC - Fixed ESX host detection
# 16/05/11 - KK - LENGTH Control required for all FIELDS (119004)
# 06/06/11 - KK - Inventory file moved to the /etc/cs folder (127987)
# 09/06/11 - KK - MW_EDITION field checked once again after the main scan (160892)
# 13/06/11 - KK - ORAEDIT is UNKNOWN by default
# 28/07/11 - DK - Better discovery of TNS_ADMIN
# 31/01/12 - US - PHASE 16
# 02/05/12 - US - Env file removed
# 14/08/12 - US - Env file is deleted if exists
# 08/10/12 - US - Solaris zones support is added; umask is used for Temp dirs
# 14/02/13 - US - Env file is removed from ${INSTANCE_PATH}
# 13/05/13 - US - The script was not detecting the instance name with underscore
# 23/05/13 - US - Symlynk in ORACLE_HOME workaround
# 27/06/13 - US - output for "SAP_INSTALLED"="Y" condition is added
# 10/07/13 - US - userdata1/userdata3 [#63918]
# 16/07/13 - DK - WPAR support via clogin is added, improvements in port and edition detection
# 19/07/12 - DK - Fixed umask variable names
# 06/08/13 - US - protection for "rm" command is added
# 07/08/13 - DF - wrap up path with "" and  check if directory exists before chmod 755 command
# 29/08/13 - US - typo: "2 >/dev/null" -----> "2> /dev/null"
# 25/09/13 - US - `which mktemp` for SUNOUS/LINUX
# 26/09/13 - US - chmod for ${TMPSUBDIR} is added
# 30/10/13 - US - ora_for_sap.tmp temporary file is created for SAP scanner
# 19/12/13 - DF - Added ps -ef output in debug mode
# 14/02/14 - DF - Common functions moved into shared library script
# 28/02/14 - US - switch DB_NAME and SUBSYSTEM_INSTANCE for SAP
# 17/06/14 - US - "which tac" -x check
# 23/10/14 - VM - Fix unnecessary data in ORAEDIT detection
# 19/02/15 - US - PHASE 24
# 28/05/15 - US - PHASE 25
# 29/05/15 - US - Show_PS_Output function call is added
##############################################################################

SetEnvParameter(){
    ENV_FILE=$1;
    INSTANCE_ID=$2;
    PARAM_NAME=$3;
    PARAM_VALUE=$4;

    if [ -f "$ENV_FILE" ]; then
        awk -v INSTANCE="$INSTANCE_ID" -v PMTR="$PARAM_NAME" -v VALUE="$PARAM_VALUE" '
BEGIN {process=0; IFS = "="; instance_found=0; parameter_found=0;}
/^[ \t]*#/ {print;next}
/^[ \t]*\[/ {
    ere="\\[" INSTANCE "\\]"
    if (match($0, ere)) {
        process=1;
        instance_found=1;
     } else {
        if (process == 1 && parameter_found == 0) {
            print PMTR "=" VALUE;
        }
        process=0;
        parameter_found=0;
     }
     print
     next;
}
{
    if (process == 1) {
        ere="^[ \t]*" PMTR "="
        if (match($0, ere)) { print PMTR "=" VALUE; parameter_found=1; next }
    }
    print;
}

END {
    if (instance_found == 0) {
       print "[" INSTANCE "]"
       print PMTR "=" VALUE
    } else {
        if (process == 1 && parameter_found == 0) {
            print PMTR "=" VALUE;
        }
    }
}' < $ENV_FILE > $TEMPDIR/TEMPFILE && mv $TEMPDIR/TEMPFILE $ENV_FILE;
    else
        echo "[$INSTANCE_ID]" > $ENV_FILE
        echo "$PARAM_NAME=$PARAM_VALUE" >> $ENV_FILE
    fi
}


# Get value of specific env variable for specific pid
# Parameters:
#   $1 - pid
#   $2 - env var name
Get_Env_Var_For_Pid() {
    [ "$DEBUG_MODE" = "true" ] && set -x
    get_proc_env() {
        [ "$DEBUG_MODE" = "true" ] && set -x
        # get process environment using the BSD flavour of "ps"
        # you must be root to get this information
        _len=`case $UOS in
            AIX)     ps www $1;;
            LINUX)   ps wwwp $1;;
            SUNOS)   /usr/ucb/ps -www $1;;
        esac | awk 'NR==2 {print length()}'`
        _fs=`printf "\034"`
        case $UOS in
            AIX)     ps wwwe $1;;
            LINUX)   ps wwwep $1;;
            SUNOS)   /usr/ucb/ps -wwwe $1;;
        esac | awk 'NR==2 {print substr($0, '"${_len}"'+1)}'  | \
          sed 's/^ *//' |\
          sed 's/ \([^ ]*=\)/'"${_fs}"'\1/g' | tr "${_fs}" '\n'
    }

    if [ ! -s "$TEMPDIR/ENV_FOR_PID_$1" ]; then
	Get_Env_Var_For_Pid_umask=`umask`
	umask 066
        get_proc_env $1 > $TEMPDIR/ENV_FOR_PID_$1
	umask "$Get_Env_Var_For_Pid_umask"
    fi
    if [ -s "$TEMPDIR/ENV_FOR_PID_$1" ]; then
        head_lines=`wc -l $TEMPDIR/ENV_FOR_PID_$1 | awk '{print $0-1}'`
        cat $TEMPDIR/ENV_FOR_PID_$1 | head -n $head_lines | awk -F= "\$1==\"$2\" {print \$2}"
    fi
}

# chroot-based virtualisation solutions (like AIX WPARs) run processes in a chroot,
# so the information from the process environment (LD_LIBRARY_PATH, procldd)
# is relative to the chroot path, and not to "/" .
# For AIX WPARS, this functions checks if a process runs in a WPAR and adds
# the chroot path to the second argument (or to every element if that argument is a PATH-like string).
#
# Parameters:
# $1 - pid,
# $2 - PATH-like string, returns PATH-like string on stdout
Handle_WPAR() {
    [ "$DEBUG_MODE" = "true" ] && set -x
    if [ $UOS != "AIX" ]; then echo "$2"; return; fi
    if wpar=`ps -o wpar -p $1 2>/dev/null`; then :; else echo "$2"; return; fi
    wpar=`echo "$wpar"|awk 'NR==2{print $1}'`
    if [ x"$wpar" != xGlobal ]; then
        prefix=`lswpar -q -c -a directory $wpar | sed 's#/$##'`
    else
        echo "$2"; return
    fi
    if [ x"$prefix" = x ]; then
        echo "$2"
    else
        printf "%s" "$2" | tr ':' '\n' | sed 's#^/#'"${prefix}"'/#' | tr '\n' ':'
    fi
}

# Checks if process defined by PID is not in global WPAR
# $1 - PID
# 0 - global; 1 - the process is not in global WPAR
Is_PID_In_Global_WPAR(){
    if [ "$UOS" != "AIX" ]; then
    	return 0;
    fi
    if wpar=`ps -o wpar -p $1 2>/dev/null`; then
	    wpar=`echo "$wpar"|awk 'NR==2{print $1}'`
	    if [ x"$wpar" != xGlobal ]; then
		return 1;
	    fi
    fi
    return 0;
}

# Get full path to executable, resolving wpars. Trying workaround different situations.
Get_Exe_By_Pid() {
    # parameters:
    # $1 -- pid of process
    # $2 -- regexp for possible daemon names
    # $3 -- command line argument that specify root of daemon installation.

    [ "$DEBUG_MODE" = "true" ] && set -x

    get_exe_by_memmap() {
        [ "$DEBUG_MODE" = "true" ] && set -x
        # The memory map lists which memory segments a process uses,
        # and also shows which files are mapped into the address space
        # For Linux and Solaris, the executable is always the first file
        # mapped. For AIX, the executable is flagged as "text data BSS heap"
        # or as "code".
        case $UOS in
            AIX) maj_min_inode=`strings /proc/$1/map | sed 's/^.*jfs/jfs/' | awk 'NR==1'`
                maj=`echo $maj_min_inode | cut -f 2 -d'.'`
                min=`echo $maj_min_inode | cut -f 3 -d'.'`
                inode=`echo $maj_min_inode | cut -f 4 -d'.'`
                if [ -n "$maj" -a -n "$min" -a -n "$inode" ]; then
                    lv=`ls -l /dev | grep -E "^b.*$maj, *$min " | awk '{print $NF}'`
                    if [ -n "$lv" ]; then
                        mp=`lslv $lv | awk '/^MOUNT POINT/ {print $3}'`
                        if [ -n "$mp" -a -d "$mp" ]; then
                            ncheck -i $inode $mp | awk 'NR==2 {print "'"${mp}"'" $2}'
                        fi
                    fi
                fi
                ;;
            LINUX) ls -l /proc/$1/exe | awk '{print $NF}';;
            SUNOS)  pmap  $1 | awk '(NR==2 || NR==3) && ($0 ~ /.*[[:space:]]+r-x--[[:space:]]+\/.*/) {print $4}'
#            SUNOS) pmap $1 | awk 'NR==2' |\
#                      sed 's/^[^ ][^ ]*  *[^ ][^ ]*  *[^ ][^ ]*  *//';;
        esac
    }

    phys_mount() {
        [ "$DEBUG_MODE" = "true" ] && set -x
        # list "physical" file systems, i.e. no NFS, no procfs etc.
        case $UOS in
            AIX) mount | awk '$1~/\/dev/{print $2}';;
            HP-UX|SUNOS) mount | grep 'on /dev' | sed 's/ on \/dev.*$//';;
            LINUX) mount | grep '^/dev' | sed 's/^.*on \(.*\) type.*$/\1/';;
        esac
    }

    get_file_by_fuser() {
        [ "$DEBUG_MODE" = "true" ] && set -x
        # use fuser to find a file that is held open by a process.
        # $1 - PID, $2 - file name, $3 - additional regexp to filter
        #   fuser output, e.g. /t/ for text files (process executable)
        # THIS IS VERY SLOW AND SHOULD BE THE LAST RESORT ONLY
        phys_mount | while read i; do
            if fuser -c $i 2>&1 | tr ' ' '\012' | awk 'NR>1 && '"${3}" | \
                tr -d '[a-z]' | grep '^'$1'$' >/dev/null; then
                echo $i
            fi
        done | while read i; do
            find $i -name "$2" -xdev | while read j; do
                fuseropt="-f"
                [ "$UOS" = "AIX" ] && fuseropt="-fx"
                if fuser $fuseropt $j 2>&1 | tr ' ' '\012' | awk 'NR>1 && '"${3}" | \
                    tr -d '[a-z]' | grep '^'$1'$' >/dev/null; then
                    echo $j
                fi
            done
        done
    }

    create_map_exe_2_pid(){
        [ "$DEBUG_MODE" = "true" ] && set -x

	create_map_exe_2_pid_umask=`umask`
        umask 066
        rm $TEMPDIR/ora_home_dirs 2> /dev/null; touch $TEMPDIR/ora_home_dirs
        if [ ! -f $TEMPDIR/mapped_exe_pid ]; then
           if [ -f /etc/oratab ]; then
               grep -v "#" /etc/oratab| grep ":" | grep "/" | cut -d':' -f2 >> $TEMPDIR/ora_home_dirs
           fi
           if [ -f /var/opt/oracle/oratab ]; then
               grep -v "#" /var/opt/oracle/oratab | grep ":" | grep "/" | cut -d':' -f2 >> $TEMPDIR/ora_home_dirs
           fi
           #
           #<HOME NAME="OraDb10g_home1" LOC="/oracle/oracle/product/10.2.0/db_1" TYPE="O" IDX="1"/
           #
           if [ -f /etc/oraInst.loc ]; then
               ORA_INV=`grep "inventory_loc" /etc/oraInst.loc | cut -d'=' -f2`
               if [ -f ${ORA_INV}/ContentsXML/inventory.xml ]; then
                   grep 'HOME NAME' ${ORA_INV}/ContentsXML/inventory.xml | cut -d'"' -f4 >>$TEMPDIR/ora_home_dirs
               fi
           fi
           if [ -f /var/opt/oracle/oraInst.loc ]; then
               ORA_INV=`grep "inventory_loc" /var/opt/oracle/oraInst.loc | cut -d'=' -f2`
               if [ -f ${ORA_INV}/ContentsXML/inventory.xml ]; then
                   grep 'HOME NAME' ${ORA_INV}/ContentsXML/inventory.xml | cut -d'"' -f4 >>$TEMPDIR/ora_home_dirs
               fi
           fi
           #
           # TNS
           #
           ps -ef | grep tnslsnr | grep -v grep | grep -v sed | sed 's/\/bin\/tnslsnr.*$//' | awk '{print $NF}' >> $TEMPDIR/ora_home_dirs

           # we could use the listener.ora for additional oracle home

           #
           # LOGFILE
           #
           if [ -f $TEMPDIR/subs.ora.log.save ]; then
               grep ";SUBSYSTEM_TYPE=ORA;" $TEMPDIR/subs.ora.log.save | sed 's/.*INSTANCE_PATH=//' | sed 's/;.*$//' >>$TEMPDIR/ora_home_dirs
           fi

           #
           # FOUND ORACLE_HOME
           #
           sort -u $TEMPDIR/ora_home_dirs > $TEMPDIR/unique_ora_home_dirs
           cat $TEMPDIR/unique_ora_home_dirs | while read filename; do
               if [ -f $filename/bin/oracle ] ; then
                   fuseropt="-f"
                   [ "$UOS" = "AIX" ] && fuseropt="-fx"
                   fuser $fuseropt $filename/bin/oracle 2>/dev/null | tr ' ' '\012' | tr -d '[a-z]' | \
                       awk -v EXENAME=${filename}/bin/oracle '{if (NF==1) {printf("%s %s\n",EXENAME,$1);}}' >> $TEMPDIR/mapped_exe_pid
              fi
           done
        fi
	umask "$create_map_exe_2_pid_umask"
    }

    create_map_mnt_2_pid(){
        [ "$DEBUG_MODE" = "true" ] && set -x
	create_map_mnt_2_pid_umask=`umask`
        umask 066
        if [ ! -f $TEMPDIR/mapped_mnt_pid ]; then
            phys_mount | while read mntfile; do
                fuser -c $mntfile 2>/dev/null | tr ' ' '\012' | tr -d '[a-z]' | \
                    awk -v EXENAME=$mntfile \
                    '{if (NF==1) {printf("%s %s\n",EXENAME,$1);}}' >> $TEMPDIR/mapped_mnt_pid
            done
        fi
	umask "$create_map_mnt_2_pid_umask"
    }


    phys_mount() {
        [ "$DEBUG_MODE" = "true" ] && set -x
        # list "physical" file systems, i.e. no NFS, no procfs etc.
        case $UOS in
            AIX) mount | awk '$1~/\/dev/{print $2}';;
            HP-UX|SUNOS) mount | grep 'on /dev' | sed 's/ on \/dev.*$//';;
            LINUX) mount | grep '^/dev' | sed 's/^.*on \(.*\) type.*$/\1/';;
        esac
    }

    get_file_by_fuser3() {
        [ "$DEBUG_MODE" = "true" ] && set -x
        # use fuser to find a file that is held open by a process.
        # $1 - PID, $2 - file name, $3 - additional regexp to filter
        #   fuser output, e.g. /t/ for text files (process executable)
        # THIS IS VERY SLOW AND SHOULD BE THE LAST RESORT ONLY
	get_file_by_fuser3_umask=`umask`
        umask 066
        create_map_mnt_2_pid "$1" "$2" "$3"

        grep " $1" $TEMPDIR/mapped_mnt_pid | cut -d' ' -f1 | sort -u | while read i; do
            grep "FSX:$i:FSX" $TEMPDIR/mapped_used_fs >/dev/null 2>&1
            if [ $? -eq 1 ]; then
                 # Not Scanned for binary
                 find $i -name oracle -xdev | grep "bin/oracle" >> $TEMPDIR/unique_ora_home_dirs
                 echo "FSX:$i:FSX" >> $TEMPDIR/mapped_used_fs
            fi
        done
        cat $TEMPDIR/unique_ora_home_dirs | while read j; do
            filename=`echo $j| sed 's/\/bin\/oracle//'`
            grep "$filename" $TEMPDIR/mapped_exe_pid >/dev/null 2>&1
            if [ $? -ge 1 ]; then
                # no match found add fuser info to mapped_exe_pid
                fuseropt="-f"
                [ "$UOS" = "AIX" ] && fuseropt="-fx"
                fuser $fuseropt $filename/bin/oracle 2>&1 | tr ' ' '\012' | tr -d '[a-z]' | \
                    awk -v EXENAME=${filename}/bin/oracle \
                    '{if (NF==1) {printf("%s %s\n",EXENAME,$1);}}' >> $TEMPDIR/mapped_exe_pid

            fi
        done
	umask "$get_file_by_fuser3_umask"
    }

    get_file_by_fuser2() {
        [ "$DEBUG_MODE" = "true" ] && set -x
        # use fuser to find a file that is held open by a process.
        # $1 - PID, $2 - file name, $3 - additional regexp to filter
        #   fuser output, e.g. /t/ for text files (process executable)

	get_file_by_fuser2_umask=`umask`
        umask 066

        # Create EXE list
        create_map_exe_2_pid

        if [ -f $TEMPDIR/mapped_exe_pid ]; then
            O=`awk '$2 == "'$1'" {print $1; exit 0}' $TEMPDIR/mapped_exe_pid`
            if [ -z "$O" ]; then
               get_file_by_fuser3 "$1" "$2" "$3"
               O=`awk '$2 == "'$1'" {print $1; exit 0}' $TEMPDIR/mapped_exe_pid`
            fi
            echo $O
        fi
        umask "$get_file_by_fuser2_umask"
    }

    get_exe_by_fuser() {
        [ "$DEBUG_MODE" = "true" ] && set -x
        # get process executable using fuser. Does not work on AIX.
        fuser_exe=`which fuser`
        [ -z "$fuser_exe" ] && return
        flag="/t/"
        if [ "$UOS" = "LINUX" ]; then flag="/e/"; fi
        cmd=`ps -p $1 | awk 'NR==2{print $4}'`
        get_file_by_fuser2 $1 "$cmd" "$flag" | head -1
    }

    get_exe_by_proc() {
        [ "$DEBUG_MODE" = "true" ] && set -x
        # get proces executable by proc/cwd for pmon
        case $UOS in
            AIX)
                wd=`if [ -L /proc/$1/cwd ]; then
                        ls -l /proc/$1/cwd | awk '{print $NF}'
                elif [ -x /usr/bin/procwdx ]; then
                    procwdx $1 | tr '\011' ' ' | sed 's/^[^ ][^ ]*  *//' | \
                        sed 's/\/$//'
                fi`
                [ -n "$wd" -a -x "$wd/$2" ] && echo "$wd/$2"
                ;;
            SUNOS) wd=`pwdx $1 | tr '\011' ' ' | sed 's/^[^ ][^ ]*  *//'`
                [ -n "$wd" -a -x "$wd/$2" ] && echo "$wd/$2"
                ;;
        esac
    }

    is_valid_exe() {
        # check that found exe is valid
        # $1 -- exe pid
        # $2 -- found exe
        # $3 -- regexp for valid exe name
        [ "$DEBUG_MODE" = "true" ] && set -x
        if [ -n "$2" -a -x "$2" ]; then
            if `awk 'BEGIN {rc=1; if(match("'$2'", "^/.*/'$3'$")) {rc=0}} END {exit rc}' < /dev/null`; then
                # FINALY: check that our pid mapped to found exe.
                fuser_exe=`which fuser`
                if [ -n "$fuser_exe" -a -x "$fuser_exe" ]; then
                    fuseropt=""
                    [ "$UOS" = "AIX" ] && fuseropt="-fx"
                    procIDs=`fuser $fuseropt $2 2>&1`
                    echo "$procIDs" | grep -E " ${1}(e|m|t)" > /dev/null && return 0
                else
                    # on linux previous checks is enough to be sure that we have valid exe even if no fuser
                    if [ "$UOS" = "LINUX" ]; then
                        return 0
                    fi
                fi
            fi
        fi
        return 1
    }

    [ "$DEBUG_MODE" = "true" ] && set -x
    exe_pid=$1
    exe_regexp=$2
    exe_root_param=$3

    # 0) AIX+SOLARIS: get_exe_by_proc
    if [ "$UOS" = "AIX" -o "$UOS" = "SUNOS" ]; then
        command=`get_exe_by_proc $exe_pid`
        is_valid_exe "$exe_pid" "$command" "$exe_regexp" && echo $command && return
    fi

    # 1) LINUX+SOLARIS: get_exe_by_memmap (this is fast + reliable where it is supported)
    if [ "$UOS" = "LINUX" -o "$UOS" = "SUNOS" ]; then
        command=`get_exe_by_memmap $exe_pid`
        is_valid_exe "$exe_pid" "$command" "$exe_regexp" && echo $command && return
    fi

    # 2) process name (+HandleWPAR)
    exe_name=`ps $ps_x_option -p $exe_pid -o args | awk 'NR==2 {print $1}'`
#    command=`Handle_WPAR $exe_pid "$exe_name"`
    command="$exe_name"

    is_valid_exe "$exe_pid" "$command" "$exe_regexp" && echo $command && return

    # 2.1) get_exe_by_fuser (should be fast enough cause don't use ncheck)
    command=`get_exe_by_fuser $exe_pid`
    is_valid_exe "$exe_pid" "$command" "$exe_regexp" && echo $command && return

    # 3) process name + PATH (+HandleWPAR)
    # 4) process name + LD_LIBRARY_PATH (replace "lib" with "bin") (+HandleWPAR)
    exe_name=`ps $ps_x_option -p $exe_pid -o comm  | awk 'NR==2 {print $1}'`
    for env_var in PATH LD_LIBRARY_PATH; do
        command=''
        _path=`Get_Env_Var_For_Pid $exe_pid $env_var`
        if [ -n "$_path" ]; then
            _tmp=""
            for dir in `echo $_path | tr ':' ' '`; do
                [ "$env_var" = "LD_LIBRARY_PATH" ] && dir=`echo $dir | sed 's;/lib\(/\|$\);/bin\1;g'`
                if [ -z "$_tmp" -a -x "$dir/$exe_name" ]; then
                    _tmp="$dir/$exe_name"
                fi
            done
#            [ -n "$_tmp" ] && command=`Handle_WPAR $exe_pid "$_tmp"`
            [ -n "$_tmp" ] && command="$_tmp"
        fi
        is_valid_exe "$exe_pid" "$command" "$exe_regexp" && echo $command && return
    done

    # 5) -d parameter + (s)bin (+HandleWPAR)
    if [ -n "$exe_root_param" ]; then
        command=''
        exe_root=`ps -fp $exe_pid | awk '
{
# if daemon root passed in parameters -- extract it
  if (match($0, / '$exe_root_param' [^ ]+/)) {
    print substr($0, RSTART+length("'$exe_root_param'")+2, RLENGTH-length("'$exe_root_param'")-2)
  }
}'`
        if [ -n "$exe_root" ]; then
            _tmp=''
            if [ -x "$exe_root/sbin/$exe_name" ]; then
                _tmp="$exe_root/sbin/$exe_name"
            elif [ -x "$exe_root/bin/$exe_name" ]; then
                _tmp="$exe_root/bin/$exe_name"
            fi
        fi
#        [ -n "$_tmp" ] && command=`Handle_WPAR $exe_pid "$_tmp"`
        [ -n "$_tmp" ] && command="$_tmp"
        is_valid_exe "$exe_pid" "$command" "$exe_regexp" && echo $command && return
    fi

    # 6) AIX: get_exe_by_memmap (ncheck or find approach, SLOW)
    if [ "$UOS" = "AIX" ]; then
        command=`get_exe_by_memmap $exe_pid`
        is_valid_exe "$exe_pid" "$command" "$exe_regexp" && echo $command && return
    fi
    # 7) Get TNS_ADMIN variable for AIX, LINUX, SUNOS
    TNS_ADMIN=""
    TNS_ADMIN=`Get_Env_Var_For_Pid $exe_pid "TNS_ADMIN"`
}

Create_Temporary_SQL () {
    Create_Temporary_SQL_umask=`umask`
    umask 022

    TMP_SQL8MIN=$TEMPDIR/get_oracle8min.sql
    TMP_SQL8PLS=$TEMPDIR/get_oracle8pls.sql
    TMP_SQL_OUT=$TEMPDIR/tmp_sql_out.txt
    cat <<EOF >$TMP_SQL8MIN
connect internal
set serveroutput on;
set termout on

DECLARE
    stmt_text         varchar2(2000);
    stmt_result       number;

    ora_host          varchar2(64);
    ora_name          varchar2(64);
    ora_version       varchar2(64);
    ora_edition       varchar2(200);
    ora_fixpack       varchar2(30);

    sap_owner         varchar2(30);
    sap_ins           varchar2(5);
    sap_ver           varchar2(40);
    sap_nbr           number;
    sap_mndt          number;
    sap_cnt           number;
    sap_dt_applied    varchar2(64);
    sap_patch_applied varchar2(64);

    dmi_tables           number;
    dmi_indexes          number;
    dmi_table_partitions number;
    dmi_index_partitions number;
    dmi_MB_data_files    number;
    dmi_MB_used          number;
    dmi_MB_log_space     number;
    dmi_MB_dic_tempfiles number;
    dmi_MB_undo_files    number;
    dmi_MB_undo_segments number;
    dmi_MB_allocated     number;


BEGIN
---
--- Basic information
---
    select name into ora_name
           from v\$database;

    select banner
           into ora_edition
           from v\$version
           where banner like 'Oracle%';
---
--- FIXPACK does not exist in 7.3 and 8.0
---
    ora_fixpack := '';
---
--- PRINT ORA Basic information
---

    dbms_output.put_line('HOSTNAME='||ora_host);
    dbms_output.put_line('SUBSYSTEM_INSTANCE='||ora_name);
    dbms_output.put_line('MW_VERSION='||ora_version);
    dbms_output.put_line('MW_EDITION='||ora_edition);
--- dbms_output.put_line('FIXPACK='||ora_fixpack);
---
--- SAP
---

    sap_ins := 'N';
    sap_ver := '';
    sap_nbr := 0;
    sap_mndt := 0;
    select count(*) into sap_cnt from dba_objects where object_name='CVERS_TXT';
    if sap_cnt > 0 then
       sap_ins := 'Y';
---
---    NEEDS TO BE REWRITTEN IF NEEDED.
---
---    select owner into sap_owner from dba_objects where object_name='CVERS_TXT';
---    stmt_text := 'select STEXT from '||sap_owner||'.CVERS_TXT where LANGU=''E''';
---    execute immediate stmt_text into sap_ver;
---    stmt_text := 'select count(distinct BNAME) from '||sap_owner||'.USR02';
---    execute immediate stmt_text into sap_nbr;
---    stmt_text := 'select count(distinct MANDT) from '||sap_owner||'.T000';
---    execute immediate stmt_text into sap_mndt;
    end if;
    sap_dt_applied := '';
    sap_patch_applied := '';
---
--- PRINT SAP Information
---

dbms_output.put_line ( 'SAP_INSTALLED='    || sap_ins );
dbms_output.put_line ( 'SAP_CVERS='        || sap_ver );
dbms_output.put_line ( 'MW_NB_USERS='      || sap_nbr );
dbms_output.put_line ( 'MW_NB_MNDTS='      || sap_mndt );
dbms_output.put_line ( 'SAP_DT_APPLIED='   || sap_dt_applied );
dbms_output.put_line ( 'SAP_PATH_APPLIED=' || sap_patch_applied );

---
--- DATAMINING
---
    SELECT count(*) INTO dmi_tables
           FROM all_tables
           WHERE OWNER NOT IN ('SYS','SYSTEM');

    SELECT count(*) INTO dmi_indexes
           FROM all_indexes
           WHERE owner NOT IN ('SYS','SYSTEM');

    SELECT round((sum(bytes)/1048576)) INTO dmi_MB_data_files
           FROM dba_data_files;
---
--- Partitioned tables not checked
---
    dmi_table_partitions := 0;
    dmi_index_partitions := 0;

    SELECT round((sum(bytes)/1048576)) INTO dmi_MB_used
           FROM dba_segments;

    SELECT round((sum(bytes)/1048576)) INTO dmi_MB_log_space
          FROM v\$log;

---
--- Correction of space
---
--- Collect temporary space
    SELECT NVL(round((sum(bytes)/1048576)),0) INTO dmi_MB_dic_tempfiles
           FROM dba_data_files
        WHERE tablespace_name like 'TEMP%';

--- Collect used rollback
    SELECT NVL(round((sum(bytes)/1048576)),0) INTO dmi_MB_undo_files
           FROM dba_data_files df,  (SELECT distinct(tablespace_name) tablespace_name
                                     FROM dba_rollback_segs
                                     WHERE tablespace_name NOT in ('SYSTEM')) rb
           WHERE df.tablespace_name = rb.tablespace_name;

--- Collect undo segments
        SELECT NVL(round((sum(bytes)/1048576)),0) INTO dmi_MB_undo_segments
           FROM dba_segments
        WHERE segment_type in ('ROLLBACK','TYPE2 UNDO');


        dmi_MB_allocated := dmi_MB_data_files - dmi_MB_dic_tempfiles - dmi_MB_undo_files;
        dmi_MB_used      := dmi_MB_used - dmi_MB_undo_segments;

---
--- PRINT DMI information
---
    DBMS_OUTPUT.PUT_LINE( 'NB_TABLES='  || dmi_tables ) ;
    DBMS_OUTPUT.PUT_LINE( 'NB_INDEXES=' || dmi_indexes );
    DBMS_OUTPUT.PUT_LINE( 'TABLE_PART=' || dmi_table_partitions );
    DBMS_OUTPUT.PUT_LINE( 'INDEX_PART=' || dmi_index_partitions );
    DBMS_OUTPUT.PUT_LINE( 'ALLOC_DB='   || dmi_MB_allocated );
    DBMS_OUTPUT.PUT_LINE( 'USED_DB='    || dmi_MB_used );
    DBMS_OUTPUT.PUT_LINE( 'ALLOC_LOG='  || dmi_MB_log_space );
    DBMS_OUTPUT.PUT_LINE( 'USED_LOG='   || dmi_MB_log_space );

END;
/
exit
EOF
    cat <<EOF >$TMP_SQL8PLS
connect / as sysdba

set serveroutput on;

set verify on
set termout on
set feedback on
set linesize 130

DECLARE
    stmt_text         varchar2(2000);
    stmt_result       number;

    ora_host          varchar2(64);
    ora_name          varchar2(64);
    ora_version       varchar2(64);
    ora_edition       varchar2(200);
    ora_fixpack       varchar2(50);
	ora_id			  varchar2(30);
	ora_db_name		  varchar2(30);

    sap_owner         varchar2(30);
    sap_ins           varchar2(5);
    sap_ver           varchar2(40);
    sap_nbr           number;
    sap_mndt          number;
    sap_cnt           number;
    sap_dt_applied    varchar2(64);
    sap_patch_applied varchar2(64);

    dmi_tables           number;
    dmi_indexes          number;
    dmi_table_partitions number;
    dmi_index_partitions number;
    dmi_MB_data_files    number;
    dmi_MB_used          number;
    dmi_MB_log_space     number;
    dmi_MB_dic_tempfiles number;
    dmi_MB_undo_files    number;
    dmi_MB_undo_segments number;
    dmi_MB_allocated     number;


BEGIN
---
--- Basic information
---
    select host_name, instance_name, version
           into ora_host, ora_name, ora_version
           from v\$instance;
    select banner
           into ora_edition
           from v\$version
           where banner like 'Oracle%';
	select DBID, NAME
			into ora_id, ora_db_name
			from v\$database;
---
--- dbms_output.put_line('ORA_INFO='||ora_host||','||ora_name||','||ora_version||','||ora_edition);
---
--- FIXPACK
---
---	SELECT * into ora_fixpack FROM
---		(select comments from sys.registry\$history WHERE bundle_series = 'PSU' ORDER BY action_time)
---		temp1 WHERE rownum <= 1 ORDER BY rownum;
---
--- PRINT FIXPACK
--- dbms_output.put_line('FIXPACK='||ora_fixpack);
---
--- PRINT ORA Basic information
---
--- dbms_output.put_line('ORA_INFO='||ora_host||','||ora_name||','||ora_version||','||ora_edition||','||ora_fixpack);
    dbms_output.put_line('HOSTNAME='||ora_host);
    dbms_output.put_line('SUBSYSTEM_INSTANCE='||ora_name);
    dbms_output.put_line('MW_VERSION='||ora_version);
    dbms_output.put_line('MW_EDITION='||ora_edition);
--- dbms_output.put_line('FIXPACK='||ora_fixpack);
	dbms_output.put_line('MW_INST_ID='||ora_id);
	dbms_output.put_line('DB_NAME='||ora_db_name);
---
--- SAP
---

    sap_ins := 'N';
    sap_ver := '';
    sap_nbr := 0;
    sap_mndt := 0;
    select count(*) into sap_cnt from dba_objects where object_name='CVERS_TXT';
    if sap_cnt > 0 then
       sap_ins := 'Y';
       select owner into sap_owner from dba_objects where object_name='CVERS_TXT';
       stmt_text := 'select STEXT from '||sap_owner||'.CVERS_TXT where LANGU=''E''';
       execute immediate stmt_text into sap_ver;
       stmt_text := 'select count(distinct BNAME) from '||sap_owner||'.USR02';
       execute immediate stmt_text into sap_nbr;
       stmt_text := 'select count(distinct MANDT) from '||sap_owner||'.T000';
       execute immediate stmt_text into sap_mndt;
    end if;
    sap_dt_applied := '';
    sap_patch_applied := '';
---
--- PRINT SAP Information
---
--- dbms_output.put_line('SAP_INFO='||sap_ins||','||sap_ver||','||sap_nbr||','||sap_mndt||','||sap_dt_applied||','||sap_patch_applied);

dbms_output.put_line ( 'SAP_INSTALLED='    || sap_ins );
dbms_output.put_line ( 'SAP_CVERS='        || sap_ver );
dbms_output.put_line ( 'MW_NB_USERS='      || sap_nbr );
dbms_output.put_line ( 'MW_NB_MNDTS='      || sap_mndt );
dbms_output.put_line ( 'SAP_DT_APPLIED='   || sap_dt_applied );
dbms_output.put_line ( 'SAP_PATH_APPLIED=' || sap_patch_applied );

---
--- DATAMINING
---
    SELECT count(*) INTO dmi_tables
           FROM all_tables
           WHERE PARTITIONED = 'NO'
           AND OWNER NOT IN ('SYS','SYSTEM');

    SELECT count(*) INTO dmi_table_partitions
           FROM all_tab_partitions
           WHERE TABLE_OWNER  NOT IN ('SYS','SYSTEM');

    SELECT count(*) INTO dmi_index_partitions
           FROM dba_ind_partitions
           WHERE INDEX_OWNER  NOT IN ('SYS','SYSTEM');

    SELECT count(*) INTO dmi_indexes
           FROM all_indexes
           WHERE PARTITIONED = 'NO'
           AND owner NOT IN ('SYS','SYSTEM');

    SELECT round((sum(bytes)/1048576)) INTO dmi_MB_data_files
           FROM dba_data_files;

    SELECT round((sum(bytes)/1048576)) INTO dmi_MB_used
           FROM dba_segments;

    SELECT round((sum(bytes)/1048576)) INTO dmi_MB_log_space
          FROM v\$log;

---
--- Correction of space
---
--- Collect temporary space
    SELECT NVL(round((sum(bytes)/1048576)),0) INTO dmi_MB_dic_tempfiles
           FROM dba_tablespaces ts, dba_data_files df
           WHERE ts.tablespace_name = df.tablespace_name
           AND   ts.contents = 'TEMPORARY';

--- Collect used rollback
    SELECT NVL(round((sum(bytes)/1048576)),0) INTO dmi_MB_undo_files
           FROM dba_data_files df,  (SELECT distinct(tablespace_name) tablespace_name
                                     FROM dba_rollback_segs
                                     WHERE tablespace_name NOT in ('SYSTEM')) rb
           WHERE df.tablespace_name = rb.tablespace_name;

--- Collect undo segments
        SELECT NVL(round((sum(bytes)/1048576)),0) INTO dmi_MB_undo_segments
           FROM dba_segments
        WHERE segment_type in ('ROLLBACK','TYPE2 UNDO');


        dmi_MB_allocated := dmi_MB_data_files - dmi_MB_dic_tempfiles - dmi_MB_undo_files;
        dmi_MB_used      := dmi_MB_used - dmi_MB_undo_segments;

---
--- PRINT DMI information
---
    DBMS_OUTPUT.PUT_LINE( 'NB_TABLES='  || dmi_tables ) ;
    DBMS_OUTPUT.PUT_LINE( 'NB_INDEXES=' || dmi_indexes );
    DBMS_OUTPUT.PUT_LINE( 'TABLE_PART=' || dmi_table_partitions );
    DBMS_OUTPUT.PUT_LINE( 'INDEX_PART=' || dmi_index_partitions );
    DBMS_OUTPUT.PUT_LINE( 'ALLOC_DB='   || dmi_MB_allocated );
    DBMS_OUTPUT.PUT_LINE( 'USED_DB='    || dmi_MB_used );
    DBMS_OUTPUT.PUT_LINE( 'ALLOC_LOG='  || dmi_MB_log_space );
    DBMS_OUTPUT.PUT_LINE( 'USED_LOG='   || dmi_MB_log_space );

END;
/
exit;
EOF

umask $Create_Temporary_SQL_umask
}

#######################################################
# SCANNING ROUTINES. ORACLE
#######################################################

Scan_Running_Instances() {

    Show_PS_Output

#    RUNNING_INSTANCES=`ps $PSARGS pid,user,args | grep ora_pmon_ | grep -v grep | awk '{split($3,db,"_"); print $1 ":" $2 ":" db[3]}'`
#    if [ -z "$RUNNING_INSTANCES" ]; then
#        echo "No Oracle DB Found"
#    fi

    if [ "$UOS" = 'SUNOS' ]; then
	Scan_Running_Instances_umask=`umask`
	umask 066
	ps $PSARGS pid,ppid,user |
	awk '{print $1,$2,$3 }'> "${TEMPDIR}/pids.txt"

	/usr/ucb/ps agxwww |
	awk '{$2=$3=$4="";print}' >\
	    "${TEMPDIR}/ps_out.txt"

	awk 'FNR==NR{a[$1]=$3 FS $2;next}(a[$1]!=""){ print a[$1], $0}'\
	    "${TEMPDIR}/pids.txt" "${TEMPDIR}/ps_out.txt" >\
	    "${TEMPDIR}/process_list.txt"

        #cat "${TEMPDIR}/process_list.txt"

	RUNNING_INSTANCES=`awk '$0 !~ /csh -c / && /ora_pmon_/ {
		split($4,db,"ora_pmon_"); instance[$3]=($3 ":" $1 ":" db[2]); pidlist=pidlist "|" $3; parents[$3]=$2;
	}
	END {
		pidlist=substr(pidlist, 2)
		for (pid in parents) {
		if (parents[pid] !~ "^(" pidlist ")$") print instance[pid];
	}
	}
	' "${TEMPDIR}/process_list.txt" | sort -u`

	umask $Scan_Running_Instances_umask

    elif [ -z "$PSARGSWO" ]; then
#	RUNNING_INSTANCES=`ps $PSARGS pid,ppid,user,args | grep -v 'csh -c ' | grep -vE "(10354812|14352458|16121980|11075730)" | awk '/ora_pmon_/ && $0!~/\/ora_pmon_\//{
	RUNNING_INSTANCES=`ps $PSARGS pid,ppid,user,args | awk '$0 !~ /csh -c / && /ora_pmon_/ && $0!~/\/ora_pmon_\//{
		split($4,db,"ora_pmon_"); instance[$1]=($1 ":" $3 ":" db[2]); pidlist=pidlist "|" $1; parents[$1]=$2;
	}
	END {
		pidlist=substr(pidlist, 2)
		for (pid in parents) {
		if (parents[pid] !~ "^(" pidlist ")$") print instance[pid];
	}
	}
	' | sort -u`
    else
	#HP-UX only
	RUNNING_INSTANCES=`ps $PSARGSWO | awk '$0 !~ /csh -c / && /ora_pmon_/ && $0 !~ /\/ora_pmon_\// {
		split(($5~/:/?8:9),db,"ora_pmon_"); instance[$2]=($2 ":" $1 ":" db[2]); pidlist=pidlist "|" $2; parents[$2]=$3;
	}
	END {
		pidlist=substr(pidlist, 2)
		for (pid in parents) {
		if (parents[pid] !~ "^(" pidlist ")$") print instance[pid];
	}
	}
	' "${TEMPDIR}/process_list.txt" | sort -u`
    fi
}

Get_Oracle_Parameters() {
    [ "$DEBUG_MODE" = "true" ] && set -x

   pid=$1
   uid=$2
   sid=$3

   #ORACLE_HOME=`Get_Env_Var_For_Pid $pid "ORACLE_HOME"`

   ORACLE_HOME_IS_DIR=
   if [ "$UOS" = "AIX" ]; then
	 _fs=`printf "\034"`
	if Is_PID_In_Global_WPAR $1; then
            ORACLE_HOME=`Get_Env_Var_For_Pid $pid "ORACLE_HOME"`
	else
	    # get ORACLE_HOME from inside of WPAR
            ORACLE_HOME=`clogin "$wpar" "_len=\`ps www $1 | awk 'NR==2 {print length()}'\`; \
		 ps wwwe $1 | awk 'NR==2 {print substr(\\$0, '"'"'"\${_len}"'"'"'+1)}' | \
		 sed 's/^ *//' | sed 's/ \([^ ]*=\)/${_fs}\1/g'" | tr "${_fs}" '\n' | awk -F= '$1=="ORACLE_HOME" {print $2;}'`
	    ORACLE_HOME_IS_DIR=`clogin "$wpar" test -d "$ORACLE_HOME" 2>/dev/null && echo "dir"`
	fi
   else
       ORACLE_HOME=`Get_Env_Var_For_Pid $pid "ORACLE_HOME"`
   fi

   [ -n "$ORACLE_HOME" -a -n "$ORACLE_HOME_IS_DIR" ] && return
   [ -n "$ORACLE_HOME" -a -d "$ORACLE_HOME" ] && return

    # we must find ORACLE_HOME and ORACLE_BASE for this SID.
    #PVB CHANGED TO ORACLE_EXE
    ORACLE_EXE=`Get_Exe_By_Pid $pid "oracle"`
    if [ -n "$ORACLE_EXE" -a -s "$ORACLE_EXE" ]; then
           ORACLE_HOME=`echo $ORACLE_EXE | sed 's/\/bin\/oracle//'`
        else
           ORACLE_HOME=""
    fi
    #BVP

    if [ -n "$ORACLE_HOME" -a -d "$ORACLE_HOME" ]; then
	# everything is ok, real ORACLE_HOME is found in oracle process environment
	return
    fi

   # an attempt to build ORACLE_HOME from config files
   # seems we wasn't able to trace home via pid -- let's try old way
   ORACLE_HOME=""
   if [ -z "$ORATAB" ]; then
          case $UOS in
              AIX) ORATAB=/etc/oratab ;;
              SUNOS) ORATAB=/var/opt/oracle/oratab ;;
              LINUX) ORATAB=/etc/oratab ;;
              HP-UX) ORATAB=/etc/oratab ;;
              *) ORATAB="" ;;
          esac
   fi
       if [ -z "$ORATAB" ]; then
           echo "Can't determine correct location of oratab. Unknown OS?"
   else
       if [ ! -f $ORATAB ]; then
           echo "No $ORATAB found in system!"
       else
           ORAHOME=`cat $ORATAB | grep -v "\#" | grep -v "\*"| grep -i $sid | cut -d':' -f 2`
           if [ -z "$ORAHOME" ]; then
               ORAHOME=`cat $ORATAB | grep -v "\#" | grep '*' | cut -d':' -f 2`
           fi
           if [ ! -z "$ORAHOME" -a -d "$ORAHOME" ]; then
               # finding correct ORACLE_HOME in oratab
               ORACLE_HOME=$ORAHOME
               echo "ORACLE_HOME from oratab for $sid: $ORACLE_HOME"
           else
               echo "Can't find $sid in orarab or specified ORACLE_HOME not exists"
           fi
       fi
   fi

# PVB
    # check for SYMlink in ORACLE_HOME
    # works if the symlink is created on /
    # need to check other dirnames in the path
    #
    BASE_ORA=`echo $ORACLE_HOME | cut -f 2 -d'/'`
    NEWB_ORA=`ls -l / | awk '/->/ && $NF == "'$BASE_ORA'" {print $(NF-2)}'`
    if [ -n "$NEWB_ORA" ] ; then
       NEW_ORACLE_HOME=`echo $ORACLE_HOME | sed  "s/$BASE_ORA/$NEWB_ORA/"`
       # Check if sqlplus exists otherwise skip modify ORACLE_HOME
       #
       if [ -f $NEW_ORACLE_HOME/bin/sqlplus ] ; then
          ORACLE_HOME=$NEW_ORACLE_HOME
       fi
    fi
# BVP

}

#AIX Path is $ORACLE_HOME/bin,/etc, /usr/bin,/usr/bin/X11,/usr/lbin, and /usr/local/bin, if it exists
#HP Path is $ORACLE_HOME/bin,/usr/bin,/etc, /usr/bin/X11 and /usr/local/bin, if it exists
#Linux Path is $ORACLE_HOME/bin,/usr/bin,/bin, /usr/bin/X11 and /usr/local/bin,if it exists
#Solaris Path is $ORACLE_HOME/bin,/usr/ccs/bin, /usr/bin,/etc,/usr/openwin/bin and /usr/local/bin, if it exists

#LD_LIBRARY_PATH 	Set the LD_LIBRARY_PATH variable as $ORACLE_HOME/lib for HP, Linux, Tru64, and Solaris 32-bit.

#Set the LD_LIBRARY_PATH variable as
#$ORACLE_HOME/lib32 for Solaris 64-bit.
#LD_LIBRARY_PATH_64 	Set the LD_LIBRARY_PATH_64 variable as
#$ORACLE_HOME/lib for Solaris 64-bit.
#SHLIB_PATH 	Set the SHLIB_PATH variable as $ORACLE_HOME/lib32 for HP.
#LIBPATH 	Set the LIBPATH variable as $ORACLE_HOME/lib32: $ORACLE_HOME/lib for AIX.

#AIX 		LIBPATH 		$ORACLE_HOME/lib32:$ORACLE_HOME/lib:$LIBPATH
#HP-UX 		SHLIB_PATH 		$ORACLE_HOME/lib32:$ORACLE_HOME/lib:$SHLIB_PATH
#Linux 		LD_LIBRARY_PATH 	$ORACLE_HOME/lib:$LD_LIBRARY_PATH
#Solaris SPARC 	LD_LIBRARY_PATH 	$ORACLE_HOME/lib32:$ORACLE_HOME/lib:$LD_LIBRARY_PATH
#Solaris x86 	LD_LIBRARY_PATH 	$ORACLE_HOME/lib:$LD_LIBRARY_PATH

Set_oraparams(){
  [ "$DEBUG_MODE" = "true" ] && set -x
  USE_DIFFERENT_SH=$1
  ORAPARAMS="set -a ;"
  ORAPARAMS="$ORAPARAMS ORACLE_HOME=$ORACLE_HOME;"
  case ${UOS}_${OS_BITS} in
    AIX_32)   ORAPARAMS="$ORAPARAMS PATH=$ORACLE_HOME/bin:/etc:/usr/bin:/usr/bin/X11:/usr/lbin:/usr/local/bin:\$PATH;"
              ORAPARAMS="$ORAPARAMS LIBPATH=$ORACLE_HOME/lib32:$ORACLE_HOME/lib:\$LIBPATH;"
              ORAPARAMS="$ORAPARAMS LD_LIBRARY_PATH=$ORACLE_HOME/lib:\$LD_LIBRARY_PATH;";
              if [ -n "$USE_DIFFERENT_SH" ]; then
                  USE_DIFFERENT_SH='if ( ${?LIBPATH} == "0" ) set LIBPATH='"$ORACLE_HOME/lib"';  '"$USE_DIFFERENT_SH"
                  USE_DIFFERENT_SH='if ( ${?LD_LIBRARY_PATH} == "0" ) set LD_LIBRARY_PATH='"$ORACLE_HOME/lib"'; '"$USE_DIFFERENT_SH"
              fi
              ;;
    AIX_64)   ORAPARAMS="$ORAPARAMS PATH=$ORACLE_HOME/bin:/etc:/usr/bin:/usr/bin/X11:/usr/lbin:/usr/local/bin:\$PATH;";
              ORAPARAMS="$ORAPARAMS LIBPATH=$ORACLE_HOME/lib32:$ORACLE_HOME/lib:\$LIBPATH;"
              ORAPARAMS="$ORAPARAMS LD_LIBRARY_PATH=$ORACLE_HOME/lib:\$LD_LIBRARY_PATH;";
              if [ -n "$USE_DIFFERENT_SH" ]; then
                  USE_DIFFERENT_SH='if ( ${?LIBPATH} == "0" ) set LIBPATH='"$ORACLE_HOME/lib"';  '"$USE_DIFFERENT_SH"
                  USE_DIFFERENT_SH='if ( ${?LD_LIBRARY_PATH} == "0" ) set LD_LIBRARY_PATH='"$ORACLE_HOME/lib"'; '"$USE_DIFFERENT_SH"
              fi
              ;;
    SUNOS_32) ORAPARAMS="$ORAPARAMS PATH=$ORACLE_HOME/bin:/usr/bin:/bin:/usr/bin/X11:/usr/local/bin:\$PATH;";
              ORAPARAMS="$ORAPARAMS LD_LIBRARY_PATH=$ORACLE_HOME/lib:\$LD_LIBRARY_PATH;";
              if [ -n "$USE_DIFFERENT_SH" ]; then
                  USE_DIFFERENT_SH='if ( ${?LD_LIBRARY_PATH} == "0" ) set LD_LIBRARY_PATH='"$ORACLE_HOME/lib"'; '"$USE_DIFFERENT_SH"
              fi
              ;;
    SUNOS_64) ORAPARAMS="$ORAPARAMS PATH=$ORACLE_HOME/bin:/usr/bin:/bin:/usr/bin/X11:/usr/local/bin:\$PATH;";
              ORAPARAMS="$ORAPARAMS LD_LIBRARY_PATH=$ORACLE_HOME/lib32:\$LD_LIBRARY_PATH;";
              ORAPARAMS="$ORAPARAMS LD_LIBRARY_PATH_64=$ORACLE_HOME/lib:\$LD_LIBRARY_PATH_64;";
              if [ -n "$USE_DIFFERENT_SH" ]; then
                  USE_DIFFERENT_SH='if ( ${?LD_LIBRARY_PATH} == "0" ) set LD_LIBRARY_PATH='"$ORACLE_HOME/lib"'; '"$USE_DIFFERENT_SH"
                  USE_DIFFERENT_SH='if ( ${?LD_LIBRARY_PATH_64} == "0" ) set LD_LIBRARY_PATH_64='"$ORACLE_HOME/lib"';  '"$USE_DIFFERENT_SH"
              fi
              ;;
    LINUX_)   ORAPARAMS="$ORAPARAMS PATH=$ORACLE_HOME/bin:/usr/bin:/bin:/usr/bin/X11:/usr/local/bin:\$PATH;";
              ORAPARAMS="$ORAPARAMS LD_LIBRARY_PATH=$ORACLE_HOME/lib:\$LD_LIBRARY_PATH;";
              if [ -n "$USE_DIFFERENT_SH" ]; then
                  USE_DIFFERENT_SH='if ( ${?LD_LIBRARY_PATH} == "0" ) set LD_LIBRARY_PATH='"$ORACLE_HOME/lib"'; '"$USE_DIFFERENT_SH"
              fi
              ;;
    HP-UX_)   ORAPARAMS="$ORAPARAMS PATH=$ORACLE_HOME/bin:/usr/bin:/etc:/usr/bin/X11:/usr/local/bin:\$PATH;";
              ORAPARAMS="$ORAPARAMS LD_LIBRARY_PATH=$ORACLE_HOME/lib:\$LD_LIBRARY_PATH;";
              ORAPARAMS="$ORAPARAMS SHLIB_PATH=$ORACLE_HOME/lib32:$ORACLE_HOME/lib:\$SHLIB_PATH;";
              if [ -n "$USE_DIFFERENT_SH" ]; then
                  USE_DIFFERENT_SH='if ( ${?LD_LIBRARY_PATH} == "0" ) set LD_LIBRARY_PATH='"$ORACLE_HOME/lib"'; '"$USE_DIFFERENT_SH"
                  USE_DIFFERENT_SH='if ( ${?SHLIB_PATH} == "0" ) set SHLIB_PATH='"$ORACLE_HOME/lib32"';  '"$USE_DIFFERENT_SH"
              fi
              ;;
    esac
    ORAPARAMS="$ORAPARAMS ORACLE_SID=$sid;"
    [ -n "$TNS_ADMIN" ] && ORAPARAMS="$ORAPARAMS TNS_ADMIN=$TNS_ADMIN; "
    #[ $2 -eq 1 -a -n "USE_DIFFERENT_SH" ] && ORAPARAMS=`echo "$ORAPARAMS" | sed 's/\\$/\\\\$/g'`
}

Copy_SQL_to_WPAR() {
 [ "$DEBUG_MODE" = "true" ] && set -x
 # $1 - source
 # $2 - destination
 # $wpar - global variable
 tmp_umask=`umask`
 umask 066;
 cp "$1" "$2"
 clogin "$wpar" chown root "$2"
 clogin "$wpar" chmod 644 "$2"
 umask "$tmp_umask"
 unset tmp_umask
}

Set_Instnce_Fields()  {
 [ "$DEBUG_MODE" = "true" ] && set -x
 # $1 - SQL_OUT
 # $2 - $sid
	    #
	    # BASIC INFO
	    #
	    DBMS_TYPE="ORACLE"
	    SUBSYSTEM_TYPE="ORA"
	    SUBSYSTEM_INSTANCE=$2
	    INSTANCE_PATH=$ORACLE_HOME
#	    DB_NAME=$2
		DB_NAME=`grep "DB_NAME=" "$1" | awk -F "=" '{print $2}'`
	    MW_VERSION=$ORAVERS
	    MW_EDITION=$ORAEDIT
		FIXPACK=`cat $TEMPDIR/fixpack.txt | grep "Patch description" | grep "Database Patch Set Update" | awk -F ":" '{ print $3 }' | awk -F "(" '{ print $1 }'`
		MW_INST_ID=`grep "MW_INST_ID=" "$1" | awk -F "=" '{print $2}'`

	    #
	    # SAP INFO
	    #
	    SAP_INSTALLED=`grep "SAP_INSTALLED=" "$1" |cut -d'=' -f2`
	    SAP_CVERS=`grep "SAP_CVERS=" "$1" |cut -d'=' -f2`
	    MW_NB_USERS=`grep "SAP_MW_NB_USERS=" "$1" |cut -d'=' -f2`
	    MW_NB_MNDTS=`grep "SAP_MW_NB_MNDTS=" "$1" |cut -d'=' -f2`
	    # fixing some sap values
	    if [ "$SAP_INSTALLED" != "Y" ]; then
	        SAP_CVERS=''
	        MW_NB_USERS=''
	        MW_NB_MNDTS=''
	    fi

	    #
	    # DMI INFO
	    #
	    NB_TABLES=`grep "NB_TABLES=" "$1" |cut -d'=' -f2`
	    NB_INDEXES=`grep "NB_INDEXES=" "$1" |cut -d'=' -f2`
	    ALLOC_DB=`grep "ALLOC_DB=" "$1" |cut -d'=' -f2`
	    USED_DB=`grep "USED_DB=" "$1" |cut -d'=' -f2`
	    ALLOC_LOG=`grep "ALLOC_LOG=" "$1" |cut -d'=' -f2`
	    USED_LOG=`grep "USED_LOG=" "$1" |cut -d'=' -f2`
	    TABLE_PART=`grep "TABLE_PART=" "$1" |cut -d'=' -f2`
	    INDEX_PART=`grep "INDEX_PART=" "$1" |cut -d'=' -f2`
	    DB_PART=`grep "DB_PART=" "$1" |cut -d'=' -f2`

	    INSTANCE_NAME=$2
[ "$DEBUG_MODE" = "true" ] && cat "$1"
}

Get_port_from_listener_ora() {
   [ "$DEBUG_MODE" = "true" ] && set -x
   #$1 $ORACLE_HOME
   listener_ora="$1/network/admin/listener.ora"

   [ ! -f $listener_ora ] && return

   if [ -x "`which tac 2>&1`" ]; then
      tac_exe=tac
   else
      tac_exe='tail -r'
   fi

   $tac_exe $listener_ora|sed -e 's/[[:space:]]//g' -e 's/(/:/g' -e 's/)/ /g'|\
awk  'BEGIN {sid_found=0; PORT=0; LISTENER=""; sid_list_found=0; DEFAULT_PORT="" };
$1==":SID_NAME='$sid'" {sid_found = 1; next};
/SID_LIST_.*=/ {sid_list_found=1};
sid_found==1 && /SID_LIST_.*=/ { SID_LIST = $0; split($0,l,"SID_LIST_"); LISTENER=l[2]; sid_found = 0; next };
$0 !~ /SID_LIST_.*=/ && NF>0 && $0 !~ /^:/ {if ($0 == LISTENER) { print PORT; exit } else {PORT=0 }; };
/:ADDRESS=:PROTOCOL=[Tt][Cc][Pp] :HOST='$HOSTNAME'/ {split($3,p,"="); PORT=p[2]; DEFAULT_PORT=PORT; }
END { if (sid_list_found==0) {print DEFAULT_PORT}; }'

}


Scan_Instance() {
    [ "$DEBUG_MODE" = "true" ] && set -x

    set -a

    pid=`echo $1 | cut -f1 -d":"`
    uid=`echo $1 | cut -f2 -d":"`
    sid=`echo $1 | cut -f3 -d":"`

    Get_Oracle_Parameters $pid $uid $sid

    echo "Collecting basic fields for instance: $uid/$sid"

#     is it application wpar on AIX?
#    AIX_AP_WPAR="false"
#    if [ "$UOS" = "AIX" ]; then
#	if [ "`lswpar $wpar 2 > /dev/null | cut -f2`" = "A" ]; then
#	    AIX_AP_WPAR="true"
#	fi
#    fi

#    if [ "$UOS" = "AIX" ! -a Is_PID_In_Global_WPAR $pid -a "$SCAN_WPARS" = "true" -o "$AIX_AP_WPAR" = "true" ]; then


    Is_PID_In_Global_WPAR "$pid"
    if [ $? -eq 1 -a "$UOS" = "AIX" -a "$SCAN_WPARS" = "false" ]; then
	Reset_Vars
	return
    fi

    Is_PID_In_Global_WPAR "$pid"
    if [ $? -eq 1 -a "$UOS" = "AIX" -a "$SCAN_WPARS" = "true" ]; then

            prefix=`lswpar -q -c -a directory $wpar | sed 's#/$##'`

            uid=`clogin "$wpar" "ps -p$pid -o user" | awk 'NR==2 {print $1;}'`

	    # loocking for default sh for this uid
	    sh=`clogin "$wpar" "awk -F: '\\$1=="\"$uid\"" {print \\$NF}' /etc/passwd" | awk -F"/" '{print $NF}'`

	    USE_DIFFERENT_SH=""
	    if [ -n "$sh" -a "$sh" = "csh" ]; then
		shell_found=`clogin "$wpar" "for candidate in /bin/sh /usr/bin/sh /bin/ksh /usr/bin/ksh; do ls -l \\$candidate; done"`
		shell_found=`echo "$shell_found" | awk '$NF !~ /\/csh$/ {print $NF;}' | awk 'NR==1 {print;}'`

	        if [ -n "$shell_found" ]; then
	            # we found something suitable. Let's use it
	            echo "Using $found as shell for $uid"
	            USE_DIFFERENT_SH="$shell_found"
		    #USE_DIFFERENT_SH="$shell_found"
	        fi
	    fi

 	   Set_oraparams "$USE_DIFFERENT_SH"

	   # Collecting information about found SID
	    Scan_Instance_umask=`umask`
	    umask 066

	    if [ -f "${prefix}$ORACLE_HOME/bin/svrmgrl" ]; then
	        if [ -n "$USE_DIFFERENT_SH" ]; then
		#passed --
		    clogin "$wpar" su $uid -c "'""$USE_DIFFERENT_SH -c "'"'"$ORAPARAMS echo exit|svrmgrl"'"'"'" > "$TEMPDIR/oraver.txt"  2>&1
	            ORADIS=`cat $TEMPDIR/oraver.txt| grep -v "NEW MAIL"|grep -v Manager| grep '^Ora' |sed 's/ -.*$//'`

	        else
		#passed --
	            clogin "$wpar" su $uid -c "'""$ORAPARAMS echo exit|svrmgrl ""'" > "$TEMPDIR/oraver.txt" 2>&1
	            ORADIS=`cat $TEMPDIR/oraver.txt|grep -v "NEW MAIL"|grep -v Manager| grep '^Ora' |sed 's/ -.*$//'`
	        fi
	    else
		#passed --
	        if [ -n "$USE_DIFFERENT_SH" ]; then
	            clogin "$wpar" su $uid -c "'""$USE_DIFFERENT_SH -c "'"'"$ORAPARAMS echo '"'connect / as sysdba'"' | sqlplus /nolog"'"'"'" > "$TEMPDIR/oraver.txt" 2>&1
	            ORADIS=`cat $TEMPDIR/oraver.txt |grep -v "NEW MAIL"|grep Disconnected|sed 's/^.*Disconnected from //'|sed 's/-.*$//'`
	        else
		#passed --
	            clogin "$wpar" su $uid -c "'$ORAPARAMS echo \"connect / as sysdba\"|sqlplus /nolog'" > "$TEMPDIR/oraver.txt" 2>&1
	            ORADIS=`cat $TEMPDIR/oraver.txt|grep -v "NEW MAIL"|grep Disconnected|sed 's/^.*Disconnected from //'|sed 's/-.*$//'`
	        fi
	    fi
	    umask "$Scan_Instance_umask"

	    if [ "$DEBUG_MODE" = "true" ]; then
	        cat $TEMPDIR/oraver.txt
	    fi

	    ORAEDIT=`echo "$ORADIS" |sed 's/ Release.*$//'|sed 's/,//g'`
	    ORAVERS=`echo "$ORADIS" | sed 's/.*Release //'|sed 's/ .*$//'|sed 's/,//g'`

	#
	# if ORAVERS is empty STOP DM-ing NEEDS TO BE CORRECTED
	#
	    skip_dm=""
	    is_version=`awk 'BEGIN {if(match("'$ORAVERS'", "^[0-9\\.]+$")) {print "yes";}}' < /dev/null`;
	    if [ -z "$is_version" ]; then
	        skip_dm="yes"
	        if [ -f "$prefix/$ORACLE_HOME/inventory/ContentsXML/comps.xml" ]; then
	            ORAVERS=`grep "oracle.rdbms" "$prefix/$ORACLE_HOME/inventory/ContentsXML/comps.xml" | grep REF | tail -1| awk -F\" '{print $4}'`
	            ORAEDIT="UNKNOWN"
	        else
	            echo "* cant't find file $ORACLE_HOME/inventory/ContentsXML/comps.xml"
	        fi
	        is_version=`awk 'BEGIN {if(match("'$ORAVERS'", "^[0-9\\.]+$")) {print "yes";}}' < /dev/null`;
	        if [ -z "$is_version" ]; then
	            # last resort -- run sqlplus without su
                    clogin "$wpar" "$ORACLE_HOME/bin/sqlplus" /nolog < /dev/null > "$TEMPDIR/oraver.txt" 2>&1
	            ORAVERS=`grep "Release" $TEMPDIR/oraver.txt | sed 's/.*Release //'|sed 's/ .*$//'|sed 's/,//g' | awk 'NR==1 {print $1}'`
	            ORAEDIT="UNKNOWN"
	        fi
	    fi

	    is_version=`awk 'BEGIN {if(match("'$ORAVERS'", "^[0-9\\.]+$")) {print "yes";}}' < /dev/null`;
	    if [ -n "$is_version" ]; then
	#   ORAVERS is NUMBER
	#
	        ORABVER=`echo $ORAVERS|cut -d'.' -f1`
	        ORASVER=`echo $ORAVERS|cut -d'.' -f2`

	       if [ -f $TMP_SQL_OUT ]; then
	          rm $TMP_SQL_OUT
	       fi
	        touch $TMP_SQL_OUT
	        if [ -z "$skip_dm" ]; then
		   chmod 600 $TMP_SQL_OUT
   	           UNIQUE_SQL_FILENAME="/tmp/tmp.${$}-`od -N4 -tx /dev/random | awk 'NR==1 {print $2}'`.sql"

	           if [ $ORABVER$ORASVER  -le 80 ]; then
		       Copy_SQL_to_WPAR "$TMP_SQL8MIN" "${prefix}${UNIQUE_SQL_FILENAME}"
	               if [ -n "$USE_DIFFERENT_SH" ]; then
     	        	clogin "$wpar" su $uid -c "'""$USE_DIFFERENT_SH -c "'"'"$ORAPARAMS svrmgrl  < $UNIQUE_SQL_FILENAME"'"'"'" > "$TMP_SQL_OUT"
		       else
		        clogin "$wpar" su $uid -c "'""$ORAPARAMS svrmgrl  < $UNIQUE_SQL_FILENAME""'" > "$TMP_SQL_OUT"
		       fi
                   else
                       Copy_SQL_to_WPAR "$TMP_SQL8PLS" "${prefix}${UNIQUE_SQL_FILENAME}"
	               if [ -n "$USE_DIFFERENT_SH" ]; then
				   clogin "$wpar" su $uid -c "'""$USE_DIFFERENT_SH -c "'"'"$ORAPARAMS sqlplus /nolog  @$UNIQUE_SQL_FILENAME"'"'"'" > "$TMP_SQL_OUT"
	               else
				   clogin "$wpar" su $uid -c "'""$ORAPARAMS sqlplus /nolog  @$UNIQUE_SQL_FILENAME""'" > "$TMP_SQL_OUT"
	               fi
	           fi
                   [ "$DEBUG_MODE" = "true" ] && cat "${prefix}${UNIQUE_SQL_FILENAME}"
		   [ -f "${prefix}${UNIQUE_SQL_FILENAME}" ] && rm "${prefix}${UNIQUE_SQL_FILENAME}"
	       else
	           echo "Datamining skipped."
	       fi

	    else
	#
	#   ERROR Collecting Version number
	#   Use   version number SQLPLUS Edtion Not Found
	        ORAVERS=`grep "SQL" $TEMPDIR/oraver.txt | grep Plus|grep Release|  sed 's/.*Release '// | sed 's/ .*$//' `
	        ORAEDIT="UNKNOWN"
	#
	    fi

	    # if we have empty edition so far
	    if [ "$ORAEDIT" = "UNKNOWN" -a -n "$TMP_SQL_OUT" ]; then
	        tmpOraEdit=`cat "$TMP_SQL_OUT" | egrep '^Disco.*Ora.*Release ' | sed 's/.*Ora'/Ora/ | sed 's/ Release.*'//`
	        [ -n "$tmpOraEdit" ] && ORAEDIT="$tmpOraEdit"
	    fi

            if [ "$ORAEDIT" = "UNKNOWN" ]; then
	        ORAEDIT="`strings -n 8 ${prefix}$ORACLE_HOME/lib/libvsn*.a|grep -v Compiler|grep Release|sed 's/ Release.*//'`"
	    fi
	    #
	    # PORT info NEEDS TO BE CORRECTED
	    #
	    if [ -n "$USE_DIFFERENT_SH" ]; then
	        INSTANCE_PORT=`clogin "$wpar" su $uid -c "'""$USE_DIFFERENT_SH -c "'"'"$ORAPARAMS tnsping $sid"'"'"'" |grep -v "NEW MAIL"|grep '(PORT'|sed 's/^.*PORT[[:space:]]*=[[:space:]]*//'|sed 's/).*//'`
	    else
	        INSTANCE_PORT=`clogin "$wpar" su $uid -c "'""$ORAPARAMS tnsping $sid""'" | grep -v "NEW MAIL"|grep '(PORT'|sed 's/^.*PORT[[:space:]]*=[[:space:]]*//'|sed 's/).*//'`
	    fi

	    LSNR_PORT=`Get_port_from_listener_ora "${prefix}$ORACLE_HOME"`
	    [ -n "$LSNR_PORT" -a "$LSNR_PORT" != "0" -a "$INSTANCE_PORT" != "$LSNR_PORT"  ] && INSTANCE_PORT="$LSNR_PORT"

            Set_Instnce_Fields "$TMP_SQL_OUT" $sid

	    # update INSTANCE_PATH using prefix
	    INSTANCE_PATH=`Handle_WPAR $pid "$INSTANCE_PATH"`

    else # GLOBAL WPAR and OTHER OS

	    # loocking for default sh for this uid
	    sh=`awk -F: '\$1=="'$uid'" {print \$NF}' /etc/passwd | awk -F"/" '{print \$NF}'`
	    USE_DIFFERENT_SH=""
	    if [ -n "$sh" -a "$sh" = "csh" ]; then
	        found=""
	        # unfortunatly -- csh. Checking if we have valid sh or ksh
	        for candidate in /bin/sh /usr/bin/sh /bin/ksh /usr/bin/ksh; do
	            if [ -z "$found" -a -x $candidate ]; then
	                # check if this is not a link
	                tmp=`ls -l $candidate | awk '{print \$NF}' | awk -F"/" '{print \$NF}'`
	                if [ -n "tmp" -a "$tmp" != "csh" ]; then
	                    found=$candidate
	                fi
	            fi
	        done
	        if [ -n "$found" ]; then
	            # we found something suitable. Let's use it
	            echo "Using $found as shell for $uid"
	            USE_DIFFERENT_SH="$found"
	        fi
	    fi

           Set_oraparams "$USE_DIFFERENT_SH"

	   # Collecting information about found SID
	    Scan_Instance_umask=`umask`
	    umask 066
	    if [ -f $ORACLE_HOME/bin/svrmgrl ]; then
	        if [ -n "$USE_DIFFERENT_SH" ]; then
		#passed --
	            su $uid -c "$USE_DIFFERENT_SH -c '$ORAPARAMS echo exit|svrmgrl'" > $TEMPDIR/oraver.txt  2>&1
	            ORADIS=`cat $TEMPDIR/oraver.txt| grep -v "NEW MAIL"|grep -v Manager| grep '^Ora' |sed 's/ -.*$//'`
	        else
		#passed --
	            su $uid -c "$ORAPARAMS echo exit|svrmgrl " > $TEMPDIR/oraver.txt  2>&1
	            ORADIS=`cat $TEMPDIR/oraver.txt|grep -v "NEW MAIL"|grep -v Manager| grep '^Ora' |sed 's/ -.*$//'`
	        fi
	    else
	        if [ -n "$USE_DIFFERENT_SH" ]; then
		#passed --
				/sbin/runuser -l $uid -c "$ORAPARAMS $ORACLE_HOME/OPatch/opatch lsinventory" > $TEMPDIR/fixpack.txt
				su $uid -c "$USE_DIFFERENT_SH -c '$ORAPARAMS echo \"connect / as sysdba\" | sqlplus /nolog'" > $TEMPDIR/oraver.txt  2>&1
	            ORADIS=`cat $TEMPDIR/oraver.txt |grep -v "NEW MAIL"|grep Disconnected|sed 's/^.*Disconnected from //'|sed 's/-.*$//'`
	        else
		#passed --
				/sbin/runuser -l $uid -c "$ORAPARAMS $ORACLE_HOME/OPatch/opatch lsinventory" > $TEMPDIR/fixpack.txt
				su $uid -c "$ORAPARAMS echo \"connect / as sysdba\"|sqlplus /nolog" > $TEMPDIR/oraver.txt 2>&1
	            ORADIS=`cat $TEMPDIR/oraver.txt|grep -v "NEW MAIL"|grep Disconnected|sed 's/^.*Disconnected from //'|sed 's/-.*$//'`
	        fi
	    fi
	    umask "$Scan_Instance_umask"

	    if [ "$DEBUG_MODE" = "true" ]; then
	        cat $TEMPDIR/oraver.txt
	    fi

	    ORAEDIT=`echo "$ORADIS" |sed 's/ Release.*$//'|sed 's/,//g'`
	    ORAVERS=`echo "$ORADIS" | sed 's/.*Release //'|sed 's/ .*$//'|sed 's/,//g'`

	#
	# if ORAVERS is empty STOP DM-ing NEEDS TO BE CORRECTED
	#
	    skip_dm=""
	    is_version=`awk 'BEGIN {if(match("'$ORAVERS'", "^[0-9\\.]+$")) {print "yes";}}' < /dev/null`;
	    if [ -z "$is_version" ]; then
	        skip_dm="yes"
	        if [ -f "$ORACLE_HOME/inventory/ContentsXML/comps.xml" ]; then
	            ORAVERS=`grep "oracle.rdbms" $ORACLE_HOME/inventory/ContentsXML/comps.xml | grep REF | tail -1| awk -F\" '{print $4}'`
	            ORAEDIT="UNKNOWN"
	        else
	            echo "* cant't find file $ORACLE_HOME/inventory/ContentsXML/comps.xml"
	        fi
	        is_version=`awk 'BEGIN {if(match("'$ORAVERS'", "^[0-9\\.]+$")) {print "yes";}}' < /dev/null`;
	        if [ -z "$is_version" ]; then
	            # last resort -- run sqlplus without su
	            $ORACLE_HOME/bin/sqlplus /nolog < /dev/null > $TEMPDIR/oraver.txt 2>&1
	            ORAVERS=`grep "Release" $TEMPDIR/oraver.txt | sed 's/.*Release //'|sed 's/ .*$//'|sed 's/,//g' | awk 'NR==1 {print $1}'`
	            ORAEDIT="UNKNOWN"
	        fi
	    fi

	    is_version=`awk 'BEGIN {if(match("'$ORAVERS'", "^[0-9\\.]+$")) {print "yes";}}' < /dev/null`;
	    if [ -n "$is_version" ]; then
	#   ORAVERS is NUMBER
	#
	        ORABVER=`echo $ORAVERS|cut -d'.' -f1`
	        ORASVER=`echo $ORAVERS|cut -d'.' -f2`

	       if [ -f $TMP_SQL_OUT ]; then
	          rm $TMP_SQL_OUT
	       fi
	       touch $TMP_SQL_OUT
	       #chmod 777 $TMP_SQL_OUT
	        if [ -z "$skip_dm" ]; then
#		  chown $uid $TMP_SQL_OUT
#		  chmod 600 $TMP_SQL_OUT
	           if [ $ORABVER$ORASVER  -le 80 ]; then
	               if [ -n "$USE_DIFFERENT_SH" ]; then
				su $uid -c "$USE_DIFFERENT_SH -c '$ORAPARAMS svrmgrl < $TMP_SQL8MIN'" > "$TMP_SQL_OUT"
		       else
				su $uid -c "$ORAPARAMS svrmgrl  < $TMP_SQL8MIN" > "$TMP_SQL_OUT"
		       fi
	           else
	               if [ -n "$USE_DIFFERENT_SH" ]; then
				   su $uid -c "$USE_DIFFERENT_SH -c '$ORAPARAMS sqlplus /nolog  @$TMP_SQL8PLS'"  > "$TMP_SQL_OUT"
				   else
				   su $uid -c "$ORAPARAMS sqlplus /nolog  @$TMP_SQL8PLS" > "$TMP_SQL_OUT"
				   fi
	           fi
		 chown root $TMP_SQL_OUT
	       else
	            echo "Datamining skipped."
	       fi

	    else
	#
	#   ERROR Collecting Version number
	#   Use   version number SQLPLUS Edtion Not Found
	        ORAVERS=`grep "SQL" $TEMPDIR/oraver.txt | grep Plus|grep Release|  sed 's/.*Release '// | sed 's/ .*$//' `
	        ORAEDIT="UNKNOWN"
	#
	    fi

	    # if we have empty edition so far
	    if [ "$ORAEDIT" = "UNKNOWN" -a -n "$TMP_SQL_OUT" ]; then
	        tmpOraEdit=`cat "$TMP_SQL_OUT" | egrep '^Disco.*Ora.*Release ' | sed 's/.*Ora'/Ora/ | sed 's/ Release.*'//`
	        [ -n "$tmpOraEdit" ] && ORAEDIT="$tmpOraEdit"
	    fi

#	    ORAEDIT="UNKNOWN" # for test
            if [ "$ORAEDIT" = "UNKNOWN" ]; then
	        ORAEDIT="`strings -n 8 $ORACLE_HOME/lib/libvsn*.a|grep -v Compiler|grep Release|sed 's/ Release.*//'`"
	    fi

            Set_Instnce_Fields "$TMP_SQL_OUT" $sid


	    #
	    # PORT info NEEDS TO BE CORRECTED
	    #
	    if [ -n "$USE_DIFFERENT_SH" ]; then
	        INSTANCE_PORT=`su $uid -c "$USE_DIFFERENT_SH -c '$ORAPARAMS tnsping $sid'"|grep -v "NEW MAIL"|grep '(PORT'|sed 's/^.*PORT[[:space:]]*=[[:space:]]*//'|sed 's/).*//'`
	    else
	        INSTANCE_PORT=`su $uid -c "$ORAPARAMS tnsping $sid"|grep -v "NEW MAIL"|grep '(PORT'|sed 's/^.*PORT[[:space:]]*=[[:space:]]*//'|sed 's/).*//'`
	    fi

	    LSNR_PORT=`Get_port_from_listener_ora "$ORACLE_HOME"`
	    [ -n "$LSNR_PORT" -a "$LSNR_PORT" != "0" -a "$INSTANCE_PORT" != "$LSNR_PORT"  ] && INSTANCE_PORT="$LSNR_PORT"
    fi


    #
    # NOW WE MUST HAVE ALL REQUIRED INFO AND CAN UPDATE/CREATE ENV.
    #

    if [ -d "$INSTANCE_PATH" ]; then
        Create_Or_Update_Env_File "${INSTANCE_PATH}/.subscan_inventory_ora" "$sid"
    else
        Create_Or_Update_Env_File "/etc/cs/.subscan_inventory_ora" "$sid"
    fi

    #Reset_Vars is removed from Write_Info_To_Log for this scanner.
    Write_Info_To_Log "${SCRIPT_LOG_FILE}"

    if [ "$SAP_INSTALLED" = "Y" ]; then
	SUBSYSTEM_TYPE="SAP"
	MW_VERSION="0.0.0"
	MW_EDITION="DB"
	FIXPACK=''
#	SAP_INSTALLED=''
#       MW_NB_USERS=''
#	MW_NB_MNDTS=''
	NB_TABLES=''
	NB_INDEXES=''
	ALLOC_DB=''
	USED_DB=''
	ALLOC_LOG=''
	USED_LOG=''
	TABLE_PART=''
	INDEX_PART=''
	DB_PART=''

	#switch DB_NAME and SUBSYSTEM_INSTANCE for SAP
	tempvar="$SUBSYSTEM_INSTANCE"
	SUBSYSTEM_INSTANCE="$DB_NAME"
	DB_NAME="$tempvar"

#	Write_Info_To_Log subs.ora.log
	Write_Info_To_Log "${SCRIPT_SAP_LOG_FILE}"
    fi
    Reset_Vars
}

#######################################################
# MAIN PART
#######################################################

echo "***********************************************"
echo "COLLECTING INFORMATION OF THE BOX (ver. $Version)"
[ "$DEBUG_MODE" = "true" ] && echo $CVSID
echo "***********************************************"

SCRIPT_LOG_FILE=subs.ora.log
SCRIPT_MIF_FILE=SUBS_ORA_INV.mif
SCRIPT_SUBSYSTEM_TYPE=ORA
SCRIPT_SAP_LOG_FILE=ora_for_sap.tmp
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
    umask 022

    rm ${SCRIPT_LOG_FILE} 2> /dev/null
	rm ${SCRIPT_SAP_LOG_FILE} 2> /dev/null
	rm ${SCRIPT_MIF_FILE} 2> /dev/null

    Create_Temporary_Dir ${SCRIPT_SUBSYSTEM_TYPE}

    Create_Temporary_SQL

    Scan_Running_Instances
    if [ ! -z "$RUNNING_INSTANCES" ]; then
        for INSTANCE in $RUNNING_INSTANCES; do
            Scan_Instance "$INSTANCE"
        done
    else
#    Scan_HUR_Contingency
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

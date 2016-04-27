#!/bin/sh
#-----------------------------------------------------------------------------
# (C) Copyright 2010-2014 IBM Corporation
#-----------------------------------------------------------------------------
# NAME
#     iam_oracle_extract.sh - Oracle Sub-System Extractor
#
# SYNOPSIS
#     iam_oracle_extract.sh [-customer CUSTOMER] [-outputFile OUTPUT_FILE]
#         [-AG] [-FQDN] [-signature SIGNATURE] [-oraclePath ORACLE_PATH]
#         [-help] [-debug] [-allUserIDs] [-privIDs]
#         [-labellingFile LABELLING_FILE] [-propertiesFile PROPERTIES_FILE]
#         [-ibmOnly] [-customerOnly] [-owner OWNER] [-libPath LIB_PATH]
#
# DESCRIPTION
#     -customer CUSTOMER
#         Customer ID.
#
#     -outputFile OUTPUT_FILE
#         Name of (MEF3) output file.
#
#     -AG
#         Flag to indicate AG or Global naming standard (this applies to the
#         creation of the User ID naming convention field).
#
#     -FQDN
#         Flag to indicate that a fully qualified domain name shall be used
#         for hostnames. If this run time parameter is not provided to the
#         script, then the short name value used for hostnames.
#
#     -signature SIGNATURE
#         Extractor signature suffix. For instance, if the extractor script is
#         executed via TSCM, the value for this parameter will be '-TSCM' so 
#         that the string 'NOTaRealID-TSCM' appears in the MEF output. If this
#         parameter is not provided to the script, then the string
#         'NOTaRealID' appears in the MEF output.
#
#     -oraclePath
#         Oracle home/installation path.
#
#     -help
#         Indicates that help/informational text about the run time parameters
#         as well as the script version number shall be displayed. Lists the
#         available runtime parameters and appropriate syntax.
#
#     -debug
#         Flag to indicate if debug statements shall be written to the
#         standard output.
#
#     -allUserIDs
#         Flag to indicate whether or not all userids shall be extracted from
#         the sub-system.
#
#     -privIDs
#         Flag to indicate only Oracle userids identified [in IBM policies] as
#         having security & administrative rights shall be extracted. This
#         flag is mutually exclusive with 'allUserIDs' parameters. In other
#         words, both parameters shall not be provided to the script. If so,
#         an error message will be displayed. If this parameter is omitted,
#         allUserIDs parameter will be used at runtime as a default.
#
#     -labellingFile
#         Specifies the location and file name of the labeling file that the
#         extractor shall use to perform labeling lookups for internal userids
#         extracted from the sub-system.
#
#     -propertiesFile
#         Properties file used to specify the list of roles and privileges
#         that shall be included in the final MEF output. In other words, any
#         userids having any of those privileges or roles, will be included in
#         the MEF output.
#
#     -ibmOnly
#         Flag to state whether or not only IBM userids shall appear in the
#         MEF output.
#
#     -customerOnly
#         Flag to state whether or not only customer/vendor userids shall
#         appear in the MEF output.
#
#     -owner OWNER
#         Unix only. Parameter to specify system ID that will own
#         any script output file after runtime. Typically, MEF output,
#         logfile. This parameter is useful when script is run with sudo, to
#         allow sudoer ID to manage output files.
#
#     -libPath LIB_PATH
#         Use these parameter to provide path to extractor libraries
#         (IAMSubsystemsLibrary.sh) if they do not reside in current script
#         path.
#
# EXIT STATUS
#     0   Execution correct
#     1   Execution with warnings but MEF3 file created
#     2   Execution with errors - no MEF3 file created
#     9   Script aborted
#
# OUTPUT
#     <customer ID>_Oracle_<hostname>_<date>.mef3
#
#-------------------------------------------------------------------------------
# Version Date         # Author              Description
#-------------------------------------------------------------------------------
# V1.0.1  2009-06-16   # Anatoly Bondyuk     Initial version
# ...
# V2.0.00 2012-01-31   # Siarhei Konanau     Updated LINESIZE and PAGESIZE
#                                            R4121 - Signature Pattern
#                                            PAGESIZE=0 + script saves output from sqlplus
#                                            Fixed "subscript out of range" error (getAllUsers function) (script uses file instead arrays for getting alluserids) + formatted code
#                                            Renamed script to iam_oracle_extract.sh
#                                            Refactoring: created function writeUsersToMef
#                                            Added parameter "table" for temporary table
#                                            Fixed GetAllUsers ([YOU HAVE NEW MAIL])
#                                            Fixed GetAllUsers ([YOU HAVE NEW MAIL]) - 2;
#                                            Fixed ORACLE_INSTALL_PATH
#                                            Refactoring
# V2.0.01 2012-03-01   # Siarhei Konanau     Added parameters: libPath and owner
# V2.0.02 2012-03-05   # Siarhei Konanau     Fixed issue during pilot
# V2.0.03 2012-03-16   # Siarhei Konanau     Fixed issue during pilot
# V2.0.04 2012-03-19   # Siarhei Konanau     Fixed issue during pilot
# V2.0.05 2012-03-23   # Siarhei Konanau     Fixed issue during pilot
# V2.0.06 2012-03-26   # Siarhei Konanau     Fixed issue during pilot
# V2.0.07 2012-04-20   # Siarhei Konanau     Fixed issue during pilot (HP: getent)
# V2.0.08 2012-04-25   # Siarhei Konanau     Fixed issue during pilot
# V2.0.09 2012-05-07   # Siarhei Konanau     Fixed issue during pilot
# V2.0.10 2012-05-18   # Siarhei Konanau     Fixed issue with shutdown and halt (getent)
# V2.0.11 2012-05-30   # Siarhei Konanau     Fixed issue during pilot
# V2.0.12 2012-06-12   # Siarhei Konanau     Fixed GetOracleOwnerUser (upper -> lower)
# V2.0.14 2012-06-13   # Siarhei Konanau     Updated PSARGS / Added function GetMembersForGroup
# V2.0.15 2012-07-30   # Siarhei Konanau     Fixed GetMembersForOracleGroup
# V2.0.16 2012-08-08   # Pavel Pisakov       By default loading library from the script directory (not from current directory)
# V2.0.17 2012-08-17   # Pavel Pisakov       Fixed location of the "oratab" file. ParseConfigFile method has been rewritten.
# V2.0.18 2012-09-10   # Pavel Pisakov       Using getent instead of passwd file
# V2.0.19 2012-09-24   # Pavel Pisakov       Added get_oratab_file method
# V2.0.20 2012-10-08   # Pavel Pisakov       Fixed issue with whe null character in config files
# V2.0.21 2012-10-11   # Pavel Pisakov       Local variables are not applicable for HPUX ksh 
# V2.0.22 2012-10-30   # Pavel Pisakov       Method 'GetMembersForOracleGroup' changed to the 'get_users_from_a_group'
# V2.0.23 2012-11-02   # Pavel Pisakov       Changed data structure
# V2.0.24 2012-11-05   # Pavel Pisakov       Fixed special alghorithm of detecting admin group (.ascii part)
# V2.0.24.1 2012-11-08 # Pavel Pisakov       Minor bugs:
#                                                wrong function name 'getReturnName'
# V2.0.25 2012-11-08   # Pavel Pisakov       Use home path hardcoded in oratab if oracle home from exe is different.
# V2.0.26 2012-11-12   # Pavel Pisakov       Changed getAllUsers sql statement
# V2.0.26.1 2012-11-12 # Pavel Pisakov       Removed all parentheses
# V2.0.27 2012-11-21   # Pavel Pisakov       Works with sh, ksh and bash
# V2.0.28 2012-12-03   # Pavel Pisakov       Full path for all commands. $PATH can be empty.
# V2.0.29 2012-12-04   # Pavel Pisakov       Modified 'get_labelling_from_file'
# V2.0.29.1 2012-12-05 # Pavel Pisakov       Additional debug.
# V2.0.30 2012-12-14   # Pavel Pisakov       Fixes for HPUX and SunOS. 
#                                            + posix get_last_logon_user_id()
#                                            + posix get_state_for_user_id()
# V2.0.31 2012-12-19   # Pavel Pisakov       Fixed 'get_oracle_owner' method
# V2.0.32 2012-12-20   # Pavel Pisakov       Added ps_cmd
# V2.0.33 2013-02-05   # Pavel Pisakov       Cleaning user_list and hashes for each sid
# V2.0.34 2013-02-06   # Pavel Pisakov       Removed 'su -' invocations
# V2.0.35 2013-02-15   # Pavel Pisakov       Fixed csh environment
# V2.0.36 2013-02-28   # Pavel Pisakov       Fixed eval statements
# V2.0.37 2013-03-15   # Pavel Pisakov       Labelling function has been extended
#                                              collisions removed
#                                              new hash key names (l_name, l_desc, l_instance)
# V2.0.38 2013-04-09   # Pavel Pisakov       Refactoring
# V2.0.38.1 2013-04-18   # Pavel Pisakov     Fixed mef3 line
# V2.0.39  2013-04-23   # Pavel Pisakov      Additional ORACLE_HOME check method
# V2.0.40 2013-05-17   # Pavel Pisakov       Fixed issue with cksum
# V2.0.41 2013-05-24   # Pavel Pisakov       - get_exe_by_pid()
#                                            + get_home_by_pid()
# V2.0.42 2013-05-30   # Pavel Pisakov       Removed NOPRIVILEGE role from mef3 file content
# V2.0.43 2013-06-03   # Pavel Pisakov       Fixed issue for HPUX. The 'cut' command requires
#                                            new line character at the end of a string
# V2.0.44 2013-06-04   # Pavel Pisakov       sqlplus returns multiline version info on HP UX
# V2.0.45 2013-06-05   # Pavel Pisakov       Fixed issue for hpux - fuser, for contidion, lf_char
#                                            variable name for mef3 owner was changed
# V2.0.46 2013-06-13   # Pavel Pisakov       Fixed issue with PHYSICAL_STANDBY
# V2.0.47 2013-06-17   # Pavel Pisakov       Fixes for HPUX
# V2.0.48 2013-06-18   # Pavel Pisakov       Small issue with AIX's procwdx command
# V2.0.49 2013-06-21   # Pavel Pisakov       Modify prepare_shell_command()
# V2.0.50 2013-07-25   # Pavel Pisakov       Removed syntax check for /etc/oratab
# V2.0.51 2013-07-26   # Pavel Pisakov       Instance names are case insensitive
# V2.0.52 2013-10-08   # Pavel Pisakov       Oratab does not exist
# V2.0.53 2013-10-08   # Pavel Pisakov       Env check if not oracle owner
# V2.1    2013-10-12   # Pavel Pisakov       New ORACLE_HOME lookup method
#                                            log4sh
# V2.1.1  2013-10-17   # Pavel Pisakov       removed \s
# V2.1.2  2013-10-22   # Pavel Pisakov       Null characters
# V2.1.3  2013-11-28   # Pavel Pisakov       Changed `whoami' to `id'. POSIX v7
# V2.1.4  2014-01-08   # Pavel Pisakov       Intermediate results stores in tmp files
# V2.1.5  2014-01-17   # Pavel Pisakov       refactoring issues
# V2.1.6  2014-01-30   # Pavel Pisakov       SQL updated
# V2.1.7  2014-02-06   # Pavel Pisakov       getent exist, but doesn't return anything
# V2.1.8  2014-02-07   # Pavel Pisakov       zeroes at the end of a groupname
# V2.1.9  2014-03-07   # Pavel Pisakov       incorrent Oracle Home from proc
# V2.1.10 2014-03-10   # Pavel Pisakov       Expressions in env
# V2.2    2014-03-27   # Pavel Pisakov       New SQL
# V2.2.2  2014-02-20   # Pavel Pisakov       HPUX os name. New method a_append_uniq
#==============================================================================

# Version
version="V2.2.2"

# Script file info
script_arg_name="$0"
runtime_dir=`pwd`
script_name=`basename "$script_arg_name"`
script_dir=`dirname "$script_arg_name"`
script_path=`cd $script_dir && pwd`

# Time
audit_date=`date +%Y-%m-%d-%H.%M.%S`
date=`date +%d%b%Y | tr "[:lower:]" "[:upper:]"`
start_time=`date +"%D %r"`

# System info
cksum=`cksum $0 | awk '{ print $1 }'`
os_name=`uname`
os_version=""
whoami=""
hostname=`hostname`
ps_cmd="ps"
psargs="-ef -o"
current_uid=0
sec_user_file=""
sec_passwd_file=""

# Parameters
customer="IBM"
output_file=""
ag=false
fqnd=false
signature=""
oracle_install_path=""
debug=false
all_user_ids=false
priv_ids=false
labelling_file=""
properties_file=""
ibm_only=false
customer_only=false
mef3_owner=""
lib_path=""

# Params info
signature_group=""
unknown_parameters=""

# Temp files
tmp_file="/tmp/iam_oracle_extract.tmp"
tmp_file_2="/tmp/iam_oracle_extract_2.tmp"
script_file="/tmp/iam_oracle_extract_script.tmp"
sql_script_file="/tmp/iam_oracle_tmp_$$.sql"

# Syb-System
subsystem_name="Oracle"
oratab_file=""
remote_login_password_type=""
db_type=""

# DB
DB_PID="DB_PID"
DB_OWNER="DB_OWNER"
DB_HOME="DB_HOME"
DB_INSTANCE_NAME="DB_INSTANCE_NAME"

# Exit status codes
ex_ok=0
ex_warn=1
ex_err=2
ex_abort=9

return_code=0

# Helpers
TRUE=1
FALSE=0

# Yes/No
yes="YES"
no="NO"

# chars
character_comma=','
character_pipe='|'
character_colon=':'
character_semicolon=';'
character_space=' '
character_sharp='#'
character_lf='
'

# LDAP parameters
open_ldap_is_used=$FALSE
ldap_search_cmd=""

# ------------------------------------------------------------------------------
#  log4sh
# ------------------------------------------------------------------------------

status_info="INFO"
status_debug="DEBUG"
status_warn="WARN"
status_error="ERROR"

function print_message {

    typeset message=$1
    typeset status=$2
    typeset is_header_enabled=$3

    if test "X$is_header_enabled" = "X"; then
        is_header_enabled=true
    elif test "X$is_header_enabled" != "Xtrue" -a "X$is_header_enabled" != "Xfalse"; then
        is_header_enabled=false
    fi

    if $is_header_enabled; then
        test "X$status" = "X" && status=$status_info
        status="[$status] "
    else
        status=""
    fi

    printf "${status}${message}"

}

function print_info {

    typeset message=$1
    typeset is_header_enabled=$2

    print_message "$message" $status_info $is_header_enabled

}

function print_info_ln {

    typeset message=$1
    typeset is_header_enabled=$2

    print_info "$message\n" $is_header_enabled

}

function print_debug {

    typeset message=$1
    typeset is_header_enabled=$2

    if $debug; then
        print_message "$message" $status_debug $is_header_enabled
    fi

}

function print_debug_ln {

    typeset message=$1
    typeset is_header_enabled=$2

    print_debug "$message\n" $is_header_enabled

}

function print_warn {

    typeset message=$1
    typeset is_header_enabled=$2

    print_message "$message" $status_warn $is_header_enabled

    if test $return_code -lt $ex_warn; then
        return_code=$ex_warn
    fi

}

function print_warn_ln {

    typeset message=$1
    typeset is_header_enabled=$2

    print_warn "$message\n" $is_header_enabled

}

function print_error {

    typeset message=$1
    typeset is_header_enabled=$2

    print_message "$message" $status_error $is_header_enabled

    if test $return_code -lt $ex_err; then
        return_code=$ex_err
    fi

}

function print_error_ln {

    typeset message=$1
    typeset is_header_enabled=$2

    print_error "$message\n" $is_header_enabled

}

function print_sep {

    typeset message=$1
    typeset status=$2
    typeset is_header_enabled=$3

    test "X$status" = "X" && status=$status_info

    case $status in
        $status_debug)
            print_debug_ln "$message" $is_header_enabled
            ;;
        $status_warn)
            print_warn_ln "$message" $is_header_enabled
            ;;
        $status_error)
            print_error_ln "$message" $is_header_enabled
            ;;
        *)
            print_info_ln "$message" $is_header_enabled
            ;;
    esac

}

function print_sep_wide {

    typeset status=$1
    typeset is_header_enabled=$2

    print_sep "=========================================================" $status $is_header_enabled

}

function print_sep_slim {

    typeset status=$1
    typeset is_header_enabled=$2

    print_sep "---------------------------------------------------------" $status $is_header_enabled

}

test "X$LIBRARY_DEBUG" = "X" && LIBRARY_DEBUG=false || LIBRARY_DEBUG=true

function print_lib_debug_ln {
    if $LIBRARY_DEBUG; then print_info_ln "[DEBUG] $1" false; fi
}

#--------------------------------------------------------------------
# Associated array
#--------------------------------------------------------------------

# (hash_name, key, value) => void
function h_put {

    test $# -ne 3 && return 1

    typeset hash_name=$1
    typeset key=$2
    typeset value=$3

    print_lib_debug_ln "(h_put) h_${hash_name}_${key}='${value}'"

    eval "h_${hash_name}_${key}='${value}'"

}

# (hash_name, key) => value
function h_get {

    test $# -ne 2 && return 1

    typeset hash_name=$1
    typeset key=$2

    eval "as_print \"\$h_${hash_name}_${key}\""

}

# (hash_name, key) => void
function h_clear {

    test $# -ne 2 && return 1

    print_lib_debug_ln "(h_clear) unset h_${1}_${2}"

    eval "unset h_${1}_${2}"

}

#--------------------------------------------------------------------
# Array list
#--------------------------------------------------------------------

# get list of values separated by '\n'
function a_get_all {

    # one parameter: array_name
    if test $# -ne 1; then
        return 1
    fi

    typeset array_name=$1
    typeset size=`a_size "$array_name"`
    typeset counter=0
    typeset prepared_str=""

    while test $counter -lt $size; do
        prepared_str="${prepared_str}${counter} "
        let 'counter += 1'
    done

    oIFS=$IFS; IFS=$character_space
    for pos in $prepared_str; do
        eval "val=\$${array_name}_${pos}"
        printf "%s\n" "$val"
    done
    IFS=$oIFS

}

# a_append(arrayname) -- return size of an array
function a_size {

    if test $# -ne 1; then
        return 1
    fi

    typeset array_name=$1

    eval "size=\${${array_name}_size:-0}"
    printf "%d" $size

}

# a_append(arrayname, object) -- append object to end
function a_append {

    # two parameters: array_name and value
    if test $# -ne 2; then
        return 9
    fi

    typeset array_name=$1
    typeset element=`printf "%s\n" "$2" | sed -e 's/\\$/\\\\$/'`

    print_lib_debug_ln "(a_append) array_name: '$array_name'"
    print_lib_debug_ln "(a_append) element: '$element'"

    typeset size=`a_size "$array_name"`

    eval "${array_name}_${size}=\"$element\""
    let 'size += 1'
    eval "${array_name}_size=$size"

}

function a_to_string {

    if test $# -ne 1; then
        return 1
    fi

    typeset array_name=$1
    typeset size=`a_size "$array_name"`
    typeset separator=", "

    if test "$size" -eq 0; then
        return 0
    else

        first_element=true

        printf "["

        oIFS=$IFS; IFS=$character_lf
        for element in `a_get_all "$array_name"`; do

            if $first_element; then
                printf "%s" "$element"
                first_element=false
                continue
            fi

            printf "%s" "$separator"
            printf "%s" "$element"

        done
        IFS=$oIFS

        printf "]"

    fi
}

function a_clear {

    if test $# -ne 1; then
        return 1
    fi

    typeset array_name=$1

    print_lib_debug_ln "(a_clear) Found array name: $array_name"

    size=`a_size $array_name`
    print_lib_debug_ln "(a_clear) Size: $size"

    prepared_str=""

    counter=$size
    let 'counter = counter - 1'

    while test $counter -ge 0; do
        prepared_str="${prepared_str}${counter} "
        let 'counter = counter - 1'
    done

    print_lib_debug_ln "(a_clear) prepared_str: '$prepared_str'"

    oIFS=$IFS; IFS=$character_space
    for pos in $prepared_str; do

        print_lib_debug_ln "(a_clear) unset value: \"${array_name}_${pos}\""
        eval "unset ${array_name}_${pos}"

    done
    IFS=$oIFS

    print_lib_debug_ln "(a_clear) unset size: \"${array_name}_size\""

    eval "unset ${array_name}_size"

}

function a_count {

    if test $# -ne 2; then
        return 1
    fi

    typeset array_name=$1
    typeset var=$2

    typeset counter=0

    for element in `a_get_all "$array_name"`; do
        if test "X$element" = "X$var"; then
            let 'counter += 1'
        fi
    done

    printf $counter

}

function a_index_of {

    typeset array_name=$1
    typeset element=$2

    size=`a_size "$array_name"`
    prepared_str=""
    counter=0

    while test $counter -lt $size; do
        prepared_str="${prepared_str}${counter} "
        let 'counter = counter + 1'
    done

    oIFS=$IFS; IFS=$character_space
    for pos in $prepared_str; do
        eval "val=\$${array_name}_${pos}"
        if test "$val" = "$element"; then
            printf "%s" "$pos"
            IFS=$oIFS
            return 0
        fi
    done
    IFS=$oIFS

    printf "%s" "-1"
    return 1

}

# a_add "test_array" "8885"
# a_add "test_array" "8886"
# a_add "test_array" "8887"
# a_add "test_array" "8887"
# a_add "test_array" "8886"

# printf "test_array: %s\n" "`a_to_string test_array`"

# # > 8885, 8886, 8887, 8887, 8886

# a_add_uniq "test_array" "8885"
# a_add_uniq "test_array" "8886"
# a_add_uniq "test_array" "8887"
# a_add_uniq "test_array" "8888"

# printf "test_array: %s\n" "`a_to_string test_array`"

# # > 8885, 8886, 8887, 8887, 8886, 8888

function a_append_uniq {

    if test $# -ne 2; then
        return 9
    fi

    typeset array_name=$1
    typeset value=$2

    if test `a_index_of "$array_name" "$value"` -eq "-1"; then
        a_append "$array_name" "$value"
    fi

}

#--------------------------------------------------------------------
# Common lib
#--------------------------------------------------------------------

function as_println {
    oIFS=$IFS; IFS=''
    eval "printf '%s\\\n' '$1'"
    IFS=$oIFS
}

function as_print {
    oIFS=$IFS; IFS=''
    eval "printf '%s' '$1'"
    IFS=$oIFS
}

function clear_file {
    if test -f "$1"; then
        rm -f "$1" 1>/dev/null 2>&1
        if test $? -ne 0; then
            print_warn_ln "Can't remove file \"$1\""
        fi
    fi
}

function trim {
    printf "%s\n" "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'
}

function uc {
    printf "%s\n" "$1" | tr '[:lower:]' '[:upper:]'
}

function lc {
    printf "%s\n" "$1" | tr '[:upper:]' '[:lower:]'
}

function join_str {

    typeset variable_name="$1"
    typeset delimeter="$2"

    shift 2
    while test $# -gt 0; do
        eval "variable_data=\$$variable_name"
        if test "X$variable_data" = "X"; then
            eval "$variable_name=\"$1\""
        else
            eval "$variable_name=\"${variable_data}${delimeter}${1}\""
        fi
        shift
    done

}

#--------------------------------------------------------------------
# OS level function
#--------------------------------------------------------------------

cached_user=""
cached_shell=""

function get_user_shell {

    typeset var=$1
    typeset user=$2

    if test "X$user" != "X" -a "$user" = "$cached_user"; then
        print_debug_ln "Getting shell from cache ($cached_shell)"
        eval "$var=$cached_shell"
        return
    fi

    if test "$os_name" != "HP-UX" -a "$os_name" != "AIX"; then
        if command -v getent >/dev/null 2>&1; then
            entry=`getent passwd | grep -E "^${user}:.*" | head -n 1`
            user=`printf "%s\n" "$entry" | cut -d ":" -f1`
            shell=`printf "%s\n" "$entry" | cut -d ":" -f7`

            cached_user="$user"
            cached_shell="$shell"

            print_debug_ln "Found shell from getent ($shell)"
            eval "$var=$shell"
            return
        fi
    fi

    entry=`cat /etc/passwd | grep -E "^${user}:.*" | head -n 1`
    user=`printf "%s\n" "$entry" | cut -d ":" -f1`
    shell=`printf "%s\n" "$entry" | cut -d ":" -f7`

    cached_user="$user"
    cached_shell="$shell"

    print_debug_ln "Found shell from passwd ($shell)"

    eval "$var=$shell"

}

function absolute_path_for_command {

    typeset apfc_var_name=$1
    typeset apfc_command=$2
    typeset tmp_full_path=""

    oIFS=$IFS; IFS=':'
    for path in $PATH; do
        IFS=$oIFS

        if test -x "$path/$apfc_command"; then
            tmp_full_path="$path/$apfc_command"
            break
        fi

    done

    eval "$apfc_var_name=\"$tmp_full_path\""

}

#--------------------------------------------------------------------
# Common functions
#--------------------------------------------------------------------

function get_os_information {

    case "$os_name" in
        AIX)
            os_version=`oslevel`
            is_version=`printf "%s" "$os_version" | awk '/^[0-9]/ { print "yes" }'`
            if test "X$is_version" = "X"; then
                os_version=`uname -a | awk '{ print $4 "." $3 }'`
            fi
            sec_user_file="/etc/security/user"
            sec_passwd_file="/etc/security/passwd"
            ldap_search_cmd="/usr/ldap/bin/ldapsearch"

            ;;

        SunOS)
            PATH="/usr/xpg4/bin/:$PATH"
            export PATH
            os_version=`uname -r`
            sec_user_file=""
            sec_passwd_file="/etc/shadow"
            ldap_search_cmd="/usr/bin/ldapsearch"
            ;;

        Linux)
            os_version=`uname -r`
            psargs="axo"
            sec_user_file=""
            sec_passwd_file="/etc/shadow"
            ldap_search_cmd="/usr/bin/ldapsearch -x"
            ;;

        HP-UX)
            UNIX95=1
            export UNIX95
            os_version=`uname -r`

            # Ticket 001559bqP
            # UNIX95=1: not found
            # ps_cmd="UNIX95=1 && ps"
            ps_cmd="ps"
            sec_user_file=""
            sec_passwd_file="/etc/shadow"
            ldap_search_cmd="/opt/ldapux/bin/ldapsearch"
            ;;

        *)
            print_warn_ln "Unknow OS '$os_name' detected"
            os_version=`uname -r`
            sec_user_file=""
            sec_passwd_file="/etc/shadow"
            ;;
    esac

    whoami=`id -u -n`
    current_uid=`id -u`

    if test ! -f $ldap_search_cmd; then
        ldap_search_cmd="ldapsearch"
    fi

}

function get_return_code {

    exit_code=${1:-$return_code}

    print_sep_wide

    # TODO: clean all files
    clear_file "$sql_script_file"

    failure_instances=`a_get_all "failure_instances"`
    if test "X$failure_instances" != "X"; then
        print_warn_ln "The mef3 data has not been collected from following:"
        for failure_instance in $failure_instances; do
            print_warn_ln "$failure_instance"
        done
        print_sep_wide
    fi

    if test $exit_code -eq $ex_ok; then
        print_info_ln "The report has been finished with success"
    else
        print_info_ln "The report has been finished without success"
    fi

    print_info_ln "General return code: $exit_code"
    printf "[INFO] Elapsed time: %.2f\n" $SECONDS
    print_info_ln "UID EXTRACTOR EXECUTION - Finished"

    exit $exit_code

}


function get_help {

    echo "[INFO] Version: $version"
    echo "[INFO] USAGE: iam_oracle_extract.sh [-customer <customer id>] [-outputFile <results file>] "
    echo "[INFO]                            [-signature <signature>] [-AG]"
    echo "[INFO]                            [-help] [-debug] [-ibmOnly] [-customerOnly]"

    echo "[INFO] Details:"
    echo "[INFO] -customer           customer ID"
    echo "[INFO] -outputFile         Name of (MEF3) output file"
    echo "[INFO] -AG                 Flag to indicate AG or Global naming standard (this applies to the creation of the User ID naming convention field) "
    echo "[INFO] -FQDN               Flag to indicate that a fully qualified domain name shall be used for hostnames. If this run time parameter is not provided to the script, then the short name value shall be used for hostnames."
    echo "[INFO] -signature          Extractor signature suffix. For instance, if the extractor script is executed via TSCM, the value for this parameter shall be ‘-TSCM’ so that the string ‘NOTaRealID-TSCM’ appears in the MEF output. If this parameter is not provided to the script, then the string ‘NOTaRealID’ appears in the MEF output."
    echo "[INFO] -oraclePath         Oracle home/installation path"
    echo "[INFO] -help               Indicates that help/informational text about the run time parameters as well as the script version number shall be displayed. Lists the available runtime parameters and appropriate syntax."
    echo "[INFO] -debug              Flag to indicate if debug statements shall be written to the standard output."
    echo "[INFO] -allUserIDs         Flag to indicate whether or not all userids shall be extracted from the sub-system."
    echo "[INFO] -privIDs            Flag to indicate only ORACLE userids identified [in IBM policies] as having security & administrative rights shall be extracted. This Flag is mutually exclusive with 'allUserIDs' parameters. In other words, both parameters shall not be provided to the script. If so, an error message shall be displayed. If this parameter is omitted, allUserIDs parameter will be used at runtime as a default."
    echo "[INFO] -labellingFile      optional parameter. Specifies the location and file name of the labeling file that the extractor shall use to perform labeling lookups for internal userids extracted from the sub-system."
    echo "[INFO] -propertiesFile     Properties/configuration file used to specify the list of roles and privileges that shall be included in the final MEF output. In other words, any userids having any of those privileges or roles, shall be included in the MEF output."
    echo "[INFO] -ibmOnly            Flag to state whether or not only IBM userids shall appear in the MEF output. For further details see the 'Extractors Requirements Specification' document."
    echo "[INFO] -customerOnly       Flag to state whether or not only customer/vendor userids shall appear in the MEF output. For further details see the 'Extractors Requirements Specification' document."
    echo "[INFO] -owner              Optional. Unix only. Parameter to specify system ID that will own any script output file after runtime. Typically, MEF output, logfile. This parameter is useful when script is run with sudo, to allow sudoer ID to manage output files."
    echo "[INFO] -libPath            Use these parameter to provide path to extractor libraries (IAMSubsystemsLibrary.sh) if they do not reside in current script path."

    prepare_parameters
    print_params

}

function process_input_parameters {

    function args_error_message {
        print_error_ln "'$1' needs exactly one argument"
        get_return_code $ex_abort
    }

    function add_to_signature_group {
        join_str "signature_group" $character_sharp "$1"
    }

    while test $# -gt 0; do

        par_name=`printf -- "$1\n" | tr "[:upper:]" "[:lower:]"`

        case $par_name in

            -customer)
                shift && test $# -ne 0 || args_error_message "-customer"
                customer="$1"
                add_to_signature_group "-customer $customer"
                ;;

            -outputfile)
                shift && test $# -ne 0 || args_error_message "-outputFile"
                output_file="$1"
                add_to_signature_group "-outputFile $output_file"
                ;;

            -ag)
                ag=true
                add_to_signature_group "-ag"
                ;;

            -fqdn)
                fqnd=true
                add_to_signature_group "-fqnd"
                ;;
                
            -signature)
                shift && test $# -ne 0 || args_error_message "-signature"
                signature=$1
                add_to_signature_group "-signature $signature"
                ;;

            -oraclepath)
                shift && test $# -ne 0 || args_error_message "-oraclePath"
                oracle_install_path="$1"
                add_to_signature_group "-oraclePath $oracle_install_path"
                ;;

            -help)
                get_help
                get_return_code $ex_abort
                ;;

            -debug)
                debug=true
                add_to_signature_group "-debug"
                ;;

            -alluserids)
                all_user_ids=true
                add_to_signature_group "-allUserIDs"
                ;;

            -privids)
                priv_ids=true
                add_to_signature_group "-privIDs"
                ;;

            -labellingfile)
                shift && test $# -ne 0 || args_error_message "-labellingFile"
                labelling_file="$1"
                add_to_signature_group "-labellingFile $labelling_file"
                ;;

            -propertiesfile)
                shift && test $# -ne 0 || args_error_message "-propertiesFile"
                properties_file="$1"
                add_to_signature_group "-propertiesFile $properties_file"
                ;;

            -ibmonly)
                ibm_only=true
                add_to_signature_group "-ibmOnly"
                ;;

            -customeronly)
                customer_only=true
                add_to_signature_group "-customerOnly"
                ;;

            -owner)
                shift && test $# -ne 0 || args_error_message "-owner"
                mef3_owner="$1"
                add_to_signature_group "-owner $mef3_owner"
                ;;

            -libpath)
                shift && test $# -ne 0 || args_error_message "-libPath"
                lib_path="$1"
                add_to_signature_group "-libPath $lib_path"
                ;;

            *)
                join_str "unknown_parameters" ' ' "$1"
                ;;

        esac
        shift
    done

    if test "X$unknown_parameters" != "X"; then
        print_warn_ln "Following unknown parameters will not be processed: $unknown_parameters"
        print_sep_wide
    fi

}

function load_library {

    print_debug_ln "Looking for a library"

    if test "X$lib_path" = "X"; then
        lib_path="$script_path"
    fi

    lib_path_list=`printf "%s" "$lib_path" | tr ":" "\n"`

    # by default IFS split by all space characters.
    # we neeed only 'new line'
    oIFS=$IFS; IFS=$character_lf
    for path in $lib_path_list; do
        IFS=$oIFS

        # Remove last slash 
        path=`printf "%s\n" "$path" | sed -e 's/\/$//'`
        print_debug_ln "Working with: $path"

        library_path="${path}/IAMSubsystemsLibrary.sh"

        if test -f "$library_path"; then

            print_debug_ln "Found '$library_path'"
            #. "$library_path"
            print_sep_wide $status_debug

            return 0
        fi

    done

    print_error_ln "IAMSubsystemsLibrary.sh could not be found. Exiting."
    get_return_code $ex_abort

}

function prepare_parameters {

    if ! $priv_ids; then
        all_user_ids=true
    fi

    if $fqnd; then
        hostname=`hostname`
    else
        hostname=`hostname | cut -d "." -f 1`
    fi

    if test "X$output_file" != "X"; then

        is_abs=`printf "%s" "$output_file" | awk '{ if (match ($1, "^/")) { print "yes" } else { print "no" }}'`
        is_rel=`printf "%s" "$output_file" | awk '{ if (match ($1, "^\\\.\\\.?/")) { print "yes" } else { print "no" }}'`

        print_debug_ln "Is absolute path? $is_abs"
        print_debug_ln "Is relative path? $is_rel"

        if test $is_abs = "no" -a $is_rel = "no"; then
            output_file="/tmp/$output_file"
        fi

    else
        output_file="/tmp/${customer}_Oracle_${hostname}_${date}.mef3"
    fi

}

function print_params {

    function number_to_text {
        $1 && printf "$yes" || printf "$no"
    }

    print_info_ln "      SCRIPT NAME : $script_name"
    print_info_ln "   SCRIPT VERSION : $version"
    print_info_ln "            CKSUM : $cksum"
    print_info_ln "       OS CAPTION : $os_name"
    print_info_ln "       OS VERSION : $os_version"
    print_info_ln "           WHOAMI : $whoami"
    print_info_ln "         HOSTNAME : $hostname"
    print_info_ln "         CUSTOMER : $customer"
    print_info_ln "       OUTPUTFILE : $output_file"
    print_info_ln "        SIGNATURE : $signature"
    print_info_ln "            IS_AG : `number_to_text $ag`"
    print_info_ln "          IS_FQDN : `number_to_text $fqnd`"
    print_info_ln "    IS_ALLUSERIDS : `number_to_text $all_user_ids`"
    print_info_ln "       IS_PRIVIDS : `number_to_text $priv_ids`"
    print_info_ln "       IS_IBMONLY : `number_to_text $ibm_only`"
    print_info_ln "  IS_CUSTOMERONLY : `number_to_text $customer_only`"
    print_info_ln "    LABELLINGFILE : $labelling_file"
    print_info_ln "   PROPERTIESFILE : $properties_file"
    print_info_ln "   LABELLINGFIELD : Gecos"
    print_info_ln "         IS_DEBUG : `number_to_text $debug`"
    print_info_ln "  SIGNATURE_GROUP : $signature_group"
    print_info_ln "         LIB_PATH : $lib_path"
    print_info_ln "            OWNER : $mef3_owner"

    print_sep_wide

}

function check_params {

    if test "X$current_uid" != "X0"; then
        print_error_ln "Script should be executed with root privileges."
        get_return_code $ex_abort
    fi

    if $all_user_ids && $priv_ids; then
        print_error_ln "'-allUserIDs' and '-privIDs' are set. Can not use both switches together."
        get_return_code $ex_abort
    fi

    if $ibm_only && $customer_only; then
        print_error_ln "'-ibmOnly' and '-customerOnly' are set. Can not use both switches together."
        get_return_code $ex_abort
    fi

    # test statement -a statement - checks both conditions, it's not lazy
    if test "X$labelling_file" != "X" && test ! -f $labelling_file; then
        print_warn_ln "The specified labelling file '$labelling_file' is absent on this server. It won't be processed"
        labelling_file=""
    fi

    if test "X$properties_file" != "X" && test ! -f $properties_file; then
        print_warn_ln "The properties file '$properties_file' doesn't exist"
        properties_file=""
    fi

    clear_file "$output_file"

    oracle_install_path=`printf "%s\n" "$oracle_install_path" | sed -e 's/\/$//'`

}

#--------------------------------------------------------------------
# Susbsystem's functions
#--------------------------------------------------------------------

function add_to_failure_instances {

    typeset entry=$1

    print_debug_ln "Added to failure instances: $entry"

    # not critical to have duplicates
    a_append "failure_instances" "$entry"

}

function get_oracle_instances {

    # lists of pids:
    #   pid_list
    # and hash, that based on this pid:
    #   $pid -> "sid" = $sid
    #   $pid -> "home" = $home
    #   $pid -> "owner" = $owner

    print_debug_ln "Looking for DB instances"
    print_sep_slim $status_debug

    process_lines=`$ps_cmd $psargs pid,args | grep "_pmon_" | grep -v grep`

    oIFS=$IFS; IFS=$character_lf

    for line in $process_lines; do

        IFS=$oIFS

        line=`trim "$line"`
        print_debug_ln "Process line: '$line'"

        # Valid Characters in Instance Names
        # Instance names can consist only of the alphanumeric characters (A-Z, 
        # a-z, 0-9) and the $ or _ (underscore) characters.
        # There is no maximum length restriction for instance names. 
        if printf "%s\n" "$line" | awk '/^[0-9]+ *(ora|asm)_pmon_([A-Za-z0-9\$_])/ { print "yes" }' | grep -q '^yes$'; then

            pid=`printf "%s\n" "$line" | sed -e 's/[[:space:]].*//'`
            sid=`printf "%s\n" "$line" | sed -e 's/.*_pmon_//'`

            print_debug_ln "DB_TYPE_ORACLE, pid: '$pid', instance name: '$sid'"

            # pids are unique values
            a_append "pid_list" "$pid"
            h_put "$pid" "DB_INSTANCE_NAME" "$sid"

        fi

    done

    print_debug_ln "Oracle PIDS: `a_to_string "pid_list"`"
    if test `a_size "pid_list"` -eq 0; then
        print_error_ln "The necessary Sub System is not found/not installed/not started."
        get_return_code $ex_abort
    fi

}

function get_oratab_file {

    oratab_files="/etc/oratab:/var/opt/oracle/oratab"

    oIFS=$IFS; IFS=$character_colon
    for file in $oratab_files; do
        IFS=$oIFS

        if test -f "$file"; then
            oratab_file="$file"
            return
        fi

    done

    oratab_search_dirs="/usr:/opt:/etc:/var"

    oIFS=$IFS; IFS=$character_colon
    for path in $oratab_search_dirs; do
        IFS=$oIFS

        print_info_ln "Looking for oratab file in: $path"

        clear_file "$tmp_file"
        find "$path" -name "oratab" >"$tmp_file" 2>/dev/null

        if test -f "$tmp_file"; then
            while read -r line; do
                if test "X$line" != "X" && test -f $line; then
                    oratab_file="$line"
                    return
                fi
            done < "$tmp_file"
        fi

    done

    oratab_file=""
    print_warn_ln "Oratab file hasn't been found."

}

# array
#   oratab_sids_hashes (sid can contain sigis sign $)
# hash
#   otarab_sids_hash -> sid = instance name
#   otarab_sids_hash -> home = oracle home
function get_oratab_data {

    while read -r line; do

        print_debug_ln "Oratab file: $line"

        # remove commented lines
        line=`printf "$line\n" | sed -e 's/#.*//'`

        # remove spaces
        line=`trim "$line"`

        # some users customize this line and add to the end
        # various information.
        # instance_name:home:Y|N.*
        #           (inst name):(home ):(Y|N)

        if printf "$line\n" | awk '/^[^:]+:[^:]+:[Y|N].*/ { print "yes" }' | grep -q '^yes$'; then

            oratab_sid=`printf "$line\n" | cut -d: -f1`
            oratab_home=`printf "$line\n" | cut -d: -f2`

            key_for_hash=`printf "$oratab_sid" | cksum | awk '{ print $1 }'`

            # sids and hashes are unique values
            a_append "oratab_sids_hashes" "$key_for_hash"
            h_put "$key_for_hash" $DB_INSTANCE_NAME "$oratab_sid"
            h_put "$key_for_hash" $DB_HOME "$oratab_home"

        fi

    done < "$oratab_file"

    # for the first time - print the content of the oratab_data, to ensure that
    # every is fine
    print_sep_slim $status_debug

    for ora_sids_hash in `a_get_all oratab_sids_hashes`; do

        sid=`h_get "$ora_sids_hash" $DB_INSTANCE_NAME`
        home=`h_get "$ora_sids_hash" $DB_HOME`

        print_debug_ln "Oratab content: '$sid' => '$home'"

    done

}

function get_oracle_home {

    typeset pid=$1
    typeset sid=`h_get "$pid" $DB_INSTANCE_NAME`

    # script passes this variable to inner functions. it shouldn't be local ('typeset')
    oracle_home=""

    print_debug_ln "(get_oracle_home) sid: $sid, pid: $pid"

    function from_environment {

        typeset fe_var_name=$1
        typeset fe_pid=$2
        typeset temp_home=""

        print_debug_ln "Getting ORACLE_HOME from environment"

        lines=""
        temp_home=""

        case "$os_name" in

            AIX)
                lines=`$ps_cmd ewww $fe_pid | awk 'NR>1'`
                ;;

            SunOS)
                if test -x /usr/ucb/ps; then
                    lines=`/usr/ucb/ps ewww $fe_pid | awk 'NR>1'`
                fi
                ;;

            Linux)
                lines=`$ps_cmd -p $fe_pid ewww | awk 'NR>1'`
                ;;

        esac

        if test "X$lines" != "X"; then

            print_debug_ln "Working with: $lines"

            oIFS=$IFS; IFS=$character_space
            for var in $lines; do
                if printf "$var" | grep -q "^ORACLE_HOME="; then

                    temp_home=`printf "$var\n" | sed -e 's/^ORACLE_HOME=//'`
                    temp_home=`printf "$temp_home\n" | sed -e 's/[[:space:]].*$//'`

                    if test -d "$temp_home"; then
                        break
                    fi

                fi
            done
            IFS=$oIFS

        fi

        print_debug_ln "ORACLE_HOME from env :: '$temp_home'"

        eval "$fe_var_name=\"$temp_home\""

    }

    function from_oratab {

        typeset fo_var_name=$1
        typeset fo_sid=$2
        typeset temp_home=""

        print_debug_ln "Getting ORACLE_HOME from oratab file"

        IFS=$oIFS; IFS=$character_lf
        for oratab_sids_hash in `a_get_all oratab_sids_hashes`; do
            IFS=$oIFS

            oratab_sid=`h_get "$oratab_sids_hash" "$DB_INSTANCE_NAME"`

            if test "X$fo_sid" = "X$oratab_sid"; then
                temp_home=`h_get $oratab_sids_hash $DB_HOME`
                break
            fi

        done

        print_debug_ln "ORACLE_HOME from oratab :: '$temp_home'"

        eval "$fo_var_name=\"$temp_home\""

    }

    function from_params {

        typeset fp_var_name=$1
        typeset fp_pid=$2
        typeset temp_home=""

        print_debug_ln "Getting ORACLE_HOME from params"

        typeset process_lines=`$ps_cmd -p $fp_pid -o args | awk 'NR==2'`
        process_lines=`trim "$process_lines"`

        if printf "$process_lines\n" | grep -q "ORACLE_HOME="; then
            temp_home="$process_lines"
            temp_home=`printf "$temp_home\n" | sed -e 's/.*ORACLE_HOME=//'`
            temp_home=`printf "$temp_home\n" | sed -e 's/[[:space:]].*//'`
        fi

        print_debug_ln "ORACLE_HOME from params :: '$temp_home'"

        eval "$fp_var_name=\"$temp_home\""

    }

    function from_proc_info {

        typeset fpi_var_name=$1
        typeset fpi_pid=$2
        typeset temp_home=""

        print_debug_ln "Getting ORACLE_HOME from proc info"

        case "$os_name" in

            AIX)
                if test -x "/usr/bin/procwdx"; then
                    # '18121:  '
                    temp_home=`/usr/bin/procwdx $fpi_pid | sed -e 's/^[[:space:]]*[[:digit:]][[:digit:]]*:[[:space:]]*//'`
                elif test -e "/proc/${fpi_pid}/cwd"; then
                    temp_home=`ls -l /proc/${fpi_pid}/cwd | awk '{ print $NF }'`
                fi
                ;;

            Linux)
                if test -e "/proc/${fpi_pid}/cwd"; then
                    temp_home=`ls -l /proc/${fpi_pid}/cwd | awk '{ print $NF }'`
                fi
                ;;

            SunOS)
                if command -v "pwdx" >/dev/null 2>&1; then
                    # '18121: /full/path/goes/here'
                    temp_home=`pwdx $fpi_pid | sed -e 's/^[[:space:]]*[[:digit:]][[:digit:]]*:[[:space:]]*//'`
                fi
                ;;

            HP-UX)

                # using lsof for this task
                # looking for lsof
                lsof_path=""
                absolute_path_for_command "lsof_path" "lsof"

                if test "X$lsof_path" = "X"; then

                    swlist_path=""
                    absolute_path_for_command "swlist_path" "swlist"

                    if test "X$swlist_path" = "X"; then
                        print_warn_ln "Cannot find installed swlist"
                        break
                    fi

                    clear_file "$tmp_file"
                    $swlist_path lsof > $tmp_file

                    while read -r line; do

                        print_debug_ln "swlist: '$line'"

                        # remove commented lines
                        line=`printf "$line\n" | sed -e 's/#.*//'`

                        if printf "$line\n" | grep -qi '^[[:space:]]*lsof'; then

                            print_debug_ln "lsof has been found"
                            print_debug_ln "getting info about lsof"

                            clear_file "$tmp_file_2"

                            $swlist_path -v lsof > "$tmp_file_2"

                            while read -r lsof_info; do

                                print_debug_ln "pkg info: '$lsof_info'"

                                if printf "$lsof_line\n" | grep -q '^[[:space:]]*location[[:space:]]'; then

                                    lsof_path=`printf "$lsof_info\n" | sed -e 's/^[[:space:]]*localtion[[:space:]]*//;s/[[:space:]]*$//'`
                                    lsof_path="${lsof_path}/lsof"

                                    print_debug_ln "Found path: '$lsof_path'"

                                    break 2

                                fi

                            done

                        fi

                    done < $tmp_file

                    clear_file "$tmp_file"
                    clear_file "$tmp_file_2"

                fi

                if test "X$lsof_path" != "X"; then
                    temp_home=`$lsof_path -p $fpi_pid 2>/dev/null | awk 'NR==2 { print $NF }'`
                fi

                ;;

            *)
                print_warn_ln "Unknown OS: $os_name"
                ;;

        esac

        print_debug_ln "(pre) ORACLE_HOME from proc info :: '$temp_home'"

        temp_home=`printf "$temp_home\n" | sed -e 's/\/$//;s/\/dbs$//'`
        print_debug_ln "ORACLE_HOME from proc info :: '$temp_home'"

        eval "$fpi_var_name=\"$temp_home\""

    }

    function from_fuser {

        typeset ff_var_name=$1
        typeset ff_pid=$2
        typeset temp_home=""

        print_debug_ln "Getting ORACLE_HOME from fuser"

        fuser_path=""
        absolute_path_for_command "fuser_path" "fuser"

        if test "X$fuser_path" = "X"; then
            print_warn_ln "Fuser doesn't exist"
            eval "$ff_var_name=\"$temp_home\""
            return
        fi

        clear_file "$tmp_file"

        case "$os_name" in
            AIX)
                mount | awk '$1~/\/dev/{print $2}' > "$tmp_file"
                ;;
            Linux)
                /bin/mount | grep '^/dev' | sed 's/^.*on \(.*\) type.*$/\1/' > "$tmp_file"
                ;;
            SunOS)
                /usr/sbin/mount | grep 'on /dev' | sed 's/ on \/dev.*$//' > "$tmp_file"
                ;;
            HP-UX)
                /usr/sbin/mount | grep 'on /dev' | sed 's/ on \/dev.*$//' > "$tmp_file"
                ;;
            *)
                print_warn_ln "Unknown OS"
                eval "$ff_var_name=\"$temp_home\""
                return
                ;;
        esac

        while read -r device; do

            print_debug_ln "Found device: '$device'"

            fuser_line=`$fuser_path -c "$device" 2>/dev/null`
            fuser_line=`trim "$fuser_line"`

            print_debug_ln "Found pids on this device: '$fuser_line'"

            for pid_on_device in `echo "$fuser_line" | tr ' ' '\n'`; do

                if test "X$ff_pid" = "X$pid_on_device"; then

                    clear_file "$tmp_file_2"
                    find "$device" -xdev -name oracle >"$tmp_file_2" 2>/dev/null

                    while read -r found_file; do

                        print_debug_ln "Found file: '$found_file'"

                        file_processes=`$fuser_path -f "$found_file" 2>/dev/null`
                        file_processes=`trim "$file_processes"`

                        print_debug_ln "File's processes: '$file_processes'"

                        for file_pid in `echo $file_processes | tr ' ' '\n'`; do

                            if test "X$file_pid" = "X$ff_pid"; then

                                temp_home="$found_file"
                                temp_home=`printf "$temp_home\n" | sed -e 's/\/bin\/oracle//'`

                                print_debug_ln "Process matched: '$file_pid'"
                                print_debug_ln "Home: '$temp_home'"

                                break 4

                            fi

                        done

                    done < $tmp_file_2

                fi

            done

        done < $tmp_file


        print_debug_ln "ORACLE_HOME from params :: '$temp_home'"

        eval "$ff_var_name=\"$temp_home\""

    }

    from_environment "oracle_home" "$pid"

    if test "X$oracle_home" = "X"; then
        from_oratab "oracle_home" "$sid"
    fi

    # lightweight first
    if test "X$oracle_home" = "X"; then
        from_params "oracle_home" "$pid"
    fi

    # proc
    if test "X$oracle_home" = "X"; then
        from_proc_info "oracle_home" "$pid"
    fi

    # heavyweight method
    if test "X$oracle_home" = "X"; then
        from_fuser "oracle_home" "$pid"
    fi

    h_put "$pid" "$DB_HOME" "$oracle_home"

}

function check_instances_with_oratab {

    print_debug_ln "Checking the oratab file"

    for oratab_sids_hash in `a_get_all "oratab_sids_hashes"`; do

        oratab_sid=`h_get $oratab_sids_hash "$DB_INSTANCE_NAME"`
        oratab_home=`h_get $oratab_sids_hash "$DB_HOME"`

        print_debug_ln "line: $oratab_sid:$oratab_home"

        if test "X$oratab_sid" = 'X*'; then

            matched=0

            for pid in `a_get_all "pid_list"`; do

                stored_home=`h_get $pid $DB_HOME`
                if test "X$stored_home" = "X$oratab_home"; then
                    matched=1
                    break
                fi

            done

            if test $matched -eq 0; then
                 add_to_failure_instances "$oratab_sid:$oratab_home"
            fi

        else

            matched=0

            for pid in `a_get_all "pid_list"`; do

                stored_sid=`h_get $pid $DB_INSTANCE_NAME`

                if test "X$stored_sid" = "X$oratab_sid"; then
                    matched=1
                    break
                fi

            done

            if test $matched -eq 0; then
                 add_to_failure_instances "$oratab_sid:$oratab_home"
            fi

        fi

    done

}

function parse_config_file {

    typeset lib="${1}/rdbms/lib"

    ss_dba_grp=""
    ss_oper_grp=""

    config_c="${lib}/config.c"
    config_s="${lib}/config.s"

    files="${config_c}|${config_s}"

    oIFS=$IFS
    IFS=\|

    for config in $files; do

        print_debug_ln "Processing '$config'. Searching for '#define'."

        if test ! -f "$config"; then
            print_info_ln "Config file '$config' does not exists"
            continue
        fi

        IFS=$character_lf

        while read -r line; do

            print_debug_ln "line: '$line'"

            if printf "%s" "$line" | grep -q "^[[:space:]]*#define[[:space:]]*SS_DBA_GRP"; then

                ss_dba_grp=`printf "%s\n" "$line" | sed -e 's/^[[:space:]]*#define[[:space:]]*SS_DBA_GRP[[:space:]]*//' -e 's/[[:space:]]*$//'`
                # trim quotation marks
                ss_dba_grp=`printf "%s\n" "$ss_dba_grp" | sed -e 's/^"//' -e 's/"$//'`
                print_debug_ln "After trim: '$ss_dba_grp'"

                # can ends with \0
                # ss_dba_grp=`printf "%s" "$ss_dba_grp" | tr -d '\000'`
                # it also removes zeros
                ss_dba_grp=`printf "%s\n" "$ss_dba_grp" | sed -e 's/\\\0$//'`
                print_debug_ln "Get ss_dba_grp: '$ss_dba_grp'"

            elif printf "%s" "$line" | grep -q "^[[:space:]]*#define[[:space:]]*SS_OPER_GRP"; then

                ss_oper_grp=`printf "%s\n" "$line" | sed -e 's/^[[:space:]]*#define[[:space:]]*SS_OPER_GRP[[:space:]]*//' -e 's/[[:space:]]*$//'`
                # trim quotation marks
                ss_oper_grp=`printf "%s\n" "$ss_oper_grp" | sed -e 's/^"//' -e 's/"$//'`
                print_debug_ln "After trim: '$ss_oper_grp'"

                # can ends with \0
                # ss_oper_grp=`printf "%s" "$ss_oper_grp" | tr -d '\000'`
                # it also removes zeros
                ss_oper_grp=`printf "%s\n" "$ss_oper_grp" | sed -e 's/\\\0$//'`
                print_debug_ln "Get ss_oper_grp: '$ss_oper_grp'"
            fi

            if test "X$ss_dba_grp" != "X" -a "X$ss_oper_grp" != "X"; then
                break
            fi

        done < "$config"

        if test "X$ss_dba_grp" != "X" -a "X$ss_oper_grp" != "X"; then
            break
        fi

    done

    IFS=$oIFS

    if test "X$ss_dba_grp" = "X" -a "X$ss_oper_grp" = "X" -a -f "$config_s"; then

        print_info_ln "Run special algorithm for detecting Oracle groups"

        words="\.string|\.ascii"

        oIFS=$IFS; IFS=\|
        for word in $words; do

            print_debug_ln "Looking for the word '$word'"

            matched_times=0

            ooIFS=$IFS; IFS=$character_lf
            while read -r line; do

                if $debug; then
                    printf "[DEBUG] before line: '%s'\n" "$line"
                fi

                if printf "%s" "$line" | grep -q '\\0'; then
                    line=`printf "%s\n" "$line" | sed -e 's/\\\0//g'`
                fi

                if $debug; then
                    printf "[DEBUG] after line: '%s'\n" "$line"
                fi

                if printf "%s" "$line" | grep -q "^.*[[:space:]]*$word"; then

                    if test $matched_times -eq 0; then
                        ss_dba_grp=`printf "%s\n" "$line" | sed -e "s/^.*[[:space:]]*$word[[:space:]][[:space:]]*//" -e "s/[[:space:]]*\$//"`
                        # config file can contains quotes or not
                        ss_dba_grp=`printf "%s\n" "$ss_dba_grp" | sed -e 's/^"//' -e 's/"$//'`

                        print_debug_ln "Get ss_dba_grp: '$ss_dba_grp'"

                    else
                        ss_oper_grp=`printf "%s\n" "$line" | sed -e "s/^.*[[:space:]]*$word[[:space:]][[:space:]]*//" -e "s/[[:space:]]*\$//"`
                        # config file can contains quotes or not
                        ss_oper_grp=`printf "%s\n" "$ss_oper_grp" | sed -e 's/^"//' -e 's/"$//'`

                        print_debug_ln "Get ss_oper_grp: '$ss_oper_grp'"

                    fi

                    if test "X$ss_dba_grp" != "X" -a "X$ss_oper_grp" != "X"; then
                        IFS=$oIFS
                        break 2
                    fi

                    let 'matched_times += 1'

                fi

            done < "$config_s"

            IFS=$ooIFS

        done

        IFS=$oIFS

    fi

    return 0

}

# takes 2 parameters
#   $1 - place where the method should store users from a group
#   $2 - the name of the OS level group
function get_users_from_a_group {

    typeset store_group=$1
    typeset group=$2

    # Add user to a set.
    # Takes 2 parameters:
    #   $1 - list of users separated by comma ','
    #   $2 - the name of the group
    # 
    #   add_users 'user1,user2,user3' 'DBA'
    #   add_users 'user2' 'DBA'
    function add_users {

        # If user_names string is empty, return with warning
        test "X$1" = "X" && return 1

        oIFS=$IFS; IFS=$character_comma
        # Split string by comma (it's easest way to use this method, because
        # when we get users from passwd file or from getent, these names are
        # separated by comma.
        for user in $1; do

            print_debug_ln "Working with the user '$user'"

            test "X$user" = "X" && continue

            # TODO: append unique
            a_append_uniq "$2" "$user"

        done

        IFS=$oIFS

    }

    test "X$group" = "X" && return 1

    if test "X$os_name" != "XHP-UX" -a "X$os_name" != "XAIX"; then

        if which getent 1>/dev/null 2>&1; then

            print_debug_ln "'getent' has been found"

            users=`getent group "$group" | awk 'BEGIN { FS=":" }; { print $NF }'`
            print_debug_ln "Users from getent group: '$users'"

            add_users "$users" "$store_group"

            group_id=`getent group "$group" | cut -d ":" -f3`
            users=`getent passwd | grep -E "^[^:]*:[^:]*:[^:]*:${group_id}:.*" | cut -d ":" -f1 | tr '\n' ','`
            print_debug_ln "Users from getent passwd: '$users'"

            add_users "$users" "$store_group"

            # if getent's dbs are broken, it might return nothing
            # so checking here, if user list is not empty - exit from the function
            # otherwise trying to read /etc/passwd (the code below)
            if test `a_size "$store_group"` -ne 0; then
                return 0
            fi

        fi
    fi

    # If OS is hpux or aix, or getent is not installed on the machine
    users=`cat /etc/group | grep -E "^${group}:" | awk 'BEGIN {FS = ":"}; { print $NF }'`
    print_debug_ln "Users from group file: '$users'"

    add_users "$users" "$store_group"

    group_id=`grep -E ^${group}: /etc/group | cut -d ":" -f3`
    users=`cat /etc/passwd | grep -E "^[^:]*:[^:]*:[^:]*:${group_id}:.*" | cut -d ":" -f1 | tr '\n' ','`
    print_debug_ln "Users from passwd file: '$users'"

    add_users "$users" "$store_group"

}

function store_user_role {

    typeset user=$1
    typeset role=$2

    oIFS=$IFS; IFS=$character_lf

    user_hash=`printf "%s" "$user" | cksum | awk '{ print $1 }'`

    # append unique
    # if test `a_count "user_list" "$user_hash"` -eq 0; then
    # a_count checks all values
    # a_index_of looks for the first match
    if test `a_index_of "user_list" "$user_hash"` -eq '-1'; then

        print_debug_ln "store_user_role :: Add to array of hashes: '$user_hash'"
        print_debug_ln "store_user_role :: Add to hash: '$user_hash' name '$user'"

        a_append "user_list" "$user_hash"
        h_put "$user_hash" "name" "$user"

    fi

    stored_roles=`h_get "$user_hash" "roles"`
    if test "X$stored_roles" = "X"; then
        h_put "$user_hash" "roles" "$role"
    else
        h_put "$user_hash" "roles" "${stored_roles},${role}"
    fi

    print_debug_ln "store_user_role :: Add to hash: '$user_hash' role '$role'"

    IFS=$oIFS

}

function store_user_privileges {

    typeset user=$1
    typeset privilege=$2

    oIFS=$IFS; IFS=$character_lf

    user_hash=`printf "%s" "$user" | cksum | awk '{ print $1 }'`

    # if test `a_count "user_list" "$user_hash"` -eq 0; then
    # append unique
    # a_count ckecks all values
    # a_index_of looks for the first match
    if test `a_index_of "user_list" "$user_hash"` -eq '-1'; then

        print_debug_ln "store_user_privileges :: Add to array of hashes: '$user_hash'"
        print_debug_ln "store_user_privileges :: Add to hash: '$user_hash' name '$user'"

        a_append "user_list" "$user_hash"
        h_put "$user_hash" "name" "$user"

    fi

    stored_privs=`h_get "$user_hash" "privs"`
    if test "X$stored_privs" = "X"; then
        h_put "$user_hash" "privs" "$privilege"
    else
        h_put "$user_hash" "privs" "${stored_privs},${privilege}"
    fi

    print_debug_ln "store_user_privileges :: Add to hash: '$user_hash' privilege '$privilege'"

    IFS=$oIFS
}

function store_user_status {

    typeset user=$1
    typeset status=$2

    user_hash=`printf "%s" "$user" | cksum | awk '{ print $1 }'`

    if test `a_count "user_list" "$user_hash"` -eq 0; then
        a_append "user_list" "$user_hash"
        h_put "$user_hash" "name" "$user"
    fi

    h_put "$user_hash" "status" "$status"

    print_debug_ln "store_user_status :: Add to hash: '$user_hash' status '$status'"

}

function get_oracle_owner {

    typeset goo_pid=$1
    typeset instance_owner=`ps -p $pid -o user | awk 'NR==2'`

    instance_owner=`trim $instance_owner`
    print_debug_ln "(get_oracle_owner) instance owner: $instance_owner"

    oIFS=$IFS; IFS=$character_lf
    for user_hash in `a_get_all "user_list"`; do
        IFS=$oIFS

        user=`h_get "$user_hash" "name"`
        print_debug_ln "hash: $user_hash, user: $user"

        if test "X$user" = "X$instance_owner"; then

            print_debug_ln "Matched. Using '$user' as owner"
            h_put "$goo_pid" "$DB_OWNER" "$user"

            return 0

        fi
    done

    print_debug_ln "Can't detect correct oracle owner. Getting the first user from the list"

    # Otherwise get the first array element
    oIFS=$IFS; IFS=$character_lf
    for user_hash in `a_get_all "user_list"`; do
        IFS=$oIFS

        user=`h_get "$user_hash" "name"`
        print_debug_ln "hash: $user_hash, user: $user"

        h_put "$goo_pid" "$DB_OWNER" "$user"

        break

    done

}

function prepare_sql_script {

    typeset statement=$1

    clear_file "$sql_script_file"

    # http://www.orafaq.com/wiki/SQL*Plus_FAQ
    printf "SET WRAP OFF;\n" >> "$sql_script_file"
    printf "SET PAGESIZE 50000;\n" >> "$sql_script_file"
    printf "SET LINESIZE 32767;\n" >> "$sql_script_file"
    printf "SET LONG 32767;\n" >> "$sql_script_file"
    printf "SET LONGCHUNKSIZE 32767;\n" >> "$sql_script_file"
    printf "SET TAB OFF;\n" >> "$sql_script_file"
    printf "$statement\n" >> "$sql_script_file"
    printf "quit;\n" >> "$sql_script_file"

    chmod 0777 "$sql_script_file" 1>/dev/null 2>&1

    if $debug; then
        while read -r line; do
            printf "[DEBUG] SQL script: %s\n" "$line"
        done < $sql_script_file
    fi

}

function prepare_shell_command {

    typeset var=$1
    typeset pid=$2
    typeset statement=$3

    typeset sid=`h_get $pid $DB_INSTANCE_NAME`
    typeset home=`h_get $pid $DB_HOME`
    typeset owner=`h_get $pid $DB_OWNER`

    cmd=""
    get_user_shell "shell" "$owner"

    if printf "%s\n" "$shell" | grep -q "csh"; then
        # in eval \\ -> \ and \" -> "       --- \"     after eval
        cmd="su - $owner -c \\\""
        # in eval \\ -> \, \\ -> \, \\ -> \, \" -> " --- \\\"     after eval
        cmd="${cmd}setenv ORACLE_HOME \\\\\\\"$home\\\\\\\";"
        cmd="${cmd} setenv ORACLE_SID \\\\\\\"$sid\\\\\\\";"
        # in eval \\ -> \, \\ -> \, \\ -> \, \$ -> $ --- \\\$     after eval
        cmd="${cmd} setenv PATH \\\\\\\"$home/bin:\\\\\\\${PATH}\\\\\\\";"
        cmd="${cmd} test \\\\\\\$?LD_LIBRARY_PATH = 0 && setenv LD_LIBRARY_PATH \\\\\\\"$home/lib\\\\\\\" || setenv LD_LIBRARY_PATH \\\\\\\"$home/lib:\\\\\\\${LD_LIBRARY_PATH}\\\\\\\";"
        cmd="${cmd} $statement\\\""
    else
        cmd="su $owner -c \\\""
        cmd="${cmd}ORACLE_HOME=\\\\\\\"$home\\\\\\\"; export ORACLE_HOME;"
        cmd="${cmd} ORACLE_SID=\\\\\\\"$sid\\\\\\\"; export ORACLE_SID;"
        cmd="${cmd} PATH=\\\\\\\"$home/bin:\\\\\\\$PATH\\\\\\\"; export PATH;"
        cmd="${cmd} LD_LIBRARY_PATH=\\\\\\\"$home/lib:\\\\\\\$LD_LIBRARY_PATH\\\\\\\";"
        cmd="${cmd} export LD_LIBRARY_PATH;"
        cmd="${cmd} $statement\\\""
    fi

    eval "$var=\"$cmd\""

}

function is_oracle_version_valid {

    typeset pid=$1

    sh_statement="sqlplus -v"

    prepare_shell_command "shell_cmd" "$pid" "$sh_statement"
    print_debug_ln "Run: $shell_cmd"

    eval "$shell_cmd > $tmp_file 2>&1"

    while read -r line; do

        print_debug_ln "Working with: $line"

        db_version=""
        db_version=`printf "%s\n" "$line" | grep "Release.*Production" | sed -e 's/^.*Release[[:space:]]*//' -e 's/[[:space:]]*Production.*$//' -e 's/[[:space:]]*-$//'`

        test "X${db_version}" = "X" && continue

        major_version=`printf "%s\n" "$db_version" | cut -d "." -f1`

        print_debug_ln "Oracle version: '${db_version}'"
        print_debug_ln "Major version: '${major_version}'"

        if test "X$major_version" = "X9" -o "X$major_version" = "X10" -o "X$major_version" = "X11"; then
            return $TRUE
        fi

    done < $tmp_file

    return $FALSE

}

function get_remote_pwd_file_type {

    typeset pid=$1

    # global variable
    # Todo: make local
    remote_login_password_type=""

    sql_statement="show parameter remote_login_passwordfile;"
    prepare_sql_script "$sql_statement"

    sh_statement="sqlplus \\\\\\\"/ as sysdba\\\\\\\" @$sql_script_file"
    prepare_shell_command "shell_cmd" "$pid" "$sh_statement"
    eval "result=\`$shell_cmd\`"

    oIFS=$IFS
    IFS=$character_lf

    for line in $result; do

        print_debug_ln "Script output: '$line'"

        if printf "%s\n" "$line" | grep -q "remote_login_passwordfile"; then
            remote_login_password_type=`printf "%s\n" "$line" | awk '{ print $NF }'`
            break
        fi

    done

    IFS=$oIFS

    if test "X$remote_login_password_type" = "X"; then
        print_debug_ln "Parameter 'remote_login_passwordfile' is empty"
        remote_login_password_type="NONE"
    fi

}

function get_db_role {

    typeset pid=$1

    db_type=""

    sql_statement="select database_role from v\$database;"
    prepare_sql_script "$sql_statement"

    sh_statement="sqlplus \\\\\\\"/ as sysdba\\\\\\\" \@$sql_script_file"
    prepare_shell_command "shell_cmd" "$pid" "$sh_statement"
    eval "result=\`$shell_cmd\`"

    oIFS=$IFS; IFS=$character_lf

    is_data=$FALSE
    header_mark=$FALSE

    for line in $result; do

        print_debug_ln "Script output: '$line'"

        if test $is_data -eq $FALSE; then
            # first line
            if printf "%s" "$line" | grep -q "DATABASE_ROLE"; then
                # skipping this line (it's header)
                header_mark=$TRUE
                continue
            fi
            # second line
            if test $header_mark -eq $TRUE; then
                # skipping this line (separator line)
                is_data=$TRUE
                continue
            fi
        fi

        if printf "%s" "$line" | grep -q "rows selected"; then
            # last line
            break
        fi

        # data
        if test $is_data -eq $TRUE; then
            line=`trim "$line"`
            if test "X$line" != "X"; then
                db_type="$line"
                break
            fi
        fi

    done

    IFS=$oIFS

}

function get_pwd_file_auth_info {

    typeset pid=$1

    sql_statement="select u.username, u.sysdba, u.sysoper"
    sql_statement="${sql_statement} from v\$pwfile_users u"
    sql_statement="${sql_statement} where (u.sysdba = 'TRUE' or u.sysoper = 'TRUE');"
    prepare_sql_script "$sql_statement"

    sh_statement="sqlplus \\\\\\\"/ as sysdba\\\\\\\" \@$sql_script_file"
    prepare_shell_command "shell_cmd" "$pid" "$sh_statement"


    print_debug_ln "Running: $shell_cmd"
    clear_file $tmp_file

    # because of memory restrictions, some interpreters on a AIX machines
    # can interupt the process

    # eval "result=\`$shell_cmd\`"
    eval "$shell_cmd > $tmp_file 2>&1"

    oIFS=$IFS; IFS=$character_lf

    is_data=$FALSE
    header_mark=$FALSE

    while read -r line; do

        print_debug_ln "Script output: '$line'"

        if test $is_data -eq $FALSE; then
            # first line
            if printf "%s" "$line" | grep -q "USERNAME[[:space:]][[:space:]]*SYSDB[[:space:]][[:space:]]*SYSOP"; then
                # skipping this line (it's header)
                header_mark=$TRUE
                continue
            fi
            # second line
            if test $header_mark -eq $TRUE; then
                # skipping this line (separator line)
                is_data=$TRUE
                continue
            fi
        fi

        if printf "%s" "$line" | grep "rows selected"; then
            # last line
            break
        fi

        # data
        if test $is_data -eq $TRUE; then

            line=`trim "$line"`

            if test "X$line" != "X"; then
                # Can contain the sigil sign '$'
                user=`printf "%s" "$line" | awk '{ print $1 }' | sed -e 's/\\$/\\\\$/g'`
                is_dba=`printf "%s" "$line" | awk '{ print $2 }'`
                is_oper=`printf "%s" "$line" | awk '{ print $3 }'`

                if test "X$user" = "X" -o "X$is_dba" = "X" -o "X$is_oper" = "X"; then
                    print_warn_ln "Wrong line definition: '$line'"
                    continue
                fi

                if test $is_dba = "TRUE"; then
                    store_user_role "$user" "SYSDBA"
                    store_user_privileges "$user" "SYSDBA"
                fi

                if test $is_dba = "TRUE"; then
                    store_user_role "$user" "SYSOPER"
                    store_user_privileges "$user" "SYSOPER"
                fi

            fi

        fi

    done < "$tmp_file"

    IFS=$oIFS

}

function get_dba_users {

    typeset pid=$1

    sql_statement="select grantee, account_status"
    sql_statement="${sql_statement} from dba_role_privs, dba_users"
    sql_statement="${sql_statement} where granted_role = 'DBA' and grantee=username;"
    prepare_sql_script "$sql_statement"

    sh_statement="sqlplus \\\\\\\"/ as sysdba\\\\\\\" \@$sql_script_file"
    prepare_shell_command "shell_cmd" "$pid" "$sh_statement"

    print_debug_ln "Runnning: $shell_cmd"

    eval "result=\`$shell_cmd\`"

    oIFS=$IFS; IFS=$character_lf

    is_data=$FALSE
    header_mark=$FALSE

    for line in $result; do

        print_debug_ln "Script output: '$line'"


        if test $is_data -eq $FALSE; then
            # first line
            if printf "%s" "$line" | grep -q "GRANTEE[[:space:]][[:space:]]*ACCOUNT_STATUS"; then
                # skipping this line (it's header)
                header_mark=$TRUE
                continue
            fi
            # second line
            if test $header_mark -eq $TRUE; then
                # skipping this line (separator line)
                is_data=$TRUE
                continue
            fi
        fi

        if printf "%s" "$line" | grep -q "rows selected"; then
            # last line
            break
        fi

        # data
        if test $is_data -eq $TRUE; then

            line=`trim "$line"`

            if test "X$line" != "X"; then
                # assume that user name doesn't contain spaces
                # can contain sigil sign
                user=`printf "%s\n" "$line" | awk '{ print $1 }' | sed -e 's/\\$/\\\\$/g'`
                account_status=`printf "%s\n" "$line" | awk '{ $1 = ""; print }'`
                account_status=`trim "$account_status"`

                if test "X$user" = "X" -o "X$account_status" = "X"; then
                    print_warn_ln "Wrong line definition: '$line'"
                    continue
                fi

                print_debug_ln "User: '$user'; status: '$account_status'"

                store_user_role "$user" "DBA"
                store_user_privileges "$user" "DBA"
                store_user_status "$user" "$account_status"

            fi
        fi

    done

    IFS=$oIFS

}

function get_all_users {

    typeset pid=$1

    sql_statement="select"\
" distinct grantee,"\
" privilege,"\
" 'privilege' as auth_type,"\
" account_status"\
" from"\
" dba_sys_privs, dba_users"\
" where"\
" grantee=username"\
" union all"\
" select"\
" grantee,"\
" granted_role,"\
" 'role' as auth_type,"\
" account_status"\
" from"\
" dba_role_privs, dba_users"\
" where"\
" grantee=username"\
" union all"\
" select"\
" distinct username,"\
" 'NOPRIVILEGE',"\
" 'privilege',"\
" account_status"\
" from"\
" dba_users usr"\
" where"\
" NOT EXISTS"\
" ("\
"select"\
" distinct grantee"\
" from"\
" dba_sys_privs"\
" where"\
" grantee=usr.username"\
" union all"\
" select"\
" distinct grantee"\
" from"\
" dba_role_privs"\
" where"\
" grantee=usr.username);"

    prepare_sql_script "$sql_statement"

    sh_statement="sqlplus \\\\\\\"/ as sysdba\\\\\\\" \@$sql_script_file"
    prepare_shell_command "shell_cmd" "$pid" "$sh_statement"

    print_info_ln "Running: $shell_cmd"

    eval "result=\`$shell_cmd\`"

    oIFS=$IFS; IFS=$character_lf

    is_data=$FALSE
    header_mark=$FALSE

    for line in $result; do

        print_debug_ln "Script output: '$line'"


        if test $is_data -eq $FALSE; then
            # first line
            if printf "%s" "$line" | grep -q "GRANTEE[[:space:]][[:space:]]*PRIVILEGE[[:space:]][[:space:]]*AUTH_TYPE[[:space:]][[:space:]]*ACCOUNT_STATUS"; then
                # skipping this line (it's header)
                header_mark=$TRUE
                continue
            fi
            # second line
            if test $header_mark -eq $TRUE; then
                # skipping this line (separator line)
                is_data=$TRUE
                continue
            fi
        fi

        if printf "%s" "$line" | grep -q "rows selected"; then
            # last line
            break
        fi

        # data
        if test $is_data -eq $TRUE; then

            line=`trim "$line"`

            if test "X$line" != "X"; then

                # assume that user name doesn't contain spaces
                #user=`printf "%s" "$line" | awk '{ print $1 }' | sed -e 's/\\$/\\\\$/g'`
                user=`printf "%s" "$line" | awk '{ print $1 }'`

                # remove user from the line
                line=`printf "%s" "$line" | awk '{ $1=""; print }'`
                group_type=""

                # is it a role
                if printf "%s" "$line" | grep -q "[[:space:]]role[[:space:]]"; then
                    group_type="role"
                    line=`printf "%s\n" "$line" | sed -e 's/[[:space:]]role[[:space:]]/ '''group_type''' /'`
                elif printf "%s" "$line" | grep -q "[[:space:]]privilege[[:space:]]"; then
                    group_type="privilege"
                    line=`printf "%s\n" "$line" | sed -e 's/[[:space:]]privilege[[:space:]]/ '''group_type''' /'`
                else
                    print_warn_ln "Incorrect auth_type. Skip this line."
                    continue
                fi

                status=`printf "%s\n" "$line" | sed -e 's/^.*'''group_type'''//'`
                status=`trim "$status"`

                group=`printf "%s\n" "$line" | sed -e 's/'''group_type'''.*$//'`
                group=`trim "$group"`

                print_debug_ln "User: '$user'; status: '$status'"

                if test "X$group_type" = "Xrole"; then

                    store_user_role "$user" "$group"

                    if test "X$group" = "XDBA"; then
                        store_user_privileges "$user" "$group"
                    fi

                elif test "X$group_type" = "Xprivilege" -a "X$group" != "XNOPRIVILEGE"; then
                    store_user_privileges "$user" "$group"
                fi

                store_user_status "$user" "$status"

            fi
        fi

    done

    IFS=$oIFS

}

function check_on_existing_user {

    typeset user=$1
    typeset return_val=$2

    print_debug_ln "Checking user: '$user', saving in the '$return_val'"

    # TODO: check users through getent
    while IFS=: read -r pwd_user passwd uid gid gecos home shell; do
        if test "$user" = "$pwd_user"; then
            print_debug_ln "The user has been found in the passwd file"
            eval "$return_val=$TRUE"
            return
        fi
    done < "/etc/passwd"
    eval "$return_val=$FALSE"

}

function open_ldap_detector {

    NSSWITCH_CONF="/etc/nsswitch.conf"

    if test -f "$NSSWITCH_CONF"; then
        if cat $NSSWITCH_CONF | grep -q "passwd:.*files.*ldap"; then
            open_ldap_is_used=$TRUE
        fi
    fi

    LDAP_CONFIG="/etc/ldap.conf"
    if test -f "$LDAP_CONFIG"; then
        # The distinguished name to bind to the server with
        OPEN_LDAP_BINDDN=`cat "$LDAP_CONFIG" | grep '^[[:space:]]*binddn' | awk '{ print $2 }'`
        # The credentials to bind with
        OPEN_LDAP_BINDPW=`cat "$LDAP_CONFIG" | grep  '^[[:space:]]*bindpw' | awk '{ print $2 }'`
    fi

}

function open_ldap_get_description {

    typeset user=$1
    typeset labelling_field=$2

    typeset search_cmd="$ldap_search_cmd -Z -LLL"
    typeset search_object="uid=$user"
    typeset error_out="/tmp/openldap.err"

    if test "X$OPEN_LDAP_BINDDN" != "X" -a "X$OPEN_LDAP_BINDPW" != "X"; then
        search_cmd="$search_cmd -D \"$OPEN_LDAP_BINDDN\" -w \"$OPEN_LDAP_BINDPW\""
    fi

    if test "X$labelling_field" = "X"; then
        LDAP_USER_DESCRIPTION=`$search_cmd "($search_object)" 2>"$error_out" | cut -d ":" -f2`
    else
        LDAP_USER_DESCRIPTION=`$search_cmd "($search_object)" 2>"$error_out" | grep "${labelling_field}:" | cut -d ":" -f2`
    fi

    if test "X$LDAP_USER_DESCRIPTION" != "X"; then
        LDAP_USER_DESCRIPTION=`trim "$LDAP_USER_DESCRIPTION"`
    fi

    if $debug && -a -s "$error_out"; then
        while read -r line; do
            printf "[DEBUG] LDAP ERROR: '$line'"
        done < "$error_out"
    fi

}

function is_ag_data_correct {

    # labelling data
    data=`trim "$1"`
    value="$2"

    # set flag to false
    is_ag_data_correct=$FALSE

    # PSC country code contains 3 alphanumeric characters
    psc_matched=`printf "%s" "$data" | grep -w "[a-zA-Z0-9]\{3\}\/[INTECVFS]\/[^\/]*\/[^\/]*\/.*"`
    # ISO country code contains 2 alphanumeric characters
    iso_matched=`printf "%s" "$data" | grep -w "[a-zA-Z]\{2\}\/[INTECVFS]\/[^\/]*\/[^\/]*\/.*"`

    # if one of it is matched
    if test "X$psc_matched" != "X" -o "X$iso_matched" != "X"; then

        proc_line=""

        if test "X$psc_matched" != "X"; then
            proc_line=`printf "%s\n" "$data" | sed -n 's/.*\([a-zA-Z0-9]\{3\}\/[INTECVFS]\/[^\/]*\/[^\/]*\/.*\)/\1/p'`
        else
            proc_line=`printf "%s\n" "$data" | sed -n 's/.*\([a-zA-Z]\{2\}\/[INTECVFS]\/[^\/]*\/[^\/]*\/.*\)/\1/p'`
        fi

        owner_type=`printf "%s\n" "$proc_line" | cut -d "/" -f2`
        owner_serial=`printf "%s\n" "$proc_line" | cut -d "/" -f3`

        if test "$owner_type" = "C" -o "$owner_type" = "V"; then
            is_ag_data_correct=$TRUE

        elif test "$owner_type" = "I" -o "$owner_type" = "N" -o "$owner_type" = "T" -o "$owner_type" = "E"; then
            if `printf "%s" "$owner_serial" |  grep -vq "^\*.*"` && test "${#owner_serial}" -eq 6; then
                is_ag_data_correct=$TRUE
            else
                is_ag_data_correct=$FALSE
            fi

        elif test "$owner_type" = "F" -o "$owner_type" = "S"; then
            if `printf "%s" "$owner_serial" | grep -q "^\*.*"`; then
                is_ag_data_correct=$TRUE
            else
                is_ag_data_correct=$FALSE
            fi
        fi
    fi

    eval "$value=$is_ag_data_correct"

}

# ticket 957
# user added lines with instance names in upper case to the labelling file,
# but real instances are in lower case
#
# so all instance names are changing to upper case here

function get_labelling_from_file {

    label_value="$1"
    labelling_file="$2"
    label_user="$3"
    label_instance="$4"

    # change case of label_instance:
    label_instance=`printf "%s\n" "$label_instance" | tr '[:lower:]' '[:upper:]'`

    if test `a_size "labelling_data"` -eq 0; then

        print_info_ln "Labelling: Size if empty. Populating labelling array"

        while read -r line; do

            line=`trim "$line"`
            comma_counter=`printf "%s" "$line" | tr -cd ',' | wc -c`

            if test "X$comma_counter" = "X"; then
                continue
            fi

            if test $comma_counter -eq 1; then
                found_instance=""
                found_user=`printf "%s\n" "$line" | cut -d, -f1 | sed -e 's/\\$/\\\\$/g'`
                found_desc=`printf "%s\n" "$line" | cut -d, -f2`
            elif test $comma_counter -eq 2; then
                # make all instance names upper case
                found_instance=`printf "%s\n" "$line" | cut -d, -f1 | tr '[:lower:]' '[:upper:]'`
                found_user=`printf "%s\n" "$line" | cut -d, -f2 | sed -e 's/\\$/\\\\$/g'`
                found_desc=`printf "%s\n" "$line" | cut -d, -f3`
            fi

            if $debug; then
                printf "[DEBUG] Working with line: '%s'\n" "$line"
                printf "[DEBUG] Found instance: '%s'\n" "$found_instance"
                printf "[DEBUG] Found user: '%s'\n" "$found_user"
                printf "[DEBUG] Found description: '%s'\n" "$found_desc"
            fi

            hashed_user=`printf "%s" "${found_user}${found_instance}" | cksum | awk '{ print $1 }'`
            a_append "labelling_data" "$hashed_user"
            h_put "$hashed_user" "l_name" "$found_user"
            h_put "$hashed_user" "l_instance" "$found_instance"
            h_put "$hashed_user" "l_desc" "$found_desc"

        done < "$labelling_file"

    fi

    oIFS=$IFS; IFS=$character_lf
    for stored_hashed_user in `a_get_all "labelling_data"`; do

        stored_user=`h_get "$stored_hashed_user" "l_name"`

        print_debug_ln "Working with stored user: '$stored_user' ($stored_hashed_user)"

        if test "$stored_user" = "$label_user"; then

            stored_instance=`h_get "$stored_hashed_user" "l_instance"`
            print_debug_ln "Checking instance: '$stored_instance' and '$label_instance'"

            if test "X$stored_instance" != "X" -a "$stored_instance" != "$label_instance"; then
                continue
            fi

            stored_desc=`h_get "$stored_hashed_user" "l_desc"`
            print_debug_ln "Found descrtiption: '$stored_desc'"

            eval "$label_value=\"$stored_desc\""
            IFS=$oIFS
            return
        fi
    done
    IFS=$oIFS

    eval "$label_value=\"\""

}

function remove_labeling_delimiter {
    printf "%s\n" "$1" | sed -e "s/|/ /g"
}

function get_gecos_for_user_id {

    typeset user_name=$1
    # TODO: find through getent
    while IFS=$character_colon read -r user passwd uid gid gecos home shell; do
        if test "X$user_name" = "X$user"; then
            remove_labeling_delimiter "$gecos"
            return
        fi
    done < "/etc/passwd"
}

function get_urt_format {

    typeset gecos="$1"
    typeset userstatus="C"
    typeset userccc="000"
    typeset userserial=""
    typeset usercust=""
    typeset usercomment="$gecos"

    ## LOOK FOR CIO Format
    typeset matched=`printf "%s" "$gecos" | grep -i "s\=" | wc -l`
    if test $matched -gt 0; then
        serialccc=`printf "%s" "$gecos" | tr "[:upper:]" "[:lower:]" | sed -n 's/.*\(s=[a-zA-Z0-9]*\).*/\1/p'`
        serial=`printf "%s\n" "$serialccc" | cut -c3-8`
        ccc=`printf "%s\n" "$serialccc" | cut -c9-11`
        if test ${#serialccc} -ge 11; then
            userserial="$serial"
            userccc="$ccc"
            userstatus="I"
            usercust=""
            usercomment="$gecos"
        fi
    fi

    ## LOOK FOR IBM SSSSSS CCC Format
    matched=`printf "%s" "$gecos" | grep ".*IBM [a-zA-Z0-9-]\{6\} [a-zA-Z0-9]\{3\}" | wc -l`
    if test $matched -gt 0; then
        userstatus="I"
        oIFS="$IFS"
        IFS=' '
        step=0
        for token in $gecos; do
            if "X$token" = "XIBM"; then
                let 'tokens_need=step+3'
                if test $tokens_need -gt ${#tokens[*]}; then
                    break
                fi
                let 'step=step+1'
                continue
            fi

            if test $step -eq 1; then
                serial="$token"
                if test ${#serial} -ne 6; then
                    break
                fi
                let 'step=step+1'
            fi

            if test $step -eq 2; then
                ccc="$token"
                if test ${#ccc} -lt 3; then
                    break
                else
                    ccc3=`printf "%s\n" "$ccc" | cut -c1-3`
                fi

                userserial="$serial"
                userccc=$ccc3
                userstatus="I"
                usercomment="$gecos"
                break
            fi

        done
        IFS="$oIFS"
    fi

    usergecos="$userccc/$userstatus/$userserial/$usercust/$usercomment"

    ## LOOK FOR URT Format
    matched=`printf "%s" "$gecos" | grep ".\{2,3\}\/.\{1\}\/" | wc -l`
    if test $matched -gt 0; then
        usergecos="$gecos"
    fi
    IFS=" "
    usergecos=`remove_labeling_delimiter "$usergecos"`
    printf "%s" "$usergecos"
}

function get_state_for_user_id {

    current_user_id=$1
    var=$2
    current_user_state="Disabled"

    print_debug_ln "Getting status for user"

    check_on_existing_user "$current_user_id" "checkingResult"

    print_debug_ln "User exists: $checkingResult"

    if test $checkingResult = $FALSE; then
        printf "%s" "$current_user_state"
        return
    fi

    current_user_state="Enabled"

    print_debug_ln "Working with the passwd file"

    passwdrec=`cat /etc/passwd | grep "$current_user_id"`

    if test "X$passwdrec" != "X";then
        user_passwd=`printf "%s\n" "$passwdrec" | cut -d: -f2`
        if test "X$user_passwd" = "X*"; then
            current_user_state="Disabled"
        fi
    fi

    if test $os_name = AIX; then

        crypt=`cat $sec_passwd_file | awk "{ RS="\n\n" } /^$current_user_id:/ { print }" | grep password | cut -d" " -f3`
        if test "X$crypt" = "X*"; then
            print_debug_ln ": AIX sec_passwd_file password * DISABLED $current_user_id: crypt:$crypt"
            current_user_state="Disabled"
        fi

        locked=`cat $sec_user_file | awk "{ RS="\n\n" } /^$current_user_id:/ { print }" | grep account_locked | cut -d" " -f3`
        if test "X$locked" = "Xtrue"; then
            print_debug_ln ": AIX sec_user_file account_locked false DISABLED $current_user_id: locked:$locked"
            current_user_state="Disabled"
        fi

    elif test $os_name = HP-UX; then

        if test ! -x /usr/lbin/getprpw; then
            print_warn_ln "unable to execute /usr/lbin/getprpw. Account current_user_state may be missing from extract"
            TCB_READABLE=0
        else
            TCB_READABLE=1
        fi

        # process shadow file if it exists
        if test -r $sec_passwd_file; then

            crypt=`grep "^$current_user_id:" $sec_passwd_file | cut -d: -f2`

            # check for user disabled by LOCKED, NP, *LK*, !!, or * in password field
            if test "X$crypt" = "XLOCKED"; then

                print_debug_ln ": HPUX sec_passwd_file DISABLED $current_user_id: crypt:$crypt"
                current_user_state="Disabled"
            fi

            if test "X$crypt" = "X*"; then
                print_debug_ln ": HPUX sec_passwd_file DISABLED $current_user_id: crypt:$crypt"
                current_user_state="Disabled"
            fi

            if printf "%s" "$crypt" | grep -q "*LK*"; then
                print_debug_ln ": HPUX sec_passwd_file DISABLED $current_user_id: crypt:$crypt"
                current_user_state="Disabled"
            fi

            if test "X$crypt" = "XNP"; then
                print_debug_ln ": HPUX sec_passwd_file DISABLED $current_user_id: crypt:$crypt"
                current_user_state="Disabled"
            fi

            if printf "%s" "$crypt" | grep -q "^\!\!" >/dev/null; then
                print_debug_ln ": HPUX sec_passwd_file DISABLED $current_user_id: crypt:$crypt"
                current_user_state="Disabled"
            fi

        fi

        # peform getprpw check if TCB machine
        if test $TCB_READABLE -eq 1; then
            lockout=`/usr/lbin/getprpw -m lockout $current_user_id`
            if echo $lockout | grep -q 1; then
                print_debug_ln ": HPUX getprpw DISABLED $current_user_id: $lockout"
                current_user_state="Disabled"
            else
                print_debug_ln ": HPUX getprpw $current_user_id: $lockout"
            fi
        fi

    else

        if test -r $sec_passwd_file; then

            crypt=`grep "^$current_user_id:" $sec_passwd_file | cut -d: -f2`

            # check for user disabled by LOCKED, NP, *LK*, !!, or * in password field
            if test "X$crypt" = "XLOCKED"; then
                print_debug_ln ": sec_passwd_file DISABLED $current_user_id: crypt:$crypt"
                current_user_state="Disabled"
            fi

            if test "X$crypt" = "X*"; then
                print_debug_ln ": sec_passwd_file DISABLED $current_user_id: crypt:$crypt"
                current_user_state="Disabled"
            fi


            if printf "%s" "$crypt" | grep -q "*LK*"; then
                print_debug_ln ": sec_passwd_file DISABLED $current_user_id: crypt:$crypt"
                current_user_state="Disabled"
            fi

            if test "X$crypt" = "XNP"; then
                print_debug_ln ": sec_passwd_file DISABLED $current_user_id: crypt:$crypt"
                current_user_state="Disabled"
            fi

            if printf "%s" "$crypt" | grep -Eq "^\!\!"; then
                print_debug_ln ": sec_passwd_file DISABLED $current_user_id: crypt:$crypt"
                current_user_state="Disabled"
            fi

        fi

    fi

    eval "$var=$current_user_state"

}

function get_last_logon_user_id {

    user_id="$1"
    return_last_logon="$2"

    # Todo: initialize only once
    MNames="month_name"

    h_put $MNames "1" "Jul"
    h_put $MNames "2" "Aug"
    h_put $MNames "3" "Sep"
    h_put $MNames "4" "Oct"
    h_put $MNames "5" "Nov"
    h_put $MNames "6" "Dec"
    h_put $MNames "7" "Jan"
    h_put $MNames "8" "Feb"
    h_put $MNames "9" "Mar"
    h_put $MNames "10" "Apr"
    h_put $MNames "11" "May"
    h_put $MNames "12" "Jun"

    last_login_date=""

    if test $os_name = Linux; then

        login_data=`lastlog -u $user_id 2>/dev/null | grep "$user_id"`
        never_logged_in=`echo "$login_data" | awk '{if($0 ~ /Never logged in/){print $0}}'`

        if test "X$login_data" != "X" -a "X$never_logged_in" = "X"; then
            last_login_year=`echo "$login_data" | awk '{print $9}' | tr -d '\n'`
            last_login_month=`echo "$login_data" | awk '{print $5}' | tr -d '\n'`
            last_login_date=`echo "$login_data" | awk '{print $6}' | tr -d '\n'`
            LAST_LOGIN_TIME=`echo "$login_data" | awk '{print $7}' | tr -d '\n'`
            last_login_date="$last_login_date $last_login_month $last_login_year"
            print_debug_ln "Found date: $last_login_date"
        fi

    elif test $os_name = 'AIX'; then
        login_data=`lsuser -f $user_id 2>/dev/null | grep time_last_login | sed -e "s/.*=//"`
        if test "X$login_data" != "X"; then
            if test -e /usr/bin/perl; then
                login_data=`perl -e "print scalar(localtime($login_data))"`
            fi
        fi
        if test "X$login_data" != "X"; then
            LAST_LOGIN_YEAR=`echo "$login_data" | awk '{print $5}' | tr -d '\n'`
            LAST_LOGIN_MONTH=`echo "$login_data" | awk '{print $2}' | tr -d '\n'`
            LAST_LOGIN_DAY=`echo "$login_data" | awk '{print $3}' | tr -d '\n'`
            LAST_LOGIN_TIME=`echo "$login_data" | awk '{print $4}' | tr -d '\n'`
            last_login_date="$LAST_LOGIN_DAY $LAST_LOGIN_MONTH $LAST_LOGIN_YEAR"
        fi
    else
        CURRENT_YEAR=`date +%Y`
        CURRENT_MONTH=`date +%b`
        ON_SINCE_DATA=`finger $user_id 2>/dev/null | awk '{if($0 ~ /On since/){ printf( "%s,", $0 ) }}'`
        if test "X$ON_SINCE_DATA" != "X"; then 
            # Work with situation when user still works with an account 
            ON_SINCE_DATA=`echo "$ON_SINCE_DATA" | sed -e "s/.*On since //" | sed -e "s/ on.*//"`
            PROCESSING_DATA=`echo "$ON_SINCE_DATA" | awk '{ if ($0 ~ /,/) {print $0}}'`
            if test "X$PROCESSING_DATA" != "X"; then
                # Found the last login year
                LAST_LOGIN_YEAR=`echo "$ON_SINCE_DATA" | awk '{print $4}' | tr -d '\n'`
                LAST_LOGIN_MONTH=`echo "$ON_SINCE_DATA" | awk '{print $2}' | tr -d '\n'`

                lastLoginMonth=""
                curLoginMonth=""

                lastLoginMonth=`h_get $MNames $LAST_LOGIN_MONTH`
                curLoginMonth=`h_get $MNames $CURRENT_MONTH`

                if test "X$lastLoginMonth" != "X" -a "X$curLoginMonth" != "X"; then
                    if test $lastLoginMonth -lt 7 -a $curLoginMonth -gt 6; then
                        let 'LAST_LOGIN_YEAR -= 1'
                    fi
                fi
                LAST_LOGIN_DAY=`echo "$ON_SINCE_DATA" | awk '{ if($3 ~ /,/){outString=substr($3, 0, length($3)-1);print outString;}else{print $3}}' | tr -d '\n'`
                LAST_LOGIN_TIME=""
            else
                LAST_LOGIN_YEAR=`date +%Y`
                LAST_LOGIN_MONTH=`echo "$ON_SINCE_DATA" | awk '{print $1}' | tr -d '\n'`
                LAST_LOGIN_DAY=`echo "$ON_SINCE_DATA" | awk '{print $2}' | tr -d '\n'`
                LAST_LOGIN_TIME=`echo "$ON_SINCE_DATA" | awk '{print $3}' | tr -d '\n'`
            fi
            last_login_date="${LAST_LOGIN_DAY} ${LAST_LOGIN_MONTH} ${LAST_LOGIN_YEAR}"
        fi
        LAST_LOGIN=`finger $user_id 2>/dev/null | awk '{if($0 ~ /Last login/){ print $0 }}'`
        if test "X$LAST_LOGIN" != "X"; then
            LAST_LOGIN=`echo "$LAST_LOGIN" | sed -e "s/Last login //" | sed -e "s/ on.*//"`
            PROCESSING_DATA=`echo "$LAST_LOGIN" | awk '{ if ($0 ~ /,/) {print $0}}'`
            if test "$PROCESSING_DATA" != "X"; then
                # Found the last login year
                LAST_LOGIN_YEAR=`echo "$LAST_LOGIN" | awk '{print $4}' | tr -d '\n'`
                LAST_LOGIN_MONTH=`echo "$LAST_LOGIN" | awk '{print $2}' | tr -d '\n'`
                LAST_LOGIN_DAY=`echo "$LAST_LOGIN" | awk '{ if($3 ~ /,/){outString=substr($3, 0, length($3)-1);print outString;}else{print $3}}' | tr -d '\n'`
                LAST_LOGIN_TIME=""
            else
                if test $os_name = SunOS; then
                    LAST_LOGIN_YEAR=`date +%Y`
                    LAST_LOGIN_MONTH=`echo "$LAST_LOGIN" | awk '{print $2}' | tr -d '\n'`

                    lastLoginMonth=""
                    curLoginMonth=""

                    lastLoginMonth=`h_get $MNames $LAST_LOGIN_MONTH`
                    curLoginMonth=`h_get $MNames $CURRENT_MONTH`

                    if test "X$lastLoginMonth" != "X" -a "X$curLoginMonth" != "X"; then
                        if test $lastLoginMonth -lt 7 -a $curLoginMonth -gt 6; then
                            let 'LAST_LOGIN_YEAR -= 1'
                        fi
                    fi

                    LAST_LOGIN_DAY=`echo "$LAST_LOGIN" | awk '{print $3}' | tr -d '\n'`
                    LAST_LOGIN_TIME=`echo "$LAST_LOGIN" | awk '{print $4}' | tr -d '\n'`

                else

                    LAST_LOGIN_YEAR=`date +%Y`
                    LAST_LOGIN_MONTH=`echo "$LAST_LOGIN" | awk '{print $1}' | tr -d '\n'`

                    lastLoginMonth=""
                    curLoginMonth=""

                    lastLoginMonth=`h_get $MNames $LAST_LOGIN_MONTH`
                    curLoginMonth=`h_get $MNames $CURRENT_MONTH`

                    if test "X$lastLoginMonth" != "X" -a "X$curLoginMonth" != "X"; then
                        if test $lastLoginMonth -lt 7 -a $curLoginMonth -gt 6; then
                            let 'LAST_LOGIN_YEAR -= 1'
                        fi
                    fi

                    LAST_LOGIN_DAY=`echo "$LAST_LOGIN" | awk '{print $2}' | tr -d '\n'`
                    LAST_LOGIN_TIME=`echo "$LAST_LOGIN" | awk '{print $3}' | tr -d '\n'`

                fi
            fi
            last_login_date="${LAST_LOGIN_DAY} ${LAST_LOGIN_MONTH} ${LAST_LOGIN_YEAR}"
        fi
    fi

    eval "$return_last_logon=\"$last_login_date\""

}

function create_mef3 {

    typeset pid=$1
    typeset sid=`h_get "$pid" "$DB_INSTANCE_NAME"`

    open_ldap_detector

    oIFS=$IFS; IFS=$character_lf
    for user_hash in `a_get_all "user_list"`; do

        user=`h_get "$user_hash" "name"`

        print_sep_slim
        print_info_ln "User: '$user'"

        user_description=""
        urt_format=""
        uic_mode=""
        status=""
        last_logon=""

        groups="`h_get "$user_hash" "roles"`"
        privileges="`h_get "$user_hash" "privs"`"

        print_debug_ln "Groups: '$groups'"
        print_debug_ln "Privileges '$privileges'"

        check_on_existing_user "$user" "is_os_user"

        description_status=""

        if test $is_os_user -eq $TRUE; then

            print_info_ln "OS user"

            if test $open_ldap_is_used -eq $TRUE; then

                open_ldap_get_description "$user" "description"
                user_description="$LDAP_USER_DESCRIPTION"

                if test "X$user_description" != "X"; then

                    print_info_ln "The description '$user_description' has been detected"
                    is_ag_data_correct "$user_description" "is_correct"
                    if test $is_correct -eq $TRUE; then
                        print_info_ln "AG correct '$user_description'"
                    else
                        print_info_ln "AG incorrect '$user_description'"
                        user_description=""
                    fi
                else
                    print_info_ln "Description is empty"
                fi
            else
                print_info_ln "Get description from the GECOS"
                user_description=`get_gecos_for_user_id "$user"`
                if test "X$user_description" != "X"; then
                    is_ag_data_correct "$user_description" "is_correct"
                    if test $is_correct -eq $TRUE; then
                        print_info_ln "AG correct '$user_description'"
                    else
                        print_info_ln "AG incorrect '$user_description'"
                        user_description=""
                    fi
                else
                    print_info_ln "Description is empty"
                fi
            fi

            get_state_for_user_id "$user" "status"
            print_info_ln "Status: '$status'"

            get_last_logon_user_id "$user" "last_logon"
            print_info_ln "Last logon: '$last_logon'"

        else # internal user

            print_info_ln "Internal user"
            status=`h_get "$user_hash" "status"`
            if test "X$status" = "XOPEN"; then
                status="Enabled"
            else
                status="Disabled"
            fi
            print_info_ln "Status: '$status'"
        fi

        if test "X$labelling_file" != "X"; then

            print_info_ln "Get description from the labelling file"
            get_labelling_from_file "new_user_description" "$labelling_file" "$user" "$sid"

            if test "X$new_user_description" != "X"; then
                is_ag_data_correct "$new_user_description" "is_correct"
                if test "X$is_correct" = "X"; then
                    print_warn_ln "Can't determine AG correctness"
                elif test $is_correct -eq $TRUE; then
                    print_info_ln "AG correct '$new_user_description'"
                    user_description="$new_user_description"
                else
                    print_info_ln "AG incorrect '$new_user_description'"
                fi
            else
                print_info_ln "Description is empty"
            fi
        fi

        # Get URT format
        if test "X$user_description" != "X"; then
            urt_format=`get_urt_format "$user_description"`
            print_debug_ln "URT format: '$urt_format'"
        fi

        if printf "%s" "$user" | grep -q '^.*@.*\.ibm\.com$'; then
            uic_mode="F"
        fi

        mef_line=""
        if $ag; then
            if test "X$uic_mode" = "XF" -a "X$urt_format" = "X"; then
                mef_line=`printf "%s|A|%s|ORACLE:%s|%s|F||%s|%s|%s|%s" "$customer" "$hostname" "$sid" "$user" "$status" "$last_logon" "$groups" "$privileges"`
            elif test "X$uid_mode" = "X" -a "X$urt_format" = "X"; then
                mef_line=`printf "%s|A|%s|ORACLE:%s|%s||000/C///|%s|%s|%s|%s" "$customer" "$hostname" "$sid" "$user" "$status" "$last_logon" "$groups" "$privileges"`
            else
                mef_line=`printf "%s|A|%s|ORACLE:%s|%s||%s|%s|%s|%s|%s" "$customer" "$hostname" "$sid" "$user" "$urt_format" "$status" "$last_logon" "$groups" "$privileges"`
            fi
        else
            if test "X$uic_mode" = "XF" -a "X$user_description" = "X"; then
                mef_line=`printf "%s|A|%s|ORACLE:%s|%s|F||%s|%s|%s|%s" "$customer" "$hostname" "$sid" "$user" "$status" "$last_logon" "$groups" "$privileges"`
            else
                mef_line=`printf "%s|A|%s|ORACLE:%s|%s||%s|%s|%s|%s|%s" "$customer" "$hostname" "$sid" "$user" "$user_description" "$status" "$last_logon" "$groups" "$privileges"`
            fi
        fi

        print_debug_ln "$mef_line"

        printf "%s\n" "$mef_line" >> "$output_file"

    done

    ag_format=""
    if $ag; then
        ag_format="AG"
    else
        ag_format="GLOBAL"
    fi

    not_real_id="NOTaRealID"
    if test "X$signature" != "X"; then
        not_real_id="${not_real_id}-${signature}"
    fi

    last_line=`printf "%s|A|%s|ORACLE:%s|%s||000/V///%s:FN=%s(%s):VER=%s:CKSUM=%s|||%s|" "$customer" "$hostname" "$sid" "$not_real_id" "$audit_date" "$script_name" "$ag_format" "$version" "$cksum" "$signature_group"`

    printf "%s\n" "$last_line" >> "$output_file"

}

function mef_user_post_process {

    test ! -f "$output_file" && return 2
    if $ibm_only || $customer_only; then return 1; fi

    return_code=0
    is_ibm_user=0

    clear_file "$tmp_file"
    cp "$output_file" "$tmp_file"

    clear_file "$output_file"

    while read -r line; do
        line=`trim "$line"`

        print_debug_ln "Working with the line: '$line'\n"

        if test "X$line" != "X"; then

            MEF3_USER=`printf "%s" "$line" | awk '{ split($0, str, "|"); print str[5];}'`
            MEF3_DESCRIPTION=`printf "%s" "$line" | awk '{ split($0, str, "|"); print str[7];}'`

            # Checking on the signature record
            if printf "%s" "$line" | grep -q "NOTaRealID"; then
                printf "%s" "$line" >> "$output_file"
                continue
            fi

            # Checking if user has this format <login name>@<location>.ibm.com
            is_ibm=`printf "%s" "$MEF3_USER" | grep -i '^[^@]*@[^@]*\.ibm\.com'`
            if test "X$is_ibm" != "X" && $ibm_only; then
                printf "%s" "$line" >> "$output_file"
                continue
            elif test "X$is_ibm" != "X" && $customer_only; then
                continue
            fi

            if printf "%s" "$MEF3_DESCRIPTION" | grep -q '^.\{2,3\}\/[^\/]*\/[^\/]*\/[^\/]*\/.*$'; then
                user_gecos_mef3=`get_urt_format "$MEF3_DESCRIPTION"`
            else
                user_gecos_mef3="$MEF3_DESCRIPTION"
            fi

            if printf "%s" "$user_gecos_mef3" | grep -q ".\{2,3\}\/[^\/]*\/[^\/]*\/[^\/]*\/.*"; then
                if printf "%s" "$user_gecos_mef3" | grep -q ".\{2,3\}\/[ISFTEN]\/[^\/]*\/[^\/]*\/.*"; then
                    is_ibm_user=1
                fi
            else
                returnCode=3
            fi

            if test $is_ibm_user -eq 1 && $ibm_only; then
                printf "%s" "$line" >> "$output_file"
                continue
            fi

            if test $is_ibm_user -eq 0 && $customer_only; then
                printf "%s" "$line" >> "$output_file"
                continue
            fi

        fi

    done < "$tmp_file"

    clear_file "$tmp_file"
    return $return_code

}

function change_owner {

    test "X$mef3_owner" = "X" && return

    clear_file $tmp_file

    print_info_ln "Script is going to change the owner of the '$output_file' report to '$mef3_owner'"
    chown "$mef3_owner" "$output_file" 1>$tmp_file 2>&1

    if test $? -ne 0; then

        print_warn_ln "Sorry, script can't change owner"

        while read -r line; do
            print_warn_ln "line: $line"
        done < $tmp_file

        clear_file $tmp_file

    else
        print_info_ln "Owner has been changed successfully"
    fi

}

#-----------------------------------------------------------------------
# Main
#-----------------------------------------------------------------------

# ----------------------------------------------------------------------------
##   Header
# ----------------------------------------------------------------------------

printf "\n"
print_info_ln "UID EXTRACTOR EXECUTION - Started"
print_info_ln "START TIME: $start_time"
print_sep_wide
print_info_ln "$subsystem_name Sub-System Extractor"
print_sep_wide

get_os_information

if test $# -gt 0; then
    print_info_ln "Following parameters will be processed: $*"
    print_sep_wide
    process_input_parameters "$@"
else
    print_info_ln "The script has been started without any parameters"
    print_sep_wide
fi

load_library

# prepare parameters for output
prepare_parameters

# print parameters to output
print_params

# check parameters
check_params

print_info_ln "EXTRACTION PROCESS - Started"
print_sep_wide

# ----------------------------------------------------------------------------
##   Extraction
# ----------------------------------------------------------------------------

# 
# method gets all active instances
# if there are no active instances method returns from the script with error
#
# lists of pids:
#   pid_list
# and hash, that based on this pid:
#   $pid -> $DB_INSTANCE_NAME = $sid
#   $pid -> $DB_HOME = $home
#   $pid -> $DB_OWNER = $owner

get_oracle_instances

print_sep_slim $status_debug

# get otartab file first
# Every system with Oracle installed on it should have oratab file
# in worst case it returns empty string.
get_oratab_file

# if oratab is not empty - populate oratab_data
# $oratab_data{$oracle_instance_name} = $oracle_home;
# the hash "oratab_data' is necessary for "get_oracle_home" method
# array
#   oratab_sids_hashes (sid can contain sigis sign $)
# hash
#   otarab_sids_hash -> sid = instance name
#   otarab_sids_hash -> home = oracle home
if test "X$oratab_file" != "X" && test -f $oratab_file; then
    get_oratab_data
fi

# getting all oracle homes
for pid in `a_get_all "pid_list"`; do
    get_oracle_home "$pid"
done

# now, when all oracle homes were set, checking otatab file for stopped instances
check_instances_with_oratab

oIFS=$IFS
IFS=$character_lf
for pid in `a_get_all "pid_list"`; do

    # -------------------------------------------------------------------------
    # Clearing resources
    # -------------------------------------------------------------------------

    if test `a_size "user_list"` -gt 0; then
        oIFS=$IFS; IFS=$character_lf
        for user_hash in `a_get_all "user_list"`; do

            user=`h_get "$user_hash" "name"`
            # clear user's stored fields
            h_clear "$user_hash" "name"
            h_clear "$user_hash" "privs"
            h_clear "$user_hash" "roles"
            h_clear "$user_hash" "status"

            print_debug_ln "Remove from hash '$user_hash' user '$user'"
        done
        # remove user list
        a_clear "user_list"
        IFS=$oIFS
    fi

    if test `a_size "members_dba"` -gt 0; then
        a_clear "members_dba"
    fi

    if test `a_size "ss_oper_grp"` -gt 0; then
        a_clear "ss_oper_grp"
    fi

    # -------------------------------------------------------------------------

    home=`h_get "$pid" "$DB_HOME"`
    sid=`h_get "$pid" "$DB_INSTANCE_NAME"`

    print_info_ln "Working with '$sid' and home: '$home'"

    if test "X${home}" = "X"; then

        print_warn_ln "Script couldn't find the correct location of the ORACLE_HOME instance."
        print_warn_ln "Please try to add next line to the oratab file:"
        print_warn_ln "  $sid:/correct/oracle/home/path:N"
        print_warn_ln "Skipping this instance"

        add_to_failure_instances "$sid:$home"

        continue

    fi

    if test "X$oracle_install_path" != "X" -a "X$home" != "X$oracle_install_path"; then

        print_info_ln "Current instance home path is not equal with predefined ORACLE_PATH"
        print_debug_ln "Current instance's home path: '$home', predefined: '$oracle_install_path'"
        print_sep_slim

        continue

    fi

    # ----------------------------------------------------------------------
    # parsing config files for admin groups
    # ----------------------------------------------------------------------
    print_info_ln "Parse config file for administrative groups"
    parse_config_file "$home"

    print_info_ln "Starting the search of users with the SYDBA-privilege"

    if test "X$ss_dba_grp" != "X" -o "X$ss_oper_grp" != "X"; then
        get_users_from_a_group "members_dba" "$ss_dba_grp"
        get_users_from_a_group "members_oper" "$ss_oper_grp"
    else
        print_warn_ln "DBA and OPER groups are empty"
        add_to_failure_instances "${sid}:${home}"
        continue
    fi

    oIFS=$IFS; IFS=$character_lf
    # its a simple array, because system users can't contain sigils, spaces,
    # null chars, etc.
    for user in `a_get_all "members_dba"`; do
        store_user_role "$user" "SYSDBA"
        store_user_privileges "$user" "SYSDBA"
    done

    for user in `a_get_all "members_oper"`; do
        store_user_role "$user" "SYSOPER"
        store_user_privileges "$user" "SYSOPER"
    done

    if $debug; then
        printf "[DEBUG] OS users:"
        for user_hash in `a_get_all "user_list"`; do
            printf " '`h_get \"$user_hash\" \"name\"`'"
        done
        printf ".\n"
    fi
    IFS=$oIFS

    get_oracle_owner "$pid"

    owner=`h_get $pid $DB_OWNER`
    print_info_ln "Oracle owner: '$owner'"

    if test "X$owner" = "X"; then
        print_warn_ln "Can't obtain Oracle owner. Skipping this sid."
        add_to_failure_instances "${sid}:${home}"
        continue
    fi

    # is_oracle_version_valid "$pid"

    # if test $? -eq "$FALSE"; then
        # add_to_failure_instances "${sid}:${home}"
        # print_warn_ln "The found version of the Oracle's SID is not supported by the given script"
        # continue
    # fi

    get_remote_pwd_file_type "$pid"
    print_info_ln "Found value for parameter 'remote_login_passwordfile': '$remote_login_password_type'"

    if test $remote_login_password_type = "EXCLUSIVE" -o \
        $remote_login_password_type = "SHARED"; then

        get_db_role "$pid"
        print_debug_ln "Database role: $db_type"

        db_type=`uc "$db_type"`

        # check database role. if 'physical standby/i - can't obtain
        # users from the pwd file
        if test "X$db_type" = "XPHYSICAL STANDBY"; then

            print_info_ln "Cannot extract users from '$sid' because database is of the type 'PHYSICAL STANDBY'"

            # create the mef3 file with internal users only
            create_mef3 "$sid"
            continue

        fi

    fi

    print_info_ln "Obtain users from password file"
    get_pwd_file_auth_info "$pid"


    if $priv_ids; then
        print_info_ln "Get users with DBA group (privIDs)"
        get_dba_users "$pid"
    else
        print_info_ln "Get all users (allUserIDs)"
        get_all_users "$pid"
    fi

    create_mef3 "$pid"

    print_sep_wide

done

if test ! -f "$output_file" || test ! -s "$output_file"; then
    print_error_ln "Mef3 file is empty"
    get_return_code $ex_err
fi

print_info_ln "Running filtering the MEF file"

if $ibm_only || $customer_only; then
    mef_user_post_process
fi

if test $? -eq 2; then
    print_error_ln "The specified MEF file ($output_file) is absent on the server"
    get_return_code $ex_err
elif test $? -eq 3; then
    print_error_ln "MEF file contains incorrect record(s), because it was not possible to detect IAM format for the user's description"
    get_return_code $ex_err
fi

change_owner

print_info_ln "EXTRACTION PROCESS - Finished"

get_return_code $return_code

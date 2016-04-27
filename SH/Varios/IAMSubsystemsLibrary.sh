#!/bin/bash

#=========================================================================
# (C) Copyright 2012 IBM Corporation
#=========================================================================
# Script Name    : IAMSubsystemsLibrary.sh
# Script Purpose : External package
# Parameters     : None
# Output         : None
# Dependencies   : BASH
#-------------------------------------------------------------------------------
# Version Date         # Author              Description
#-------------------------------------------------------------------------------
# V1.0.1  2012-03-02   # Andrey Goncharenko  Initial BASH version
# V1.0.2  2012-07-06   # Andrey Goncharenko  Open Ldap functions where fixed
# V1.0.3  2012-07-26   # Andrey Goncharenko  OpenLDAP_Get_Description is fixed
# V1.0.4  2012-09-18   # Pavel Pisakov       Fixed the issue with \r\n in "Get_Labelling_From_File"
#==========================================================================================================================

VERSION_LIBRARY="V1.0.4"

LIB_TMP_FILE="/tmp/lib_tmp.txt"
PASSWDFILE="/etc/passwd"
GROUPFILE="/etc/group"

TRUE=1
FALSE=0

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

date=`date +%d%b%Y`
date=`echo $date | tr -d ' '`

myAUDITDATE=`date +%Y-%m-%d-%H.%M.%S`
DATE=`echo $date | tr "[:lower:]" "[:upper:]"`

HOST=`uname -n | cut -d. -f1 | tr "[:lower:]" "[:upper:]"`

if [ $UOS = 'AIX' ]; then
    SECUSER="/etc/security/user"
    SPASSWD="/etc/security/passwd"
elif [ $UOS = 'HP-UX' ]; then
    SECUSER=""
    SPASSWD="/etc/shadow"
elif [ $UOS = 'SUNOS' ]; then
    SECUSER=""
    SPASSWD="/etc/shadow"
elif [ $UOS = 'LINUX' ]; then
    SECUSER=""
    SPASSWD="/etc/shadow"
elif [ $UOS = 'TRU64' ]; then
    SECUSER=""
    SPASSWD="/etc/shadow"
else
    SECUSER=""
    SPASSWD="/etc/shadow"
fi
#if [ $UOS = 'SUNOS' ]; then
#    CKSUM=`cksum $0|cut -f1`
#else
#    CKSUM=`cksum $0|cut -d" " -f1`
#fi
# detecting basic information
if [ $UOS = 'LINUX' ]; then
    OS_VERSION=`uname -a|cut -f3 -d" "`
    PSARGS="axo"
    CURRENT_UID=`id -u`
elif [ $UOS = 'AIX' ]; then
    OS_VERSION=`oslevel`
    PSARGS="-ef -o"
    CURRENT_UID=`id -u`
elif [ $UOS = 'SUNOS' ]; then
    OS_VERSION=`uname -a|cut -f3 -d" "`
    PSARGS="-ef -o"
    CURRENT_UID=`id | cut -f2 -d"="|cut -f1 -d "("`
    PATH=/usr/xpg4/bin/:$PATH
elif [ $UOS = 'HP-UX' ]; then
    UNIX95=true
    export UNIX95
    OS_VERSION=`uname -a|cut -f3 -d" "`
    PSARGS="-ef -o"
    CURRENT_UID=`id -u`
else
    echo "Unknow OS $UOS detected."
fi
CURRENT_DIR=`pwd`
SCAN_TIME=`date +"%d%m%Y"`

if [ $UOS = 'AIX' ]; then
    LDAPSEARCH_CMD="/usr/ldap/bin/ldapsearch"
    if [ ! -f $LDAPSEARCH_CMD ]; then
        LDAPSEARCH_CMD="ldapsearch"
    fi
elif [ $UOS = 'HP-UX' ]; then
    LDAPSEARCH_CMD="/opt/ldapux/bin/ldapsearch"
    if [ ! -f $LDAPSEARCH_CMD ]; then
        LDAPSEARCH_CMD="ldapsearch"
    fi
elif [ $UOS = 'SUNOS' ]; then
    LDAPSEARCH_CMD="/usr/bin/ldapsearch"
    if [ ! -f $LDAPSEARCH_CMD ]; then
        LDAPSEARCH_CMD="ldapsearch"
    fi    
elif [ $UOS = 'LINUX' ]; then
    LDAPSEARCH_CMD="/usr/bin/ldapsearch -x"
    if [ ! -f "/usr/bin/ldapsearch" ]; then
        LDAPSEARCH_CMD="ldapsearch -x"
    fi    
else
    LDAPSEARCH_CMD="ldapsearch"
fi
LIB_OPEN_LDAP_IS_USED=0
LIB_OPEN_LDAP_IS_CHECKED=0

# Figuring out the max. array size for the given system
function setMaxArraySize
{
    if [[ $MAX_ARRAY_SIZE -ne 0 ]];then return;fi
    # in bash we can just assign the value directly
    (( MAX_ARRAY_SIZE=MAX_ARRAY_SIZE_DEFAULT ))
    echo "[INFO]  MAX_ARRAY_SIZE was set to $MAX_ARRAY_SIZE"
}
MAX_ARRAY_SIZE=0
#MAX_ARRAY_SIZE_DEFAULT=102400
MAX_ARRAY_SIZE_DEFAULT=1048576
setMaxArraySize

#'Checking the AG correctness and return TRUE if it is correct.
#'Checking logic:
#'The label structure is  in the form 
#'      X/Y/Z/T/U       
#'       X Y Z T U - being strings 
#'Minimal rules for determining a valid syntax : 
#'  a/  There are at least   4  "/" in the label   
#'      Mind that the U string may contain some  "/" and therefore there may be  more than 4 "/" in total 
#'   b/  X  May be  a 3 digit/letter code ( PSC Code ) or a 2 letters alphabetic code  (ISO Code )  
#'  c/  Y is a one letter long code. Y  valid  values are : 
#'                      I  (IBM regular) 
#'                      N  (IBM non-regular) 
#'                      T  (Subsidiary) 
#'                      E  (External =contractor)  
#'                      C  (Customer)  
#'                      V  (Vendor=third parties)  
#'                      F  (Functional=Shared ID) 
#'                      S  (System= Service or deamon)
#'  d/   if Y=C  or V  then Z can be anything 
#'       if Y is one of the I N T E  values, then  Y represents a serial number.  We must check that it is exactly 6 character long AND does NOT START with a " * "
#'        if Y is F or S  then Y represents an intermediate code.  We must check that it STARTS with a " * "

function IsAGDataCorrect
{
    typeset inData=$1
    isAGdataCorrect=0
    pscMatched=`echo "$inData" | grep -w "[a-zA-Z0-9]\{3\}\/[INTECVFS]\/[^\/]*\/[^\/]*\/.*" | wc -l`
    isoMatched=`echo "$inData" | grep -w "[a-zA-Z]\{2\}\/[INTECVFS]\/[^\/]*\/[^\/]*\/.*" | wc -l`
    if [[ $pscMatched -gt 0 || $isoMatched -gt 0 ]]; then   
        procLine=""
        if [[ $pscMatched -gt 0 ]]; then    
            procLine=`echo "$inData" | sed -n 's/.*\([a-zA-Z0-9]\{3\}\/[INTECVFS]\/[^\/]*\/[^\/]*\/.*\)/\1/p` 
        else
            procLine=`echo "$inData" | sed -n 's/.*\([a-zA-Z]\{2\}\/[INTECVFS]\/[^\/]*\/[^\/]*\/.*\)/\1/p` 
        fi
        oIFS="$IFS"; IFS="/"
        procLineArray=($procLine)
        IFS="$oIFS"
        YVal=${procLineArray[1]}
        ZVal=${procLineArray[2]}
        if [[ $YVal = "C" || $YVal = "V" ]]; then
            isAGdataCorrect=1
        elif [[ $YVal = "I" || $YVal = "N" || $YVal = "T" || $YVal = "E" ]]; then
            astMatched=`echo "$ZVal" | grep -v "^\*.*" | wc -l`
            if [[ ${#ZVal} -eq 6 && $astMatched -gt 0 ]]; then
                isAGdataCorrect=1
            else
                isAGdataCorrect=0
            fi
        elif [[ $YVal = "F" || $YVal = "S" ]]; then
            astMatched=`echo "$ZVal" | grep "^\*.*" | wc -l`
            if [[ $astMatched -gt 0 ]]; then
                isAGdataCorrect=1
            else
                isAGdataCorrect=0
            fi
        fi      
    fi
    echo "$isAGdataCorrect"
}
# a global variable which contains a label for the current userID
USER_LABEL_INFO=""
#Description: Post process mef-file. Remove filtered records
#Input:
#    1) [in] Path to output MEF file
#    2) [in] ibmOnly parameter
#    3) [in] customerOnly parameter
#Output:
#    returnCode
#    1  -ibmOnly and -customerOnly are identical
#    2  the specified MEF file is absent on the server
#    3  MEF file contains incorrect record(s), because it was not possible to detect URT format for the user's description
#    0  the function has been finished with success
#
function Mef_Users_Post_Process
{
    typeset outputFile=$1 ibmOnly=$2 customerOnly=$3
    isIbmUser=0
    returnCode=0
    if [[ $ibmOnly -eq 1 && $customerOnly -eq 1 ]]; then
        return 1
    fi
    if [[ $ibmOnly -eq 0 && $customerOnly -eq 0 ]]; then
        return 1
    fi
    baseMefName=`basename "$outputFile"`
    tmpOut="/tmp/${baseMefName}_tmp"
    if [[ -f "$outputFile" ]]; then
        # Storing file's data
        `echo "" >> "$outputFile"`
        `cat "$outputFile" > "$tmpOut"`
        `echo "" >> "$tmpOut"`
        # Clear the output file
        `ClearFile "$outputFile"`
        while read -r nextline; do
            if [[ $nextline != "" ]]; then
                isIbmUser=0
                CUSTOMER_MEF3=`echo "$nextline" | awk '
                            {
                                split($0, str, "|");
                                print str[1];
                            }
                        '`
                HOST_MEF3=`echo "$nextline" | awk '
                            {
                                split($0, str, "|");
                                print str[3];
                            }
                        '`
                INSTANCE_MEF3=`echo "$nextline" | awk '
                            {
                                split($0, str, "|");
                                print str[4];
                            }
                        '`
                USER_MEF3=`echo "$nextline" | awk '
                            {
                                split($0, str, "|");
                                print str[5];
                            }
                        '`
                FLAG_MEF3=`echo "$nextline" | awk '
                            {
                                split($0, str, "|");
                                print str[6];
                            }
                        '`
                DESCRIPTION_MEF3=`echo "$nextline" | awk '
                            {
                                split($0, str, "|");
                                print str[7];
                            }
                        '`
                USERSTATE_MEF3=`echo "$nextline" | awk '
                            {
                                split($0, str, "|");
                                print str[8];
                            }
                        '`
                USERLLOGON_MEF3=`echo "$nextline" | awk '
                            {
                                split($0, str, "|");
                                print str[9];
                            }
                        '`
                GROUPS_MEF3=`echo "$nextline" | awk '
                            {
                                split($0, str, "|");
                                print str[10];
                            }
                        '`
                ROLES_MEF3=`echo "$nextline" | awk '
                            {
                                split($0, str, "|");
                                print str[11];
                            }
                        '`
                # 1. Checking on the signature record
                matched=`echo "$nextline" | egrep "NOTaRealID" | wc -l`
                if [[ $matched -gt 0 ]]; then
                    `echo "$nextline" >> "$outputFile"`
                    continue
                fi
                # 2. Checking if user has this format <login name>@<location>.ibm.com
                SPECIAL_FLAG=`echo $USER_MEF3 | grep -i '.*@.*\.ibm\.com'`                
                if [[ $SPECIAL_FLAG != "" && $ibmOnly -ne 0 ]]; then
                    `echo "$nextline" >> "$outputFile"`
                    continue
                fi
                if [[ $SPECIAL_FLAG != "" && $customerOnly -ne 0 ]]; then
                    continue
                fi
                matched=`echo "$DESCRIPTION_MEF3" | grep ".\{2,3\}\/[^\/]*\/[^\/]*\/[^\/]*\/.*" | wc -l`
                if [[ $matched -eq 0 ]]; then
                    # description of the current userID doesn't contain URT format information in the description field
                    USERGECOS_MEF3=`GetURTFormat "$DESCRIPTION_MEF3"`
                else
                    USERGECOS_MEF3=$DESCRIPTION_MEF3
                fi
                matched=`echo "$USERGECOS_MEF3" | grep ".\{2,3\}\/[^\/]*\/[^\/]*\/[^\/]*\/.*" | wc -l`
                if [[ $matched -ne 0 ]]; then
                    matched=`echo "$USERGECOS_MEF3" | grep ".\{2,3\}\/[ISFTEN]\/[^\/]*\/[^\/]*\/.*" | wc -l`
                    if [[ $matched -ne 0 ]]; then
                        isIbmUser=1
                    fi
                else
                    returnCode=3
                fi
                if [[ $isIbmUser -eq 1 && $ibmOnly -eq 1 ]]; then
                    `echo "$nextline" >> "$outputFile"`
                    continue
                fi
                if [[ $isIbmUser -eq 0 && $customerOnly -eq 1 ]]; then
                    `echo "$nextline" >> "$outputFile"`
                    continue
                fi
            fi
        done < "$tmpOut"
    else
        return 2
    fi
    `ClearFile "$tmpOut"`
    return $returnCode
}
##############################
function Delete_All_Duplications
{
    typeset inputString=$1 delimiterString=$2
    outputString=""
    oIFS=$IFS
    IFS=$delimiterString
    for inputStringEntry in $inputString; do
        if [[ $outputString = "" ]]; then
            outputString=$inputStringEntry
        else
            dublicateChecker=0
            for outputStringEntry in $outputString; do
                if [[ $outputStringEntry = $inputStringEntry ]]; then
                    dublicateChecker=1
                fi
            done
            if [[ $dublicateChecker -eq 0 ]]; then
                outputString=$outputString$delimiterString$inputStringEntry
            fi
        fi
    done
    IFS=$oIFS
    outputString=`echo "$outputString" | sed -e "s/^ *//g" | sed -e "s/ *$//g"`
    echo "$outputString"
}
##############################
function OpenLDAP_Detector
{
    typeset DEBUG=$1
    if [[ LIB_OPEN_LDAP_IS_CHECKED -eq 1 ]];then
        return
    fi
    NSSWITCH_CONF="/etc/nsswitch.conf"
    if [[ -f $NSSWITCH_CONF ]]; then
        typeset PASSWD_METHOD=`awk 'BEGIN {FS = ": *"} { if ($1 == "passwd" ) print $2 }' /etc/nsswitch.conf`
        if [[ $PASSWD_METHOD != "" ]]; then
            PASSWD_METHOD=`echo "$PASSWD_METHOD" | tr "[:upper:]" "[:lower:]"`
            if [[ $PASSWD_METHOD = *files*ldap* ]]; then
                LIB_OPEN_LDAP_IS_USED=1
                fi
            fi
    fi
    OpenLDAP_Parameters
    LIB_OPEN_LDAP_IS_CHECKED=1
    OPEN_LDAP_BINDPW_enc=`echo $OPEN_LDAP_BINDPW | sed -e s/./*/g`
    if [[ $DEBUG -eq 1 ]];then
        echo "[DEBUG] OpenLDAP is checked. LIB_OPEN_LDAP_IS_USED=$LIB_OPEN_LDAP_IS_USED | OPEN_LDAP_BINDDN='$OPEN_LDAP_BINDDN' | OPEN_LDAP_BINDPW='$OPEN_LDAP_BINDPW_enc' | OPEN_LDAP_BASE='$OPEN_LDAP_BASE' | OPEN_LDAP_HOST='$OPEN_LDAP_HOST'"
    fi
}
##############################
function OpenLDAP_Parameters
{
    if [[ -f /etc/ldap.conf ]]; then
        # The distinguished name of the search base.
        OPEN_LDAP_BASE=`cat /etc/ldap.conf | grep -P '^\s*base' | awk '{ print $2 }'`
        # LDAP server.
        OPEN_LDAP_HOST=`cat /etc/ldap.conf | grep -P '^\s*host' | awk '{ print $2 }'`
        # The distinguished name to bind to the server with.
        OPEN_LDAP_BINDDN=`cat /etc/ldap.conf | grep -P '^\s*binddn' | awk '{ print $2 }'`
        # The credentials to bind with. 
        OPEN_LDAP_BINDPW=`cat /etc/ldap.conf | grep -P '^\s*bindpw' | awk '{ print $2 }'`
    fi
}
##############################
function OpenLDAP_Get_Description 
{
    typeset USER_ID=$1
    typeset LABELLINGFIELD=$2
    typeset DEBUG=$3
    LDAP_USERID_DESCRIPTION=""
    
    typeset S_LDAPSEARCH_CMD="$LDAPSEARCH_CMD -Z -LLL"
    typeset S_OBJ="uid=$USER_ID"
    typeset err_out="/tmp/openldap.err"
    
    if [ ! -z "$OPEN_LDAP_BINDDN" ] && [ ! -z "$OPEN_LDAP_BINDPW" ]; then
        S_LDAPSEARCH_CMD="$S_LDAPSEARCH_CMD -D $OPEN_LDAP_BINDDN -w $OPEN_LDAP_BINDPW" 
    fi
    if [[ $DEBUG = 1 ]];then
        echo "[DEBUG] CMD: $S_LDAPSEARCH_CMD \"($S_OBJ)\" 2>$err_out |  grep \"$LABELLINGFIELD:\" | cut -d\":\" -f2"
    fi
    LDAP_USERID_DESCRIPTION=`$S_LDAPSEARCH_CMD "($S_OBJ)" 2>$err_out | grep "$LABELLINGFIELD:" | cut -d":" -f2`
    if [[ $LDAP_USERID_DESCRIPTION != "" ]];then
        LDAP_USERID_DESCRIPTION=`trims "$LDAP_USERID_DESCRIPTION"`
    fi
    if [[ $DEBUG = 1 ]] && [[ -s $err_out ]]; then
        typeset err=`cat $err_out`
        echo "[DEBUG] LDAP ERROR: $err"
    fi
    if [ -f $err_out ];then unlink $err_out; fi
}
# Remove labeling delimiter
#Input:
#    1) [in] Labeling data
#Return:
#    Labeling data without of file delimiter
function Remove_Labeling_Delimiter
{
    typeset labellingData=$1
    outLabellingData=`echo "$labellingData" | sed "s/|/ /g"`
    echo "$outLabellingData"
}
# Get label for user id from the file.
#Input:
#    1) [in] Path to file with labelling
#    2) [in] User id
#    3) [in] instance name
#Return:
#    Labelling info for user
function Get_Labelling_From_File
{
    typeset labellingFile=$1 userID=$2 instanceName=$3
    # Clear global value
    USER_LABEL_INFO=""
    userID=`echo $userID | tr "\134" "\057"`
    
    #AGetAll LabellingHashData labellingHashDataBuffer
    
    LabelCnt=`ANElem LabellingHashData`
    
    if [[ $LabelCnt -eq 0 ]]; then
        if [[ -f $labellingFile ]]; then
            TMPLABEL="/tmp/getlabellingfromfile.tmp"
            #`cat $labellingFile | sed 's/[\x0D\x0A]*$//' | tr "\134" "\057" > $TMPLABEL 2>/dev/null`
            `cat $labellingFile | sed 's/\r$//' | tr "\134" "\057" > $TMPLABEL 2>/dev/null`
            `echo "" >> $TMPLABEL`
            if  [[ $? -eq 0 ]]; then
                while read nextline; do
                    if [[ $nextline != "" ]]; then
                        eval unset LABELING_ENTRIES
                        oIFS="$IFS"; IFS=','
                        LABELING_ENTRIES=($nextline)
                    if [[ ${#LABELING_ENTRIES[*]} -eq 2 ]]; then
                        AStore LabellingHashData "${LABELING_ENTRIES[0]}" "${LABELING_ENTRIES[1]}"
                    elif [[ ${#LABELING_ENTRIES[*]} -eq 3 ]]; then
                        AStore LabellingHashData "${LABELING_ENTRIES[0]} ${LABELING_ENTRIES[1]}" "${LABELING_ENTRIES[2]}"
                    fi
                    IFS="$oIFS"
                  fi
                done < $TMPLABEL
            fi            
            `ClearFile "$TMPLABEL" 2>/dev/null`
            fi
    fi
    if [[ $instanceName = "" ]]; then
        AGet LabellingHashData "$userID"
        if  [[ $? -ne 0 ]]; then
            AGet LabellingHashData "$userID" userLabel
            userLabel=`Remove_Labeling_Delimiter "$userLabel"`
            USER_LABEL_INFO=$userLabel
        fi
    else
        AGet LabellingHashData "$instanceName $userID"
        if  [[ $? -ne 0 ]]; then
            AGet LabellingHashData "$instanceName $userID" userLabel
            userLabel=`Remove_Labeling_Delimiter "$userLabel"`
            USER_LABEL_INFO=$userLabel
        fi
    fi
    #echo $USER_LABEL_INFO
    return 0
}
# detecting last login information
function Get_Last_Logon_User_Id
{
    typeset userID=$1
    AUnset MNames
    AStore MNames "Jul" "1"
    AStore MNames "Aug" "2"
    AStore MNames "Sep" "3"
    AStore MNames "Oct" "4"
    AStore MNames "Nov" "5"
    AStore MNames "Dec" "6"
    AStore MNames "Jan" "7"
    AStore MNames "Feb" "8"
    AStore MNames "Mar" "9"
    AStore MNames "Apr" "10"
    AStore MNames "May" "11"
    AStore MNames "Jun" "12"
    LAST_LODIN_DATE=""
    if [ $UOS = 'LINUX' ]; then
        LOGIN_DATA=`lastlog -u $userID 2>/dev/null | grep "$userID" | grep -v grep`
        NEVER_LOGGED_IN=`echo "$LOGIN_DATA" | awk '{if($0 ~ /Never logged in/){print $0}}'`
        if [[ $LOGIN_DATA != "" && $NEVER_LOGGED_IN = "" ]]; then
            LAST_LOGIN_YEAR=`echo "$LOGIN_DATA" | awk '{print $9}' | tr -d '\n'`
            LAST_LOGIN_MONTH=`echo "$LOGIN_DATA" | awk '{print $5}' | tr -d '\n'`
            LAST_LOGIN_DAY=`echo "$LOGIN_DATA" | awk '{print $6}' | tr -d '\n'`
            LAST_LOGIN_TIME=`echo "$LOGIN_DATA" | awk '{print $7}' | tr -d '\n'`
            LAST_LODIN_DATE=$LAST_LOGIN_DAY" "$LAST_LOGIN_MONTH" "$LAST_LOGIN_YEAR
        fi      
    elif [ $UOS = 'AIX' ]; then
        LOGIN_DATA=`lsuser -f $userID 2>/dev/null | grep time_last_login | grep -v grep | sed -e "s/.*=//"`
        if [[ $LOGIN_DATA != "" ]]; then
            if [ -e /usr/bin/perl ]; then
                LOGIN_DATA=`perl -e "print scalar(localtime($LOGIN_DATA))"`
            fi
        fi  
        if [[ $LOGIN_DATA != "" ]]; then
            LAST_LOGIN_YEAR=`echo "$LOGIN_DATA" | awk '{print $5}' | tr -d '\n'`
            LAST_LOGIN_MONTH=`echo "$LOGIN_DATA" | awk '{print $2}' | tr -d '\n'`
            LAST_LOGIN_DAY=`echo "$LOGIN_DATA" | awk '{print $3}' | tr -d '\n'`
            LAST_LOGIN_TIME=`echo "$LOGIN_DATA" | awk '{print $4}' | tr -d '\n'`
            LAST_LODIN_DATE=$LAST_LOGIN_DAY" "$LAST_LOGIN_MONTH" "$LAST_LOGIN_YEAR
        fi      
    else
        CURRENT_YEAR=`date +%Y`
        CURRENT_MONTH=`date +%b`
        ON_SINCE_DATA=`finger $userID 2>/dev/null | awk '{if($0 ~ /On since/){ printf( "%s,", $0 ) }}'`
        if [[ $ON_SINCE_DATA != "" ]]; then 
            # Work with situation when user still works with an account 
            ON_SINCE_DATA=`echo "$ON_SINCE_DATA" | sed -e "s/.*On since //" | sed -e "s/ on.*//"`           
            PROCESSING_DATA=`echo "$ON_SINCE_DATA" | awk '{ if ($0 ~ /,/) {print $0}}'`
            if [[ $PROCESSING_DATA != "" ]]; then
                # Found the last login year
                LAST_LOGIN_YEAR=`echo "$ON_SINCE_DATA" | awk '{print $4}' | tr -d '\n'`                                
                LAST_LOGIN_MONTH=`echo "$ON_SINCE_DATA" | awk '{print $2}' | tr -d '\n'`
                lastLoginMonth=""
                curLoginMonth=""
                AGet MNames "$LAST_LOGIN_MONTH"                
                if  [[ $? -ne 0 ]]; then
                    AGet MNames "$LAST_LOGIN_MONTH" lastLoginMonth
                fi
                AGet MNames "$CURRENT_MONTH"                
                if  [[ $? -ne 0 ]]; then
                    AGet MNames "$CURRENT_MONTH" curLoginMonth
                fi                
                if [[ $lastLoginMonth != "" && $curLoginMonth != "" ]]; then
                    if [[ $lastLoginMonth -lt 7 && $curLoginMonth -gt 6 ]]; then
                        ((LAST_LOGIN_YEAR -= 1))
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
            LAST_LODIN_DATE=$LAST_LOGIN_DAY" "$LAST_LOGIN_MONTH" "$LAST_LOGIN_YEAR
        fi
        LAST_LOGIN=`finger $userID 2>/dev/null | awk '{if($0 ~ /Last login/){ print $0 }}'`
        if [[ $LAST_LOGIN != "" ]]; then    
            LAST_LOGIN=`echo "$LAST_LOGIN" | sed -e "s/Last login //" | sed -e "s/ on.*//"`         
            PROCESSING_DATA=`echo "$LAST_LOGIN" | awk '{ if ($0 ~ /,/) {print $0}}'`
            if [[ $PROCESSING_DATA != "" ]]; then
                # Found the last login year
                LAST_LOGIN_YEAR=`echo "$LAST_LOGIN" | awk '{print $4}' | tr -d '\n'`
                LAST_LOGIN_MONTH=`echo "$LAST_LOGIN" | awk '{print $2}' | tr -d '\n'`
                LAST_LOGIN_DAY=`echo "$LAST_LOGIN" | awk '{ if($3 ~ /,/){outString=substr($3, 0, length($3)-1);print outString;}else{print $3}}' | tr -d '\n'`
                LAST_LOGIN_TIME=""
            else
                if [ $UOS = 'SUNOS' ]; then
                    LAST_LOGIN_YEAR=`date +%Y`
                    LAST_LOGIN_MONTH=`echo "$LAST_LOGIN" | awk '{print $2}' | tr -d '\n'`
                    lastLoginMonth=""
                    curLoginMonth=""
                    AGet MNames "$LAST_LOGIN_MONTH"                
                    if  [[ $? -ne 0 ]]; then
                        AGet MNames "$LAST_LOGIN_MONTH" lastLoginMonth
                    fi
                    AGet MNames "$CURRENT_MONTH"                
                    if  [[ $? -ne 0 ]]; then
                        AGet MNames "$CURRENT_MONTH" curLoginMonth
                    fi
                    if [[ $lastLoginMonth != "" && $curLoginMonth != "" ]]; then
                        if [[ $lastLoginMonth -lt 7 && $curLoginMonth -gt 6 ]]; then
                            ((LAST_LOGIN_YEAR -= 1))
                        fi
                    fi
                    LAST_LOGIN_DAY=`echo "$LAST_LOGIN" | awk '{print $3}' | tr -d '\n'`
                    LAST_LOGIN_TIME=`echo "$LAST_LOGIN" | awk '{print $4}' | tr -d '\n'`
                else
                    LAST_LOGIN_YEAR=`date +%Y`
                    LAST_LOGIN_MONTH=`echo "$LAST_LOGIN" | awk '{print $1}' | tr -d '\n'`
                    lastLoginMonth=""
                    curLoginMonth=""
                    AGet MNames "$LAST_LOGIN_MONTH"                
                    if  [[ $? -ne 0 ]]; then
                        AGet MNames "$LAST_LOGIN_MONTH" lastLoginMonth
                    fi
                    AGet MNames "$CURRENT_MONTH"                
                    if  [[ $? -ne 0 ]]; then
                        AGet MNames "$CURRENT_MONTH" curLoginMonth
                    fi
                    if [[ $lastLoginMonth != "" && $curLoginMonth != "" ]]; then
                        if [[ $lastLoginMonth -lt 7 && $curLoginMonth -gt 6 ]]; then
                            ((LAST_LOGIN_YEAR -= 1))
                        fi
                    fi
                    LAST_LOGIN_DAY=`echo "$LAST_LOGIN" | awk '{print $2}' | tr -d '\n'`
                    LAST_LOGIN_TIME=`echo "$LAST_LOGIN" | awk '{print $3}' | tr -d '\n'`
                fi
            fi
            #if [[ ${#LAST_LOGIN_DAY} -eq 1 ]];then
                #$LAST_LOGIN_DAY="0${LAST_LOGIN_DAY}"
            #fi
            LAST_LODIN_DATE="${LAST_LOGIN_DAY} ${LAST_LOGIN_MONTH} ${LAST_LOGIN_YEAR}"
        fi  
    fi  
    echo $LAST_LODIN_DATE
}
# Get full path to executable
function Get_Exe_By_Pid
{
    # parameters:
    # $1 -- pid of process
    exe_pid=$1
    executable_name=`ps -p $exe_pid -o comm,pid  | awk 'NR==2 {print $1}'`
    function phys_mount
    {
        # list "physical" file systems, i.e. no NFS, no procfs etc.
        case $UOS in
            AIX) mount | awk '$1~/\/dev/{print $2}';;
            HP-UX|SUNOS) mount | grep 'on /dev' | sed 's/ on \/dev.*$//';;
            LINUX) mount | grep '^/dev' | sed 's/^.*on \(.*\) type.*$/\1/';;
        esac
    }
    function get_file_by_fuser 
    {
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
                if fuser -f $j 2>&1 | tr ' ' '\012' | awk 'NR>1 && '"${3}" | \
                    tr -d '[a-z]' | grep '^'$1'$' >/dev/null; then
                    echo $j
                fi
            done
        done
    }
    function get_exe_by_fuser
    {
        # get process executable using fuser. Does not work on AIX.
        [ "$UOS" = "AIX" ] && return
        flag="/t/"
        if [ "$UOS" = "LINUX" ]; then flag="/e/"; fi
        cmd=`ps -p $1 | awk 'NR==2{print $4}'`
        # hack for oracle -- look only /bin/oracle$
        get_file_by_fuser $1 "oracle" "$flag" | head -1
    }
    function get_exe_by_proc
    {
        # get proces executable by proc/cwd for pmon
        ls -l /proc/$1/cwd | awk '{ print $NF }' | sed 's/dbs\/$/bin\/oracle/'
    }
    function get_exe_by_memmap
    {
        # The memory map lists which memory segments a process uses,
        # and also shows which files are mapped into the address space
        # For Linux and Solaris, the executable is always the first file
        # mapped. For AIX, the executable is flagged as "text data BSS heap"
        # or as "code".
        case $UOS in
            AIX) lv_inode=`svmon -P $1 | awk '
                   $1 !~ /\// {s=0}
                   $0 ~ /(clnt|pers) (text data BSS heap|code)/ && $0 ~ /- *$/ {s=1}
                   (s==1) && $0 ~ /\/dev\/.* / {print $0}'`
                if [ -n "$lv_inode" ]; then
                    lv_inode=`echo $lv_inode | sed 's/^.*\/dev\///' | sed 's/ .*$//'`
                    lv=`echo $lv_inode | cut -f1 -d':'`
                    inode=`echo $lv_inode | cut -f2 -d':'`
                    mp=`lslv $lv | awk '/^MOUNT POINT/ {print $3}'`
                    if [ -n "$mp" -a -d "$mp" -a -n "$inode" ]; then
                        find $mp -inum $inode
                    fi
                fi
                ;;
            LINUX) ls -l /proc/$1/exe | awk '{print $NF}';;
            SUNOS) pmap $1 | awk 'NR==2' |\
                      sed 's/^[^ ][^ ]*  *[^ ][^ ]*  *[^ ][^ ]*  *//';;
        esac
    }
    if [ "$UOS" = "HP-UX" ]; then
        command=`get_exe_by_fuser $exe_pid $executable_name`
    else
        if [ "$UOS" = "AIX" ]; then
           command=`get_exe_by_proc $exe_pid`
        else
           command=`get_exe_by_memmap $exe_pid`
        fi
    fi
    echo $command | grep -E '^/' > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        # if we still can't find correct pwd try last resort -- scan PATH
        # first -- for user of process, second -- for root
        pid_owner=`ps -p $exe_pid -o user | awk 'NR==2 {print $1}'`
        if [ "$pid_owner" != "root" ]; then
            command=`su - $pid_owner -c "which $executable_name 2> /dev/null"`
        fi
        if [ -z "$command" ]; then
            command=`which $executable_name 2> /dev/null`
        fi
        if [ -z "$command" ]; then
            command="$executable_name"
        fi
    fi
    echo "$command"
}
##############################
function ShadowPassword
{
    typeset PWD=$1
    if [[ $PWD != "" ]]; then
      SHADOW_PWD=`echo "$PWD" | sed -e "s/./*/g"`
      echo "$SHADOW_PWD"
    else
      echo ""
    fi
}
##############################
function ClearFile
{
    typeset FILE=$1
    `echo "" > "$FILE" && rm "$FILE"` 
    if [[ $? -ne 0 ]]; then
      echo "[ERROR] Unable to open '$FILE'"
    fi
}
##############################
function GetMembersForGroup
{
    typeset inputGroupID=$1
    inputGroupID=`echo $inputGroupID | tr "[:upper:]" "[:lower:]"`
    LISTMEMBERS=""
    isGroupDetected=0      # flag to check the presence of userIDs into /etc/passwd
    detectedGroupID=""
    while IFS=: read -r group gpasswd gid members
    do
        ugroup=`echo $group | tr "[:upper:]" "[:lower:]"`
        if [[ $inputGroupID = $ugroup ]]; then
            isGroupDetected=1
            detectedGroupID=$gid
            if [ $UOS = 'SUNOS' ]; then
                count_members=`echo $members | nawk -F"," '{print NF}'`
            else
                count_members=`echo $members | awk -F"," '{print NF}'`
            fi
            while [[ $count_members -gt 0 ]];do
                if [ $UOS = 'SUNOS' ]; then
                    membersDescr=`echo $members | nawk -F"," '{print $i}' i=$count_members`
                else
                    membersDescr=`echo $members | awk -F"," '{print $i}' i=$count_members`
                fi
                ((count_members -= 1))
                if [[ $LISTMEMBERS = "" ]]; then
                    LISTMEMBERS=$membersDescr
                else
                    LISTMEMBERS=$LISTMEMBERS"|"$membersDescr
                fi
            done        
        fi            
    done < $GROUPFILE
    if [[ $isGroupDetected -ne 0 && $detectedGroupID != "" ]]; then
        while IFS=: read -r userid passwd uid gid gecos home shell
        do
            userid=`echo "$userid" | tr "[:upper:]" "[:lower:]"`
            if [[ $detectedGroupID = $gid ]]; then
                if [[ $LISTMEMBERS = "" ]]; then
                    LISTMEMBERS=$userid
                else
                    LISTMEMBERS=$LISTMEMBERS"|"$userid
                fi
            fi
        done < $PASSWDFILE    
    fi    
    echo $LISTMEMBERS
}
##############################
function GetOwnersForGroup
{
    typeset inputUserID=$1
    inputUserID=`echo $inputUserID | tr "[:upper:]" "[:lower:]"`    
    user_gid=""
    OWNER_GROUP_NAME=""
    while IFS=: read -r userid passwd uid gid gecos home shell
    do
        userid=`echo $userid | tr "[:upper:]" "[:lower:]"`
        if [[ $userid = $inputUserID ]]; then
            user_gid=$gid
        fi
    done < $PASSWDFILE
    index=0    
    while IFS=: read -r group gpasswd gid members
    do
        user_gid=`echo $user_gid | tr "[:upper:]" "[:lower:]"`
        gid=`echo $gid | tr "[:upper:]" "[:lower:]"`
        if [[ $user_gid = $gid ]]; then
            if [[ $OWNER_GROUP_NAME = "" ]]; then
                OWNER_GROUP_NAME=$group
            else
                OWNER_GROUP_NAME=$OWNER_GROUP_NAME"|"$group
            fi
            ((index += 1))            
        fi        
    done < $GROUPFILE
    echo $OWNER_GROUP_NAME
}
##############################
function GetGecosForUserID
{
    typeset inputUserID=$1
    inputUserID=`echo $inputUserID | tr "[:upper:]" "[:lower:]"`    
    gecosinfo=""
    while IFS=: read -r userid passwd uid gid gecos home shell
    do
        userid=`echo $userid | tr "[:upper:]" "[:lower:]"`
        
        if [[ $userid = $inputUserID ]]; then
            gecosinfo=$gecos
            break
        fi
    done < $PASSWDFILE
    gecosinfo=`Remove_Labeling_Delimiter "$gecosinfo"`
    echo "$gecosinfo"
}
##############################
function CheckOnExistingUser
{
    typeset inputUserID=$1
    inputUserID=`echo $inputUserID | tr "[:upper:]" "[:lower:]"`
    while IFS=: read -r userid passwd uid gid gecos home shell
    do
        userid=`echo $userid | tr "[:upper:]" "[:lower:]"`
        if [[ $userid = $inputUserID ]]; then
            echo $TRUE
            return 0
        fi
    done < $PASSWDFILE
    echo $FALSE
}
##############################
function GetStateForUserID
{
    typeset ckid=$1
    typeset DEBUG=$2
    typeset state="Disabled"
    checkingResult=`CheckOnExistingUser $ckid`
    if [[ $checkingResult = $FALSE ]]; then
        echo $state
        return
    fi
    state="Enabled"
    typeset passwdrec=`cat /etc/passwd | grep "$ckid"`
    if [[  $passwdrec != "" ]];then
        typeset passwd=`echo "$passwdrec" | cut -d: -f2`
        if [[  $passwd = "*" ]]; then
            state="Disabled"
        fi
    fi
    if [ $UOS = 'AIX' ]; then
        ckid=`echo $ckid | tr "[:upper:]" "[:lower:]"`
        crypt=`cat $SPASSWD | tr "[:upper:]" "[:lower:]" | awk "{ RS="\n\n" } /^$ckid:/ { print }" | grep password|cut -d" " -f3`
        if [[ $crypt = "*" ]]; then
            if [[ $DEBUG -ne 0 ]]; then
                echo "[DEBUG]: AIX SPASSWD password * DISABLED $ckid: crypt:$crypt" >&2
            fi
            state="Disabled"
        fi
        locked=`cat $SECUSER | tr "[:upper:]" "[:lower:]" | awk "{ RS="\n\n" } /^$ckid:/ { print }" |grep account_locked|cut -d" " -f3`
        if [[ $locked = "true" ]]; then
            if [[ $DEBUG -ne 0 ]]; then
                echo "[DEBUG]: AIX SECUSER account_locked false DISABLED $ckid: locked:$locked" >&2
            fi
            state="Disabled"
        fi
    elif [ $UOS = 'HP-UX' ]; then
        if [ ! -x /usr/lbin/getprpw ]; then
            echo "[WARN] unable to execute /usr/lbin/getprpw. Account state may be missing from extract"
            TCB_READABLE=0
        else
            TCB_READABLE=1
        fi
        # process shadow file if it exists
        if [  -r $SPASSWD ]; then
            crypt=`grep ^$ckid: $SPASSWD|cut -d: -f2`
            # check for user disabled by LOCKED, NP, *LK*, !!, or * in password field
            if [[ $crypt = "LOCKED" ]]; then
                if [[ $DEBUG -ne 0 ]]; then
                    echo "[DEBUG]: HPUX SPASSWD DISABLED $ckid: crypt:$crypt" >&2
                fi
                state="Disabled"
            fi
            if [[ $crypt = "*" ]]; then
                if [[ $DEBUG -ne 0 ]]; then
                    echo "[DEBUG]: HPUX SPASSWD DISABLED $ckid: crypt:$crypt" >&2
                fi
                state="Disabled"
            fi
            if [[ $crypt = "*LK*" ]]; then
                if [[ $DEBUG -ne 0 ]]; then
                    echo "[DEBUG]: HPUX SPASSWD DISABLED $ckid: crypt:$crypt" >&2
                fi
                state="Disabled"
            fi
            if [[ $crypt = "NP" ]]; then
                if [[ $DEBUG -ne 0 ]]; then
                    echo "[DEBUG]: HPUX SPASSWD DISABLED $ckid: crypt:$crypt" >&2
                fi
                state="Disabled"
            fi
            if echo "$crypt" | egrep "^\!\!" > /dev/null; then
                if [[ $DEBUG -ne 0 ]]; then
                    echo "[DEBUG]: HPUX SPASSWD DISABLED $ckid: crypt:$crypt" >&2
                fi
                state="Disabled"
            fi
            ## additional check for HP TCB systems
        fi
        # peform getprpw check if TCB machine
        if [[ $TCB_READABLE -eq 1 ]]; then
            lockout=`/usr/lbin/getprpw -m lockout $ckid`
            matched=`echo $lockout|grep 1|wc -l`
            if [[ $matched -gt 0 ]]; then
                if [[ $DEBUG -ne 0 ]]; then
                    echo "[DEBUG]: HPUX getprpw DISABLED $ckid: $lockout" >&2
                fi
                state="Disabled"
            else
                if [[ $DEBUG -ne 0 ]]; then
                    echo "[DEBUG]: HPUX getprpw $ckid: $lockout" >&2
                fi
            fi
        fi
    else
        if [ -r $SPASSWD ]; then
            crypt=`grep ^$ckid: $SPASSWD|cut -d: -f2`
            # check for user disabled by LOCKED, NP, *LK*, !!, or * in password field
            if [[ $crypt = "LOCKED" ]]; then
                if [[ $DEBUG -ne 0 ]]; then
                    echo "[DEBUG]: SPASSWD DISABLED $ckid: crypt:$crypt" >&2
                fi
                state="Disabled"
            fi
            if [[ $crypt = "*" ]]; then
                if [[ $DEBUG -ne 0 ]]; then
                    echo "[DEBUG]: SPASSWD DISABLED $ckid: crypt:$crypt" >&2
                fi
                state="Disabled"
            fi
            #if [[ $crypt = "*LK*" ]]; then
            if echo "$crypt" | grep "*LK*" > /dev/null; then        #V 4.5
                if [[ $DEBUG -ne 0 ]]; then
                    echo "[DEBUG]: SPASSWD DISABLED $ckid: crypt:$crypt" >&2
                fi
                state="Disabled"
            fi
            if [[ $crypt = "NP" ]]; then
                if [[ $DEBUG -ne 0 ]]; then
                    echo "[DEBUG]: SPASSWD DISABLED $ckid: crypt:$crypt" >&2
                fi
                state="Disabled"
            fi
            if echo "$crypt" | egrep "^\!\!" > /dev/null; then
                if [[ $DEBUG -ne 0 ]]; then
                    echo "[DEBUG]: SPASSWD DISABLED $ckid: crypt:$crypt" >&2
                fi
                state="Disabled"
            fi
        fi
    fi
    echo $state
}
##############################
function GetURTFormat
{
    typeset gecos=$1
    typeset userstatus="C"
    typeset userccc="000"
    typeset userserial=""
    typeset usercust=""
    typeset usercomment=$gecos
    ## LOOK FOR CIO Format
    matched=`echo $gecos | grep -i "s\=" | wc -l`
    if [[ $matched -gt 0 ]]; then
        serialccc=$(echo $gecos | tr "[:upper:]" "[:lower:]" | sed -n 's/.*\(s=[a-zA-Z0-9]*\).*/\1/p')
        serial=$(echo $serialccc|cut -c3-8)
        ccc=$(echo $serialccc|cut -c9-11)
        if [[ ${#serialccc} -ge 11 ]]; then
            userserial=$serial
            userccc=$ccc
            userstatus="I"
            usercust=""
            usercomment=$gecos
        fi
    fi
    ## LOOK FOR IBM SSSSSS CCC Format
    matched=`echo $gecos | grep ".*IBM [a-zA-Z0-9-]\{6\} [a-zA-Z0-9]\{3\}" | wc -l`
    if [[ $matched -gt 0 ]]; then
        userstatus="I"
        oIFS="$IFS"; IFS=' ' 
        tokens=($gecos)
        IFS="$oIFS"  
        count=0
        while(( $count < ${#tokens[*]} )); do
            if [[ ${tokens[$count]} = "IBM" ]]; then
                if [[ count+3 -gt ${#tokens[*]} ]]; then
                    break
                fi
                serial=${tokens[$count+1]}
                ccc=${tokens[$count+2]}
                if [[ ${#serial} -ne 6 ]]; then
                    break
                fi
                if [[ ${#ccc} -lt 3 ]]; then
                    break
                else
                    ccc3=$(echo $ccc}|cut -c1-3)
                fi
                userserial=$serial
                userccc=$ccc3
                userstatus="I"
                usercomment=$gecos
                break
            fi
            let count=count+1
        done
    fi
    usergecos="$userccc/$userstatus/$userserial/$usercust/$usercomment"
    ## LOOK FOR URT Format
    matched=`echo $gecos | grep ".\{2,3\}\/.\{1\}\/" | wc -l`
    if [[ $matched -gt 0 ]]; then
        usergecos=$gecos
    fi
    IFS=" "
    usergecos=`Remove_Labeling_Delimiter "$usergecos"`
    echo "$usergecos"
}

# [AG]
# USAGE: ArraySortUniq <arrayname>
# Sorts array and removes duplicates
function ArraySortUniq
{
    typeset ARRAY=$1
    typeset value
    typeset -i i=0
    typeset -i cnt=0
    typeset TMP_OUT="/tmp/tmp.$$"
    eval cnt=\${#$ARRAY[@]}
    while [[ $i -lt $cnt ]];
    do 
        eval value=\"\${$ARRAY[$i]}\"
        echo "$value"
        let i+=1; 
    done | sort | uniq > $TMP_OUT;
    #eval unset \${ARRAY[@]}
    eval ${ARRAY}=\(\`cat \$TMP_OUT\`\)
    unlink $TMP_OUT
}
##############################
function Get_Aliases_List
{
    eval unset GLOBAL_ALIASES_LIST
    if [[ $UOS = 'HP-UX' ]]; then
        ALIASES_IP=`netstat -ai | awk {' print $4'} | grep -v "Address" | uniq`
    elif [[ $UOS = 'AIX' ]]; then
        ALIASES_IP=`ifconfig -a | grep "inet"| cut -f 2 -d " " | uniq`
    elif [[ $UOS = 'SUNOS' ]]; then
        ALIASES_IP=`ifconfig -a | grep "inet" | cut -f 2 -d " " | uniq`
    else
        ALIASES_IP=`ifconfig -a | grep "inet"| cut -f 2 -d ":" | cut -f 1 -d " " | uniq`
    fi    
    for ALIASE_IP in $ALIASES_IP; do
        if [[ -f /etc/hosts ]]; then
            if [[ $UOS != 'HP-UX' ]]; then
                ALIASES_HOST=`cat /etc/hosts | grep $ALIASE_IP | sed -e "s/#.*$//" | awk '{split ($0, buff, " ");for (i in buff) size++;for (i in buff) {if(i != size-1){print buff[i];}}}'`
            else
                ALIASES_HOST=$ALIASES_IP # the command 'netstat -ia' has already resolved the IPs in the host name
            fi  
            for ALIASE_HOST in $ALIASES_HOST; do
                if [[ $DEBUG -ne 0 ]]; then
                    echo "[DEBUG]: Host name's aliase '$ALIASE_HOST' was found for IP '$ALIASE_IP'"
                fi
                # checking on the IPV4-format
                ip4format_checker=`echo $ALIASE_HOST | egrep "^[0-9 ]*\.[0-9 ]*\.[0-9 ]*\.[0-9]*$" 2>/dev/null`
                # checking on the IPV6-format
                ip6format_checker=`echo $ALIASE_HOST | egrep "[:]+" 2>/dev/null`
                if [[ $ip4format_checker != "" && $ip6format_checker = "" ]]; then 
                    RESOLVED_HOST=`nslookup $ALIASE_HOST | grep "Name: " | sed -e "s/Name:[ \t]*//"`
                    if [[ $DEBUG -ne 0 ]]; then
                        echo "[DEBUG]: Resolved host for '$ALIASE_HOST' is '$RESOLVED_HOST'"
                    fi
                    if [[ $RESOLVED_HOST != "" ]]; then
                        ALIASE_HOST=$RESOLVED_HOST
                    else
                        ALIASE_HOST=""
                    fi
                fi
                GLOBAL_ALIASES_LIST[${#GLOBAL_ALIASES_LIST[*]}]=$ALIASE_HOST
            done
        fi
    done
}
# Usage: AStore <arrayname> <index> [<value> [<append>]]
# Stores value <value> in associative array <arrayname> with index <index>
# If no <value> is given, nothing is stored in the value array.
# This can be used for set operations.
# If a 4th argument is given, the value is appended to the current value
# stored for the index (if any).
# Return value is 0 for success, 1 for failure due to full array,
# 2 for failure due to bad index or arrayname, 3 for bad syntax
function AStore
{
    #----------------------
    function aStorePart 
    {
        typeset Arr=$1 Index=$2 Val=$3 DEBUG=0
        typeset -i NumArgs=$4 Used Free=0 NumInd arrEnd
        [[ -z $Index ]] && return 2
        # Arr must be a valid ksh variable name
        if eval [[ -z \"\$${Arr}_free\" ]]; then      # New array
            # Start free pointer at 1 - we do not use element 0
            Free=1
            arrEnd=0
            NumInd=0
        else    # Extant array
            (( arrEnd=${Arr}_end ))
            resInd=$(Ind ${Arr}_ind "$Index" $arrEnd)
            NumInd=$resInd
        fi
        # If the supplied <index> is not in use yet, we must find a slot for it
        # and store the index in that slot.
        if [[ NumInd -eq 0 ]]; then
            if [[ Free -eq 0 ]]; then   # If this is not a newly created array...
                eval Used=\${#${Arr}_ind[*]}
                if [[ $Used -ge $MAX_ARRAY_SIZE ]]; then
                    # No space available
                    return 1 
                fi
                (( Free=${Arr}_free ))
            fi
            # Find an unused element
            while eval [[ -n \"\${${Arr}_ind[Free]}\" ]]; do
                ((Free+=1))
                (( Free >= $MAX_ARRAY_SIZE )) && Free=1    # wrap
            done
            NumInd=Free
            ((Free+=1))
            (( NumInd > arrEnd )) && arrEnd=NumInd
            (( ${Arr}_free=Free ))
            (( ${Arr}_end=$arrEnd ))
            # Store index
            eval ${Arr}_ind[NumInd]=\$Index
        fi
        case $NumArgs in
            2) return 0;;           # Set no value
            3) eval ${Arr}_val[NumInd]=\$Val;;  # Store value
            4)  # Append value
                eval ${Arr}_val[NumInd]=\"\${${Arr}_val[NumInd]}\$Val\";;
            *) return 3;;
        esac
        return 0
    }
    #----------------------
    typeset Arr=$1 Index=$2 Val=$3 DEBUG=0
    typeset -i NumArgs=$#
    typeset -i Arr_cnt_next Arr_cnt_old Arr_cnt_cur=1 full=1 Arr_cnt
    eval Arr_cnt=\$${Arr}_cnt
    (( Arr_cnt_next=$Arr_cnt+1 ))
    (( Arr_cnt_old=$Arr_cnt ))
    if [[ $DEBUG -ne 0 ]]; then echo ">>> Arr_cnt_old='$Arr_cnt_old'";fi
    while [[ $Arr_cnt_cur -le $Arr_cnt_next && $full -ne 0 ]]; do
    if [[ $DEBUG -ne 0 ]]; then echo ">>> AStore : aStorePart --> ${Arr}_${Arr_cnt_cur} ... $Index ... $Val ... $NumArgs";fi
        aStorePart "${Arr}_${Arr_cnt_cur}" "$Index" "$Val" $NumArgs
        full=$?
        if [[ $DEBUG -ne 0 ]]; then echo ">>> AStore : full = '$full'";fi
        if [[ $full -eq 0 ]];then
            break
        fi
        let Arr_cnt_cur+=1
    done
    if [[ $Arr_cnt_cur -gt $Arr_cnt_old ]]; then
        (( ${Arr}_cnt=Arr_cnt_cur ))
    fi
    return 0
}
# Usage: AGet <arrayname> <index> <var>
# Finds the value indexed by <index> in associative array <arrayname>.
# If there is no such array or index, 0 is returned and <var> is not touched.
# Otherwise, <var> (if given) is set to the indexed value and the numeric index
# for <index> in the arrays is returned.
function AGet
{
    #----------------------
    function aGetPart
    {
        typeset Arr=$1 Index=$2 Var=$3 End
        typeset -i NumInd
        # Can't use implicit integer referencing on ${Arr}_end here because it may
        # not be set yet.
        eval End=\$${Arr}_end
        [[ -z $End ]] && return 0
        resInd=$(Ind ${Arr}_ind "$Index" $End)
        NumInd=$resInd
        if (( NumInd > 0 )) && [[ -n $Var ]]; then
            eval $Var=\"\${${Arr}_val[NumInd]}\"
        fi
        return $NumInd
    }
    #----------------------
    typeset Arr=$1 Index=$2 Var=$3
    typeset -i  NumInd=0
    typeset -i Arr_cnt
    eval Arr_cnt=\$${Arr}_cnt
    (( Arr_cnt )) || (( Arr_cnt=1 ))
    typeset num=1
    while [[ $num -le $Arr_cnt && $NumInd -eq 0 ]]; do 
        #echo "[$LINENO] $0: $@ ... Arr_cnt = $num/$Arr_cnt"
        aGetPart "${Arr}_${num}" "$Index" "$Var"
        NumInd=$?
        let num+=1;
    done
    return $NumInd
}
# Usage: AUnset <arrayname>
# Removes all elements from associative array <arrayname>
function AUnset
{
    typeset Arr=$1
    typeset -i num=1 Arr_cnt
    eval Arr_cnt=\$${Arr}_cnt
    (( Arr_cnt )) || (( Arr_cnt=1 ))
    while [[ $num -le $Arr_cnt && $NumInd -eq 0 ]]; do 
        eval unset ${Arr}_${num}_ind ${Arr}_${num}_val ${Arr}_${num}_free
        let num+=1;
    done
}
# Usage: Ind <arrayname> <value> [[<nsearch>] <firstelem>]
# Returns the index of the first element of <arrayname> that has value <value>.
# Note, <arrayname> is a full ksh array name, not an associate array name as
# used by this library.
# Returns 0 if it is none found.
# Works only for indexes 1..255.
# If <nsearch> is given, the first <nsearch> elements of the array are
# searched, with only nonempty elements counted.
# If not, the first n nonempty elements are searched,
# where n is the number of elements in the array.
# If a fourth argument (<firstelem>) is given, it is the index to start with;
# the search continues for <nsearch> elements.
# Element zero should not be set.
function Ind
{
    typeset Arr=$1 Val=$2 ElemVal
#echo "Arr = $Arr"
    typeset -i NElem ElemNum=${4:-1} NumNonNull=0 num_set
    eval num_set=\${#$Arr[*]}
#echo "num_set = $num_set"
    if [[ $# -eq 3 ]]; then
        NElem=$3
        # No point in searching more elements than are set
        (( NElem > num_set )) && NElem=num_set
    else
        NElem=$num_set
    fi
    while (( ElemNum <= $MAX_ARRAY_SIZE && NumNonNull < NElem )); do
        eval ElemVal=\"\${$Arr[ElemNum]}\"
        if [[ $Val = "$ElemVal" ]]; then
            echo "$ElemNum"
            return $ElemNum
        fi
        [[ -n $ElemVal ]] && ((NumNonNull+=1))
        ((ElemNum+=1))
    done
    echo ""    
}
# Usage: ADelete <arrayname> <index>
# Removes index <index> from associative array <arrayname>
# Returns 0 on success, 1 if <index> was not an index of <arrayname>
function ADelete
{
    #----------------------
    function aDeletePart
    {
        typeset Arr=$1 Index=$2 End
        typeset -i NumInd
        # Can't use implicit integer referencing on ${Arr}_end here because it may
        # not be set yet.
        eval End=\$${Arr}_end
    End=0
    #Ind1 ${Arr}_ind "$Index"
        resInd=$(Ind ${Arr}_ind "$Index")
        NumInd=$resInd
        if (( NumInd > 0 )); then
            eval Free=\$${Arr}_free
            eval unset ${Arr}_ind[NumInd] ${Arr}_val[NumInd]
            (( NumInd < ${Arr}_free )) && (( ${Arr}_free=NumInd ))
            eval Free=\$${Arr}_free
            return 0
        else
            return 1
        fi
    }
    #----------------------
    typeset Arr=$1 Index=$2 num=1
    typeset -i  NumInd=1 Arr_cnt
    eval Arr_cnt=\$${Arr}_cnt
    (( Arr_cnt )) || (( Arr_cnt=1 ))
    while [[ $num -le $Arr_cnt && $NumInd -ne 0 ]]; do 
        aDeletePart "${Arr}_${num}" "$Index"
        NumInd=$?
        (( NumInd==0 )) && break
        let num+=1;
    done
    return $NumInd
}
# Usage: AGetLgeArrayPtrQnty <arrayname> 
# Retrieves the quonity of arrays in the array group <arrayname>_num
function AGetLgeArrayPtrQnty
{
    typeset Arr=$1
    typeset -i arraysqnt=0
    eval arraysqnt=\${#${Arr}_large[*]}
    return $arraysqnt
}
# Usage: AGetAll2File <arrayname> <varname>
# All of the indices of array <arrayname> are stored in shell array <varname>
# with indices starting with 0.
# The total number of indices is returned.
function AGetAll2File
{
    typeset Arr=$1 FileName=$2 ElemVal NumNonNull=0 i=1 
    if [[ $FileName = "" ]];then
        echo "[WARN]  $0: File name is not defined...exiting"
        return 0
    fi
    typeset -i  Arr_cnt
    eval Arr_cnt=\$${Arr}_cnt
    (( Arr_cnt )) || (( Arr_cnt=1 ))
    #echo "[$LINENO] $0: Arr_cnt = '$Arr_cnt'"
    typeset -i num_array=1 num_elem=1
    >$FileName
    while [[ $i -le $Arr_cnt ]]; do
        typeset ElemNum=1 NElem
        NumNonNull=0 
        #echo "[$LINENO] AGetAllToFile: i = '$i'"
        eval NElem=\${#${Arr}_${i}_ind[*]}
        #echo "[$LINENO] AGetAllToFile: i = '$i' ... NElem = '$NElem'"
        while (( num_elem <= $MAX_ARRAY_SIZE && NumNonNull < NElem )); do
            eval ElemVal=\"\${${Arr}_${i}_ind[ElemNum]}\"
            if [[ -n $ElemVal ]]; then
                eval VarName=\$ElemVal
                echo "$VarName">>$FileName
                (( NumNonNull+=1 ))
            fi
            (( ElemNum+=1 ))
        done
        ((i+=1))
    done
    return $NumNonNull
}
# Usage: AGetAll <arrayname> <varname>
# All of the indices of array <arrayname> are stored in shell array <varname>
# with indices starting with 0.
# The total number of indices is returned.
function AGetAll
{
    #echo "[WARN]  Function '$0' is deprecated. Only first $MAX_ARRAY_SIZE elements of array will be returned"
    #echo "        Rework please your script and use the function 'AGetAll2File' instead of '$0'"
    
    # BASH has no array-size limitation
    typeset -i NElem ElemNum=1 NumNonNull=0
    typeset Arr=$1 VarName=$2 ElemVal
    eval NElem=\${#${Arr}_1_ind[*]}
    while (( ElemNum <= $MAX_ARRAY_SIZE && NumNonNull < NElem )); do
        eval ElemVal=\"\${${Arr}_1_ind[ElemNum]}\"
        if [[ -n $ElemVal ]]; then
            eval $VarName[NumNonNull]=\$ElemVal
            ((NumNonNull+=1))
        fi
        ((ElemNum+=1))
    done
    return $NumNonNull
}
# Usage: APrintAll <arrayname> [<sep>]
# For each value stored in <arrayname>, a line containing the index and value
# is printed in the form: index<sep>value
# If <sep> is not passed, '=' is used.
# The total number of indices is returned.
function APrintAll
{
    #print "Calling APrintALL: $1"
    typeset -i  NumNonNull=0 i=1
    typeset Arr=$1 Sep=$2 ElemVal ElemInd
    (( $# < 2 )) && Sep="="
    typeset -i  Arr_cnt
    eval Arr_cnt=\$${Arr}_cnt
    (( Arr_cnt )) || (( Arr_cnt=1 ))
    while [[ $i -le $Arr_cnt ]]; do
        typeset ElemNum=1 NElem
        NumNonNull=0 
        eval NElem=\${#${Arr}_${i}_ind[*]}
        while (( ElemNum <= $MAX_ARRAY_SIZE && NumNonNull < NElem )); do
            eval ElemInd=\"\${${Arr}_${i}_ind[ElemNum]}\" \
            ElemVal=\"\${${Arr}_${i}_val[ElemNum]}\"
        if [[ -n $ElemInd ]]; then
            echo "$ElemInd$Sep$ElemVal"
            ((NumNonNull+=1))
        fi
        ((ElemNum+=1))
        done
        ((i+=1))
    done
    return $NumNonNull
}
# Usage: ANElem <arrayname>
# The total number of indices in <arrayname> is returned.
function ANElem
{
    typeset Arr=$1 
    typeset -i  Arr_cnt NElem NElemCur num=1
    eval Arr_cnt=\$${Arr}_cnt
    (( Arr_cnt )) || (( Arr_cnt=1 ))
    while [[ $num -le $Arr_cnt && $NumInd -eq 0 ]]; do 
        eval NElemCur=\${#${Arr}_${num}_ind[*]}
        (( NElem+=NElemCur ))
        (( num+=1 ))
    done
    echo "$NElem"
}

# Usage: InArray <arrayname> <var>
# Finds the value <var> in given global array
# Returns 0 if found and 1 otherwise
function InArray
{
    typeset Arr=$1 Var=$2
    typeset i=0
    eval NElem=\${#${Arr}[*]}
    while [[ $NElem -gt $i ]];do 
        eval ElemVal=\"\${${Arr}[i]}\"
        if [ "$ElemVal" = "$Var" ]; then
            return 0
        fi
        let i+=1;
    done
    return 1
}

#======================================================================================================
#   trims - removes whitespaces
#======================================================================================================
function trims
{
    str=$1
    #str=`echo "$str" | sed 's/^'"$(echo '\011')*"'//g;s/^ *//g'`
    #str=`echo "$str" | sed 's/'"$(echo '\011')*$"'//g;s/ *$//g'`
    str=`echo "$str" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'`
    echo "$str"
}

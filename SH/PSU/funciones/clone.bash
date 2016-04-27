function clone(){
#Variables
local PATH1=$1
local PATH2=$2
local ORACLE_HOME=$3
local ORACLE_BASE=$4
local OSDBA_GROUP=`cat $ORACLE_HOME/rdbms/lib/config.c | grep 'define SS_DBA_GRP' | awk -F '"' '{print $2}'`
local OSOPER_GROUP=`cat $ORACLE_HOME/rdbms/lib/config.c | grep 'define SS_OPER_GRP' | awk -F '"' '{print $2}'`
#Copiado
cp $PATH1 $PATH2
#Clonado
if [ -s $OSOPER_GROUP ];
	then 
		perl $ORACLE_HOME/clone/bin/clone.pl ORACLE_HOME=$ORACLE_HOME ORACLE_HOME_NAME=MyOraHome_db_2 ORACLE_BASE=$ORACLE_BASE OSDBA_GROUP=$OSDBA_GROUP OSOPER_GROUP=$OSOPER_GROUP
	else
		OSOPER_GROUP=$OSDBA_GROUP
		perl $ORACLE_HOME/clone/bin/clone.pl ORACLE_HOME=$ORACLE_HOME ORACLE_HOME_NAME=MyOraHome_db_2 ORACLE_BASE=$ORACLE_BASE OSDBA_GROUP=$OSDBA_GROUP OSOPER_GROUP=$OSOPER_GROUP
	fi
}
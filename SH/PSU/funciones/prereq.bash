function prereq(){
#Variables
local USER=$1
local ORACLE_HOME=$2
local PATCH=$3
#Prerequisitos
sudo -u $USER $ORACLE_HOME/OPatch/opatch prereq CheckConflictAmongPatchesWithDetail -oh $ORACLE_HOME -phBaseDir $PATCH
sudo -u $USER $ORACLE_HOME/OPatch/opatch prereq CheckConflictAgainstOHWithDetail -oh $ORACLE_HOME -phBaseDir $PATCH
sudo -u $USER $ORACLE_HOME/OPatch/opatch prereq CheckActiveFilesAndExecutables -oh $ORACLE_HOME -phBaseDir $PATCH
sudo -u $USER $ORACLE_HOME/OPatch/opatch prereq CheckSystemSpace -oh $ORACLE_HOME -phBaseDir $PATCH
}
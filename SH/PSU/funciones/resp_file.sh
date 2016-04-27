function resp_file(){
#Variables
local ORACLE_HOME=$1
local PATHRF=$2
#Response file
$ORACLE_HOME/OPatch/ocm/bin/emocmrsp -no_banner -output $PATHRF/file.rsp
}
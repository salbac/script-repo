function opatch(){
#Variables
local OPATCH=$1
local PSUPATCH=$2
local ORACLE_HOME=$3
local RESP=$4
local DBVERSIONS=$5
local OSARCH=$6
local VOPATCH=`$ORACLE_HOME/OPatch/opatch version | grep 'OPatch Version' | awk -F ":" '{print $2}'`
local OP3=`echo $VOPATCH | awk -F "." '{print $4}'`
local OP4=`echo $VOPATCH | awk -F "." '{print $5}'`
#Version OPATCH
if [ $OSARCH = x86_64 ];
	then
		case $DBVERSION in
		11.2.0.3)
			if [[ $OP3 -ge 3 ]] && [[ $OP4 -ge 0 ]];
			then
			echo "Opatch ok"
			else 
			#Actualizar OPATCH
			mv $ORACLE_HOME/OPatch OPatch-BCK
			cp $ORACLE_BASE/admin/work/APAR/REPO/p6880880_112000_LINUX.zip $ORACLE_HOME
			mkdir OPatch
			unzip p6880880_112000_LINUX-x86-64.zip
			fi
		;;
		11.2.0.4)
			if [[ $OP3 -ge 3 ]] && [[ $OP4 -ge 6 ]];
			then
			echo "Opatch ok"
			else 
			#Actualizar OPATCH
			mv $ORACLE_HOME/OPatch OPatch-BCK
			cp $ORACLE_BASE/admin/work/APAR/REPO/p6880880_112000_LINUX.zip $ORACLE_HOME
			mkdir OPatch
			unzip p6880880_112000_LINUX-x86-64.zip
			fi
		;;
		esac
	else
		case $DBVERSION in
		11.2.0.3)
			if [[ $OP3 -ge 3 ]] && [[ $OP4 -ge 0 ]];
			then
			echo "Opatch ok"
			else 
			#Actualizar OPATCH
			mv $ORACLE_HOME/OPatch OPatch-BCK
			cp $ORACLE_BASE/admin/work/APAR/REPO/p6880880_112000_LINUX.zip $ORACLE_HOME
			mkdir OPatch
			unzip p6880880_112000_LINUX.zip
			fi
		;;
		11.2.0.4)
			if [[ $OP3 -ge 3 ]] && [[ $OP4 -ge 6 ]];
			then
			echo "Opatch ok"
			else 
			#Actualizar OPATCH
			mv $ORACLE_HOME/OPatch OPatch-BCK
			cp $ORACLE_BASE/admin/work/APAR/REPO/p6880880_112000_LINUX.zip $ORACLE_HOME
			mkdir OPatch
			unzip p6880880_112000_LINUX.zip
			fi
		;;
		esac
#Aplicacion PSU
if [ $RAC='TRUE' ];
	then
	$ORACLE_HOME/OPatch/opatch auto $PSUPATCH -oh $ORACLE_HOME -ocmrf $RESP
	else
	$ORACLE_HOME/OPatch/opatch apply $PSUPATCH -oh $ORACLE_HOME -ocmrf $RESP
fi
}
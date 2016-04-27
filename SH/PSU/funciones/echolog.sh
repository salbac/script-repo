#Funcion que inserta mensajes en un fichero de log INFO/ERROR/WARNING
#
#Variables
LDATE=$(date "+%d-%m-%Y_%H:%M:%S") #FOrmato de fecha
LOG=$ORACLE_BASE/admin/work/APAR/LOG/$FLOG #Path del log
#Funcion
function echolog(){
local MSGLOG=$1
case "$MSGLOG" in
	INFO)
	echo "INFO@${LDATE}: $@"  | awk '{printf ("%s\n", $0);system("");}'  | tee -a ${LOG} >&2
	;;
	ERROR)
	echo "ERROR@${LDATE}: $@"  | awk '{printf ("%s\n", $0);system("");}' | tee -a ${LOG} >&2
	;;
	WARNING)
	echo "WARNING@${LDATE}: $@"  | awk '{printf ("%s\n", $0);system("");}' | tee -a ${LOG} >&2
	;;
esac
}

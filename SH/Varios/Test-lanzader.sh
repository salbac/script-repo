#----------------------------------------------------------------------------
#--     Id: test.sh 1 2015-08-17 
#----------------------------------------------------------------------------
#--     IT Now
#--     
#----------------------------------------------------------------------------
#--     File-Name........:  test.sh
#--     Author...........:  Sergio Alba 
#--     Editor...........:  Sergio Alba
#--     Date.............:  2015-08-17
#--     Revision.........:  0
#--     Purpose..........:  Ejecuta SQL en las BBDD desde SHELL		 
#--     Usage............:  ./test.sh
#--     Group/Privileges.:  DBA
#--     Input parameters.:  none
#--     Called by........:  DBA o acceso a vistas V$
#--     Restrictions.....:  unknown
#--     Notes............:
#----------------------------------------------------------------------------
#--		 Revision history.:      
#----------------------------------------------------------------------------
#!/bin/ksh
ALL_DATABASES=`cat /etc/oratab|grep -v "^#"|grep -v "N$"|cut -f1 -d: -s`
for DB in $ALL_DATABASES
do
   VPATH=$PATH
   export ORACLE_SID=$DB
   USR=`ps -ef |grep ora_dbw0 |grep -v grep |grep $DB} | awk '{print $1}'`
   export ORACLE_HOME=`grep "^${DB}:" /etc/oratab|cut -d: -f2 -s`
   export PATH=$ORACLE_HOME/bin:$PATH
   export ORACLE_TERM=xterm
   export LD_LIBRARY_PATH=$ORACLE_HOME/lib:/lib:/usr/lib
   echo "---> Database $ORACLE_SID, using home $ORACLE_HOME"
   echo "---> Path $PATH"
   echo "---> Terminal $ORACLE_TERM"
   echo "---> Library $LD_LIBRARY_PATH"
   echo "---> OS user $USR"
  
	sudo su - $USR -c sqlplus / as sysdba 
	@<<-EOF
	set serveroutput on;
	set verify on
	set termout on
	set feedback on
	set linesize 130
	select instance_name, status from V/$INSTANCE;
	exit;
	EOF

   unset ORACLE_SID
   unset ORACLE_HOME
   unset LD_LIBRARY_PATH
   unset ORACLE_TERM
   export PATH=$VPATH
done




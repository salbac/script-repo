#Setea variables para todas las instancias y ejecuta un script
#!/bin/ksh
ALL_DATABASES=`cat /etc/oratab|grep -v "^#"|grep -v "N$"|cut -f1 -d: -s`
for DB in $ALL_DATABASES
do
   unset  TWO_TASK
   export ORACLE_SID=$DB
   export ORACLE_HOME=`grep "^${DB}:" /etc/oratab|cut -d: -f2 -s`
   export PATH=$ORACLE_HOME/bin:$PATH
   echo "---> Database $ORACLE_SID, using home $ORACLE_HOME"
   sqlplus -s system/${DB}password @<<-EOF
select * from global_name;
exit;
EOF
done
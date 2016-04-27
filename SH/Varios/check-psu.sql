set serveroutput on;
set verify on
set termout on
set feedback on
set linesize 130

DECLARE
    ora_fixpack       varchar2(50);

BEGIN
---
--- FIXPACK
---
SELECT * into ora_fixpack FROM (select comments from sys.registry$history WHERE bundle_series = 'PSU' ORDER BY action_time) suppliers2 WHERE rownum <= 1 ORDER BY rownum;
--- PRINT FIXPACK
dbms_output.put_line('FIXPACK='||ora_fixpack);
---
END;
/

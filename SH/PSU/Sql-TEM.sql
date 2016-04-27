Javier Castellano Olarte
13:23
-- Politicas de HC ejecutadas el dia de hoy para maquinas con fecha igual al dia de hoy
-- Se debera comprobar que el exit code sea 0 y que la fecha de finalizacion sea del dia de hoy
use BFEnterprise;
select b.computerid as Computerid
     , substring(comp.Value,1,LEN(comp.Value)-1) AS ComputerName
     , ltrim(rtrim(a.name)) as Action
     , rtrim(a.sitename) as Site
     , DATEADD(hour, DATEDIFF(hour, GETUTCDATE(), GETDATE()),b.starttime) as starttime_local
     , DATEADD(hour, DATEDIFF(hour, GETUTCDATE(), GETDATE()),b.endtime) as endtime_local
     , b.endtime-b.starttime as tempstotal
     , b.ExitCode as exitcode
from BES_ACTIONS a
      , ACTIONRESULTS b
      , BES_COLUMN_HEADINGS comp
	  , BES_COLUMN_HEADINGS hc_dates
where a.ActionID=b.ActionID 
      and a.computerid=b.computerid
      and a.NAME like '**NO PARAR**%' and a.NAME not like '%POL_Deploy%'
      and a.ComputerID=comp.ComputerID
      and comp.Name='Computer Name'
	  and (a.SITENAME like 'C024-T-%' or a.SITENAME like 'C024-GTS-S-%')
      and hc_dates.ComputerID=comp.ComputerID
      and hc_dates.Name='ITnow_HC_Dates'
      and hc_dates.Value like  '%' + substring(convert(char, getdate(),105),1,2) + '-' + substring(convert(char, getdate()),1,3) +'%'
      and DATEADD(hour, DATEDIFF(hour, GETUTCDATE(), GETDATE()),b.starttime) > convert(date,GETDATE())
order by b.endtime desc
go

USE master
GO

SELECT @@VERSION as 'SQL Server Version';

--1
------ Disk space
--
SELECT
	DISTINCT volumes.logical_volume_name AS LogicalName,
    volumes.volume_mount_point AS Drive,
    CONVERT(INT,volumes.available_bytes/1024/1024/1024) AS FreeSpace,
    CONVERT(INT,volumes.total_bytes/1024/1024/1024) AS TotalSpace,
    CONVERT(INT,volumes.total_bytes/1024/1024/1024) - CONVERT(INT,volumes.available_bytes/1024/1024/1024) AS OccupiedSpace
FROM sys.master_files mf
CROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.FILE_ID) volumes
ORDER BY Drive

--2
------ Database file space usage
--

USE tempdb
GO

SELECT DB_NAME() AS DbName, 
    name AS FileName, 
    type_desc,
    ROUND(size/128.0, 2) AS CurrentSizeMB,  
    size/128.0 - CAST(FILEPROPERTY(name, 'SpaceUsed') AS INT)/128.0 AS FreeSpaceMB

FROM sys.database_files
WHERE type IN (0,1);

--
--
--
SELECT 
	DB_NAME(database_id) AS [Database Name], 
    type_desc, 
    size/128.0/1024 AS [Current Size MB],
	SUBSTRING(physical_name, 1, 3) AS [Drive],
	name AS [File Name]
FROM sys.master_files
WHERE database_id > 6 AND type IN (0)
ORDER BY [Database Name], [Current Size MB]
GO

--3
------ Logs Status
--

DBCC SQLPERF(LOGSPACE)
GO

--3
------ Jobs Status
--

USE msdb
SELECT name AS [Job Name]
         ,CONVERT(VARCHAR,DATEADD(S,(run_time/10000)*60*60 /* hours */ 
          +((run_time - (run_time/10000) * 10000)/100) * 60 /* mins */ 
          + (run_time - (run_time/100) * 100)  /* secs */
           ,CONVERT(DATETIME,RTRIM(run_date),113)),100) AS [Time Run]
         ,CASE WHEN enabled=1 THEN 'Enabled' 
               ELSE 'Disabled' 
          END [Job Status]
         ,CASE WHEN SJH.run_status=0 THEN 'Failed'
                     WHEN SJH.run_status=1 THEN 'Succeeded'
                     WHEN SJH.run_status=2 THEN 'Retry'
                     WHEN SJH.run_status=3 THEN 'Cancelled'
               ELSE 'Unknown' 
          END [Job Outcome]
FROM   sysjobhistory SJH 
JOIN   sysjobs SJ 
ON     SJH.job_id=sj.job_id 
WHERE  step_id=0 
AND SJH.run_status <> 1
AND    DATEADD(S, 
  (run_time/10000)*60*60 /* hours */ 
  +((run_time - (run_time/10000) * 10000)/100) * 60 /* mins */ 
  + (run_time - (run_time/100) * 100)  /* secs */, 
  CONVERT(DATETIME,RTRIM(run_date),113)) >= DATEADD(d,-1,GetDate()) 
ORDER BY [Time Run] DESC
GO

--4
------ Backup Last Status
--
USE master
GO

SELECT  
   --CONVERT(CHAR(100), SERVERPROPERTY('Servername')) AS Server, 
   msdb.dbo.backupset.database_name,  
   MAX(msdb.dbo.backupset.backup_finish_date) AS last_db_backup_date
FROM   msdb.dbo.backupmediafamily  
   INNER JOIN msdb.dbo.backupset 
   ON msdb.dbo.backupmediafamily.media_set_id = msdb.dbo.backupset.media_set_id  
WHERE  msdb..backupset.type = 'D'
GROUP BY 
   msdb.dbo.backupset.database_name  
ORDER BY  
   msdb.dbo.backupset.database_name 
GO


/*
SELECT 
	percent_complete, 
	start_time, 
	status, 
	command, 
	estimated_completion_time, 
	cpu_time, 
	total_elapsed_time
FROM 
	sys.dm_exec_requests
WHERE
	command in ('DbccSpaceReclaim','DbccFilesCompact')

*/



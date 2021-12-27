## SQL server Clusterless Availability Group Read-Scale for 
This will run on Linux Docker.
 
This code uses the image of SQL Server docker to setup Availability Group Read-Scale in Clusterless architecture.  It does not support fail over or DR.
 
This version is not working, seems have problem to restore backup db maybe I am not using same password.  
### How to Use
 
1. Run the following command in this directory:
 
```
docker-compose up [-d] [--build] [--force-recreate] [--remove-orphans]
```
It will take about 2 minutes to configure the environment
 
2. Connect to the SQL Server instances using the sa login and the passowrd listed in the docker-compose.yml file.
 
3. When done, clean up the environment by running
```
docker-compose down
```
 
### Detail 
 
It will create 3 containers (db1, db2, db3) host 3 SQL instances. Each will have DEVDB database. 
 
db1 is the primary instance. db2, db3 are readonly replica. 
 
The script will restore DEVDB from a bak file. It has some test study data in.  We can also use published script from db solution. The script need some clean up for this purpose. 
 
3 Sql instances run on default prot 1433, and mapped to host on port 1535, 1635, 1735 respectively.
 
There is an Avaialbility Group Listener runs on db1 on port 1540, mapped to host 1540. It handles read/write traiffic and load balance for read load among db2/3.
 
### Testing
Please wait until DB instance is full up. Check log in contailer for the status. 

From the host, you can connect to each instance directly by specifying the Server name as "localhost,1x35" with sa passowrd found in docker-compose.yml;.  ag_login should also works. To connect to port 1635 or 1735, with database as DEVDB, you must also supply Addintional Connection Parameter ***'ApplicationIntent=ReadOnly'***, otherwise it will fail with message:
```
The target database ('DEVDB') is in an availability group and is currently accessible for connections when the application intent is set to read only.
```
 
 
To take advantage of AG, client needs to connect localhost,1540, with and without 'ApplicationIntent=ReadOnly' for write/read and readonly. 
 
After connect, issue 
```
select  @@SERVERNAME, * from study 
```
 
To see it jumps among db2/3 for readonly connection, need try disconnect and reconnect a few times with quite a few minutes wating. And it should never connect to db1.
 
You can also try to update the table in master (connect to port 1535, or 1540 without Addintional Connection Parameter) and check the changes in the secondary replica. It should happen almost instantly. 
 
Attempt to update data in salve, should fail. 
 
 
### Utilities
 
Connect to primary, run T-SQL scripts:
 
```
use master
GO
 
SELECT * FROM sys.availability_group_listeners
 
SELECT   AVGSrc.replica_server_name AS SourceReplica   
    , AVGRepl.replica_server_name AS ReadOnlyReplica
    , AVGRepl.read_only_routing_url AS RoutingURL
    , AVGRL.routing_priority AS RoutingPriority
FROM sys.availability_read_only_routing_lists AVGRL
INNER JOIN sys.availability_replicas AVGSrc ON AVGRL.replica_id = AVGSrc.replica_id
INNER JOIN sys.availability_replicas AVGRepl ON AVGRL.read_only_replica_id = AVGRepl.replica_id
INNER JOIN sys.availability_groups AV ON AV.group_id = AVGSrc.group_id
ORDER BY SourceReplica
 
select *
FROM    sys.availability_group_listeners AVGLis
INNER JOIN sys.availability_groups AV on AV.group_id = AVGLis.group_id
 
 
```


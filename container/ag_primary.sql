USE [master]
GO

IF NOT EXISTS(SELECT * from sys.databases where name = 'DEVDB')
BEGIN

    RESTORE DATABASE DEVDB FROM DISK = N'/var/opt/mssql/backup/DEVDB.bak' WITH FILE = 1, NORECOVERY, NOUNLOAD, STATS = 10


    RESTORE LOG DEVDB FROM DISK = N'/var/opt/mssql/backup/DEVDB.trn' WITH FILE = 1, NORECOVERY, NOUNLOAD, STATS = 10

    PRINT 'Restore DEVDB done'
    RESTORE DATABASE DEVDB WITH RECOVERY

    --change recovery model and take full backup for db to meet requirements of AG
    ALTER DATABASE [DEVDB] SET RECOVERY FULL ;

    USE [master]

    --create logins for AG
    -- this password could also be originate from an environemnt variable passed in to this script through SQLCMD
    CREATE LOGIN ag_login WITH PASSWORD = 'AbcY123!';
    CREATE USER ag_user FOR LOGIN ag_login;

    -- create certificate for AG
    -- this password could also be originate from an environemnt variable passed in to this script through SQLCMD
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'AbcY123!';


    CREATE CERTIFICATE ag_certificate WITH SUBJECT = 'ag_certificate';
    BACKUP CERTIFICATE ag_certificate
    TO FILE = '/var/opt/mssql/shared/ag_certificate.cert'
    WITH PRIVATE KEY (
            FILE = '/var/opt/mssql/shared/ag_certificate.key',
            ENCRYPTION BY PASSWORD = 'AbcY123!'
        );


    -- create HADR endpoint on port 5022
    CREATE ENDPOINT [Hadr_endpoint]
    STATE=STARTED
    AS TCP (
        LISTENER_PORT = 5022,
        LISTENER_IP = ALL
    )
    FOR DATA_MIRRORING (
        ROLE = ALL,
        AUTHENTICATION = CERTIFICATE ag_certificate,
        ENCRYPTION = REQUIRED ALGORITHM AES
    )

    GRANT CONNECT ON ENDPOINT::Hadr_endpoint TO [ag_login];

    ---------------------------------------------------------------------------------------------
    --CREATE PRIMARY AG GROUP ON PRIMARY CLUSTER PRIMARY REPLICA
    -- https://docs.microsoft.com/en-us/sql/t-sql/statements/create-availability-group-transact-sql?view=sql-server-ver15
    ---------------------------------------------------------------------------------------------
    --for clusterless AG the failover mode always needs to be manual

    CREATE AVAILABILITY GROUP [AG]
    WITH (
        CLUSTER_TYPE = NONE
    )
    FOR REPLICA ON
    N'db1' WITH
    (
        ENDPOINT_URL = N'tcp://db1:5022',
        AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
        SEEDING_MODE = AUTOMATIC,
        FAILOVER_MODE = MANUAL,
        PRIMARY_ROLE( ALLOW_CONNECTIONS = READ_WRITE,
                    READ_ONLY_ROUTING_LIST = (('db2','db3'),'db1')
                    ),
        SECONDARY_ROLE (ALLOW_CONNECTIONS = READ_ONLY,READ_ONLY_ROUTING_URL = N'TCP://localhost:1535')
    ),
    N'db2' WITH
    (
        ENDPOINT_URL = N'tcp://db2:5022',
        AVAILABILITY_MODE = SYNCHRONOUS_COMMIT, --ASYNCHRONOUS_COMMIT
        SEEDING_MODE = AUTOMATIC,
        FAILOVER_MODE = MANUAL,
        SECONDARY_ROLE (ALLOW_CONNECTIONS = READ_ONLY, READ_ONLY_ROUTING_URL = N'TCP://localhost:1635') 
    ),
    N'db3' WITH
    (
        ENDPOINT_URL = N'tcp://db3:5022',
        AVAILABILITY_MODE = SYNCHRONOUS_COMMIT,
        SEEDING_MODE = AUTOMATIC,
        FAILOVER_MODE = MANUAL,
        SECONDARY_ROLE (ALLOW_CONNECTIONS = READ_ONLY, READ_ONLY_ROUTING_URL = N'TCP://localhost:1735') 
    );;


    --wait a bit and add database to AG
    USE [master]

    WAITFOR DELAY '00:00:10'
    ALTER AVAILABILITY GROUP [AG] ADD DATABASE [DEVDB]


    -- created AG listener
    DECLARE @create_listener AS NVARCHAR(200)
    SELECT @create_listener =  N'ALTER AVAILABILITY GROUP AG ADD LISTENER N''ag-listener'' ( WITH IP ((N''' 
        + CONVERT(nvarchar, CONNECTIONPROPERTY('local_net_address')) + ''', N''255.255.255.240'')), PORT=1540)'

    print @create_listener
    exec sp_executesql @create_listener

    -- ALTER AVAILABILITY GROUP AG ADD LISTENER N'ag-listener' ( WITH IP ((N'172.27.0.2', N'255.255.255.240')), PORT=1540);
END

GO

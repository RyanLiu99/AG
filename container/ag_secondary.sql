USE [master]

IF NOT EXISTS(SELECT * from sys.databases where name = 'DEVDB')
BEGIN

    --create login for AG, used by end point
    -- this password could also be originate from an environemnt variable passed in to this script through SQLCMD
    -- it should however, match the password from the primary script
    CREATE LOGIN ag_login WITH PASSWORD = 'AbcY123!';
    CREATE USER ag_user FOR LOGIN ag_login;

    -- create certificate
    -- this time, create the certificate using the certificate file created in the primary node
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'AbcY123!';

    -- this password could also be originate from an environemnt variable passed in to this script through SQLCMD
    -- it should however, match the password from the primary script
    CREATE CERTIFICATE ag_certificate
        AUTHORIZATION ag_user
        FROM FILE = '/var/opt/mssql/shared/ag_certificate.cert'
        WITH PRIVATE KEY (
        FILE = '/var/opt/mssql/shared/ag_certificate.key',
        DECRYPTION BY PASSWORD = 'AbcY123!'
    )

    --create HADR endpoint

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

    --add current node to the availability group

    ALTER AVAILABILITY GROUP [AG] JOIN WITH (CLUSTER_TYPE = NONE)
    ALTER AVAILABILITY GROUP [AG] GRANT CREATE ANY DATABASE
END
GO


CREATE DATABASE DanpheSAAS;

Go 

CREATE TABLE [DanpheSAAS].[dbo].Tenants (
    Id INT IDENTITY(1000,1) PRIMARY KEY,
    HospitalName VARCHAR(100) NOT NULL,
  HospitalShortName NVARCHAR(100),
  Email NVARCHAR(100) NOT NULL,
    ContactNumber VARCHAR(20),
    TenantId NVARCHAR(100) UNIQUE,
  IsPaid bit,
    WebUrl NVARCHAR(200),
  CreatedOn datetime
);

Go

CREATE TABLE [DanpheSAAS].[dbo].Configuration (
    ParameterId INT IDENTITY(1,1) PRIMARY KEY,
    ParameterName NVARCHAR(100),
    ParameterValue NVARCHAR(100),
    Description NVARCHAR(MAX)
);

Go

INSERT INTO [DanpheSAAS].[dbo].Configuration ( ParameterName, ParameterValue)VALUES
    ( '-sourcePath', 'Y:\Danphe International3.3 Prod\Danphe International3.3 Prod'), 
  ( '-destinationPath', 'Y:\IIS\'),
    ( '-danpheDbPath', 'Y:\Automate\web_hosting\web_hosting\DEV_DanpheEMR_INT.bak'),
  ( '-danpheAdminScriptPath', 'Y:\Automate\web_hosting\web_hosting\DanpheAdmin_CompleteDB.sql'),
   ('-powerShellScriptPath', 'F:\SAAS\DanpheSAAS.ps1'),
   ('-serverName', 'DESKTOP-BA3DBD9\SQLEXPRESS01') ;


Go

  CREATE TABLE [DanpheSAAS].[dbo].EmailProviders
  (id INT  identity(1000,1)  primary key,
	EmailProviders varchar(100))

Go

CREATE TABLE [DanpheSAAS].[dbo].ErrorLog 
(LogId INT IDENTITY(1,1) PRIMARY KEY,
    ErrorText NVARCHAR(MAX),
	LogDateTime DATETIME,
    TenantId NVARCHAR(MAX));



	
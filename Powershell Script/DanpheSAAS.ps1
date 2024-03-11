param (
    [string]$websiteName,
    [string]$sourcePath,
    [string]$destinationPath,
    [string]$danpheDbPath,
    [string]$danpheAdminScriptPath,
    [string]$serverName
)
if (-not $websiteName -or -not $sourcePath -or -not $destinationPath -or -not $danpheDbPath -or -not $danpheAdminScriptPath -or -not $serverName) {
    Write-Host "Usage: ./DanpheSASS.ps1 -websiteName <WebsiteName> -sourcePath <PathToWebsite> -destinationPath <DestinationPath> -danpheDbPath <danpheDbPath> -danpheAdminScriptPath <danpheAdminScriptPath> -serverName <SQL serverName>"
    exit
}
$ErrorActionPreference = 'Stop'  #Halts the script when error occurs

#===============================================DB Automate=====================================================

function Restore-Database {
    param (
        [string]$dbName,
        [string]$dbPath,
        [string]$serverName
    )

    Push-Location
    Import-Module "sqlps" -DisableNameChecking
    Pop-Location

    $server = New-Object Microsoft.SqlServer.Management.Smo.Server $serverName
    $restore = New-Object Microsoft.SqlServer.Management.Smo.Restore
    $device = New-Object Microsoft.SqlServer.Management.Smo.BackupDeviceItem $dbPath, "FILE"
    $restore.Devices.Add($device)

    try {
        $filelist = $restore.ReadFileList($server)
    }
    catch {
        $exception = $_.Exception
        Write-Host "$exception. `n`nDoes the SQL Server service account have access to the backup location?" -ForegroundColor Red
        throw
        exit 1
    }

    $filestructure = @{}; $datastructure = @{}; $logstructure = {}
    $logfiles = $filelist | Where-Object { $_.Type -eq "L" }
    $datafiles = $filelist | Where-Object { $_.Type -ne "L" }

    # Data Files (if the database has filestreams, make sure the server has them enabled)
    $defaultdata = $server.DefaultFile
    $defaultlog = $server.DefaultLog
    if ($defaultdata.Length -eq 0) {
        $defaultdata = $server.Information.MasterDBPath
    }

    if ($defaultlog.Length -eq 0) {
        $defaultlog = $server.Information.MasterDBLogPath
    }

    foreach ($file in $datafiles) {
        $newfilename = "$dbName" + "_" + [System.Guid]::NewGuid().ToString() + ".mdf"
    
        # Create a new $datastructure object for each iteration
        $datastructure = @{}
        $datastructure.physical = "$defaultdata\$newfilename"
        $datastructure.logical = $file.LogicalName
        $filestructure.Add($file.LogicalName, $datastructure)
    }

    # Log Files
    foreach ($file in $logfiles) {
        $newfilename = "$dbName" + "_" + [System.Guid]::NewGuid().ToString() + ".ldf"

        $logstructure = @{}
        $logstructure["physical"] = "$defaultlog\$newfilename"
        $logstructure["logical"] = $file.LogicalName
        $filestructure[$file.LogicalName] = $logstructure
    }


    # Make sure big restores don't timeout
    $server.ConnectionContext.StatementTimeout = 0

    foreach ($file in $filestructure.Values) {
        $movefile = New-Object "Microsoft.SqlServer.Management.Smo.RelocateFile"
        $movefile.LogicalFileName = $file.logical
        $movefile.PhysicalFileName = $file.physical
        $null = $restore.RelocateFiles.Add($movefile)
    }

    # Write-Host "Restoring $dbName to $serverName" -ForegroundColor Yellow

    # Kill all connections
    $server.KillAllProcesses($dbName)

    $restore.add_PercentComplete($percent)
    $restore.PercentCompleteNotification = 1
    $restore.add_Complete($complete)
    $restore.ReplaceDatabase = $true
    $restore.Database = $dbName
    $restore.Action = "Database"
    $restore.NoRecovery = $false

    # Take the most recent backup set if there are more than one
    $restore.FileNumber = $restore.ReadBackupHeader($server).Rows.Count

    $restore.sqlrestore($serverName)
    
    Write-Host "Restore complete!" -ForegroundColor Green

}

function Restore-DanpheAdmin {
    param(
        [string]$sqlScriptFilePath,
        [string]$dbName,
        [string]$serverName
    )

    # Define variables
    $sqlScriptFilePath = $danpheAdminScriptPath
    $connectionString = "Server=$serverName;Integrated Security=True;"

    try {
        # Read the contents of the SQL script file
        $sqlScript = Get-Content -Path $sqlScriptFilePath -Raw

        # Replace text in the SQL script
        $sqlScript = $sqlScript -replace [regex]::Escape("DanpheAdmin"), $dbName

        # Write the updated SQL script back to the file
        $sqlScript | Set-Content -Path $sqlScriptFilePath

        # Write-Host "Text replaced successfully in the SQL script."

        # Create a connection to the SQL Server instance
        $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)

        # Open the connection
        $connection.Open()

        # Execute SQL script batches
        $sqlBatches = $sqlScript -split "GO\b" | Where-Object { $_ -match '\S' }

        foreach ($batch in $sqlBatches) {
            $command = New-Object -TypeName System.Data.SqlClient.SqlCommand($batch, $connection)
            $command.ExecuteNonQuery()
        }

        Write-Host "SQL script executed successfully."
    }
    catch {
        # Write-Error "An error occurred: $_"
        throw
    }
    finally {
        # Close the connection
        if ($connection.State -eq 'Open') {
            $connection.Close()
        }
    }

    # Revert changes in the SQL script
    $sqlScript = Get-Content -Path $sqlScriptFilePath -Raw
    $sqlScript = $sqlScript -replace [regex]::Escape($dbName), "DanpheAdmin"
    $sqlScript | Set-Content -Path $sqlScriptFilePath

    Write-Host "Text reverted successfully in the SQL script."
}


#===============================================DB Automate=====================================================



#=============================================IIS Automate======================================================

$destinationPath = Join-Path -Path $destinationPath -ChildPath $websiteName
$myport = $null
# $ipv4Address = (ipconfig | Select-String -Pattern 'IPv4 Address').ToString().Split(":")[-1].Trim()

function Get-FreePort {
    param (
        [int]$portRangeStart,
        [int]$portRangeEnd
    )
    # Loop through the port range and find a free port
    for ($port = $portRangeStart; $port -le $portRangeEnd; $port++) {
        $result = Test-NetConnection -ComputerName localhost -Port $port

        if (-not $result.TcpTestSucceeded) {
            return $port
        }
    }
}

function Set-InboundRules {
    param (
        [string]$Name,
        [int]$Port
    )
    # Define rule properties
    $description = "Allow inbound traffic on port $Port"
    $protocol = "TCP"
    $action = "Allow"

    # Check if a rule with the same rule name already exists
    $existingRule = Get-NetFirewallRule -Name $Name -ErrorAction SilentlyContinue

    if ($null -ne $existingRule) {
        # Delete the existing rule
        try {
            Remove-NetFirewallRule -Name $Name
            Write-Host "Existing firewall rule with name '$Name' has been deleted."
        }
        catch {
            Write-Host "Error deleting existing firewall rule: $_"
        }
    }

    # Create the rule
    try {
        New-NetFirewallRule -DisplayName $Name `
            -Description $description `
            -Name $Name `
            -Protocol $protocol `
            -LocalPort $Port `
            -Action $action
    }
    catch {
        throw
    }

}

function Update-ConnectionStrings {
    param (
        [string]$dbDanpheEMR,
        [string]$dbDanpheAdmin,
        [string]$jsonFilePath,
        [string]$serverName
    )
    if (Test-Path $jsonFilePath -PathType Leaf) {
        $appsettingJson = Get-Content $jsonFilePath -raw | ConvertFrom-Json
        #alter connection strings
        $appsettingJson.Connectionstring = "Data Source=$serverName;Initial Catalog=$dbDanpheEMR;Integrated Security=True;MultipleActiveResultSets=true"
        $appsettingJson.ConnectionStringAdmin = "Data Source=$serverName; Initial Catalog=$dbDanpheAdmin; Integrated Security=True"
        $appsettingJson.ConnectionStringPACSServer = "Data Source=$serverName; Initial Catalog=Danphe_PACS; Integrated Security=True"
        $appsettingJson | ConvertTo-Json | Set-Content -Path $jsonFilePath
    }
    else {
        throw "AppSetting not found"
    }
}



function New-WebAppWithAppPool {

    param (
        [string]$Name
    )
    if (-not (Get-Module -ListAvailable -Name WebAdministration)) {
        Import-Module WebAdministration
    }

    if (Test-Path "IIS:\AppPools\$Name") {
        Write-Host "Application pool '$Name' already exists."
    }
    else {
        # Write-Host "Application pool '$Name' does not exist."
        New-WebAppPool -Name $Name 
        Set-ItemProperty "IIS:\AppPools\$Name" -Name "managedRuntimeVersion" -Value ""
        # Write-Host "Application pool '$Name' created successfully."

        # Create a new IIS website and associate it with the application pool
        New-WebSite -Name $Name -PhysicalPath $destinationPath -Port $myport -ApplicationPool $Name -Force
        
        Start-WebSite -Name $Name
        Write-Host "Website deployed successfully with application pool."
    }
}

function New-DbUserLogin {
    param (
        [string]$UserName,
        [string]$dbDanpheEMR,
        [string]$dbDanpheAdmin,
        [string]$serverName

    )
    # Creating server security logins
    # Import the SQL Server module for powershell

    
    Push-Location
    Import-Module "sqlps" -DisableNameChecking
    Pop-Location

    # Set the server and database variables

    # Set the login and user variables
    $login = "IIS APPPOOL\$UserName"
    $user = "IIS APPPOOL\$UserName"

    # Create the login
    Invoke-Sqlcmd -ServerInstance $serverName -Database "master" -Query "CREATE LOGIN [$login] FROM WINDOWS;"

    # Add the login to the server role
    Invoke-Sqlcmd -ServerInstance $serverName -Database "master" -Query "ALTER SERVER ROLE sysadmin ADD MEMBER [$login];"

    # Create user mapping for Database1
    Invoke-Sqlcmd -ServerInstance $serverName -Database $dbDanpheAdmin -Query "CREATE USER [$user] FOR LOGIN [$login];"

    # Create user mapping for Database2
    Invoke-Sqlcmd -ServerInstance $serverName -Database $dbDanpheEMR -Query "CREATE USER [$user] FOR LOGIN [$login];"

    # Grant role membership for Database1
    Invoke-Sqlcmd -ServerInstance $serverName -Database $dbDanpheAdmin -Query "ALTER ROLE db_datareader ADD MEMBER [$login];"
    Invoke-Sqlcmd -ServerInstance $serverName -Database $dbDanpheAdmin -Query "ALTER ROLE db_datawriter ADD MEMBER [$login];"
    Invoke-Sqlcmd -ServerInstance $serverName -Database $dbDanpheAdmin -Query "ALTER ROLE db_owner ADD MEMBER [$login];"
    Invoke-Sqlcmd -ServerInstance $serverName -Database $dbDanpheAdmin -Query "ALTER ROLE db_securityadmin ADD MEMBER [$login];"

    # Grant role membership for Database2
    Invoke-Sqlcmd -ServerInstance $serverName -Database $dbDanpheEMR -Query "ALTER ROLE db_datareader ADD MEMBER [$login];"
    Invoke-Sqlcmd -ServerInstance $serverName -Database $dbDanpheEMR -Query "ALTER ROLE db_datawriter ADD MEMBER [$login];"
    Invoke-Sqlcmd -ServerInstance $serverName -Database $dbDanpheEMR -Query "ALTER ROLE db_owner ADD MEMBER [$login];"
    Invoke-Sqlcmd -ServerInstance $serverName -Database $dbDanpheEMR -Query "ALTER ROLE db_securityadmin ADD MEMBER [$login];"

}



function Add-AndSaveUrlToDb {
    param (
        [string]$serverName,
        [string]$databaseName,
        [string]$tableName,
        [string]$columnName,
        [string]$valueToUpdate,
        [string]$whereCondition
    )

    $connectionString = "Server=$serverName;Database=$databaseName;Integrated Security=True;"

    try {
        # Create a connection to the SQL Server instance
        $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)

        # Open the connection
        $connection.Open()

        # Construct the SQL update query
        $updateQuery = "UPDATE $tableName SET $columnName = '$valueToUpdate' WHERE $whereCondition"

        # Create a command object
        $command = New-Object -TypeName System.Data.SqlClient.SqlCommand($updateQuery, $connection)

        # Execute the command
        $rowsAffected = $command.ExecuteNonQuery()

        Write-Host "$rowsAffected row(s) updated successfully."
    }
    catch {
        Write-Error "An error occurred: $_"
        throw
    }
    finally {
        # Close the connection
        if ($connection.State -eq 'Open') {
            $connection.Close()
        }
    }
} 

function Get-IpAddress {
    # Get all network interfaces and their IP addresses excluding loopback and link-local addresses
    $allIPAddresses = [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() | 
    Where-Object { $_.OperationalStatus -eq 'Up' -and $_.Supports([System.Net.NetworkInformation.NetworkInterfaceComponent]::IPv4) } | 
    ForEach-Object { $_.GetIPProperties().UnicastAddresses } | 
    Where-Object { $_.Address.AddressFamily -eq 'InterNetwork' -and `
            $_.Address.IPAddressToString -notlike '127.*' -and `
            $_.Address.IPAddressToString -notlike '169.254.*' } | 
    ForEach-Object { $_.Address.IPAddressToString }

    # Check if any suitable IP addresses are found
    if ($allIPAddresses.Count -eq 0) {
        Write-Host "No suitable IP addresses found."
        exit
    }

    # Choose a random IP address from the collected list
    $randomIpAddress = $allIPAddresses | Get-Random
    return $randomIpAddress
}


function Add-ErrorLogToDb {
    param (
        [string]$serverName,
        [string]$databaseName,
        [string]$tableName,
        [string]$errorText,
        [string]$tenantId
    )

    $connectionString = "Server=$serverName;Database=$databaseName;Integrated Security=True;"

    try {
        # Create a connection to the SQL Server instance
        $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)

        # Open the connection
        $connection.Open()

        # Construct the SQL insert query
        $insertQuery = "INSERT INTO $tableName (ErrorText, LogDateTime, TenantId) VALUES ('$errorText', GETDATE(), '$tenantId')"

        # Create a command object
        $command = New-Object -TypeName System.Data.SqlClient.SqlCommand($insertQuery, $connection)

        # Execute the command
        $rowsAffected = $command.ExecuteNonQuery()

        Write-Host "$rowsAffected row(s) inserted successfully."
    }
    catch {
        Write-Error "An error occurred: $_"
        throw
    }
    finally {
        # Close the connection
        if ($connection.State -eq 'Open') {
            $connection.Close()
        }
    }
}





try {

    # Initialize progress variables
    $totalTasks = 9
    $currentTask = 0

    # Function to update progress
    function Update-Progress {
        param(
            [string]$activity
        )
        $currentTask++
        $percentComplete = ($currentTask / $totalTasks) * 100
        Write-Progress -Activity $activity -Status "Progress" -PercentComplete $percentComplete
    }

    # Get a free port
    Update-Progress -activity "Getting a free port"
    $myport = Get-FreePort -portRangeStart 49152 -portRangeEnd 65535
    Write-Host "Free port: $myport" -ForegroundColor Blue

    # Restore database
    Update-Progress -activity "Restoring database"
    Restore-Database -dbName $websiteName -dbPath $danpheDbPath -servername $serverName

    # Restore DanpheAdmin database
    Update-Progress -activity "Restoring DanpheAdmin database"
    Restore-DanpheAdmin -sqlScriptFilePath $danpheAdminScriptPath -dbName ("DanpheAdmin_" + $websiteName) -serverName $serverName

    # Set inbound rules
    Update-Progress -activity "Setting inbound rules"
    Set-InboundRules -Name $websiteName -Port $myport

    # Copy files
    Update-Progress -activity "Copying files"
    Copy-Item -Path $sourcePath -Destination $destinationPath -Recurse

    # Update connection strings
    Update-Progress -activity "Updating connection strings"
    Update-ConnectionStrings -dbDanpheEMR $websiteName -dbDanpheAdmin ("DanpheAdmin_" + $websiteName) -jsonFilePath "$destinationPath\appsettings.json" -serverName $serverName

    # Create new web application with application pool
    Update-Progress -activity "Creating web application"
    New-WebAppWithAppPool -Name $websiteName

    # Create new database user login
    Update-Progress -activity "Creating database user login"
    New-DbUserLogin -UserName $websiteName -dbDanpheEMR $websiteName -dbDanpheAdmin ("DanpheAdmin_" + $websiteName) -serverName $serverName

    Update-Progress -activity "Gettin IP address"
    $ipv4Address = Get-IpAddress

    Update-Progress -activity "Saving Tenant URL To Database"
    Add-AndSaveUrlToDb -serverName $serverName  `
        -databaseName "DanpheSAAS" `
        -tableName "Tenants" `
        -columnName "WebUrl" `
        -valueToUpdate ("http://" + "$ipv4Address" + ":" + "$myport") `
        -whereCondition "Tenants.TenantId = '$websiteName'"


    # Call the function to add error log to the database
    
    Write-Host "Setup completed successfully" -ForegroundColor Green
    Write-Host ("Tenant URL : http://" + "$ipv4Address" + ":" + "$myport")
} 
catch {
    Write-Host "Error: $_" -ForegroundColor Yellow
    Add-ErrorLogToDb -serverName $serverName -databaseName "DanpheSAAS" -tableName "ErrorLog" -errorText "Error: $_" -tenantId $websiteName
    # throw
}






Import-Module PSRemoteRegistry
$servers = @(import-csv("servers.csv"))

foreach($server in $servers)
{
    $isalive = Test-RegKey -CN $server.name -Hive LocalMachine -Key "Software" -Ping
    if($isalive) {
        $cstatus = "Connected"
        $exists = Test-RegKey -CN $server.name -Hive LocalMachine -Key "Software\Microsoft\Microsoft Operations Manager\3.0\Agent Management Groups\MyCompanyCorp"
        if($exists) {
            Write-Host "$($server.name) - Removing MyCompanyCorp key"
            Remove-RegKey -CN $server.name -Hive LocalMachine -Key "Software\Microsoft\Microsoft Operations Manager\3.0\Agent Management Groups\MyCompanyCorp" -R -F
            $status = "Removed"
        } else {
            Write-Host "$($server.name) - The MyCompanyCorp key does not exist"
            $status = "Does not exist"
        }

        $fexists = Test-RegKey -CN $server.name -Hive LocalMachine -Key "Software\Microsoft\Microsoft Operations Manager\3.0\Agent Management Groups\MyCompanyMonitoring"
        if($fexists) {
            Write-Host "$($server.name) - The MyCompanyMonitoring exists"
            $fstatus = "Exists"
        } else {
            Write-Host "$($server.name) - The MyCompanyMonitoring key does not exist"
            $fstatus = "Does not exist"
        }
        
    } else {
        Write-Host "$($server.name) - Failed to connect to remote registry"
        $cstatus = "Failed to connect"
        $status = "N/A"
        $fstatus = "N/A"
    }
    
    $objOutput = New-Object PSObject -Property @{
        Server = $server.name
        Connected = $cstatus
        MyCompanyCorp = $status
        MyCompanyMonitoring = $fstatus
    }
    
    $objreport+=@($objoutput)
}

$objreport | select Server, Connected, MyCompanyCorp, MyCompanyMonitoring | export-csv -notype report.csv

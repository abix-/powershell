﻿function Set-DNS {
    [CmdletBinding(SupportsShouldProcess=$false, ConfirmImpact='Medium')]
    param (
        [Parameter(Position = 1,Mandatory = $true)]
        [alias("c")]
        $csv,
        [switch]$cred
    )

    if($cred) { $usercred = Get-Credential }
    $servers = @(Import-Csv $csv)
    foreach ($_s in $servers){
        $nics = $null
        $thisnic = $null
        Write-Progress -Status "Working on $($_s.ComputerName)" -Activity "Gathering Data"
        if((Test-Connection -ComputerName $_s.ComputerName -count 1 -ErrorAction 0)) {
            if(!$cred) { $nics = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter IPEnabled=TRUE -ComputerName $_s.ComputerName -ErrorAction Stop }
            else { $nics = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter IPEnabled=TRUE -ComputerName $_s.ComputerName -ErrorAction Stop -Credential $usercred }
            if($_s.'NIC Index' -and $_s.'Primary DNS') {
                $thisnic = $nics | ?{$_.Index -eq $_s.'NIC Index'}
                    if($thisnic) {
                    Write-Host "$($_s.ComputerName) - $($_s.'NIC Index') - Current DNS Servers: $($thisnic.DNSServerSearchOrder)"
                    Write-Host "$($_s.ComputerName) - $($_s.'NIC Index') - Set DNS servers to: $($_s.'Primary DNS') $($_s.'Secondary DNS') $($_s.'Tertiary DNS')"
            
                    if($($_s.'Primary DNS')) {
                        [array]$newdns = $($_s.'Primary DNS')
                        if($($_s.'Secondary DNS') -ne "N/A") { $newdns += $($_s.'Secondary DNS') }
                        if($($_s.'Tertiary DNS') -ne "N/A") { $newdns += $($_s.'Tertiary DNS') }
                    } else { Write-Host "You must have a Primary DNS specified in the input CSV"; pause; continue }
           
                    if($confirm -ne "A") { $confirm = Read-Host "$($_s.ComputerName) - Yes/No/All (Y/N/A)" }
                    switch ($confirm) {
                        "Y" {setDNS $_s.ComputerName $thisnic $newdns}
                        "N" {}
                        "A" {setDNS $_s.ComputerName $thisnic $newdns}
                    }
                } else { Write-Host "$($_s.ComputerName) - $($_s.'NIC Index') - NIC not found" }
            } else { Write-Host "The input CSV does not appear to be valid results from Get-DNS.ps1"; Exit }     
        } else { Write-Host "$($_s.ComputerName)  - Is offline" } 
    }
}

function Get-DNS {
    [cmdletbinding()]
    param (
	    [parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
	    [string[]] $servers = $env:computername,
        $scriptPath = (Get-Location).Path,
        [switch]$cred
    )

    if($cred) { $usercred = Get-Credential }
    $i = 0
    $results = @()
    if($servers.EndsWith(".txt")) {
        $output = $servers  -replace "\\","_" -replace "\.txt","" -replace "\.",""
        $outputFile = "$scriptPath\Get-DNS$($output).csv"
        $servers = gc $servers
    } else { $outputFile = "$scriptPath\$servers.csv" }
    foreach($_s in $servers) {
        $i++
        Write-Progress -Status "[$i/$($servers.count)] $($_s) " -Activity "Gathering Data" -PercentComplete (($i/$servers.count)*100)
        $result = @()
        $networks = $null
	    if(Test-Connection -ComputerName $_s -Count 3 -ea 0) {
		    try {
                if(!$cred) {
			        $Networks = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter IPEnabled=TRUE -ComputerName $_s -ErrorAction Stop
                } else {
                    $Networks = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter IPEnabled=TRUE -ComputerName $_s -ErrorAction Stop -Credential $usercred
                }
		    } catch {
			    Write-Host "Failed to Query $_s. Error details: $_"
                $result = addToDNSObj $_s.ToUpper() "Failed WMI Query"
                $results += $result
                continue
		    }
		    foreach($Network in $Networks) {
			    $DNSServers = $Network.DNSServerSearchOrder
			    $NetworkName = $Network.Description
			    If(!$DNSServers) {
				    $PrimaryDNSServer = $SecondaryDNSServer = $TertiaryDNSServer = "N/A"
			    } else {
                    if($Network.DNSServerSearchOrder[0]) { $PrimaryDNSServer = $DNSServers[0] } else { $PrimaryDNSServer = "N/A" }
                    if($Network.DNSServerSearchOrder[1]) { $SecondaryDNSServer = $DNSServers[1] } else { $SecondaryDNSServer = "N/A" }
                    if($Network.DNSServerSearchOrder[2]) { $TertiaryDNSServer = $DNSServers[2] } else { $TertiaryDNSServer = "N/A" }
                }
			    If($network.DHCPEnabled) { $IsDHCPEnabled = $true } else { $IsDHCPEnabled = $false }
                $results += addToDNSObj $_s.ToUpper() "Online" $network.Index $network.IPAddress[0] $PrimaryDNSServer $SecondaryDNSServer $TertiaryDNSServer $IsDHCPEnabled $NetworkName
		    }
	    } else {
		    Write-Host "$_s not reachable"
            $results += addToDNSObj $_s.ToUpper() "Ping Failed"
	    }
    }
    $results
    $results | Export-Csv $outputFile -NoTypeInformation
    Write-Host "Results have been written to '$outputFile'"
}

function Get-Uptime {
    [cmdletbinding()]
    Param (
        $servers,
        $cred
    )

    if($servers.EndsWith(".txt")) { $servers = gc $servers }
    if(!$cred) { $scred = Get-Credential } 
    else { $scred = $cred }

    foreach($_s in $servers) {
        Get-WmiObject -ComputerName $_s -ClassName win32_operatingsystem -Credential $scred |  select csname, @{LABEL='LastBootUpTime';EXPRESSION={$_.ConverttoDateTime($_.lastbootuptime)}}
    }
}

function Clear-DNSCache {
    ipconfig /flushdns
    netsh interface ip delete destinationcache
}

function setDNS($computer,$nic,$newDNS) {
    $x = $nic.SetDNSServerSearchOrder($newDNS) 
    if($x.ReturnValue -eq 0) { Write-Host "$computer - Successfully changed DNS Servers" } 
    else { Write-Host "$computer - Failed to change DNS Servers" }
}

function addToDNSObj($cn="N/A",$stat="N/A",$index="N/A",$ip="N/A",$pdns="N/A",$sdns="N/A",$tdns="N/A",$dhcp="N/A",$name="N/A") {
    $obj = New-Object -Type PSObject
    $obj | Add-Member -MemberType NoteProperty -Name ComputerName -Value $cn
    $obj | Add-Member -MemberType NoteProperty -Name Status -Value $stat
    $obj | Add-Member -MemberType NoteProperty -Name "NIC Index" -Value $index
    $obj | Add-Member -MemberType NoteProperty -Name "IP Address" -Value $ip
	$obj | Add-Member -MemberType NoteProperty -Name "Primary DNS" -Value $pdns
	$obj | Add-Member -MemberType NoteProperty -Name "Secondary DNS" -Value $sdns
    $obj | Add-Member -MemberType NoteProperty -Name "Tertiary DNS" -Value $tdns
	$obj | Add-Member -MemberType NoteProperty -Name IsDHCPEnabled -Value $dhcp
	$obj | Add-Member -MemberType NoteProperty -Name NetworkName -Value $name
    return $obj
}

function Get-Firmware {
    [cmdletbinding()]
    Param (
        $vmhost
    )

    function writeToObj($vmhost,$firmware="N/A",$driver="N/A") {
        return 
    }

    if($vmhost.EndsWith(".txt")) { $vmhost = gc $vmhost }

    $allobj = @()
    foreach($v in $vmhost) {
        $i++
        $nic = "N/A"
        Write-Progress -Activity "Reading data from $v" -Status "[$i/$($vmhost.count)]" -PercentComplete (($i/$vmhost.count)*100)
        $esxcli = Get-EsxCli -VMHost $v
        $nic = $esxcli.network.nic.get("vmnic4")
        $allobj += New-Object PSObject -Property @{
            Host = $vmhost
            Firmware = $firmware
            Driver = $driver
        }
    
        writeToObj $v $nic.driverinfo.firmwareversion $nic.driverinfo.version
    }

    $allobj | select Host, Firmware, Driver
}

function Wait-Service {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory=$true)][string]$ServiceName,
        [int]$WaitMinutes = 1
    )
    $ServiceObj = $null
    do {
        Write-Host "[$ServiceName] Waiting for service to enter Running state"
        $ServiceObj = Get-WmiObject -Class win32_service -Filter "Name='$ServiceName'"
        Sleep -Seconds 10
    } while (($ServiceObj -eq $null) -or ($ServiceObj.State -ne "Running"))

    $ProcessID = $ServiceObj.ProcessID
    do {
        $ProcessObj = Get-WmiObject -Class win32_process -Filter "ProcessID='$ProcessID'"
        $ServiceCreationDate = $ServiceObj.ConvertToDateTime($ProcessObj.CreationDate)
        Write-Host "[$ServiceName] Process at PID $ProcessID was created at [$ServiceCreationDate]"
        Sleep -Seconds 10
    } while ($ServiceCreationDate.AddMinutes($WaitMinutes) -gt (Get-Date))
    Write-Host "[$ServiceName] Started on [$ServiceCreationDate] More than $WaitMinutes minutes have elapsed"
}
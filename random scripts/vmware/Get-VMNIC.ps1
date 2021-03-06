[cmdletbinding()]
Param (
    $servers,
    [switch]$cred
)

function GetNic($server,$credential,$eaction) {
    if(!$cred) { 
        $nic = get-vm $server | Get-VMGuestNetworkInterface -ea $eaction| where {($_.name -like "*Local Area Connection*") -and ($_.description -like "*Ethernet Adapter*")}
    } else { 
        $nic = get-vm $server | Get-VMGuestNetworkInterface -guestcredential $credential -ea $eaction | where {($_.name -like "*Local Area Connection*") -and ($_.description -like "*Ethernet Adapter*")} 
    }
    return $nic
}

$serverlist = gc $servers
if(!$serverlist) {
    Write-Host "No servers were found in $servers"
    Exit
}

$connection = connect-viserver my-vcenter.domain.local

if($cred) {
    $credential = Get-Credential -credential $null
}

$allobj = @()
foreach($server in $serverlist) {
    try { $vm = get-vm $server -ea "STOP" }
    catch { 
        Write-Host "$server - Was not found"
        $obj = New-Object -TypeName PSObject -Property @{
     		Hostname = $server
            NIC = ""
            Status = "VM not found"
     		IPPolicy = ""
     		IP = ""
            SubnetMask = ""
            DefaultGateway = ""
            DnsPolicy = ""
            "Primary DNS" = ""
            "Secondary DNS" = ""
            "Tertiary DNS" = ""
            
    	}
        $allobj += $obj
    }
    if($vm.PowerState -eq "PoweredOn") {
        Write-Host "$server - Connecting"
        try { $nic = GetNic $server $credential "STOP" }
        catch { 
            Write-Host "$server - Failed to connect with credential1"
            if(!$credential2) { $credential2 = Get-Credential -credential $null }
            Write-Host "$server - Attempting connection with credential2"
            $nic = GetNic $server $credential2 "CONTINUE"
        }
        
        Write-Host "$server - Correlating data"
        if($nic.count -gt 1) {
            Write-Host "$server - There is more than one NIC. No actions performed."
        } elseif($nic) {
            if ($nic.DNS.Count -gt 1){
                $pdns = $nic.DNS[0]
                $sdns = $nic.DNS[1]
                $tdns = $nic.DNS[2]
            } else {
                $pdns = $nic.DNS
                $sdns = ""
                $tdns = ""
            }
            
            $vmnic = Get-NetworkAdapter $vm
            if($vmnic.ConnectionState -like "NotConnected*") {
                $status = "Disconnected"
            } elseif($vmnic.ConnectionState -like "Connected*") {
                $status = "Connected"
            }
            
            $obj = New-Object -TypeName PSObject -Property @{
         		Hostname = $server
                NIC = $nic.Name
                Status = $status
         		IPPolicy = $nic.IPPolicy
         		IP = $nic.Ip
                SubnetMask = $nic.SubnetMask
                DefaultGateway = $nic.DefaultGateway
                DnsPolicy = $nic.DnsPolicy
                "Primary DNS" = $pdns
                "Secondary DNS" = $sdns
                "Tertiary DNS" = $tdns
                
        	}
            $allobj += $obj
        }
    } elseif($vm.PowerState -eq "PoweredOff") {
            $obj = New-Object -TypeName PSObject -Property @{
         		Hostname = $server
                NIC = ""
                Status = $vm.PowerState
         		IPPolicy = ""
         		IP = ""
                SubnetMask = ""
                DefaultGateway = ""
                DnsPolicy = ""
                "Primary DNS" = ""
                "Secondary DNS" = ""
                "Tertiary DNS" = ""
                
        	}
            $allobj += $obj
    }
}

$allobj | Select Hostname,NIC,Status,IPPolicy,IP,SubnetMask,DefaultGateway,DnsPolicy,"Primary DNS","Secondary DNS","Tertiary DNS"
#$allobj | Select Hostname,NIC,Status,IPPolicy,IP,SubnetMask,DefaultGateway,DnsPolicy,"Primary DNS","Secondary DNS","Tertiary DNS" | export-csv results.csv -notype
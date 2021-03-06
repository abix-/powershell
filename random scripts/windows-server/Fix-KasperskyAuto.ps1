[cmdletbinding()]
Param (
    [alias("s")]
    [Parameter(Mandatory=$true)]
    $servers = ""
)

foreach($server in $servers) {
    if((Test-Connection -ComputerName $server -count 1 -ErrorAction 0)) {
        Write-Host "$server - Changing settings"
        sc.exe \\$server config "klnagent" start= auto
        sc.exe \\$server failure "klnagent" reset= 0 actions= none/5000/none/5000/none/5000
        sc.exe \\$server start "klnagent"
    } else { Write-Host "$server - Offline" }
}
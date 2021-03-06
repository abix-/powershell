[cmdletbinding()]
Param (
    [alias("s")]
    [Parameter(Mandatory=$true)]
    $server = ""
)

if((Test-Connection -ComputerName $server -count 1 -ErrorAction 0)) {
    sc.exe \\$server failure "klnagent" reset= 0 actions= none/5000/none/5000/none/5000
} else { Write-Host "$server is offline" }
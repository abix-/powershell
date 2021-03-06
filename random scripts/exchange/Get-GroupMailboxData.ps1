[cmdletbinding()]
Param (
    [parameter(Mandatory=$true)]
    $group
)

$session = new-pssession -cn dc

try { 
    icm { import-module activedirectory }  -session $session
    $members = icm -session $session -script { param($adgroup) get-adgroupmember $adgroup -ea "STOP" } -args $group
}
catch {
    Write-Host $error[0] -foregroundcolor "red"
    Exit
}

remove-pssession -cn wh-dc01

$results = @()
foreach($member in $members) {
    $mailboxstatistics = get-mailboxstatistics $member.samaccountname
    $mailbox = get-mailbox $member.samaccountname
    $obj = New-Object -TypeName PSObject -Property @{
 		Username = $member.samaccountname
        StorageLimitStatus = $mailboxstatistics.StorageLimitStatus
        TotalItemSize = $mailboxstatistics.TotalItemSize
        ProhibitSendQuota = $mailbox.ProhibitSendQuota
        IssueWarningQuota = $mailbox.IssueWarningQuota
	}
    $results += $obj
}

$results | ft Username,TotalItemSize,StorageLimitStatus,ProhibitSendQuota,IssueWarningQuota | sort-object TotalItemSize -Descending

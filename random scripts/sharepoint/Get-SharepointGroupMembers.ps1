[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SharePoint")
$site = New-Object Microsoft.SharePoint.SPSite("http://yourservername/sites/yoursitecollection ")
$groups = $site.RootWeb.sitegroups
foreach ($grp in $groups) {"Group: " + $grp.name; foreach ($user in $grp.users) {"  User: " + $user.name} }
$site.Dispose()

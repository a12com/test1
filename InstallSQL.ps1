#install SQL Server
$cred= Get-Credential "adatum\administrator" 
$pssession = New-PSSession -ComputerName lon-svr2 -Credential $cred
copy-item "C:\Training\SQL_1\ConfigurationFile.ini" -Destination "c:\" -ToSession $pssession
Invoke-Command -ComputerName "lon-svr2" -Credential $cred -ScriptBlock {& d:\setup.exe /ConfigurationFile='c:\ConfigurationFile.ini' }

#install ps version 5.1
#copy-item "C:\Training\SQL_1\SQL_Server\Win8.1AndW2K12R2-KB3191564-x64.msu" -Destination "h:\" -ToSession $pssession
#Invoke-Command -ComputerName "lon-svr2" -Credential $cred -ScriptBlock {& h:\Win8.1AndW2K12R2-KB3191564-x64.msu /quiet}

Enter-PSSession -ComputerName "lon-svr2" -Credential $cred

#Get SQL Server Instance Path:
$SQLService = "SQL Server (inst2)"; 
$SQLInstancePath = "";
$SQLServiceName = ((Get-Service | WHERE { $_.DisplayName -eq $SQLService }).Name).Trim();
If ($SQLServiceName.contains("`$")) { $SQLServiceName = $SQLServiceName.SubString($SQLServiceName.IndexOf("`$")+1,$SQLServiceName.Length-$SQLServiceName.IndexOf("`$")-1) }
foreach ($i in (get-itemproperty "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server").InstalledInstances)
{
  If ( ((Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL").$i).contains($SQLServiceName) ) 
  { $SQLInstancePath = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\"+`
  (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL").$i}
} 
$SQLTcpPath = "$SQLInstancePath\MSSQLServer\SuperSocketNetLib\Tcp"
Get-ChildItem $SQLTcpPath | ForEach-Object {Get-ItemProperty $_.pspath} `
| Format-Table -Autosize -Property @{N='IPProtocol';E={$_.PSChildName}}, Enabled, Active, TcpPort, TcpDynamicPorts, IpAddress

# Set IP protocol's properties:
$IPProtocol="IPALL"   # Options: "IPALL"/"IP4"/"IP6"/Etc
#$Enabled = "0"            # Options: "0" - Disabled / "1" - Enabled
#$Active = "0"              # Options: "0" - Inactive / "1" - Active
$Port = "1433"                   # Options: "0"/"" (Empty)
$DynamicPort = ""    # Options: "0"/"" (Empty)
#$IPAddress="::0"        # There must not be IP Address duplication for any IP Protocol

$SQLTcpPath = "$SQLInstancePath\MSSQLServer\SuperSocketNetLib\Tcp"
Get-ChildItem $SQLTcpPath | ForEach-Object {Get-ItemProperty $_.pspath} `
| Format-Table -Autosize -Property @{N='IPProtocol';E={$_.PSChildName}}, Enabled, Active, TcpPort, TcpDynamicPorts, IpAddress

#Set-ItemProperty -Path "$SQLTcpPath\$IPProtocol" -Name "Enabled" -Value $Enabled
#Set-ItemProperty -Path "$SQLTcpPath\$IPProtocol" -Name "Active" -Value $Active
Set-ItemProperty -Path "$SQLTcpPath\$IPProtocol" -Name "TcpPort" -Value $Port
Set-ItemProperty -Path "$SQLTcpPath\$IPProtocol" -Name "TcpDynamicPorts" -Value $DynamicPort
#Set-ItemProperty -Path "$SQLTcpPath\$IPProtocol" -Name "IPAddress" -Value $IPAddress

Get-ChildItem $SQLTcpPath | ForEach-Object {Get-ItemProperty $_.pspath} `
| Format-Table -Autosize -Property @{N='IPProtocol';E={$_.PSChildName}}, Enabled, Active, TcpPort, TcpDynamicPorts, IpAddress

#restart server to apply changes
Restart-Service -displayname "SQL Server (inst2)"
Import-Module NetSecurity
New-NetFirewallRule -DisplayName "SQL 1433 allow" -Direction Inbound -Protocol Tcp -LocalPort 1433 -Action Allow
Import-Module SQLPS
$qry = (Invoke-Sqlcmd -ServerInstance lon-svr2\inst2 -Query "Select @@servername;").Column1
$VM = $qry.Substring(0, $qry.IndexOf('\'))
$Instance = $qry.Substring($qry.IndexOf('\')+1)

#firewall status 
$Compliance = 'Firewall Not Enabled'
$Check = get-netfirewallprofile | Where-Object {$_.Name -eq 'Domain' -and $_.Enabled -eq 'True'}
$Check = get-netfirewallprofile | Where-Object {$_.Name -eq 'Public' -and $_.Enabled -eq 'True'}
$Check = get-netfirewallprofile | Where-Object {$_.Name -eq 'Private' -and $_.Enabled -eq 'True'}
if ($Check) {$Compliance = 'Firewall Enabled'}
$Compliance
Get-NetFirewallRule -DisplayName "SQL 1433 allow"

#SQL Features list
get-wmiobject win32_product | 
where {$_.Name -match "SQL" -AND $_.vendor -eq "Microsoft Corporation"} | 
select name, version

Exit-PSSession



$ErrorActionPreference = "Continue"

$HTML_HEAD = "<head>
<title>$Family_Name</title>
<style type='text/css'>
body{
background-color: #EDEDED;
margin: 25px 25px 25px 25px;
padding: 0px 0px 0px 0px;
font-size: 11px;
text-align: left;
font-family: arial, helvetica, verdana, sans-serif;
color: #3A5064;
font-weight: normal;
}

hr{
border: 2px;
height: 6px;
border-bottom: 1px dotted #B3B3B3;
}

table{
background-color: transparent;
margin: 0px 0px 0px 0px;
padding: 0px 0px 0px 0px;
border: 2px solid #B3B3B3;
font-size: 11px;
}

td{
padding: 5px 5px 5px 5px;
border-bottom: 1px solid #B3B3B3;
border-right: 1px solid #B3B3B3; 
text-align: left;
vertical-align: top;
}

tr:nth-child(even) td{
background-color:lightblue;
}

tr:hover td{
background-color:grey;
}
</style>
</head>"

# Create Event Collector Log on machine
New-EventLog -LogName "PSEventCollector" -Source "PSEventCollector"

# Get time script was run
$dateTime = Get-Date -format yyyy.MM.dd-HHmm

$ResultFolder = "C:\Log_Review"

# XML search filter location
$XML_LOCATION = $ResultFolder + "\Filters"
# Event log backup folder
$EVENT_LOCATION = $ResultFolder + "\EventLogs"
# Event report location
$dataBackupFolder = $EVENT_LOCATION + ("\" + $env:COMPUTERNAME)
New-Item $dataBackupFolder -type directory
$dataBackupFolder += ("\" + $dateTime)
New-Item $dataBackupFolder -type directory

[regex] $AlertSearch = "104|400|410|1001|1102|2004|2005|4624|4625|4740"
[regex] $Junk = "Security ID:		S-1-5-18*"
# Edit Account Domain to reflect your domain
[regex] $DC_Junk = "Account Name:		.{0,14}\$
	Account Domain:		<DOMAIN>"
[regex] $DC_Junk2 = "New Logon:
	Security ID:		ANONYMOUS LOGON
	Account Name:		ANONYMOUS LOGON"


$EventList = @()
$AlertList = @()

#
# Get all event filters from file, read events from log, write events to report
#

# Get Each XML search filter file
Get-ChildItem -include *.xml -Path $XML_LOCATION -recurse | ForEach-Object {
    [xml] $Filter_XML = Get-Content $_.FullName
    $Family_Name = $Filter_XML.Family.ID
    $EventList = $Filter_XML.Family.event
    
    ForEach ($Event in $EventList) {
        $eventSearch = @(Get-WinEvent -FilterHashtable @{logname=$Event.LogName; providername=$Event.Provider; ID=$Event.ID} -Force)
        If ($Event.ID -match $AlertSearch) { 
            If ($Event.ID -eq "4624") {
                $AlertList = $AlertList + ($eventSearch | Where-Object { $_.Message -notmatch $Junk -and $_.Message -notmatch $DC_Junk -and $_.Message -notmatch $DC_Junk2 })
            } else { $AlertList += $eventSearch }
        }
        $events += $eventSearch
    }
    
    $familyXML = $events | Select-Object TimeCreated, LogName, LevelDisplayName, Level, ProviderName, ContainerLog, ID, Message | Sort-Object TimeCreated | ConvertTo-Html  -title $Family_Name -pre "<h1>$Family_Name</h1>" -head $HTML_HEAD > (($dataBackupFolder + "\" + $Family_Name + ".html"))

    Clear-Variable -Name events
    Clear-Variable -Name Event
}

#
# Write out Alert Report HTML file
#
$Family_Name = "Alerts"
$ReportOut = $AlertList | Select-Object TimeCreated, LogName, LevelDisplayName, Level, ProviderName, ContainerLog, ID, Message | Sort-Object TimeCreated | ConvertTo-Html  -title "Alerts" -pre "<h1>Alerts</h1>" -head $HTML_HEAD > (($dataBackupFolder + "\Alerts.html"))

#
# Pass The Hash Detection
#
$Family_Name = "Pass the Hash"
$PtHEvents = Get-WinEvent -FilterHashtable @{logname="System"; ID=4624; LogonType=3; AuthenticationPackageName="NTLM"}  -Oldest | Where-Object { $_.TargetUserName -ne "ANONYMOUS LOGON" -and $_.TargetDomainName -ne $env:UserDomain }
$PtHXML = $PtHEvents | Select-Object TimeCreated, MachineName, LogName, LevelDisplayName, Level, ProviderName, ContainerLog, ID, Message | Sort-Object TimeCreated | ConvertTo-Html  -title $Family_Name -pre "<h1>$Family_Name</h1>" -head $HTML_HEAD > (($dataBackupFolder + "\Pass_the_Hash.html"))

#
# Special popup reports
#

# Remote Desktop Use
$Family_Name = "Remote Desktop Use"
$RDPEvents = Get-WinEvent -FilterHashtable @{logname="Security"; ID=4624; LogonType=10}  -Oldest
$RDPEvents += Get-WinEvent -FilterHashtable @{logname="Security"; ID=4634; LogonType=10}  -Oldest
$RDPXML = $RDPEvents | Select-Object TimeCreated, MachineName, LogName, LevelDisplayName, Level, ProviderName, ContainerLog, ID, Message | Sort-Object TimeCreated | ConvertTo-Html -title $Family_Name -pre "<h1>$Family_Name</h1>" -head $HTML_HEAD  > (($dataBackupFolder + "\RDP_Events.html"))

# Create directory for log backup
$LogDir = $dataBackupFolder + "\RawLogs"
if(!(Test-Path $LogDir -PathType Container)) { New-Item $LogDir -type directory }

# Backup logs locally
$applog = $LogDir + "\Application.evtx"
$syslog = $LogDir + "\System.evtx"
$seclog = $LogDir + "\Security.evtx"

wevtutil epl Application $applog
wevtutil epl System $syslog
wevtutil epl Security $seclog

# Clear logs after collection
wevtutil cl Application
wevtutil cl System
wevtutil cl Security

# Get event for last time logs were remotely collected
$CollectionCheck = Get-WinEvent -FilterHashtable @{logname="PSEventCollector"; providername="PSEventCollector"; ID=99} -MaxEvents 1 -Force

if ($CollectionCheck.TimeCreated -gt (Get-Date).AddDays(-14)) {
    # Get Folders older than two weeks if collection has occured within the last two weeks
    $OldData = Get-ChildItem "$EVENT_LOCATION\$env:COMPUTERNAME" | Where { $_.CreationTime -lt (Get-Date).AddDays(-14) } | Select Name
	$OldData | ForEach-Object {
		Remove-Item "$EVENT_LOCATION\$env:COMPUTERNAME\$_" -Recurse -Force
	}
}

# Write application specific log event for local event collection
Write-EventLog -LogName "PSEventCollector" -Source "PSEventCollector" -EventId 1 -Message "Log Collection script has completed"
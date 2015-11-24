#
# Manual Remote event collector
#

$ErrorActionPreference = "Continue"

# FIRST RUN VARIABLE
# $Date_Range = (Get-Date).AddDays(-14)  # 14 days earlier than current date-time

$CompName = $env:COMPUTERNAME
$user = $env:USERNAME

$DataSave = "D:\Log_Review"
Import-Module ActiveDirectory
$ServerList = Get-ADComputer -Filter * | Select -Expand Name

#Create Folder structure if it doesn't exist
ForEach ($computer in $ServerList) {
    if(!(Test-Path "$DataSave\$computer" -PathType Container)) {New-Item -ItemType Directory -Path "$DataSave\$computer"}
}

ForEach ($computer in $ServerList) {
    if(Test-Connection -ComputerName $computer -Count 2 -Quiet) {
        # Get last collection run on remote computer
        $CollectionCheck = Get-WinEvent -FilterHashtable @{logname="PSEventCollector"; providername="PSEventCollector"; ID=99} -ComputerName $computer -MaxEvents 1 -Force

        $RemoteFolder = "\\$computer\C$\Log_Review\EventLogs\$computer\"
        $LatestData = Get-ChildItem $RemoteFolder | Where { $_.CreationTime -gt $CollectionCheck.TimeCreated } | Select Name
        # FIRST RUN COLLECTION ACTION on first run only uncomment this line and comment out previous line
        # $LatestData = Get-ChildItem $RemoteFolder | Where { $_.CreationTime -gt $Date_Range }

        $LatestData | ForEach-Object {
			# Copy all log archive data from remote machine to local directory
			Copy-Item "$RemoteFolder\$_" -Destination "$DataSave\$computer" -Recurse
		}

        # Write remote event for remote collection action
        $LatestData | ForEach-Object {
            If (Test-Path "$DataSave\$computer\$_" -PathType) {
                Invoke-Command -ComputerName $computer -ScriptBlock { Write-EventLog -LogName "PSEventCollector" -Source "PSEventCollector" -EventId 99 -Message "Events have been collected by $user from $CompName" }
            }
        }
    }
}
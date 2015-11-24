Installation and configuration of Distributed Log Management Script
-------------------------------------------------------------------

1. Move files to GPO accessible location ( [ on domain controller ] C:\Windows\SYSVOL\domain )
	- Auto_Log_Review.ps1
	- Each file in "Filters" folder
2. Move Remote_Log_Collector.ps1 to system with access to all other systems
	- Edit Remote_Log_Collector.ps1 "$DataSave" variable to point to save location of your choice for the logs and reports that you will be collecting from remote computers.
3. Configure GPO for log collection
	- Make sure to use the server name you will be collecting from as the setting for the WinRM Trusted Hosts
	- Make sure to set the maximum log size so that every system can store more than a week's worth of events. (We don't want Windows to archive the event log)
	- This GPO will enable
		- Powershell Remoting
		- Powershell script running on local computers ( Unrestricted to allow local and remote scripts )
		- WinRM
		- WMI  (May not be needed, more testing required)
		- Firewall exceptions for WinRM and WMI
		- Create folder structure on %SYSTEMDRIVE% for log script and filters
			- Set permissions on this folder to ONLY allow SYSTEM write privileges
		- Create a scheduled task
			- Runs every Sunday at midnight
			- Runs if a user is logged on or not
			- Runs as SYSTEM
			- Runs powershell.exe with script location as flag ( Systems are not configured to run powershell scripts by default )

4. Deploy and Test


NOTES:

-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
Remote_Log_Collector.ps1 is not configured for first run!
-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

Script is configured to query custom log created by log collection script. It is also configured to collect log data from the last time the remote collection was run. This is dependant on the script writing an event to the custom event log.

Local event collection script is configured to archive event logs on local machine and then clear all logs. Verify you have backups of the event logs before testing and deploying. 

Local event collection script is configured to query custom log for remote collection events, if an event is found within the last two weeks all archive data older than two weeks on the local machine will be deleted to save space.

Local event collection script creates HTML reports of each filter family and an HTML report of events to pay special attention to as well as evtx backups of each of the logs. The remote collection script collects all of these things.

If GPO is configured properly Local collection script and filters CANNOT be edited on local machines and only from the SYSVOL folder on the domain controllers.

Remote collection script will query Active Directory for all computer names and run against that list. This means that it will run against Linux machines as well and create errors. They will display but verify hostnames are linux machines and ignore.
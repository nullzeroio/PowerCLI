<#
.SYNOPSIS
	vSphere guest OS & VMware Tools status report
.DESCRIPTION
	This function/script will query ALL guests in the environment and report on some basic guest OS details, as well as VMware Tools details.

	You can either supply a vCenter Server name, or if you are already connected to one, or more, vCenter servers, it will automatically run against all currently connected servers.

	Note: If you supply a vCenter Server name to connect to, the script will first DISCONNECT any currently connected session; this is to guarantee that the results returned are ONLY from the
	server name provided, and not from any others.
.PARAMETER Server
	Name of vCenter server (VI Server)
.INPUTS
	System.String
.OUTPUTS
	System.Management.Automation.PSCustomObject
.EXAMPLE
	.\Invoke-VMwareToolsReport.ps1 -Server VCENTER01.corp.com -Verbose | Out-GridView
.EXAMPLE
	.\Invoke-VMwareToolsReport.ps1 -Verbose | Export-Csv C:\VMWareToolsReport.csv -NoTypeInformation
.NOTES

	#TAG:PUBLIC
		
			GitHub: https://github.com/vScripter
			Twitter: @vScripter
			Email: kevin@vmotioned.com
			Blog: www.vMotioned.com
	
	[-------------------------------------DISCLAIMER-------------------------------------]
	 All script are provided as-is with no implicit
	 warranty or support. It's always considered a best practice
	 to test scripts in a DEV/TEST environment, before running them
	 in production. In other words, I will not be held accountable
	 if one of my scripts is responsible for an RGE (Resume Generating Event).
	 If you have questions or issues, please reach out/report them on
	 my GitHub page. Thanks for your support!
	[-------------------------------------DISCLAIMER-------------------------------------]
	
.LINK
	https://github.com/vScripter
#>

[CmdletBinding()]
param (
	[Parameter(Position = 0,
			   Mandatory = $false,
			   HelpMessage = 'Name of vCenter Server')]
	[System.String]$Server
)

BEGIN {
	
	Write-Verbose -Message 'Checking for VMware.VimAutomation.Core PSSnapin'
	if ((Get-PSSnapin -Name VMware.VimAutomation.Core -ErrorAction 'SilentlyContinue').Name -eq $null) {
		try {
			Add-PSSnapin VMware.VimAutomation.Core -ErrorAction 'Stop'
		} catch {
			Write-Warning -Message "Error adding VMware PSSnapin: $_"
			Write-Warning -Message 'Exiting script'
			Exit
		} # try/catch
	} else {
		Write-Verbose -Message "VMware.VimAutomation.Core PSSnapin is already added; continuing..."
	} # end if/else
	
	if ($Server) {		
		Write-Verbose -Message 'Closing any current vCenter Server connections'
		try {
			Disconnect-VIServer -Server * -Confirm:$false -Force -ErrorAction 'Stop'
		} catch {
			Write-Warning -Message 'Error disconnecting current vCenter server connections; results may not be accurate or output may not be desired'
		} # end try/catch
		
		Write-Verbose -Message 'Connecting to vCenter Server'
		try {			
			$viServer = Connect-VIServer -Server $Server -ErrorAction 'Stop'
		} catch {
			Write-Warning -Message 'Error connecting to vCenter'
			Write-Warning -Message 'Exiting script'
			Exit
		} # end try/catch
		
	} elseif (($global:defaultviserver).Name -eq $null) {
		Write-Warning -Message 'No default vCenter connection. Connect to vCenter or specify a vCenter Server name and try again.'
		Write-Warning -Message 'Exiting script'
		Exit
	} # end if/else

} # end BEGIN block

PROCESS {
	
	Write-Verbose -Message 'Gathering VM details'
	foreach ($vis in ($global:defaultviservers).Name) {
		$guestDetailQuery = $null
		$guestDetailQuery = Get-View -Server $vis -ViewType VirtualMachine -ErrorAction 'Stop'
		
		foreach ($guest in $guestDetailQuery) {
			$objGuestDetail = @()
			$objGuestDetail = [PSCustomObject] @{
				Name = $guest.Name
				HostName = $guest.Guest.HostName
				IPAddress = $guest.Guest.IPAddress
				GuestOS = $guest.Guest.GuestFullName
				ToolsVersion = $guest.Guest.ToolsVersion
				ToolsStatus = $guest.Guest.ToolsStatus
				ToolsVersionStatus1 = $guest.Guest.ToolsVersionStatus
				ToolsVersionStatus2 = $guest.Guest.ToolsVersionStatus2
				ToolsRunningStatus = $guest.Guest.ToolsRunningStatus
				VIServer = $vis
			} # end $objGuestDetail
			
			$objGuestDetail
		} # end foreach $guest
	} # end foreach $vis
	
} # end PROCESS block

END {
	
} # end END block
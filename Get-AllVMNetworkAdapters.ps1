<#
.SYNOPSIS
	Basic script that will list what type of network adapter each powered on guest has been assigned
.DESCRIPTION
	Basic script that will list what type of network adapter each powered on guest has been assigned

	This was originally written to provide a quick way of discovering guests that had a certain network adapter type, such as 'e1000', for the
	entire inventory of guests that are powered on
.PARAMETER Server
	Name of vCenter Server (VI Server)
.INPUTS
	System.String
.EXAMPLE
	.\Get-AllVMNetworkAdapters.ps1 -Server VCENTER01.corp.com -Verbose
.NOTES
	20150120	K. Kirkpatrick
	[+] Added script to repo

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

[cmdletbinding()]
param (
	[parameter(Mandatory = $true,
			   Position = 0)]
	[System.String]$Server
)

BEGIN {
	
	$vmName = @{ Name = "VM"; Expression = { $_.Parent.Name } }
	
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
	
	Write-Verbose -Message "Connecting to vCenter Server '$Server'"
	try {
		Connect-VIServer -Server $Server -ErrorAction 'Stop' | Out-Null
	} catch {
		Write-Warning -Message 'Error connecting to vCenter'
		Write-Warning -Message 'Exiting script'
		Exit
	} # end try/catch
	
} # end BEGIN block

PROCESS {
	Write-Verbose -Message 'Gathering Network Adpater Details for ALL guests'
	
	Get-VM |
	Where-Object { $_.PowerState -eq "PoweredOn" } |
	Get-NetworkAdapter |
	Select-Object $vmName, Name, Type
	
} # end PROCESS block

END {
	Write-Verbose -Message 'Done'
} # end END block
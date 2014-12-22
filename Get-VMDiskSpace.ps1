<#
.SYNOPSIS
	Gather guest OS partition details from a VMware vSphere environment
.DESCRIPTION
	This script/function will return individual partition space details for VMware guests operating systems.
	
	The script/function is geared towards the virtualization administrator that may not have the necessary guest OS credentials or privileges to query partion level disk space details across a heterogeneous guest environment. 

	This script/function pulls the information that is provided by VMware Tools, within the each guest OS. As such, VMware Tools must be installed to query this level of detail via the vSphere API.

	Pipeline input is supported, so you can use it similar to 'Get-DataCenter DC01 | Get-VM | .\Get-VMDiskSpace'.

	The native input format that is required is that of a VI virtual machine (see .INPUTS). Any string values provided will be checked and then attemtpe to be converted to the proper type.
	
	Sample format from '| Format-Table -AutoSize' (See Example 1 for execution details)

Name     Partition CapacityInGB SpaceUsedInGB SpaceFreeInGB PercentFree
----     --------- ------------ ------------- ------------- -----------
WINSRV01 C:\                 50            12            38          76
WINSRV01 D:\                500           419            81          16
WINSRV02 C:\                 60            25            34          58
REDHAT01 /                    8             4             4          49
REDHAT01 /boot                0             0             0          65
REDHAT01 /sda4               49             5            45          91
REDHAT01 /sdb                59             6            53          89

.PARAMETER Name
	Display name of VMware Guest/s
.PARAMETER VIServer
	FQDN of vCenter Server (VI Server)
.INPUTS
	System.String
	VMware.VimAutomation.ViCore.Impl.V1.Inventory.VirtualMachineImpl
.OUTPUTS
	System.Management.Automation.PSCustomObject
.EXAMPLE
	.\Get-VMDiskSpace -Name WINSRV01,WINSRV02,REDHAT01 | Format-Table -AutoSize
.EXAMPLE
	.\Get-VMDiskSpace -Name VM01,VM02 -VIServer vcenter01.company.com -Verbose | Out-GridView
.EXAMPLE
	Get-Cluster CLUS01 | Get-VM | .\Get-VMDiskSpace | Export-Csv C:\VI_CLUS01_DiskSpaceReport.csv -NoTypeInformation
.EXAMPLE
	.\Get-VMDiskSpace -Name (Get-VM VM01,VM02,VM03) | Out-GridView
.NOTES
	Author: Kevin Kirkpatrick
	Last Update: 20141222

	#TAG:PUBLIC
	
	GitHub:	 https://github.com/vN3rd
	Twitter:  @vN3rd
	Email:	 kevin@pinelabs.co

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
	https://github.com/vN3rd
#>

#Requires -Version 3

[cmdletbinding(DefaultParameterSetName = "Default")]
param (
	[parameter(Mandatory = $true,
			   Position = 0,
			   ValueFromPipeline = $true,
			   ValueFromPipelineByPropertyName = $true)]
	[alias('VM', 'Guest')]
	$Name,
	
	[parameter(Mandatory = $false,
			   Position = 1)]
	[string]$VIServer
)

BEGIN {
	<#
	- call/set variables
	- Check if the VMware.VimAutomation.Core PSSnapin had been added; if not, attempt to add it
	- Connect to the provided vCenter Server, if none if provided, check to see if a connection has already been established
	#>
	
	$colFinalResults = @()
	
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
	
	
	Write-Verbose -Message 'Connecting to vCenter Server'
	
	if ($VIServer) {
		try {
			$VIServer = Connect-VIServer -Server $VIServer
		} catch {
			Write-Warning -Message 'Error connecting to vCenter'
			Write-Warning -Message 'Exiting script'
			Exit
		} # end try/catch
	} elseif (($global:defaultviserver).Name -eq $null) {
		Write-Warning -Message 'No default vCenter connection. Connect to vCenter or specify a vCenter Server name and try again.'
		Write-Warning -Message 'Exiting script'
		Exit
	} else {
		$VIServer = $global:defaultviserver
	} # end if/else
	
}# BEGIN

PROCESS {
	
	# call/set variables and varialbe types
	$objGuestDisk = @()
	$vmDetail = $null
	$diskInfo = $null
	[int]$diskCapacity = $null
	[int]$diskSpaceUsed = $null
	[int]$diskSpaceFree = $null
	[int]$diskPercentFree = $null
	
	<#
	- Validate VM type; if strings were passed, convert the type from [System.String] to [VMware.VimAutomation.ViCore.Impl.V1.Inventory.VirtualMachineImpl] by using Get-VM
	- use foreach to interate through the array of guest names passed
	- ignore guests that are powered off
	- store detail in a custom object and add each iteration to the $colFinalResults array
	#>
	
	Write-Verbose -Message 'Validating VM Type'
	
	if (($Name).GetType().Fullname -ne 'VMware.VimAutomation.ViCore.Impl.V1.Inventory.VirtualMachineImpl') {
		try {
			$Name = Get-VM -Name $Name
		} catch {
			Write-Warning -Message "Error converting $Name to a proper VI object type"
			Write-Warning -Message 'Exiting script'
			Exit
		} # end try/catch
	} else {
		Write-Verbose -Message 'VM Type is correct; continuing...'
	} # end if/else
	
	try {
		foreach ($vm in $Name) {
			
			Write-Verbose -Message "Gathering VM Details on $($vm.Name)"
			
			if ($vm.PowerState -eq 'PoweredOff') {
				
				Write-Warning -Message "$($vm.Name) is PoweredOff"
				
			} else {
				$vmDetail = $vm.ExtensionData
			} # end if/else
			
			$diskInfo = $vmDetail.Guest.Disk
			
			foreach ($disk in $diskInfo) {
				if ($disk.Capacity -eq 0) {
					Write-Warning -Message "Disk capacity is zero; zeroing all values for the $($disk.Diskpath) partition on $($vm.name)"
					$diskCapacity = 0
					$diskSpaceUsed = 0
					$diskSpaceFree = 0
					$diskPercentFree = 0
				} else {
					$diskCapacity = $disk.Capacity / 1GB
					$diskSpaceUsed = ($disk.Capacity - $disk.FreeSpace) / 1GB
					$diskSpaceFree = $disk.FreeSpace / 1GB
					$diskPercentFree = ($disk.FreeSpace / $disk.Capacity) * 100
				} # end if/else
				
				$objGuestDisk = [PSCustomObject] @{
					Name = $vm.Name
					Partition = $disk.DiskPath
					CapacityInGB = $diskCapacity
					SpaceUsedInGB = $diskSpaceUsed
					SpaceFreeInGB = $diskSpaceFree
					PercentFree = $diskPercentFree
				} # end $objGuest
				
				$colFinalResults += $objGuestDisk
			} # end forech
		} # end foreach
	} catch {
		Write-Warning -Message "Error Gathering Details - $_"
	} # end try/catch
	
}# end PROCESS

END {
	Write-Verbose -Message 'Done'
	$colFinalResults
	
}# end END
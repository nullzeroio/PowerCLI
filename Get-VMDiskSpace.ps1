<#
.SYNOPSIS
	Gather guest OS partition details from a VMware vSphere environment
.DESCRIPTION
	This script/function will return individual partition space details for VMware guests operating systems.

	The script/function is geared towards the virtualization administrator that may not have the necessary guest OS credentials or
	privileges to query partion level disk space details across a heterogeneous guest environment.

	This script/function pulls the information that is provided by VMware Tools, within the each guest OS. As such, VMware Tools
	must be installed to query this level of detail via the vSphere API.

	Pipeline input is supported, so you can use it similar to 'Get-DataCenter DC01 | Get-VM | .\Get-VMDiskSpace'.

	The native input format that is required is that of a VI virtual machine (see .INPUTS). Any string values provided will be
	checked and then an attempt to convert it to the proper type will be made.

	Also included in the output are 'DatastoreList','VMXPath' and 'DatastoreMapping' properties. Since there is no easy/reliable
	way to correlate: guest partition --> .VMDK --> datastore, the 'DatastoreList' represents all datastores that the guest has
	a current .VMDK on. The 'DatastoreMapping' property contains an actual mapping of which .VMDK is sitting on which datastore.
	The 'VMXPath' property contains the datastore mapping and path to where the .VMX file is located for a partiular guest.
	search in a larger environment.

	This script/function will also create a log directory named 'Get-VMDiskSpaceLogs' in the same directory where the script is ran from.

	Sample output:

Name             : WINSERVER01
Cluster          : CLUS1
VMHost           : prdesxi02.corp.domain
Partition        : C:\
CapacityInGB     : 50
SpaceUsedInGB    : 24
SpaceFreeInGB    : 26
PercentFree      : 51
DatastoreList    : nas01_sata_nonrepl_nfs1, nas01_sata_nonrepl_nfs2
VMXPath          : [nas01_sata_nonrepl_nfs2] WINSERVER01/WINSERVER01.vmx
DatastoreMapping : [nas01_sata_nonrepl_nfs2] WINSERVER01/WINSERVER01.vmdk, [nas01_sata_nonrepl_nfs1] WINSERVER01/WINSERVER01_1.vmdk

Name             : WINSERVER01
Cluster          : CLUS1
VMHost           : prdesxi02.corp.domain
Partition        : E:\
CapacityInGB     : 50
SpaceUsedInGB    : 26
SpaceFreeInGB    : 24
PercentFree      : 47
DatastoreList    : nas01_sata_nonrepl_nfs1, nas01_sata_nonrepl_nfs2
VMXPath          : [nas01_sata_nonrepl_nfs2] WINSERVER01/WINSERVER01.vmx
DatastoreMapping : [nas01_sata_nonrepl_nfs2] WINSERVER01/WINSERVER01.vmdk, [nas01_sata_nonrepl_nfs1] WINSERVER01/WINSERVER01_1.vmdk

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
	Last Update: 20141223
	Last Update Notes:
	- Added 'DatastoreList', 'VMXPath' & 'DatastoreMapping' properties to output
	- Added logging


	#TAG:PUBLIC

	GitHub:	 https://github.com/vScripter
	Twitter:  @vScripter
	Email:	 kevin@vMotioned.com

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
	- define functions
	- call/set variables
	- setup logging
	- Check if the VMware.VimAutomation.Core PSSnapin had been added; if not, attempt to add it
	- Connect to the provided vCenter Server, if none if provided, check to see if a connection has already been established
	#>
	
	function Get-ScriptDirectory {
		if ($hostinvocation -ne $null) {
			Split-Path $hostinvocation.MyCommand.path
		} else {
			Split-Path $script:MyInvocation.MyCommand.Path
		}
	} # end function Get-ScriptDirectory
	
	function TimeStamp {
		$dtLogTimeStamp = Get-Date -Format ("[yyyy-MM-dd HH:mm:ss] ")
		$dtLogTimeStamp
	} # end function TimeStamp
	
	$dtScriptStart = Get-Date
	$dtLogFileName = (Get-Date).ToString("yyyyMMddHHmmss")
	
	$scriptPath = Get-ScriptDirectory
	$logDirectory = "$scriptPath\Get-VMDiskSpaceLogs"
	$log = "$logDirectory\Get-VMDiskSpace_$dtLogFileName.log"
	
	if (-not (Test-Path -Path $logDirectory)) {
		try {
			New-Item -ItemType Directory -Path $scriptPath -Name 'Get-VMDiskSpaceLogs' | Out-Null
		} catch {
			Write-Warning -Message "Error creating log directory '$logDirectory'"
			Write-Warning -Message 'Exiting script'
			Exit
		} # end try/catch
	} # end if/else Test-Path
	
	Write-Output "======== Get-VMDiskSpace - Started - $(TimeStamp) ========" >> $log
	
	$colFinalResults = @()
	
	Write-Verbose -Message 'Checking for VMware.VimAutomation.Core PSSnapin'
	
	if ((Get-PSSnapin -Name VMware.VimAutomation.Core -ErrorAction 'SilentlyContinue').Name -eq $null) {
		try {
			Add-PSSnapin VMware.VimAutomation.Core -ErrorAction 'Stop'
		} catch {
			Write-Warning -Message "Error adding VMware PSSnapin: $_"
			Write-Warning -Message 'Exiting script'
			Write-Output "$(TimeStamp) Error: adding PSSnapin - $_" >> $log
			Write-Output "$(TimeStamp) Error: Exiting script" >> $log
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
			Write-Output "$(TimeStamp) Error: connecting to vCenter - $_" >> $log
			Write-Output "$(TimeStamp) Error: Exiting script" >> $log
			Exit
		} # end try/catch
	} elseif (($global:defaultviserver).Name -eq $null) {
		Write-Warning -Message 'No default vCenter connection. Connect to vCenter or specify a vCenter Server name and try again.'
		Write-Warning -Message 'Exiting script'
		Write-Output "$(TimeStamp) Error: No default vCenter connection. Connect to vCenter or specify a vCenter server name and try again" >> $log
		Write-Output "$(TimeStamp) Error: Exiting script" >> $log
		Exit
	} else {
		$VIServer = $global:defaultviserver
	} # end if/else
	
}# BEGIN

PROCESS {
	<#
	- Validate VM type; if strings were passed, convert the type from [System.String] to [VMware.VimAutomation.ViCore.Impl.V1.Inventory.VirtualMachineImpl] by using Get-VM
	- use foreach to interate through the array of guest names passed
	- ignore guests that are powered off
	- collect data on current datastores that each partition could potentially reside on
	- store detail in a custom object and add each iteration to the $colFinalResults array
	#>
	
	Write-Verbose -Message 'Validating VM Type'
	
	if (($Name).GetType().Fullname -ne 'VMware.VimAutomation.ViCore.Impl.V1.Inventory.VirtualMachineImpl') {
		try {
			$Name = Get-VM -Name $Name -ErrorAction 'Stop'
		} catch {
			Write-Warning -Message "Error converting $Name to a proper VI object type"
			Write-Warning -Message 'Exiting script'
			Write-Output "$(TimeStamp) Error: converting $Name to a proper VI object type" >> $log
			Write-Output "$(TimeStamp) Error: Exiting script" >> $log
			Exit
		} # end try/catch
	} else {
		Write-Verbose -Message 'VM Type is correct or has been converted correctly; continuing...'
	} # end if/else
	
	try {
		foreach ($vm in $Name) {
			# call/set variables and varialbe types
			$objGuestDisk = @()
			$vmDetail = $null
			$diskInfo = $null
			[int]$diskCapacity = $null
			[int]$diskSpaceUsed = $null
			[int]$diskSpaceFree = $null
			[int]$diskPercentFree = $null
			$vmCurrentDatastores = $null
			$dsName = $null
			$dsMap = $null
			$vmVMXPath = $null
			$vmHostDetail = $null
			
			Write-Verbose -Message "Gathering VM details on $($vm.Name)"
			Write-Output "$(TimeStamp) Info: Gatering VM details on $($vm.Name)" >> $log
			
			if ($vm.PowerState -eq 'PoweredOff') {
				
				Write-Warning -Message "$($vm.Name) is Powered Off"
				Write-Output "$(TimeStamp) Warning: $($vm.Name) is Powered Off " >> $log
				
			} else {
				$vmDetail = $vm.ExtensionData
				
				Write-Verbose -Message "Gathering current datastores on $($vm.Name)"
				
				$vmCurrentDatastores = $vmDetail.Config.DatastoreUrl.Name
				
				foreach ($datastore in $vmCurrentDatastores) {
					$dsName += "$datastore, "
				} # end foreach $datastore
				
			<# In regex, '$' indicates the last charater in a string or before '\n' at the end of a line or string; '.' is wildcard for any single charater except for '\n';
			"..$" = remove the last two charaters of the string, which would be a comma and one space, in this scenario. #>
				$dsName = $dsName -replace "..$"
				
				Write-Verbose -Message "Gathering .VMDK <--> Datastore mappings for $($vm.Name)"
				
				$vmDatastoreMap = ($vmDetail.layoutex.file | Where-Object { $_.name -like '*.vmdk' -and $_.name -notlike '*flat*' }).Name
				
				foreach ($mapping in $vmDatastoreMap) {
					$dsMap += "$mapping, "
				} # end foreach $mapping
				
				$dsMap = $dsMap -replace "..$"
				
				
				Write-Verbose -Message "Gathering .VMX path for $($vm.Name)"
				
				$vmVMXPath = $vmDetail.summary.config.vmpathname
				
				
				Write-Verbose -Message "Gathering VM Host details for $($vm.Name)"
				
				try {
					$vmHostDetail = Get-VMHost -Id ($vmDetail.Summary.Runtime.Host) -ErrorAction 'Stop'
				} catch {
					Write-Warning -Message "Error gathering host details"
					Write-Warning -Message 'Exiting script'
					Write-Output "$(TimeStamp) Error: gathering host details - $_" >> $log
					Write-Output "$(TimeStamp) Error: Exiting script" >> $log
					Exit
				} # end try/catch
				
				
				Write-Verbose -Message "Gathering partition details on $($vm.Name)"
				
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
						Cluster = $vmHostDetail.Parent
						VMHost = $vmHostDetail.Name
						Partition = $disk.DiskPath
						CapacityInGB = $diskCapacity
						SpaceUsedInGB = $diskSpaceUsed
						SpaceFreeInGB = $diskSpaceFree
						PercentFree = $diskPercentFree
						DatastoreList = $dsName
						VMXPath = $vmVMXPath
						DatastoreMapping = $dsMap
					} # end $objGuest
					
					$colFinalResults += $objGuestDisk
				} # end foreach $disk
				
			} # end foreach $vm
		} # end if/else
	} catch {
		Write-Warning -Message "Error Gathering Details on $vm - $_"
		Write-Output "$(TimeStamp) Error: Gathering Details on $vm - $_" >> $log
	} # end try/catch
	
}# end PROCESS

END {
	Write-Verbose -Message 'Done'
	$colFinalResults
	$dtScriptEnd = Get-Date
	$dtRuntime = $dtScriptEnd - $dtScriptStart
	Write-Output "======== Total Runtime: $($dtRunTime.Hours) Hours, $($dtRuntime.Minutes) Minutes, $($dtRuntime.Seconds) Seconds  ========" >> $log
	Write-Output "======== Get-VMDiskSpace - Completed - $(TimeStamp) ========" >> $log
	
}# end END

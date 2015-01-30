<#
 .SYNOPSIS
	Function to retrieve Cisco Discovery Protocol (CDP) information from ESXi host network adapters.
 .DESCRIPTION
 	Function to retrieve Cisco Discovery Protocol (CDP) information from ESXi host network adapters.
	
 	This function accepts a single host or multiple hosts and also accepts pipeline input from current PowerCLI cmdlets, such as Get-VMHost
 .PARAMETER Name
  	The name of a host/s or a proper VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl object.
 .INPUTS
 	System.String
	VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl
 .OUTPUTS
 	System.Management.Automation.PSCustomObject
 .EXAMPLE
 	.\Get-VMHostCDPInfo -Name ESXi01,ESXi02 -Verbose | Format-Table -AutoSize
 .EXAMPLE
 	Get-VMHost ESXi01,ESXi02 | .\Get-VMHostCDPInfo.ps1 | Where-Object {$PSItem.Connected -eq 'True'}
 .EXAMPLE
	.\Get-VMHostCDPInfo.ps1 -Name (Get-VMHost ESXI01.corp.domain) -Verbose | ft -a
 .NOTES
	20150130	K. Kirkpatrick
	[+] Refactored entire script

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
Param
(
	[parameter(Mandatory = $true,
			   ValueFromPipeline = $true,
			   ValueFromPipelineByPropertyName = $true)]
	[ValidateNotNullOrEmpty()]
	$Name
)

BEGIN {
		
} # end BEGIN block

PROCESS {
	
	foreach ($vmhost in $Name) {
		$pNicCdpInfo = $null
		$physicalNic = $null
		$pNic = $null
		[bool]$Connected = $null
		$pNicCdpInfo = $null
		$objNicCDP = @()
		
		Write-Verbose -Message 'Validating VM Host input'
		if (($vmhost).GetType().Fullname -ne 'VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl') {
			try {
				Write-Verbose -Message "Converting VM Host $vmhost to proper type"
				$vmhost = Get-VMHost -Name $vmhost -ErrorAction 'Stop'
			} catch {
				Write-Warning -Message "Error converting host to a proper VI object type"
			} # end try/catch
		} else {
			Write-Verbose -Message 'VM Host Type is correct or has been converted correctly; continuing...'
		} # end if/else
		
		try {
			<# The 'QueryNetworkHint()' method is only available for use via the results of $hostNicQuery, which is why we need
			   to split the query in to two parts. Otherwise it could be combined in a single statement #>
			$hostNicQuery = Get-View $vmhost.ExtensionData.ConfigManager.NetworkSystem
			$physicalNic = $hostNicQuery.NetworkInfo.Pnic
			
			foreach ($pNic in $physicalNic) {
				
				$pNicCdpInfo = $hostNicQuery.QueryNetworkHint($pNic.Device)
				
				if ($pNicCdpInfo.ConnectedSwitchPort) {
					$Connected = $true
				} else {
					$Connected = $false
				} # end if/else
				
				$objNicCDP = [PSCustomObject] @{
					VMHost = $vmhost.Name
					HostNIC = $pNic.Device
					Connected = $Connected
					SwitchName = $pNicCdpInfo.ConnectedSwitchPort.DevId
					HardwarePlatform = $pNicCdpInfo.ConnectedSwitchPort.HardwarePlatform
					SoftwareVersion = $pNicCdpInfo.ConnectedSwitchPort.SoftwareVersion
					SwitchMangementAddress = $pNicCdpInfo.ConnectedSwitchPort.MgmtAddr
					SwitchPortId = $pNicCdpInfo.ConnectedSwitchPort.PortId
				} # end $objNicCDP
				
				$objNicCDP
			} # end foreach $pNic
			
		} catch {
			
			Write-Warning -Message "[ERROR] Could not gather information from $vmhost.name"
			
		} # end try/catch
	} # end foreach
	
} # end PROCESS block

END {
	
} # end END block


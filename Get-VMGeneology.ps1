<#
.SYNOPSIS
	Gathers current 'geneology' of a VM.
.DESCRIPTION
	Gathers current 'geneology' of a VM, which gathers and returns the current host the VM is running on, the current datastore, the current
	cluster, the number of hosts in the cluster, the current virtual port group and VLAN and the current vSwitch
.PARAMETER Name
	Display name of VM guest
.PARAMETER vCenterServer
	vCenter server name
.EXAMPLE
	.\Get-VMGeneology.ps1 -Name testvm1 -Verbose
.EXAMPLE
	.\Get-VMGeneology.ps1 -Name testvm1 -vCenterServer viserver1.company.com -Verbose
.EXAMPLE
	Get-VM testvm1 | .\Get-VMGeneology.ps1

VM                : VISERVER01
CurrentHost       : esxi01.company.com
CurrentCluster    : Prod
NumHostsInCluster : 5
CurrentDatastore  : filer1_fc_lun_1
PortGroup         : Prod_192.168.1.x_VLAN_10
PortGroupVLAN     : 10
vSwitch           : vSwitch1

.NOTES
	9/27/14		K. Kirkpatrick		Created

	TODO:	[+] Add full support for supplying multiple VMs


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

[cmdletbinding(PositionalBinding = $true)]
param (
	[parameter(Mandatory = $true,
			   HelpMessage = "Enter display name of VM ",
			   ValueFromPipeline = $true,
			   ValueFromPipelineByPropertyName = $true,
			   ParameterSetName = "Name",
			   Position = 0)]
	[alias("VM")]
	[string]$Name,
	
	[parameter(Mandatory = $false, Position = 1, ValueFromPipeline = $true)]
	[alias("VC")]
	[string]$vCenterServer
	
)

BEGIN
{
	# define variables
	$getvm = $null
	$vmconfig = $null
	$vihost = $null
	$HostDetail = $null
	$ClusterDetail = $null
	$currentvpg = $null
	$CurrentVswitch = $null
	
}# end BEGIN

PROCESS
{
	try
	{
		
		Write-Verbose -Message "Querying for guest geneology"
		
		$GetVM = Get-VM -Name $Name	# get vm and store result into variable
		$VMConfig = ($GetVM | Get-View).config	# use Get-View to call the config attribute in order to access child values
		$VIHost = $GetVM | Get-VMHost	# Get VMHost where guest is currently running
		$ClusterDetail = $VIHost | Get-Cluster | Get-View	# Use Get-ViewType to store cluster detail of current host
		$CurrentVPG = $GetVM | Get-VirtualPortGroup		# Grab current virtual port group the guest is using
		$CurrentVswitch = $GetVM | Get-VirtualSwitch	# Grab current vSwitch the VM is running on
		
		$objVMGenes = New-Object -TypeName PSObject -Property @{
			VM = $VMConfig.Name
			CurrentHost = $GetVM.VMHost
			CurrentCluster = $ClusterDetail.Name
			NumHostsInCluster = $ClusterDetail.host.count
			CurrentDatastore = $VMConfig.datastoreurl.name
			PortGroup = $CurrentVPG.Name
			PortGroupVLAN = $CurrentVPG.VLanId
			vSwitch = $CurrentVswitch.Name
		}# end objVMGenes
		
	} catch
	{
		Write-Warning -Message "$_"
	}# end try/catch
	
}# end PROCESS

END
{
	# Call final results and customize output order
	Write-Verbose -Message "Calling final results"
	
	$objVMGenes | Select-Object VM, CurrentHost, CurrentCluster, NumHostsInCluster, CurrentDatastore, PortGroup, PortGroupVLAN, vSwitch
}# end END
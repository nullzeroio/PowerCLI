<#
.SYNOPSIS
	Get VMware's installed guest toolset (VMware Tools) build-to-version mapping information from VMware's provided mapping file using Invoke-WebRequest
.DESCRIPTION
	This function will return build and version information that will help correlate the two when querying for VMware Tools versions and builds.

	For example, if you are looking at the version of VM Tools within a particular guest OS, that is going to differ from what is returned from a query from PowerCLI.

	You can use the build/version map to make that correlation, and even automate the reference to your liking.
.PARAMETER File
	Path and name of file you wish to save the information to
.PARAMETER URI
	Web URI where the VMware provided build sheet is located
.INPUTS
	System.String
.OUTPUTS
	System.Management.Automation.PSCustomObject
.EXAMPLE
	Get-VMToolsBuildToVersionMapping -Verbose | Format-Table -AutoSize

VERBOSE: Gathering source from the web via REST
VERBOSE: GET http://packages.vmware.com/tools/versions with 0-byte payload
VERBOSE: received 5460-byte response of content type text/plain
VERBOSE: Reading data from file
VERBOSE: Parsing content

VIVersion ESXiServerVersion               GuestToolsVersion ESXiBuildNumber
--------- -----------------               ----------------- ---------------
9441      ../../unsupported/tools/esx/6.0 9.7.1             1636483
9354      esx/5.5ep05                     9.4.10            2143827
9354      esx/5.5p03                      9.4.10            2143827
9354      esx/5.5u2                       9.4.10            2068190
9350      esx/5.5p02                      9.4.6             1892794
9349      esx/5.5ep04                     9.4.5             1881737
9349      esx/5.5ep03                     9.4.5             1746974
9349      esx/5.5ep02                     9.4.5             1750340
9349      esx/5.5u1                       9.4.5             1623387
9344      esx/5.5p01                      9.4.0             1474528
9344      esx/5.5                         9.4.0             1331820
9231      esx/5.1u3                       9.0.15            2323236
9229      esx/5.1p06                      9.0.13            2126665
9228      esx/5.1p05                      9.0.12            1897911
9227      esx/5.1ep05                     9.0.11            1900470
9227      esx/5.1p04                      9.0.11            1743533
9226      esx/5.1ep04                     9.0.10            1612806
9226      esx/5.1u2                       9.0.10            1483097
9221      esx/5.1p03                      9.0.5             1312873
9221      esx/5.1p02                      9.0.5             1157734
....[Truncated for example]....

.EXAMPLE
	Get-VMToolsBuildToVersionMapping -Verbose | Where-Object { $_.VIVersion -eq 9354 } | Format-Table -AutoSize
.NOTES

	20150127	K. Kirkpatrick
	[+] Created

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

#Requires -Version 3

[cmdletbinding(DefaultParameterSetName = 'Default')]
param (
	[parameter(Mandatory = $false,
			   Position = 0)]
	[validatescript({ (Invoke-WebRequest -Uri $_).StatusCode -eq 200 })]
	[System.String]$URI = 'http://packages.vmware.com/tools/versions',
	
	[parameter(Mandatory = $false,
			   Position = 1)]
	[validatescript({ Test-Path -LiteralPath (Split-Path -LiteralPath $_) -Type Container })]
	[System.String]$ExportFile = "$ENV:TEMP\vmToolsBVMap.txt"
)

BEGIN {
	
	Write-Verbose -Message 'Gathering source from the web via REST'
	try {
		Invoke-RestMethod -Method Get -Uri $URI -ErrorAction 'Stop' | Out-File $ExportFile -Encoding utf8 -ErrorAction 'Stop' -Force
	} catch {
		Write-Warning -Message 'Error gathering source information from the web'
		Write-Warning -Message 'Exiting'
		Exit
	} # end try/catch
	
	Write-Verbose -Message 'Reading data from file'
	try {
		$vmToolsBVMap = Get-Content $ExportFile -ErrorAction 'Stop' | Select-Object -Skip 15
	} catch {
		Write-Warning -Message 'Could not read data from file'
		Write-Warning -Message 'Exiting'
		Exit
	} # end try/catch
	
} # end END block

PROCESS {
	
	Write-Verbose -Message 'Parsing content'
	foreach ($line in $vmToolsBVMap) {
		$line = $line -split '\s+'
		$objVMt = @()
		$objVMt = [PSCustomObject] @{
			VIVersion = $line[0]
			ESXiServerVersion = $line[1]
			GuestToolsVersion = $line[2]
			ESXiBuildNumber = $line[3]
		} # end $objVMt
		$objVMt
	} # end foreach $line
	
} # end PROCESS block

END {
	# finish up
} # end END block
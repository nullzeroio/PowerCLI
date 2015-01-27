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

[cmdletbinding()]
param (
	[parameter(Mandatory = $false,
			   Position = 0)]
	[validatescript({ Test-Path -LiteralPath $_ -Type Leaf })]
	[System.String]$File = 'C:\vmToolsBVMap.txt',

	[parameter(Mandatory = $false,
			   Position = 1)]
	[validatescript({ (Invoke-WebRequest -Uri $_).StatusCode -eq 200 })]
	[System.String]$URI = 'http://packages.vmware.com/tools/versions'
)

BEGIN {

	Write-Verbose -Message 'Gathering source from the web'
	try {
		(Invoke-WebRequest -Uri $URI -ErrorAction 'Stop').content | Out-File $file -Encoding utf8 -ErrorAction 'Stop'
	} catch {
		Write-Warning -Message 'Error gathering source information from the web'
		Write-Warning -Message 'Exiting'
		Exit
	} # end try/catch

} # end END block

PROCESS {

	Write-Verbose -Message 'Reading content from file'
	$vmToolsBVMap = Get-Content $file | Select-Object -Skip 15

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
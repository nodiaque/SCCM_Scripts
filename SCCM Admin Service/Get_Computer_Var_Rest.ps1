<#
	.SYNOPSIS
		Get computer variable from rest API and decrypt it
	
	.DESCRIPTION
		To use this script, you need a username and password that will be used to access
		the Rest API.

		To generated the crypted password, you need a hash and the password.
		ConvertTo-SecureString -String <pass> -Key <key>

		You can generate a key with
			$Key = New-Object Byte[] 32
			[Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($Key)

		There is surely better way to do it, didn't bother. You can modify the script to obtain these value
		from different source.

		#To Do
		- Cloud connection doesn't work, call for deprecated calls.
	
	.PARAMETER
		
	
	.NOTES
		===========================================================================
		Created with: 	SAPIEN Technologies, Inc., PowerShell Studio 2023 v5.8.232
		Created on:   	2023-11-09 15:00
		Created by:   	Jean-Sébastien Frenette
		Organization: 	
		Filename:     	Get_Computer_Var_Rest.ps1
		===========================================================================
#>

# Variable that must be set
$Endpoint = "<your_site_server_rest_api_URL>" # This is only the FQDN of the server
$variable = "RDPUsers" # Variable you are looking for
$username = "<user>" # User account used to query the Rest API in user@domain format. If using cloud, be sure the account is cloud sync
$EncryptedPassword = "<cryptedpass>" # Crypted pass for the user. 

# Variables for cloud endpoint, presently doesn't work
$ExternalEndpointFQDN = "" # Can be obtain from configmgr installed on a computer
$clientid = "<clientid>" # Your Entra AD Application Client ID
$tenantid = "<tenantid>" # Your Entra AD Tenant ID
$applicationIDURI = "https://ConfigMgrService" # You Entra AD Application IDURI
$tenantname = "<tenantname>" # Your Entra AD Tenant name (FQDN) 
$ClientSecret = "<clientsecret>" # Client secret from Entra AD

# Do not touch variables from here
$ExternalEndpoint = "HTTPS://$ExternalEndpointFQDN/AdminService"
$device = $env:computername

# Determine active MP candidates and if 
$ActiveMPCandidates = Get-WmiObject -Namespace "root\ccm\LocationServices" -Class "SMS_ActiveMPCandidate"
$ActiveMPInternalCandidatesCount = ($ActiveMPCandidates | Where-Object {
		$PSItem.Type -like "Assigned"
	} | Measure-Object).Count
$ActiveMPExternalCandidatesCount = ($ActiveMPCandidates | Where-Object {
		$PSItem.Type -like "Internet"
	} | Measure-Object).Count

# Determine if ConfigMgr client has detected if the computer is currently on internet or intranet
$CMClientInfo = Get-WmiObject -Namespace "root\ccm" -Class "ClientInfo"
switch ($CMClientInfo.InInternet)
{
	$true {
		if ($ActiveMPExternalCandidatesCount -ge 1)
		{
			$Script:AdminServiceEndpointType = "External"
		}
		else
		{
			
		}
	}
	$false {
		if ($ActiveMPInternalCandidatesCount -ge 1)
		{
			$Script:AdminServiceEndpointType = "Internal"
		}
		else
		{
			
		}
	}
}

# This is for debugging purpose and to force Internal. 
$Script:AdminServiceEndpointType = "Internal"

# Set the admin service URL according to endpoint type
switch ($Script:AdminServiceEndpointType)
{
	"Internal" {
		$Script:AdminServiceURL = "https://{0}/AdminService/wmi" -f $Endpoint
	}
	"External" {
		$Script:AdminServiceURL = "{0}/wmi" -f $ExternalEndpoint
	}
}

# Generate the Credential needed for the operation
$Script:Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList @($Script:UserName, $EncryptedPassword)



if ($Script:AdminServiceEndpointType -like "External")
{
	try
	{
		# Attempt to install PSIntuneAuth module, if already installed ensure the latest version is being used
		try
		{
			$PSIntuneAuthModule = Get-InstalledModule -Name "PSIntuneAuth" -ErrorAction Stop -Verbose:$false
			if ($PSIntuneAuthModule -ne $null)
			{
				$LatestModuleVersion = (Find-Module -Name "PSIntuneAuth" -ErrorAction SilentlyContinue -Verbose:$false).Version
				if ($LatestModuleVersion -gt $PSIntuneAuthModule.Version)
				{
					$UpdateModuleInvocation = Update-Module -Name "PSIntuneAuth" -Scope CurrentUser -Force -ErrorAction Stop -Confirm:$false -Verbose:$false
				}
			}
		}
		catch [System.Exception] {
			try
			{
				# Install NuGet package provider
				$PackageProvider = Install-PackageProvider -Name "NuGet" -Force -Verbose:$false
				
				# Install PSIntuneAuth module
				Install-Module -Name "PSIntuneAuth" -Scope AllUsers -Force -ErrorAction Stop -Confirm:$false -Verbose:$false
				
			}
			catch [System.Exception] {
			}
		}
		
		# This doesn't work
		# Retrieve authentication token
		#$Script:AuthToken = Get-MSIntuneAuthToken -TenantName $TenantName -ClientID $ClientID -Credential $Credential -Resource $ApplicationIDURI -RedirectUri "https://login.microsoftonline.com/common/oauth2/nativeclient" -ErrorAction Stop
		
		#$Script:AuthToken =Get-MsalToken -ClientId $ClientID -UserCredential $Credential -RedirectUri "https://login.microsoftonline.com/common/oauth2/nativeclient" -TenantId $tenantid
		#$Script:AuthToken = Get-MsalToken -TenantId $TenantId -ClientId $ClientID -ClientSecret ($ClientSecret | ConvertTo-SecureString -AsPlainText -Force) -ErrorAction SilentlyContinue -ErrorVariable badoutput
		#$Script:AuthToken = Get-MsalToken -TenantId $TenantId -ClientId $AppId -ClientSecret ($ClientSecret | ConvertTo-SecureString -AsPlainText -Force) -ErrorAction SilentlyContinue -ErrorVariable badoutput
	}
	catch [System.Exception] {
		
	}
}

# Fetch the device in Rest
$resource = "/SMS_R_System?`$filter=startswith(Name,`'$device`')"
$AdminServiceUri = $AdminServiceURL + $Resource
switch ($Script:AdminServiceEndpointType)
{
	"External" {
		# External doesn't work
		#$deviceInfo = Invoke-RestMethod -Method Get -Uri $AdminServiceUri -Headers @{ Authorization = "Bearer $($MsalToken.AccessToken)" } -ErrorAction Stop
	}
	"Internal" {
		# Call AdminService endpoint to retrieve package data
		$deviceInfo = Invoke-RestMethod -Method Get -Uri $AdminServiceUri -Credential $Credential -ErrorAction Stop
	}
}

# If a device is found
if ($deviceInfo)
{
	# Fetch the resource ID needed to get machine settings
	$resourceID = $deviceInfo.value.ResourceID
	
	# Get hte Machine Settings so we can get the variable
	$resource = "/SMS_MachineSettings($resourceID)"
	$AdminServiceUri = $AdminServiceURL + $Resource
	switch ($Script:AdminServiceEndpointType)
	{
		"External" {
			# This doesn't work
			$devInfo = Invoke-RestMethod -Method Get -Uri $AdminServiceUri -Headers $AuthToken -ErrorAction Stop
		}
		"Internal" {
			# Call AdminService endpoint to retrieve package data
			$devInfo = Invoke-RestMethod -Method Get -Uri $AdminServiceUri -Credential $Credential -ErrorAction Stop
		}
	}
	
	# Get all variables
	$variables = $devInfo.value.MachineVariables
	
	# Search for the variables we are looking for
	$i = 0
	$notfound = $true
	While ($i -lt $variables.count -and $notFound)
	{
		if ($variables[$i].Name -eq $variable)
		{
			# Variable found at position $i
			$notfound = $false
		}
		else
		{
			$i++
		}
		
	}
	
	$varValue = $variables[$i].value
	
	Write-Host $varValue
}
else
{
	Write-Host "Device not found"
}
# SIG # Begin signature block
# MIIrcQYJKoZIhvcNAQcCoIIrYjCCK14CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAs72fFgwvlSJFi
# 7PsfTrfmHvPSqFoyZw5cJYSsNnE0R6CCJWkwggU9MIIEJaADAgECAhAG4KIaKzBS
# rETjPZq37iLfMA0GCSqGSIb3DQEBCwUAMIGLMScwJQYJKoZIhvcNAQkBFhhtaWtl
# LnN0ZWZhbmFraXNAc3RtLmluZm8xCzAJBgNVBAYTAkNBMQ8wDQYDVQQIEwZRdWVi
# ZWMxETAPBgNVBAcTCE1vbnRyZWFsMQwwCgYDVQQKEwNTVE0xDDAKBgNVBAsTA1NU
# TTETMBEGA1UEAxMKU1RNIEVudCBDQTAeFw0xMzAyMDUxODI3NThaFw0yODA5Mjgx
# ODEyMTBaMIGLMScwJQYJKoZIhvcNAQkBFhhtaWtlLnN0ZWZhbmFraXNAc3RtLmlu
# Zm8xCzAJBgNVBAYTAkNBMQ8wDQYDVQQIEwZRdWViZWMxETAPBgNVBAcTCE1vbnRy
# ZWFsMQwwCgYDVQQKEwNTVE0xDDAKBgNVBAsTA1NUTTETMBEGA1UEAxMKU1RNIEVu
# dCBDQTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAMZumlFJmtlOU0Td
# eMzI2agguFbh9jv+ubJAXWiBVkt+L5aveUl2WV4e/g75AcjTyzuae1MyGrRnl5nm
# LWgPua9ag5mgJ97jJFfHRmCMBC5b32N6rYiezl7hqUkpawgPzBZP4X0o61oBbMt0
# kwomxo3mkBoQOJ/3yWukC00J7HH4SeOio3YNFUu4mt/SsjwYEOjv1A5hx6QG8BWC
# rqaBEANJNaN4yXAMF1cWz3DhJaNIGDeA5hE+Zjv7KfumrcRRkqnQKMwcES4VQmL+
# 38S0XIKgNYqAS/3KmsLpfINCQOF1WxzP4Wtxs9YZjXzp2U7VdPsjcLDVxce+QVmq
# sATDIHsCAwEAAaOCAZkwggGVMBMGCSsGAQQBgjcUAgQGHgQAQwBBMAsGA1UdDwQE
# AwIBRjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBRAAum2WRW4EBSlzkH78rE2
# dqnISTCCAQYGA1UdHwSB/jCB+zCB+KCB9aCB8oaBtWxkYXA6Ly8vQ049U1RNJTIw
# RW50JTIwQ0EsQ049c3RtLXJvb3QwMixDTj1DRFAsQ049UHVibGljJTIwS2V5JTIw
# U2VydmljZXMsQ049U2VydmljZXMsQ049Q29uZmlndXJhdGlvbixEQz1zdG0sREM9
# aW5mbz9jZXJ0aWZpY2F0ZVJldm9jYXRpb25MaXN0P2Jhc2U/b2JqZWN0Q2xhc3M9
# Y1JMRGlzdHJpYnV0aW9uUG9pbnSGOGh0dHA6Ly9zdG0tcm9vdDAyLnN0bS5pbmZv
# L0NlcnRFbnJvbGwvU1RNJTIwRW50JTIwQ0EuY3JsMBIGCSsGAQQBgjcVAQQFAgMH
# AAgwIwYJKwYBBAGCNxUCBBYEFMpuJh2CWYtZ1JLttjCxCvTulUnRMA0GCSqGSIb3
# DQEBCwUAA4IBAQAhvwaw3UNkY+VC1V5o/r9PT02UJ2PY169n2ZbGjBWd4fWsYTgG
# 0vlNKha1wuAwQR896bwCWdL/aG9qX3GBiAdAVe1hdnNFAYeW3/WL+qACY/FT/38q
# NHie5/HJ6EcT0TM98hsrj9zNWXYDAamoc75P0/BWvwcQ1neTxAg9pvk9R0nBGjqD
# Cm/B+7hzezjN3iaxsxcrnUFYngT0NVb7nqLOz1y+uNpAgjj5B2XUbfL+P8Fm8Hys
# ycw+by72Q7zzsUM+pBzhwzkdDihtb1cu2wV5axo8+5TOj7Q0073GG0Gbf9Du2Tko
# Lohfp32h5Ru/WSP9kSwrvNJSS9dOjFOwTt4HMIIFgzCCA2ugAwIBAgIORea7A4Mz
# w4VlSOb/RVEwDQYJKoZIhvcNAQEMBQAwTDEgMB4GA1UECxMXR2xvYmFsU2lnbiBS
# b290IENBIC0gUjYxEzARBgNVBAoTCkdsb2JhbFNpZ24xEzARBgNVBAMTCkdsb2Jh
# bFNpZ24wHhcNMTQxMjEwMDAwMDAwWhcNMzQxMjEwMDAwMDAwWjBMMSAwHgYDVQQL
# ExdHbG9iYWxTaWduIFJvb3QgQ0EgLSBSNjETMBEGA1UEChMKR2xvYmFsU2lnbjET
# MBEGA1UEAxMKR2xvYmFsU2lnbjCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoC
# ggIBAJUH6HPKZvnsFMp7PPcNCPG0RQssgrRIxutbPK6DuEGSMxSkb3/pKszGsIhr
# xbaJ0cay/xTOURQh7ErdG1rG1ofuTToVBu1kZguSgMpE3nOUTvOniX9PeGMIyBJQ
# bUJmL025eShNUhqKGoC3GYEOfsSKvGRMIRxDaNc9PIrFsmbVkJq3MQbFvuJtMgam
# Hvm566qjuL++gmNQ0PAYid/kD3n16qIfKtJwLnvnvJO7bVPiSHyMEAc4/2ayd2F+
# 4OqMPKq0pPbzlUoSB239jLKJz9CgYXfIWHSw1CM69106yqLbnQneXUQtkPGBzVeS
# +n68UARjNN9rkxi+azayOeSsJDa38O+2HBNXk7besvjihbdzorg1qkXy4J02oW9U
# ivFyVm4uiMVRQkQVlO6jxTiWm05OWgtH8wY2SXcwvHE35absIQh1/OZhFj931dmR
# l4QKbNQCTXTAFO39OfuD8l4UoQSwC+n+7o/hbguyCLNhZglqsQY6ZZZZwPA1/cna
# KI0aEYdwgQqomnUdnjqGBQCe24DWJfncBZ4nWUx2OVvq+aWh2IMP0f/fMBH5hc8z
# SPXKbWQULHpYT9NLCEnFlWQaYw55PfWzjMpYrZxCRXluDocZXFSxZba/jJvcE+kN
# b7gu3GduyYsRtYQUigAZcIN5kZeR1BonvzceMgfYFGM8KEyvAgMBAAGjYzBhMA4G
# A1UdDwEB/wQEAwIBBjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBSubAWjkxPi
# oufi1xzWx/B/yGdToDAfBgNVHSMEGDAWgBSubAWjkxPioufi1xzWx/B/yGdToDAN
# BgkqhkiG9w0BAQwFAAOCAgEAgyXt6NH9lVLNnsAEoJFp5lzQhN7craJP6Ed41mWY
# qVuoPId8AorRbrcWc+ZfwFSY1XS+wc3iEZGtIxg93eFyRJa0lV7Ae46ZeBZDE1ZX
# s6KzO7V33EByrKPrmzU+sQghoefEQzd5Mr6155wsTLxDKZmOMNOsIeDjHfrYBzN2
# VAAiKrlNIC5waNrlU/yDXNOd8v9EDERm8tLjvUYAGm0CuiVdjaExUd1URhxN25mW
# 7xocBFymFe944Hn+Xds+qkxV/ZoVqW/hpvvfcDDpw+5CRu3CkwWJ+n1jez/QcYF8
# AOiYrg54NMMl+68KnyBr3TsTjxKM4kEaSHpzoHdpx7Zcf4LIHv5YGygrqGytXm3A
# BdJ7t+uA/iU3/gKbaKxCXcPu9czc8FB10jZpnOZ7BN9uBmm23goJSFmH63sUYHpk
# qmlD75HHTOwY3WzvUy2MmeFe8nI+z1TIvWfspA9MRf/TuTAjB0yPEL+GltmZWrSZ
# VxykzLsViVO6LAUP5MSeGbEYNNVMnbrt9x+vJJUEeKgDu+6B5dpffItKoZB0Jaez
# PkvILFa9x8jvOOJckvB595yEunQtYQEgfn7R8k8HWV+LLUNS60YMlOH1Zkd5d9VU
# Wx+tJDfLRVpOoERIyNiwmcUVhAn21klJwGW45hpxbqCo8YLoRT5s1gLXCmeDBVrJ
# pBAwggZZMIIEQaADAgECAg0B7BySQN79LkBdfEd0MA0GCSqGSIb3DQEBDAUAMEwx
# IDAeBgNVBAsTF0dsb2JhbFNpZ24gUm9vdCBDQSAtIFI2MRMwEQYDVQQKEwpHbG9i
# YWxTaWduMRMwEQYDVQQDEwpHbG9iYWxTaWduMB4XDTE4MDYyMDAwMDAwMFoXDTM0
# MTIxMDAwMDAwMFowWzELMAkGA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24g
# bnYtc2ExMTAvBgNVBAMTKEdsb2JhbFNpZ24gVGltZXN0YW1waW5nIENBIC0gU0hB
# Mzg0IC0gRzQwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDwAuIwI/rg
# G+GadLOvdYNfqUdSx2E6Y3w5I3ltdPwx5HQSGZb6zidiW64HiifuV6PENe2zNMes
# wwzrgGZt0ShKwSy7uXDycq6M95laXXauv0SofEEkjo+6xU//NkGrpy39eE5DiP6T
# GRfZ7jHPvIo7bmrEiPDul/bc8xigS5kcDoenJuGIyaDlmeKe9JxMP11b7Lbv0mXP
# RQtUPbFUUweLmW64VJmKqDGSO/J6ffwOWN+BauGwbB5lgirUIceU/kKWO/ELsX9/
# RpgOhz16ZevRVqkuvftYPbWF+lOZTVt07XJLog2CNxkM0KvqWsHvD9WZuT/0TzXx
# nA/TNxNS2SU07Zbv+GfqCL6PSXr/kLHU9ykV1/kNXdaHQx50xHAotIB7vSqbu4Th
# DqxvDbm19m1W/oodCT4kDmcmx/yyDaCUsLKUzHvmZ/6mWLLU2EESwVX9bpHFu7FM
# CEue1EIGbxsY1TbqZK7O/fUF5uJm0A4FIayxEQYjGeT7BTRE6giunUlnEYuC5a1a
# hqdm/TMDAd6ZJflxbumcXQJMYDzPAo8B/XLukvGnEt5CEk3sqSbldwKsDlcMCdFh
# niaI/MiyTdtk8EWfusE/VKPYdgKVbGqNyiJc9gwE4yn6S7Ac0zd0hNkdZqs0c48e
# fXxeltY9GbCX6oxQkW2vV4Z+EDcdaxoU3wIDAQABo4IBKTCCASUwDgYDVR0PAQH/
# BAQDAgGGMBIGA1UdEwEB/wQIMAYBAf8CAQAwHQYDVR0OBBYEFOoWxmnn48tXRTkz
# pPBAvtDDvWWWMB8GA1UdIwQYMBaAFK5sBaOTE+Ki5+LXHNbH8H/IZ1OgMD4GCCsG
# AQUFBwEBBDIwMDAuBggrBgEFBQcwAYYiaHR0cDovL29jc3AyLmdsb2JhbHNpZ24u
# Y29tL3Jvb3RyNjA2BgNVHR8ELzAtMCugKaAnhiVodHRwOi8vY3JsLmdsb2JhbHNp
# Z24uY29tL3Jvb3QtcjYuY3JsMEcGA1UdIARAMD4wPAYEVR0gADA0MDIGCCsGAQUF
# BwIBFiZodHRwczovL3d3dy5nbG9iYWxzaWduLmNvbS9yZXBvc2l0b3J5LzANBgkq
# hkiG9w0BAQwFAAOCAgEAf+KI2VdnK0JfgacJC7rEuygYVtZMv9sbB3DG+wsJrQA6
# YDMfOcYWaxlASSUIHuSb99akDY8elvKGohfeQb9P4byrze7AI4zGhf5LFST5GETs
# H8KkrNCyz+zCVmUdvX/23oLIt59h07VGSJiXAmd6FpVK22LG0LMCzDRIRVXd7OlK
# n14U7XIQcXZw0g+W8+o3V5SRGK/cjZk4GVjCqaF+om4VJuq0+X8q5+dIZGkv0pqh
# cvb3JEt0Wn1yhjWzAlcfi5z8u6xM3vreU0yD/RKxtklVT3WdrG9KyC5qucqIwxIw
# TrIIc59eodaZzul9S5YszBZrGM3kWTeGCSziRdayzW6CdaXajR63Wy+ILj198fKR
# MAWcznt8oMWsr1EG8BHHHTDFUVZg6HyVPSLj1QokUyeXgPpIiScseeI85Zse46qE
# gok+wEr1If5iEO0dMPz2zOpIJ3yLdUJ/a8vzpWuVHwRYNAqJ7YJQ5NF7qMnmvkiq
# K1XZjbclIA4bUaDUY6qD6mxyYUrJ+kPExlfFnbY8sIuwuRwx773vFNgUQGwgHcIt
# 6AvGjW2MtnHtUiH+PvafnzkarqzSL3ogsfSsqh3iLRSd+pZqHcY8yvPZHL9TTaRH
# WXyVxENB+SXiLBB+gfkNlKd98rUJ9dhgckBQlSDUQ0S++qCV5yBZtnjGpGqqIpsw
# ggZfMIIFR6ADAgECAhN/AAAFSXoOvFFunDlnAAgAAAVJMA0GCSqGSIb3DQEBCwUA
# MIGLMScwJQYJKoZIhvcNAQkBFhhtaWtlLnN0ZWZhbmFraXNAc3RtLmluZm8xCzAJ
# BgNVBAYTAkNBMQ8wDQYDVQQIEwZRdWViZWMxETAPBgNVBAcTCE1vbnRyZWFsMQww
# CgYDVQQKEwNTVE0xDDAKBgNVBAsTA1NUTTETMBEGA1UEAxMKU1RNIEVudCBDQTAe
# Fw0yMjA0MDUxNDQ1MTVaFw0yNzA0MDQxNDQ1MTVaMF4xFDASBgoJkiaJk/IsZAEZ
# FgRpbmZvMRMwEQYKCZImiZPyLGQBGRYDc3RtMRUwEwYKCZImiZPyLGQBGRYFY29y
# cG8xGjAYBgNVBAMTEWNvcnBvLVNVQkNBUFIxLUNBMIIBIjANBgkqhkiG9w0BAQEF
# AAOCAQ8AMIIBCgKCAQEAzHG/o7kdYYzDXOTwK2XJU8drquXSW2yqhy6zASZVOL/A
# BOhWu+J8QTZKiu4yfE8ho7BpviZCXMzYLmnBvl0w3Jh7VP/Nfl36SXSE1JPQidBL
# 33GA5dgQGAgk7iwkgp3Am8KUAXWMxOzrbUIRU6NviNvcErEEb4anO909K+uH7SGz
# 2kw4YZnkxMTqKKOUhBR1uiVJPO3ptfB9W6Z0XnlHB58FWAH39lmf6b1LXZmgiK9u
# rQNMyoaqo2X3IzwAJE8TF13pEzM1v4kFznvhGe1oCwtuS2FpOs/CwvXG67N+rL0Y
# 29jXbsZakMxBrfONdDB0wlLd40VHo3RAOJSuNZa+TQIDAQABo4IC5jCCAuIwEAYJ
# KwYBBAGCNxUBBAMCAQMwIwYJKwYBBAGCNxUCBBYEFBgVVoh5RId0oofmkyxIomOM
# XM/VMB0GA1UdDgQWBBT2CmV/ijVxa+Pvzhb6iMTQh80ZxDAZBgkrBgEEAYI3FAIE
# DB4KAFMAdQBiAEMAQTALBgNVHQ8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAfBgNV
# HSMEGDAWgBRAAum2WRW4EBSlzkH78rE2dqnISTCCAQ4GA1UdHwSCAQUwggEBMIH+
# oIH7oIH4hoG4bGRhcDovLy9DTj1TVE0lMjBFbnQlMjBDQSg3KSxDTj1zdG0tcm9v
# dDAyLENOPUNEUCxDTj1QdWJsaWMlMjBLZXklMjBTZXJ2aWNlcyxDTj1TZXJ2aWNl
# cyxDTj1Db25maWd1cmF0aW9uLERDPXN0bSxEQz1pbmZvP2NlcnRpZmljYXRlUmV2
# b2NhdGlvbkxpc3Q/YmFzZT9vYmplY3RDbGFzcz1jUkxEaXN0cmlidXRpb25Qb2lu
# dIY7aHR0cDovL3N0bS1yb290MDIuc3RtLmluZm8vQ2VydEVucm9sbC9TVE0lMjBF
# bnQlMjBDQSg3KS5jcmwwggEcBggrBgEFBQcBAQSCAQ4wggEKMIGqBggrBgEFBQcw
# AoaBnWxkYXA6Ly8vQ049U1RNJTIwRW50JTIwQ0EsQ049QUlBLENOPVB1YmxpYyUy
# MEtleSUyMFNlcnZpY2VzLENOPVNlcnZpY2VzLENOPUNvbmZpZ3VyYXRpb24sREM9
# c3RtLERDPWluZm8/Y0FDZXJ0aWZpY2F0ZT9iYXNlP29iamVjdENsYXNzPWNlcnRp
# ZmljYXRpb25BdXRob3JpdHkwWwYIKwYBBQUHMAKGT2h0dHA6Ly9zdG0tcm9vdDAy
# LnN0bS5pbmZvL0NlcnRFbnJvbGwvc3RtLXJvb3QwMi5zdG0uaW5mb19TVE0lMjBF
# bnQlMjBDQSg4KS5jcnQwDQYJKoZIhvcNAQELBQADggEBAEVxMfW8lqpIb8DOI6jk
# /xoA6dl2yUp7wq0TxbxPvzroZDIwgwEKjaBYEQ0a/rjPgR14kk1mQdLDuu6MUULJ
# fC5j0tjOPqgURdlCoL7ZRZMQVBNzAEIdgKDJbmdiw7Qa/5jYSF2Qo8LHO4/LaUVI
# K72YXV+J7SF3XJoKygR/B0crS4oclKhq1M7eTwElMefZyHiDzvuPM1/fAlO3JOgd
# A8UxPUWK0j3/65je+F/0+KY5rEK40V12Vz8t23ziZPj4VTReqYUE9Wpen7fCdjcU
# 3PPffAxNp49CTiJgPS69a34JFVxYfNC6LBGwjigLbdEOreTiJJ94aOIJdbWduWZX
# bEUwggZoMIIEUKADAgECAhABSJA9woq8p6EZTQwcV7gpMA0GCSqGSIb3DQEBCwUA
# MFsxCzAJBgNVBAYTAkJFMRkwFwYDVQQKExBHbG9iYWxTaWduIG52LXNhMTEwLwYD
# VQQDEyhHbG9iYWxTaWduIFRpbWVzdGFtcGluZyBDQSAtIFNIQTM4NCAtIEc0MB4X
# DTIyMDQwNjA3NDE1OFoXDTMzMDUwODA3NDE1OFowYzELMAkGA1UEBhMCQkUxGTAX
# BgNVBAoMEEdsb2JhbFNpZ24gbnYtc2ExOTA3BgNVBAMMMEdsb2JhbHNpZ24gVFNB
# IGZvciBNUyBBdXRoZW50aWNvZGUgQWR2YW5jZWQgLSBHNDCCAaIwDQYJKoZIhvcN
# AQEBBQADggGPADCCAYoCggGBAMLJ3AO2G1D6Kg3onKQh2yinHfWAtRJ0I/5eL8Ma
# XZayIBkZUF92IyY1xiHslO+1ojrFkIGbIe8LJ6TjF2Q72pPUVi8811j5bazAL5B4
# I0nA+MGPcBPUa98miFp2e0j34aSm7wsa8yVUD4CeIxISE9Gw9wLjKw3/QD4AQkPe
# Gu9M9Iep8p480Abn4mPS60xb3V1YlNPlpTkoqgdediMw/Px/mA3FZW0b1XRFOkaw
# ohZ13qLCKnB8tna82Ruuul2c9oeVzqqo4rWjsZNuQKWbEIh2Fk40ofye8eEaVNHI
# JFeUdq3Cx+yjo5Z14sYoawIF6Eu5teBSK3gBjCoxLEzoBeVvnw+EJi5obPrLTRl8
# GMH/ahqpy76jdfjpyBiyzN0vQUAgHM+ICxfJsIpDy+Jrk1HxEb5CvPhR8toAAr4I
# GCgFJ8TcO113KR4Z1EEqZn20UnNcQqWQ043Fo6o3znMBlCQZQkPRlI9Lft3Lbbwb
# Tnv5qgsiS0mASXAbLU/eNGA+vQIDAQABo4IBnjCCAZowDgYDVR0PAQH/BAQDAgeA
# MBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMB0GA1UdDgQWBBRba3v0cHQIwQ0qyO/x
# xLlA0krG/TBMBgNVHSAERTBDMEEGCSsGAQQBoDIBHjA0MDIGCCsGAQUFBwIBFiZo
# dHRwczovL3d3dy5nbG9iYWxzaWduLmNvbS9yZXBvc2l0b3J5LzAMBgNVHRMBAf8E
# AjAAMIGQBggrBgEFBQcBAQSBgzCBgDA5BggrBgEFBQcwAYYtaHR0cDovL29jc3Au
# Z2xvYmFsc2lnbi5jb20vY2EvZ3N0c2FjYXNoYTM4NGc0MEMGCCsGAQUFBzAChjdo
# dHRwOi8vc2VjdXJlLmdsb2JhbHNpZ24uY29tL2NhY2VydC9nc3RzYWNhc2hhMzg0
# ZzQuY3J0MB8GA1UdIwQYMBaAFOoWxmnn48tXRTkzpPBAvtDDvWWWMEEGA1UdHwQ6
# MDgwNqA0oDKGMGh0dHA6Ly9jcmwuZ2xvYmFsc2lnbi5jb20vY2EvZ3N0c2FjYXNo
# YTM4NGc0LmNybDANBgkqhkiG9w0BAQsFAAOCAgEALms+j3+wsGDZ8Z2E3JW2318N
# vyRR4xoGqlUEy2HB72Vxrgv9lCRXAMfk9gy8GJV9LxlqYDOmvtAIVVYEtuP+Hrvl
# EHZUO6tcIV4qNU1Gy6ZMugRAYGAs29P2nd7KMhAMeLC7VsUHS3C8pw+rcryNy+vu
# wUxr2fqYoXQ+6ajIeXx2d0j9z+PwDcHpw5LgBwwTLz9rfzXZ1bfub3xYwPE/DBmy
# AqNJTJwEw/C0l6fgTWolujQWYmbIeLxpc6pfcqI1WB4m678yFKoSeuv0lmt/cqzq
# pzkIMwE2PmEkfhGdER52IlTjQLsuhgx2nmnSxBw9oguMiAQDVN7pGxf+LCue2dZb
# Ijj8ZECGzRd/4amfub+SQahvJmr0DyiwQJGQL062dlC8TSPZf09rkymnbOfQMD6p
# kx/CUCs5xbL4TSck0f122L75k/SpVArVdljRPJ7qGugkxPs28S9Z05LD7MtgUh4c
# RiUI/37Zk64UlaiGigcuVItzTDcVOFBWh/FPrhyPyaFsLwv8uxxvLb2qtutoI/Dt
# lCcUY8us9GeKLIHTFBIYAT+Eeq7sR2A/aFiZyUrCoZkVBcKt3qLv16dVfLyEG02U
# u45KhUTZgT2qoyVVX6RrzTZsAPn/ct5a7P/JoEGWGkBqhZEcr3VjqMtaM7WUM36y
# jQ9zvof8rzpzH3sg23IwggdxMIIGWaADAgECAhMZAAhTYLmmLOul8QYfAAMACFNg
# MA0GCSqGSIb3DQEBCwUAMF4xFDASBgoJkiaJk/IsZAEZFgRpbmZvMRMwEQYKCZIm
# iZPyLGQBGRYDc3RtMRUwEwYKCZImiZPyLGQBGRYFY29ycG8xGjAYBgNVBAMTEWNv
# cnBvLVNVQkNBUFIxLUNBMB4XDTI0MDMwNTEzNDg0NVoXDTI3MDQwNDE0NDUxNVow
# gfExFDASBgoJkiaJk/IsZAEZFgRpbmZvMRMwEQYKCZImiZPyLGQBGRYDc3RtMRUw
# EwYKCZImiZPyLGQBGRYFY29ycG8xFTATBgNVBAsTDEdlc3Rpb24gUGFyYzEaMBgG
# A1UECxMRUG9zdGVzIGV0IHVzYWdlcnMxFDASBgNVBAsTC0J1cmVhdXRpcXVlMRAw
# DgYDVQQLEwdVc2FnZXJzMSEwHwYDVQQDExhGcmVuZXR0ZSwgSmVhbi1TZWJhc3Rp
# ZW4xLzAtBgkqhkiG9w0BCQEWIEplYW4tU2ViYXN0aWVuLkZyZW5ldHRlQHN0bS5p
# bmZvMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEApb59qZMQpIqekWj5
# DBb8VL9MkpX9f9V+iSfzZFvCeLnuDa7ArnAlcYGfO5dLIREkoCgQuvhhlduLCARk
# Ay9eOHJ59KS6fXdh5XqUYaXz6jnzTMjBK7sH4yxKPyuXd3Yg/PsoNhORLp5TbZfc
# ua38nKi4K7pGbOetAEIvRz1yp3hTXN8gfq7LjblHNToSU/An+/kW6wpVgZdPZlD9
# oe70heIyUIRtfgwJXSSVOj1zMckhD7yg3aA0C29Ild8mZ8jpWoigjWHqAZa0Fbpu
# ChLMHT4fVuvWoFtsWUCzFnFBqAZSLEiPsK2FlwedQ57BuFvzQ3v7qUS5pNc9p97n
# KqPwFQIDAQABo4IDkjCCA44wPAYJKwYBBAGCNxUHBC8wLQYlKwYBBAGCNxUIhrvV
# RYL8726EmZEKg6zabpi5ZDaB+a02gfu4OwIBZAIBAjATBgNVHSUEDDAKBggrBgEF
# BQcDAzALBgNVHQ8EBAMCB4AwGwYJKwYBBAGCNxUKBA4wDDAKBggrBgEFBQcDAzAd
# BgNVHQ4EFgQUGsajaQsj8F5bdvzgY8ubyxoorOAwHwYDVR0jBBgwFoAU9gplf4o1
# cWvj784W+ojE0IfNGcQwggERBgNVHR8EggEIMIIBBDCCAQCggf2ggfqGgbZsZGFw
# Oi8vL0NOPWNvcnBvLVNVQkNBUFIxLUNBLENOPXN1YmNhcHIxLENOPUNEUCxDTj1Q
# dWJsaWMlMjBLZXklMjBTZXJ2aWNlcyxDTj1TZXJ2aWNlcyxDTj1Db25maWd1cmF0
# aW9uLERDPXN0bSxEQz1pbmZvP2NlcnRpZmljYXRlUmV2b2NhdGlvbkxpc3Q/YmFz
# ZT9vYmplY3RDbGFzcz1jUkxEaXN0cmlidXRpb25Qb2ludIY/aHR0cDovL3N1YmNh
# cHIxLmNvcnBvLnN0bS5pbmZvL0NlcnRFbnJvbGwvY29ycG8tU1VCQ0FQUjEtQ0Eu
# Y3JsMIIBKgYIKwYBBQUHAQEEggEcMIIBGDCBrQYIKwYBBQUHMAKGgaBsZGFwOi8v
# L0NOPWNvcnBvLVNVQkNBUFIxLUNBLENOPUFJQSxDTj1QdWJsaWMlMjBLZXklMjBT
# ZXJ2aWNlcyxDTj1TZXJ2aWNlcyxDTj1Db25maWd1cmF0aW9uLERDPXN0bSxEQz1p
# bmZvP2NBQ2VydGlmaWNhdGU/YmFzZT9vYmplY3RDbGFzcz1jZXJ0aWZpY2F0aW9u
# QXV0aG9yaXR5MGYGCCsGAQUFBzAChlpodHRwOi8vc3ViY2FwcjEuY29ycG8uc3Rt
# LmluZm8vQ2VydEVucm9sbC9zdWJjYXByMS5jb3Jwby5zdG0uaW5mb19jb3Jwby1T
# VUJDQVBSMS1DQSgzKS5jcnQwOwYDVR0RBDQwMqAwBgorBgEEAYI3FAIDoCIMIEpl
# YW4tU2ViYXN0aWVuLkZyZW5ldHRlQHN0bS5pbmZvME8GCSsGAQQBgjcZAgRCMECg
# PgYKKwYBBAGCNxkCAaAwBC5TLTEtNS0yMS0xNTE2Nzg1NTgtMTI0NDg1ODk1OC0x
# MjU2NDEwMDYxLTY0NTA3MA0GCSqGSIb3DQEBCwUAA4IBAQA8u4ZN2XQDKGJ5/o55
# Q9TCMF8shlcgbiQP6uMOtsO8/JCl+GaBmP/PrK4fvvoHs0L5COpg1OgTqzcr5F12
# 8D9L+JGNHQUaoS5NgO3Eji501rWfZLoRjAip5r5McXGLAj7/PBrm+TqP5lDRoSLy
# w3q0cE2h7SVyMMsYVGDCUf3LWVYvF1TZnOTf9Hkgj2eScJSlqz2pVqt5w13zyOkq
# JbCfRz25hf+gPwscf8zuMAoJ4upjnVEF7shhjwyqEKqhO93KWbvZYbDf7lO00VeZ
# 1nuRpF4agCnDlr2DxabWQ8tsdXYejRYSxqWp8dkWsNauNgDWUZm7eEXYojQCPvyE
# Bip8MYIFXjCCBVoCAQEwdTBeMRQwEgYKCZImiZPyLGQBGRYEaW5mbzETMBEGCgmS
# JomT8ixkARkWA3N0bTEVMBMGCgmSJomT8ixkARkWBWNvcnBvMRowGAYDVQQDExFj
# b3Jwby1TVUJDQVBSMS1DQQITGQAIU2C5pizrpfEGHwADAAhTYDANBglghkgBZQME
# AgEFAKBMMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMC8GCSqGSIb3DQEJBDEi
# BCB7B6JiyLLt+NpSc3g67EucM/ykUnVrDoN5x8pVPmloEjANBgkqhkiG9w0BAQEF
# AASCAQBNAXUlUuFkdNQYKoDG2E+bP+qVUY20XnHc9jhh4keTn/ZQsuIsk3Chq3df
# PJz4FQPNPsOiafn178i/935uqIOguxqfj1ALdbsdjpDi3ZTHaMNuF1nr1uheL2Of
# kv0GHP1xSC1+fu+ijyRB/bXNhDUSseQZzDdGSat1GosgfFn3mxtrWAlcUq0f6lS8
# fSZkYLMcEIr584Ur1TBsLHk0oZtl00dMTX6VpORNmwy4JpmqtyXR1FM6BQsFbJBt
# bSQaU7ESIePw6o3kP8E62qVe+OfBdCxt11W9oOPDYs7EpZz2u10b8/j6+FOjzxB3
# 2TrGHah977T3S2UqviziItesmWhnoYIDbDCCA2gGCSqGSIb3DQEJBjGCA1kwggNV
# AgEBMG8wWzELMAkGA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYtc2Ex
# MTAvBgNVBAMTKEdsb2JhbFNpZ24gVGltZXN0YW1waW5nIENBIC0gU0hBMzg0IC0g
# RzQCEAFIkD3CirynoRlNDBxXuCkwCwYJYIZIAWUDBAIBoIIBPTAYBgkqhkiG9w0B
# CQMxCwYJKoZIhvcNAQcBMBwGCSqGSIb3DQEJBTEPFw0yNDAzMDgxNDI4NDhaMCsG
# CSqGSIb3DQEJNDEeMBwwCwYJYIZIAWUDBAIBoQ0GCSqGSIb3DQEBCwUAMC8GCSqG
# SIb3DQEJBDEiBCAxCycCZk8Km8oFkOsrR7B6KhFkBVG4YVjNuLEnB1WiJjCBpAYL
# KoZIhvcNAQkQAgwxgZQwgZEwgY4wgYsEFDEDDhdqpFkuqyyLregymfy1WF3PMHMw
# X6RdMFsxCzAJBgNVBAYTAkJFMRkwFwYDVQQKExBHbG9iYWxTaWduIG52LXNhMTEw
# LwYDVQQDEyhHbG9iYWxTaWduIFRpbWVzdGFtcGluZyBDQSAtIFNIQTM4NCAtIEc0
# AhABSJA9woq8p6EZTQwcV7gpMA0GCSqGSIb3DQEBCwUABIIBgA30oB4jXlj9ZwXy
# vtepS2GP2Oy6VO3KvgUPHWHVA5DvaJy+LrPZbCnL/VqQtaL8+xknRUVHti4H8DXk
# oVHR4G+bCWZnwhBzDckqSO36j61ooApj9RjvxGYm+PpgmK4uYjw90B7CvpQutRB0
# Xe0Jx0ittH+oLnU1YHMfhMM2FDxMb94ojb+OpbrRoU3VKP7pcqvox+2bMPQHlfAE
# mPMoR16eCnO4iAeC3y33snOdThDD6L9h2XxhHAzQjNB9qQV/e5dEgcDopqdi2FxR
# BzLJe59i7ekXbHN5ebgtlkS/mcSY/XNsHkGsdixUtUlO7Coi5vJXlR9VHKWcVxee
# Slcuz1setCfKbbF7z7ORwtLnicAQKQrFC7ecKBnLsvMPgxPb5643I/IIu+BTnoFD
# dWwESw70PuEb+AnnoU4W/v1+Qyx/L9JMirxabneSfMGbgFzPjqla78vC1Jh8W0p2
# I9OSy3EBK3bD8KN6ivb5GLDUwN7OT2WHSQ2rDXv0Q3sc207mkQ==
# SIG # End signature block

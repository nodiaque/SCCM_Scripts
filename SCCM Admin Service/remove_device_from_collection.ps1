<#	
	.NOTES
	===========================================================================
	 Created with: 	SAPIEN Technologies, Inc., PowerShell Studio 2022 v5.8.211
	 Created on:   	2023-03-22 13:22
	 Created by:   	Jean-Sébastien Frenette
	 Organization: 	
	 Filename: 		remove_device_from_collection.ps1    	
	===========================================================================
	.DESCRIPTION
		Remove the device from the collection using SCCM adminservice
#>

[cmdletbinding()]
param (
	[parameter(Mandatory = $true, HelpMessage = "The SCCM Computer Name")]
	[ValidateNotNullOrEmpty()]
	[String]$device,
	[parameter(Mandatory = $true, HelpMessage = "The SCCM collection ID")]
	[ValidateNotNullOrEmpty()]
	[String]$collectionID,
	[parameter(Mandatory = $true, HelpMessage = "The SCCM site server FAQDN")]
	[ValidateNotNullOrEmpty()]
	[String]$sccmsite
)

function Get-AuthCredential
{
	# Construct PSCredential object for authentication
	$EncryptedPassword = ConvertTo-SecureString -String $Script:Password -AsPlainText -Force
	$Script:Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList @($Script:UserName, $EncryptedPassword)
}

function New-CMDirectRule
{
	[OutputType([hashtable])]
	[cmdletbinding(DefaultParameterSetName = "Params")]
	param (
		[parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = "InputObject", Position = 0)]
		[object]$InputObject,
		[parameter(Mandatory = $True, ParameterSetName = "Params", Position = 0)]
		[int]$ResourceId,
		[parameter(Mandatory = $False, ValueFromPipelineByPropertyName = $True, ParameterSetName = "Params", Position = 1)]
		[parameter(Mandatory = $False, ValueFromPipelineByPropertyName = $True, ParameterSetName = "InputObject", Position = 1)]
		[string]$RuleName,
		[parameter(Mandatory = $False, ParameterSetName = "Params", Position = 2)]
		[validateset("Device", "User")]
		[string]$Type = "Device"
	)
	
	PROCESS
	{
		try
		{
			if ($InputObject)
			{
				$Type = if ($InputObject | Get-Member -Name "UniqueUserName")
				{
					"User"
				}
				else
				{
					"Device"
				}
				$ResourceId = if ($InputObject.MachineId) { $InputObject.MachineId }
				else { $InputObject.ResourceID }
				$RuleName = $InputObject.Name
			}
			
			$ResourceClassName = switch ($Type)
			{
				"Device" { "SMS_R_System" }
				"User" { "SMS_R_User" }
				default { "SMS_R_System" }
			}
			
			$RuleName = if (-not $RuleName) { $ResourceId }
			else { $RuleName }
			
			$RuleObject = if ($RuleName, $ResourceClassName, $ResourceID)
			{
				@{
					collectionRule = @{
						"@odata.type"	  = "#AdminService.SMS_CollectionRuleDirect"
						ResourceClassName = $ResourceClassName
						RuleName		  = $RuleName
						ResourceID	      = $ResourceID
					}
				}
			}
			else
			{
				$null
			}
			
			return $RuleObject
		}
		catch
		{
			throw $_
		}
	}
}

function Start-Logging
{
	param ($scriptname)
	$curdatetime = get-date -UFormat "%Y-%m-%d-%Hh%M_%S"
	if ($logbasefolder.Length -eq 0)
	{
		try
		{
			$Global:tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment -ErrorAction SilentlyContinue
			$LogPath = $tsenv.Value('_SMSTSLOGPATH')
			$Global:scriptLogPath = $LogPath
			$Global:LogFile = $Logpath + "\" + $scriptname + "_" + $curdatetime + ".log"
			$Global:64bit = [Environment]::Is64BitProcess
			Start-Transcript $logfile -Force
			writeLog -text "Executing in task sequence"
			writeLog -text "tsenv is $tsenv "
			writeLog -text "64-Bit process: $64bit"
		}
		catch
		{
			$Logpath = $env:TEMP
			$Global:scriptLogPath = $LogPath
			$Global:LogFile = $Logpath + "\" + $scriptname + "_" + $curdatetime + ".log"
			$Global:64bit = [Environment]::Is64BitProcess
			Start-Transcript $logfile -Force
			writeLog -text "Unable to load Microsoft.SMS.TSEnvironment"
			writeLog -text "Running in standalonemode"
			writeLog -text "64-Bit process: $64bit"
		}
	}
	else
	{
		$Logpath = $logbasefolder
		$Global:scriptLogPath = $LogPath
		$Global:LogFile = $Logpath + "\" + $scriptname + "_" + $curdatetime + ".log"
		$Global:64bit = [Environment]::Is64BitProcess
		Start-Transcript $logfile -Force
		try
		{
			$Global:tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment -ErrorAction SilentlyContinue
			
			writeLog -text "Executing in task sequence"
			writeLog -text "tsenv is $tsenv "
		}
		catch
		{
			writeLog -text "Running in standalonemode"
		}
		writeLog -text "64-Bit process: $64bit"
	}
}

function Stop-Logging
{
	Stop-Transcript
}

function writeLog
{
	param (
		[Parameter(Mandatory = $true, Position = 0)]
		[String]$text
	)
	process
	{
		[string]$user = whoami
		$DateNow = "[{0:yyyy/MM/dd} {0:HH:mm:ss}]" -f (Get-Date) + "[$user]"
		Write-Output "$($DateNow)> $text"
	}
}

$current_path = split-path (Get-Location).Path -NoQualifier
$scriptName = $MyInvocation.MyCommand.Name
$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
$scriptFullPath = $scriptPath + "\" + $scriptName

$scriptName = $scriptName + "-" + $device + "-" + $collectionID
Start-Logging -scriptname $scriptName
writeLog -text "Device: $device"
writeLog -text "SCCMSite: $sccmsite"
writeLog -text "CollectionID: $collectionID"
writeLog -text "Retrait de $device de la collection $collectionid"

$useCurrentCred = $true
if ([string]::IsNullOrEmpty($Script:UserName))
{
	if ($tsenv)
	{
		# Attempt to read TSEnvironment variable MDMUserName
		$Script:UserName = $tsenv.Value("MDMUserName")
		if (-not ([string]::IsNullOrEmpty($Script:UserName)))
		{
			writeLog -text "Using username from TSEnvironment variable"
			$useCurrentCred = $false
			# Attempt to read TSEnvironment variable MDMPassword
			$Script:Password = $tsenv.Value("MDMPassword")
			if (([string]::IsNullOrEmpty($Script:Password)))
			{
				writeLog -text "ERROR: No password found in TSEnvironment variable, exiting"
				$ERRORCODE = "-1"
				Stop-Logging
				$host.SetShouldExit($ERRORCODE)
				[System.Environment]::Exit($ERRORCODE)
			}
			else
			{
				Get-AuthCredential
			}
		}
		else
		{
			writeLog -text "Using current user as credential"
		}
	}
	else
	{
		writeLog -text "Using current user as credential"
	}
}
else
{
	writeLog -text "Using current user as credential"
}


$URIDev = "https://$sccmsite/AdminService/wmi/SMS_R_System?`$filter=startswith(Name,`'$device`')"

if ($useCurrentCred)
{
	$deviceInfo = Invoke-RestMethod -Method 'Get' -Uri $URIDev -UseDefaultCredentials
}
else
{
	$deviceInfo = Invoke-RestMethod -Method 'Get' -Uri $URIDev -credential $Credential
}

$resourceID = $deviceInfo.value.ResourceID
writeLog -text "Device Resource ID: $resourceID"

$CollectionRule = New-CMDirectRule -ResourceId $ResourceId -RuleName $device -Type "Device"

$URIDEL = "https://$sccmsite/AdminService/wmi/SMS_Collection(`'$collectionID`')/AdminService.DeleteMembershipRule"

$Result = foreach ($Rule in $CollectionRule)
{
	if ($useCurrentCred)
	{
		$Params = @{
			Method	    = "POST"
			ContentType = "application/json"
			Body	    = $Rule | ConvertTo-Json -Depth 100
			URI		    = $URIDEL
			UseDefaultCredential = $True
		}
	}	else	{
		$Params = @{
			Method	    = "POST"
			ContentType = "application/json"
			Body	    = $Rule | ConvertTo-Json -Depth 100
			URI		    = $URIDEL
			credential  = $Credential
		}
	}
	$error.clear()
	try
	{
		Invoke-RestMethod @Params -ErrorAction Stop
	}
	catch [System.Net.WebException] {
		[string]$user = whoami
		$DateNow = "[{0:yyyy/MM/dd} {0:HH:mm:ss}]" -f (Get-Date) + "[$user]"
		Write-Host "$($DateNow)> Le $device n'est pas dans le collection $collectionID"
		Write-Host "$($DateNow)> Returnvalue = 0"
		$ERRORCODE = 0
		Stop-Logging
		$host.SetShouldExit($ERRORCODE)
		[System.Environment]::Exit($ERRORCODE)
	}
	catch
	{
		[string]$user = whoami
		$DateNow = "[{0:yyyy/MM/dd} {0:HH:mm:ss}]" -f (Get-Date) + "[$user]"
		Write-Host "$($DateNow)> Erreur: $Error[0]"
		Write-Host "$($DateNow)> Type: $($Error[0].exception.gettype().fullname)"
	}
	
}

if ($Result.returnvalue -eq 0)
{
	writeLog -text "Returnvalue = $($Result.returnvalue)"
	writeLog -text "Succès"
	$ERRORCODE = $Result.returnvalue
}
else
{
	writeLog -text "Échec"
	writeLog -text "Est-ce que la collection exist?"
	$ERRORCODE = "-1"
}

Stop-Logging
$host.SetShouldExit($ERRORCODE)
[System.Environment]::Exit($ERRORCODE)


# SIG # Begin signature block
# MIIrDgYJKoZIhvcNAQcCoIIq/zCCKvsCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCjdfDoMKVDWqFz
# Q1mAe950UIt63vr/kaWWIW9yBZAzMqCCJQ8wggU9MIIEJaADAgECAhAG4KIaKzBS
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
# jQ9zvof8rzpzH3sg23IwggcXMIIF/6ADAgECAgoU2e87AAIABbnAMA0GCSqGSIb3
# DQEBCwUAMF4xFDASBgoJkiaJk/IsZAEZFgRpbmZvMRMwEQYKCZImiZPyLGQBGRYD
# c3RtMRUwEwYKCZImiZPyLGQBGRYFY29ycG8xGjAYBgNVBAMTEWNvcnBvLVNVQkNB
# UFIxLUNBMB4XDTIwMDMwMjE3MTkzMVoXDTI0MDMwMTE3MTkzMVowgfExFDASBgoJ
# kiaJk/IsZAEZFgRpbmZvMRMwEQYKCZImiZPyLGQBGRYDc3RtMRUwEwYKCZImiZPy
# LGQBGRYFY29ycG8xFTATBgNVBAsTDEdlc3Rpb24gUGFyYzEaMBgGA1UECxMRUG9z
# dGVzIGV0IHVzYWdlcnMxFDASBgNVBAsTC0J1cmVhdXRpcXVlMRAwDgYDVQQLEwdV
# c2FnZXJzMSEwHwYDVQQDExhGcmVuZXR0ZSwgSmVhbi1TZWJhc3RpZW4xLzAtBgkq
# hkiG9w0BCQEWIEplYW4tU2ViYXN0aWVuLkZyZW5ldHRlQHN0bS5pbmZvMIIBIjAN
# BgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEApb59qZMQpIqekWj5DBb8VL9MkpX9
# f9V+iSfzZFvCeLnuDa7ArnAlcYGfO5dLIREkoCgQuvhhlduLCARkAy9eOHJ59KS6
# fXdh5XqUYaXz6jnzTMjBK7sH4yxKPyuXd3Yg/PsoNhORLp5TbZfcua38nKi4K7pG
# bOetAEIvRz1yp3hTXN8gfq7LjblHNToSU/An+/kW6wpVgZdPZlD9oe70heIyUIRt
# fgwJXSSVOj1zMckhD7yg3aA0C29Ild8mZ8jpWoigjWHqAZa0FbpuChLMHT4fVuvW
# oFtsWUCzFnFBqAZSLEiPsK2FlwedQ57BuFvzQ3v7qUS5pNc9p97nKqPwFQIDAQAB
# o4IDQTCCAz0wPAYJKwYBBAGCNxUHBC8wLQYlKwYBBAGCNxUIhrvVRYL8726EmZEK
# g6zabpi5ZDaB+a02gfu4OwIBZAIBAjATBgNVHSUEDDAKBggrBgEFBQcDAzALBgNV
# HQ8EBAMCB4AwGwYJKwYBBAGCNxUKBA4wDDAKBggrBgEFBQcDAzAdBgNVHQ4EFgQU
# GsajaQsj8F5bdvzgY8ubyxoorOAwHwYDVR0jBBgwFoAU9gplf4o1cWvj784W+ojE
# 0IfNGcQwggERBgNVHR8EggEIMIIBBDCCAQCggf2ggfqGgbZsZGFwOi8vL0NOPWNv
# cnBvLVNVQkNBUFIxLUNBLENOPXN1YmNhcHIxLENOPUNEUCxDTj1QdWJsaWMlMjBL
# ZXklMjBTZXJ2aWNlcyxDTj1TZXJ2aWNlcyxDTj1Db25maWd1cmF0aW9uLERDPXN0
# bSxEQz1pbmZvP2NlcnRpZmljYXRlUmV2b2NhdGlvbkxpc3Q/YmFzZT9vYmplY3RD
# bGFzcz1jUkxEaXN0cmlidXRpb25Qb2ludIY/aHR0cDovL3N1YmNhcHIxLmNvcnBv
# LnN0bS5pbmZvL0NlcnRFbnJvbGwvY29ycG8tU1VCQ0FQUjEtQ0EuY3JsMIIBKgYI
# KwYBBQUHAQEEggEcMIIBGDCBrQYIKwYBBQUHMAKGgaBsZGFwOi8vL0NOPWNvcnBv
# LVNVQkNBUFIxLUNBLENOPUFJQSxDTj1QdWJsaWMlMjBLZXklMjBTZXJ2aWNlcyxD
# Tj1TZXJ2aWNlcyxDTj1Db25maWd1cmF0aW9uLERDPXN0bSxEQz1pbmZvP2NBQ2Vy
# dGlmaWNhdGU/YmFzZT9vYmplY3RDbGFzcz1jZXJ0aWZpY2F0aW9uQXV0aG9yaXR5
# MGYGCCsGAQUFBzAChlpodHRwOi8vc3ViY2FwcjEuY29ycG8uc3RtLmluZm8vQ2Vy
# dEVucm9sbC9zdWJjYXByMS5jb3Jwby5zdG0uaW5mb19jb3Jwby1TVUJDQVBSMS1D
# QSgyKS5jcnQwOwYDVR0RBDQwMqAwBgorBgEEAYI3FAIDoCIMIEplYW4tU2ViYXN0
# aWVuLkZyZW5ldHRlQHN0bS5pbmZvMA0GCSqGSIb3DQEBCwUAA4IBAQClPBM8FhVv
# cux9BSd4XIh7WC1gC+Fj0JGl4DhBJn6Ba7oSfMD22rIv/uj9LPtyxoZD5lyKQKAr
# mHLi+htvWnUrCrHEqdKOHE8f5EqmBWdDZChZ6NQc/jhYoFIyGe3JSUyjM4Yz4B7X
# eN/UqSyMwHpFF55D6YT9L0FcfMjCjZrLDIZlCgqfgAolEEqNeuBlB9rS2C1wttrK
# Wfu0r3R4Oj7VMamKNTuGFeM71fZwd4lEYyIdz744MnNcBJC24Z+GNRja/9KUeG4s
# KvlPMElTNTyDFasFwbzoXLEIE52xdVBUCWY43eFZGE7cnmi7Md/4i5U1E+RfqM9h
# sEzXGF0MsaJiMYIFVTCCBVECAQEwbDBeMRQwEgYKCZImiZPyLGQBGRYEaW5mbzET
# MBEGCgmSJomT8ixkARkWA3N0bTEVMBMGCgmSJomT8ixkARkWBWNvcnBvMRowGAYD
# VQQDExFjb3Jwby1TVUJDQVBSMS1DQQIKFNnvOwACAAW5wDANBglghkgBZQMEAgEF
# AKBMMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMC8GCSqGSIb3DQEJBDEiBCBQ
# iOFhW6mRTFA+tzatM9WpLVcFC08UVIJiwk2/1xk3cjANBgkqhkiG9w0BAQEFAASC
# AQAQ45sd9GdUVVwz6Eb3rFqrNgM86z7m66k7ZmmQx2FZlZIREvwPZNL+w5auu2oR
# 7XiU4V1NfgizZHGJEkZW3Me3MyF3co5o3dvoBh84zxiqUwAhpLyhZFPvaJcTpsVa
# 20Qe3ChpAv7WKvTSmKafZn0Rvfj+yB4tu5jvPoA/B/zOLx29Vm/hAw4KLa/8F0V0
# hozgErKu+d5IVwtUJnKaNFL8WIxRU4W2TT2GUt4X4Km1UXw8/4MnvtNuBMmZkmU4
# w8dXA9j/uB3pGOr14fg6OhgbhVyYgYtZISYlpWcGcmbGFKKxzJhv/c7tTmaAPVE9
# QUiZHkba/W7pJf6OhtLmFplIoYIDbDCCA2gGCSqGSIb3DQEJBjGCA1kwggNVAgEB
# MG8wWzELMAkGA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYtc2ExMTAv
# BgNVBAMTKEdsb2JhbFNpZ24gVGltZXN0YW1waW5nIENBIC0gU0hBMzg0IC0gRzQC
# EAFIkD3CirynoRlNDBxXuCkwCwYJYIZIAWUDBAIBoIIBPTAYBgkqhkiG9w0BCQMx
# CwYJKoZIhvcNAQcBMBwGCSqGSIb3DQEJBTEPFw0yNDAyMDIxMzI5MzdaMCsGCSqG
# SIb3DQEJNDEeMBwwCwYJYIZIAWUDBAIBoQ0GCSqGSIb3DQEBCwUAMC8GCSqGSIb3
# DQEJBDEiBCA44cKZxnjYPejXXXNajXC3rp7+uRZzpdyDib7NQkOr1jCBpAYLKoZI
# hvcNAQkQAgwxgZQwgZEwgY4wgYsEFDEDDhdqpFkuqyyLregymfy1WF3PMHMwX6Rd
# MFsxCzAJBgNVBAYTAkJFMRkwFwYDVQQKExBHbG9iYWxTaWduIG52LXNhMTEwLwYD
# VQQDEyhHbG9iYWxTaWduIFRpbWVzdGFtcGluZyBDQSAtIFNIQTM4NCAtIEc0AhAB
# SJA9woq8p6EZTQwcV7gpMA0GCSqGSIb3DQEBCwUABIIBgLYA3Rlso/kUWkDM4Hva
# cZEwZruRNoTdkUwK+9IM9HZ4ryfW5JC1iJkKad5fltIFv4JYd9ffJMi5mjs2vjd1
# 6WpYl6C/56/6DKt5J8sR58R2vOoUUGazwHCcbi6ygNmR1BQ287VcfPu8vK3bJhdv
# gafOKNVB68NiozKmqXl00JdPY3yDO2mr5mp1zv26oZxxesyIAR6T5q4DzDhOc19U
# 9khH27D9eEaGCrp1P3j9Qca2Kzau254jbajhJ+38X6vrdsERF1cBUePXbXdGoMs3
# jJjbxlrUv3rdhQd+2OrtX/9toBKwUbh+n/GrxAJ+VqBrLjEHnHMoKJuzRzli+r7I
# X4U98FAKkmvKMlhFCzLp5CC9CpmlMNfDfIqfvSWitmU5uH4WpWwqMkjOzge2k4bt
# SVP4C7zT7t2rLSDeNJRLC3ovL1iIDHztGh14LWAq8Av7RBSymm8chBNGnyWuOl2u
# 6mJxf/MJDFGn23crzUE5fEB+2RlmN9SdTMy6kwfUAlHJiQ==
# SIG # End signature block

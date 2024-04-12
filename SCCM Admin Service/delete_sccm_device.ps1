<#
	.SYNOPSIS
		Delete device from SCCM
	
	.DESCRIPTION
		Delete device from SCCM using the rest api
		Todo
		- Add a way to do it from CMG
	
	.PARAMETER device
		The device to delete
	
	.PARAMETER sccmsite
		The FQDN to the site server to contact through rest api
	
	.PARAMETER username
		User account used to query the Rest API.
		If null, will get it from Task Sequence variable. If not in TS or variable not set, will use current user
			

	.PARAMETER password
		Password to connect to the rest api. Used only if username is set and not using current user

	.NOTES
		===========================================================================
		Created with: 	SAPIEN Technologies, Inc., PowerShell Studio 2024 v5.8.239
		Created on:   	2024-04-12 08:01
		Created by:   	Jean-Sébastien Frenette
		Organization:
		Filename:     	delete_sccm_device.ps1
		===========================================================================
#>
param
(
	[Parameter(Mandatory = $true)]
	[string]$device,
	[Parameter(Mandatory = $true)]
	[string]$endpoint,
	[string]$username,
	[string]$password
)


$current_path = split-path (Get-Location).Path -NoQualifier
$scriptName = $MyInvocation.MyCommand.Name
$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
$scriptFullPath = $scriptPath + "\" + $scriptName
$useCurrentCred = $true # Per default, we use current user unless we find something defined
$scriptName = $scriptName + "-" + $device
$credential = ""


<#
	.SYNOPSIS
		Start logging using transcript
	
	.DESCRIPTION
		Detect if running in task sequence or not. If task sequence, will create logfile in smstslogpath. If not running in task sequence, will revert to windows\temp unless customlogpath is specified.
		
		SCCM SMSTSLOGPATH is always prefered even if customlogpath is specified
	
	.PARAMETER scriptname
		Name of the script, will be used in the filename of the logging file
	
	.PARAMETER customlogpath
		Custom log path destination without filename
	
	.EXAMPLE
		PS C:\> Start-Logging
	
	.NOTES
		Additional information about the function.
#>
function Start-Logging
 {
	param
	(
		[Parameter(Mandatory = $true)]
		[string]$scriptname,
		[string]$customlogpath
	)
	
	$curdatetime = get-date -UFormat "%Y-%m-%d-%Hh%M_%S"
	try
	{
		$Global:tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment -ErrorAction SilentlyContinue
		$LogPath = $tsenv.Value('_SMSTSLOGPATH')
		$Global:scriptLogPath = $LogPath
		$Global:LogFile = $Logpath + "\" + $scriptname + "_" + $curdatetime + ".log"
		Write-CMLogEntry -Value 'Logging init' -Severity "1" -init $true -logfilepath $logfile
		Start-Transcript $logfile -Force -NoClobber -Append
		
		Write-CMLogEntry -Value "Executing in task sequence" -Severity 1
		Write-CMLogEntry -Value "tsenv is $tsenv "
	}
	catch
	{
		if ($customlogpath)
		{
			if (Test-Path -Path $customlogpath)
			{
				$LogPath = $customlogpath
			}
			else
			{
				$Logpath = $env:TEMP
			}
			
		}
		else
		{
			$Logpath = $env:TEMP
		}
		
		$Global:scriptLogPath = $LogPath
		$Global:LogFile = $Logpath + "\" + $scriptname + "_" + $curdatetime + ".log"
		Write-CMLogEntry -Value 'Logging init' -Severity "1" -init $true -logfilepath $logfile
		Start-Transcript $logfile -Force -NoClobber -Append
		Write-CMLogEntry -Value "Unable to load Microsoft.SMS.TSEnvironment" -Severity 1
		Write-CMLogEntry -Value "Running in standalonemode" -Severity 1
	}
	$Global:64bit = [Environment]::Is64BitProcess
	Write-CMLogEntry -Value "64-Bit process: $64bit" -Severity 1
	if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
	{
		$Global:RunAsAdmin = $false
		Write-CMLogEntry -Value "Not running as admin" -Severity 1
	}
	else
	{
		$Global:RunAsAdmin = $true
		Write-CMLogEntry -Value "Running as admin" -Severity 1
	}
}

<#
	.SYNOPSIS
		Stop logging
	
	.DESCRIPTION
		Run the stop-transcript command
	
	.EXAMPLE
				PS C:\> Stop-Logging
	
	.NOTES
		Additional information about the function.
#>
function Stop-Logging
{
	Stop-Transcript
}

<#
	.SYNOPSIS
		Write into log file using CM Format
	
	.DESCRIPTION
		Write into a log file following the formating of cmtrace. Need to init the file first with the parameter init and logfilepath to create the first line in the right format.
	
	.PARAMETER Value
		Content to be written into log file
	
	.PARAMETER Severity
		Severity of the message
	
	.PARAMETER init
		Indique qu'on veut créé le fichier de log
	
	.PARAMETER logfilepath
		Path to logfile
	
	.EXAMPLE
		PS C:\> Write-CMLogEntry
	
	.NOTES
		Additional information about the function.
#>
function Write-CMLogEntry
{
	param
	(
		[Parameter(Mandatory = $true,
				   HelpMessage = 'Value added to the log file.')]
		[ValidateNotNullOrEmpty()]
		[string]$Value,
		[Parameter(Mandatory = $false,
				   HelpMessage = 'Severity for the log entry. 1 for Informational, 2 for Warning and 3 for Error.')]
		[ValidateNotNullOrEmpty()]
		[ValidateSet('1', '2', '3')]
		[string]$Severity = "1",
		[boolean]$init = $false,
		[string]$logfilepath
	)
	
	# Construct time stamp for log entry
	if (-not (Test-Path -Path 'variable:global:TimezoneBias'))
	{
		[string]$global:TimezoneBias = [System.TimeZoneInfo]::Local.GetUtcOffset((Get-Date)).TotalMinutes
		if ($TimezoneBias -match "^-")
		{
			$TimezoneBias = $TimezoneBias.Replace('-', '+')
		}
		else
		{
			$TimezoneBias = '-' + $TimezoneBias
		}
	}
	$Time = -join @((Get-Date -Format "HH:mm:ss.fff"), $TimezoneBias)
	# Construct date for log entry
	$Date = (Get-Date -Format "MM-dd-yyyy")
	# Construct context for log entry
	$Context = $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)
	# Construct final log entry
	$LogText = "<![LOG[$($Value)]LOG]!><time=""$($Time)"" date=""$($Date)"" component=""$($scriptname)"" context=""$($Context)"" type=""$($Severity)"" thread=""$($PID)"" file="""">"
	# Add value to log file
	if ($init)
	{
		Out-File -InputObject $LogText -Encoding 'UTF8' -FilePath $LogFilePath -ErrorAction Stop
	}
	else
	{
		Write-Host -Object $LogText
	}
}

<#
	.SYNOPSIS
		Get a PSCredential
	
	.DESCRIPTION
		Return a PSCredential object built with the information in parameters.
		Can use either securePass or pass. If both are set, only securePass will be used.
	
	.PARAMETER user
		Username of the credential
	
	.PARAMETER securePass
		Password of the user as a SecureString object
	
	.PARAMETER pass
		Plain text password. Use either this or securePass
	
	.EXAMPLE
		PS C:\> Get-Credential -user 'Value1' -securePass $value2
	
	.NOTES
		Additional information about the function.
#>
function Get-Credential
{
	[OutputType([System.Management.Automation.PSCredential])]
	param
	(
		[Parameter(Mandatory = $true)]
		[string]$user,
		[Parameter(Mandatory = $false)]
		[System.Security.SecureString]$securePass,
		[Parameter(Mandatory = $false)]
		[string]$pass
	)
	if ([string]::IsNullOrEmpty($securePass))
	{
		$securePass = ConvertTo-SecureString -String $Script:Password -AsPlainText -Force
	}
	$credential = New-Object -TypeName System.Management.Automation.PSCredential -argumentlist $user, $securePass
	return $credential
}

try
{
	
	Start-Logging -scriptname $scriptName
	
	Write-CMLogEntry -Value "Verifying parameters"
	if (-not [string]::IsNullOrEmpty($username) -and -not [string]::IsNullOrEmpty($password))
	{
		Write-CMLogEntry -Value "Username and password parameters used"
		Write-CMLogEntry -Value "Username: $username"
		#Write-CMLogEntry -Value "Password: $password"  # Uncomment for debuging or delete
		$credential = Get-Credential -user $username -pass $password
		$useCurrentCred = $false
	}
	else
	{
		if ($tsenv)
		{
			# Attempt to read TSEnvironment variable MDMUserName
			$userName = $tsenv.Value("MDMUserName")
			if (-not ([string]::IsNullOrEmpty($Script:UserName)))
			{
				Write-CMLogEntry -Value "Using username from TSEnvironment variable"
				Write-CMLogEntry -Value "Username: $username"
				
				# Attempt to read TSEnvironment variable MDMPassword
				$password = $tsenv.Value("MDMPassword")
				if (([string]::IsNullOrEmpty($Script:Password)))
				{
					Write-CMLogEntry -Value "No password set in TSEnvironment" -Severity 2
				}
				else
				{
					Write-CMLogEntry -Value "Using password from TSEnvironement variable"
					#Write-CMLogEntry -Value "Password: $password"
					$credential = Get-Credential -user $username -pass $password
					$useCurrentCred = $false
				}
			}
			else
			{
				Write-CMLogEntry -Value "Using current user as credential"
			}
		}
		else
		{
			Write-CMLogEntry -Value "Using current user as credential"
		}
	}
	
	# Rest query to find device in SCCM
	$URIDev = "https://$endpoint/AdminService/wmi/SMS_R_System?`$filter=startswith(Name,`'$device`')"
	
	# Find device in SCCM
	if ($useCurrentCred)
	{
		$deviceInfo = Invoke-RestMethod -Method 'Get' -Uri $URIDev -UseDefaultCredentials -ErrorAction STOP
	}
	else
	{
		$deviceInfo = Invoke-RestMethod -Method 'Get' -Uri $URIDev -Credential $Credential -ErrorAction STOP
	}
	
	# Get resourceID from result
	$resourceID = $deviceInfo.value.ResourceID
	$result = ""
	
	if (-not [string]::IsNullOrEmpty($resourceID))
	{
		# Rest query to delete device
		$URI = "https://$endpoint/AdminService/wmi/SMS_R_System($resourceID)"
		
		# Parameter needed in the query to actually delete the device
		if ($useCurrentCred)
		{
			$Params = @{
				Method			     = "DELETE"
				ContentType		     = "application/json"
				URI				     = $URI
				UseDefaultCredential = $True
			}
		}
		else
		{
			$Params = @{
				Method	    = "DELETE"
				ContentType = "application/json"
				URI		    = $URI
				credential  = $Credential
			}
		}
		$error.clear()
		try
		{
			$result = Invoke-RestMethod @Params -ErrorAction Stop
			Write-CMLogEntry -Value "Success"
		}
		catch [System.Net.WebException] {
			
			Write-CMLogEntry -Value "Unable to delete device $device, insuffisant permission" -Severity 3
			Write-CMLogEntry -Value "Exit code: 1" -Severity 3
			Stop-Logging
			[System.Environment]::Exit(1)
		}
		catch
		{
			Write-CMLogEntry -Value "Error during device removal!" -Severity "3"
			if (-not [string]::IsNullOrEmpty($_.Exception))
			{
				Write-CMLogEntry -Value $_.Exception -Severity "3"
			}
			
			if (-not [string]::IsNullOrEmpty($_.ErrorDetails))
			{
				Write-CMLogEntry -Value $_.ErrorDetails -Severity "3"
			}
			Write-CMLogEntry -Value "Exit code: 1" -Severity 3
			Stop-Logging
			[System.Environment]::Exit(1)
		}
	}
	
}
catch
{
	Write-CMLogEntry -Value "Error!" -Severity "3"
	if (-not [string]::IsNullOrEmpty($_.Exception))
	{
		Write-CMLogEntry -Value $_.Exception -Severity "3"
	}
	
	if (-not [string]::IsNullOrEmpty($_.ErrorDetails))
	{
		Write-CMLogEntry -Value $_.ErrorDetails -Severity "3"
	}
	
	Write-CMLogEntry -Value "Exit code: 1" -Severity 3
	Stop-Logging
	[System.Environment]::Exit(1)
}

Write-CMLogEntry -Value "Operation completed" -Severity "1"
Stop-Logging
[System.Environment]::Exit(0)
# SIG # Begin signature block
# MIIrhAYJKoZIhvcNAQcCoIIrdTCCK3ECAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBHxtBjfZ7ZjrFn
# dIqQAswyAXd+Vk6aCc0StXX9LQzfp6CCJXwwggU9MIIEJaADAgECAhAG4KIaKzBS
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
# bEUwggZ7MIIEY6ADAgECAhABB2SbCLCn/n3WVKjy9Cn2MA0GCSqGSIb3DQEBCwUA
# MFsxCzAJBgNVBAYTAkJFMRkwFwYDVQQKExBHbG9iYWxTaWduIG52LXNhMTEwLwYD
# VQQDEyhHbG9iYWxTaWduIFRpbWVzdGFtcGluZyBDQSAtIFNIQTM4NCAtIEc0MB4X
# DTIzMTEwNzE3MTM0MFoXDTM0MTIwOTE3MTM0MFowbDELMAkGA1UEBhMCQkUxGTAX
# BgNVBAoMEEdsb2JhbFNpZ24gbnYtc2ExQjBABgNVBAMMOUdsb2JhbHNpZ24gVFNB
# IGZvciBNUyBBdXRoZW50aWNvZGUgQWR2YW5jZWQgLSBHNCAtIDIwMjMxMTCCAaIw
# DQYJKoZIhvcNAQEBBQADggGPADCCAYoCggGBALmomz6pptxC00Gfik1DRwn5aIsT
# +3WPmVzKgEJh74664XHWR5CtmU1jA7bvqSaj+zbqbhRH99dNRHSyKl6dMl8EaK+3
# yc9bCycvKE6C3o61s4n65xFJyCdAXpNvCSHG1l+Y87e6oUByrt0P384hQgRUOOrK
# It0DuRqh4LcclyhzLCCNP2aydpnaOsn2cpZSdNh9ZW7gIm/+r0b9fq9OyImBMqGY
# K49357Kj1ZqfH9GDIE5N70w7UXuRI+GDSqJvuATmZBRLLjt86bX9s242REA29b4h
# 5ujQ+n73qE5GrJSw0Cl04rGXqn848YnierfKbAUwGFhvfVt+OpHUfG9O/+kxfqWC
# NeEu/wpg6lKFV4d65CqvPKLfedvgeY/fke3/Jj12QEvfG0v2gqjqgyitU7a3ltcd
# LYzvv32KnpR8U6lkBGt8zBZnGTGCkun0OrzUiKi9ju5PEnnY/+CWkFB+ARX/8ONs
# Xhr0r0DF5Sc9Rvg6QTj/OUi03AYB+zsIKGhpqQIDAQABo4IBqDCCAaQwDgYDVR0P
# AQH/BAQDAgeAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMB0GA1UdDgQWBBT4o6fl
# I3VW0aWlO4luFnHLVdaICTBWBgNVHSAETzBNMAgGBmeBDAEEAjBBBgkrBgEEAaAy
# AR4wNDAyBggrBgEFBQcCARYmaHR0cHM6Ly93d3cuZ2xvYmFsc2lnbi5jb20vcmVw
# b3NpdG9yeS8wDAYDVR0TAQH/BAIwADCBkAYIKwYBBQUHAQEEgYMwgYAwOQYIKwYB
# BQUHMAGGLWh0dHA6Ly9vY3NwLmdsb2JhbHNpZ24uY29tL2NhL2dzdHNhY2FzaGEz
# ODRnNDBDBggrBgEFBQcwAoY3aHR0cDovL3NlY3VyZS5nbG9iYWxzaWduLmNvbS9j
# YWNlcnQvZ3N0c2FjYXNoYTM4NGc0LmNydDAfBgNVHSMEGDAWgBTqFsZp5+PLV0U5
# M6TwQL7Qw71lljBBBgNVHR8EOjA4MDagNKAyhjBodHRwOi8vY3JsLmdsb2JhbHNp
# Z24uY29tL2NhL2dzdHNhY2FzaGEzODRnNC5jcmwwDQYJKoZIhvcNAQELBQADggIB
# AHArWS5rBVK1Jlchtc8Q6JrwrMtyVGhtVUWZljlYRxvQaWsobPCTi6ZEy3jJq05i
# xIIfBZDerAaWO66gRg2BhuyQcNyyNS7LVS1DR2+Lek5BP/6yIZxAMditj5U3GoLr
# yLcOp6FcGqrAakn9D4oEBybC2Q7PJgN9MEW/bFB6D+kkNkyApOgiQStgZrysC88y
# yIB/KkbHnMLlHw/WVfkCDGHFvGKPXaMiYetqmHiwZC8JsA3JuAgcWl4GMCRdcYN2
# OP1IaphdP0JIbyyENvzm/pLC0nBjQYO19KAKZVrVQfSDqDAbyNZbbkDow83mN+LJ
# 6VVci1PE7uHfu9O1kYq7Z3O1CPCoSKsOG+BEcL7iBOcRqeE/UEGaDGYKVkXBBUH5
# QhX9BKaRtfpMFop+fgWaoYd0VP3Hp8Dmk2edpB0qXDoEtU7VFx6j4o3uPjwKgU9Z
# MfsF/5gZ05i4BthIm0mT4QLHbbIsitzqXtvUb/0HrB48NlF38T4skmT1mPBPK5oQ
# 89pfOPpKQsl/YKObSaEzCxDOwk+l07KAWBkm+kMJSrV11Z7Yrw2vHrb7S0l4/V+x
# 6obteup3utHs54Y1Cflau5bh9gpX+f3W/iQaAFC9nk3IkRg37NIozg+ul0Ydwnxg
# y7uaZK6WtbnlynrletZ4QSTeZsn2UBdFpX/TH+oe2u/oMIIHcTCCBlmgAwIBAgIT
# GQAIU2C5pizrpfEGHwADAAhTYDANBgkqhkiG9w0BAQsFADBeMRQwEgYKCZImiZPy
# LGQBGRYEaW5mbzETMBEGCgmSJomT8ixkARkWA3N0bTEVMBMGCgmSJomT8ixkARkW
# BWNvcnBvMRowGAYDVQQDExFjb3Jwby1TVUJDQVBSMS1DQTAeFw0yNDAzMDUxMzQ4
# NDVaFw0yNzA0MDQxNDQ1MTVaMIHxMRQwEgYKCZImiZPyLGQBGRYEaW5mbzETMBEG
# CgmSJomT8ixkARkWA3N0bTEVMBMGCgmSJomT8ixkARkWBWNvcnBvMRUwEwYDVQQL
# EwxHZXN0aW9uIFBhcmMxGjAYBgNVBAsTEVBvc3RlcyBldCB1c2FnZXJzMRQwEgYD
# VQQLEwtCdXJlYXV0aXF1ZTEQMA4GA1UECxMHVXNhZ2VyczEhMB8GA1UEAxMYRnJl
# bmV0dGUsIEplYW4tU2ViYXN0aWVuMS8wLQYJKoZIhvcNAQkBFiBKZWFuLVNlYmFz
# dGllbi5GcmVuZXR0ZUBzdG0uaW5mbzCCASIwDQYJKoZIhvcNAQEBBQADggEPADCC
# AQoCggEBAKW+famTEKSKnpFo+QwW/FS/TJKV/X/Vfokn82Rbwni57g2uwK5wJXGB
# nzuXSyERJKAoELr4YZXbiwgEZAMvXjhyefSkun13YeV6lGGl8+o580zIwSu7B+Ms
# Sj8rl3d2IPz7KDYTkS6eU22X3Lmt/JyouCu6RmznrQBCL0c9cqd4U1zfIH6uy425
# RzU6ElPwJ/v5FusKVYGXT2ZQ/aHu9IXiMlCEbX4MCV0klTo9czHJIQ+8oN2gNAtv
# SJXfJmfI6VqIoI1h6gGWtBW6bgoSzB0+H1br1qBbbFlAsxZxQagGUixIj7CthZcH
# nUOewbhb80N7+6lEuaTXPafe5yqj8BUCAwEAAaOCA5IwggOOMDwGCSsGAQQBgjcV
# BwQvMC0GJSsGAQQBgjcVCIa71UWC/O9uhJmRCoOs2m6YuWQ2gfmtNoH7uDsCAWQC
# AQIwEwYDVR0lBAwwCgYIKwYBBQUHAwMwCwYDVR0PBAQDAgeAMBsGCSsGAQQBgjcV
# CgQOMAwwCgYIKwYBBQUHAwMwHQYDVR0OBBYEFBrGo2kLI/BeW3b84GPLm8saKKzg
# MB8GA1UdIwQYMBaAFPYKZX+KNXFr4+/OFvqIxNCHzRnEMIIBEQYDVR0fBIIBCDCC
# AQQwggEAoIH9oIH6hoG2bGRhcDovLy9DTj1jb3Jwby1TVUJDQVBSMS1DQSxDTj1z
# dWJjYXByMSxDTj1DRFAsQ049UHVibGljJTIwS2V5JTIwU2VydmljZXMsQ049U2Vy
# dmljZXMsQ049Q29uZmlndXJhdGlvbixEQz1zdG0sREM9aW5mbz9jZXJ0aWZpY2F0
# ZVJldm9jYXRpb25MaXN0P2Jhc2U/b2JqZWN0Q2xhc3M9Y1JMRGlzdHJpYnV0aW9u
# UG9pbnSGP2h0dHA6Ly9zdWJjYXByMS5jb3Jwby5zdG0uaW5mby9DZXJ0RW5yb2xs
# L2NvcnBvLVNVQkNBUFIxLUNBLmNybDCCASoGCCsGAQUFBwEBBIIBHDCCARgwga0G
# CCsGAQUFBzAChoGgbGRhcDovLy9DTj1jb3Jwby1TVUJDQVBSMS1DQSxDTj1BSUEs
# Q049UHVibGljJTIwS2V5JTIwU2VydmljZXMsQ049U2VydmljZXMsQ049Q29uZmln
# dXJhdGlvbixEQz1zdG0sREM9aW5mbz9jQUNlcnRpZmljYXRlP2Jhc2U/b2JqZWN0
# Q2xhc3M9Y2VydGlmaWNhdGlvbkF1dGhvcml0eTBmBggrBgEFBQcwAoZaaHR0cDov
# L3N1YmNhcHIxLmNvcnBvLnN0bS5pbmZvL0NlcnRFbnJvbGwvc3ViY2FwcjEuY29y
# cG8uc3RtLmluZm9fY29ycG8tU1VCQ0FQUjEtQ0EoMykuY3J0MDsGA1UdEQQ0MDKg
# MAYKKwYBBAGCNxQCA6AiDCBKZWFuLVNlYmFzdGllbi5GcmVuZXR0ZUBzdG0uaW5m
# bzBPBgkrBgEEAYI3GQIEQjBAoD4GCisGAQQBgjcZAgGgMAQuUy0xLTUtMjEtMTUx
# Njc4NTU4LTEyNDQ4NTg5NTgtMTI1NjQxMDA2MS02NDUwNzANBgkqhkiG9w0BAQsF
# AAOCAQEAPLuGTdl0Ayhief6OeUPUwjBfLIZXIG4kD+rjDrbDvPyQpfhmgZj/z6yu
# H776B7NC+QjqYNToE6s3K+RddvA/S/iRjR0FGqEuTYDtxI4udNa1n2S6EYwIqea+
# THFxiwI+/zwa5vk6j+ZQ0aEi8sN6tHBNoe0lcjDLGFRgwlH9y1lWLxdU2Zzk3/R5
# II9nknCUpas9qVarecNd88jpKiWwn0c9uYX/oD8LHH/M7jAKCeLqY51RBe7IYY8M
# qhCqoTvdylm72WGw3+5TtNFXmdZ7kaReGoApw5a9g8Wm1kPLbHV2Ho0WEsalqfHZ
# FrDWrjYA1lGZu3hF2KI0Aj78hAYqfDGCBV4wggVaAgEBMHUwXjEUMBIGCgmSJomT
# 8ixkARkWBGluZm8xEzARBgoJkiaJk/IsZAEZFgNzdG0xFTATBgoJkiaJk/IsZAEZ
# FgVjb3JwbzEaMBgGA1UEAxMRY29ycG8tU1VCQ0FQUjEtQ0ECExkACFNguaYs66Xx
# Bh8AAwAIU2AwDQYJYIZIAWUDBAIBBQCgTDAZBgkqhkiG9w0BCQMxDAYKKwYBBAGC
# NwIBBDAvBgkqhkiG9w0BCQQxIgQgjBMBID7ItHA5YAUit7EKr3/JjzyUiyWv7wlU
# Dlchyl4wDQYJKoZIhvcNAQEBBQAEggEAl85EENwOEDsbMl34KkeLYxWR8PHcZCTl
# IZjHszWQ9lZuK8X7Nj8YbAiUXf+JFtlTU6HoJdzTllgN9BhhISRhhuBQnWLwQfrY
# uFzheT9X2Q85Mlo6KoQzr3O5mnZR7RrYqa9OiAksTMvMp/rjkwUC5A7Crfu+f6Hj
# +tsRHKTH4wq9JmANDlFTSKGBWc4kun12/Kg3Gq1eHYVFSYiAKE/c/PH99OwLhE4U
# CCuR5m8UuZsX7SS8DcHPyYSzL6CA/RSFefMn0t78RtrcjVVCPiPRktCKnLzdhAP4
# 4D0BMTYc3vZCflESKILCT3nYfXM6BmPa2nxeCh5H0ZVzRnUM4YmfG6GCA2wwggNo
# BgkqhkiG9w0BCQYxggNZMIIDVQIBATBvMFsxCzAJBgNVBAYTAkJFMRkwFwYDVQQK
# ExBHbG9iYWxTaWduIG52LXNhMTEwLwYDVQQDEyhHbG9iYWxTaWduIFRpbWVzdGFt
# cGluZyBDQSAtIFNIQTM4NCAtIEc0AhABB2SbCLCn/n3WVKjy9Cn2MAsGCWCGSAFl
# AwQCAaCCAT0wGAYJKoZIhvcNAQkDMQsGCSqGSIb3DQEHATAcBgkqhkiG9w0BCQUx
# DxcNMjQwNDEyMTI0NDAyWjArBgkqhkiG9w0BCTQxHjAcMAsGCWCGSAFlAwQCAaEN
# BgkqhkiG9w0BAQsFADAvBgkqhkiG9w0BCQQxIgQgKlK0NE5+nZTj1r01ONy+kK8q
# 1DRgH0VohGfbE1BTFJMwgaQGCyqGSIb3DQEJEAIMMYGUMIGRMIGOMIGLBBRE05Oc
# zRuIf4Z6zNqB7K8PZfzSWTBzMF+kXTBbMQswCQYDVQQGEwJCRTEZMBcGA1UEChMQ
# R2xvYmFsU2lnbiBudi1zYTExMC8GA1UEAxMoR2xvYmFsU2lnbiBUaW1lc3RhbXBp
# bmcgQ0EgLSBTSEEzODQgLSBHNAIQAQdkmwiwp/591lSo8vQp9jANBgkqhkiG9w0B
# AQsFAASCAYBnwz2pqUQK8Uw5FOJOsh4Er76DnYRoZDO4dsngkP2gxt5KHIZovNqT
# yVMc+Ra/cdMP26PWapLGZT1LpjopW4h1BmcilTyAPykIIY5fIBrB8EbkNSMSy+jk
# GyoK0zCyDZyRSVf54M15ggDn/VNKEallDQPwzOMY0khVymBRJVDAv3cGZ5aXaJgq
# fas85mgCay9hWFhgOpf2NA5PF4/JVmex5NQIlLhk4RaT20KXEnpFWsqc6xgjWeh8
# 1WIppo7xG91JBZet0rBQ2AAh8PUA44kKt5IKQoYHxhd6E05ivxmaW+DUaeqKHxdC
# 09GCR/oCY4GE8n4zLAtRvGxwvZdAPcUFmz/+9gsV9phVFQr9rV8rvInVooC3kIkO
# pZ3+vnaAgCgFjou/FZDt91ciy73xS6TV+gjML4brHopOM53JZWB7XLR2ZeKyhvbb
# WBoOw20iwSRj4+TRqilztBHxh7ZKGOM9LEkhaUe/Lc7O6jo1BujLd0JGngDtB25E
# LdG8c6qfcqk=
# SIG # End signature block

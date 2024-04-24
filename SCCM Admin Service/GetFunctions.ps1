﻿<#	
	.NOTES
	===========================================================================
	 Created with: 	SAPIEN Technologies, Inc., PowerShell Studio 2021 v5.8.188
	 Created on:   	2021-10-12 09:05
	 Created by:   	Jean-Sébastien Frenette
	 Organization: 	STM
	 Filename:     	
	===========================================================================
	.DESCRIPTION
		A description of the file.
#>

###############
#Sample script for returning AdminService classes
# By: Adam Gross
# @AdamGrossTX
# https://www.asquaredozen.com
# https://github.com/AdamGrossTX
###############
[cmdletbinding()]
param (
	[parameter(Mandatory = $true)]
	[String]$SiteServer
)
$Main = {
	$FormatEnumerationLimit = -1
	$ControllerResults = Get-AdminServiceDetails -ServerName $SiteServer -ClassType 'Controller'
	$WMIResults = Get-AdminServiceDetails -ServerName $SiteServer -ClassType 'WMI'
	
	#Controllers
	$ContClasses = $ControllerResults.Edmx.DataServices.Schema.EntityType
	$ContFunctions = $ControllerResults.Edmx.DataServices.Schema.Function
	$ContActions = $ControllerResults.Edmx.DataServices.Schema.Action
	$ContContainers = $ControllerResults.Edmx.DataServices.Schema.EntityContainer
	
	Write-Host "Classes" -ForegroundColor Green
	#$ContClasses | Format-Table -wrap | Out-File -FilePath c:\temp\contclasses.txt -force
	$CSV_File = "c:\temp\contclasses.csv"
	$header = "Name;Property;Type"
	$header | Out-File -FilePath $CSV_File
	ForEach ($value in $ContClasses)
	{
		foreach ($prop in $value.Property)
		{
			$output = "$($value.Name);$($prop.Name);$($prop.type)"
			$output | Add-Content -Path $CSV_File
		}
	}
	
	
	Write-Host "Functions" -ForegroundColor Green
	#$ContFunctions | Format-Table -wrap
	$CSV_File = "c:\temp\contfunctions.csv"
	$header = "Name;IsBound;Parameter;ReturnType"
	$header | Out-File -FilePath $CSV_File
	ForEach ($value in $ContFunctions)
	{
		$params = ""
		$returns = ""
		foreach ($param in $($value.Parameter))
		{
			if ($params)
			{
				$params = "$params,$($param.Name)"
			}
			else
			{
				$params = "$($param.Name)"
			}
			
		}
		foreach ($returnval in $($value.ReturnType))
		{
			if ($returns)
			{
				$returns = "$returns,$($returnval.Name)"
			}
			else
			{
				$returns = "$($returnval.Name)"
			}
		}
		$output = "$($value.Name);$($value.IsBound);$params;$returns"
		$output | Add-Content -Path $CSV_File		
	}
	
	Write-Host "Actions" -ForegroundColor Green
	#$ContActions | Format-Table -wrap
	
	$CSV_File = "c:\temp\contactions.csv"
	$header = "Name;IsBound;Parameter"
	$header | Out-File -FilePath $CSV_File
	ForEach ($value in $ContActions)
	{
		$params = ""
		foreach ($param in $($value.Parameter))
		{
			if ($params)
			{
				$params = "$params,$($param.Name)"
			}
			else
			{
				$params = "$($param.Name)"
			}
			
		}
		$output = "$($value.Name);$($value.IsBound);$params"
		$output | Add-Content -Path $CSV_File
	}

	
	Write-Host "Containers" -ForegroundColor Green
	#$ContContainers | Format-Table -wrap
	
	$CSV_File = "c:\temp\contcontainers.csv"
	$header = "Name;EntitySet"
	$header | Out-File -FilePath $CSV_File
	ForEach ($value in $ContContainers)
	{
		$params = ""
		foreach ($param in $($value.EntitySet))
		{
			if ($params)
			{
				$params = "$params,$($param.Name)"
			}
			else
			{
				$params = "$($param.Name)"
			}
			
		}
		$output = "$($value.Name);$params"
		$output | Add-Content -Path $CSV_File
	}
	
	
	#WMI
	$wmiSchema = $WMIResults.Edmx.DataServices.Schema
	$wmiClasses = $WMIResults.Edmx.DataServices.Schema.EntityType
	$wmiComplexClasses = $WMIResults.Edmx.DataServices.Schema.ComplexType
	$wmiContainers = $WMIResults.Edmx.DataServices.Schema.EntityContainer
	$wmiActionImport = $WMIResults.Edmx.DataServices.Schema.EntityContainer.ActionImport
	$wmiAction = $WMIResults.Edmx.DataServices.Schema.action
	
	Write-Host "Schema" -ForegroundColor Green
	$wmiSchema | Format-Table -wrap
	
	
	$CSV_File = "c:\temp\wmiClasses.csv"
	$header = "Name;Abstract;PropertyName;PropertyType"
	$header | Out-File -FilePath $CSV_File
	ForEach ($value in $wmiClasses)
	{
		$prop = ""
		foreach ($prop in $($value.Property))
		{
			$output = "$($value.Name);$($value.Abstract);$($prop.Name);$($prop.Type)"
			
		}
		
		
	}
	
	Write-Host "Classes" -ForegroundColor Green
	#$wmiClasses | Format-Table -wrap
	$CSV_File = "c:\temp\wmiClasses.csv"
	$header = "Name;Abstract;PropertyName;PropertyType"
	$header | Out-File -FilePath $CSV_File
	ForEach ($value in $wmiClasses)
	{
		$prop = ""
		foreach ($prop in $($value.Property))
		{
			$output = "$($value.Name);$($value.Abstract);$($prop.Name);$($prop.Type)"
			$output | Add-Content -Path $CSV_File
		}
		
		
	}
	Write-Host "ComplexClasses" -ForegroundColor Green
	#$wmiComplexClasses | Format-Table -wrap
	
	$CSV_File = "c:\temp\wmiComplexClasses.csv"
	$header = "Name"
	$header | Out-File -FilePath $CSV_File
	ForEach ($value in $wmiComplexClasses)
	{
			$output = "$($value.Name)"
			$output | Add-Content -Path $CSV_File
	}
	
	Write-Host "Containers" -ForegroundColor Green
	#$wmiContainers | Format-Table -wrap
	
	$CSV_File = "c:\temp\wmiContainer.csv"
	$header = "ContainerName;EntityName;EntityType"
	$header | Out-File -FilePath $CSV_File
	ForEach ($value in $wmiContainers)
	{
		foreach ($entity in $value.entityset)
		{
			$output = "$($value.Name);$($entity.name);$($entity.entitytype)"
			$output | Add-Content -Path $CSV_File
		}
		
	}
	
	Write-Host "ActionImport" -ForegroundColor Green
	#$wmiActionImport.Name | Format-Table -wrap
	
	$CSV_File = "c:\temp\wmiActionImport.csv"
	$header = "Name;Action"
	$header | Out-File -FilePath $CSV_File
	ForEach ($value in $wmiActionImport)
	{
		$output = "$($value.Name);$($value.Action)"
		$output | Add-Content -Path $CSV_File
	}
	
	Write-Host "Action" -ForegroundColor Green
	#$wmiActionImport.Name | Format-Table -wrap
	
	$CSV_File = "c:\temp\wmiAction.csv"
	$header = "Name;IsBound;ParameterName;ParameterType;ReturnType"
	$header | Out-File -FilePath $CSV_File
	ForEach ($value in $wmiAction)
	{
		foreach ($param in $value.parameter)
		{
			$output = "$($value.Name);$($value.isbound);$($param.name);$($param.type);$($value.returntype.type)"
			$output | Add-Content -Path $CSV_File
		}
		
	}
	
}

Function Get-AdminServiceDetails
{
	param (
		$ServerName,
		$ClassType,
		[switch]$Metadata = $true
	)
	
	$ClassTypeURI = switch ($ClassType)
	{
		"WMI" { "wmi"; break; }
		"Controller" { "v1.0"; break; }
	}
	
	if ($Metadata)
	{
		$BaseURI = "https://{0}/AdminService/{1}/{2}" -f $ServerName, $ClassTypeURI, "`$metadata"
	}
	else
	{
		$BaseURI = "https://{0}/AdminService/{1}/" -f $ServerName, $ClassTypeURI
	}
	$Results = Invoke-RestMethod -Method Get -Uri "$($BaseURI)" -UseDefaultCredentials
	return $Results
}

#You can add a foreach loop on each object to get the properties for each entity. 

#$ControllerClasses = ($ControllerResults | ConvertFrom-Json).value
#$WMIClasses = ($WMIResults | ConvertFrom-Json).value

#Write-Host "Controller Classes" -ForegroundColor Green
#$ControllerClasses | Out-GridView
#Write-Host "WMI Classes" -ForegroundColor Green
#$WMIClasses | Out-GridView    

& $Main


# SIG # Begin signature block
# MIIrDgYJKoZIhvcNAQcCoIIq/zCCKvsCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCD1N3FeYwjSH50I
# O3KSniBekvu4HcvIEhREfLP0HweyWaCCJQ8wggU9MIIEJaADAgECAhAG4KIaKzBS
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
# AKBMMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMC8GCSqGSIb3DQEJBDEiBCAx
# N+37h7Ws8fgxYgAFDaFxey9GEvwjtOitf/a6r1UgjjANBgkqhkiG9w0BAQEFAASC
# AQB4ar6JJHU8FMah1cipsGtw9K8WbZooU/hpuIw1HjKO7lfJb8LSf5vvfB6a5rQ2
# ETlNIxP/EDIOdWhnZRmBk9vq1DC7QfCc4O+QUjsAx+PU9286aEV50g67j3ebPiBY
# +omXbxliCzETy1Rguelpuda28SefMB8NV4J3nEHNW7wt4uZ5upWo0G9hO8Ud36gl
# liPw7OVDL9CbdTskoAlALwq1f+CYme8f0Pt+YULOwyFY81MNsi6nMxdTORgKCs1W
# cEOWBTtrrg0F4EE2TqsZnCO1TVELACew7v/ejvu+cR8rRSG0gCx+m/YalayeGhhE
# /5hCNdvGhkrcz+8+wmykx5khoYIDbDCCA2gGCSqGSIb3DQEJBjGCA1kwggNVAgEB
# MG8wWzELMAkGA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYtc2ExMTAv
# BgNVBAMTKEdsb2JhbFNpZ24gVGltZXN0YW1waW5nIENBIC0gU0hBMzg0IC0gRzQC
# EAFIkD3CirynoRlNDBxXuCkwCwYJYIZIAWUDBAIBoIIBPTAYBgkqhkiG9w0BCQMx
# CwYJKoZIhvcNAQcBMBwGCSqGSIb3DQEJBTEPFw0yMzAzMjIxNzE2NDlaMCsGCSqG
# SIb3DQEJNDEeMBwwCwYJYIZIAWUDBAIBoQ0GCSqGSIb3DQEBCwUAMC8GCSqGSIb3
# DQEJBDEiBCBHREeZbwtTL6pvw0A6Fc7t13APN5hdvnrDRpfmtWEB0jCBpAYLKoZI
# hvcNAQkQAgwxgZQwgZEwgY4wgYsEFDEDDhdqpFkuqyyLregymfy1WF3PMHMwX6Rd
# MFsxCzAJBgNVBAYTAkJFMRkwFwYDVQQKExBHbG9iYWxTaWduIG52LXNhMTEwLwYD
# VQQDEyhHbG9iYWxTaWduIFRpbWVzdGFtcGluZyBDQSAtIFNIQTM4NCAtIEc0AhAB
# SJA9woq8p6EZTQwcV7gpMA0GCSqGSIb3DQEBCwUABIIBgI8kX4tS7g6dmBcNfDwc
# v9dziYxkpyh2mi5qmM88TBUJLy3yVh7FGKT07+oFmz1+s86FkqG9UnVUmiukpFYY
# DIegVm0Epru+VjtQ98weIrVToNWM0+02dKR8mjWynZqIuQwvWwlIaqIKbgJSuUu0
# vmJhst6RXCmjjeJQSl/2eSQ8r2oD3LjqL68MYRelRWypJ/pdhe23m7opILwawnR+
# McOOIwDCOyxvL/tjfXigZVifQ27K5SZk9Aa4Q/btuC9fEebpY+cOk9cixc5HZUNk
# hGDjEDBVB+8pNOx6UEAWLnTlKndKMTf+FoyU6zFypepVPxsRHI8+C+rAhuqLSfat
# 4ul5igI7irkGQ9O8z6PZzuoPhG65FFZOphIg5Io0PrKq988XPsRVHLQ7BVOR8j8G
# VI/gjBxrsrSF7fIWvr8/6KXr5TmIJI+JibvdKSvyiDhjGrPIobZReJpWQe1Gn5U/
# y8/DcFPS/GUIyg2ZYN47I2T9irdwtLNak0cmNl7TnWY5+g==
# SIG # End signature block

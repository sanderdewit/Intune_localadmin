#=============================================================================================================================
#
# Script Name:     Remediate_localadmins.ps1
# Description:     Remidiate local admins to match, sec group, deviceadmin, globaladmin & local-admin, make sure to run as 64 bits ps
# version:         v0.3
#=============================================================================================================================

# Define Variables
$DeviceAdmin = '<insert SID>'
$GlobalAdmin = '<insert SID>'
$serialnumber = ($(Get-CimInstance win32_bios).SerialNumber)
$groupnaming = "SECGRP-LA-PC-$($serialnumber)"
$ClientID = '<CLIENTID>'
$ClientSecret = '<CLIENT secret>'
$TenantName = 'tenant.onmicrosoft.com'
$loggingpath = 'c:\programdata\scripts'

########################################
# start script
########################################

#detect internet
if (!(Get-NetRoute | ? DestinationPrefix -eq '0.0.0.0/0' | Get-NetIPInterface | Where ConnectionState -eq 'Connected')){ Throw 'no connection'}

#detect if windows release is at least win10 2004
if (!([environment]::OSVersion.Version.build -ge '19041')){throw 'Windows lower than 2004 detected'}

import-module Microsoft.PowerShell.LocalAccounts

function get-laGroup{
    param (
        [parameter(Mandatory = $true)]
        $ClientID,
 
        [parameter(Mandatory = $true)]
        $ClientSecret,
 
        [parameter(Mandatory = $true)]
        $TenantName
    )

# Connect to Microsoft Graph with application credentials.
function Connect-MsGraphAsApplication {
    param (
        [parameter(Mandatory = $true)]
        $ClientID,
 
        [parameter(Mandatory = $true)]
        $ClientSecret,
 
        [parameter(Mandatory = $true)]
        $TenantName
    )
    # Declarations.
    $LoginUrl = 'https://login.microsoft.com'
    $ResourceUrl = 'https://graph.microsoft.com'
    # Force TLS 1.2.
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  
    # Compose REST request.
    $Body = @{ grant_type = "client_credentials"; resource = $ResourceUrl; client_id = $ClientID; client_secret = $ClientSecret }
    $OAuth = Invoke-RestMethod -Method Post -Uri $LoginUrl/$TenantName/oauth2/token?api-version=1.0 -Body $Body
    $OAuth.access_token
}
 
$AccessToken = Connect-MsGraphAsApplication -TenantName $TenantName -ClientID $ClientID -ClientSecret $ClientSecret
# Create header
$Header = @{
    Authorization = "$($AccessToken)"
}
$serialnumber = ($(Get-CimInstance win32_bios).SerialNumber)
$Uri = "https://graph.microsoft.com/v1.0/groups?$`Filter=displayname eq '$($groupnaming)'"
# Fetch relevant group
$GroupsRequest = Invoke-RestMethod -Uri $Uri -Headers $Header -Method Get -ContentType 'application/json'
$Group = $GroupsRequest.Value
return $($Group[0].securityIdentifier)
}


if (!(test-path $loggingpath)){New-Item $loggingpath -Force -ItemType Directory}
Start-Transcript -Path "$loggingpath\localadmin.log" #choose to overwrite, if you want to append, add -append
$localAdmin = ((Get-LocalUser | Select-Object -First 1).SID).AccountDomainSID.ToString()+'-500' #built-in localadmin is always SID 500, account should be disabled
$localAdmins = @()
$desiredadmins = @()
$desiredadmins += $localAdmin
$desiredadmins += $DeviceAdmin
$desiredadmins += $GlobalAdmin
try  {
      if (get-laGroup -ClientID $ClientID -ClientSecret $ClientSecret -TenantName $TenantName)
      {
      $desiredAdmins += get-laGroup -ClientID $ClientID -ClientSecret $ClientSecret -TenantName $TenantName
      }
     }
catch{
      throw ('Unable to retrieve AzureAD group')
     }

try 
{
    $administratorsGroup = ([ADSI]"WinNT://$env:COMPUTERNAME").psbase.children.find("Administrators")
    $administratorsGroupMembers= $administratorsGroup.psbase.invoke("Members")
       foreach ($administrator in $administratorsGroupMembers) {
        $localAdmins += (New-Object System.Security.Principal.SecurityIdentifier($administrator.GetType().InvokeMember('objectSid','GetProperty',$null,$administrator,$null),0)).value
       }
       #remove forbidden local administrators
       foreach ($Admin in $localAdmins)
       {
        if ($desiredadmins -notcontains $Admin)
        {
	   Remove-LocalGroupMember -Group Administrators -Member $Admin -verbose -ErrorAction Continue
        }
       }
       #adding missing local administrators
       foreach ($Admin in $desiredadmins)
       {
        if ($localAdmins -notcontains $Admin)
        {
         add-LocalGroupMember -Group Administrators -Member $Admin -verbose
        }
       }
}
catch 
{ 
Write-Error $Error[0]
exit 1
}
Stop-Transcript
exit 0

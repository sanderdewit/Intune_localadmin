#=============================================================================================================================
#
# Script Name:     Remediate_localadmins.ps1
# Description:     Remidiate local admins to match, sec group, deviceadmin, globaladmin & local-admin, make sure to run as 64 bits ps
# version:         v0.2
#=============================================================================================================================

# Define Variables
$localadmin = '<localadmin>'
$deviceadmin = '<insert SID>'
$globaladmin = '<insert SID>'
$serialnumber = ($(Get-CimInstance win32_bios).SerialNumber)
$groupnaming = "SECGRP-LA-PC-$($serialnumber)"
$ClientID = '<CLIENTID>'
$ClientSecret = '<CLIENT secret>'
$TenantName = 'tenant.onmicrosoft.com'
$loggingpath = 'c:\programdata\scripts'
$domain = 'userdomain' #use for the on-premises domain for AzureAD sourced users (no aadconnect), use AzureAD

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
    $LoginUrl = "https://login.microsoft.com"
    $ResourceUrl = "https://graph.microsoft.com"
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
$GroupsRequest = Invoke-RestMethod -Uri $Uri -Headers $Header -Method Get -ContentType "application/json"
$Group = $GroupsRequest.Value
return $($Group[0].securityIdentifier)
}


if (!(test-path $loggingpath)){New-Item $loggingpath -Force -ItemType Directory}
$lagroup = get-laGroup -ClientID $ClientID -ClientSecret $ClientSecret -TenantName $TenantName
Start-Transcript -Path "$loggingpath\localadmin.log" #choose to overwrite, if you want to append, add -append
$localAdministrators = @()
$desiredadmins = @()
$desiredadmins += $localadmin
$desiredadmins += $deviceadmin
$desiredadmins += $globaladmin

try 
{
    $desiredadmins += $lagroup
    $administratorsGroup = ([ADSI]"WinNT://$env:COMPUTERNAME").psbase.children.find("Administrators")
    $administratorsGroupMembers= $administratorsGroup.psbase.invoke("Members")
       foreach ($administrator in $administratorsGroupMembers) {
        $localAdministrators += $administrator.GetType().InvokeMember('Name','GetProperty',$null,$administrator,$null)
       }
       #remove forbidden local administrators
       foreach ($localadmin in $localAdministrators)
       {
        if ($desiredadmins -notcontains $localadmin)
        {
	if (!(Get-LocalUser -Name $localadmin -ErrorAction Ignore) -and ($localadmin -notlike 'S-1-12*')){
         Remove-LocalGroupMember -Group Administrators -Member "$Domain\$localadmin" -verbose -ErrorAction Continue
	 }
	 else 
	  {
	   Remove-LocalGroupMember -Group Administrators -Member $localadmin -verbose -ErrorAction Continue
	  }
        }
       }
       #adding missing local administrators
       foreach ($localadmin in $desiredadmins)
       {
        if ($localAdministrators -notcontains $localadmin)
        {
         add-LocalGroupMember -Group Administrators -Member $localadmin -verbose
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

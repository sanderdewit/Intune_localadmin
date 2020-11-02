#=============================================================================================================================
#
# Script Name:     Detect_localadmins.ps1
# Description:     Detect localadmin, local admin user, device admin, global admin and the sec group for LA.
# version:         v0.2
#=============================================================================================================================

# Define Variables
$localadmin = '<localadmin>'
$deviceadmin = '<insert SID>'
$globaladmin = '<insert SID>'
$serialnumber = ($(Get-CimInstance win32_bios).SerialNumber)
$groupnaming = "SECGRP-LA-PC-$($serialnumber)"
$ClientID = '<clientid>'
$ClientSecret = '<clientsecret>'
$TenantName = 'tenant.onmicrosoft.com'
$loggingpath = 'c:\programdata\scripts'

########################################
# start script
########################################

#detect internet
if (!(Get-NetRoute | ? DestinationPrefix -eq '0.0.0.0/0' | Get-NetIPInterface | Where ConnectionState -eq 'Connected')){ Throw 'no connection'}

function get-laGroup {
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

$Uri = "https://graph.microsoft.com/v1.0/groups?$`Filter=displayname eq '$($groupnaming)'"
# Fetch relevant group
$GroupsRequest = Invoke-RestMethod -Uri $Uri -Headers $Header -Method Get -ContentType "application/json"
$Group = $GroupsRequest.Value
return $($Group[0].securityIdentifier)
}
 

$localAdministrators = @()
$desiredadmins = @()
$desiredadmins += $localadmin
$desiredadmins += $deviceadmin
$desiredadmins += $globaladmin
 
try
{
    if (get-laGroup -ClientID $ClientID -ClientSecret $ClientSecret -TenantName $TenantName){$desiredadmins += get-laGroup -ClientID $ClientID -ClientSecret $ClientSecret -TenantName $TenantName}
    $administratorsGroup = ([ADSI]"WinNT://$env:COMPUTERNAME").psbase.children.find("Administrators")
    $administratorsGroupMembers= $administratorsGroup.psbase.invoke("Members")
    foreach ($administrator in $administratorsGroupMembers) {
        $localAdministrators += $administrator.GetType().InvokeMember('Name','GetProperty',$null,$administrator,$null)
    }
    $compare = Compare-Object -ReferenceObject $desiredadmins -DifferenceObject $localAdministrators
    if ($compare -eq $null){
    Write-Host "Match"
        exit 0
        }
    else{
        #Local admins not matching
        Write-Output "No_Match, $compare"       
        exit 1
    }  
}
catch{
    $errMsg = $_.Exception.Message
    Write-Error $errMsg
    exit 1
}

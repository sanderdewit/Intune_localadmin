#=============================================================================================================================
#
# Script Name:     Detect_localadmins.ps1
# Description:     Detect localadmin, local admin user, device admin, global admin and the sec group for LA.
# version:         v0.8
#=============================================================================================================================

# Define Variables
$DeviceAdmin = '<insert SID>'
$GlobalAdmin = '<insert SID>'
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
if (!([environment]::OSVersion.Version.build -ge '19041')){throw 'Windows lower than 2004 detected'}
import-module Microsoft.PowerShell.LocalAccounts
$localAdmin = ((Get-LocalUser | Select-Object -First 1).SID).AccountDomainSID.ToString()+'-500' #built-in localadmin is always SID 500, account should be disabled

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
    $LoginUrl = 'https://login.microsoft.com'
    $ResourceUrl = 'https://graph.microsoft.com'
    # Force TLS 1.2.
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  
    # Compose REST request.
    $Body = @{ grant_type = 'client_credentials'; resource = $ResourceUrl; client_id = $ClientID; client_secret = $ClientSecret }
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
$GroupsRequest = Invoke-RestMethod -Uri $Uri -Headers $Header -Method Get -ContentType 'application/json'
$Group = $GroupsRequest.Value
return $($Group[0].securityIdentifier)
}
 

$localAdmins = @()
$desiredAdmins = @()
$desiredAdmins += $localAdmin
$desiredAdmins += $DeviceAdmin
$desiredAdmins += $GlobalAdmin
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
    $compare = Compare-Object -ReferenceObject $desiredAdmins -DifferenceObject $localAdmins
    if ($compare -eq $null){
    Write-Host "Match"
        exit 0
        }
    else{
        #Local admins not matching
        if (!(Get-ItemProperty -Path 'HKLM:\SOFTWARE\IntunePAR\' -Name 'LaCheck' -ErrorAction SilentlyContinue))
        {
        #detected first run
            foreach ($Admin in $desiredadmins){
                if ($localAdmins -notcontains $Admin)
                {
                add-LocalGroupMember -Group Administrators -Member $Admin -verbose
                }
            }
        if ((Get-ChildItem HKU: |where-object {$_.Name -match 'S-\d-\d+-(\d+-){1,14}\d+$'}).PSChildName -contains ((Get-LocalUser|Select-Object -First 1).SID).AccountDomainSID.ToString()+'-503' -eq $true) #defaultuser session detected
        {
         $defaultuser = $true
        }
        foreach ($Admin in $localAdmins)
        {
         if ($desiredadmins -notcontains $Admin -and ($defaultuser -ne $true))
           {
            Remove-LocalGroupMember -Group Administrators -Member $Admin -verbose -ErrorAction Continue
           }
        }
        new-Item -Path 'HKLM:\SOFTWARE\IntunePAR' -Force
        New-ItemProperty -Path 'HKLM:\SOFTWARE\IntunePAR' -Name 'LACheck' -Value 1 -Force
        Write-Output 'initial setup'
        exit 0
        }
     Write-Output "No_Match, $compare"       
     exit 1
    }
}
catch
{
    $errMsg = $_.Exception.Message
    Write-Error $errMsg
    exit 1
}

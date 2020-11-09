$expirationyears = '3'
$appName = 'Local administrator solution'

Connect-AzureAD
if(!($AADApp = Get-AzureADApplication -Filter "DisplayName eq '$($appName)'"  -ErrorAction SilentlyContinue))
{
	#Application Key for $expirationyears years
	$Guid = New-Guid
	$startDate = Get-Date
	
	$PasswordCredential 				= New-Object -TypeName Microsoft.Open.AzureAD.Model.PasswordCredential
	$PasswordCredential.StartDate 		= $startDate
	$PasswordCredential.EndDate 		= $startDate.AddYears($expirationyears)
	$PasswordCredential.KeyId 			= $Guid
	$PasswordCredential.Value 			= ([System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(($Guid))))+"="

	$AADApp = New-AzureADApplication -DisplayName $appName -PasswordCredentials $PasswordCredential -RequiredResourceAccess $reqGraph
    $AADSPN = New-AzureADServicePrincipal -AppId $AADApp.AppId
	
    $Scopes = New-Object System.Collections.Generic.List[Microsoft.Open.AzureAD.Model.OAuth2Permission]
    $Scope = $AADApp.Oauth2Permissions | Where-Object { $_.Value -eq "user_impersonation" }
    $Scope.IsEnabled = $false
    $Scopes.Add($Scope)
    Set-AzureADApplication -ObjectId $AADApp.ObjectID -Oauth2Permissions $Scopes
    $EmptyScopes = New-Object System.Collections.Generic.List[Microsoft.Open.AzureAD.Model.OAuth2Permission]

	#Microsoft Graph to search permissionID
	$svcprincipal = Get-AzureADServicePrincipal -All $true | Where-Object { $_.DisplayName -eq "Microsoft Graph" }

	### Microsoft Graph to search permissionID
	$ResourcePermissions = New-Object -TypeName "Microsoft.Open.AzureAD.Model.RequiredResourceAccess"
	$ResourcePermissions.ResourceAppId = $svcprincipal.AppId

	##Application Permissions
	$AddGroupReadAll = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList '5b567255-7703-4780-807c-7be8301ae99b','Role' #Group.Read.All
	
	$ResourcePermissions.ResourceAccess = $AddGroupReadAll


    Set-AzureADApplication -ObjectId $AADApp.ObjectID -Oauth2Permissions $EmptyScopes -RequiredResourceAccess $ResourcePermissions

	$AppDetailsOutput = "Application Details for the $appName application:
=========================================================
Application Name: 	$appName
Application Id:   	$($AADApp.AppId)
Secret Key:       	$($PasswordCredential.Value)
"
	Write-Output $AppDetailsOutput
}
else
{
	Write-Error "$appName already exists"
}

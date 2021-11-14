#get-info for roles
function Convert-AzureAdSidToObjectId {
    param([String] $ObjectId)
    $bytes = [Guid]::Parse($ObjectId).ToByteArray()
    $array = New-Object 'UInt32[]' 4

    [Buffer]::BlockCopy($bytes, 0, $array, 0, 16)
    $sid = "S-1-12-1-$array".Replace(' ', '-')
    return $sid
}

Connect-AzureAD
$roles = Get-AzureADDirectoryRole
$globaladmin = $roles|Where-Object {$_.displayname -eq 'Global Administrator'}
$deviceadmin = $roles|Where-Object {$_.displayname -eq 'Azure AD Joined Device Local Administrator'}

$globaladminSid = Convert-AzureAdSidToObjectId $($globaladmin.objectId)
$deviceAdminSid = Convert-AzureAdSidToObjectId $($deviceadmin.objectId)

Write-Output "SIDs for the accounts are:
globaladmin: $globaladminSid
deviceadmin: $deviceAdminSid
"

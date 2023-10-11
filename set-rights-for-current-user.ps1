# https://gist.github.com/jermdavis/6fb0a6e47d6f1342c089af4c04d29c35#file-2_add-docker-role-ps1

param(
    [string]$userName = $env:username,
    [string]$userDomain = $env:userdomain
)

# non-admin rights to access engine: https://github.com/tfenster/dockeraccesshelper
function GrantRights
{
    param(
        [string]$domain,
        [string]$user
    )

    Write-Host "Adding $domain \ $user to docker named pipe's rights" -ForegroundColor Green

    $account="$($domain)\$($user)"
    $npipe = "\\.\pipe\docker_engine"                                                                                 
    $dirInfo = New-Object "System.IO.DirectoryInfo" -ArgumentList $npipe                                               
    $dirRights = $dirInfo.GetAccessControl()  
	
    $fullControl =[System.Security.AccessControl.FileSystemRights]::FullControl                                       
    $allow =[System.Security.AccessControl.AccessControlType]::Allow 
	
    $rule = New-Object "System.Security.AccessControl.FileSystemAccessRule" -ArgumentList $account,$fullControl,$allow
    $dirRights.AddAccessRule($rule)                                                                                        
    $dirInfo.SetAccessControl($dirRights)

    Write-Host "Done." -ForegroundColor Green
}

# Make sure the current user has rights to run containers
GrantRights $userDomain $userName
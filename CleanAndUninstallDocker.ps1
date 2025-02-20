# Get the current user's name
$currentUser = $env:USERNAME
$windowsFilterFolderPath = "C:\ProgramData\Docker\windowsfilter"
$dockerService = Get-Service -Name docker -ErrorAction SilentlyContinue

# List of folders to delete
$foldersToClean = @(
    "C:\docker",
    "C:\ProgramData\docker",
    "C:\Program Files\docker",
    "C:\Users\$currentUser\.docker"
)

# Function to delete a folder and handle errors
function Remove-Folder {
    param (
        [string]$folderPath
    )

    if (Test-Path $folderPath) {
        try {
            # Attempt to delete the folder
            Remove-Item -Path $folderPath -Recurse -Force -ErrorAction Stop
            Write-Output "Successfully deleted: $folderPath"
        }
        catch {
            # Suppress errors for folders under windowsfilter
            if ($folderPath -like "C:\ProgramData\docker\windowsfilter*") {
                Write-Output "Failed to delete: $folderPath"
            }
            elseif ($folderPath -like "C:\ProgramData\docker*") {
                .\clean-docker-windowsfilter-folder.ps1
            } 
            else {
                Write-Output "Failed to delete: $folderPath"
                Write-Error $_.Exception.Message
            }
        }

    }
    else {
        Write-Output "Folder does not exist: $folderPath"
    }
}


#Execution Starts Here
if ($null -ne $dockerService -and $dockerService.Status -eq 'Running') {
    .\Find-OrphanDockerLayers.ps1 -RenameOrphanLayers
}
else {
    Write-Host "Docker service is not running or doesn't exist." -ForegroundColor Red
}

if ($null -ne $dockerService -and $dockerService.Status -eq 'Running') {
    Write-Host "Docker service is running. Stopping the service..."
    Stop-Service -Name docker -Force
    Write-Host "Docker service stopped successfully."

    $confirmation = Read-Host "Please press + C when you see the msg='API listen on //./pipe/docker_engine' after sometime! (Y/N)" -ForegroundColor Yellow

    if ($confirmation -match "^[yY]$") {
        Write-Host "Acknowledged. Proceeding..." -ForegroundColor Green
        dockerd -D --shutdown-timeout 900

        if (Test-Path $windowsFilterFolderPath) {
            Write-Host "The folder exists: $windowsFilterFolderPath" -ForegroundColor Green
        }
        else {
            Write-Host "The folder does not exist: $folderPath" -ForegroundColor Red
        }

        if (Test-Path $windowsFilterFolderPath) {
            $subfolders = Get-ChildItem -Path $windowsFilterFolderPath -Directory

            if ($subfolders.Count -gt 0) {
                Write-Host "Unable to clean folder path '$windowsFilterFolderPath'." -ForegroundColor Red
            }
            else {
                # Perform docker uninstallation
                .\uninstall-docker.ps1

                # Iterate over each folder and attempt to delete
                foreach ($folder in $foldersToClean) {
                    Remove-Folder -folderPath $folder
                }
            }
        }

    }
    elseif ($confirmation -match "^[nN]$") {
        Write-Host "Denied." -ForegroundColor Red
    }
    else {
        Write-Host "Invalid input. Please enter 'y' or 'n'." -ForegroundColor Yellow
    }
}
else {
    Write-Host "Docker service is not running or doesn't exist." -ForegroundColor Red
}
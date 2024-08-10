# Get the current user's name
$currentUser = $env:USERNAME

# List of folders to delete
$folders = @(
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
            Remove-Item -Path $folderPath -Recurse -Force
            Write-Output "Successfully deleted: $folderPath"
        } catch {
            Write-Error "Failed to delete: $folderPath"
            Write-Error $_.Exception.Message

             # Check if the folder is C:\ProgramData\docker\windowsfilter
            if ($folderPath -eq "C:\ProgramData\docker\windowsfilter") {
                Write-Output "If you're having trouble deleting the folder, please visit the following blog for help: https://sitecoresafari.wordpress.com/2023/10/16/regain-disk-space-occupied-by-docker/"
            }
        }
    } else {
        Write-Output "Folder does not exist: $folderPath"
    }
}

# Iterate over each folder and attempt to delete
foreach ($folder in $folders) {
    Remove-Folder -folderPath $folder
}

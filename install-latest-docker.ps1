#Run as Admin

# https://gist.github.com/jermdavis/6fb0a6e47d6f1342c089af4c04d29c35#file-1_install-docker-ps1

param(
    [string]$dockerEnginePath = "C:\",
    [string]$dockerInstallPath = "C:\Docker",
    [string]$dockerEngineUrl = "https://download.docker.com/win/static/stable/x86_64/docker-28.1.1.zip",
    [string]$dockerZip = "docker.zip",

    [string]$serviceName = "docker",

	[string]$dockerPluginInstallPath = "C:\Program Files\Docker\cli-plugins",
    [string]$composeEngineUrl = "https://github.com/docker/compose/releases/latest/download/docker-compose-windows-x86_64.exe",
    [string]$composeExe = "docker-compose.exe"
)

$ErrorActionPreference = "Stop"

function DownloadFile
{
    param(
        [string]$name,
        [string]$downloadUrl,
        [string]$output
    )

    if(-not(Test-Path $output))
    {
        Write-Host "Downloading $name file" -ForegroundColor Green
        Invoke-WebRequest -Uri $downloadUrl -OutFile $output
    }
    else
    {
        Write-Host "$name already exists" -ForegroundColor Yellow
    }
}

function FetchLatestEngineUrl
{
	$archiveUrl = "https://download.docker.com/win/static/stable/x86_64/"
	
	Write-Host "Checking for latest Engine at $archiveUrl" -ForegroundColor Yellow

	$response = Invoke-WebRequest -Uri $archiveUrl -UseBasicParsing

	# Parse the HTML content using regular expressions to find the latest version and download link
	$pattern = '<a href="([^"]*docker-([\d.]+)\.zip)"'
	$matches = [regex]::Matches($response.Content, $pattern)

	$latestVersion = $null
	$latestDownloadLink = $null

	foreach ($match in $matches) {
		$downloadLink = $match.Groups[1].Value
		$version = $match.Groups[2].Value

		if ($latestVersion -eq $null -or [Version]$version -gt [Version]$latestVersion) {
			$latestVersion = $version
			$latestDownloadLink = $downloadLink
		}
	}

	if ($latestVersion -ne $null -and $latestDownloadLink -ne $null) {
		Write-Host "Latest Available Version: $latestVersion"
		$script:dockerEngineUrl = "$archiveUrl$latestDownloadLink"
		
	} else {
		Write-Host "Unable to find the latest version and download link. Installing 24.0.6"
	}
}

function StopAndRemoveExistingService
{
    param(
        [string]$svcName
    )
    $service = Get-Service | where { $_.Name -eq $svcName }
    if($service.length -eq 0)
    {
        Write-Host "No existing service for $svcName" -ForegroundColor Green
    }
    else
    {
        $service | % {
          Write-Host "Service '$($_.DisplayName)' exists" -ForegroundColor Yellow
          if($_.Status -eq "Running")
          {
            Write-Host "$($_.Name) service is running" -ForegroundColor Yellow

            $items = docker ps -q

            if($items -ne $null)
            {
                popd
                throw "Containers are running - stop them before running this script"
            }

          }

          Write-Host "Removing service" -ForegroundColor Green
          Stop-Service $_.Name
          dockerd --unregister-service
        }
    }
}

function EnsureDockerInPath
{
    param(
        [string]$installPath
    )

    $path = [System.Environment]::GetEnvironmentVariable("Path","Machine")
    if(-not($path.Contains($installPath)))
    {
        $newPath = "$($env:path);$($installPath)"
        Write-Host "New path: $newPath" -ForegroundColor Green
        [Environment]::SetEnvironmentVariable("Path", $newPath, [System.EnvironmentVariableTarget]::Machine)
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    }
    else
    {
        Write-Host "Path is already correct" -ForegroundColor Yellow
    }
}

function VerifyWindowsFeature
{
	param(
		[string]$featureName
	)
	
	$hasFeature = (Get-WindowsOptionalFeature -FeatureName $featureName -Online | Select -ExpandProperty State) -eq "Enabled"
	if(-not $hasFeature)
	{
		Write-Host "$featureName feature not currently installed - adding" -ForegroundColor Yellow
		$result = Enable-WindowsOptionalFeature -Online -FeatureName $featureName -NoRestart -All

		return $result.RestartNeeded
	}
	else
	{
		Write-Host "$featureName feature is already installed" -ForegroundColor Green
		return $false
	}
}

function EnsureWindowsFeatures
{
	$containersNeedsRestart = VerifyWindowsFeature "Containers"
	$hyperVNeedsReboot = VerifyWindowsFeature "Microsoft-Hyper-V"

	if($containersNeedsRestart -or $hyperVNeedsReboot)
	{
		popd
		throw "Restart required after adding Windows features"
	}
}

function EnsureDockerServiceRunning
{
    param(
        [string]$svcName
    )
	
    Write-Host "Registering & starting $svcName service" -ForegroundColor Green
    dockerd --register-service
    Start-Service $svcName
}

# Make sure Hyper-V etc is installed
EnsureWindowsFeatures

# Go to this user's downloads folder
pushd $(New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path

# stop & remove any running service if possible
StopAndRemoveExistingService $serviceName

# Fetch the docker engine and unzip it
FetchLatestEngineUrl
DownloadFile "Docker" $dockerEngineUrl $dockerZip
Expand-Archive $dockerZip -DestinationPath $dockerEnginePath -Force
Remove-Item $dockerZip

# Make sure the docker folder is in the path
EnsureDockerInPath $dockerInstallPath

# Get docker service running
EnsureDockerServiceRunning $serviceName

# Install Compose plugin to Support v1 & v2
DownloadFile "Compose" $composeEngineUrl $composeExe
Unblock-File $composeExe
	# for V1
Copy-Item -Path $composeExe -Destination $dockerInstallPath
	# for V2
New-Item -ItemType Directory -Force -Path $dockerPluginInstallPath | Out-Null
Copy-Item -Path $composeExe -Destination $dockerPluginInstallPath

Remove-Item $composeExe

Write-Host "Docker compose plugin installed." -ForegroundColor Green

popd


## Needs Run as administrator ##

function RemoveService
{
    param(
        [string]$serviceName
    )
    $service = Get-Service | where { $_.Name -eq $serviceName }
    if($service.length -eq 0)
    {
        Write-Host "$servicecName service not found" -ForegroundColor Green
    }
    else
    {
        $service | % {
          Write-Host "Service '$($_.DisplayName)' found" -ForegroundColor Yellow
          if($_.Status -eq "Running")
          {
            Write-Host "$($_.Name) service is running" -ForegroundColor Yellow

            $items = docker ps -q
            if($items -ne $null)
            {
                throw "Containers are running - stop them and re-run this script"
            }
          }

          Write-Host "Removing $($_.Name) service" -ForegroundColor Green
          Stop-Service $_.Name
          dockerd --unregister-service
        }
    }
}


# stop & remove any running service
RemoveService "docker"
write-host "Please clean-up Docker folders" -ForegroundColor Yellow


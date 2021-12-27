  $db1Exists = docker ps -q -f name="db1"

    if ([string]::IsNullOrEmpty($db1Exists)) {
        Write-Host "Remove container db1"
        docker rm -f db1
    }
	
	 $db2Exists = docker ps -q -f name="db2"

    if ([string]::IsNullOrEmpty($db2Exists)) {
        Write-Host "Remove container db2"
        docker rm -f db2
    }
	
	
	  $db3Exists = docker ps -q -f name="db3"

    if ([string]::IsNullOrEmpty($db3Exists)) {
        Write-Host "Remove container db3"
        docker rm -f db3
    }
	
docker-compose up -d --build --force-recreate --remove-orphans
docker image prune -f
docker network prune -f
docker builder prune -f

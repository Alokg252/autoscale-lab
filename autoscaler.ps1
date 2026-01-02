$MIN = 2
$MAX = 6

while ($true) {

    # Get CPU usage for api containers
    $stats = docker stats --no-stream --format "{{.CPUPerc}}" api 2>$null

    if (-not $stats) {
        Start-Sleep -Seconds 5
        continue
    }

    $cpuValues = $stats | ForEach-Object {
        ($_ -replace '%','') -as [double]
    }

    $avgCpu = ($cpuValues | Measure-Object -Average).Average

    # Count running api containers
    $count = (docker ps --filter "name=api" --format "{{.ID}}").Count

    Write-Host "CPU: $([math]::Round($avgCpu,2))% | replicas: $count"

    if ($avgCpu -gt 70 -and $count -lt $MAX) {
        $new = $count + 1
        Write-Host "Scaling up → $new"
        docker compose up -d --scale api=$new
    }

    if ($avgCpu -lt 30 -and $count -gt $MIN) {
        $new = $count - 1
        Write-Host "Scaling down → $new"
        docker compose up -d --scale api=$new
    }

    Start-Sleep -Seconds 10
}

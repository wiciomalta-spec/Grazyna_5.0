param([string]$cmd)

switch ($cmd) {

"status" {
  node agent/src/index.ts
}

"start" {
  docker build -t ahe-app app
  docker run -p 3001:3001 ahe-app
}

"hybrid" {
  docker run -e APP_PROFILE=hybrid ahe-app
}

"benchmark" {
  Write-Host "Running performance test..."
}

"optimize" {
  Write-Host "Analyzing metrics and optimizing..."
}

"default" {
  Write-Host "Commands:"
  Write-Host "status | start | hybrid | benchmark | optimize"
}

}
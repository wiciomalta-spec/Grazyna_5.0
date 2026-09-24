#requires -Version 7.0
[CmdletBinding()]
param(
  [ValidateSet('Inventory','Plan','Apply')][string]$Action='Inventory',
  [string[]]$Targets=@('backend','frontend'),
  [string]$PlanId=''
)
$ErrorActionPreference='Stop'
$Root='E:\Grazyna_5.0'; $Backend=Join-Path $Root 'backend'; $Frontend=Join-Path $Root 'frontend'
$LogDir=Join-Path $Root 'logs\updates'; $StateDir=Join-Path $Root 'runtime\update'
New-Item -ItemType Directory -Force -Path $LogDir,$StateDir | Out-Null
$stamp=Get-Date -Format 'yyyyMMdd_HHmmss'; $log=Join-Path $LogDir "controlled_update_$stamp.log"
function Write-Log([string]$Level,[string]$Message){$line="[$Level] $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message";Add-Content -LiteralPath $log -Value $line -Encoding UTF8}
function Get-Cmd([string]$name){$c=Get-Command $name -ErrorAction SilentlyContinue;if($c){$c.Source}else{$null}}
function Get-Npm([string]$dir){$pkg=Join-Path $dir 'package.json';$lock=Join-Path $dir 'package-lock.json';[pscustomobject]@{target=(Split-Path $dir -Leaf);path=$dir;package_exists=(Test-Path $pkg);lock_exists=(Test-Path $lock);package_sha=if(Test-Path $pkg){(Get-FileHash $pkg -Algorithm SHA256).Hash}else{$null};lock_sha=if(Test-Path $lock){(Get-FileHash $lock -Algorithm SHA256).Hash}else{$null};node_modules=Test-Path (Join-Path $dir 'node_modules')}}
function Get-ProcessState{$p=@();foreach($x in @(Get-Process node -ErrorAction SilentlyContinue)){try{$p+=[pscustomobject]@{pid=$x.Id;name='node';memory_mb=[math]::Round($x.WorkingSet64/1MB,1)}}catch{}};foreach($x in @(Get-Process python -ErrorAction SilentlyContinue)){try{$w=Get-CimInstance Win32_Process -Filter "ProcessId=$($x.Id)" -ErrorAction SilentlyContinue;if($w.CommandLine -like '*Grazyna_MPPS_V21*'){$p+=[pscustomobject]@{pid=$x.Id;name='python';memory_mb=[math]::Round($x.WorkingSet64/1MB,1)}}}catch{}};$p}
Write-Log INFO "GRAŻYNA CONTROLLED UPDATE — action=$Action targets=$($Targets -join ',')"
$inventory=[ordered]@{timestamp=(Get-Date).ToString('o');root=$Root;tools=[ordered]@{node=(Get-Cmd 'node');npm=(Get-Cmd 'npm');git=(Get-Cmd 'git');ollama=(Get-Cmd 'ollama')};backend=Get-Npm $Backend;frontend=Get-Npm $Frontend;processes=@(Get-ProcessState);ports=@(3001,8788,1883,11434|ForEach-Object{$port=$_;$owner=Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue|Select-Object -First 1;[pscustomobject]@{port=$port;state=if($owner){$owner.State}else{'FREE'};pid=if($owner){$owner.OwningProcess}else{$null}}})}
if($Action -eq 'Inventory'){$inventory|ConvertTo-Json -Depth 8;exit 0}
$actions=@()
foreach($t in $Targets){switch($t){'backend'{if($inventory.backend.lock_exists){$actions+=[pscustomobject]@{id='backend-npm-ci';target='backend';command='npm ci --ignore-scripts';reason='package-lock.json'}}}'frontend'{if($inventory.frontend.lock_exists){$actions+=[pscustomobject]@{id='frontend-npm-ci';target='frontend';command='npm ci --ignore-scripts';reason='package-lock.json'}}}}}
if($Action -eq 'Plan'){
  $plan=[ordered]@{plan_id=([guid]::NewGuid().ToString('N'));created=(Get-Date).ToString('o');mode='CONTROLLED';root=$Root;preconditions=@('brak operacji ECU/FLASH','nie zatrzymuj MPPS','backup/log przed zmianą','health-check po backendzie');actions=$actions;excluded=@('git pull/merge','ECU/FLASH','driver install','Ollama model pull','zatrzymywanie procesów MPPS')}
  $planPath=Join-Path $StateDir 'current_plan.json';$plan|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $planPath -Encoding UTF8
  Write-Log INFO "PLAN zapisany plan_id=$($plan.plan_id)"
  $plan|ConvertTo-Json -Depth 8;exit 0
}
if($Action -eq 'Apply'){
  $planPath=Join-Path $StateDir 'current_plan.json'
  if(-not (Test-Path $planPath)){throw 'PLAN_MISSING'}
  $saved=Get-Content -LiteralPath $planPath -Raw|ConvertFrom-Json
  if($PlanId -ne $saved.plan_id){throw "PLAN_MISMATCH: aktualny plan_id=$($saved.plan_id)"}
  $actions=@($saved.actions)
}
Write-Log INFO "APPLY zatwierdzone plan_id=$PlanId";$results=@()
foreach($a in $actions){$dir=if($a.target -eq 'backend'){$Backend}else{$Frontend};Write-Log INFO "START $($a.id)";Push-Location $dir;try{& npm ci --ignore-scripts 2>&1|ForEach-Object{Write-Log INFO "$_"};if($LASTEXITCODE -ne 0){throw "npm ci exit=$LASTEXITCODE"};$results+=[pscustomobject]@{id=$a.id;status='PASS'};Write-Log INFO "PASS $($a.id)"}catch{$results+=[pscustomobject]@{id=$a.id;status='FAIL';error=$_.Exception.Message};Write-Log ERROR "FAIL $($a.id): $($_.Exception.Message)";throw}finally{Pop-Location}}
try{$h=Invoke-RestMethod 'http://127.0.0.1:3001/health' -TimeoutSec 5;$results+=[pscustomobject]@{id='backend-health';status=if($h.status -eq 'ok'){'PASS'}else{'FAIL'}}}catch{$results+=[pscustomobject]@{id='backend-health';status='FAIL';error=$_.Exception.Message}}
[ordered]@{status=if(@($results|Where-Object status -eq 'FAIL').Count -eq 0){'PASS'}else{'FAIL'};plan_id=$PlanId;results=$results;log=$log}|ConvertTo-Json -Depth 8

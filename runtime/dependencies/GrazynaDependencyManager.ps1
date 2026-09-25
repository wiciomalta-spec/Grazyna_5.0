#requires -Version 7.0
[CmdletBinding()]
param(
  [ValidateSet('Inventory','Catalog','Plan','Apply')][string]$Action='Inventory',
  [string]$Root=(Split-Path -Parent (Split-Path -Parent $PSScriptRoot)),
  [string]$PlanId='',
  [string]$Confirm=''
)
$ErrorActionPreference='Stop'
$Root=(Resolve-Path -LiteralPath $Root -ErrorAction Stop).Path
$State=Join-Path $Root 'runtime\dependencies'
$CatalogPath=Join-Path $State 'dependency_catalog.json'
$PlanPath=Join-Path $State 'dependency_plan.json'
New-Item -ItemType Directory -Force -Path $State | Out-Null
function Read-Json([string]$p){ if(Test-Path $p){ Get-Content -LiteralPath $p -Raw | ConvertFrom-Json } }
function Get-Hash([string]$p){ if(Test-Path $p){ (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash } }
function Get-Manifest([string]$Path,[string]$Kind){
  try {
    $j=Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    $deps=@()
    if($j.dependencies){$deps += $j.dependencies.PSObject.Properties | ForEach-Object {[pscustomobject]@{name=$_.Name;range=[string]$_.Value;scope='runtime'}}}
    if($j.devDependencies){$deps += $j.devDependencies.PSObject.Properties | ForEach-Object {[pscustomobject]@{name=$_.Name;range=[string]$_.Value;scope='dev'}}}
    [pscustomobject]@{kind=$Kind;path=$Path;sha256=Get-Hash $Path;name=$j.name;version=$j.version;dependencies=@($deps)}
  } catch { [pscustomobject]@{kind=$Kind;path=$Path;parse_error=$_.Exception.Message} }
}
function Get-Inventory {
  $manifests=@()
  foreach($p in @(Get-ChildItem -LiteralPath $Root -Filter package.json -File -Recurse -ErrorAction SilentlyContinue)){
    if($p.FullName -notmatch '\\node_modules\\|\\.git\\'){ $manifests += Get-Manifest $p.FullName 'npm' }
  }
  foreach($p in @(Get-ChildItem -LiteralPath $Root -Include requirements.txt,pyproject.toml -File -Recurse -ErrorAction SilentlyContinue)){
    if($p.FullName -notmatch '\\venv\\|\\.git\\|\\node_modules\\'){ $manifests += [pscustomobject]@{kind='python';path=$p.FullName;sha256=Get-Hash $p.FullName;name=$null;version=$null;dependencies=@();note='manifest-discovered; package parsing remains read-only'} }
  }
  [ordered]@{
    schema='GRAZYNA_DEPENDENCY_INVENTORY_V1';timestamp=(Get-Date).ToString('o');root=$Root
    package_manifests=@($manifests)
    tools=[ordered]@{node=(Get-Command node -ErrorAction SilentlyContinue).Source;npm=(Get-Command npm -ErrorAction SilentlyContinue).Source;python=(Get-Command python -ErrorAction SilentlyContinue).Source;git=(Get-Command git -ErrorAction SilentlyContinue).Source}
  }
}
$inv=Get-Inventory
if($Action -eq 'Inventory'){$inv|ConvertTo-Json -Depth 12;exit 0}
if($Action -eq 'Catalog'){
  $catalog=[ordered]@{schema='GRAZYNA_DEPENDENCY_CATALOG_V1';generated=$inv.timestamp;root=$Root;source_inventory=$inv.schema;policy=[ordered]@{auto_discover=$true;auto_document=$true;auto_modify_dependency_versions=$false;auto_install_new_packages=$false;ecu_flash_write=$false};manifests=$inv.package_manifests}
  $catalog|ConvertTo-Json -Depth 20|Set-Content -LiteralPath $CatalogPath -Encoding UTF8
  $catalog|ConvertTo-Json -Depth 20;exit 0
}
$catalog=Read-Json $CatalogPath
if(-not $catalog){throw 'CATALOG_MISSING: run Catalog first'}
$actions=@()
foreach($m in @($catalog.manifests)){
  if($m.kind -eq 'npm'){
    $dir=Split-Path $m.path -Parent
    $lock=Join-Path $dir 'package-lock.json'
    if(Test-Path $lock){$actions += [pscustomobject]@{id=('npm-ci-'+[guid]::NewGuid().ToString('N').Substring(0,8));kind='npm';path=$dir;command='npm ci --ignore-scripts';risk='dependency-sync';requires_network=$true}}
  }
}
if($Action -eq 'Plan'){
  $plan=[ordered]@{schema='GRAZYNA_DEPENDENCY_PLAN_V1';plan_id=([guid]::NewGuid().ToString('N'));created=(Get-Date).ToString('o');root=$Root;source_catalog=$CatalogPath;mode='CONTROLLED';actions=@($actions);blocked=@('automatic version selection','automatic package invention','ECU/FLASH','driver installation','MPPS process termination','git pull/merge','Ollama model pull')}
  $plan|ConvertTo-Json -Depth 20|Set-Content -LiteralPath $PlanPath -Encoding UTF8
  $plan|ConvertTo-Json -Depth 20;exit 0
}
if($Action -eq 'Apply'){
  if($Confirm -ne 'GRAZYNA-DEPENDENCY-APPLY'){throw 'CONFIRMATION_REQUIRED: wymagane -Confirm GRAZYNA-DEPENDENCY-APPLY'}
  if(-not $PlanId){throw 'PLAN_ID_REQUIRED'}
  $plan=Read-Json $PlanPath
  if(-not $plan){throw 'PLAN_MISSING'}
  if([string]$plan.root -ne $Root){throw 'ROOT_MISMATCH'}
  if([string]$plan.plan_id -ne $PlanId){throw 'PLAN_MISMATCH'}
  $results=@()
  foreach($a in @($plan.actions)){
    Push-Location $a.path
    try{& npm ci --ignore-scripts 2>&1 | Out-Null;if($LASTEXITCODE -ne 0){throw "npm ci exit=$LASTEXITCODE"};$results += [pscustomobject]@{id=$a.id;status='PASS'}}catch{$results += [pscustomobject]@{id=$a.id;status='FAIL';error=$_.Exception.Message};throw}finally{Pop-Location}
  }
  [ordered]@{schema='GRAZYNA_DEPENDENCY_APPLY_RESULT_V1';status='PASS';plan_id=$PlanId;root=$Root;results=$results}|ConvertTo-Json -Depth 12;exit 0
}

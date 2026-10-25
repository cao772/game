param(
  [ValidateRange(1,5)][int]$Samples=3,
  [ValidateRange(0,5)][int]$IntervalSeconds=1,
  [switch]$SkipGpu
)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path $PSScriptRoot -Parent
$sampleRows=@()
$errors=@()
for($sampleIndex=0;$sampleIndex -lt $Samples;$sampleIndex++) {
  $cpuValue=$null; $freeValue=$null; $totalValue=$null
  try {
    $os=Get-CimInstance Win32_OperatingSystem -OperationTimeoutSec 5
    if($null -ne $os.FreePhysicalMemory){$freeValue=[math]::Round($os.FreePhysicalMemory/1MB,2)}
    if($null -ne $os.TotalVisibleMemorySize){$totalValue=[math]::Round($os.TotalVisibleMemorySize/1MB,2)}
    $cpuRows=@(Get-CimInstance Win32_Processor -OperationTimeoutSec 5)
    $cpuValues=@($cpuRows | Where-Object {$null -ne $_.LoadPercentage} | ForEach-Object {$_.LoadPercentage})
    if($cpuValues.Count -gt 0 -and $cpuValues.Count -eq $cpuRows.Count){$cpuValue=($cpuValues | Measure-Object -Average).Average}
  } catch {$errors += $_.Exception.Message}
  $sampleRows += [pscustomobject]@{utc=(Get-Date).ToUniversalTime().ToString('o');cpuPercent=$cpuValue;freeMemoryGiB=$freeValue;totalMemoryGiB=$totalValue}
  if($sampleIndex -lt $Samples-1 -and $IntervalSeconds -gt 0){Start-Sleep -Seconds $IntervalSeconds}
}
$diskFree=$null
$driveId=[IO.Path]::GetPathRoot($projectRoot).TrimEnd('\')
try {
  $disk=Get-CimInstance Win32_LogicalDisk -OperationTimeoutSec 5 | Where-Object {$_.DeviceID -eq $driveId}
  if($null -ne $disk.FreeSpace){$diskFree=[math]::Round($disk.FreeSpace/1GB,2)}
} catch {$errors += $_.Exception.Message}
$gpu=$null; $gpuStatus='unavailable'
$gpuCommand=Get-Command nvidia-smi -ErrorAction SilentlyContinue
if(-not $SkipGpu -and $gpuCommand) {
  $gpuProcess=New-Object System.Diagnostics.Process
  try {
    $gpuProcess.StartInfo.FileName=$gpuCommand.Source
    $gpuProcess.StartInfo.Arguments='--query-gpu=name,memory.total,memory.used,utilization.gpu --format=csv,noheader'
    $gpuProcess.StartInfo.UseShellExecute=$false
    $gpuProcess.StartInfo.CreateNoWindow=$true
    $gpuProcess.StartInfo.RedirectStandardOutput=$true
    $gpuProcess.StartInfo.RedirectStandardError=$true
    [void]$gpuProcess.Start()
    if($gpuProcess.WaitForExit(5000)) {
      if($gpuProcess.ExitCode -eq 0){$gpu=@($gpuProcess.StandardOutput.ReadToEnd().Trim() -split '\r?\n');$gpuStatus='observed'}
      else {$gpuStatus='failed';$errors += $gpuProcess.StandardError.ReadToEnd()}
    } else {$gpuProcess.Kill();$gpuStatus='timeout'}
  } catch {$errors += $_.Exception.Message} finally {$gpuProcess.Dispose()}
} elseif($SkipGpu){$gpuStatus='skipped'}
$freeMinimum=$null; $cpuAverage=$null
if(@($sampleRows | Where-Object {$null -eq $_.freeMemoryGiB}).Count -eq 0){$freeMinimum=($sampleRows.freeMemoryGiB | Measure-Object -Minimum).Minimum}
if(@($sampleRows | Where-Object {$null -eq $_.cpuPercent}).Count -eq 0){$cpuAverage=[math]::Round(($sampleRows.cpuPercent | Measure-Object -Average).Average,2)}
$decision=if($null -eq $freeMinimum -or $null -eq $cpuAverage -or $null -eq $diskFree){'unknown'}elseif($freeMinimum -lt 4 -or $diskFree -lt 10){'stop_dispatch'}elseif($freeMinimum -lt 6 -or $cpuAverage -gt 85){'reduce'}elseif($freeMinimum -ge 8 -and $diskFree -ge 20 -and $cpuAverage -lt 70){'eligible_for_review'}else{'hold'}
$result=[pscustomobject]@{utc=(Get-Date).ToUniversalTime().ToString('o');samples=$sampleRows;cpuAverage=$cpuAverage;freeMemoryMinGiB=$freeMinimum;diskDrive=$driveId;diskFreeGiB=$diskFree;gpuCsv=$gpu;gpuStatus=$gpuStatus;resourceGate=$decision;errors=$errors;note='Short sample only. Missing CPU/RAM/disk blocks dispatch; GPU does not measure remote model inference.'}
$logDir=Join-Path $PSScriptRoot 'logs'
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$payload=$result | ConvertTo-Json -Depth 6
$latest=Join-Path $logDir 'latest-resource.json'
$temporary=Join-Path $logDir ([guid]::NewGuid().ToString()+'.tmp')
try {
  [IO.File]::WriteAllText($temporary,$payload,(New-Object Text.UTF8Encoding($false)))
  if(Test-Path -LiteralPath $latest){[IO.File]::Replace($temporary,$latest,[NullString]::Value)}else{[IO.File]::Move($temporary,$latest)}
} finally {if(Test-Path -LiteralPath $temporary){Remove-Item -LiteralPath $temporary}}
$result | ConvertTo-Json -Depth 6 -Compress | Add-Content -LiteralPath (Join-Path $logDir 'resources.jsonl') -Encoding utf8
$payload

$path = Join-Path $PSScriptRoot "firebase_defines.json"
if (-not (Test-Path $path)) {
  Write-Host "MISSING: firebase_defines.json"
  exit 1
}
try {
  $cfg = Get-Content -Raw -Encoding UTF8 $path | ConvertFrom-Json
} catch {
  Write-Host "INVALID JSON: firebase_defines.json"
  exit 1
}
$required = @(
  "FIREBASE_ANDROID_API_KEY",
  "FIREBASE_ANDROID_APP_ID",
  "FIREBASE_MESSAGING_SENDER_ID",
  "FIREBASE_PROJECT_ID"
)
$missing = $false
foreach ($key in $required) {
  $value = $cfg.$key
  if ([string]::IsNullOrWhiteSpace([string]$value)) {
    Write-Host "MISSING: $key"
    $missing = $true
  } else {
    Write-Host "OK: $key"
  }
}
if ($missing) { exit 1 }
Write-Host "Firebase mobile configuration looks complete."

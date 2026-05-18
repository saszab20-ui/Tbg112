$ErrorActionPreference = 'Stop'

$workspace = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$tooling = 'C:\Users\badur\Desktop\FitPlanPro\.tooling'
$env:Path = "$tooling\jdk17\bin;$env:Path"
$env:JAVA_HOME = "$tooling\jdk17"

$deps = Join-Path $workspace '.firebase-smoke'
New-Item -ItemType Directory -Force $deps | Out-Null

npm --prefix $deps install --silent @firebase/rules-unit-testing firebase
npx --yes firebase-tools@13.35.1 emulators:exec `
  --project tarnobrzeg-112 `
  --only firestore `
  "node tools/firestore_rules_smoke_test.mjs"

if ((Resolve-Path -LiteralPath $deps -ErrorAction SilentlyContinue).Path.StartsWith($workspace)) {
  Remove-Item -LiteralPath $deps -Recurse -Force
}

$debugLog = Join-Path $workspace 'firestore-debug.log'
if (Test-Path -LiteralPath $debugLog) {
  Remove-Item -LiteralPath $debugLog -Force
}

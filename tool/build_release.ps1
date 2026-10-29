# Builds the Play Store bundle, then checks it for things that must never ship.
#
#   .\tool\build_release.ps1
#
# - Obfuscated (class and function names scrambled). Keep build\symbols: it is the only way to
#   read a crash report from this build. Upload it to Play Console / Crashlytics with the bundle.
# - Built with no test flags: no TEST_SCHOOLS_JSON, no ALLOW_HTTP, so release rules apply
#   (HTTPS only, no log output, no test school list).
# - The signing key comes from android\key.properties, which is kept out of git.

$ErrorActionPreference = 'Stop'

flutter build appbundle --release --obfuscate --split-debug-info=build\symbols
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$bundle = 'build\app\outputs\bundle\release\app-release.aab'
if (-not (Test-Path $bundle)) { Write-Error "Bundle not found: $bundle"; exit 1 }

# A bundle is a zip. Look inside for what must not be there.
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path $bundle))
$problems = @()
try {
    foreach ($entry in $zip.Entries) {
        if ($entry.FullName -match 'test_schools|\.define\.json|key\.properties|\.keystore|\.jks') {
            $problems += "forbidden file in bundle: $($entry.FullName)"
            continue
        }
        # Search text-like and compiled app entries for private addresses.
        if ($entry.Length -gt 0 -and $entry.FullName -match 'flutter_assets|libapp\.so|\.json$|\.xml$') {
            $reader = New-Object System.IO.StreamReader($entry.Open(), [System.Text.Encoding]::Latin1)
            $text = $reader.ReadToEnd(); $reader.Close()
            if ($text -match '(?<![0-9])(10\.0\.0\.\d+|192\.168\.\d+\.\d+|127\.0\.0\.1)(?![0-9])') {
                $problems += "private address '$($Matches[1])' found in: $($entry.FullName)"
            }
        }
    }
} finally { $zip.Dispose() }

if ($problems.Count -gt 0) {
    $problems | ForEach-Object { Write-Host "  PROBLEM: $_" -ForegroundColor Red }
    Write-Error 'The bundle contains things that must not ship. Do not upload it.'
    exit 1
}
Write-Host "OK: $bundle has no test list, no private addresses, no keys." -ForegroundColor Green
Write-Host 'Keep build\symbols with this release.'

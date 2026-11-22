param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^emulator-[0-9]+$')]
    [string]$Serial,
    [string]$ApkPath = "$PSScriptRoot/../build/app/outputs/flutter-apk/app-release.apk",
    [string]$AdbPath = 'adb'
)

$ErrorActionPreference = 'Stop'
$packageName = 'com.selfcheck.selfcheck_jibun_check'
if ((& $AdbPath -s $Serial shell getprop ro.kernel.qemu).Trim() -ne '1') {
    throw 'This probe is restricted to an Android emulator.'
}
if (-not (Test-Path -LiteralPath $ApkPath -PathType Leaf)) {
    throw 'Build the release APK with tool/recognition_native_smoke.dart first.'
}
& $AdbPath -s $Serial install -r (Resolve-Path -LiteralPath $ApkPath).Path
if ($LASTEXITCODE -ne 0) {
    throw 'Probe installation failed. Use a dedicated emulator with the same signing key.'
}
& $AdbPath -s $Serial shell am force-stop $packageName
& $AdbPath -s $Serial shell am start -n "$packageName/.MainActivity"
if ($LASTEXITCODE -ne 0) { throw 'Probe launch failed.' }

$deadline = [DateTime]::UtcNow.AddSeconds(30)
while ([DateTime]::UtcNow -lt $deadline) {
    $smokeProcessId = ([string](& $AdbPath -s $Serial shell pidof -s $packageName)).Trim()
    if ($smokeProcessId -match '^[0-9]+$') {
        $logs = & $AdbPath -s $Serial logcat -d "--pid=$smokeProcessId" -s flutter:I
        if ($logs -match 'SELFCHECK_NATIVE_SMOKE FAIL') {
            $logs | Select-String 'SELFCHECK_NATIVE_SMOKE' | Write-Output
            throw 'Native recognition failed in the release build.'
        }
        if ($logs -match 'SELFCHECK_NATIVE_SMOKE ALL_PASS') {
            $logs | Select-String 'SELFCHECK_NATIVE_SMOKE' | Write-Output
            exit 0
        }
    }
    Start-Sleep -Milliseconds 500
}
throw 'Probe timed out. Confirm the APK uses tool/recognition_native_smoke.dart.'

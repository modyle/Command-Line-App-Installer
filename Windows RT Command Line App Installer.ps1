$scriptName = "Command-Line-App-Installer.bat"
$url = "https://modyle.github.io/Command-Line-App-Installer/Command-Line-App-Installer.bat"
$workDir = Join-Path $env:LOCALAPPDATA "WinRTInstaller"

if (-not (Test-Path $workDir)) {
    New-Item -ItemType Directory -Path $workDir -Force | Out-Null
}

$tempPath = Join-Path $workDir $scriptName

Write-Host "--- Command Line App Installer v1.0 ---" -ForegroundColor Cyan
Write-Host "[*] Downloading components..." -ForegroundColor Gray

try {
    $webClient = New-Object System.Net.WebClient
    $webClient.DownloadFile($url, $tempPath)

    Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$tempPath`"" -Wait
}
catch {
    Write-Host "[!] Error: $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    Write-Host "[+] Session closed." -ForegroundColor Green
}
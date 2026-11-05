# Menyalakan server TARA dan membukanya ke internet lewat ngrok, supaya tester bisa memakai aplikasi
# dari HP dan jaringan mereka sendiri.
#
# Pakai (dari PowerShell, di folder ini):
#   .\jalankan_tara.ps1 -Domain nama-anda.ngrok-free.app
#
# Sebelum pertama kali:
#   1. Daftar di https://dashboard.ngrok.com (gratis).
#   2. Jalankan sekali:  ngrok config add-authtoken <token dari dashboard>
#   3. Ambil alamat tetap gratis di menu Domains, lalu pakai sebagai -Domain.
#
# Selama tester memakai aplikasi, laptop, jendela server, dan jendela ini harus tetap menyala.
# Laragon (MySQL) juga harus sudah jalan.

param(
  [Parameter(Mandatory = $true)][string]$Domain,
  [int]$Port = 5000
)

$Domain = $Domain -replace '^https?://', '' -replace '/+$', ''
$backend = Join-Path $PSScriptRoot 'backend\node_backend'

# Server dijalankan di jendela terpisah. TRUST_PROXY membuat pembatas percobaan login menghitung
# tiap tester sendiri-sendiri, bukan sebagai satu alamat ngrok.
Start-Process powershell -ArgumentList @(
  '-NoExit', '-Command',
  "`$env:TRUST_PROXY = '1'; Set-Location '$backend'; node index.js"
)

Write-Host "Menunggu server di port $Port ..."
foreach ($attempt in 1..30) {
  try {
    Invoke-WebRequest -Uri "http://127.0.0.1:$Port/health" -UseBasicParsing -TimeoutSec 2 | Out-Null
    break
  } catch {
    Start-Sleep -Seconds 1
  }
}

Write-Host ''
Write-Host "Alamat untuk aplikasi dan tester : https://$Domain"
Write-Host "Panel admin                     : https://$Domain/admin"
Write-Host 'Tekan Ctrl+C di jendela ini untuk menutup akses dari internet.'
Write-Host ''

# Terminal yang dibuka sebelum ngrok dipasang belum mengenali perintah "ngrok", jadi dicari juga di tempat pasangnya.
$ngrok = (Get-Command ngrok -ErrorAction SilentlyContinue).Source
if (-not $ngrok) { $ngrok = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links\ngrok.exe' }
if (-not (Test-Path $ngrok)) {
  Write-Host 'ngrok tidak ditemukan. Pasang dengan: winget install Ngrok.Ngrok' -ForegroundColor Red
  exit 1
}

# ngrok lama memakai --domain, ngrok baru memakai --url.
$flag = if ((& $ngrok http --help 2>&1 | Out-String) -match '--url') { "--url=https://$Domain" } else { "--domain=$Domain" }
& $ngrok http $flag $Port

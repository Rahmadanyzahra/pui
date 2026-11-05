# Membangun APK TARA dengan alamat server yang sudah ditanam, supaya tester cukup memasang lalu daftar
# tanpa membuka "Pengaturan server".
#
# Pakai (dari PowerShell, di folder ini):
#   .\bangun_apk.ps1 -Server https://nama-anda.ngrok-free.app
#
# Hasilnya: dist\tara-android.apk  (berkas inilah yang diunggah ke Google Drive).

param(
  [Parameter(Mandatory = $true)][string]$Server
)

$Server = $Server.TrimEnd('/')
if ($Server -notmatch '^https://') {
  Write-Host 'Alamat server harus diawali https:// agar data tester terenkripsi.' -ForegroundColor Red
  exit 1
}

Set-Location $PSScriptRoot
$log = Join-Path $env:TEMP 'tara_build.log'
$built = $false
# Build kadang gagal sementara di mesin ini, jadi dicoba sampai tiga kali.
foreach ($attempt in 1..3) {
  flutter build apk --release --target-platform android-arm64 "--dart-define=TARA_SERVER_URL=$Server" *> $log
  if (Select-String -Path $log -Pattern 'Built build' -Quiet) { $built = $true; break }
  Write-Host "Percobaan $attempt gagal, mengulang ..."
}
if (-not $built) {
  Write-Host "Build gagal. Lihat $log" -ForegroundColor Red
  exit 1
}

New-Item -ItemType Directory -Force -Path dist | Out-Null
Copy-Item build\app\outputs\flutter-apk\app-release.apk dist\tara-android.apk -Force
Write-Host "Selesai: dist\tara-android.apk  (server: $Server)" -ForegroundColor Green

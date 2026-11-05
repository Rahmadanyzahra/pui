# Membangun TARA versi web dan menaruhnya di server, sehingga bisa dibuka lewat browser di
#   https://<alamat-server>/app/
# dari laptop maupun iPhone.
#
# Pakai (dari PowerShell, di folder ini):
#   .\bangun_web.ps1
#
# Folder web\ di proyek ini sudah dipakai aplikasi web admin lama, jadi versi web TARA dibangun di
# folder kerja terpisah (build\web_staging) yang berisi salinan kode aplikasi.

Set-Location $PSScriptRoot
$stage = Join-Path $PSScriptRoot 'build\web_staging'
$target = Join-Path $PSScriptRoot 'backend\node_backend\public\app'

if (-not (Test-Path (Join-Path $stage 'web\index.html'))) {
  New-Item -ItemType Directory -Force -Path $stage | Out-Null
  flutter create --platforms=web --project-name patara_ai $stage | Out-Null
}

# Salin kode dan aset terbaru ke folder kerja.
robocopy (Join-Path $PSScriptRoot 'lib') (Join-Path $stage 'lib') /MIR /NFL /NDL /NJH /NJS | Out-Null
robocopy (Join-Path $PSScriptRoot 'asset') (Join-Path $stage 'asset') /MIR /NFL /NDL /NJH /NJS | Out-Null
Copy-Item pubspec.yaml, pubspec.lock, analysis_options.yaml -Destination $stage -Force
Remove-Item (Join-Path $stage 'test') -Recurse -Force -ErrorAction SilentlyContinue

# Judul dan nama aplikasi di tab browser.
$index = Join-Path $stage 'web\index.html'
(Get-Content $index -Raw) -replace '<title>.*?</title>', '<title>TARA</title>' -replace 'content="patara_ai"', 'content="TARA"' | Set-Content $index -Encoding utf8
$manifest = Join-Path $stage 'web\manifest.json'
(Get-Content $manifest -Raw) -replace '"name": "patara_ai"', '"name": "TARA"' -replace '"short_name": "patara_ai"', '"short_name": "TARA"' | Set-Content $manifest -Encoding utf8

Push-Location $stage
$log = Join-Path $env:TEMP 'tara_web_build.log'
# --no-web-resources-cdn: mesin gambar Flutter ikut dibundel, tidak diambil dari server Google saat dibuka.
flutter pub get *> $log
flutter build web --release --base-href /app/ --no-web-resources-cdn --no-wasm-dry-run *>> $log
$built = Test-Path 'build\web\main.dart.js'
Pop-Location
if (-not $built) {
  Write-Host "Build web gagal. Lihat $log" -ForegroundColor Red
  exit 1
}

robocopy (Join-Path $stage 'build\web') $target /MIR /NFL /NDL /NJH /NJS | Out-Null
Write-Host "Selesai. Versi web ada di $target" -ForegroundColor Green
Write-Host 'Buka lewat  https://<alamat-server>/app/  (server harus dinyalakan ulang bila baru pertama kali).'

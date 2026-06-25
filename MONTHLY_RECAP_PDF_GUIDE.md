# Monthly Recap PDF Download Feature

## 📋 Deskripsi Fitur
Fitur baru ini memungkinkan orang tua untuk mendownload rekap aktivitas bulanan anak dalam format PDF yang profesional dan mudah dibaca.

## ✨ Fitur-Fitur

### 1. **Laporan PDF Bulanan**
- Berisi data aktivitas selama sebulan penuh
- Format profesional dengan header, statistik, dan tabel
- Informasi anak dan orang tua

### 2. **Statistik Komprehensif**
- Total aktivitas (bulan + semua)
- Aktivitas minggu ini
- Tingkat konsistensi (%)
- Hari aktif (minggu ini)
- Aktivitas utama

### 3. **Breakdown Jenis Aktivitas**
- Daftar semua jenis aktivitas dengan jumlah
- Persentase untuk setiap jenis
- Diurutkan dari yang paling banyak

### 4. **Data Mingguan**
- Aktivitas per hari (Senin-Minggu)
- Visualisasi mudah dibaca dalam tabel

## 🔌 API Endpoint

### Download Monthly Recap PDF
```
GET /analytics/child/<child_id>/monthly-recap-pdf
```

**Headers yang Diperlukan:**
- `Authorization: Bearer <token>` (atau cookie `session_token`)

**Response:**
- Content-Type: `application/pdf`
- File: `Rekap_[ChildName]_[YYYY MM].pdf`

**Contoh:**
```bash
curl -H "Authorization: Bearer YOUR_TOKEN" \
  http://localhost:5000/analytics/child/123/monthly-recap-pdf \
  -o rekap.pdf
```

## 🛠️ Instalasi & Konfigurasi (Node.js)

The PDF generation for monthly recaps is handled by the active Node.js backend in `backend/node_backend`. There are no Python prerequisites for the current runtime. To set up the backend:

```bash
cd backend/node_backend
npm install
# development
npm run dev
# or production
npm start
```

Environment variables for SMTP and other settings are read from `.env` in `backend/node_backend` (see `.env.example`).

## 📊 Struktur PDF

```
┌─────────────────────────────────────────┐
│   LAPORAN BULANAN AKTIVITAS [NAMA ANAK] │
│          Periode: [BULAN TAHUN]         │
├─────────────────────────────────────────┤
│ INFORMASI ANAK                          │
│  - Nama Anak                            │
│  - Usia                                 │
│  - Orang Tua (Email)                    │
├─────────────────────────────────────────┤
│ RINGKASAN STATISTIK BULANAN             │
│  - Total Aktivitas (Bulan)              │
│  - Total Aktivitas (Semua)              │
│  - Aktivitas Minggu Ini                 │
│  - Konsistensi (%)                      │
│  - Hari Aktif                           │
│  - Aktivitas Utama                      │
├─────────────────────────────────────────┤
│ JENIS AKTIVITAS                         │
│  [Tabel dengan breakdown aktivitas]     │
├─────────────────────────────────────────┤
│ AKTIVITAS PER HARI (MINGGU INI)         │
│  [Tabel dengan data mingguan]           │
├─────────────────────────────────────────┤
│ Dibuat pada: [TANGGAL WAKTU]            │
└─────────────────────────────────────────┘
```

## 🎨 Styling PDF

- **Warna Header**: #2c3e50 (Dark blue-gray)
- **Warna Heading**: #34495e (Medium blue-gray)
- **Background Tabel**: #ecf0f1 (Light gray)
- **Tabel Statistik**: Green background (#d5f4e6)
- **Table Header**: Blue (#3498db) dan Green (#27ae60)

## 🚀 Contoh Penggunaan

### Frontend (JavaScript/TypeScript)
```javascript
// Download PDF untuk child dengan ID 123
async function downloadMonthlyRecap(childId) {
  try {
    const response = await fetch(
      `/analytics/child/${childId}/monthly-recap-pdf`,
      {
        headers: {
          'Authorization': `Bearer ${getToken()}`
        }
      }
    );
    
    if (!response.ok) throw new Error('Failed to generate PDF');
    
    // Create blob and download
    const blob = await response.blob();
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `rekap_${childId}_${new Date().toISOString().split('T')[0]}.pdf`;
    document.body.appendChild(a);
    a.click();
    window.URL.revokeObjectURL(url);
  } catch (error) {
    console.error('Error:', error);
  }
}
```

### Flutter Example
```dart
Future<void> downloadMonthlyRecap(int childId) async {
  try {
    final response = await http.get(
      Uri.parse('http://localhost:5000/analytics/child/$childId/monthly-recap-pdf'),
      headers: {
        'Authorization': 'Bearer ${getToken()}',
      },
    );
    
    if (response.statusCode == 200) {
      // Simpan file PDF
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/rekap_$childId.pdf');
      await file.writeAsBytes(response.bodyBytes);
      // Open file atau share
    }
  } catch (e) {
    print('Error: $e');
  }
}
```

## ⚙️ Konfigurasi Lanjutan

### Error Handling
If PDF generation fails, the Node backend returns a 500 with an error message. Check `backend/node_backend` logs and ensure required environment variables are set.

### Batasan
- PDF dihasilkan on-the-fly (tidak disimpan)
- Maksimal 500 aktivitas per child yang diproses
- Format PDF selalu A4

## 📝 Modifikasi Kode

Fungsi utama yang ditambahkan:

1. **`_generate_monthly_recap_pdf(user_data, child_data, menu_data) -> BytesIO | None`**
   - Generates PDF document
   - Returns BytesIO buffer atau None jika error

2. **`GET /analytics/child/<int:child_id>/monthly-recap-pdf`**
   - Endpoint untuk download
   - Requires authentication
   - Returns PDF file attachment

## 🔍 Testing

### Manual Test dengan cURL
```bash
# 1. Login dulu
curl -X POST http://localhost:5000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"parent@example.com","password":"password"}'

# 2. Copy token dari response
# 3. Download PDF
curl -H "Authorization: Bearer TOKEN_DARI_STEP_2" \
  http://localhost:5000/analytics/child/1/monthly-recap-pdf \
  -o rekap.pdf
```

## 📦 File yang Dimodifikasi / Active

The active implementation is in `backend/node_backend`:

1. `backend/node_backend/index.js` — main Express app and PDF generation
2. `backend/node_backend/smoke_test.js` — smoke tests for endpoints
3. `backend/node_backend/package.json` — dependencies and scripts

## 🐛 Troubleshooting

### PDF kosong/tidak ada konten
- Pastikan ada aktivitas untuk child tersebut
- Check logs di `backend/node_backend` untuk error detail

### Error saat menghasilkan PDF
1. Pastikan Node backend berjalan: `cd backend/node_backend && npm run dev`
2. Periksa logs pada server Node
3. Pastikan env vars di `backend/node_backend/.env` sudah diisi

### File terlalu besar
- Reduce activity limit dalam `_list_activity_records()`
- Default: 500 activities

## 🔐 Keamanan

- ✅ Requires authentication (`@require_auth`)
- ✅ Only parent can download their own child's data
- ✅ User reference validation

## 📈 Next Steps (Optional)

Fitur yang bisa ditambahkan:
1. **Email Delivery**: Kirim PDF via email otomatis
2. **Monthly Auto-Generate**: Generate PDF otomatis setiap bulan
3. **Excel Export**: Tambah export ke format Excel
4. **Custom Date Range**: Pilih periode custom, bukan hanya bulan saat ini
5. **Multiple Children**: Download recap untuk multiple children sekaligus

---

**Dibuat pada**: May 2026
**Version**: 1.0

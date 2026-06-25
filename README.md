# patara_ai

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Backend Lokal (Node.js)

Project ini sekarang memakai backend Node.js/Express sebagai satu-satunya backend aktif.

Endpoint utama yang tersedia:

- `GET /health`
- `POST /api/register`
- `POST /api/login`
- `GET /api/me`
- `POST /api/logout`
- `GET /children`
- `POST /children`
- `GET /activities`
- `POST /activities`
- `POST /growth/record`
- `GET /growth/records/<child_id>`
- `GET /nutrition/foods`
- `POST /nutrition/food-intake`
- `GET /nutrition/daily-analysis/<child_id>/<date>`
- `GET /analytics/parent`
- `GET /analytics/child/<child_id>`
- `POST /notifications/email-preferences`
- `GET /notifications/email-preferences`
- `POST /invites/redeem`
- `POST /tokens/generate`
- `POST /tokens/connect`
- `GET /tokens/list`
- `GET /tokens/status`
- `POST /ai/chat`

File backend ada di:

- `backend/node_backend/index.js`
- `backend/node_backend/db.js`
- `backend/node_backend/db_mysql.js`

### Jalankan Backend Node

```powershell
cd backend/node_backend
npm install
npm run dev
```

Backend default jalan di `http://127.0.0.1:5000`.

### MySQL / XAMPP

Untuk MySQL, set `USE_MYSQL=1` dan isi `MYSQL_*` di `backend/node_backend/.env`.
Schema MySQL ada di `backend/node_backend/migrations/schema_mysql.sql`.

### Status Flask

Backend Flask lama sudah dihapus dari folder `backend/`. Gunakan backend Node di `backend/node_backend`.

## Jalankan Flutter Mobile dan Web

### Android Emulator

Backend URL yang dipakai aplikasi:

- `http://10.0.2.2:5000`

### Web

Backend URL yang dipakai aplikasi:

- `http://127.0.0.1:5000`

Jalankan web:

```powershell
flutter run -d chrome
```

Catatan:

- Service backend di Flutter sudah mendukung token auth (`Authorization: Bearer ...`) untuk web.
- CORS sudah diaktifkan di backend supaya request dari Flutter Web bisa akses endpoint GET/POST.

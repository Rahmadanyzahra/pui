# Patara AI Backend (Node.js Only)

Status: backend utama sekarang full Node.js/Express di folder `backend/node_backend`.

## Struktur

```
backend/
├── node_backend/
│   ├── index.js
│   ├── db.js
│   ├── db_mysql.js
│   ├── package.json
│   ├── TESTING.md
│   └── README.md
└── patara_backend.db
```

## Jalankan (Laragon + MySQL)

```powershell
cd backend/node_backend
npm install
node import_schema_mysql_v2.js
npm run dev
```

Default server: `http://127.0.0.1:5000`

## Endpoint Utama

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
- `GET /growth/records/:child_id`
- `GET /nutrition/foods`
- `POST /nutrition/food-intake`
- `GET /nutrition/daily-analysis/:child_id/:date`
- `GET /analytics/parent`
- `GET /analytics/child/:child_id`
- `POST /notifications/email-preferences`
- `GET /notifications/email-preferences`
- `POST /invites/redeem`
- `POST /tokens/generate`
- `POST /tokens/connect`
- `GET /tokens/list`
- `GET /tokens/status`
- `POST /ai/chat`

## Catatan

- Backend Python/Flask lama sudah dicabut dari folder ini.
- Referensi operasional backend ada di `backend/node_backend/README.md` dan `backend/node_backend/TESTING.md`.

## 🎉 What's Working

✅ Growth tracking with WHO standards
✅ Nutrition monitoring with validation
✅ Automated weekly recaps (every 7 days)
✅ Email notifications to parents
✅ Enhanced login with captcha
✅ Complete test coverage
✅ Full documentation

## 📈 Version History

**Phase 2** (Current)
- Growth tracking (WHO standards)
- Nutrition monitoring (20+ foods)
- Weekly automated recaps
- Email notifications
- Captcha security

**Phase 1** (Previous)
- Monthly PDF recaps
- Monthly analytics
- Monthly tracking

---

**Ready for production deployment!** 🎯

For questions, see the comprehensive documentation files in this directory.

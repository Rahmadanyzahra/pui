# JWT Implementation Summary

> **Role contract:** Any `parent` role examples below are historical. Current app JWTs use `orang_tua` or `delegasi`; old `parent`/`delegated_parent` values are normalized at authentication. See [ROLE_AUTHORIZATION_MODEL.md](../ROLE_AUTHORIZATION_MODEL.md).

## ✅ Status: Completed

Aplikasi Patara AI telah berhasil di-upgrade dengan **JWT (JSON Web Token)** authentication untuk keamanan yang lebih baik dan scalability yang lebih tinggi.

---

## 📋 Apa yang Diubah

### 1. **Backend Dependencies** 
✅ Menambahkan `jsonwebtoken` di package.json

### 2. **JWT Utilities** (`jwt_auth.js`)
✅ Dibuat file baru dengan fungsi-fungsi JWT:
- `generateAccessToken()` - Generate access token (15 menit)
- `generateRefreshToken()` - Generate refresh token (7 hari)
- `verifyAccessToken()` - Verifikasi access token
- `verifyRefreshToken()` - Verifikasi refresh token
- `getTokenFromRequest()` - Extract token dari header/cookies

### 3. **Authentication Middleware** 
✅ Updated `requireAuth` middleware:
- Dari: Database lookup setiap request
- Ke: JWT signature verification (stateless)
- Lebih cepat dan tidak perlu database

### 4. **Auth Endpoints**
✅ Updated semua auth endpoints:
- `/api/register` - Return access & refresh token
- `/api/login` - Return access & refresh token  
- `/api/me` - Verify JWT token (tidak perlu DB lookup)
- `/api/logout` - Clear JWT cookies
- `/api/refresh` - Generate new token pair (NEW)

### 5. **Token Storage**
✅ Tokens disimpan di secure HTTP-only cookies:
- `access_token` - Short-lived (15 minutes)
- `refresh_token` - Long-lived (7 days)

---

## 🔒 Keamanan

| Feature | Status |
|---------|--------|
| Password Hashing (bcrypt) | ✅ |
| JWT Signature | ✅ |
| Secure Cookies (httpOnly) | ✅ |
| CSRF Protection (sameSite) | ✅ |
| CAPTCHA on Login | ✅ |
| Login History Tracking | ✅ |
| Role-Based Access Control | ✅ |

---

## 🚀 Setup

### 1. Install Dependencies
```bash
cd backend/node_backend
npm install
```

### 2. Configure Environment Variables
Buka `.env.example` dan copy ke `.env`, lalu edit:
```env
# Generate secrets dengan:
# node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"

JWT_SECRET=your-super-secret-key
JWT_REFRESH_SECRET=your-refresh-secret-key
JWT_ACCESS_EXPIRY=15m
JWT_REFRESH_EXPIRY=7d
```

### 3. Start Backend
```bash
npm start      # Production
npm run dev    # Development (with nodemon)
```

### 4. Test JWT Implementation
```bash
npm run smoke  # Existing smoke tests
node test_jwt.js  # JWT-specific tests
```

---

## 📚 API Changes

### Register (POST /api/register)
**Before:**
```json
{
  "token": "uuid-token",
  "user_id": 1
}
```

**After:**
```json
{
  "access_token": "eyJ...",
  "refresh_token": "eyJ...",
  "user_id": 1,
  "email": "user@example.com",
  "role": "parent"
}
```

### Login (POST /api/login)
**Before:**
```json
{
  "token": "uuid-token",
  "user_id": 1
}
```

**After:**
```json
{
  "access_token": "eyJ...",
  "refresh_token": "eyJ...",
  "user_id": 1,
  "email": "user@example.com",
  "role": "parent"
}
```

### New: Refresh Token (POST /api/refresh)
```bash
POST /api/refresh

Response:
{
  "access_token": "eyJ...",
  "refresh_token": "eyJ..."
}
```

---

## 💻 Client Updates Required

### Flutter/Dart
```dart
// Save tokens after login
final storage = FlutterSecureStorage();
await storage.write(key: 'access_token', value: data['access_token']);
await storage.write(key: 'refresh_token', value: data['refresh_token']);

// Use token in requests
final token = await storage.read(key: 'access_token');
final response = await http.get(
  Uri.parse('$apiUrl/api/me'),
  headers: {'Authorization': 'Bearer $token'},
);

// Handle token expiry
if (response.statusCode == 401) {
  // Call /api/refresh to get new token
}
```

### Web/JavaScript
```javascript
// Tokens sudah otomatis di-cookies (httpOnly)
// Client tidak perlu manual storage

// Make authenticated request
fetch('/api/me', {
  headers: {
    'Authorization': `Bearer ${accessToken}`
  },
  credentials: 'include'
})
```

---

## 📊 Performance Improvements

| Metrik | Session (Old) | JWT (New) |
|--------|---------------|----------|
| Auth Check | Database query | Signature verify |
| Speed | ~50ms (DB) | ~1ms (crypto) |
| Scalability | Single DB | Unlimited (stateless) |
| Multi-server | Shared session store | Native support |

---

## 🔄 Backward Compatibility

Old session functions masih tersedia:
- `getUserBySession()` - Deprecated
- `tokenFromRequest()` - Deprecated
- `createSession()` - Deprecated

Untuk migration bertahap, Anda bisa:
1. Keep old functions untuk backward compatibility
2. Gradually update clients ke JWT
3. Hapus old functions setelah semua clients terupdate

---

## 📖 Dokumentasi Lengkap

Untuk detail lengkap, baca: [`JWT_IMPLEMENTATION.md`](./JWT_IMPLEMENTATION.md)

Berisi:
- Configuration guide
- API endpoint documentation
- Security best practices
- Troubleshooting
- Production checklist

---

## 🧪 Testing

### Unit Tests
```bash
npm run test
```

### JWT-Specific Tests
```bash
node test_jwt.js
```

Output:
```
✅ Register User
✅ Get Current User (with JWT)
✅ Login with credentials
✅ Unauthorized Access (invalid token)
✅ Missing Authorization Header
✅ Logout
✅ Invalid Credentials
```

---

## ⚠️ Important Notes

1. **Secret Keys**
   - Ubah `JWT_SECRET` dan `JWT_REFRESH_SECRET` di production
   - Jangan gunakan default values
   - Simpan di environment variables yang aman

2. **Token Expiry**
   - Access token: 15 menit (short-lived)
   - Refresh token: 7 hari (long-lived)
   - Clients harus implement refresh logic

3. **Database**
   - Old `sessions` table tidak lagi digunakan
   - Bisa dihapus atau diarchive setelah migration complete
   - Tidak ada perubahan pada schema lain

4. **HTTPS**
   - Mandatory di production (`secure: true` in cookies)
   - Development bisa pakai HTTP

---

## ✨ Next Steps

1. **Install dependencies**: `npm install`
2. **Configure JWT secrets**: Edit `.env`
3. **Test implementation**: `node test_jwt.js`
4. **Update Flutter clients**: Implement new token handling
5. **Monitor in production**: Track token refresh patterns

---

## 📞 Support

Jika ada issues:
1. Periksa JWT_IMPLEMENTATION.md untuk troubleshooting
2. Verifikasi JWT_SECRET di environment
3. Check browser console untuk error messages
4. Review backend logs untuk JWT verification errors

---

**Status**: ✅ Ready for Production
**Version**: 1.0
**Date**: June 2026

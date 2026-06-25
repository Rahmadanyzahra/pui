# Login History API Documentation

## Overview
Admin users can now view and manage user login history through new backend endpoints.

## New Endpoints

### 1. Get User Login History
**GET** `/admin/users/<user_id>/login-history`

Retrieves the login history for a specific user.

**Requirements:**
- Admin role
- Valid authentication token

**Parameters:**
- `user_id` (path): User ID to retrieve login history for

**Response (200 OK):**
```json
{
  "user_id": 1,
  "email": "user@example.com",
  "login_history_count": 5,
  "login_history": [
    {
      "id": 1,
      "user_id": 1,
      "email": "user@example.com",
      "ip_address": "192.168.1.1",
      "user_agent": "Mozilla/5.0...",
      "login_time": "2026-05-06T10:30:45Z"
    },
    ...
  ]
}
```

**Error Response (404):**
```json
{
  "error": "User tidak ditemukan"
}
```

---

### 2. Delete User Login History
**DELETE** `/admin/users/<user_id>/login-history`

Deletes all login records for a specific user. This action is irreversible.

**Requirements:**
- Admin role
- Valid authentication token

**Parameters:**
- `user_id` (path): User ID to delete login history for

**Response (200 OK):**
```json
{
  "message": "Riwayat login berhasil dihapus",
  "user_id": 1,
  "email": "user@example.com",
  "deleted_count": 5
}
```

**Error Response (404):**
```json
{
  "error": "User tidak ditemukan"
}
```

---

## Features

✅ **Track Login Details** - Records timestamp, IP address, user agent for each login
✅ **Admin View** - Admins can view login history for any user
✅ **Admin Delete** - Admins can delete login history to clean user records
✅ **Dual Backend Support** - Works with both SQLite and Firestore
✅ **Security** - Requires admin role for all operations

## Login History Data Captured

When a user logs in successfully, the system records:
- **User ID** - Internal user identifier
- **Email** - User's email address
- **IP Address** - Remote IP address of login request
- **User Agent** - Browser/client information
- **Login Time** - ISO 8601 timestamp (UTC)

## Usage Examples

### Get Login History (cURL)
```bash
curl -X GET \
  'http://localhost:5000/admin/users/1/login-history' \
  -H 'Authorization: Bearer YOUR_TOKEN' \
  -H 'Content-Type: application/json'
```

### Delete Login History (cURL)
```bash
curl -X DELETE \
  'http://localhost:5000/admin/users/1/login-history' \
  -H 'Authorization: Bearer YOUR_TOKEN' \
  -H 'Content-Type: application/json'
```

### Get Login History (JavaScript)
```javascript
async function getUserLoginHistory(userId, authToken) {
  const response = await fetch(`/admin/users/${userId}/login-history`, {
    method: 'GET',
    headers: {
      'Authorization': `Bearer ${authToken}`,
      'Content-Type': 'application/json'
    }
  });
  return response.json();
}

async function deleteUserLoginHistory(userId, authToken) {
  const response = await fetch(`/admin/users/${userId}/login-history`, {
    method: 'DELETE',
    headers: {
      'Authorization': `Bearer ${authToken}`,
      'Content-Type': 'application/json'
    }
  });
  return response.json();
}
```

## Database Schema

### SQLite
```sql
CREATE TABLE login_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  email TEXT,
  ip_address TEXT,
  user_agent TEXT,
  login_time TEXT NOT NULL,
  FOREIGN KEY(user_id) REFERENCES users(id)
)
```

### Firestore
```
Collection: login_history
Document Fields:
  - id: number
  - user_id: number
  - email: string
  - ip_address: string
  - user_agent: string
  - login_time: string (ISO 8601)
```

## Notes

- Login history is recorded automatically when users successfully authenticate
- Firebase/Google authentication logins are NOT tracked (only local email/password logins)
- Maximum 100 records per user are returned in a single request
- Deleting login history is irreversible and may affect audit logs
- All operations require admin privileges

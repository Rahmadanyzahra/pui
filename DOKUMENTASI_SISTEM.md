# 📱 PATARA AI - DOKUMENTASI SISTEM

## 📌 Daftar Isi
1. [Ikhtisar Aplikasi](#ikhtisar-aplikasi)
2. [Fitur Utama](#fitur-utama)
3. [Arsitektur Sistem](#arsitektur-sistem)
4. [Alur Pengguna](#alur-pengguna)
5. [Struktur Database](#struktur-database)
6. [Teknologi & Stack](#teknologi--stack)

---

## 🎯 Ikhtisar Aplikasi

**PATARA AI** adalah aplikasi mobile Flutter untuk **tracking & monitoring perkembangan anak** dengan fitur AI-powered insights. Aplikasi mendukung 3 kategori usia anak:

| Kategori | Usia | Fitur |
|----------|------|-------|
| **Baby** | 0-1 tahun | Sleep, feeding, diaper tracking, immunization |
| **Toddler** | 1-2 tahun | Behavior, language, potty training, play ideas |
| **Balita** | 2-5 tahun | Developmental monitoring, social skills, daily routines |

### Peran Pengguna:
- **Parent**: Mengelola profil anak, monitoring real-time, melihat reports & analytics
- **Child**: Mengakses dashboard personal, tracking aktivitas harian

---

## ✨ Fitur Utama

### 1️⃣ **Authentication & Role Management**
- Firebase Auth (email/password, phone auth)
- Role selection: Parent atau Child
- Profile setup dengan avatar

### 2️⃣ **Dashboard Real-Time**
- Live status untuk setiap anak
- Real-time database untuk instant updates
- Kategori usia: baby, toddler, balita

### 3️⃣ **Activity Tracking**
- Tracking aktivitas harian per kategori usia
- Data saved to Firestore: `tracking/{uid}/{category}/{yyyy-mm-dd}`
- Activity types: sleep, feeding, behavior, learning, mood, etc

### 4️⃣ **Parent Dashboard**
- Unified view semua anak
- Statistics & analytics
- Development reports
- Insights & recommendations

### 5️⃣ **AI Features**
- Parenting recommendations
- Child development insights
- Smart notifications

### 6️⃣ **Gamification**
- Points system
- Badges & achievements
- Reward tracking

### 7️⃣ **Analytics & Reports**
- Daily/weekly/monthly summaries
- Development progress charts
- Milestone tracking
- Screen time monitoring

### 8️⃣ **Push Notifications**
- Milestone alerts
- Appointment reminders
- Activity reminders

---

## 🏗️ Arsitektur Sistem

```
┌─────────────────────────────────────────────────────┐
│                   PATARA AI APP                      │
│                  (Flutter Mobile)                    │
└─────────────────────────────────────────────────────┘
                        ↓
        ┌───────────────┬───────────────┬──────────────┐
        ↓               ↓               ↓              ↓
    ┌────────┐    ┌──────────┐    ┌─────────┐  ┌──────────┐
    │Firebase│    │ Backend  │    │ Local   │  │Analytics │
    │Auth    │    │ API      │    │Storage  │  │Services  │
    └────────┘    └──────────┘    └─────────┘  └──────────┘
        ↓               ↓               ↓              ↓
    ┌─────────────────────────────────────────────────────┐
    │           Firebase Cloud Services                    │
    ├─────────────────────────────────────────────────────┤
    │ • Cloud Firestore (Document DB)                      │
    │ • Realtime Database (Live status)                    │
    │ • Cloud Functions (Backend logic)                    │
    │ • Cloud Storage (Files/Photos)                       │
    │ • FCM (Push notifications)                           │
    └─────────────────────────────────────────────────────┘
```

---

## 👥 Alur Pengguna Utama

### **Alur Login & Role Selection**
```
App Start
   ↓
[Splash Screen]
   ↓
Is User Authenticated?
   ├─ YES → [Dashboard Gate] → Route ke Dashboard sesuai role
   └─ NO  → [Login Screen]
            ↓
         [Register Screen]
            ↓
         [Role Selection] → Parent / Child
            ↓
         [Age Group Selection] → Baby / Toddler / Balita
            ↓
         [Complete Profile]
            ↓
         [Dashboard]
```

### **Alur Tracking Aktivitas (Misal: Remaja)**
```
[Teen Dashboard]
   ↓
Input Daily Data:
   • Mood (1-5)
   • Focus time (minutes)
   • Water intake (mL)
   • Sleep hours
   • Daily goals
   ↓
[Tap Save Button]
   ↓
Validasi Data
   ↓
Save to Firestore: tracking/{uid}/remaja/{yyyy-mm-dd}
   ↓
Push to Realtime DB: live/{uid}
   ↓
Log to Backend API
   ↓
Show Success/Error Message
```

### **Alur Parent Monitoring**
```
[Parent Dashboard]
   ↓
[View All Children]
   ├─ Baby Dashboard
   ├─ Toddler Dashboard
   ├─ Anak Dashboard
   └─ Teen Dashboard
   ↓
[Real-time Status Updates] (from live/{uid})
   ↓
[Analytics & Reports]
   ├─ Daily summaries
   ├─ Weekly trends
   ├─ Development milestones
   └─ Health alerts
   ↓
[Notifications]
   └─ Push alerts for important events
```

---

## 📊 Struktur Database

### **Firestore Collections:**

#### 1. **users/{uid}**
```
userId: string
email: string
displayName: string
role: 'parent' | 'child'
selectedRole: 'parent' | 'child'
phoneNumber: string?
photoUrl: string?
createdAt: timestamp
lastLogin: timestamp
preferences: {
  theme: string
  language: string
  notifications: boolean
}
```

#### 2. **childProfiles/{childId}**
```
parentId: string (FK → users)
userId: string? (FK → users, null untuk baby/toddler/balita)
name: string
birthDate: timestamp
age: integer
category: 'baby' | 'toddler' | 'balita'
photoUrl: string?
isConnected: boolean
createdAt: timestamp
updatedAt: timestamp?
```

#### 3. **tracking/{uid}/{category}/{yyyy-mm-dd}**

**Baby:**
```
tidur: integer (count)
menyusu: integer (count)
popok: integer (count)
milestones: array
feedingLogs: array
sleepLogs: array
immunizationDone: boolean
savedAt: timestamp
```

**Toddler:**
```
makan: integer
tidur: integer
sensoryPlay: map/array
tantrum: integer
bicara: integer
toiletTraining: map
milestone: array
kontakMata: integer
responsPanggilanNama: integer
interaksiSosial: integer
fokusBermain: integer
kemampuanBicara: integer
savedAt: timestamp
```

**Balita:**
```
belajar: map
sensoryPlay: map/array
perilaku: map
interaksiSosial: map
motorikKasar: map
motorikHalus: map
emosi: map
kebiasaanHarian: map
milestone: array
savedAt: timestamp
```

#### 4. **screen_time/{uid}/daily/{yyyy-mm-dd}**
```
total_menit: integer
by_dashboard: {
  baby: integer,
  toddler: integer,
  balita: integer
}
date: string (YYYY-MM-DD)
created_at: timestamp
```

#### 5. **activities/{activityId}**
```
childId: string (FK)
userId: string (FK)
date: timestamp
activityType: string
description: string?
startTime: timestamp?
endTime: timestamp?
durationMinutes: integer?
quantity: number?
unit: string?
notes: string?
createdAt: timestamp
updatedAt: timestamp?
```

### **Realtime Database:**

#### live/{uid}
```
{
  "live": {
    "user_id": {
      "category": "baby|toddler|balita",
      "displayName": "string",
      "lastUpdate": timestamp,
      // ... category-specific fields
    }
  }
}
```

---

## 🔐 Security Rules

### **Firestore Rules:**
```
match /tracking/{uid}/{document=**} {
  allow read, write: if request.auth != null && 
    request.auth.uid == uid;
}

match /users/{uid} {
  allow read, write: if request.auth != null && 
    request.auth.uid == uid;
}

match /childProfiles/{childId} {
  allow read, write: if request.auth != null && 
    (request.auth.uid == resource.data.parentId || 
     request.auth.uid == request.resource.data.parentId);
}
```

### **Realtime Database Rules:**
```
"live": {
  "$uid": {
    ".read": "auth != null",
    ".write": "auth != null && auth.uid == $uid"
  }
}
```

---

## 💻 Teknologi & Stack

### **Frontend:**
- **Framework**: Flutter (Dart)
- **State Management**: Built-in StatefulWidget
- **UI Components**: Material Design 3

### **Backend & Cloud:**
- **Authentication**: Firebase Auth
- **Database**: Firestore + Realtime Database
- **Storage**: Cloud Storage
-- **Notifications**: FCM (Firebase Cloud Messaging)
-- **Server**: Node.js (Express) — active backend located at `backend/node_backend` (the Python/Flask implementation is archived)

### **Packages Utama:**
```yaml
firebase_core: ^2.24.0
firebase_auth: ^4.10.0
cloud_firestore: ^4.13.0
firebase_database: ^10.2.0
firebase_storage: ^11.2.0
image_picker: ^1.0.4
flutter_local_notifications: ^14.1.0
```

---

## 📱 Main Screens

| Screen | Role | Deskripsi |
|--------|------|-----------|
| Splash Screen | Both | Loading & initialization |
| Login Screen | Both | Email/password login |
| Register Screen | Both | Create new account |
| Role Selection | Both | Pilih Parent atau Child |
| Age Selection | Parent | Pilih kategori usia anak |
| Dashboard Baby | Parent/Child | Tracking: sleep, feed, diaper |
| Dashboard Toddler | Parent/Child | Tracking: behavior, language |
| Dashboard Anak | Parent/Child | Tracking: learning, tasks |
| Dashboard Remaja | Parent/Child | Tracking: mood, focus, water |
| Parent Dashboard | Parent | Unified view all children |
| Analytics | Parent | Reports & statistics |
| Profile Settings | Both | User preferences |
| AI Chat | Both | Parenting assistant |

---

## 🔄 Data Flow

```
User Input
    ↓
Validation
    ↓
State Update (setState)
    ↓
Save to Firestore
    ↓
Update Realtime DB (live status)
    ↓
Log to Backend API
    ↓
Update UI
    ↓
Show Notification
```

---

## 📈 Deployment & Production

- **Platform**: Android & iOS
- **Firebase Project**: parata-2e653
-- **Backend**: Node.js (Express) API (`backend/node_backend`)
- **Database Region**: Default (us-central1)


# 🗄️ ERD (Entity Relationship Diagram) - PATARA AI

## Entity Relationship Diagram (Firestore & Realtime DB)

```
┌──────────────────────────────────────────────────────────────────────────┐
│                           PATARA AI - ERD                                │
└──────────────────────────────────────────────────────────────────────────┘

┌─────────────────────┐         ┌──────────────────────┐
│      USERS          │         │  CHILD PROFILES      │
├─────────────────────┤         ├──────────────────────┤
│ PK: uid             │◄────────│ PK: childId          │
│ email               │1    M   │ FK: parentId → users │
│ displayName         │         │ FK: userId → users   │
│ role (parent/child) │         │ name                 │
│ photoUrl            │         │ birthDate            │
│ createdAt           │         │ age                  │
│ lastLogin           │         │ category             │
│ preferences         │         │ photoUrl             │
│ phoneNumber         │         │ isConnected          │
└─────────────────────┘         │ createdAt            │
        ▲                        │ updatedAt            │
        │                        └──────────────────────┘
        │                                 ▲
        │ N                               │
        │                                 │
        │                     ┌───────────┴───────────┐
        │                     │                       │
        │              ┌──────────────────┐    ┌─────────────────┐
        │              │  TRACKING        │    │  REAL-TIME DB   │
        │              │  (Firestore)     │    │  (live/{uid})   │
        │              ├──────────────────┤    ├─────────────────┤
        │              │ uid              │    │ uid (PK)        │
        │              │ category         │    │ category        │
        │              │ YYYY-MM-DD       │    │ displayName     │
        │              │                  │    │ lastUpdate      │
        │              │ Category Data:   │    │ ...status       │
        │              │ - Baby:          │    │ (computed)      │
        │              │   tidur,menyusu  │    └─────────────────┘
        │              │ - Toddler:       │
        │              │   tantrum,bicara │
        │              │ - Anak:          │
        │              │   belajar,poin   │
        │              │ - Remaja:        │
        │              │   mood,focus     │
        │              └──────────────────┘


┌──────────────────────┐      ┌──────────────────────┐
│  ACTIVITIES          │      │  GAMIFICATION DATA   │
├──────────────────────┤      ├──────────────────────┤
│ PK: activityId       │      │ PK: userId           │
│ FK: childId          │      │ totalPoints          │
│ FK: userId           │      │ badges[]             │
│ date                 │      │ streak               │
│ activityType         │      │ level                │
│ description          │      │ lastActivityDate     │
│ startTime            │      │ milestones{}         │
│ endTime              │      └──────────────────────┘
│ durationMinutes      │
│ quantity             │      ┌──────────────────────┐
│ moodBefore           │      │  INVITE CODES        │
│ moodAfter            │      ├──────────────────────┤
│ rating (1-5)         │      │ PK: code             │
│ notes                │      │ parentId             │
│ createdAt            │      │ childName            │
│ updatedAt            │      │ createdAt            │
└──────────────────────┘      │ expiresAt            │
                              │ used                 │
                              └──────────────────────┘
```

---

## Relationship Cardinality

```
USERS ────────┬──── (1:N) ──── CHILD PROFILES
              │
              ├──── (1:N) ──── TRACKING DATA (by uid)
              │
              ├──── (1:N) ──── ACTIVITIES
              │
              ├──── (1:1) ──── GAMIFICATION DATA
              │
              └──── (1:N) ──── REAL-TIME DB (live/{uid})

CHILD PROFILES ──── (N:1) ──── USERS (parentId)
```

---

## Database Collections Path

### **Firestore Structure:**

```
parata-2e653 (Project)
│
├── users/
│   ├── {uid1}/
│   │   ├── email: "parent@example.com"
│   │   ├── displayName: "John Doe"
│   │   ├── role: "parent"
│   │   ├── preferences: {...}
│   │   └── ...
│   └── {uid2}/
│       ├── email: "child@example.com"
│       ├── displayName: "Jane Doe"
│       ├── role: "child"
│       └── ...
│
├── childProfiles/
│   ├── {childId1}/
│   │   ├── parentId: "{uid1}"
│   │   ├── userId: null (baby/toddler)
│   │   ├── name: "Baby Aisya"
│   │   ├── birthDate: Timestamp
│   │   ├── category: "baby"
│   │   └── ...
│   ├── {childId2}/
│   │   ├── parentId: "{uid1}"
│   │   ├── userId: null
│   │   ├── name: "Toddler Rafa"
│   │   ├── category: "toddler"
│   │   └── ...
│   └── {childId3}/
│       ├── parentId: "{uid1}"
│       ├── userId: "{uid2}"
│       ├── name: "Teen Jane"
│       ├── category: "remaja"
│       └── ...
│
├── tracking/
│   ├── {uid1}/ (parent uid)
│   │   ├── baby/ (collection)
│   │   │   ├── 2024-04-29/
│   │   │   │   ├── tidur: 3
│   │   │   │   ├── menyusu: 8
│   │   │   │   └── ...
│   │   │   └── 2024-04-28/
│   │   │       └── ...
│   │   │
│   │   ├── toddler/
│   │   │   ├── 2024-04-29/
│   │   │   │   ├── tantrum: 2
│   │   │   │   ├── bicara: 15
│   │   │   │   └── ...
│   │   │   └── ...
│   │   │
│   │   ├── anak/
│   │   │   ├── 2024-04-29/
│   │   │   │   ├── belajarMenit: 60
│   │   │   │   ├── poin: 150
│   │   │   │   └── ...
│   │   │   └── ...
│   │   │
│   │   └── remaja/
│   │       ├── 2024-04-29/
│   │       │   ├── moodIndex: 3
│   │       │   ├── focusMinutes: 90
│   │       │   └── ...
│   │       └── ...
│   │
│   └── {uid2}/ (teen child uid)
│       └── remaja/
│           ├── 2024-04-29/
│           │   ├── moodIndex: 2
│           │   └── ...
│           └── ...
│
├── gamificationData/
│   ├── {uid1}/
│   │   ├── totalPoints: 1500
│   │   ├── badges: ["milestone_1", "streak_7"]
│   │   ├── streak: 7
│   │   └── ...
│   └── ...
│
├── activities/
│   ├── {activityId1}/
│   │   ├── childId: "{childId1}"
│   │   ├── userId: "{uid1}"
│   │   ├── date: Timestamp
│   │   ├── activityType: "feeding"
│   │   └── ...
│   └── ...
│
├── inviteCodes/
│   ├── ABC123/
│   │   ├── parentId: "{uid1}"
│   │   ├── childName: "Rafa Toddler"
│   │   ├── createdAt: Timestamp
│   │   └── ...
│   └── ...
│
└── reports/
    ├── {reportId1}/
    │   ├── childId: "{childId1}"
    │   ├── title: "Monthly Report"
    │   ├── period: "2024-04"
    │   └── ...
    └── ...
```

### **Realtime Database Structure:**

```
{
  "live": {
    "{uid1}": {
      "category": "baby",
      "displayName": "Parent Aisya",
      "lastUpdate": 1704067200000,
      "tidur": 3,
      "menyusu": 8,
      "popok": 5
    },
    "{uid2}": {
      "category": "toddler",
      "displayName": "Parent Rafa",
      "lastUpdate": 1704067300000,
      "tantrum": 2,
      "bicara": 15,
      "aktivitas": 3
    },
    "{uid3}": {
      "category": "remaja",
      "displayName": "jane@example.com",
      "lastUpdate": 1704067400000,
      "moodLabel": "Happy",
      "focusMinutes": 90
    }
  }
}
```

---

## Data Types & Formats

### **Timestamps:**
- Format: Firebase Timestamp (seconds + nanoseconds)
- Display: ISO 8601 (2024-04-29T10:30:00Z)

### **Categories:**
```
baby     → Bayi (0-1 tahun)
toddler  → Toddler (1-2 tahun)
balita   → Balita (2-5 tahun)
```

> Behavior tracking is limited to toddler and balita (1-5 tahun).

### **Activity Types:**
```
baby:
  - feeding (menyusu)
  - MPASI
  - sleep (tidur)
  - diaper (popok)
  - milestone

toddler:
  - behavior (tantrum, kontak_mata, respons_panggilan_nama, interaksi_sosial, fokus_bermain, kemampuan_bicara)
  - language (bicara)
  - sensory_play
  - toilet_training
  - milestone

balita:
  - learning (belajar)
  - sensory_play
  - behavior (perilaku)
  - social (interaksi sosial)
  - gross_motor (motorik kasar)
  - fine_motor (motorik halus)
  - emotion (emosi)
  - daily_habits (kebiasaan harian)
```

---

## Field Descriptions

### **Users Collection:**

| Field | Type | Required | Deskripsi |
|-------|------|----------|-----------|
| uid | String (PK) | ✓ | Firebase Auth UID |
| email | String | ✓ | Email unik |
| displayName | String | ✓ | Nama pengguna |
| role | String | ✓ | "parent" atau "child" |
| selectedRole | String | ✓ | Role yang sedang dipilih |
| photoUrl | String | ✗ | URL foto profil |
| phoneNumber | String | ✗ | Nomor telepon |
| createdAt | Timestamp | ✓ | Waktu registrasi |
| lastLogin | Timestamp | ✗ | Login terakhir |
| preferences | Map | ✗ | Theme, language, notifications |

### **ChildProfiles Collection:**

| Field | Type | Required | Deskripsi |
|-------|------|----------|-----------|
| childId | String (PK) | ✓ | Unique child ID |
| parentId | String (FK) | ✓ | Parent UID |
| userId | String (FK) | ✗ | Child UID (null untuk baby/toddler) |
| name | String | ✓ | Nama anak |
| birthDate | Timestamp | ✓ | Tanggal lahir |
| age | Integer | ✓ | Umur dalam tahun |
| category | String | ✓ | baby, toddler, balita |
| photoUrl | String | ✗ | Foto anak |
| isConnected | Boolean | ✓ | Sudah terhubung dengan parent |
| createdAt | Timestamp | ✓ | Dibuat saat |
| updatedAt | Timestamp | ✗ | Update terakhir |

### **Tracking/{uid}/{category}/{date}:**

Bergantung pada category, field berbeda:

**Baby Fields:**
- tidur (int) - jumlah kali tidur
- menyusu (int) - jumlah kali menyusu
- popok (int) - jumlah kali ganti popok
- milestones (array)
- feedingLogs (array)
- sleepLogs (array)
- diaperLogs (array)
- immunizationDone (bool)

**Toddler Fields:**
- makan (int)
- tidur (int)
- sensoryPlay (map/array)
- tantrum (int)
- bicara (int)
- toiletTraining (map)
- milestone (array)
- kontakMata (int)
- responsPanggilanNama (int)
- interaksiSosial (int)
- fokusBermain (int)
- kemampuanBicara (int)

**Balita Fields:**
- belajar (map)
- sensoryPlay (map/array)
- perilaku (map)
- interaksiSosial (map)
- motorikKasar (map)
- motorikHalus (map)
- emosi (map)
- kebiasaanHarian (map)
- milestone (array)

---

## Indexes (untuk query optimization)

### **Firestore Indexes:**

1. **Tracking collection:**
   ```
   Collection: tracking/{uid}/category/
   Composite Index: uid, category, date (desc)
   ```

2. **Activities collection:**
   ```
   Collection: activities
   Composite Index: childId, date (desc)
   Composite Index: userId, date (desc)
   Composite Index: childId, activityType, date (desc)
   ```

3. **ChildProfiles collection:**
   ```
   Collection: childProfiles
   Composite Index: parentId, createdAt (desc)
   ```


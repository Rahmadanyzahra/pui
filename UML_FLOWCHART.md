# 📊 UML & Flowchart - PATARA AI

## 1️⃣ UML CLASS DIAGRAM

```
┌──────────────────────────────────────────────────────────────────────────┐
│                        UML CLASS DIAGRAM                                 │
└──────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│            <<Abstract>>                  │
│         DashboardBase                    │
├─────────────────────────────────────────┤
│ - category: String                      │
│ - uid: String                           │
│ - todayKey: String                      │
│ - saving: bool                          │
├─────────────────────────────────────────┤
│ + _saveData(): void                     │
│ + _loadData(): void                     │
│ + _buildUI(): Widget                    │
└─────────────────────────────────────────┘
      ▲         ▲           ▲          ▲
      │         │           │          │
      │ extends │ extends   │ extends  │ extends
      │         │           │          │
      │         │           │          │
┌─────┴──┐  ┌───┴────┐  ┌───┴────┐  ┌──┴────────┐
│ Baby   │  │Toddler │  │ Anak   │  │ Remaja   │
│Dashboard│ │Dashboard│ │Dashboard│ │Dashboard │
├────────┤  ├────────┤  ├────────┤  ├──────────┤
│- tidur │  │-tantrum│  │-belajar│  │- mood    │
│- menyusu│ │-bicara │  │-poin   │  │- focus   │
│- popok │  │-aktivitas│ │-checklist│ │-waterMl  │
│- logs[]│  │-stars  │  │-tasks[]│  │-sleep    │
└────────┘  └────────┘  └────────┘  └──────────┘


┌──────────────────────────────────────────┐
│         User                             │
├──────────────────────────────────────────┤
│ - uid: String (PK)                       │
│ - email: String                          │
│ - displayName: String                    │
│ - role: String ('parent'|'child')        │
│ - photoUrl: String?                      │
│ - createdAt: DateTime                    │
│ - preferences: Map<String, dynamic>      │
├──────────────────────────────────────────┤
│ + fromFirestore(doc): User               │
│ + toFirestore(): Map                     │
│ + copyWith(...): User                    │
└──────────────────────────────────────────┘
         ▲                    ▲
         │ 1              M   │
         │                    │
    ┌────┴────────────────────┴──────┐
    │                                 │
    │ (1:N relationship)              │
    │                                 │
    ▼                                 ▼
┌──────────────────────────────────────────┐
│      ChildProfile                        │
├──────────────────────────────────────────┤
│ - id: String (PK)                        │
│ - parentId: String (FK→User)             │
│ - userId: String? (FK→User)              │
│ - name: String                           │
│ - birthDate: DateTime                    │
│ - age: int                               │
│ - category: String                       │
│ - photoUrl: String?                      │
│ - isConnected: bool                      │
│ - createdAt: DateTime                    │
│ - updatedAt: DateTime?                   │
├──────────────────────────────────────────┤
│ + fromFirestore(doc): ChildProfile       │
│ + toFirestore(): Map                     │
│ + copyWith(...): ChildProfile            │
│ + getAgeCategory(): String               │
└──────────────────────────────────────────┘
         ▲                    ▲
         │ 1              M   │
         │                    │
         ├────────────────────┤
         │                    │
    ┌────┴────────────────────┴──────┐
    │                                 │
    │ (1:N relationship)              │
    │                                 │
    ▼                                 ▼
┌──────────────────────────────────────────┐
│      DailyActivity                       │
├──────────────────────────────────────────┤
│ - id: String? (PK)                       │
│ - childId: String (FK)                   │
│ - userId: String (FK)                    │
│ - date: DateTime                         │
│ - activityType: String                   │
│ - description: String?                   │
│ - startTime: DateTime?                   │
│ - endTime: DateTime?                     │
│ - durationMinutes: int?                  │
│ - quantity: double?                      │
│ - unit: String?                          │
│ - rating: int?                           │
│ - notes: String?                         │
│ - createdAt: DateTime                    │
│ - updatedAt: DateTime?                   │
├──────────────────────────────────────────┤
│ + calculateDuration(): int?              │
│ + fromFirestore(doc): DailyActivity      │
│ + toFirestore(): Map                     │
└──────────────────────────────────────────┘


┌──────────────────────────────────────────┐
│    TrackingData (Firestore)              │
├──────────────────────────────────────────┤
│ - uid: String                            │
│ - category: String                       │
│ - date: String (YYYY-MM-DD)              │
│ - data: Map<String, dynamic>             │
│   (diisi sesuai category)                │
│ - savedAt: Timestamp                     │
├──────────────────────────────────────────┤
│ + fromSnapshot(snapshot): Map            │
│ + toFirestore(): Map                     │
└──────────────────────────────────────────┘


┌──────────────────────────────────────────┐
│    GamificationData                      │
├──────────────────────────────────────────┤
│ - userId: String (PK)                    │
│ - totalPoints: int                       │
│ - badges: List<String>                   │
│ - streak: int                            │
│ - level: int                             │
│ - lastActivityDate: DateTime             │
│ - milestones: Map<String, dynamic>       │
├──────────────────────────────────────────┤
│ + addPoints(points): void                │
│ + addBadge(badge): void                  │
│ + updateStreak(): void                   │
│ + getLevel(): int                        │
└──────────────────────────────────────────┘
```

---

## 2️⃣ UML SEQUENCE DIAGRAM - Login & Initial Setup

```
User          App              Firebase      Parent         Dashboard
  │            │                 │             │                │
  ├──Login────►│                 │             │                │
  │            ├──Auth Init──────►│             │                │
  │            │                 │             │                │
  │            │◄──Auth Success──┤             │                │
  │            │                 │             │                │
  │            ├──Load User Data─►│             │                │
  │            │                 │             │                │
  │            │◄──User Data─────┤             │                │
  │            │                 │             │                │
  │            ├──Get Preferences┤             │                │
  │            │                 │             │                │
  ├◄───Roles───┤                 │             │                │
  │            │                 │             │                │
  ├──Select Role───►│             │             │                │
  │            ├─────Save Preference─────────►│                │
  │            │                 │             │                │
  │            │                 │◄────Confirm──┤              │
  │            │◄──Redirect──────┤             │                │
  │            │                 │             │                │
  ├◄───Child List──┤             │             │                │
  │            ├──Get Children───►│             │                │
  │            │                 │             │                │
  │            │◄──Children Data─┤             │                │
  │            │                 │             │                │
  ├◄───Dashboard──┤             │             │                │
  │            ├──Listen Live Status─────────────────────────────►│
  │            │                 │             │                │
  │            │◄──Real-time Updates─────────────────────────────┤
  │            │                 │             │                │
```

---

## 3️⃣ UML SEQUENCE DIAGRAM - Save Activity Data

```
User         Dashboard        Firestore       Realtime DB      Backend
  │             │                │                 │               │
  ├─Input Data──┤                │                 │               │
  │             ├──Validate─────┐│                 │               │
  │             │◄──Valid───────┘│                 │               │
  │             │                │                 │               │
  ├─Tap Save───►│                │                 │               │
  │             ├──setState(saving=true)           │               │
  │             │                │                 │               │
  │             ├──Save to Firestore───────────────►│               │
  │             │                │                 │               │
  │             │◄──Success──────┤                 │               │
  │             │                │                 │               │
  │             ├──Push Live Status──────────────────────────────►│
  │             │                │                 │               │
  │             │◄──Updated──────┤                 │               │
  │             │                │                 │               │
  │             ├──Log Activity────────────────────────────────────►│
  │             │                │                 │               │
  │             │◄──Logged───────┤                 │               │
  │             │                │                 │               │
  │             ├──setState(saving=false)          │               │
  │             │                │                 │               │
  ├◄──Success──┤                │                 │               │
  │             ├──showSnackBar()                  │               │
  │             │                │                 │               │
```

---

## 4️⃣ SYSTEM FLOWCHART - Main Application Flow

```
                            ┌────────────────┐
                            │   App Start    │
                            └────────┬───────┘
                                     ▼
                        ┌───────────────────────┐
                        │  Initialize Firebase  │
                        │  & Dependencies      │
                        └───────────┬───────────┘
                                    ▼
                    ┌───────────────────────────────┐
                    │  Show Splash Screen           │
                    │  (Loading...)                 │
                    └───────────┬───────────────────┘
                                ▼
                    ┌───────────────────────────────┐
                    │  Check Authentication State   │
                    └────┬──────────────────────┬───┘
                         │ No Auth              │ Auth
                         ▼                      ▼
              ┌─────────────────────┐  ┌──────────────────┐
              │  Show Login Screen   │  │ Load User Data   │
              └──────────┬──────────┘  └────────┬─────────┘
                         │                      ▼
                         │         ┌────────────────────┐
                         │         │ Check User Role    │
                         │         └─────┬──────────┬───┘
                         │               │          │
                         │         Parent│          │Child
                         │               ▼          ▼
                         │    ┌──────────────┐  ┌──────────────┐
                         │    │ Load Children│  │ Child       │
                         │    │ & Display    │  │ Dashboard   │
                         │    │ Parent       │  └──────────────┘
                         │    │ Dashboard    │
                         │    └──────┬───────┘
                         │           ▼
                         │  ┌─────────────────┐
                         │  │ Select Child &  │
                         │  │ Category        │
                         │  └────────┬────────┘
                         │           ▼
                         │  ┌─────────────────┐
                         │  │ Show Category   │
                         │  │ Dashboard       │
                         │  │ (Baby/Toddler/  │
                         │  │  Anak/Remaja)   │
                         │  └─────────────────┘
                         │
              ┌──────────┴──────────┐
              ▼                     ▼
    ┌──────────────────┐  ┌──────────────────┐
    │  Register (New)   │  │  Login (Existing)│
    └────────┬─────────┘  └────────┬─────────┘
             ▼                     ▼
    ┌──────────────────┐  ┌──────────────────┐
    │  Create Account  │  │  Verify Credentials
    │  with Email/Pass │  │  (Firebase Auth)
    └────────┬─────────┘  └────────┬─────────┘
             ▼                     │
    ┌──────────────────┐           │
    │  Select Role     │◄──────────┘
    │ (Parent/Child)   │
    └────────┬─────────┘
             ▼
    ┌──────────────────┐
    │ Select Child Age │
    │ (if Parent)      │
    └────────┬─────────┘
             ▼
    ┌──────────────────┐
    │  Create Profile  │
    │  & Setup Info    │
    └────────┬─────────┘
             ▼
    ┌──────────────────┐
    │  Save to         │
    │  Firebase        │
    └──────────────────┘
```

---

## 5️⃣ FLOWCHART - Activity Tracking Data Flow

```
    ┌──────────────────────┐
    │ User Opens Dashboard │
    └──────────┬───────────┘
               ▼
    ┌──────────────────────────────────┐
    │ Load Existing Data from Firestore│
    │ (tracking/{uid}/{cat}/{date})    │
    └──────────┬───────────────────────┘
               ▼
    ┌──────────────────────┐
    │  Populate Form with  │
    │  Existing Data (if   │
    │  any)                │
    └──────────┬───────────┘
               ▼
    ┌──────────────────────┐
    │   User Input Data    │
    │ (mood, sleep, etc.)  │
    └──────────┬───────────┘
               ▼
    ┌──────────────────────┐
    │   Tap Save Button    │
    └──────────┬───────────┘
               ▼
    ┌──────────────────────────────────┐
    │  Validate Input Data             │
    ├──────────────────────────────────┤
    │ ✓ Check required fields          │
    │ ✓ Check value ranges             │
    │ ✓ Check data types               │
    └──────────┬───────────────────────┘
               ▼
           Valid?
          /        \
        YES        NO
       /            \
      ▼              ▼
    Save       Show Error
    │          Message
    ▼          & Stop
 ┌───────────────────────────┐
 │ setState(saving = true)   │
 │ Show Loading Indicator    │
 └────────┬────────┬────────┘
          │        │
    ┌─────▼──┐ ┌──▼──────────┐
    │ Save to│ │ Update Live │
    │Firestore│ │ Status      │
    │        │ │ (Realtime)  │
    └─────┬──┘ └──┬───────────┘
         │        │
         ▼        ▼
    ┌────────────────────────────┐
    │  Log Activity to Backend   │
    │  (non-blocking)            │
    └────────┬───────────────────┘
             ▼
    ┌────────────────────────────┐
    │  setState(saving = false)  │
    │  Hide Loading Indicator    │
    └────────┬───────────────────┘
             ▼
         Success?
        /        \
       YES       NO
      /           \
     ▼             ▼
  ┌──────────┐  ┌────────────┐
  │ Show     │  │ Show Error │
  │Success   │  │ Message    │
  │Snackbar  │  │ (Details)  │
  └──────────┘  └────────────┘
```

---

## 6️⃣ FLOWCHART - Real-time Parent Monitoring

```
    ┌──────────────────────────┐
    │ Parent Open Dashboard    │
    └───────────┬──────────────┘
                ▼
    ┌──────────────────────────────────┐
    │ Load Children Profiles from       │
    │ Firestore (childProfiles)         │
    └───────────┬──────────────────────┘
                ▼
    ┌──────────────────────────────────┐
    │ For Each Child:                  │
    │ Listen to Live Status            │
    │ (Realtime DB: live/{uid})        │
    └───────────┬──────────────────────┘
                ▼
    ┌──────────────────────────────────┐
    │ Setup StreamListener for Each    │
    │ Child's Real-time Data           │
    └───────────┬──────────────────────┘
                ▼
    ┌──────────────────────────────────┐
    │ Show Dashboard UI with:          │
    │ - Child Cards (status)           │
    │ - Live Data Display              │
    │ - Last Update Time               │
    └───────────┬──────────────────────┘
                ▼
    ┌──────────────────────────────────┐
    │ Listen for Real-time Updates     │
    │ (StreamBuilder on live/{uid})    │
    └───────────┬──────────────────────┘
                ▼
        Data Changed?
         /        \
       YES        NO
      /            \
     ▼              ▼
  ┌──────────┐  (Keep listening)
  │ Update   │
  │ UI with  │
  │ New Data │
  └────┬─────┘
       ▼
  ┌──────────────────┐
  │ Show Notification│
  │ (if enabled)     │
  └──────────────────┘
```

---

## 7️⃣ COMPONENT INTERACTION DIAGRAM

```
┌─────────────────────────────────────────────────────┐
│                   UI Layer                          │
├─────────────────────────────────────────────────────┤
│ • Screens (Dashboard, Parent, Analysis)             │
│ • Widgets (Cards, Forms, Charts)                    │
│ • Theme Provider                                    │
└──────────────────┬──────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────┐
│               Service Layer                         │
├─────────────────────────────────────────────────────┤
│ • ActivityTrackingService    • ScreenTimeTracker    │
│ • ChildProfileService        • RealtimeService     │
│ • GameficationService        • BackendApiService   │
│ • LocalNotificationService   • AnalysisService    │
└──────────────────┬──────────────────────────────────┘
                   │
        ┌──────────┼──────────┐
        │          │          │
        ▼          ▼          ▼
   ┌────────┐ ┌────────┐ ┌──────────┐
   │Firebase│ │Local   │ │Backend   │
   │Auth    │ │Storage │ │API       │
   │        │ │        │ │          │
   └────────┘ └────────┘ └──────────┘
        │          │          │
        └──────────┼──────────┘
                   ▼
┌──────────────────────────────────────┐
│      Data Layer / Persistence        │
├──────────────────────────────────────┤
│ • Firestore (Document DB)            │
│ • Realtime DB (Live updates)         │
│ • Cloud Storage (Files)              │
│ • SharedPreferences (Local cache)    │
└──────────────────────────────────────┘
```

---

## 8️⃣ STATE MANAGEMENT FLOW

```
┌─────────────────────┐
│   User Action       │
│ (Button tap, input) │
└──────────┬──────────┘
           ▼
┌─────────────────────┐
│  setState() called  │
└──────────┬──────────┘
           ▼
┌──────────────────────────┐
│ Update Local State       │
│ (_moodIndex, _points,    │
│  etc.)                   │
└──────────┬───────────────┘
           ▼
┌──────────────────────────┐
│  Call Service Method     │
│ (_saveData(),            │
│  _loadData())            │
└──────────┬───────────────┘
           ▼
┌──────────────────────────┐
│  Service Calls Firebase  │
│  (Firestore, Realtime DB)│
└──────────┬───────────────┘
           ▼
┌──────────────────────────┐
│  Data Synced to Cloud    │
└──────────┬───────────────┘
           ▼
┌──────────────────────────┐
│ setState() - Rebuild UI  │
└──────────────────────────┘
```

---

## 9️⃣ Push Notification Flow

```
    ┌──────────────────┐
    │ Event Triggered  │
    │ (Milestone, etc) │
    └────────┬─────────┘
             ▼
    ┌──────────────────────┐
    │ Check Notification   │
    │ Settings (Enabled?)  │
    └────────┬──────────────┘
             ▼
    ┌──────────────────────┐
    │ Build Notification   │
    │ Payload              │
    └────────┬──────────────┘
             ▼
    ┌──────────────────────────────┐
    │ Send via FCM                 │
    │ (Firebase Cloud Messaging)   │
    └────────┬──────────────────────┘
             ▼
    ┌──────────────────────┐
    │ Device Receives      │
    │ Notification         │
    └────────┬──────────────┘
             ▼
    ┌──────────────────────────────┐
    │ Local Notification Service   │
    │ Display in Notification Panel│
    └────────┬──────────────────────┘
             ▼
    ┌──────────────────────┐
    │ User Taps            │
    │ Notification         │
    └────────┬──────────────┘
             ▼
    ┌──────────────────────┐
    │ Navigate to Related  │
    │ Screen               │
    └──────────────────────┘
```

---

## 🔟 Error Handling Flow

```
    ┌────────────────────┐
    │ Operation Called   │
    │ (e.g., Save Data)  │
    └─────────┬──────────┘
              ▼
    ┌────────────────────┐
    │ Try Block Executes │
    └─────────┬──────────┘
              ▼
          Success?
         /        \
       YES        NO
      /            \
     ▼              ▼
  Continue      Exception Caught
  & Return      └────────┬────────┘
                         ▼
                  ┌─────────────────┐
                  │ Print Error Log │
                  │ (console/file)  │
                  └────────┬────────┘
                           ▼
                  ┌─────────────────────┐
                  │ Show Error SnackBar │
                  │ with Error Details  │
                  │ (to user)           │
                  └────────┬────────────┘
                           ▼
                  ┌─────────────────────┐
                  │ setState() if needed│
                  │ (reset flags, UI)   │
                  └─────────────────────┘
```


# Role-Based Access Control (RBAC) Implementation Guide
## Patara AI - Roles: Parent, Child, Delegated Parent & Assistant

**Document Date:** May 7, 2026  
**Status:** Implementation Ready

---

## 📋 Executive Summary

This document outlines the implementation strategy for the three-tier role-based access control system in Patara AI:

| Role | Dashboard | Data Input | Monitoring | Notifications |
|------|-----------|-----------|-----------|---|
| **Parent** | Full | Yes (all children) | All assigned children | All types |
| **Child** | Minimal (profile & milestone) | Limited (own only) | Own only | Limited |
| **Delegated Parent** | Parent-like | Yes (specific children) | Assigned children only | All types (retains from primary parent) |

---

## 🏗️ Current System Architecture

### Role Storage
- **Location:** Firestore at `users/{uid}` document
- **Current Fields:**
  - `selectedRole`: "parent" or "child" 
  - `role`: Legacy field (synced with selectedRole)
  - `parentAccessAll`: Boolean (parent can see all children)
  - `isDashboardLocked`: Boolean (child dashboard restriction)

### Current Dashboard Types
1. **Parent Dashboard** → `FiveMenuShell` (5-tab menu system)
   - Tabs: Dashboard, Activity, Schedule, Info, AI Chat
   - Shows all children and analytics

2. **Child Dashboards**
   - Baby (0-1): `dashboard_baby.dart` (parent-managed)
   - Toddler (1-2): `dashboard_toddler.dart` (parent-managed)
   - Balita (2-5): `dashboard_anak.dart` (self-managed)
   - Remaja (13-17): `dashboard_remaja.dart` (self-managed with optional parent connection)

### Child Profile Management
- Stored in `child_profiles` collection with parentId FK
- Each parent can have multiple children
- Remaja children can optionally connect their own Firebase account

---

## 🎯 Implementation Requirements

### 1. Backend Changes (backend/app.py)

#### 1.1 Extend Role Constants
```python
# Add to app.py
VALID_ROLES = {'parent', 'child', 'delegated_parent', 'assistant'}
PARENT_ROLES = {'parent', 'delegated_parent', 'assistant'}
DATA_INPUT_ROLES = {'parent', 'delegated_parent', 'assistant'}
```

#### 1.2 Update User Profile Initialization
Modify `_ensure_firestore_user_profile()` to accept delegated_parent role and store parent reference:

```python
def _ensure_firestore_user_profile(uid: str, email: str = "", role: str = "parent", 
                                   linked_parent_uid: str = None) -> Dict[str, Any]:
    # ... existing code ...
    if not snapshot.exists:
        doc_ref.set({
            "uid": uid,
            "email": email,
            "role": role,
            "selectedRole": role,
            "linkedParentUid": linked_parent_uid,  # For delegated_parent
            "assignedChildren": [],  # List of child IDs this user can manage
            "created_at": now,
            "lastUpdated": now,
        }, merge=True)
```

#### 1.3 Add Role Validation Decorator
```python
def require_role(*allowed_roles):
    """Decorator to check if user has required role for endpoint"""
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            user_role = _current_user_role()
            if user_role not in allowed_roles:
                return jsonify({"error": "Insufficient permissions"}), 403
            return f(*args, **kwargs)
        return decorated_function
    return decorator
```

#### 1.4 Protect Data Input Endpoints
Update endpoints like `/nutrition/food-intake`, `/growth/record`, `/activities` to:
- Only allow roles in `DATA_INPUT_ROLES`
- Check if user has access to the child being updated
- For delegated_parent, verify child is in `assignedChildren`

```python
@app.post("/nutrition/food-intake")
@require_auth
@require_role('parent', 'delegated_parent', 'assistant')
def post_nutrition_food_intake():
    # existing code to track food
    user_role = _current_user_role()
    child_id = request.json.get('child_id')
    
    # For delegated parent, verify access
    if user_role == 'delegated_parent':
        user_doc = _firestore_user_doc(g.current_user['uid']).get()
        if child_id not in user_doc.to_dict().get('assignedChildren', []):
            return jsonify({"error": "No access to this child"}), 403
    
    # Process food intake...
    return jsonify({"success": True})
```

#### 1.5 Add Delegated Parent Management Endpoints
```python
# Create delegated parent account (called by primary parent)
@app.post("/delegated-parents/create")
@require_auth
@require_role('parent')
def create_delegated_parent():
    """Primary parent creates a delegated parent account"""
    data = request.json
    parent_uid = g.current_user['uid']
    
    # Create new user with delegated_parent role
    delegated_email = data.get('email')
    delegated_uid = data.get('uid')  # Or generate new account
    children_ids = data.get('children', [])
    
    db = _bootstrap_firestore()
    db.collection('users').document(delegated_uid).set({
        'email': delegated_email,
        'role': 'delegated_parent',
        'selectedRole': 'delegated_parent',
        'linkedParentUid': parent_uid,
        'assignedChildren': children_ids,
        'created_at': _utc_now_iso(),
    })
    
    return jsonify({
        'delegatedParentUid': delegated_uid,
        'message': 'Delegated parent created successfully'
    })

# Update assigned children for delegated parent
@app.put("/delegated-parents/<delegated_uid>/children")
@require_auth
@require_role('parent')
def update_delegated_parent_children(delegated_uid):
    """Update which children a delegated parent can manage"""
    parent_uid = g.current_user['uid']
    children_ids = request.json.get('children', [])
    
    db = _bootstrap_firestore()
    db.collection('users').document(delegated_uid).set({
        'assignedChildren': children_ids,
    }, merge=True)
    
    return jsonify({'success': True})
```

---

### 2. Frontend Changes (Flutter)

#### 2.1 Extend RoleSelectionScreen
File: `lib/features/role_selection_screen.dart`

Add delegated_parent option to role selection:

```dart
class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  
  Future<void> _selectRole(String role) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'email': user.email,
      'selectedRole': role,
      'role': role,
      'linkedParentUid': role == 'delegated_parent' ? null : null,
      'assignedChildren': role == 'delegated_parent' ? [] : null,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pilih Role'), centerTitle: true),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Selamat datang di Patara AI!',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 48),
                
                // Parent Role
                _buildRoleCard(
                  icon: Icons.person,
                  title: 'Orang Tua',
                  description: 'Pantau perkembangan anak, recap mingguan, notifikasi',
                  color: const Color(0xFFEC407A),
                  onTap: () => _selectRole('parent'),
                ),
                const SizedBox(height: 16),
                
                // Delegated Parent Role
                _buildRoleCard(
                  icon: Icons.supervisor_account,
                  title: 'Asisten / Pendamping',
                  description: 'Input data harian, pantau anak tertentu',
                  color: const Color(0xFFFF7043),
                  onTap: () => _selectRole('delegated_parent'),
                ),
                const SizedBox(height: 16),
                
                // Child Role
                _buildRoleCard(
                  icon: Icons.child_care,
                  title: 'Anak',
                  description: 'Lihat profil & milestone sendiri',
                  color: const Color(0xFFBA68C8),
                  onTap: _selectChildRole,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withValues(alpha: 0.8), color],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(icon, size: 40, color: Colors.white),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
```

#### 2.2 Update DashboardGateScreen for Role Routing
File: `lib/main.dart`

Extend the routing logic in DashboardGateScreen:

```dart
class DashboardGateScreen extends StatelessWidget {
  const DashboardGateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const RoleSelectionScreen();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final role = data['selectedRole'] as String? ?? 'parent';

        // Route based on role
        switch (role) {
          case 'parent':
            return const FiveMenuShell(
              dashboardType: 'parent',
              initialIndex: 0,
            );
          
          case 'delegated_parent':
            // Delegated parent sees parent-like dashboard
            // But limited to assigned children
            return const FiveMenuShell(
              dashboardType: 'delegated_parent',
              initialIndex: 0,
              assignedChildren: [], // Will be populated from Firestore
            );
          
          case 'child':
            final umur = (data['umur'] as num?)?.toInt() ?? 8;
            final category = _resolveChildCategory(umur: umur);
            return ChildDashboardScreen(
              category: category,
              umur: umur,
            );
          
          default:
            return const RoleSelectionScreen();
        }
      },
    );
  }

  String _resolveChildCategory({required int umur}) {
    if (umur <= 1) return 'baby';
    if (umur <= 3) return 'toddler';
    if (umur <= 12) return 'anak';
    return 'remaja';
  }
}
```

#### 2.3 Add Parent-Child Selection Screen
Create new file: `lib/features/parent_child_selection_screen.dart`

When parent logs in, show which children to monitor:

```dart
class ParentChildSelectionScreen extends StatefulWidget {
  const ParentChildSelectionScreen({super.key});

  @override
  State<ParentChildSelectionScreen> createState() => 
      _ParentChildSelectionScreenState();
}

class _ParentChildSelectionScreenState 
    extends State<ParentChildSelectionScreen> {
  
  final Set<String> _selectedChildren = {};
  bool _selectAll = true;

  @override
  Widget build(BuildContext context) {
    final parentUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih Anak untuk Dipantau'),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('child_profiles')
            .where('parentId', isEqualTo: parentUid)
            .orderBy('birthDate', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final children = snapshot.data!.docs;

          if (children.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Belum ada anak yang ditambahkan'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // Navigate to add child screen
                    },
                    child: const Text('Tambah Anak'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: CheckboxListTile(
                  title: const Text('Pantau Semua Anak'),
                  value: _selectAll,
                  onChanged: (value) {
                    setState(() {
                      _selectAll = value ?? false;
                      if (_selectAll) {
                        _selectedChildren.addAll(
                          children.map((c) => c.id)
                        );
                      } else {
                        _selectedChildren.clear();
                      }
                    });
                  },
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: children.length,
                  itemBuilder: (context, index) {
                    final child = children[index];
                    final childId = child.id;
                    final name = child['name'] as String? ?? 'Unknown';

                    return CheckboxListTile(
                      title: Text(name),
                      value: _selectedChildren.contains(childId),
                      onChanged: (value) {
                        setState(() {
                          if (value ?? false) {
                            _selectedChildren.add(childId);
                          } else {
                            _selectedChildren.remove(childId);
                          }
                          _selectAll = _selectedChildren.length == 
                                       children.length;
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: () async {
            // Save selection to Firestore
            await FirebaseFirestore.instance
                .collection('users')
                .doc(parentUid)
                .set({
              'monitoredChildren': _selectedChildren.toList(),
              'monitorAll': _selectAll,
              'lastUpdated': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => const FiveMenuShell(
                    dashboardType: 'parent',
                  ),
                ),
              );
            }
          },
          child: const Text('Lanjutkan'),
        ),
      ),
    );
  }
}
```

#### 2.4 Update FiveMenuShell for Role Awareness
File: `lib/features/menu/five_menu_shell.dart`

Modify constructor to accept role and assigned children:

```dart
class FiveMenuShell extends StatefulWidget {
  final String dashboardType; // 'parent' or 'delegated_parent'
  final int initialIndex;
  final List<String>? assignedChildren; // For delegated_parent

  const FiveMenuShell({
    super.key,
    required this.dashboardType,
    this.initialIndex = 0,
    this.assignedChildren,
  });

  @override
  State<FiveMenuShell> createState() => _FiveMenuShellState();
}

class _FiveMenuShellState extends State<FiveMenuShell> {
  
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    // Build tab bar based on role
    final isDelegatedParent = widget.dashboardType == 'delegated_parent';
    
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          // Dashboard tab
          _buildMenuDashboardTab(isDelegatedParent),
          
          // Activity/Input tab (full for parent, limited for delegated)
          MenuActivityTab(
            isDelegatedParent: isDelegatedParent,
            assignedChildren: widget.assignedChildren ?? [],
          ),
          
          // Schedule tab
          const MenuJadwalTab(),
          
          // Info tab
          const MenuInfoTab(),
          
          // AI Chat tab
          const MenuAiTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.add), label: 'Input'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Jadwal'),
          BottomNavigationBarItem(icon: Icon(Icons.info), label: 'Info'),
          BottomNavigationBarItem(icon: Icon(Icons.smart_toy), label: 'AI'),
        ],
      ),
    );
  }

  Widget _buildMenuDashboardTab(bool isDelegatedParent) {
    if (isDelegatedParent) {
      return const DelegatedParentDashboardTab();
    }
    return const MenuDashboardTab();
  }
}
```

#### 2.5 Create Delegated Parent Dashboard Tab
Create new file: `lib/features/menu/delegated_parent_dashboard_tab.dart`

```dart
class DelegatedParentDashboardTab extends StatefulWidget {
  const DelegatedParentDashboardTab({super.key});

  @override
  State<DelegatedParentDashboardTab> createState() => 
      _DelegatedParentDashboardTabState();
}

class _DelegatedParentDashboardTabState 
    extends State<DelegatedParentDashboardTab> {

  @override
  Widget build(BuildContext context) {
    final userUid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userUid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final assignedChildren = 
            List<String>.from(userData['assignedChildren'] ?? []);
        final linkedParentUid = userData['linkedParentUid'] as String?;

        if (assignedChildren.isEmpty) {
          return const Center(
            child: Text('Tidak ada anak yang ditugaskan'),
          );
        }

        // Display only assigned children
        return SingleChildScrollView(
          child: Column(
            children: [
              // Show which parent delegated this
              if (linkedParentUid != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.info),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Dashboard ini menampilkan anak yang ditugaskan kepada Anda',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              
              // List assigned children
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _fetchAssignedChildren(assignedChildren),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final children = snapshot.data ?? [];
                  
                  return Column(
                    children: children.map((child) {
                      return Card(
                        margin: const EdgeInsets.all(8),
                        child: ListTile(
                          title: Text(child['name'] ?? 'Unknown'),
                          subtitle: Text('Umur: ${child['age']}'),
                          trailing: const Icon(Icons.arrow_forward),
                          onTap: () {
                            // Open child details
                          },
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchAssignedChildren(
      List<String> childIds) async {
    if (childIds.isEmpty) return [];
    
    final docs = await FirebaseFirestore.instance
        .collection('child_profiles')
        .where(FieldPath.documentId, whereIn: childIds)
        .get();
    
    return docs.docs
        .map((doc) => {...doc.data(), 'id': doc.id})
        .toList();
  }
}
```

---

### 3. Firestore Security Rules Updates

File: `firestore.rules`

Add role-based access control:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Users collection
    match /users/{uid} {
      allow read, update, delete: if request.auth.uid == uid;
      allow create: if request.auth != null;
    }

    // Child profiles - existing rules, enhance with delegated_parent check
    match /child_profiles/{childId} {
      allow read: if request.auth != null && (
        request.auth.uid == resource.data.parentId ||
        // Also allow delegated_parent if child is in their assignedChildren
        canAccessChildAsDelegate(request.auth.uid, childId)
      );
      allow write: if request.auth != null && (
        request.auth.uid == resource.data.parentId ||
        (isDataInputRole(request.auth.uid) && 
         canAccessChildAsDelegate(request.auth.uid, childId))
      );
      allow create: if request.auth != null;
    }

    // Tracking data (health, nutrition, etc.)
    match /tracking/{uid}/{document=**} {
      allow read, write: if request.auth != null && (
        request.auth.uid == uid ||
        canAccessAsDelegate(request.auth.uid, uid)
      );
    }

    // Family notifications
    match /family_notifications/{notificationId} {
      allow create: if request.auth != null && isParentRole(request.auth.uid);
      allow read, update: if request.auth != null && (
        request.auth.uid == resource.data.parentId ||
        request.auth.uid == resource.data.recipientUid
      );
    }

    // Helper functions
    function isParentRole(uid) {
      let user = get(/databases/$(database)/documents/users/$(uid)).data;
      let role = user.selectedRole ?? user.role ?? 'parent';
      return role in ['parent', 'delegated_parent'];
    }

    function isDataInputRole(uid) {
      let user = get(/databases/$(database)/documents/users/$(uid)).data;
      let role = user.selectedRole ?? user.role ?? 'parent';
      return role in ['parent', 'delegated_parent', 'assistant'];
    }

    function canAccessChildAsDelegate(uid, childId) {
      let userDoc = get(/databases/$(database)/documents/users/$(uid)).data;
      let assignedChildren = userDoc.assignedChildren ?? [];
      return childId in assignedChildren && 
             (userDoc.selectedRole ?? userDoc.role ?? 'parent') in 
             ['delegated_parent', 'assistant'];
    }

    function canAccessAsDelegate(uid, parentUid) {
      let userDoc = get(/databases/$(database)/documents/users/$(uid)).data;
      return userDoc.linkedParentUid == parentUid && 
             (userDoc.selectedRole ?? userDoc.role ?? 'parent') in 
             ['delegated_parent', 'assistant'];
    }
  }
}
```

---

### 4. Data Model Updates

#### 4.1 Firestore User Document Schema

```javascript
// Location: users/{uid}
{
  // Identity
  "uid": string,                    // Firebase UID
  "email": string,
  
  // Roles
  "role": string,                   // "parent" | "child" | "delegated_parent"
  "selectedRole": string,           // Currently active role
  
  // Hierarchy (for delegated parents)
  "linkedParentUid": string | null, // Primary parent UID (only for delegated)
  "assignedChildren": string[],     // Child IDs this user can manage
  
  // Monitoring preferences (parent only)
  "monitoredChildren": string[],    // Which children to show
  "monitorAll": boolean,            // Show all children
  "parentAccessAll": boolean,       // Can see all activities
  
  // Dashboard settings
  "dashboardCategory": string,      // "baby" | "toddler" | "balita" | "anak" | "remaja"
  "isDashboardLocked": boolean,
  "preferredLandingDashboard": string | null,
  
  // Child-specific
  "umur": number | null,            // Age
  
  // Notification preferences
  "emailNotifications": {
    "weeklyRecap": boolean,
    "deviationAlerts": boolean,
    "immunizationReminders": boolean,
    "milestone_alerts": boolean
  },
  
  // Timestamps
  "created_at": Timestamp,
  "lastUpdated": Timestamp,
  "schemaVersion": number           // Current: 3
}
```

#### 4.2 Child Profiles Collection

Add role relationship:

```javascript
// Location: child_profiles/{childId}
{
  "id": string,                     // Document ID
  "parentId": string,               // Parent UID (FK to users)
  "userId": string | null,          // Child UID if has own account (remaja)
  "name": string,
  "age": number,
  "birthDate": Timestamp,
  "category": string,               // "baby" | "toddler" | "balita" | "anak" | "remaja"
  "photoUrl": string | null,
  "isConnected": boolean,           // Connected to parent
  "managedBy": string[],            // UIDs who can manage this child
  "created_at": Timestamp,
  "updated_at": Timestamp
}
```

---

## 🔄 Implementation Sequence

### Phase 1: Backend Setup
1. Update role constants in `backend/app.py`
2. Add role validation decorator
3. Create delegated parent management endpoints
4. Update data input endpoints with role checks
5. Test with Postman/curl

### Phase 2: Frontend Core Changes
1. Update `RoleSelectionScreen` to show delegated_parent option
2. Update `DashboardGateScreen` routing logic
3. Extend `FiveMenuShell` constructor for role parameters
4. Update Firestore user document schema

### Phase 3: UI Components
1. Create `ParentChildSelectionScreen`
2. Create `DelegatedParentDashboardTab`
3. Create role display widget for menu header
4. Add role-aware input forms

### Phase 4: Security & Rules
1. Update `firestore.rules` with helper functions
2. Add role-based read/write restrictions
3. Test permission scenarios

### Phase 5: Testing & Polish
1. Test role switching
2. Test delegated parent data access
3. Test notification permissions
4. Polish UI/UX

---

## 🧪 Testing Checklist

### Backend
- [ ] Parent can create delegated parent account
- [ ] Parent can update assigned children for delegated parent
- [ ] Delegated parent can only input data for assigned children
- [ ] Child cannot access data input endpoints
- [ ] Role validation works on all protected endpoints

### Frontend
- [ ] RoleSelectionScreen shows 3 role options
- [ ] DashboardGateScreen routes to correct dashboard
- [ ] Parent can select which children to monitor
- [ ] Delegated parent sees assigned children only
- [ ] Child sees minimal dashboard
- [ ] Role switching works correctly

### Security
- [ ] Firestore rules enforce role-based access
- [ ] Delegated parent cannot access unassigned children
- [ ] Child cannot write to other children's data
- [ ] Parent can revoke delegated parent access

---

## 📞 Implementation Support

For each section, refer to:
- Backend: `backend/app.py` (lines indicated)
- Frontend: `lib/features/` and `lib/services/`
- Rules: `firestore.rules`

---

**Last Updated:** May 7, 2026

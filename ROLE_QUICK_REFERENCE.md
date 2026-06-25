# Role Implementation Quick Reference
## Patara AI RBAC System - Developer Cheatsheet

---

## 🚀 Quick Start Implementation

### Step 1: Backend Constants & Helpers (30 min)
**File:** `backend/app.py`

```python
# Add these at the top
VALID_ROLES = {'parent', 'child', 'delegated_parent', 'assistant'}
PARENT_ROLES = {'parent', 'delegated_parent'}
DATA_INPUT_ROLES = {'parent', 'delegated_parent', 'assistant'}

# Copy the validation functions from ROLE_CODE_EXAMPLES.md:
# - require_role decorator
# - _user_can_access_child()
# - _current_user_role()
# - _current_user_uid()
```

**Endpoints to Add:**
- `POST /delegated-parents/create` - Create delegated parent
- `PUT /delegated-parents/<uid>/children` - Update assigned children
- `GET /delegated-parents` - List all delegated parents

---

### Step 2: Frontend Role Selection (45 min)
**File:** `lib/features/role_selection_screen.dart`

Replace existing role selection with 3 options:
1. Orang Tua (Parent) → Orange/Pink
2. Asisten (Delegated Parent) → Orange  
3. Anak (Child) → Purple

Check: ROLE_CODE_EXAMPLES.md for `_RoleSelectionScreenState` implementation

---

### Step 3: Dashboard Routing (30 min)
**File:** `lib/main.dart` → `DashboardGateScreen`

Add role-based routing:
```dart
switch (role) {
  case 'parent':
    return FiveMenuShell(dashboardType: 'parent');
  case 'delegated_parent':
    return FiveMenuShell(dashboardType: 'delegated_parent', 
                         assignedChildren: [from Firestore]);
  case 'child':
    return ChildDashboardScreen(...);
}
```

---

### Step 4: Firestore Security (20 min)
**File:** `firestore.rules`

Add helper functions:
```javascript
function isDataInputRole(uid) {
  let user = get(/databases/$(database)/documents/users/$(uid)).data;
  let role = user.selectedRole ?? user.role ?? 'parent';
  return role in ['parent', 'delegated_parent', 'assistant'];
}

function canAccessChildAsDelegate(uid, childId) {
  let userDoc = get(/databases/$(database)/documents/users/$(uid)).data;
  let assignedChildren = userDoc.assignedChildren ?? [];
  return childId in assignedChildren;
}
```

Update child_profiles rules:
```javascript
match /child_profiles/{childId} {
  allow write: if request.auth != null && (
    request.auth.uid == resource.data.parentId ||
    (isDataInputRole(request.auth.uid) && 
     canAccessChildAsDelegate(request.auth.uid, childId))
  );
}
```

---

### Step 5: Protect Data Endpoints (60 min)
**File:** `backend/app.py`

Add to endpoints:
- `/nutrition/food-intake`
- `/growth/record`
- `/activities`
- Any data input endpoint

Pattern:
```python
@app.post("/endpoint")
@require_auth
@require_role('parent', 'delegated_parent', 'assistant')
def endpoint_name():
    child_id = request.json.get('child_id')
    if not _user_can_access_child(g.current_user['uid'], 
                                   _current_user_role(), 
                                   child_id):
        return jsonify({"error": "No access"}), 403
    # Process data...
```

---

## 📋 File Changes Summary

| File | Changes | Time |
|------|---------|------|
| `backend/app.py` | Add constants, decorators, endpoints | 2 hrs |
| `lib/features/role_selection_screen.dart` | 3-option UI | 45 min |
| `lib/main.dart` | Role routing in DashboardGateScreen | 30 min |
| `firestore.rules` | Role-based access control | 20 min |
| **New:** `lib/features/parent_child_selection_screen.dart` | Parent child selection UI | 45 min |
| **New:** `lib/features/menu/delegated_parent_dashboard_tab.dart` | Delegated parent dashboard | 60 min |
| **New:** `lib/features/menu/delegated_parent_setup_screen.dart` | Delegated parent setup flow | 45 min |

**Total Time:** ~6-7 hours

---

## 🔑 Key Firestore Documents

### User Document (`users/{uid}`)
```javascript
{
  // All roles
  "uid": "firebase_uid",
  "email": "user@example.com",
  "selectedRole": "parent|child|delegated_parent",
  "role": "parent|child|delegated_parent",
  "created_at": Timestamp,
  
  // Parent only
  "monitoredChildren": ["childId1", "childId2"],
  "monitorAll": true,
  "emailNotifications": {...},
  
  // Delegated parent only
  "linkedParentUid": "parent_uid",
  "assignedChildren": ["childId1", "childId3"]
}
```

### Child Profile Document (`child_profiles/{childId}`)
```javascript
{
  "parentId": "parent_uid",  // Always references primary parent
  "managedBy": ["uid1", "uid2"],  // For audit trail
  "name": "Anak 1",
  "age": 5,
  "category": "anak"
}
```

---

## 🧪 Testing Commands

### Test 1: Parent Login
```
1. Login as parent
2. Select "Orang Tua" role
3. Should see 5-menu dashboard with all children
```

### Test 2: Create Delegated Parent
```curl
POST /delegated-parents/create
{
  "email": "asisten@example.com",
  "name": "Asisten Budi",
  "children": ["childId1", "childId2"]
}
```

### Test 3: Delegated Parent Data Input
```curl
POST /nutrition/food-intake
Header: Authorization: Bearer [delegated_parent_token]
{
  "child_id": "childId1",
  "mealType": "lunch",
  "foodItems": [...]
}
✓ Should succeed

POST /nutrition/food-intake
Header: Authorization: Bearer [delegated_parent_token]
{
  "child_id": "childId3",  // NOT assigned
  "mealType": "lunch"
}
✗ Should fail with 403
```

### Test 4: Child Cannot Input
```curl
POST /nutrition/food-intake
Header: Authorization: Bearer [child_token]
✗ Should fail with 403
```

---

## ⚠️ Common Pitfalls

### 1. Forgetting to check `linkedParentUid`
❌ Bad: Allow delegated parent to see all data
✅ Good: Check `assignedChildren` list against child_id

### 2. Not updating Firestore user doc during registration
❌ Bad: User role not persisted
✅ Good: Call `_ensure_firestore_user_profile()` on signup

### 3. Firestore rules not matching backend validation
❌ Bad: Backend says no, but Firestore allows it
✅ Good: Mirror backend role checks in rules

### 4. Not handling dashboard type in FiveMenuShell
❌ Bad: Delegated parent sees all children
✅ Good: Pass `assignedChildren` and filter in tab components

### 5. Child can still access parent endpoints
❌ Bad: No role checking on endpoints
✅ Good: `@require_role('parent', 'delegated_parent')` on protected endpoints

---

## 🔄 Role Transition Flow

### Parent → Delegated Parent (Same User)
```
User with 'parent' role
  ↓
Click "Switch to Asisten" in settings
  ↓
Update selectedRole to 'delegated_parent'
  ↓
Store linkedParentUid = own uid (becomes own delegated account)
  ↓
DashboardGateScreen reroutes to delegated parent dashboard
```

### New Delegated Parent Account
```
Primary parent creates account via API
  ↓
Backend generates Firebase user (email + temp password)
  ↓
Backend creates Firestore doc with linkedParentUid + assignedChildren
  ↓
Delegated parent receives login credentials
  ↓
First login → RoleSelectionScreen (already has delegated_parent role)
  ↓
Direct to delegated parent dashboard
```

---

## 📊 Access Control Matrix

```
Endpoint                    Parent  Child  Delegated  Notes
────────────────────────────────────────────────────────────
POST /nutrition/food-intake   ✅      ❌       ✅     Assigned only
POST /growth/record           ✅      ❌       ✅     Assigned only
POST /activities              ✅      ❌       ✅     Assigned only
GET /analytics/child/:id      ✅      ❌       ✅     Assigned only
POST /delegated-parents/*     ✅      ❌       ❌     Parent only
GET /children                 ✅      ❌       ✅     Assigned only
PUT /child/:id                ✅      ❌       ❌     Parent only
```

---

## 🔐 Security Best Practices

1. **Always verify parent ownership** when delegated parent accesses data
2. **Log who records data** (parent vs delegated_parent) in tracking docs
3. **Delegated parent cannot modify linked_parent_uid** (prevent privilege escalation)
4. **Revoke access atomically** - update assignedChildren array
5. **Check role before processing** request - don't trust frontend

---

## 📱 UI Components to Create

### New Screens
1. `ParentChildSelectionScreen` - Which children to monitor
2. `DelegatedParentSetupScreen` - Setup instructions
3. `DelegatedParentDashboardTab` - Main dashboard
4. `DelegatedParentManagementScreen` - Create/edit delegated accounts (in parent settings)

### Modified Screens
1. `RoleSelectionScreen` - Add delegated_parent button
2. `DashboardGateScreen` - Add role routing
3. `FiveMenuShell` - Accept role parameters
4. `MenuDashboardTab` - Filter by monitored children
5. `MenuAiTab` - Role-aware prompts

---

## 🎯 Implementation Milestones

- [ ] **Day 1-2:** Backend setup (constants, decorators, API endpoints)
- [ ] **Day 2-3:** Firestore rules update
- [ ] **Day 3-4:** Frontend role selection & routing
- [ ] **Day 4-5:** Dashboard implementations
- [ ] **Day 5-6:** Testing & bug fixes
- [ ] **Day 6-7:** Security review & deployment

---

## 📞 Support References

- Full details: `ROLE_BASED_ACCESS_IMPLEMENTATION.md`
- Code examples: `ROLE_CODE_EXAMPLES.md`
- Current structure: `ERD_DATABASE.md`
- Firestore rules: `firestore.rules`

---

**Quick Reference Version:** 1.0  
**Last Updated:** May 7, 2026

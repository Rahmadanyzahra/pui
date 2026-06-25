# Role Implementation Details & Code Examples
## Patara AI RBAC System

---

## 📊 Role Capabilities Matrix

### Feature Access by Role

| Feature | Parent | Child | Delegated Parent |
|---------|--------|-------|-----------------|
| View own dashboard | ✅ Full | ✅ Limited | ✅ Parent-like |
| View children's data | ✅ All | ❌ | ✅ Assigned only |
| Input health data | ✅ | ❌ | ✅ Assigned only |
| Input menu/nutrition | ✅ | ❌ | ✅ Assigned only |
| Input activity/sleep | ✅ | ❌ | ✅ Assigned only |
| View weekly recap | ✅ | ❌ | ✅ (Primary parent retains) |
| Manage child profiles | ✅ | ❌ | ❌ |
| Create delegated accounts | ✅ | ❌ | ❌ |
| Select monitoring children | ✅ | N/A | N/A |
| Edit own profile | ✅ | ✅ | ✅ |

---

## 🔐 Data Access Rules

### Parent Role
```
Can access:
  - All own children's data
  - All family members' activity logs
  - All notifications and recaps
  - Full analytics for all children
  
Cannot:
  - Access other parents' data
  - Override child account access
```

### Child Role
```
Can access:
  - Own profile and milestones
  - Own dashboard (if 'anak' or 'remaja')
  - Own activity logs (limited)
  
Cannot:
  - View other children's data
  - Input data for other children
  - Access parent settings
```

### Delegated Parent Role
```
Can access:
  - Assigned children's data only (specified by primary parent)
  - Input daily tracking for assigned children
  - View assigned children's analytics
  - Receive all notifications (inherited from primary parent)
  
Cannot:
  - Access unassigned children
  - Create new child profiles
  - Create other delegated accounts
  - Manage primary parent settings
```

---

## 🛠️ Implementation Details by Component

### 1. Backend User Profile Management

#### Initialization Function (app.py)
```python
def _ensure_firestore_user_profile(
    uid: str, 
    email: str = "", 
    role: str = "parent",
    linked_parent_uid: str = None
) -> Dict[str, Any]:
    """
    Create or update user profile in Firestore.
    
    Args:
        uid: Firebase UID
        email: User email
        role: User role (parent, child, delegated_parent)
        linked_parent_uid: For delegated parents, their primary parent's UID
    
    Returns:
        User profile dictionary
    """
    db = _bootstrap_firestore()
    if db is None:
        return {
            "uid": uid, 
            "email": email, 
            "role": role,
            "linkedParentUid": linked_parent_uid
        }

    doc_ref = _firestore_user_doc(uid)
    assert doc_ref is not None
    snapshot = doc_ref.get()
    now = _utc_now_iso()

    if not snapshot.exists:
        initial_data = {
            "uid": uid,
            "email": email,
            "role": role,
            "selectedRole": role,
            "created_at": now,
            "lastUpdated": now,
            "schemaVersion": 3,
        }
        
        # Add delegated parent fields if applicable
        if role == "delegated_parent":
            initial_data.update({
                "linkedParentUid": linked_parent_uid,
                "assignedChildren": [],
            })
        
        # Add parent fields
        if role == "parent":
            initial_data.update({
                "monitoredChildren": [],
                "monitorAll": True,
                "parentAccessAll": True,
                "emailNotifications": {
                    "weeklyRecap": True,
                    "deviationAlerts": True,
                    "immunizationReminders": True,
                    "milestone_alerts": True,
                },
            })
        
        doc_ref.set(initial_data, merge=True)
        return initial_data

    data = snapshot.to_dict() or {}
    updates: Dict[str, Any] = {
        "lastUpdated": now,
        "schemaVersion": 3,
    }
    
    if email and not data.get("email"):
        updates["email"] = email
    if role and not data.get("role"):
        updates["role"] = role
        updates["selectedRole"] = role
    
    if updates:
        doc_ref.set(updates, merge=True)
        data.update(updates)

    # Ensure required fields
    data["uid"] = uid
    data.setdefault("email", email)
    data.setdefault("role", role)
    data.setdefault("selectedRole", role)
    data.setdefault("schemaVersion", 3)
    
    return data
```

---

### 2. Role Validation & Decorators

#### Role Checking Functions
```python
VALID_ROLES = {'parent', 'child', 'delegated_parent', 'assistant'}
PARENT_ROLES = {'parent', 'delegated_parent'}
DATA_INPUT_ROLES = {'parent', 'delegated_parent', 'assistant'}

def _current_user_role() -> str:
    """Get current user's role from request context."""
    if hasattr(g, "current_user"):
        role = (g.current_user.get("role") or 
                g.current_user.get("selectedRole") or 
                "parent")
        return str(role).strip().lower() or "parent"
    return "parent"

def _current_user_uid() -> str | None:
    """Get current user's UID."""
    if hasattr(g, "current_user"):
        return g.current_user.get("uid")
    return None

def require_role(*allowed_roles):
    """Decorator to enforce role-based access control."""
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            user_role = _current_user_role()
            if user_role not in allowed_roles:
                return jsonify({
                    "error": "Insufficient permissions",
                    "required_roles": list(allowed_roles),
                    "user_role": user_role
                }), 403
            return f(*args, **kwargs)
        return decorated_function
    return decorator

def require_child_access(get_child_id_func):
    """
    Decorator to verify user has access to specific child.
    
    Args:
        get_child_id_func: Function that returns child_id from request
    """
    def decorator(f):
        @wraps(f)
        def decorated_function(*args, **kwargs):
            child_id = get_child_id_func()
            if not child_id:
                return jsonify({"error": "Child ID required"}), 400
            
            user_uid = _current_user_uid()
            user_role = _current_user_role()
            
            if not _user_can_access_child(user_uid, user_role, child_id):
                return jsonify({
                    "error": "No access to this child",
                    "child_id": child_id
                }), 403
            
            return f(*args, **kwargs)
        return decorated_function
    return decorator

def _user_can_access_child(uid: str, role: str, child_id: str) -> bool:
    """Check if user can access specific child."""
    if role == 'child':
        return False  # Children can't manage other children
    
    db = _bootstrap_firestore()
    if not db:
        return False
    
    child_doc = db.collection('child_profiles').document(child_id).get()
    if not child_doc.exists:
        return False
    
    child_data = child_doc.to_dict() or {}
    
    # Parent can access all their children
    if role == 'parent' and child_data.get('parentId') == uid:
        return True
    
    # Delegated parent can only access assigned children
    if role in ['delegated_parent', 'assistant']:
        user_doc = db.collection('users').document(uid).get()
        if user_doc.exists:
            user_data = user_doc.to_dict() or {}
            assigned = user_data.get('assignedChildren', [])
            return child_id in assigned
    
    return False
```

---

### 3. Delegated Parent Management Endpoints

#### Create Delegated Parent
```python
@app.post("/delegated-parents/create")
@require_auth
@require_role('parent')
def create_delegated_parent():
    """
    Create a new delegated parent account.
    
    Request JSON:
    {
        "email": "assistant@example.com",
        "name": "Assistant Name",
        "children": ["childId1", "childId2"]  # Assigned child IDs
    }
    """
    data = request.json or {}
    delegated_email = data.get('email')
    delegated_name = data.get('name')
    assigned_children = data.get('children', [])
    parent_uid = g.current_user['uid']
    
    if not delegated_email or not delegated_name:
        return jsonify({
            "error": "Email and name are required"
        }), 400
    
    # Verify all children belong to this parent
    db = _bootstrap_firestore()
    for child_id in assigned_children:
        child_doc = db.collection('child_profiles').document(child_id).get()
        if not child_doc.exists:
            return jsonify({
                "error": f"Child {child_id} not found"
            }), 404
        
        child_data = child_doc.to_dict() or {}
        if child_data.get('parentId') != parent_uid:
            return jsonify({
                "error": f"Child {child_id} does not belong to this parent"
            }), 403
    
    try:
        # Create Firebase Auth account for delegated parent
        delegated_user = firebase_auth.create_user(
            email=delegated_email,
            password=data.get('password', ''),
            display_name=delegated_name,
        )
        
        # Create Firestore profile
        db.collection('users').document(delegated_user.uid).set({
            'email': delegated_email,
            'displayName': delegated_name,
            'role': 'delegated_parent',
            'selectedRole': 'delegated_parent',
            'linkedParentUid': parent_uid,
            'assignedChildren': assigned_children,
            'created_at': _utc_now_iso(),
            'lastUpdated': _utc_now_iso(),
            'schemaVersion': 3,
        })
        
        return jsonify({
            'success': True,
            'delegatedParentUid': delegated_user.uid,
            'email': delegated_email,
            'message': 'Delegated parent created successfully'
        }), 201
        
    except firebase_auth.EmailAlreadyExistsError:
        return jsonify({
            "error": "Email already exists"
        }), 409
    except Exception as e:
        return jsonify({
            "error": str(e)
        }), 500
```

#### Update Delegated Parent's Children
```python
@app.put("/delegated-parents/<delegated_uid>/children")
@require_auth
@require_role('parent')
def update_delegated_parent_children(delegated_uid):
    """
    Update which children a delegated parent can manage.
    
    Request JSON:
    {
        "children": ["childId1", "childId2", "childId3"]
    }
    """
    data = request.json or {}
    assigned_children = data.get('children', [])
    parent_uid = g.current_user['uid']
    
    db = _bootstrap_firestore()
    
    # Verify delegated parent belongs to this parent
    delegated_doc = db.collection('users').document(delegated_uid).get()
    if not delegated_doc.exists:
        return jsonify({"error": "Delegated parent not found"}), 404
    
    delegated_data = delegated_doc.to_dict() or {}
    if delegated_data.get('linkedParentUid') != parent_uid:
        return jsonify({
            "error": "This delegated parent does not belong to you"
        }), 403
    
    # Verify all children belong to this parent
    for child_id in assigned_children:
        child_doc = db.collection('child_profiles').document(child_id).get()
        if not child_doc.exists:
            return jsonify({
                "error": f"Child {child_id} not found"
            }), 404
        
        child_data = child_doc.to_dict() or {}
        if child_data.get('parentId') != parent_uid:
            return jsonify({
                "error": f"Child {child_id} does not belong to you"
            }), 403
    
    # Update assigned children
    db.collection('users').document(delegated_uid).set({
        'assignedChildren': assigned_children,
        'lastUpdated': _utc_now_iso(),
    }, merge=True)
    
    return jsonify({
        'success': True,
        'assignedChildren': assigned_children,
        'message': 'Assigned children updated successfully'
    }), 200

# List delegated parents for current parent
@app.get("/delegated-parents")
@require_auth
@require_role('parent')
def list_delegated_parents():
    """Get all delegated parents created by current parent."""
    parent_uid = g.current_user['uid']
    db = _bootstrap_firestore()
    
    query = db.collection('users').where(
        'linkedParentUid', '==', parent_uid
    ).where(
        'role', '==', 'delegated_parent'
    )
    
    delegated = []
    for doc in query.stream():
        data = doc.to_dict() or {}
        delegated.append({
            'uid': doc.id,
            'email': data.get('email'),
            'displayName': data.get('displayName'),
            'assignedChildren': data.get('assignedChildren', []),
            'created_at': data.get('created_at'),
        })
    
    return jsonify({
        'delegatedParents': delegated,
        'count': len(delegated)
    }), 200
```

---

### 4. Protected Data Input Endpoints

#### Food Intake Endpoint (with role check)
```python
@app.post("/nutrition/food-intake")
@require_auth
@require_role('parent', 'delegated_parent', 'assistant')
def post_nutrition_food_intake():
    """
    Record food intake for a child.
    Only parent and delegated parent can access.
    """
    data = request.json or {}
    child_id = data.get('child_id')
    uid = g.current_user['uid']
    user_role = _current_user_role()
    
    if not child_id:
        return jsonify({"error": "child_id is required"}), 400
    
    # Verify access to this child
    if not _user_can_access_child(uid, user_role, child_id):
        return jsonify({
            "error": "No access to this child"
        }), 403
    
    # Process food intake
    nutrition_data = {
        'childId': child_id,
        'date': data.get('date', _utc_now_iso()),
        'mealType': data.get('mealType'),  # breakfast, lunch, dinner, snack
        'foodItems': data.get('foodItems', []),
        'notes': data.get('notes'),
        'recordedBy': uid,  # Track who recorded
        'recordedByRole': user_role,
        'timestamp': _utc_now_iso(),
    }
    
    db = _bootstrap_firestore()
    doc_ref = db.collection('child_profiles').document(child_id).collection(
        'nutrition'
    ).add(nutrition_data)
    
    return jsonify({
        'success': True,
        'foodIntakeId': doc_ref[1].id,
        'message': 'Food intake recorded successfully'
    }), 201

# Similar pattern for /growth/record, /activities, etc.
@app.post("/growth/record")
@require_auth
@require_role('parent', 'delegated_parent', 'assistant')
def post_growth_record():
    """Record growth measurement for a child."""
    data = request.json or {}
    child_id = data.get('child_id')
    uid = g.current_user['uid']
    user_role = _current_user_role()
    
    if not _user_can_access_child(uid, user_role, child_id):
        return jsonify({"error": "No access to this child"}), 403
    
    # Record height, weight, head circumference
    growth_data = {
        'childId': child_id,
        'date': data.get('date', _utc_now_iso()),
        'height': data.get('height'),
        'weight': data.get('weight'),
        'headCircumference': data.get('headCircumference'),
        'recordedBy': uid,
        'recordedByRole': user_role,
        'timestamp': _utc_now_iso(),
    }
    
    db = _bootstrap_firestore()
    db.collection('child_profiles').document(child_id).collection(
        'growth'
    ).add(growth_data)
    
    return jsonify({
        'success': True,
        'message': 'Growth record added'
    }), 201
```

---

### 5. Flutter Implementation - Role Selection

#### Enhanced RoleSelectionScreen
```dart
class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  bool _isLoading = false;

  Future<void> _selectRole(String role) async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Save role selection to Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'email': user.email,
        'selectedRole': role,
        'role': role,
        'lastUpdated': FieldValue.serverTimestamp(),
        
        // Role-specific fields
        if (role == 'parent') ...{
          'monitoredChildren': [],
          'monitorAll': true,
          'parentAccessAll': true,
          'emailNotifications': {
            'weeklyRecap': true,
            'deviationAlerts': true,
            'immunizationReminders': true,
            'milestone_alerts': true,
          },
        },
        
        if (role == 'delegated_parent') ...{
          'linkedParentUid': null,  // Will be set by parent
          'assignedChildren': [],
        },
        
        if (role == 'child') ...{
          'umur': null,
          'dashboardCategory': null,
          'isDashboardLocked': false,
        },
      }, SetOptions(merge: true));

      if (!mounted) return;
      
      // Navigate to next screen based on role
      if (role == 'parent') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const ParentChildSelectionScreen(),
          ),
        );
      } else if (role == 'child') {
        await _selectChildRole();
      } else if (role == 'delegated_parent') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const DelegatedParentSetupScreen(),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih Role'),
        centerTitle: true,
      ),
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
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Pilih role Anda untuk melanjutkan',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                
                // Parent Role
                _RoleCard(
                  icon: Icons.person,
                  title: 'Orang Tua',
                  description: 'Pantau perkembangan anak, recap mingguan, notifikasi',
                  color: const Color(0xFFEC407A),
                  onTap: _isLoading ? null : () => _selectRole('parent'),
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 16),
                
                // Delegated Parent Role
                _RoleCard(
                  icon: Icons.supervisor_account,
                  title: 'Asisten / Pendamping',
                  description: 'Input data harian, pantau anak tertentu',
                  color: const Color(0xFFFF7043),
                  onTap: _isLoading ? null : () => _selectRole('delegated_parent'),
                  isLoading: _isLoading,
                ),
                const SizedBox(height: 16),
                
                // Child Role
                _RoleCard(
                  icon: Icons.child_care,
                  title: 'Anak',
                  description: 'Lihat profil & milestone sendiri',
                  color: const Color(0xFFBA68C8),
                  onTap: _isLoading ? null : _selectChildRole,
                  isLoading: _isLoading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback? onTap;
  final bool isLoading;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: isLoading ? null : onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.8),
                color,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
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
              if (isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 2,
                  ),
                )
              else
                const Icon(Icons.arrow_forward, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
```

---

## 🔗 Relationship Diagrams

### Role Hierarchy
```
Primary Parent (uid1)
    ├── Child Profile 1 (4 years old)
    ├── Child Profile 2 (10 years old)
    │   └── Has Firebase Account (remaja, uid2)
    ├── Child Profile 3 (1 year old)
    └── Delegated Parents
        ├── Asisten A (uid3)
        │   - Can manage Child 1 & 3
        │   - Receives all notifications
        │   └── Can input data for Child 1 & 3
        └── Asisten B (uid4)
            - Can manage Child 2
            - Receives all notifications
            └── Can input data for Child 2
```

### Data Access Flow
```
Request from uid3 (Delegated Parent A)
    ↓
Check Authentication (Firebase token)
    ↓
Check Role: delegated_parent ✓
    ↓
Check Child Access: is child in assignedChildren? ✓
    ↓
Allow: Input data to Child 1 & 3
Block: Cannot create child profiles
Block: Cannot access Child 2 data
```

---

## ✅ Validation Checklist

### Backend
- [ ] All new endpoints accept `delegated_parent` role
- [ ] Decorators enforce role checks
- [ ] Child access verification works
- [ ] Delegated parents can't access unassigned children
- [ ] Children can't input data

### Frontend  
- [ ] RoleSelectionScreen shows all 3 role options
- [ ] Role selection saves to Firestore correctly
- [ ] DashboardGateScreen routes based on role
- [ ] Delegated parent dashboard filters children correctly
- [ ] Parent can select which children to monitor

### Security
- [ ] Firestore rules match backend validation
- [ ] No SQL injection possible
- [ ] Delegated parent can't modify `linkedParentUid`
- [ ] Can't escalate privileges

---

**Document Version:** 1.0  
**Last Updated:** May 7, 2026

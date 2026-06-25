# JWT Migration Checklist for Flutter/Dart Client

## Phase 1: Preparation ✅
- [x] Analyze current token handling in app
- [x] Understand new JWT token flow
- [x] Plan migration strategy

## Phase 2: Backend Implementation ✅
- [x] Add jsonwebtoken dependency
- [x] Create JWT utilities (jwt_auth.js)
- [x] Update authentication middleware
- [x] Update login endpoint
- [x] Update register endpoint
- [x] Add /api/refresh endpoint
- [x] Add JWT documentation
- [x] Test JWT implementation

## Phase 3: Frontend Updates (TODO)

### 3.1 Update BackendApiService
Location: `lib/services/backend_api_service.dart`

Tasks:
- [ ] Update token extraction logic to handle both `token` and `access_token`
- [ ] Store both `access_token` and `refresh_token` in FlutterSecureStorage
- [ ] Add refresh token expiry calculation (7 days from now)
- [ ] Update headers to use `access_token` instead of generic `token`

Example changes:
```dart
// OLD
final token = response['token'];
await storage.write(key: 'session_token', value: token);

// NEW  
final accessToken = response['access_token'];
final refreshToken = response['refresh_token'];
await storage.write(key: 'access_token', value: accessToken);
await storage.write(key: 'refresh_token', value: refreshToken);

// Calculate expiry times
final now = DateTime.now();
await storage.write(
  key: 'access_token_expiry',
  value: now.add(Duration(minutes: 15)).toIso8601String(),
);
await storage.write(
  key: 'refresh_token_expiry', 
  value: now.add(Duration(days: 7)).toIso8601String(),
);
```

### 3.2 Implement Token Refresh Logic
Location: `lib/services/backend_api_service.dart`

Tasks:
- [ ] Add `refreshAccessToken()` method
- [ ] Detect 401 responses and auto-refresh
- [ ] Retry failed requests with new token
- [ ] Handle refresh token expiry (redirect to login)

Example:
```dart
Future<String> _getValidAccessToken() async {
  final storage = FlutterSecureStorage();
  var token = await storage.read(key: 'access_token');
  final expiryStr = await storage.read(key: 'access_token_expiry');
  
  if (expiryStr != null) {
    final expiry = DateTime.parse(expiryStr);
    if (DateTime.now().isAfter(expiry)) {
      // Token expired, refresh it
      token = await refreshAccessToken();
    }
  }
  
  return token ?? '';
}

Future<String?> refreshAccessToken() async {
  final storage = FlutterSecureStorage();
  final refreshToken = await storage.read(key: 'refresh_token');
  
  if (refreshToken == null) {
    // No refresh token, redirect to login
    return null;
  }
  
  try {
    final response = await http.post(
      Uri.parse('$backendApiUrl/api/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'refresh_token': refreshToken}),
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      await storage.write(
        key: 'access_token',
        value: data['access_token'],
      );
      await storage.write(
        key: 'refresh_token',
        value: data['refresh_token'],
      );
      return data['access_token'];
    }
  } catch (e) {
    print('Error refreshing token: $e');
  }
  
  return null;
}
```

### 3.3 Handle 401 Responses
Location: All HTTP request methods in `BackendApiService`

Tasks:
- [ ] Wrap requests in try-catch
- [ ] Detect 401 status code
- [ ] Call token refresh if 401
- [ ] Retry request with new token
- [ ] If refresh fails, redirect to login

Example:
```dart
Future<Map<String, dynamic>?> _makeRequest(
  String method,
  String endpoint, {
  Map<String, dynamic>? body,
}) async {
  try {
    var token = await _getValidAccessToken();
    if (token == null) {
      // Redirect to login
      _handleUnauthorized();
      return null;
    }
    
    // First attempt
    final response = await _doRequest(method, endpoint, body, token);
    
    if (response.statusCode == 401) {
      // Token might be expired, try refresh
      final newToken = await refreshAccessToken();
      if (newToken != null) {
        // Retry with new token
        return await _doRequest(method, endpoint, body, newToken);
      } else {
        _handleUnauthorized();
        return null;
      }
    }
    
    return _parseResponse(response);
  } catch (e) {
    print('Request error: $e');
    return null;
  }
}
```

### 3.4 Update Login/Register Screens
Location: `lib/features/auth/login_screen.dart` and `register_screen.dart`

Tasks:
- [ ] Extract both tokens from response
- [ ] Store tokens with expiry times
- [ ] Show success message
- [ ] Navigate to next screen

### 3.5 Update Logout
Location: `lib/services/backend_api_service.dart` and auth screens

Tasks:
- [ ] Clear both `access_token` and `refresh_token`
- [ ] Clear expiry time keys
- [ ] Call logout endpoint if needed
- [ ] Clear app state/cached data

Example:
```dart
Future<void> logout() async {
  try {
    final token = await storage.read(key: 'access_token');
    if (token != null) {
      await http.post(
        Uri.parse('$backendApiUrl/api/logout'),
        headers: {'Authorization': 'Bearer $token'},
      );
    }
  } catch (e) {
    print('Logout error: $e');
  } finally {
    // Clear tokens
    await storage.delete(key: 'access_token');
    await storage.delete(key: 'refresh_token');
    await storage.delete(key: 'access_token_expiry');
    await storage.delete(key: 'refresh_token_expiry');
    await storage.delete(key: 'user_id');
  }
}
```

### 3.6 Add Token Validation
Location: `lib/services/backend_api_service.dart`

Tasks:
- [ ] Add method to check if tokens exist
- [ ] Add method to check if access token expired
- [ ] Add method to get current user info from JWT
- [ ] Add app startup check for valid tokens

Example:
```dart
Future<bool> hasValidToken() async {
  final token = await storage.read(key: 'access_token');
  if (token == null) return false;
  
  final expiryStr = await storage.read(key: 'access_token_expiry');
  if (expiryStr == null) return false;
  
  final expiry = DateTime.parse(expiryStr);
  return DateTime.now().isBefore(expiry);
}

Future<void> validateTokenOnAppStart() async {
  final hasToken = await hasValidToken();
  if (!hasToken) {
    final refreshToken = await storage.read(key: 'refresh_token');
    if (refreshToken != null) {
      // Try to refresh
      await refreshAccessToken();
    } else {
      // No tokens, redirect to login
      _handleUnauthorized();
    }
  }
}
```

### 3.7 Error Handling
Location: Throughout app

Tasks:
- [ ] Handle 401 Unauthorized responses
- [ ] Handle token refresh failures
- [ ] Handle network errors during refresh
- [ ] Provide user feedback (retry, login, etc)
- [ ] Log errors for debugging

### 3.8 Testing
Tasks:
- [ ] Test login with new JWT tokens
- [ ] Test token refresh before expiry
- [ ] Test auto-refresh on 401 response
- [ ] Test logout clears tokens
- [ ] Test app startup with expired token
- [ ] Test app startup with expired refresh token
- [ ] Test concurrent requests during token refresh
- [ ] Test offline scenarios

## Phase 4: Deployment

### 4.1 Staging Environment
- [ ] Deploy backend with JWT changes
- [ ] Update Flutter app with new token handling
- [ ] Test full flow end-to-end
- [ ] Monitor token refresh patterns
- [ ] Check for any 401 errors
- [ ] Verify performance (no delays during token refresh)

### 4.2 Production Deployment
- [ ] Backup current production database
- [ ] Deploy backend with JWT support
- [ ] Deploy updated Flutter app
- [ ] Monitor error logs
- [ ] Check login/register success rates
- [ ] Monitor token refresh frequency
- [ ] Verify no increased 401 errors

### 4.3 Rollback Plan
- [ ] Keep old session token functions in backend
- [ ] Have previous app version ready in stores
- [ ] Document rollback procedure
- [ ] Monitor for critical issues

## Phase 5: Cleanup (Post-Deployment)

Tasks (1-2 weeks after deployment):
- [ ] Verify no old token handling in app
- [ ] Monitor database for unused `sessions` table
- [ ] Remove old session functions from backend (if full migration complete)
- [ ] Update documentation
- [ ] Remove deprecated code
- [ ] Optimize token refresh logic based on production data

## Files to Modify

1. **lib/services/backend_api_service.dart** (MAIN)
   - Token handling
   - JWT verification
   - Auto-refresh logic
   - Error handling

2. **lib/features/auth/login_screen.dart**
   - Store new JWT tokens
   - Handle token expiry
   - Success message

3. **lib/features/auth/register_screen.dart**
   - Store new JWT tokens
   - Handle token expiry
   - Success message

4. **lib/main.dart**
   - App startup token validation
   - Redirect to login if no valid token

5. **lib/services/secure_storage_service.dart** (if exists)
   - Key names for new tokens
   - Expiry management

## Key Differences: Session → JWT

| Aspect | Session Token | JWT |
|--------|---------------|-----|
| Storage | `session_token` | `access_token` + `refresh_token` |
| Lifetime | No auto-expiry | 15 min + 7 day |
| Refresh | Manual logout required | Auto-refresh |
| Endpoint | (none) | POST /api/refresh |
| Error Handling | Simple 401 | 401 + auto-retry |
| Storage Keys | 1 key | 3 keys (token + 2 expiries) |

## Support

Questions? Check:
- Backend: `JWT_IMPLEMENTATION.md`
- Summary: `JWT_UPGRADE_SUMMARY.md`
- Backend code: `jwt_auth.js` in backend/node_backend/

---

**Status**: Implementation guide ready
**Estimated Time**: 4-6 hours for complete migration
**Priority**: High (security improvement)

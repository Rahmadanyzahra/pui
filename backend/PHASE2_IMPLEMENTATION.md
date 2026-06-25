# Phase 2 Implementation - Growth & Nutrition Tracking

> LEGACY NOTE: Dokumen ini arsip implementasi Python/Flask lama. Backend aktif saat ini adalah Node.js di `backend/node_backend`.

> ACTIVE BACKEND: The implementation has been migrated to Node.js. For the current runtime, see `backend/node_backend` — start with `cd backend/node_backend && npm install && npm start`. The content below is an archived Python reference retained for historical/context purposes.

## Overview

Phase 2 adds comprehensive pediatric health tracking features to Patara AI:
- **Growth Tracking**: Record and analyze child growth using WHO standards
- **Nutrition Monitoring**: Log food intake and validate against age-based recommendations
- **Automated Weekly Recaps**: Generate and send weekly summaries to parents
- **Email Notifications**: Parent notification system with preferences
- **Login Security**: Math captcha for enhanced authentication

## Architecture

### New Dependencies / Notes
- Active implementation uses Node.js (see `backend/node_backend`)
- Key Node dependencies: `express`, `dotenv`, `sqlite3`, `cors`, `uuid`, `bcrypt`
- Legacy Python references (Flask, ReportLab) are archived and kept for historical reference

### New Database Tables

#### 1. `growth_records`
Stores growth measurements for each child:
```sql
CREATE TABLE growth_records (
    id INTEGER PRIMARY KEY,
    child_id INTEGER NOT NULL,
    parent_id INTEGER NOT NULL,
    height_cm REAL,
    weight_kg REAL,
    head_circumference_cm REAL,
    immunization_notes TEXT,
    milestones_notes TEXT,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(child_id) REFERENCES child(id),
    FOREIGN KEY(parent_id) REFERENCES user(id)
)
```

#### 2. `food_intake`
Logs food consumption with nutritional values:
```sql
CREATE TABLE food_intake (
    id INTEGER PRIMARY KEY,
    child_id INTEGER NOT NULL,
    parent_id INTEGER NOT NULL,
    food_name TEXT NOT NULL,
    quantity_grams REAL,
    meal_type TEXT,
    calories REAL,
    protein_g REAL,
    carbs_g REAL,
    fat_g REAL,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(child_id) REFERENCES child(id),
    FOREIGN KEY(parent_id) REFERENCES user(id)
)
```

#### 3. `email_preferences`
User notification preferences:
```sql
CREATE TABLE email_preferences (
    id INTEGER PRIMARY KEY,
    user_id INTEGER UNIQUE,
    email TEXT NOT NULL,
    weekly_recap BOOLEAN DEFAULT 1,
    alerts BOOLEAN DEFAULT 1,
    notify_deviations BOOLEAN DEFAULT 1,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(user_id) REFERENCES user(id)
)
```

#### 4. `weekly_recap`
Stores generated weekly summaries:
```sql
CREATE TABLE weekly_recap (
    id INTEGER PRIMARY KEY,
    child_id INTEGER NOT NULL,
    parent_id INTEGER NOT NULL,
    user_email TEXT,
    growth_summary TEXT,
    nutrition_summary TEXT,
    milestones TEXT,
    alerts TEXT,
    sent_at TEXT DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(child_id) REFERENCES child(id),
    FOREIGN KEY(parent_id) REFERENCES user(id)
)
```

### New Modules

#### 1. `growth_tracker.py`
**Functions:**
- `calculate_age_in_months(birth_date)` - Age calculation
- `calculate_age_in_years(birth_date)` - Age in years
- `calculate_bmi(weight_kg, height_cm)` - BMI computation
- `get_percentile(value, p3, p50, p97)` - Percentile categorization
- `assess_growth(age_years, height_cm, weight_kg)` - WHO-based assessment
- `get_expected_milestones(age_years)` - Developmental milestones
- `create_growth_record()` - Database record creation
- `get_growth_records()` - Retrieve growth history

**Standards:**
- Height-for-age percentiles (WHO) for ages 1-5 years
- Weight-for-age percentiles (WHO) for ages 1-5 years  
- BMI-for-age percentiles (WHO) for ages 1-5 years
- Developmental milestones for ages 1-5

#### 2. `nutrition_tracker.py`
**Functions:**
- `get_food_nutrition(food_name, quantity_grams)` - Nutritional values
- `get_daily_nutrition(db_path, child_id, date)` - Daily aggregation
- `validate_nutrition(age_years, weight_kg, daily_nutrition)` - Recommendation validation
- `create_food_intake()` - Log food consumption
- `get_food_list()` - Available foods

**Food Database:**
20+ common Indonesian foods with complete nutritional profiles:
- Rice, chicken, fish, eggs
- Vegetables: carrots, spinach, broccoli, tomatoes
- Fruits: bananas, apples, oranges, papaya
- Dairy: milk, yogurt, cheese
- Legumes: beans, peanuts, tofu

**Age-Based Recommendations (ages 1-10):**
- Calorie targets
- Protein requirements (g/kg body weight)
- Carbohydrate and fat distribution

#### 3. `email_service.py`
**Functions:**
- `send_email(to, subject, body, is_html)` - Generic email sender
- `send_weekly_recap(recipient_email, child_name, growth_summary, nutrition_summary, alerts)` - Professional recap email
- `send_alert_notification()` - Alert emails for deviations

**Configuration (Environment Variables):**
```
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587
SENDER_EMAIL=your-email@gmail.com
SENDER_PASSWORD=your-app-password
```

#### 4. `captcha_service.py`
**Functions:**
- `generate_login_captcha()` - Generate math captcha
- `verify_login_captcha(session_id, answer)` - Verify answer
- `get_captcha_service()` - Get service instance

**Features:**
- Simple math problems (addition)
- Session tracking with attempt limits
- 3 attempts per captcha
- Session auto-cleanup on expiry

## API Endpoints

### Growth Tracking

#### Record Growth
```
POST /growth/record
Content-Type: application/json
Authorization: Bearer {token}

{
    "child_id": 123,
    "height_cm": 95.5,
    "weight_kg": 14.2,
    "head_circumference_cm": 48.0,
    "immunization_notes": "DPT-3 received",
    "milestones_notes": "Can walk independently"
}

Response: 201 Created
{
    "message": "Pertumbuhan tercatat",
    "record": {...},
    "assessment": {
        "height_status": "normal",
        "weight_status": "normal",
        "bmi_status": "normal",
        "warnings": []
    }
}
```

#### Get Growth Records
```
GET /growth/records/{child_id}
Authorization: Bearer {token}

Response: 200 OK
{
    "child_id": 123,
    "child_name": "Budi",
    "records": [
        {
            "height_cm": 95.5,
            "weight_kg": 14.2,
            "created_at": "2024-01-15T10:30:00Z"
        }
    ],
    "latest_assessment": {...}
}
```

### Nutrition Tracking

#### Get Available Foods
```
GET /nutrition/foods
Authorization: Bearer {token}

Response: 200 OK
{
    "foods": ["nasi putih", "ayam", "telur", ...],
    "count": 24
}
```

#### Record Food Intake
```
POST /nutrition/food-intake
Content-Type: application/json
Authorization: Bearer {token}

{
    "child_id": 123,
    "food_name": "nasi putih",
    "quantity_grams": 100,
    "meal_type": "main"
}

Response: 201 Created
{
    "message": "Asupan makanan tercatat",
    "intake": {
        "food_name": "nasi putih",
        "quantity_grams": 100,
        "calories": 130.0,
        "protein_g": 2.7,
        "carbs_g": 28.0,
        "fat_g": 0.3
    }
}
```

#### Get Daily Nutrition Analysis
```
GET /nutrition/daily-analysis/{child_id}/{date}
Authorization: Bearer {token}

Response: 200 OK
{
    "date": "2024-01-15",
    "daily_nutrition": {
        "total_calories": 1200,
        "total_protein": 35,
        "total_carbs": 150,
        "total_fat": 30
    },
    "validation": {
        "calories": {
            "status": "normal",
            "percentage": 95
        },
        "protein": {
            "status": "below_recommended",
            "percentage": 85,
            "alert": "Asupan protein 15% di bawah rekomendasi"
        }
    }
}
```

### Email Notifications

#### Set Email Preferences
```
POST /notifications/email-preferences
Content-Type: application/json
Authorization: Bearer {token}

{
    "weekly_recap": true,
    "alerts": true,
    "notify_deviations": true
}

Response: 200 OK
{
    "message": "Preferensi email diperbarui",
    "preferences": {...}
}
```

#### Get Email Preferences
```
GET /notifications/email-preferences
Authorization: Bearer {token}

Response: 200 OK
{
    "user_id": 1,
    "email": "parent@example.com",
    "weekly_recap": true,
    "alerts": true,
    "notify_deviations": true
}
```

### Captcha Security

#### Get Captcha Challenge
```
GET /auth/captcha

Response: 200 OK
{
    "session_id": "abc123def456...",
    "question": "23 + 45 = ?"
}
```

#### Verify Captcha
```
POST /auth/captcha/verify
Content-Type: application/json

{
    "session_id": "abc123def456...",
    "answer": "68"
}

Response: 200 OK
{
    "valid": true,
    "message": "Captcha benar"
}
```

#### Login with Captcha
```
POST /login
Content-Type: application/json

{
    "email": "parent@example.com",
    "password": "secure_password",
    "captcha_session_id": "abc123def456...",
    "captcha_answer": "68"
}

Response: 200 OK
{
    "message": "Login berhasil",
    "token": "eyJ0eXAiOiJKV1QiLCJhbGc...",
    "user_id": 1
}
```

## Automated Weekly Recap

### Scheduler Configuration
- **Trigger:** Every 7 days
- **Time:** UTC (default at 9 AM UTC)
- **Scope:** Children with `weekly_recap = true` in email_preferences

### Recap Contents
1. **Growth Summary**: Latest height, weight, and assessment
2. **Nutrition Summary**: Average daily intake for past 7 days
3. **Milestones**: Recent developmental milestones
4. **Alerts**: Any deviations from recommendations

### Implementation
```python
# Backend automatically starts scheduler on app startup
if __name__ == "__main__":
    _init_db()
    
    if scheduler is not None:
        scheduler.add_job(send_weekly_recaps, 'interval', days=7, id='weekly_recap_job')
        scheduler.start()
    
    app.run(host=host, port=port, debug=True)
```

## Environment Configuration

Create `.env` file in backend directory:
```
# Email Configuration
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587
SENDER_EMAIL=your-email@gmail.com
SENDER_PASSWORD=your-app-password

# Optional: Firebase
FIREBASE_CREDENTIALS_PATH=parata-2e653-firebase-adminsdk-fbsvc-3f9269be1c.json

# Optional: App configuration
PATARA_HOST=0.0.0.0
PATARA_PORT=5000
PATARA_FRONTEND_APP_URL=http://192.168.1.4:5174
```

## Client Implementation Guide

### For Flutter/Frontend:

1. **Before Login** - Get Captcha:
```dart
final response = await http.get(
  Uri.parse('$backendUrl/auth/captcha'),
);
final captchaData = jsonDecode(response.body);
// Show question to user
```

2. **User Answers Captcha** - Verify:
```dart
final verifyResponse = await http.post(
  Uri.parse('$backendUrl/auth/captcha/verify'),
  body: jsonEncode({
    'session_id': captchaData['session_id'],
    'answer': userAnswer,
  }),
);
```

3. **Proceed with Login**:
```dart
final loginResponse = await http.post(
  Uri.parse('$backendUrl/login'),
  body: jsonEncode({
    'email': email,
    'password': password,
    'captcha_session_id': captchaData['session_id'],
    'captcha_answer': userAnswer,
  }),
);
```

4. **Record Growth**:
```dart
await http.post(
  Uri.parse('$backendUrl/growth/record'),
  headers: {'Authorization': 'Bearer $token'},
  body: jsonEncode({
    'child_id': childId,
    'height_cm': 95.5,
    'weight_kg': 14.2,
    'head_circumference_cm': 48.0,
    'immunization_notes': 'DPT-3',
    'milestones_notes': 'Can walk',
  }),
);
```

5. **Record Food Intake**:
```dart
await http.post(
  Uri.parse('$backendUrl/nutrition/food-intake'),
  headers: {'Authorization': 'Bearer $token'},
  body: jsonEncode({
    'child_id': childId,
    'food_name': 'nasi putih',
    'quantity_grams': 100,
    'meal_type': 'main',
  }),
);
```

6. **Set Email Preferences**:
```dart
await http.post(
  Uri.parse('$backendUrl/notifications/email-preferences'),
  headers: {'Authorization': 'Bearer $token'},
  body: jsonEncode({
    'weekly_recap': true,
    'alerts': true,
    'notify_deviations': true,
  }),
);
```

## Security Considerations

1. **Password Hashing**: Existing `check_password_hash()` continues for local auth
2. **Captcha**: Simple math captcha prevents automated login attempts
3. **Email Validation**: `email-validator` library validates email format
4. **Rate Limiting**: Use `Flask-Limiter` for endpoint protection
5. **Firebase**: Optional for additional OAuth/2FA support

## Error Handling

All endpoints return appropriate HTTP status codes:
- `400`: Bad request (missing/invalid parameters)
- `401`: Authentication failed (wrong password/captcha)
- `403`: Forbidden (insufficient permissions)
- `404`: Resource not found (child not found)
- `500`: Server error
- `503`: Service unavailable (dependency not installed)

## Performance Optimization

1. **Database Indices**: Consider adding indexes:
   ```sql
   CREATE INDEX idx_growth_records_child_id ON growth_records(child_id);
   CREATE INDEX idx_food_intake_child_date ON food_intake(child_id, DATE(created_at));
   CREATE INDEX idx_email_preferences_user ON email_preferences(user_id);
   ```

2. **Query Limits**: 
   - Growth records limited to 52 weeks (1 year) by default
   - Daily nutrition calculated on-demand

3. **Scheduler**: Runs on 7-day interval (configurable)

## Testing

### Test Growth Tracking:
```bash
# Record measurement
curl -X POST http://localhost:5000/growth/record \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "child_id": 1,
    "height_cm": 95.5,
    "weight_kg": 14.2,
    "head_circumference_cm": 48.0
  }'

# Get records
curl -X GET http://localhost:5000/growth/records/1 \
  -H "Authorization: Bearer TOKEN"
```

### Test Nutrition Tracking:
```bash
# Record food
curl -X POST http://localhost:5000/nutrition/food-intake \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "child_id": 1,
    "food_name": "nasi putih",
    "quantity_grams": 100,
    "meal_type": "main"
  }'

# Get foods list
curl -X GET http://localhost:5000/nutrition/foods \
  -H "Authorization: Bearer TOKEN"
```

### Test Captcha:
```bash
# Get captcha
curl -X GET http://localhost:5000/auth/captcha

# Verify captcha
curl -X POST http://localhost:5000/auth/captcha/verify \
  -H "Content-Type: application/json" \
  -d '{
    "session_id": "...",
    "answer": "68"
  }'
```

## Troubleshooting (Node backend)

1. **"Growth tracking tidak tersedia"**: Check `backend/node_backend` for the growth endpoints and ensure the Node server is running (`npm run dev` or `npm start`).
2. **Email not sending**: Check SMTP credentials in `backend/node_backend/.env` and restart the Node server.
3. **Scheduler not running**: Verify the Node scheduler/cron job is configured and server process is active; check logs in `backend/node_backend`.
4. **Captcha always fails**: Verify captcha endpoints in `backend/node_backend` and check request/response logs.
5. **Database errors**: Ensure migrations/initialization ran (`backend/node_backend/db.js`) and the SQLite DB exists or MySQL is available if configured.

## Future Enhancements

1. **Graph Generation**: Use matplotlib/plotly for visual growth charts
2. **PDF Reports**: Extend the Node PDF generation code in `backend/node_backend` (e.g., pdfkit/pdfmake or custom renderer) for nutrition summaries
3. **AI Analysis**: Integrate with AI module for personalized recommendations
4. **SMS Notifications**: Add SMS option for non-email users
5. **Batch Operations**: Allow bulk growth record imports
6. **Advanced Captcha**: Replace math captcha with image CAPTCHA or reCAPTCHA
7. **Multi-language Support**: Localize validation messages
8. **Mobile Push**: Send push notifications alongside email

## Version History

- **v2.0** (Current): Growth tracking, nutrition monitoring, weekly recaps, email notifications, captcha
- **v1.0**: Monthly PDF recaps, monthly analytics

## Support & Documentation

For more details:
- Growth standards: [WHO Child Growth Standards](https://www.who.int/childgrowth/)
- Food nutrition: See `FOOD_DATABASE` in `nutrition_tracker.py`
- Email templates: See `email_service.py`
- API schemas: See endpoint documentation above

# PHASE 2 QUICK START GUIDE

> LEGACY NOTE: Dokumen ini arsip implementasi Python/Flask lama. Backend aktif saat ini adalah Node.js di `backend/node_backend`.

## What's New

Patara AI now includes:
1. **Growth Tracking** - Record height, weight, head circumference using WHO standards
2. **Nutrition Monitoring** - Log food intake and track daily nutrition vs. recommendations
3. **Weekly Automated Recaps** - Automatic email summaries every 7 days
4. **Email Notifications** - Configurable parent notifications
5. **Enhanced Login Security** - Math captcha for authentication

## Installation & Setup

### 1. Install Dependencies
```bash
cd backend/node_backend
npm install
```

### 2. Set Up Environment Variables
Create `.env` file in backend directory:
```
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587
SENDER_EMAIL=your-email@gmail.com
SENDER_PASSWORD=your-app-password
```

### 3. Run Backend
```bash
# development (auto-reload):
cd backend/node_backend && npm run dev
# production / default:
cd backend/node_backend && npm start
```

The scheduler for weekly recaps will start automatically.

## Quick API Usage

### 1. Get Captcha Challenge
```bash
curl http://localhost:5000/auth/captcha
```
Response: `{"session_id": "...", "question": "23 + 45 = ?"}`

### 2. Login with Captcha
```bash
curl -X POST http://localhost:5000/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "parent@example.com",
    "password": "password",
    "captcha_session_id": "session_id",
    "captcha_answer": "68"
  }'
```

### 3. Record Child Growth
```bash
curl -X POST http://localhost:5000/growth/record \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "child_id": 1,
    "height_cm": 95.5,
    "weight_kg": 14.2,
    "head_circumference_cm": 48.0,
    "immunization_notes": "DPT-3",
    "milestones_notes": "Walking"
  }'
```

### 4. Log Food Intake
```bash
curl -X POST http://localhost:5000/nutrition/food-intake \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "child_id": 1,
    "food_name": "nasi putih",
    "quantity_grams": 100,
    "meal_type": "main"
  }'
```

### 5. View Daily Nutrition
```bash
curl http://localhost:5000/nutrition/daily-analysis/1/2024-01-15 \
  -H "Authorization: Bearer TOKEN"
```

### 6. Get Growth Records
```bash
curl http://localhost:5000/growth/records/1 \
  -H "Authorization: Bearer TOKEN"
```

### 7. Set Email Preferences
```bash
curl -X POST http://localhost:5000/notifications/email-preferences \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "weekly_recap": true,
    "alerts": true,
    "notify_deviations": true
  }'
```

## Flutter Integration Example

```dart
// 1. Get Captcha
final captchaResponse = await http.get(
  Uri.parse('$backendUrl/auth/captcha'),
);
final captchaData = jsonDecode(captchaResponse.body);
// Show captchaData['question'] to user

// 2. Verify Captcha
final verifyResponse = await http.post(
  Uri.parse('$backendUrl/auth/captcha/verify'),
  body: jsonEncode({
    'session_id': captchaData['session_id'],
    'answer': userAnswer,
  }),
);

// 3. Login
final loginResponse = await http.post(
  Uri.parse('$backendUrl/login'),
  body: jsonEncode({
    'email': email,
    'password': password,
    'captcha_session_id': captchaData['session_id'],
    'captcha_answer': userAnswer,
  }),
);

final token = jsonDecode(loginResponse.body)['token'];

// 4. Record Growth
await http.post(
  Uri.parse('$backendUrl/growth/record'),
  headers: {'Authorization': 'Bearer $token'},
  body: jsonEncode({
    'child_id': childId,
    'height_cm': heightValue,
    'weight_kg': weightValue,
    'head_circumference_cm': headCircValue,
  }),
);

// 5. Record Food
await http.post(
  Uri.parse('$backendUrl/nutrition/food-intake'),
  headers: {'Authorization': 'Bearer $token'},
  body: jsonEncode({
    'child_id': childId,
    'food_name': selectedFood,
    'quantity_grams': gramValue,
    'meal_type': mealType,
  }),
);
```

## Test the Features

Run the smoke test (Node):
```bash
cd backend/node_backend
npm run smoke
```

This tests (smoke):
- Health endpoint
- Register/login flows
- Basic children/activity endpoints
- Analytics/insights endpoints
- Token generation and admin overview

## Database Schema

Three new tables are created automatically:

1. **growth_records** - Growth measurements
2. **food_intake** - Food consumption logs
3. **email_preferences** - User notification settings
4. **weekly_recap** - Generated weekly summaries

## Available Foods

The system includes 20+ common Indonesian foods:
- nasi putih (white rice)
- ayam (chicken)
- telur (eggs)
- ikan (fish)
- sayuran (vegetables)
- buah-buahan (fruits)
- susu (milk)
- dll (and more)

Get full list: `GET /nutrition/foods`

## WHO Growth Standards

Growth assessment based on:
- Height-for-age percentiles
- Weight-for-age percentiles
- BMI-for-age percentiles
- Ages 1-5 years

Categories:
- Below normal: <3rd percentile
- Normal: 3rd-97th percentile
- Above normal: >97th percentile

## Weekly Recap Schedule

- **Frequency**: Every 7 days
- **Trigger**: Automatic via the Node.js scheduler (internal timer or cron-based job implemented in `backend/node_backend`)
- **Includes**:
  - Latest growth measurements
  - Daily nutrition average (last 7 days)
  - Developmental milestones
  - Deviation alerts
  
- **Recipients**: Parents with `weekly_recap=true`

## Troubleshooting

### "Captcha tidak tersedia" / other feature missing
This document is a legacy archive of the old Python/Flask implementation. The active backend is the Node.js service in `backend/node_backend`.

If a feature appears missing:
1. Check `backend/node_backend` for the corresponding implementation (e.g., captcha generation, growth tracking, nutrition endpoints).
2. Verify environment variables in `backend/node_backend/.env` and restart with `npm start` or `npm run dev`.
3. Check Node logs (console output) for errors.

### Emails not sending
1. Check SMTP credentials in `.env` inside `backend/node_backend`
2. Verify `SENDER_EMAIL` and `SENDER_PASSWORD` (use App Password for Gmail)
3. Check network connectivity and firewall rules

## File Structure (active Node backend)

```
backend/
└── node_backend/
  ├── index.js                     # Main Express app
  ├── db.js                        # DB helpers (SQLite)
  ├── smoke_test.js                # Smoke test script (Node)
  ├── package.json                 # Node dependencies & scripts
  ├── .env.example                 # Example env vars
  └── patara_backend.db            # SQLite database (created at runtime)
```

## What's Next?

After setting up Phase 2:

1. **Add UI for Growth Tracking** in Flutter:
   - Form to record height, weight, head circumference
   - Chart to visualize growth over time
   - WHO status indicators

2. **Add UI for Nutrition Logging** in Flutter:
   - Food selection interface
   - Portion size picker
   - Daily nutrition summary

3. **Add Email Preferences** in Flutter:
   - Toggle for weekly recaps
   - Notification settings

4. **Enhanced Captcha** (optional):
   - Replace math captcha with image CAPTCHA
   - Or integrate Google reCAPTCHA

5. **Graphs & Charts**:
   - Growth charts with percentile curves
   - Nutrition graphs by nutrient
   - Weekly trends

## Support

For detailed API documentation, see:
- `PHASE2_IMPLEMENTATION.md` - Complete API reference
- `backend/node_backend/smoke_test.js` - Example usage (smoke tests)
- Individual module files for function details

---

**Happy tracking!** 🎯

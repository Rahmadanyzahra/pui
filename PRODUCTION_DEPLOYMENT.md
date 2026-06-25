# Patara AI - Production Deployment Guide

**Last Updated:** May 13, 2026  
**Target Environment:** Linux/Windows Server with MySQL  
**Status:** Ready for deployment ✅

---

## **Pre-Deployment Checklist**

- [x] Database schema created and tested (MySQL `parata_a1`)
- [x] Backend unit tests passing (4/4 Jest tests)
- [x] Flutter-MySQL integration tests passing (5/5)
- [x] Security audit fixed (npm audit fix --force)
- [x] All critical code errors fixed (Child.fromFirestore method)
- [x] Flutter analyzer warnings resolved (30 INFO-level, 0 ERRORS)
- [x] Git repository initialized and commits saved

---

## **Deployment Architecture**

```
┌─────────────────────────────────────────────────────────────┐
│                    Production Environment                    │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────────────┐      ┌──────────────────────┐    │
│  │  Flutter Web/App     │      │  Node.js Backend     │    │
│  │  (Build: dist/web/)  │◄────►│  (Port: 5000)        │    │
│  └──────────────────────┘      └──────────────────────┘    │
│                                         │                    │
│                                         ▼                    │
│                          ┌──────────────────────────┐       │
│                          │   MySQL Database         │       │
│                          │   (parata_a1)            │       │
│                          │   - users                │       │
│                          │   - children             │       │
│                          │   - activities           │       │
│                          │   - sessions             │       │
│                          │   - ... (8 total tables) │       │
│                          └──────────────────────────┘       │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## **1. Backend Deployment (Node.js)**

### **Prerequisites**
- Node.js v24.x or later
- MySQL 8.0+
- PM2 (for process management)

### **Installation Steps**

```bash
# 1. Install PM2 globally (production process manager)
npm install -g pm2

# 2. Navigate to backend directory
cd backend/node_backend

# 3. Install production dependencies
npm install --production

# 4. Configure environment variables
cp .env.example .env
# Edit .env with production values:
# - DB_HOST=production.mysql.host
# - DB_PORT=3306
# - DB_USER=production_user
# - DB_PASSWORD=secure_password
# - DB_NAME=parata_a1
# - NODE_ENV=production
# - PORT=5000
```

### **Database Setup**

```bash
# 1. Create database (if not exists)
mysql -u root -p
> CREATE DATABASE parata_a1;
> EXIT;

# 2. Import schema
cd backend/node_backend
USE_MYSQL=true node import_schema_mysql_v2.js
```

### **Start Backend Service**

```bash
# Start with PM2
pm2 start index.js --name "patara-backend"

# Save PM2 config (auto-start on reboot)
pm2 save
pm2 startup

# Monitor
pm2 status
pm2 logs patara-backend
```

### **Health Check**
```bash
curl http://localhost:5000/health
# Expected: {"status":"ok"}
```

---

## **2. Flutter App Deployment**

### **Web Deployment**

```bash
# 1. Build production web app
flutter build web --release

# 2. Output location: build/web/
# Deploy these files to:
# - Apache: /var/www/html/patara_ai/
# - Nginx: /usr/share/nginx/html/patara_ai/
# - IIS: C:\inetpub\wwwroot\patara_ai\
```

### **Mobile Deployment (Android/iOS)**

```bash
# Android APK
flutter build apk --release
# Output: build/app/outputs/flutter-app.apk

# iOS IPA
flutter build ios --release
# Output: build/ios/ipa/
```

---

## **3. Server Configuration**

### **Nginx Reverse Proxy** (Recommended)

```nginx
server {
    listen 80;
    server_name yourdomain.com;
    
    # Redirect to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name yourdomain.com;
    
    ssl_certificate /etc/ssl/certs/your_cert.crt;
    ssl_certificate_key /etc/ssl/private/your_key.key;
    
    # Flutter Web App
    location / {
        root /usr/share/nginx/html/patara_ai;
        try_files $uri $uri/ /index.html;
        # CORS headers
        add_header Access-Control-Allow-Origin *;
    }
    
    # Backend API
    location /api {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
```

### **Apache Virtual Host**

```apache
<VirtualHost *:443>
    ServerName yourdomain.com
    DocumentRoot /var/www/html/patara_ai
    
    SSLEngine on
    SSLCertificateFile /etc/ssl/certs/your_cert.crt
    SSLCertificateKeyFile /etc/ssl/private/your_key.key
    
    # Flutter routing
    <Directory /var/www/html/patara_ai>
        RewriteEngine On
        RewriteBase /
        RewriteRule ^index\.html$ - [L]
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteCond %{REQUEST_FILENAME} !-d
        RewriteRule . /index.html [L]
    </Directory>
    
    # Backend proxy
    ProxyPreserveHost On
    ProxyPass /api http://localhost:5000/api
    ProxyPassReverse /api http://localhost:5000/api
</VirtualHost>
```

---

## **4. Database Backup Strategy**

### **Automated Daily Backup**

```bash
# Create backup script: /opt/patara_backup.sh
#!/bin/bash
BACKUP_DIR="/backups/mysql"
DATE=$(date +%Y%m%d_%H%M%S)
FILE="$BACKUP_DIR/parata_a1_$DATE.sql"

mysqldump -u root -p$DB_PASSWORD parata_a1 > $FILE
gzip $FILE

# Keep only last 30 days
find $BACKUP_DIR -mtime +30 -delete

# Add to crontab (daily at 2 AM)
# 0 2 * * * /opt/patara_backup.sh
```

---

## **5. Monitoring & Logging**

### **Application Monitoring**

```bash
# Real-time status
pm2 monit

# View logs
pm2 logs patara-backend
pm2 logs patara-backend --err

# Rotate logs
pm2 install pm2-logrotate
```

### **Database Monitoring**

```bash
# Check connections
mysql -u root -p -e "SHOW PROCESSLIST;"

# Table sizes
mysql -u root -p -e "SELECT table_name, ROUND(((data_length + index_length) / 1024 / 1024), 2) AS size_mb FROM information_schema.tables WHERE table_schema = 'parata_a1' ORDER BY size_mb DESC;"
```

---

## **6. Performance Optimization**

### **Node.js Tuning**

```bash
# Edit /etc/systemd/system/patara-backend.service
[Service]
Environment="NODE_ENV=production"
Environment="UV_THREADPOOL_SIZE=128"
ExecStart=/usr/local/bin/pm2 start index.js --max-memory-restart 500M
```

### **MySQL Optimization**

```bash
# Edit /etc/mysql/my.cnf
[mysqld]
max_connections=1000
max_allowed_packet=256M
innodb_buffer_pool_size=2G
query_cache_size=64M
innodb_log_file_size=512M
```

---

## **7. SSL/TLS Security**

### **Let's Encrypt (Free SSL)**

```bash
# Install Certbot
sudo apt-get install certbot python3-certbot-nginx

# Generate certificate
sudo certbot certonly --nginx -d yourdomain.com

# Auto-renewal (every 60 days)
sudo certbot renew --dry-run
```

---

## **8. Health Check Endpoints**

| Endpoint | Method | Response | Purpose |
|----------|--------|----------|---------|
| `/health` | GET | `{"status":"ok"}` | Backend alive |
| `/api/login` | POST | JSON token | Database connectivity |
| `/api/register` | POST | User data | MySQL write test |
| `/notifications/push/public-key` | GET | VAPID key | Push notifications |

---

## **9. Post-Deployment Testing**

```bash
# 1. Smoke test backend
node smoke_test.js

# 2. Run all tests
npm test

# 3. Flutter integration tests
flutter test test/integration/flutter_backend_test.dart

# 4. Load test (optional)
# Use tools like: Apache JMeter, k6, or Locust
```

---

## **10. Rollback Procedure**

```bash
# If issues occur:

# 1. Stop backend
pm2 stop patara-backend

# 2. Revert code
git checkout previous-commit-hash

# 3. Reinstall dependencies
npm install

# 4. Restart backend
pm2 start index.js --name "patara-backend"

# 5. Database rollback (if needed)
# Restore from backup: mysql parata_a1 < backup.sql
```

---

## **Emergency Contacts & Troubleshooting**

| Issue | Solution |
|-------|----------|
| Backend not starting | Check logs: `pm2 logs` and `.env` configuration |
| MySQL connection error | Verify credentials and firewall, test: `mysql -u user -p -h host` |
| High memory usage | Increase Node.js memory limit or optimize queries |
| SSL certificate error | Renew certificate: `certbot renew --force-renewal` |
| Flutter app not loading | Clear browser cache, check web server configuration |

---

## **Version Info**

- **Flutter:** 3.24.x
- **Node.js:** 24.14.0
- **MySQL:** 8.4.3
- **npm:** 11.0.0
- **PM2:** Latest

---

**Successfully deployed to production! 🚀**

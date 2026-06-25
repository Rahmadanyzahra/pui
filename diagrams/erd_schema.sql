-- ERD schema for Patara AI
-- Adjust types per target database (PostgreSQL, MySQL, SQLite).

CREATE TABLE users (
  uid VARCHAR(36) PRIMARY KEY,
  email VARCHAR(255) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  display_name VARCHAR(255),
  phone VARCHAR(50),
  role VARCHAR(32) NOT NULL,
  family_settings JSON,
  default_dashboard VARCHAR(64),
  status VARCHAR(32) DEFAULT 'active',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  deleted_at TIMESTAMP NULL
);

CREATE TABLE children (
  id VARCHAR(36) PRIMARY KEY,
  parent_uid VARCHAR(36) NOT NULL,
  name VARCHAR(255) NOT NULL,
  birth_date DATE,
  age INT,
  gender VARCHAR(32),
  metadata JSON,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  deleted_at TIMESTAMP NULL,
  CONSTRAINT fk_children_parent FOREIGN KEY (parent_uid) REFERENCES users(uid)
);

CREATE TABLE child_profiles (
  id VARCHAR(36) PRIMARY KEY,
  child_id VARCHAR(36) NOT NULL,
  bio TEXT,
  medical JSON,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_child_profiles_child FOREIGN KEY (child_id) REFERENCES children(id)
);

CREATE TABLE activities (
  id VARCHAR(36) PRIMARY KEY,
  parent_uid VARCHAR(36) NOT NULL,
  child_id VARCHAR(36) NOT NULL,
  metadata JSON,
  score VARCHAR(64),
  start_time TIMESTAMP,
  end_time TIMESTAMP,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  deleted_at TIMESTAMP NULL,
  CONSTRAINT fk_activities_parent FOREIGN KEY (parent_uid) REFERENCES users(uid),
  CONSTRAINT fk_activities_child FOREIGN KEY (child_id) REFERENCES children(id)
);

CREATE TABLE schedules (
  id VARCHAR(36) PRIMARY KEY,
  parent_uid VARCHAR(36) NOT NULL,
  child_id VARCHAR(36) NOT NULL,
  title VARCHAR(255) NOT NULL,
  reminder_time TIMESTAMP,
  active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  deleted_at TIMESTAMP NULL,
  dashboard_config JSON,
  CONSTRAINT fk_schedules_parent FOREIGN KEY (parent_uid) REFERENCES users(uid),
  CONSTRAINT fk_schedules_child FOREIGN KEY (child_id) REFERENCES children(id)
);

CREATE TABLE reports (
  id VARCHAR(36) PRIMARY KEY,
  user_uid VARCHAR(36) NOT NULL,
  title VARCHAR(255),
  content TEXT,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_reports_user FOREIGN KEY (user_uid) REFERENCES users(uid)
);

CREATE TABLE gamification_data (
  id VARCHAR(36) PRIMARY KEY,
  user_uid VARCHAR(36) NOT NULL,
  points INT DEFAULT 0,
  badge JSON,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_gamification_user FOREIGN KEY (user_uid) REFERENCES users(uid)
);

CREATE TABLE sessions (
  token VARCHAR(255) PRIMARY KEY,
  user_uid VARCHAR(36) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  expires_at TIMESTAMP,
  revoked BOOLEAN DEFAULT FALSE,
  CONSTRAINT fk_sessions_user FOREIGN KEY (user_uid) REFERENCES users(uid)
);

CREATE TABLE push_subscriptions (
  id VARCHAR(36) PRIMARY KEY,
  user_uid VARCHAR(36) NOT NULL,
  endpoint TEXT NOT NULL,
  keys JSON,
  device_id VARCHAR(255),
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT uq_push_subscription UNIQUE (user_uid, device_id),
  CONSTRAINT fk_push_subscription_user FOREIGN KEY (user_uid) REFERENCES users(uid)
);

CREATE TABLE invites (
  code VARCHAR(100) PRIMARY KEY,
  created_by VARCHAR(36) NOT NULL,
  email VARCHAR(255),
  used BOOLEAN DEFAULT FALSE,
  expires_at TIMESTAMP,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_invites_creator FOREIGN KEY (created_by) REFERENCES users(uid)
);

CREATE TABLE connection_tokens (
  token VARCHAR(255) PRIMARY KEY,
  user_uid VARCHAR(36) NOT NULL,
  device_id VARCHAR(255),
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  expires_at TIMESTAMP,
  revoked BOOLEAN DEFAULT FALSE,
  CONSTRAINT fk_connection_tokens_user FOREIGN KEY (user_uid) REFERENCES users(uid)
);

CREATE TABLE delegation_assignments (
  id VARCHAR(36) PRIMARY KEY,
  delegated_parent_uid VARCHAR(36) NOT NULL,
  child_profile_id VARCHAR(36) NOT NULL,
  permission_scope VARCHAR(128),
  assigned_by VARCHAR(36) NOT NULL,
  assigned_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  expires_at TIMESTAMP,
  active BOOLEAN DEFAULT TRUE,
  CONSTRAINT fk_delegation_delegated_parent FOREIGN KEY (delegated_parent_uid) REFERENCES users(uid),
  CONSTRAINT fk_delegation_child_profile FOREIGN KEY (child_profile_id) REFERENCES child_profiles(id),
  CONSTRAINT fk_delegation_assigned_by FOREIGN KEY (assigned_by) REFERENCES users(uid)
);

CREATE INDEX idx_activities_child_start_time ON activities(child_id, start_time);
CREATE INDEX idx_schedules_parent_reminder_time ON schedules(parent_uid, reminder_time);
CREATE INDEX idx_invites_email ON invites(email);
CREATE INDEX idx_children_parent ON children(parent_uid);
CREATE INDEX idx_sessions_user ON sessions(user_uid);

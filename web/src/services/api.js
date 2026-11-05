/**
 * Backend API Service untuk React Web
 * Use Vite env `VITE_API_URL` when available, otherwise fall back
 * to the local Node backend on localhost.
 */

const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://127.0.0.1:5000';

class ApiService {
  constructor() {
    this.token = null;
    this.role = localStorage.getItem('role') || 'parent';
  }

  async request(endpoint, options = {}, retryAuth = true) {
    const url = `${API_BASE_URL}${endpoint}`;
    const headers = {
      'Content-Type': 'application/json',
      ...options.headers,
    };

    if (this.token) {
      headers['Authorization'] = `Bearer ${this.token}`;
    }

    const response = await fetch(url, {
      ...options,
      credentials: 'include',
      headers,
    });

    if (!response.ok) {
      const bodyText = await response.text().catch(() => '');
      if (response.status === 401) {
        const publicAuthRoute = endpoint === '/api/admin/login' || endpoint === '/api/admin/captcha';
        if (retryAuth && !publicAuthRoute && endpoint !== '/api/refresh') {
          const refresh = await fetch(`${API_BASE_URL}/api/refresh`, {
            method: 'POST',
            credentials: 'include',
          });
          if (refresh.ok) return this.request(endpoint, options, false);
        }
        if (!publicAuthRoute) {
          localStorage.removeItem('admin_session');
          localStorage.removeItem('role');
          localStorage.removeItem('token');
          this.token = null;
          this.role = 'parent';
          window.location.href = '/login';
        }
      }
      const message = `API Error: ${response.status}` + (bodyText ? ` - ${bodyText}` : '');
      throw new Error(message);
    }

    const bodyText = await response.text();
    try {
      return JSON.parse(bodyText);
    } catch {
      return bodyText;
    }
  }

  // Auth
  async login(email, password) {
    const data = await this.request('/api/login', {
      method: 'POST',
      body: JSON.stringify({ email, password }),
    });
    const token = data.token || data.access_token;
    if (token) {
      this.token = token;
      localStorage.setItem('token', token);
      this.role = data.role || 'parent';
      localStorage.setItem('role', this.role);
    }
    return data;
  }

  async getAdminCaptcha() {
    const response = await fetch(`${API_BASE_URL}/api/admin/captcha`, {
      headers: { 'Cache-Control': 'no-cache' },
      credentials: 'include',
    });
    if (!response.ok) throw new Error('Gagal memuat verifikasi login.');
    return response.json();
  }

  async adminLogin(email, password, captchaSessionId, captchaAnswer) {
    const data = await this.request('/api/admin/login', {
      method: 'POST',
      body: JSON.stringify({
        email,
        password,
        captcha_session_id: captchaSessionId,
        captcha_answer: captchaAnswer,
      }),
    });
    if (data.role !== 'super_admin') {
      throw new Error('Akun tidak memiliki akses super admin.');
    }
    this.token = null;
    this.role = 'super_admin';
    localStorage.setItem('admin_session', '1');
    localStorage.setItem('role', this.role);
    return data;
  }

  async register(email, password, role = 'parent') {
    const data = await this.request('/api/register', {
      method: 'POST',
      body: JSON.stringify({ email, password, role }),
    });
    const token = data.token || data.access_token;
    if (token) {
      this.token = token;
      localStorage.setItem('token', token);
      this.role = data.role || role;
      localStorage.setItem('role', this.role);
    }
    return data;
  }

  // Children Management
  async getChildren() {
    return this.request('/children');
  }

  async createChild(nama, umur) {
    return this.request('/children', {
      method: 'POST',
      body: JSON.stringify({ nama, umur }),
    });
  }

  async getChild(childId) {
    return this.request(`/children/${childId}`);
  }

  async updateChild(childId, nama, umur) {
    return this.request(`/children/${childId}`, {
      method: 'PUT',
      body: JSON.stringify({ nama, umur }),
    });
  }

  async deleteChild(childId) {
    return this.request(`/children/${childId}`, { method: 'DELETE' });
  }

  async deleteAdminChild(childId) {
    return this.request(`/admin/children/${encodeURIComponent(childId)}`, { method: 'DELETE' });
  }

  // Activities
  async logActivity(childId, activityType, value, created_at = undefined) {
    const body = {
      child_id: childId,
      activity_type: activityType,
      value,
    };
    if (created_at) body.created_at = created_at;
    return this.request('/activities', {
      method: 'POST',
      body: JSON.stringify(body),
    });
  }

  async getActivities(childId = null) {
    let endpoint = '/activities';
    if (childId) {
      endpoint += `?child_id=${childId}`;
    }
    return this.request(endpoint);
  }

  // Activities with date filter
  async getActivitiesWithDate({ from, to } = {}) {
    let endpoint = '/activities';
    const params = [];
    if (from) params.push(`from=${encodeURIComponent(from)}`);
    if (to) params.push(`to=${encodeURIComponent(to)}`);
    if (params.length) endpoint += `?${params.join('&')}`;
    return this.request(endpoint);
  }

  // Download recap CSV
  async downloadActivitiesRecap({ from, to } = {}) {
    let endpoint = '/activities/download';
    const params = [];
    if (from) params.push(`from=${encodeURIComponent(from)}`);
    if (to) params.push(`to=${encodeURIComponent(to)}`);
    if (params.length) endpoint += `?${params.join('&')}`;
    const url = `${API_BASE_URL}${endpoint}`;
    return fetch(url, { credentials: 'include' }).then(response => {
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      return response.blob();
    });
  }

  // Insight perkembangan
  async getActivitiesInsight({ from, to } = {}) {
    let endpoint = '/activities/insight';
    const params = [];
    if (from) params.push(`from=${encodeURIComponent(from)}`);
    if (to) params.push(`to=${encodeURIComponent(to)}`);
    if (params.length) endpoint += `?${params.join('&')}`;
    return this.request(endpoint);
  }

  // Analytics
  async getParentAnalytics() {
    return this.request('/analytics/parent');
  }

  async getChildAnalytics(childId) {
    return this.request(`/analytics/child/${childId}`);
  }

  // Connection Tokens
  async generateConnectionToken(role = 'delegated_parent') {
    return this.request('/tokens/generate', {
      method: 'POST',
      body: JSON.stringify({ role }),
    });
  }

  // Child insights & alerts
  async getChildInsights(childId) {
    return this.request(`/insights/child/${childId}`);
  }

  async getChildAlerts(childId) {
    return this.request(`/alerts/child/${childId}`);
  }

  async getPushPublicKey() {
    return this.request('/notifications/push/public-key');
  }

  async subscribePush(subscription) {
    return this.request('/notifications/push/subscribe', {
      method: 'POST',
      body: JSON.stringify({ subscription }),
    });
  }

  async unsubscribePush(endpoint) {
    return this.request('/notifications/push/unsubscribe', {
      method: 'POST',
      body: JSON.stringify({ endpoint }),
    });
  }

  async testPush() {
    return this.request('/notifications/push/test', { method: 'POST' });
  }

  // Admin
  async getAdminOverview() {
    return this.request('/admin/overview');
  }

  async getAdminUsers() {
    return this.request('/admin/users');
  }

  async getAdminUserLoginHistory(userId) {
    return this.request(`/admin/users/${encodeURIComponent(userId)}/login-history`);
  }

  async deleteAdminUserLoginHistory(userId) {
    return this.request(`/admin/users/${encodeURIComponent(userId)}/login-history`, {
      method: 'DELETE',
    });
  }

  async deleteAdminUser(userId) {
    return this.request(`/admin/users/${encodeURIComponent(userId)}`, {
      method: 'DELETE',
    });
  }

  async getAdminChildren() {
    return this.request('/admin/children');
  }

  async getAdminActivities() {
    return this.request('/admin/activities');
  }

  async deleteAdminActivity(activityId) {
    return this.request(`/admin/activities/${encodeURIComponent(activityId)}`, {
      method: 'DELETE',
    });
  }

  async getAdminBehaviorEvents({ query, status } = {}) {
    const params = new URLSearchParams();
    if (query) params.set('q', query);
    if (status) params.set('status', status);
    const suffix = params.size ? `?${params.toString()}` : '';
    const result = await this.request(`/admin/behavior-events${suffix}`);
    return result.items || [];
  }

  async deleteAdminBehaviorEvent(eventId) {
    return this.request(`/admin/behavior-events/${encodeURIComponent(eventId)}`, {
      method: 'DELETE',
    });
  }

  async getAdminChildAnalytics(childId) {
    return this.request(`/admin/children/${encodeURIComponent(childId)}/analytics`);
  }

  // Growth Prediction & PDF Download
  async getGrowthPrediction(childId, period = '7day') {
    return this.request(`/api/growth-prediction/${childId}/${period}`);
  }

  async downloadGrowthPredictionPdf(childId, period = '7day') {
    // Direct URL for PDF download - the browser will handle it as a file download
    const url = `${API_BASE_URL}/api/growth-prediction/${childId}/${period}/download`;
    return fetch(url, { credentials: 'include' }).then(response => {
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      return response.blob();
    });
  }

  async sendGrowthPredictionEmail(childId, period = '7day', email = null) {
    return this.request(`/api/growth-prediction/${childId}/email-report`, {
      method: 'POST',
      body: JSON.stringify({ period, email }),
    });
  }

  // Email Preferences
  async getEmailPreferences() {
    return this.request('/notifications/email-preferences');
  }

  async updateEmailPreferences(preferences) {
    return this.request('/notifications/email-preferences', {
      method: 'POST',
      body: JSON.stringify(preferences),
    });
  }

  logout() {
    fetch(`${API_BASE_URL}/api/logout`, {
      method: 'POST',
      credentials: 'include',
    }).catch(() => null);
    localStorage.removeItem('admin_session');
    localStorage.removeItem('token');
    localStorage.removeItem('role');
    this.token = null;
    this.role = 'parent';
  }

  // Health check
  async healthCheck() {
    return this.request('/health');
  }
}

export default new ApiService();

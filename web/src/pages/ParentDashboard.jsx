import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import api from '../services/api';
import { enableWebPushNotifications } from '../services/webPush';
import '../styles/dashboard.css';

export default function ParentDashboard() {
  const [children, setChildren] = useState([]);
  const [analytics, setAnalytics] = useState(null);
  const [loading, setLoading] = useState(true);
  const [showNewChildForm, setShowNewChildForm] = useState(false);
  const [newChild, setNewChild] = useState({ nama: '', umur: '' });
  const [tokenRole, setTokenRole] = useState('remaja');
  const [generatedToken, setGeneratedToken] = useState('');
  const [tokenLoading, setTokenLoading] = useState(false);
  const [tokenMessage, setTokenMessage] = useState('Belum ada token yang dibuat.');
  const [downloadingPdf, setDownloadingPdf] = useState({});
  const [childAnalytics, setChildAnalytics] = useState({});
  const [deleting, setDeleting] = useState({});
  const [emailPrefs, setEmailPrefs] = useState({ 
    weekly_recap: false, 
    growth_alert: false, 
    food_insight: false, 
    email: '' 
  });
  const [updatingPrefs, setUpdatingPrefs] = useState(false);
  const navigate = useNavigate();

  useEffect(() => {
    fetchData();
  }, []);

  const fetchData = async () => {
    try {
      setLoading(true);
      const [childrenData, analyticsData, prefsData] = await Promise.all([
        api.getChildren(),
        api.getParentAnalytics(),
        api.getEmailPreferences().catch(() => ({ email: '', weekly_recap: false, growth_alert: false, food_insight: false }))
      ]);
      setChildren(childrenData);
      setAnalytics(analyticsData);
      setEmailPrefs(prefsData);
      
      // Fetch analytics for each child
      const analyticsMap = {};
      for (const child of childrenData) {
        try {
          const childAnal = await api.getChildAnalytics(child.id);
          analyticsMap[child.id] = childAnal;
        } catch (err) {
          console.warn(`Failed to fetch analytics for child ${child.id}:`, err);
          analyticsMap[child.id] = {};
        }
      }
      setChildAnalytics(analyticsMap);
    } catch (err) {
      console.error('Failed to fetch data:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleCreateChild = async (e) => {
    e.preventDefault();
    try {
      await api.createChild(newChild.nama, parseInt(newChild.umur));
      setNewChild({ nama: '', umur: '' });
      setShowNewChildForm(false);
      fetchData();
    } catch (err) {
      console.error('Failed to create child:', err);
    }
  };

  const handleDeleteChild = async (childId, childName) => {
    if (!window.confirm(`Hapus anak "${childName}"? Tindakan ini tidak dapat dibatalkan.`)) {
      return;
    }
    try {
      setDeleting((prev) => ({ ...prev, [childId]: true }));
      await api.deleteChild(childId);
      fetchData();
      window.alert(`"${childName}" berhasil dihapus.`);
    } catch (err) {
      window.alert('Gagal menghapus anak: ' + (err.message || err));
    } finally {
      setDeleting((prev) => ({ ...prev, [childId]: false }));
    }
  };

  const handleUpdateEmailPrefs = async (e) => {
    e.preventDefault();
    try {
      setUpdatingPrefs(true);
      await api.updateEmailPreferences(emailPrefs);
      window.alert('Preferensi email berhasil disimpan!');
    } catch (err) {
      window.alert('Gagal menyimpan preferensi: ' + (err.message || err));
    } finally {
      setUpdatingPrefs(false);
    }
  };

  const handleLogout = () => {
    api.logout();
    navigate('/login');
  };

  const handleEnableAlerts = async () => {
    try {
      await enableWebPushNotifications();
      window.alert('Notifikasi push berhasil diaktifkan');
    } catch (err) {
      window.alert(err.message || 'Gagal mengaktifkan notifikasi push');
    }
  };

  const handleGenerateToken = async () => {
    try {
      setTokenLoading(true);
      setTokenMessage('Membuat token baru...');
      const token = await api.generateConnectionToken(tokenRole);
      setGeneratedToken(token);
      setTokenMessage('Token berhasil dibuat. Bagikan ke akun anak untuk menyambungkan perangkat.');
    } catch (err) {
      setTokenMessage(err.message || 'Gagal membuat token');
    } finally {
      setTokenLoading(false);
    }
  };

  const handleCopyToken = async () => {
    if (!generatedToken) return;
    try {
      await navigator.clipboard.writeText(generatedToken);
      window.alert('Token disalin ke clipboard');
    } catch (err) {
      window.alert('Gagal menyalin token');
    }
  };

  const handleDownloadPdf = async (childId, childName, period) => {
    try {
      const key = `${childId}_${period}`;
      setDownloadingPdf((prev) => ({ ...prev, [key]: true }));
      const blob = await api.downloadGrowthPredictionPdf(childId, period);
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `growth_report_${period}_${childName}.pdf`;
      document.body.appendChild(a);
      a.click();
      window.URL.revokeObjectURL(url);
      document.body.removeChild(a);
    } catch (err) {
      window.alert(err.message || `Gagal mengunduh PDF untuk periode ${period}`);
    } finally {
      const key = `${childId}_${period}`;
      setDownloadingPdf((prev) => ({ ...prev, [key]: false }));
    }
  };

  if (loading) {
    return <div className="loading">Loading dashboard...</div>;
  }

  return (
    <div className="dashboard-container">
      <header className="dashboard-header">
        <h1>Parent Dashboard</h1>
        <div style={{ display: 'flex', gap: 8 }}>
          <button onClick={handleEnableAlerts} className="btn-secondary">
            Enable Alerts
          </button>
          <button onClick={handleLogout} className="btn-logout">
            Logout
          </button>
        </div>
      </header>

      <div className="dashboard-content">
        {/* Analytics Section */}
        {analytics && (
          <section className="analytics-section">
            <h2>Family Overview</h2>
            <div className="stats-grid">
              <div className="stat-card">
                <span className="stat-label">Total Children</span>
                <span className="stat-value">{children.length}</span>
              </div>
              <div className="stat-card">
                <span className="stat-label">Active Activities</span>
                <span className="stat-value">{analytics.total_activities || 0}</span>
              </div>
              <div className="stat-card">
                <span className="stat-label">Weekly Average</span>
                <span className="stat-value">{analytics.weekly_average || 0}</span>
              </div>
            </div>
            <div className="insight-strip">
              <div className="insight-chip">
                <span>Check-in</span>
                <strong>{analytics.dashboard?.checkin_rate || 0}%</strong>
              </div>
              <div className="insight-chip">
                <span>Aktivitas Minggu Ini</span>
                <strong>{analytics.dashboard?.week_activities || 0}</strong>
              </div>
              <div className="insight-chip">
                <span>Insight Utama</span>
                <strong>{analytics.dashboard?.latest_activity_label || 'Belum ada data'}</strong>
              </div>
            </div>
          </section>
        )}

        <section className="token-section">
          <div className="section-header">
            <h2>Connection Token</h2>
            <button
              onClick={handleGenerateToken}
              className="btn-primary"
              disabled={tokenLoading}
            >
              {tokenLoading ? 'Membuat...' : 'Buat Token'}
            </button>
          </div>

          <div className="token-card">
            <p className="token-helper">
              Gunakan token ini untuk menyambungkan akun anak ke dashboard parent.
            </p>

            <div className="token-form-row">
              <label>
                Role target
                <select
                  value={tokenRole}
                  onChange={(e) => setTokenRole(e.target.value)}
                  className="token-select"
                >
                  <option value="remaja">Remaja</option>
                  <option value="anak">Anak</option>
                </select>
              </label>

              <div className="token-message">{tokenMessage}</div>
            </div>

            <div className="token-output">
              <div className="token-label">Token saat ini</div>
              <code className="token-value">{generatedToken || 'Belum dibuat'}</code>
              <button
                type="button"
                className="btn-secondary token-copy-btn"
                onClick={handleCopyToken}
                disabled={!generatedToken}
              >
                Copy Token
              </button>
            </div>
          </div>
        </section>

        {/* Children Section */}
        <section className="children-section">
          <div className="section-header">
            <h2>Your Children</h2>
            <button
              onClick={() => setShowNewChildForm(!showNewChildForm)}
              className="btn-secondary"
            >
              + Add Child
            </button>
          </div>

          {showNewChildForm && (
            <form onSubmit={handleCreateChild} className="new-child-form">
              <input
                type="text"
                placeholder="Child Name"
                value={newChild.nama}
                onChange={(e) => setNewChild({ ...newChild, nama: e.target.value })}
                required
              />
              <input
                type="number"
                placeholder="Age"
                value={newChild.umur}
                onChange={(e) => setNewChild({ ...newChild, umur: e.target.value })}
                required
                min="0"
                max="18"
              />
              <button type="submit" className="btn-primary">
                Create
              </button>
              <button
                type="button"
                onClick={() => setShowNewChildForm(false)}
                className="btn-secondary"
              >
                Cancel
              </button>
            </form>
          )}

          <div className="children-grid">
            {children.length > 0 ? (
              children.map((child) => {
                const childAnal = childAnalytics[child.id] || {};
                const isBalita = child.umur < 3;
                const isAnak = child.umur >= 3 && child.umur < 13;
                const isRemaja = child.umur >= 13;
                const ageGroup = isBalita ? 'Balita' : isAnak ? 'Anak' : 'Remaja';
                
                return (
                  <div key={child.id} className="child-card">
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'start', marginBottom: 10 }}>
                      <div>
                        <h3>{child.nama}</h3>
                        <p className="age-label">
                          {child.umur} tahun • <span style={{ color: '#e91e63', fontWeight: 'bold' }}>{ageGroup}</span>
                        </p>
                      </div>
                      <button
                        type="button"
                        onClick={() => handleDeleteChild(child.id, child.nama)}
                        disabled={deleting[child.id]}
                        style={{
                          background: '#ff4444',
                          color: 'white',
                          border: 'none',
                          padding: '6px 12px',
                          borderRadius: '4px',
                          cursor: deleting[child.id] ? 'not-allowed' : 'pointer',
                          opacity: deleting[child.id] ? 0.6 : 1,
                          fontSize: 12,
                          fontWeight: 'bold'
                        }}
                      >
                        {deleting[child.id] ? 'Hapus...' : 'Hapus'}
                      </button>
                    </div>

                    {/* Age-Specific Content */}
                    {isBalita && (
                      <div style={{ background: '#fff3e0', padding: 12, borderRadius: 8, marginBottom: 12 }}>
                        <h4 style={{ margin: '0 0 8px 0', color: '#ff9800' }}>Pantauan Balita</h4>
                        <div style={{ fontSize: 12 }}>
                          <p style={{ margin: 4 }}>📏 Tinggi: {childAnal.height || '-'}</p>
                          <p style={{ margin: 4 }}>⚖️ Berat: {childAnal.weight || '-'}</p>
                          <p style={{ margin: 4 }}>🍼 Status Gizi: {childAnal.nutrition_status || 'Belum diisi'}</p>
                          <p style={{ margin: 4 }}>💤 Pola Tidur: {childAnal.sleep_pattern || 'Belum direkam'}</p>
                        </div>
                      </div>
                    )}

                    {isAnak && (
                      <div style={{ background: '#e3f2fd', padding: 12, borderRadius: 8, marginBottom: 12 }}>
                        <h4 style={{ margin: '0 0 8px 0', color: '#2196f3' }}>Aktivitas Anak</h4>
                        <div style={{ fontSize: 12 }}>
                          <p style={{ margin: 4 }}>📚 Belajar: {childAnal.total_learning || 0} jam</p>
                          <p style={{ margin: 4 }}>🏃 Olahraga: {childAnal.total_sports || 0} jam</p>
                          <p style={{ margin: 4 }}>🎮 Screen Time: {childAnal.screen_time || 0} jam</p>
                          <p style={{ margin: 4 }}>😴 Istirahat: {childAnal.rest_hours || 0} jam</p>
                        </div>
                      </div>
                    )}

                    {isRemaja && (
                      <div style={{ background: '#f3e5f5', padding: 12, borderRadius: 8, marginBottom: 12 }}>
                        <h4 style={{ margin: '0 0 8px 0', color: '#9c27b0' }}>Pantauan Remaja</h4>
                        <div style={{ fontSize: 12 }}>
                          <p style={{ margin: 4 }}>📱 Aktivitas Digital: {childAnal.digital_time || 0} jam</p>
                          <p style={{ margin: 4 }}>📖 Fokus Belajar: {childAnal.focus_score || '-'}%</p>
                          <p style={{ margin: 4 }}>🏃 Aktifitas Fisik: {childAnal.physical_activity || 'Rendah'}</p>
                          <p style={{ margin: 4 }}>😌 Mood: {childAnal.mood_score || '-'}</p>
                        </div>
                      </div>
                    )}

                    {/* Overall Analytics */}
                    {childAnal.total_activities && (
                      <div style={{ background: '#f5f5f5', padding: 10, borderRadius: 6, marginBottom: 12, fontSize: 12 }}>
                        <span style={{ fontWeight: 'bold' }}>Total Aktivitas: </span>
                        <span>{childAnal.total_activities} • </span>
                        <span style={{ fontWeight: 'bold' }}>Weekly Avg: </span>
                        <span>{childAnal.weekly_average || 0}</span>
                      </div>
                    )}

                    <button
                      onClick={() => navigate(`/child/${child.id}`)}
                      className="btn-primary"
                      style={{ width: '100%', marginBottom: 10 }}
                    >
                      Lihat Detail Lengkap
                    </button>

                    <div style={{ marginTop: 12, display: 'flex', flexDirection: 'column', gap: 6 }}>
                      <p style={{ fontSize: 12, fontWeight: 'bold', margin: 0 }}>📥 Download Laporan:</p>
                      <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                        <button
                          type="button"
                          className="btn-secondary"
                          style={{ fontSize: 12, padding: '6px 10px' }}
                          onClick={() => handleDownloadPdf(child.id, child.nama, '7day')}
                          disabled={downloadingPdf[`${child.id}_7day`]}
                        >
                          {downloadingPdf[`${child.id}_7day`] ? '⏳' : '7hari'}
                        </button>
                        <button
                          type="button"
                          className="btn-secondary"
                          style={{ fontSize: 12, padding: '6px 10px' }}
                          onClick={() => handleDownloadPdf(child.id, child.nama, '30day')}
                          disabled={downloadingPdf[`${child.id}_30day`]}
                        >
                          {downloadingPdf[`${child.id}_30day`] ? '⏳' : '30hari'}
                        </button>
                        <button
                          type="button"
                          className="btn-secondary"
                          style={{ fontSize: 12, padding: '6px 10px' }}
                          onClick={() => handleDownloadPdf(child.id, child.nama, '3month')}
                          disabled={downloadingPdf[`${child.id}_3month`]}
                        >
                          {downloadingPdf[`${child.id}_3month`] ? '⏳' : '3bulan'}
                        </button>
                      </div>
                    </div>
                  </div>
                );
              })
            ) : (
              <p className="empty-message">Belum ada anak. Buat anak baru untuk memulai monitoring!</p>
            )}
          </div>
        </section>
      </div>
    </div>
  );
}

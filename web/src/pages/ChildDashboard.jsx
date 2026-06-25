import { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import api from '../services/api';
import '../styles/dashboard.css';

export default function ChildDashboard() {
  const { childId } = useParams();
  const [child, setChild] = useState(null);
  const [analytics, setAnalytics] = useState(null);
  const [activities, setActivities] = useState([]);
  const [loading, setLoading] = useState(true);
  const [activityType, setActivityType] = useState('belajar');
  const [activityValue, setActivityValue] = useState('');
  const [downloadingPdf, setDownloadingPdf] = useState({});
  const [activityDate, setActivityDate] = useState(() => {
    const today = new Date();
    return today.toISOString().slice(0, 10);
  });
  const navigate = useNavigate();

  useEffect(() => {
    fetchData();
  }, [childId]);

  const fetchData = async () => {
    try {
      setLoading(true);
      const [analyticsData, activitiesData, childrenData] = await Promise.all([
        api.getChildAnalytics(childId),
        api.getActivities(childId),
        api.getChildren(),
      ]);

      const currentChild = childrenData.find((c) => c.id === parseInt(childId));
      setChild(currentChild);
      setAnalytics(analyticsData);
      setActivities(activitiesData);
    } catch (err) {
      console.error('Failed to fetch data:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleLogActivity = async (e) => {
    e.preventDefault();
    try {
      await api.logActivity(
        parseInt(childId),
        activityType,
        parseInt(activityValue),
        activityDate
      );
      setActivityValue('');
      setActivityDate(new Date().toISOString().slice(0, 10));
      fetchData();
    } catch (err) {
      console.error('Failed to log activity:', err);
    }
  };

  const handleDownloadPdf = async (period) => {
    try {
      setDownloadingPdf((prev) => ({ ...prev, [period]: true }));
      const blob = await api.downloadGrowthPredictionPdf(parseInt(childId), period);
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      const childName = child?.nama || `child_${childId}`;
      a.download = `growth_report_${period}_${childName}.pdf`;
      document.body.appendChild(a);
      a.click();
      window.URL.revokeObjectURL(url);
      document.body.removeChild(a);
    } catch (err) {
      console.error('Failed to download PDF:', err);
      alert(err.message || `Gagal mengunduh PDF untuk periode ${period}`);
    } finally {
      setDownloadingPdf((prev) => ({ ...prev, [period]: false }));
    }
  };

  if (loading) {
    return <div className="loading">Loading child dashboard...</div>;
  }

  if (!child) {
    return (
      <div className="error-container">
        <p>Child not found</p>
        <button onClick={() => navigate(-1)} className="btn-primary">
          Go Back
        </button>
      </div>
    );
  }

  return (
    <div className="dashboard-container">
      <header className="dashboard-header">
        <button onClick={() => navigate(-1)} className="btn-back">
          ← Back
        </button>
        <h1>{child.nama}'s Dashboard</h1>
      </header>

      <div className="dashboard-content">
        {/* Analytics Section */}
        {analytics && (
          <section className="analytics-section">
            <h2>Activity Overview</h2>
            <div className="stats-grid">
              <div className="stat-card">
                <span className="stat-label">Total Activities</span>
                <span className="stat-value">{analytics.total_activities || 0}</span>
              </div>
              <div className="stat-card">
                <span className="stat-label">Learning Hours</span>
                <span className="stat-value">{analytics.learning_hours || 0}</span>
              </div>
              <div className="stat-card">
                <span className="stat-label">Rewards Points</span>
                <span className="stat-value">{analytics.rewards || 0}</span>
              </div>
            </div>
            <div style={{ marginTop: 16, padding: 12, backgroundColor: '#f0f0f0', borderRadius: 8 }}>
              <p style={{ fontWeight: 'bold', marginBottom: 8, margin: 0 }}>Download Laporan Pertumbuhan:</p>
              <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                <button
                  type="button"
                  className="btn-secondary"
                  onClick={() => handleDownloadPdf('7day')}
                  disabled={downloadingPdf['7day']}
                >
                  {downloadingPdf['7day'] ? 'Mengunduh 7 Hari...' : 'Download 7 Hari'}
                </button>
                <button
                  type="button"
                  className="btn-secondary"
                  onClick={() => handleDownloadPdf('30day')}
                  disabled={downloadingPdf['30day']}
                >
                  {downloadingPdf['30day'] ? 'Mengunduh 30 Hari...' : 'Download 30 Hari'}
                </button>
                <button
                  type="button"
                  className="btn-secondary"
                  onClick={() => handleDownloadPdf('3month')}
                  disabled={downloadingPdf['3month']}
                >
                  {downloadingPdf['3month'] ? 'Mengunduh 3 Bulan...' : 'Download 3 Bulan'}
                </button>
              </div>
            </div>
          </section>
        )}

        {/* Activity Logging Section */}
        <section className="activity-section">
          <h2>Log Activity</h2>
          <form onSubmit={handleLogActivity} className="activity-form">
            <div className="form-group">
              <label>Activity Type</label>
              <select
                value={activityType}
                onChange={(e) => setActivityType(e.target.value)}
              >
                <option value="belajar">Learning</option>
                <option value="bermain">Playing</option>
                <option value="istirahat">Rest</option>
                <option value="makan">Eating</option>
                <option value="tidur">Sleep</option>
              </select>
            </div>

            <div className="form-group">
              <label>Duration/Value</label>
              <input
                type="number"
                value={activityValue}
                onChange={(e) => setActivityValue(e.target.value)}
                placeholder="Minutes or count"
                required
                min="0"
              />
            </div>

            <div className="form-group">
              <label>Date</label>
              <input
                type="date"
                value={activityDate}
                onChange={e => setActivityDate(e.target.value)}
                max={new Date().toISOString().slice(0, 10)}
                required
              />
            </div>
            <button type="submit" className="btn-primary">
              Log Activity
            </button>
          </form>
        </section>

        {/* Activities History */}
        <section className="history-section">
          <h2>Recent Activities</h2>
          <div className="activities-list">
            {activities.length > 0 ? (
              activities.slice(0, 10).map((activity, idx) => (
                <div key={idx} className="activity-item">
                  <span className="activity-type">{activity.activity_type}</span>
                  <span className="activity-value">{activity.value}</span>
                  <span className="activity-date">
                    {new Date(activity.created_at).toLocaleDateString()}
                  </span>
                </div>
              ))
            ) : (
              <p className="empty-message">No activities logged yet</p>
            )}
          </div>
        </section>
      </div>
    </div>
  );
}

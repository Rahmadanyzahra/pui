import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import api from '../services/api';
import { enableWebPushNotifications } from '../services/webPush';
import '../styles/admin.css';

function formatDate(value) {
  if (!value) return '-';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;
  return date.toLocaleDateString('id-ID', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

function statLabel(value) {
  return typeof value === 'number' ? value.toLocaleString('id-ID') : value;
}

const WEEKDAY_ORDER = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

function normalizeWeekdayKey(value) {
  const key = String(value || '').trim().toLowerCase();
  if (!key) return '';

  if (['sen', 'senin', 'mon', 'monday'].includes(key)) return 'Sen';
  if (['sel', 'selasa', 'tue', 'tues', 'tuesday'].includes(key)) return 'Sel';
  if (['rab', 'rabu', 'wed', 'wednesday'].includes(key)) return 'Rab';
  if (['kam', 'kamis', 'thu', 'thurs', 'thursday'].includes(key)) return 'Kam';
  if (['jum', 'jumat', 'fri', 'friday'].includes(key)) return 'Jum';
  if (['sab', 'sabtu', 'sat', 'saturday'].includes(key)) return 'Sab';
  if (['min', 'minggu', 'sun', 'sunday'].includes(key)) return 'Min';

  return '';
}

function normalizeWeeklySeries(rawSeries) {
  const normalized = Object.fromEntries(WEEKDAY_ORDER.map((day) => [day, 0]));
  const source = rawSeries && typeof rawSeries === 'object' ? rawSeries : {};

  Object.entries(source).forEach(([key, value]) => {
    const day = normalizeWeekdayKey(key);
    if (!day) return;
    normalized[day] += Number(value) || 0;
  });

  return normalized;
}

function fallbackSeriesFromActivities(activities) {
  const normalized = Object.fromEntries(WEEKDAY_ORDER.map((day) => [day, 0]));
  const list = Array.isArray(activities) ? activities : [];

  list.forEach((activity) => {
    const createdAt = activity?.created_at;
    if (!createdAt) return;
    const date = new Date(createdAt);
    if (Number.isNaN(date.getTime())) return;

    const jsDay = date.getDay();
    // JS day: 0=Sun..6=Sat, convert to Monday-first index.
    const mondayFirstIndex = (jsDay + 6) % 7;
    const day = WEEKDAY_ORDER[mondayFirstIndex];
    normalized[day] += 1;
  });

  return normalized;
}

function formatActivityValue(value) {
  if (!value) return '-';
  const raw = String(value);

  try {
    const parsed = JSON.parse(raw);
    if (parsed && typeof parsed === 'object') {
      const title = parsed.title || parsed.menu || parsed.note || parsed.description;
      const when = parsed.scheduleDate || parsed.date;

      if (title && when) {
        return `${title} • ${formatDate(when)}`;
      }
      if (title) {
        return String(title);
      }

      return Object.entries(parsed)
        .slice(0, 3)
        .map(([key, val]) => `${key}:${String(val)}`)
        .join(' • ');
    }
  } catch {
    return raw;
  }

  return raw;
}

export default function AdminDashboard() {
  const [activeSection, setActiveSection] = useState('overview');
  const [overview, setOverview] = useState(null);
  const [users, setUsers] = useState([]);
  const [children, setChildren] = useState([]);
  const [activities, setActivities] = useState([]);
  const [behaviorEvents, setBehaviorEvents] = useState([]);
  const [activitySearch, setActivitySearch] = useState('');
  const [behaviorSearch, setBehaviorSearch] = useState('');
  const [selectedChildId, setSelectedChildId] = useState(null);
  const [selectedChildDetail, setSelectedChildDetail] = useState(null);
  const [selectedChildInsight, setSelectedChildInsight] = useState(null);
  const [selectedChildAlerts, setSelectedChildAlerts] = useState([]);
  const [downloadingPdf, setDownloadingPdf] = useState({});
  const [childModal, setChildModal] = useState({
    open: false,
    mode: 'create',
    child: null,
    nama: '',
    umur: '',
    saving: false,
    error: '',
  });
  const [loading, setLoading] = useState(true);
  const [detailLoading, setDetailLoading] = useState(false);
  const [error, setError] = useState('');
  const navigate = useNavigate();

  useEffect(() => {
    let active = true;

    const load = async () => {
      try {
        setLoading(true);
        const [overviewData, usersData, childrenData, activitiesData, behaviorData] = await Promise.all([
          api.getAdminOverview(),
          api.getAdminUsers(),
          api.getAdminChildren(),
          api.getAdminActivities(),
          api.getAdminBehaviorEvents(),
        ]);

        if (!active) return;
        setOverview(overviewData);
        setUsers(usersData);
        setChildren(childrenData);
        setActivities(activitiesData);
        setBehaviorEvents(behaviorData);
        setError('');

        if (childrenData.length > 0) {
          setSelectedChildId((current) => current ?? childrenData[0].id);
        } else {
          setSelectedChildDetail(null);
        }
      } catch (err) {
        if (active) setError(err.message || 'Gagal memuat dashboard admin');
      } finally {
        if (active) setLoading(false);
      }
    };

    load();

    return () => {
      active = false;
    };
  }, []);

  useEffect(() => {
    const id = setInterval(() => {
      handleRefresh();
    }, 30000);
    return () => clearInterval(id);
  }, []);

  useEffect(() => {
    let active = true;

    const loadDetail = async () => {
      if (!selectedChildId) return;
      try {
        setDetailLoading(true);
        const detail = await api.getAdminChildAnalytics(selectedChildId);
        if (active) setSelectedChildDetail(detail);
      } catch {
        if (active) setSelectedChildDetail(null);
      } finally {
        if (active) setDetailLoading(false);
      }
    };

    loadDetail();

    return () => {
      active = false;
    };
  }, [selectedChildId]);

  const handleLogout = () => {
    api.logout();
    navigate('/login');
  };

  const handleRefresh = async () => {
    setLoading(true);
    try {
      const [overviewData, usersData, childrenData, activitiesData, behaviorData] = await Promise.all([
        api.getAdminOverview(),
        api.getAdminUsers(),
        api.getAdminChildren(),
        api.getAdminActivities(),
        api.getAdminBehaviorEvents({ query: behaviorSearch.trim() }),
      ]);
      setOverview(overviewData);
      setUsers(usersData);
      setChildren(childrenData);
      setActivities(activitiesData);
      setBehaviorEvents(behaviorData);
      setError('');
    } catch (err) {
      setError(err.message || 'Gagal memuat data');
    } finally {
      setLoading(false);
    }
  };

  const handleEnableAlerts = async () => {
    try {
      await enableWebPushNotifications();
      alert('Notifikasi push berhasil diaktifkan');
    } catch (err) {
      setError(err.message || 'Gagal mengaktifkan notifikasi push');
    }
  };

  const jumpToSection = (sectionId) => {
    setActiveSection(sectionId);
    const target = document.getElementById(sectionId);
    if (target) {
      target.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }
  };

  const closeChildModal = () => {
    setChildModal({
      open: false,
      mode: 'create',
      child: null,
      nama: '',
      umur: '',
      saving: false,
      error: '',
    });
  };

  const openCreateChildModal = () => {
    setChildModal({
      open: true,
      mode: 'create',
      child: null,
      nama: '',
      umur: '',
      saving: false,
      error: '',
    });
  };

  const openEditChildModal = (child) => {
    setChildModal({
      open: true,
      mode: 'edit',
      child,
      nama: child.nama || '',
      umur: String(child.umur ?? ''),
      saving: false,
      error: '',
    });
  };

  const handleDeleteChild = async (child) => {
    if (!window.confirm(`Hapus anak ${child.nama}?`)) return;
    try {
      await api.deleteAdminChild(child.id);
      if (selectedChildId === child.id) setSelectedChildId(null);
      await handleRefresh();
    } catch (e) {
      setError(e.message || 'Gagal menghapus anak');
    }
  };

  const handleDeleteLoginHistory = async (user) => {
    const confirmed = window.confirm(
      `Hapus semua riwayat login untuk ${user.email}? Tindakan ini tidak bisa dibatalkan.`
    );
    if (!confirmed) return;

    try {
      const result = await api.deleteAdminUserLoginHistory(user.id);
      alert(result?.message || 'Riwayat login berhasil dihapus');
    } catch (e) {
      setError(e.message || 'Gagal menghapus riwayat login user');
    }
  };

  const handleDeleteUser = async (user) => {
    const confirmed = window.confirm(
      `Hapus akun ${user.email} beserta semua data terkait (anak, riwayat, dll)? Tindakan ini tidak bisa dibatalkan.`
    );
    if (!confirmed) return;

    try {
      const result = await api.deleteAdminUser(user.id);
      alert(result?.message || 'Akun user berhasil dihapus');
      await handleRefresh();
    } catch (e) {
      setError(e.message || 'Gagal menghapus akun user');
    }
  };

  const handleDeleteActivity = async (activity) => {
    const confirmed = window.confirm('Hapus catatan aktivitas ini secara permanen?');
    if (!confirmed) return;

    try {
      await api.deleteAdminActivity(activity.id);
      await handleRefresh();
    } catch (err) {
      setError(err.message || 'Gagal menghapus aktivitas');
    }
  };

  const handleDeleteBehaviorEvent = async (event) => {
    const confirmed = window.confirm('Hapus catatan perilaku sensitif ini? Tindakan akan masuk ke audit dan insight tidak lagi menghitungnya.');
    if (!confirmed) return;
    try {
      await api.deleteAdminBehaviorEvent(event.id);
      await handleRefresh();
    } catch (err) {
      setError(err.message || 'Gagal menghapus catatan perilaku');
    }
  };

  const handleDownloadPdf = async (period) => {
    if (!selectedChildId) return;
    try {
      setDownloadingPdf((prev) => ({ ...prev, [period]: true }));
      const blob = await api.downloadGrowthPredictionPdf(selectedChildId, period);
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      const childName = selectedChildDetail?.child?.nama || `child_${selectedChildId}`;
      a.download = `growth_report_${period}_${childName}.pdf`;
      document.body.appendChild(a);
      a.click();
      window.URL.revokeObjectURL(url);
      document.body.removeChild(a);
    } catch (e) {
      setError(e.message || `Gagal mengunduh PDF untuk periode ${period}`);
    } finally {
      setDownloadingPdf((prev) => ({ ...prev, [period]: false }));
    }
  };

  const submitChildModal = async (event) => {
    event.preventDefault();
    const trimmedName = childModal.nama.trim();
    const parsedAge = Number.parseInt(childModal.umur, 10);

    if (!trimmedName) {
      setChildModal((prev) => ({ ...prev, error: 'Nama anak wajib diisi' }));
      return;
    }

    if (!Number.isFinite(parsedAge) || parsedAge < 0) {
      setChildModal((prev) => ({ ...prev, error: 'Umur harus berupa angka valid' }));
      return;
    }

    setChildModal((prev) => ({ ...prev, saving: true, error: '' }));
    try {
      if (childModal.mode === 'edit' && childModal.child) {
        await api.updateChild(childModal.child.id, trimmedName, parsedAge);
        if (selectedChildId === childModal.child.id) {
          setSelectedChildId(childModal.child.id);
        }
      } else {
        const created = await api.createChild(trimmedName, parsedAge);
        if (created?.id) {
          setSelectedChildId(created.id);
        }
      }
      await handleRefresh();
      closeChildModal();
    } catch (e) {
      setChildModal((prev) => ({
        ...prev,
        saving: false,
        error: e.message || 'Gagal menyimpan data anak',
      }));
    }
  };

  // Load insights & alerts for selected child
  useEffect(() => {
    let alive = true;
    const loadExtras = async () => {
      if (!selectedChildId) {
        setSelectedChildInsight(null);
        setSelectedChildAlerts([]);
        return;
      }
      try {
        const [ins, alerts] = await Promise.all([
          api.getChildInsights(selectedChildId).catch(() => null),
          api.getChildAlerts(selectedChildId).catch(() => ({ alerts: [] })),
        ]);
        if (!alive) return;
        setSelectedChildInsight(ins);
        setSelectedChildAlerts((alerts && alerts.alerts) || []);
      } catch {
        if (alive) {
          setSelectedChildInsight(null);
          setSelectedChildAlerts([]);
        }
      }
    };
    loadExtras();
    return () => {
      alive = false;
    };
  }, [selectedChildId]);

  // Simple polling to show browser notifications for alerts (every 60s)
  useEffect(() => {
    let mounted = true;
    let lastAlerts = {};
    const poll = async () => {
      if (!selectedChildId) return;
      try {
        const res = await api.getChildAlerts(selectedChildId).catch(() => ({ alerts: [] }));
        const alerts = (res && res.alerts) || [];
        if (!mounted) return;
        setSelectedChildAlerts(alerts);
        // Notify on newly appeared alerts
        const key = String(selectedChildId);
        const prev = lastAlerts[key] || [];
        const newOnes = alerts.filter(a => !prev.some(p => p.type === a.type && p.message === a.message));
        if (newOnes.length && typeof window.Notification !== 'undefined' && Notification.permission === 'granted') {
          newOnes.forEach(a => new Notification(`Alert: ${a.type}`, { body: a.message }));
        }
        lastAlerts[key] = alerts;
      } catch {
        return;
      }
    };
    const id = setInterval(poll, 60000);
    // initial poll
    poll();
    return () => {
      mounted = false;
      clearInterval(id);
    };
  }, [selectedChildId]);

  const weeklySeries = normalizeWeeklySeries(overview?.weekly_series);
  const hasWeeklySeries = Object.values(weeklySeries).some((value) => Number(value) > 0);
  const fallbackSeries = fallbackSeriesFromActivities(overview?.latest_activities || activities);
  const chartSeries = hasWeeklySeries ? weeklySeries : fallbackSeries;
  const maxSeries = Math.max(1, ...Object.values(chartSeries).map((value) => Number(value) || 0));
  const summary = overview?.summary || {};

  if (loading) {
    return <div className="admin-loading">Memuat dashboard super admin...</div>;
  }

  return (
    <div className="admin-shell">
      <aside className="admin-sidebar">
        <div className="brand">SchoolHub</div>
        <nav className="sidebar-nav">
          <button className={`nav-item ${activeSection === 'overview' ? 'active' : ''}`} onClick={() => jumpToSection('overview')}>Dashboard</button>
          <button className={`nav-item ${activeSection === 'users' ? 'active' : ''}`} onClick={() => jumpToSection('users')}>Users</button>
          <button className={`nav-item ${activeSection === 'children' ? 'active' : ''}`} onClick={() => jumpToSection('children')}>Children</button>
          <button className={`nav-item ${activeSection === 'activities' ? 'active' : ''}`} onClick={() => jumpToSection('activities')}>Activities</button>
          <button className={`nav-item ${activeSection === 'insights' ? 'active' : ''}`} onClick={() => jumpToSection('insights')}>Insights</button>
          <button className={`nav-item ${activeSection === 'alerts' ? 'active' : ''}`} onClick={() => jumpToSection('alerts')}>Alerts</button>
          <button className={`nav-item ${activeSection === 'notifications' ? 'active' : ''}`} onClick={() => jumpToSection('notifications')}>Notifications</button>
        </nav>
        <div className="sidebar-footer">
          <button className="nav-item">Profile</button>
          <button className="nav-item" onClick={handleLogout}>Logout</button>
        </div>
      </aside>

      <main className="admin-page">
        <header className="admin-hero" id="overview">
          <div>
            <p className="eyebrow">Super Admin Web</p>
            <h1>Monitoring parent, delegasi, anak, insight, dan grafik</h1>
            <p className="hero-copy">
              Dashboard super admin menampilkan ringkasan data parent, delegasi, semua anak, aktivitas terbaru, dan insight otomatis.
            </p>
          </div>
          <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
            <button onClick={handleRefresh} className="admin-logout">Refresh</button>
            <button onClick={handleEnableAlerts} className="admin-logout">Enable Alerts</button>
          </div>
        </header>

        {error && <div className="admin-alert">{error}</div>}

        <section className="metric-grid" id="activities">
          <div className="metric-card">
            <span>Users</span>
            <strong>{statLabel(summary.users_count || 0)}</strong>
            <small>
              {statLabel(summary.parent_count ?? summary.orang_tua_count ?? 0)} parent · {statLabel(summary.delegated_parent_count ?? summary.delegasi_count ?? 0)} delegasi
            </small>
          </div>
          <div className="metric-card">
            <span>Children</span>
            <strong>{statLabel(summary.children_count || 0)}</strong>
            <small>Total entitas anak yang termonitor</small>
          </div>
          <div className="metric-card">
            <span>Activities</span>
            <strong>{statLabel(summary.activities_count || 0)}</strong>
            <small>{statLabel(summary.activity_types_count || 0)} tipe aktivitas</small>
          </div>
          <div className="metric-card">
            <span>Top Insight</span>
            <strong>{overview?.latest_children?.[0]?.insight?.summary || 'Belum ada data'}</strong>
            <small>{overview?.latest_children?.[0]?.insight?.recommendation || 'Insight akan muncul saat data bertambah'}</small>
          </div>
        </section>

        <section className="admin-grid">
          <article className="panel panel-span-2">
            <div className="panel-header">
              <div>
                <p className="panel-kicker">Grafik Aktivitas</p>
                <h2>Distribusi aktivitas mingguan</h2>
              </div>
            </div>
            <div className="bar-chart">
              {Object.entries(chartSeries).map(([label, value]) => {
                const amount = Number(value) || 0;
                const height = `${Math.max(6, (amount / maxSeries) * 100)}%`;
                return (
                  <div key={label} className="bar-item">
                    <div className="bar-track">
                      <div className="bar-fill" style={{ height }} />
                    </div>
                    <span>{label}</span>
                    <small>{amount}</small>
                  </div>
                );
              })}
            </div>
          </article>

          <article className="panel">
            <div className="panel-header">
              <div>
                <p className="panel-kicker">Monitoring</p>
                <h2>Data terbaru</h2>
              </div>
            </div>
            <div className="activity-feed">
              {(activities || []).slice(0, 10).map((activity) => (
                <div key={activity.id} className="feed-item">
                  <div>
                    <strong>{activity.activity_type}</strong>
                    <p className="activity-value" title={String(activity.value || '')}>
                      {formatActivityValue(activity.value)}
                    </p>
                  </div>
                  <span>{formatDate(activity.created_at)}</span>
                </div>
              ))}
            </div>
          </article>
        </section>

        <section className="panel" id="activity-records">
          <div className="panel-header">
            <div>
              <p className="panel-kicker">Audit Data</p>
              <h2>Catatan aktivitas aplikasi</h2>
            </div>
            <input
              type="search"
              aria-label="Cari aktivitas"
              placeholder="Cari aktivitas, anak, atau isi"
              value={activitySearch}
              onChange={(event) => setActivitySearch(event.target.value)}
            />
          </div>
          <div className="table-wrap">
            <table className="admin-table">
              <thead>
                <tr>
                  <th>Jenis</th>
                  <th>Anak</th>
                  <th>Isi aktivitas</th>
                  <th>Waktu</th>
                  <th>Aksi</th>
                </tr>
              </thead>
              <tbody>
                {activities
                  .filter((activity) => {
                    const child = children.find((item) => String(item.id) === String(activity.child_id));
                    const searchable = [activity.activity_type, activity.value, child?.nama, activity.child_id]
                      .filter(Boolean)
                      .join(' ')
                      .toLowerCase();
                    return searchable.includes(activitySearch.trim().toLowerCase());
                  })
                  .map((activity) => {
                    const child = children.find((item) => String(item.id) === String(activity.child_id));
                    return (
                      <tr key={activity.id}>
                        <td>{activity.activity_type || 'Aktivitas'}</td>
                        <td>{child?.nama || activity.child_id || '—'}</td>
                        <td className="activity-value" title={String(activity.value || '')}>
                          {formatActivityValue(activity.value)}
                        </td>
                        <td>{formatDate(activity.created_at)}</td>
                        <td>
                          <button
                            type="button"
                            className="table-action-btn danger"
                            onClick={() => handleDeleteActivity(activity)}
                          >
                            Hapus aktivitas
                          </button>
                        </td>
                      </tr>
                    );
                  })}
              </tbody>
            </table>
          </div>
        </section>

        <section className="panel" id="behavior-research">
          <div className="panel-header">
            <div>
              <p className="panel-kicker">Dataset Perilaku</p>
              <h2>Catatan dan validasi caregiver</h2>
            </div>
            <div style={{ display: 'flex', gap: 8 }}>
              <input
                type="search"
                aria-label="Cari catatan perilaku"
                placeholder="Cari anak, perilaku, atau pemicu"
                value={behaviorSearch}
                onChange={(event) => setBehaviorSearch(event.target.value)}
                onKeyDown={(event) => {
                  if (event.key === 'Enter') handleRefresh();
                }}
              />
              <button type="button" className="table-action-btn" onClick={handleRefresh}>
                Cari
              </button>
            </div>
          </div>
          <div className="table-wrap">
            <table className="admin-table">
              <thead>
                <tr>
                  <th>Anak</th>
                  <th>Perilaku</th>
                  <th>Pemicu</th>
                  <th>Durasi / intensitas</th>
                  <th>Status</th>
                  <th>Waktu kejadian</th>
                  <th>Aksi</th>
                </tr>
              </thead>
              <tbody>
                {behaviorEvents.map((event) => {
                  const child = children.find((item) => String(item.id) === String(event.child_id));
                  return (
                    <tr key={event.id}>
                      <td>{event.child_name || child?.nama || event.child_id}</td>
                      <td>{String(event.behavior_type || 'lainnya').replaceAll('_', ' ')}</td>
                      <td>{event.trigger_text || 'Tidak dicatat'}</td>
                      <td>{event.duration_minutes == null ? 'Durasi tidak diketahui' : `${event.duration_minutes} menit`} · {event.intensity || 'unknown'}</td>
                      <td>{event.validation_status || 'pending'}</td>
                      <td>{formatDate(event.event_at)}</td>
                      <td>
                        <button type="button" className="table-action-btn danger" onClick={() => handleDeleteBehaviorEvent(event)}>
                          Hapus catatan
                        </button>
                      </td>
                    </tr>
                  );
                })}
                {!behaviorEvents.length && (
                  <tr><td colSpan="7">Belum ada catatan perilaku.</td></tr>
                )}
              </tbody>
            </table>
          </div>
        </section>

        <section className="panel" id="users">
          <div className="panel-header">
            <div>
              <p className="panel-kicker">Users</p>
              <h2>Semua akun terdaftar</h2>
            </div>
          </div>
          <div className="table-wrap">
            <table className="admin-table">
              <thead>
                <tr>
                  <th>ID</th>
                  <th>Email</th>
                  <th>Role</th>
                  <th>Dibuat</th>
                  <th>Aksi</th>
                </tr>
              </thead>
              <tbody>
                {users
                  .filter((user) => ['parent', 'delegated_parent', 'orang_tua', 'delegasi'].includes(String(user.role || '').toLowerCase()))
                  .map((user) => (
                  <tr key={`${user.id}-${user.email}`}>
                    <td>{user.id}</td>
                    <td>{user.email}</td>
                    <td>
                      <span className={`role-pill role-${String(user.role || 'parent').toLowerCase()}`}>
                        {user.role || 'parent'}
                      </span>
                    </td>
                    <td>{formatDate(user.created_at)}</td>
                    <td>
                      <button
                        type="button"
                        className="table-action-btn danger"
                        onClick={() => handleDeleteLoginHistory(user)}
                      >
                        Hapus Riwayat Login
                      </button>
                      <button
                        type="button"
                        className="table-action-btn danger"
                        onClick={() => handleDeleteUser(user)}
                        style={{ marginLeft: '8px' }}
                      >
                        Hapus Akun
                      </button>
                    </td>
                  </tr>
                  ))}
              </tbody>
            </table>
          </div>
        </section>

        <section className="admin-grid" id="children">
          <article className="panel panel-span-2">
            <div className="panel-header">
              <div>
                <p className="panel-kicker">Children</p>
                <h2>Daftar semua anak</h2>
              </div>
              <div>
                <button className="admin-logout" onClick={openCreateChildModal}>Tambah Anak</button>
              </div>
            </div>
            <div className="child-grid">
              {children.map((child) => {
                const isSelected = selectedChildId === child.id;
                return (
                  <div
                    key={child.id}
                    className={`child-tile ${isSelected ? 'selected' : ''}`}
                    onClick={() => setSelectedChildId(child.id)}
                    role="button"
                    tabIndex={0}
                    onKeyDown={(event) => {
                      if (event.key === 'Enter' || event.key === ' ') {
                        event.preventDefault();
                        setSelectedChildId(child.id);
                      }
                    }}
                  >
                    <strong>{child.nama}</strong>
                    <span>{child.umur} tahun</span>
                    <small>Parent: {child.parent_email || child.parent_uid || child.parent_id}</small>
                    <div className="child-actions" onClick={(e) => e.stopPropagation()}>
                      <button type="button" className="child-action-btn" onClick={() => openEditChildModal(child)}>Edit</button>
                      <button type="button" className="child-action-btn danger" onClick={() => handleDeleteChild(child)}>Hapus</button>
                    </div>
                  </div>
                );
              })}
            </div>
          </article>

          <article className="panel">
            <div className="panel-header">
              <div>
                <p className="panel-kicker">Insight</p>
                <h2>Detail anak terpilih</h2>
              </div>
            </div>
            {detailLoading ? (
              <div className="empty-state">Memuat insight...</div>
            ) : selectedChildDetail ? (
              <div className="detail-stack">
                <div className="detail-card">
                  <span className="detail-label">Anak</span>
                  <strong>{selectedChildDetail.child?.nama}</strong>
                  <p>{selectedChildDetail.child?.umur} tahun</p>
                </div>
                <div className="detail-card accent">
                  <span className="detail-label">Kesimpulan Perkembangan</span>
                  <strong style={{color:'#1a237e'}}>{selectedChildDetail.insight?.summary || '-'}</strong>
                  <br />
                  <span className="detail-label">Saran AI</span>
                  <span style={{color:'#00695c'}}>{selectedChildDetail.insight?.recommendation || '-'}</span>
                </div>
                <div className="detail-card">
                  <span className="detail-label">Monitoring</span>
                  <strong>{selectedChildDetail.analytics?.checkin_rate || 0}%</strong>
                  <p>{selectedChildDetail.activity_count || 0} aktivitas tercatat</p>
                </div>
                <div className="detail-card">
                  <span className="detail-label">Download Laporan PDF</span>
                  <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                    <button
                      type="button"
                      className="child-action-btn"
                      onClick={() => handleDownloadPdf('7day')}
                      disabled={downloadingPdf['7day']}
                    >
                      {downloadingPdf['7day'] ? 'Mengunduh...' : '7 Hari'}
                    </button>
                    <button
                      type="button"
                      className="child-action-btn"
                      onClick={() => handleDownloadPdf('30day')}
                      disabled={downloadingPdf['30day']}
                    >
                      {downloadingPdf['30day'] ? 'Mengunduh...' : '30 Hari'}
                    </button>
                    <button
                      type="button"
                      className="child-action-btn"
                      onClick={() => handleDownloadPdf('3month')}
                      disabled={downloadingPdf['3month']}
                    >
                      {downloadingPdf['3month'] ? 'Mengunduh...' : '3 Bulan'}
                    </button>
                  </div>
                </div>
                {selectedChildInsight && (
                  <div className="detail-card">
                    <span className="detail-label">AI Insight</span>
                    <strong>{selectedChildInsight.insight_text || 'Belum ada insight'}</strong>
                    <p>Provider: {selectedChildInsight.provider || 'stub'}</p>
                  </div>
                )}
                {selectedChildAlerts.length > 0 && (
                  <div className="detail-card" id="alerts">
                    <span className="detail-label">Early Warning</span>
                    <ul className="alert-list">
                      {selectedChildAlerts.map((alert, index) => (
                        <li key={`${alert.type}-${index}`}>
                          <strong>{alert.type}</strong>
                          <span>{alert.message}</span>
                        </li>
                      ))}
                    </ul>
                  </div>
                )}
              </div>
            ) : (
              <div className="empty-state">Pilih anak untuk melihat insight.</div>
            )}
          </article>
        </section>

        <section className="panel" id="insights">
          <div className="panel-header">
            <div>
              <p className="panel-kicker">Monitoring Tren</p>
              <h2>Insight cepat dari 12 anak terbaru</h2>
            </div>
          </div>
          <div className="insight-list">
            {(overview?.latest_children || []).map((item) => (
              <div key={item.id} className="insight-row">
                <div>
                  <strong>{item.nama}</strong>
                  <p>{item.insight?.summary}</p>
                </div>
                <div className="insight-meta">
                  <span>{item.consistency_rate || 0}% konsistensi</span>
                  <small>{item.week_activities || 0} aktivitas minggu ini</small>
                </div>
              </div>
            ))}
          </div>
        </section>
      </main>

      <aside className="admin-right">
        <div className="calendar panel">
          <div className="panel-header">
            <div>
              <p className="panel-kicker">September 2030</p>
              <h3>Agenda</h3>
            </div>
          </div>
          <div className="agenda">
            {(overview?.latest_activities || []).slice(0, 6).map((act, idx) => (
              <div key={act.id || idx} className="agenda-item">
                <strong>{new Date(act.created_at).toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' })}</strong>
                <span className="activity-value" title={String(act.value || '')}>
                  {act.activity_type} • {formatActivityValue(act.value)}
                </span>
              </div>
            ))}
            {(!(overview?.latest_activities || []).length) && <div className="agenda-item">Tidak ada agenda</div>}
          </div>
        </div>

        <div className="panel messages" id="notifications">
          <div className="panel-header">
            <div>
              <p className="panel-kicker">Messages</p>
              <h3>Recent messages</h3>
            </div>
          </div>
          <div className="message-list">
            {(overview?.latest_activities || []).slice(0, 6).map((m, idx) => (
              <div key={m.id || idx} className="message-item">
                <strong>{m.activity_type}</strong>
                <p className="activity-value" title={String(m.value || '')}>
                  {formatActivityValue(m.value || '—')}
                </p>
                <small>{formatDate(m.created_at)}</small>
              </div>
            ))}
            {(!(overview?.latest_activities || []).length) && <div className="message-item">Belum ada pesan</div>}
          </div>
        </div>
      </aside>

      {childModal.open && (
        <div className="modal-backdrop" role="presentation" onClick={closeChildModal}>
          <div className="modal-card" role="dialog" aria-modal="true" aria-labelledby="child-modal-title" onClick={(event) => event.stopPropagation()}>
            <div className="modal-header">
              <div>
                <p className="panel-kicker">{childModal.mode === 'edit' ? 'Edit Anak' : 'Tambah Anak'}</p>
                <h3 id="child-modal-title">{childModal.mode === 'edit' ? 'Ubah data anak' : 'Tambah anak baru'}</h3>
              </div>
              <button type="button" className="modal-close" onClick={closeChildModal}>×</button>
            </div>

            <form className="modal-form" onSubmit={submitChildModal}>
              <label className="form-field">
                <span>Nama anak</span>
                <input
                  type="text"
                  value={childModal.nama}
                  onChange={(event) => setChildModal((prev) => ({ ...prev, nama: event.target.value }))}
                  placeholder="Contoh: Aisyah"
                  autoComplete="off"
                />
              </label>

              <label className="form-field">
                <span>Umur</span>
                <input
                  type="number"
                  min="0"
                  max="99"
                  value={childModal.umur}
                  onChange={(event) => setChildModal((prev) => ({ ...prev, umur: event.target.value }))}
                  placeholder="Contoh: 7"
                />
              </label>

              {childModal.error && <div className="form-error">{childModal.error}</div>}

              <div className="form-actions">
                <button type="button" className="form-button secondary" onClick={closeChildModal} disabled={childModal.saving}>
                  Batal
                </button>
                <button type="submit" className="form-button primary" disabled={childModal.saving}>
                  {childModal.saving ? 'Menyimpan...' : childModal.mode === 'edit' ? 'Simpan Perubahan' : 'Tambah Anak'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
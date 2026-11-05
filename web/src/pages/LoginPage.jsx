import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import api from '../services/api';
import '../styles/auth.css';

export default function LoginPage() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [captcha, setCaptcha] = useState(null);
  const [captchaAnswer, setCaptchaAnswer] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const navigate = useNavigate();

  const refreshCaptcha = async () => {
    try {
      setCaptcha(await api.getAdminCaptcha());
      setCaptchaAnswer('');
    } catch (err) {
      setError(err.message || 'Gagal memuat verifikasi login');
    }
  };

  useEffect(() => {
    let active = true;
    api.getAdminCaptcha()
      .then((challenge) => {
        if (active) setCaptcha(challenge);
      })
      .catch((err) => {
        if (active) setError(err.message || 'Gagal memuat verifikasi login');
      });
    return () => {
      active = false;
    };
  }, []);

  const handleLogin = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      const response = await api.adminLogin(
        email,
        password,
        captcha?.session_id,
        captchaAnswer,
      );
      if (response.role === 'super_admin') {
        navigate('/admin');
      } else {
        setError('Akun ini tidak memiliki akses super admin.');
      }
    } catch (err) {
      setError(err.message || 'Login failed');
      await refreshCaptcha();
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="auth-container">
      <div className="auth-card">
        <h1>Patara AI</h1>
        <p className="subtitle">Portal administrasi PATARA AI</p>

        <form onSubmit={handleLogin}>
          <div className="form-group">
            <label>Email</label>
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="your@email.com"
              required
            />
          </div>

          <div className="form-group">
            <label>Password</label>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="••••••••"
              required
            />
          </div>

          <div className="form-group">
            <label htmlFor="admin-captcha-answer">Verifikasi: {captcha?.question || 'memuat...'}</label>
            <input
              id="admin-captcha-answer"
              type="text"
              inputMode="numeric"
              autoComplete="off"
              value={captchaAnswer}
              onChange={(event) => setCaptchaAnswer(event.target.value)}
              required
            />
          </div>

          {error && <div className="error-message">{error}</div>}

          <button type="submit" disabled={loading || !captcha?.session_id} className="btn-primary">
            {loading ? 'Logging in...' : 'Login'}
          </button>
        </form>

        <div className="auth-footer">
          <p className="auth-note">
            Masuk hanya dengan akun super admin yang dibuat oleh administrator sistem.
          </p>
        </div>
      </div>
    </div>
  );
}

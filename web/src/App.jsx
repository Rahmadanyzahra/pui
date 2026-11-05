import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom';

import LoginPage from './pages/LoginPage';
import AdminDashboard from './pages/AdminDashboard';

function getSession() {
  const role = localStorage.getItem('role') || 'parent';
  return {
    token: localStorage.getItem('admin_session'),
    role: role === 'admin' ? 'super_admin' : role,
  };
}

function PublicGate({ children }) {
  const { token, role } = getSession();
  if (token && role === 'super_admin') return <Navigate to="/admin" replace />;
  return children;
}

function ProtectedGate({ children, roles }) {
  const { token, role } = getSession();

  if (!token) {
    return <Navigate to="/login" replace />;
  }

  if (roles && !roles.includes(role)) {
    return <Navigate to="/login" replace />;
  }

  return children;
}

function RootRedirect() {
  const { token, role } = getSession();
  if (token && role === 'super_admin') return <Navigate to="/admin" replace />;
  return <Navigate to="/login" replace />;
}

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<RootRedirect />} />
        <Route
          path="/login"
          element={
            <PublicGate>
              <LoginPage />
            </PublicGate>
          }
        />
        <Route path="/register" element={<Navigate to="/login" replace />} />
        <Route
          path="/admin"
          element={
            <ProtectedGate roles={['super_admin']}>
              <AdminDashboard />
            </ProtectedGate>
          }
        />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  );
}
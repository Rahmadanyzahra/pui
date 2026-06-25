import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom';

import LoginPage from './pages/LoginPage';
import RegisterPage from './pages/RegisterPage';
import ParentDashboard from './pages/ParentDashboard';
import ChildDashboard from './pages/ChildDashboard';
import AdminDashboard from './pages/AdminDashboard';

function getSession() {
  const role = localStorage.getItem('role') || 'parent';
  return {
    token: localStorage.getItem('token'),
    role: role === 'admin' ? 'super_admin' : role,
  };
}

function PublicGate({ children }) {
  const { token, role } = getSession();
  if (!token) return children;
  return <Navigate to={role === 'super_admin' ? '/admin' : '/dashboard'} replace />;
}

function ProtectedGate({ children, roles }) {
  const { token, role } = getSession();

  if (!token) {
    return <Navigate to="/login" replace />;
  }

  if (roles && !roles.includes(role)) {
    return <Navigate to={role === 'super_admin' ? '/admin' : '/dashboard'} replace />;
  }

  return children;
}

function RootRedirect() {
  const { token, role } = getSession();
  if (!token) return <Navigate to="/login" replace />;
  return <Navigate to={role === 'super_admin' ? '/admin' : '/dashboard'} replace />;
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
        <Route
          path="/register"
          element={
            <PublicGate>
              <RegisterPage />
            </PublicGate>
          }
        />
        <Route
          path="/dashboard"
          element={
            <ProtectedGate roles={['parent','delegated_parent']}>
              <ParentDashboard />
            </ProtectedGate>
          }
        />
        <Route
          path="/child/:childId"
          element={
            <ProtectedGate roles={['parent', 'delegated_parent', 'super_admin']}>
              <ChildDashboard />
            </ProtectedGate>
          }
        />
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
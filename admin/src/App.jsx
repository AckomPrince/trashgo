import React from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { Toaster } from 'react-hot-toast';
import { AuthProvider, useAuth } from './context/AuthContext';
import Layout from './components/Layout';
import Login     from './pages/Login';
import Dashboard from './pages/Dashboard';
import Riders    from './pages/Riders';
import Orders    from './pages/Orders';
import Analytics from './pages/Analytics';
import Disputes  from './pages/Disputes';
import Pricing   from './pages/Pricing';

function PrivateRoute({ children }) {
  const { user, loading } = useAuth();
  if (loading) return (
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', minHeight: '100vh' }}>
      <div style={{ width: 40, height: 40, border: '3px solid #2E7D32', borderTopColor: 'transparent', borderRadius: '50%', animation: 'spin 1s linear infinite' }} />
    </div>
  );
  return user ? <Layout>{children}</Layout> : <Navigate to="/login" replace />;
}

export default function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Toaster position="top-right" toastOptions={{ style: { fontFamily: 'Inter, sans-serif', fontSize: 14 } }} />
        <style>{`* { font-family: Inter, system-ui, sans-serif; } @keyframes spin { to { transform: rotate(360deg); } }`}</style>
        <Routes>
          <Route path="/login" element={<Login />} />
          <Route path="/"          element={<PrivateRoute><Dashboard /></PrivateRoute>} />
          <Route path="/riders"    element={<PrivateRoute><Riders /></PrivateRoute>} />
          <Route path="/orders"    element={<PrivateRoute><Orders /></PrivateRoute>} />
          <Route path="/analytics" element={<PrivateRoute><Analytics /></PrivateRoute>} />
          <Route path="/disputes"  element={<PrivateRoute><Disputes /></PrivateRoute>} />
          <Route path="/pricing"   element={<PrivateRoute><Pricing /></PrivateRoute>} />
          <Route path="*"          element={<Navigate to="/" replace />} />
        </Routes>
      </BrowserRouter>
    </AuthProvider>
  );
}

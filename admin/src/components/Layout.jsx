import React, { useState } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import {
  LayoutDashboard, Users, Package, BarChart2,
  AlertTriangle, Settings, LogOut, Menu, X, Trash2
} from 'lucide-react';

const NAV = [
  { to: '/',          icon: LayoutDashboard, label: 'Dashboard' },
  { to: '/riders',    icon: Users,           label: 'Riders' },
  { to: '/orders',    icon: Package,         label: 'Orders' },
  { to: '/analytics', icon: BarChart2,       label: 'Analytics' },
  { to: '/disputes',  icon: AlertTriangle,   label: 'Disputes' },
  { to: '/pricing',   icon: Settings,        label: 'Pricing' },
];

const G = '#2E7D32';

export default function Layout({ children }) {
  const { user, logout } = useAuth();
  const { pathname }     = useLocation();
  const navigate         = useNavigate();
  const [open, setOpen]  = useState(false);

  const handleLogout = () => { logout(); navigate('/login'); };

  const Sidebar = () => (
    <aside style={{
      width: 240, minHeight: '100vh', background: '#1B5E20',
      display: 'flex', flexDirection: 'column', flexShrink: 0,
    }}>
      {/* Logo */}
      <div style={{ padding: '24px 20px', borderBottom: '1px solid rgba(255,255,255,0.1)', display: 'flex', alignItems: 'center', gap: 10 }}>
        <div style={{ background: 'white', borderRadius: 10, padding: 6 }}>
          <Trash2 size={22} color={G} />
        </div>
        <div>
          <div style={{ color: 'white', fontWeight: 700, fontSize: 18 }}>TrashGo</div>
          <div style={{ color: 'rgba(255,255,255,0.6)', fontSize: 11 }}>Admin Portal</div>
        </div>
      </div>

      {/* Nav */}
      <nav style={{ flex: 1, padding: '12px 8px' }}>
        {NAV.map(({ to, icon: Icon, label }) => {
          const active = pathname === to;
          return (
            <Link key={to} to={to} onClick={() => setOpen(false)} style={{
              display: 'flex', alignItems: 'center', gap: 12,
              padding: '10px 14px', borderRadius: 10, margin: '2px 0',
              background: active ? 'rgba(255,255,255,0.15)' : 'transparent',
              color: active ? 'white' : 'rgba(255,255,255,0.7)',
              textDecoration: 'none', fontWeight: active ? 600 : 400,
              transition: 'all 0.2s',
            }}>
              <Icon size={18} />
              <span>{label}</span>
            </Link>
          );
        })}
      </nav>

      {/* User */}
      <div style={{ padding: 16, borderTop: '1px solid rgba(255,255,255,0.1)' }}>
        <div style={{ color: 'rgba(255,255,255,0.8)', fontSize: 13, marginBottom: 8 }}>
          {user?.full_name}
        </div>
        <button onClick={handleLogout} style={{
          display: 'flex', alignItems: 'center', gap: 8,
          color: 'rgba(255,255,255,0.7)', background: 'none',
          border: 'none', cursor: 'pointer', fontSize: 13, padding: 0,
        }}>
          <LogOut size={16} /> Logout
        </button>
      </div>
    </aside>
  );

  return (
    <div style={{ display: 'flex', minHeight: '100vh', background: '#F5F5F5', fontFamily: 'Inter, sans-serif' }}>
      {/* Desktop sidebar */}
      <div style={{ display: 'none' }} className="desktop-sidebar">
        <Sidebar />
      </div>
      <Sidebar />

      {/* Main content */}
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', minWidth: 0 }}>
        {/* Top bar */}
        <header style={{
          background: 'white', padding: '0 24px', height: 60,
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          borderBottom: '1px solid #E0E0E0', position: 'sticky', top: 0, zIndex: 10,
        }}>
          <span style={{ fontWeight: 600, color: '#333' }}>
            {NAV.find(n => n.to === pathname)?.label || 'TrashGo Admin'}
          </span>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <div style={{ width: 36, height: 36, borderRadius: '50%', background: G, display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'white', fontWeight: 700 }}>
              {user?.full_name?.[0]?.toUpperCase()}
            </div>
          </div>
        </header>
        <main style={{ flex: 1, padding: 24, overflow: 'auto' }}>
          {children}
        </main>
      </div>
    </div>
  );
}

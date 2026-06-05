import React, { useEffect, useState } from 'react';
import { Users, Package, DollarSign, AlertCircle, CheckCircle, Clock, XCircle, UserCheck } from 'lucide-react';
import api from '../api/axios';

const G = '#2E7D32';

function StatCard({ icon: Icon, label, value, color = G, bg = '#E8F5E9' }) {
  return (
    <div style={{ background: 'white', borderRadius: 16, padding: 20, boxShadow: '0 2px 8px rgba(0,0,0,0.06)', display: 'flex', alignItems: 'center', gap: 16 }}>
      <div style={{ width: 52, height: 52, background: bg, borderRadius: 14, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <Icon size={24} color={color} />
      </div>
      <div>
        <div style={{ fontSize: 24, fontWeight: 700, color: '#1A1A1A' }}>{value}</div>
        <div style={{ fontSize: 13, color: '#757575' }}>{label}</div>
      </div>
    </div>
  );
}

export default function Dashboard() {
  const [stats, setStats]   = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    api.get('/admin/dashboard')
      .then(r => setStats(r.data.stats))
      .catch(() => {})
      .finally(() => setLoading(false));
  }, []);

  if (loading) return <div style={{ display: 'flex', justifyContent: 'center', padding: 60 }}><div style={{ width: 40, height: 40, border: `3px solid ${G}`, borderTopColor: 'transparent', borderRadius: '50%', animation: 'spin 1s linear infinite' }} /></div>;

  return (
    <div>
      <h1 style={{ margin: '0 0 24px', fontSize: 22, fontWeight: 700 }}>Dashboard</h1>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: 16, marginBottom: 32 }}>
        <StatCard icon={Users}      label="Total Customers" value={stats?.total_customers ?? 0} />
        <StatCard icon={UserCheck}  label="Total Riders"    value={stats?.total_riders ?? 0} color="#1565C0" bg="#E3F2FD" />
        <StatCard icon={Package}    label="Total Orders"    value={stats?.total_orders ?? 0}   color="#F57C00" bg="#FFF3E0" />
        <StatCard icon={DollarSign} label="Revenue (GHS)"  value={`GHS ${parseFloat(stats?.total_revenue || 0).toFixed(2)}`} color="#2E7D32" />
        <StatCard icon={CheckCircle} label="Completed"     value={stats?.completed ?? 0} color="#388E3C" bg="#E8F5E9" />
        <StatCard icon={Clock}      label="Active Orders"  value={stats?.active ?? 0}    color="#F57C00" bg="#FFF3E0" />
        <StatCard icon={XCircle}    label="Cancelled"      value={stats?.cancelled ?? 0} color="#D32F2F" bg="#FFEBEE" />
        <StatCard icon={AlertCircle} label="Pending Riders" value={stats?.pending_rider_approvals ?? 0} color="#7B1FA2" bg="#F3E5F5" />
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 20 }}>
        <QuickActions />
        <RecentAlert stats={stats} />
      </div>
    </div>
  );
}

function QuickActions() {
  const actions = [
    { label: 'Pending Rider Approvals', href: '/riders?status=pending', color: '#7B1FA2' },
    { label: 'Active Orders',           href: '/orders?status=in_progress', color: '#F57C00' },
    { label: 'Open Disputes',           href: '/disputes', color: '#D32F2F' },
    { label: 'View Analytics',          href: '/analytics', color: '#1565C0' },
  ];
  return (
    <div style={{ background: 'white', borderRadius: 16, padding: 20, boxShadow: '0 2px 8px rgba(0,0,0,0.06)' }}>
      <h3 style={{ margin: '0 0 16px', fontSize: 16, fontWeight: 600 }}>Quick Actions</h3>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
        {actions.map(a => (
          <a key={a.href} href={a.href} style={{
            display: 'block', padding: '10px 14px', borderRadius: 10,
            background: a.color + '12', color: a.color,
            textDecoration: 'none', fontWeight: 500, fontSize: 14,
            border: `1px solid ${a.color}30`,
          }}>
            → {a.label}
          </a>
        ))}
      </div>
    </div>
  );
}

// FIX: system status now fetched from the real /admin/health endpoint
// instead of being hardcoded as ONLINE for everything.
function RecentAlert({ stats }) {
  const pending = stats?.pending_rider_approvals ?? 0;
  const [health, setHealth] = useState(null);

  useEffect(() => {
    api.get('/admin/health')
      .then(r => setHealth(r.data.checks))
      .catch(() => setHealth({ database: 'offline', firebase: 'error', paystack: 'error' }));
  }, []);

  const SERVICE_LABELS = {
    database: 'Database',
    firebase: 'Push Notifications',
    paystack: 'Payment Gateway',
  };

  return (
    <div style={{ background: 'white', borderRadius: 16, padding: 20, boxShadow: '0 2px 8px rgba(0,0,0,0.06)' }}>
      <h3 style={{ margin: '0 0 16px', fontSize: 16, fontWeight: 600 }}>System Status</h3>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
        <StatusRow label="API Server" status="online" />
        {health
          ? Object.entries(SERVICE_LABELS).map(([key, label]) => (
              <StatusRow key={key} label={label} status={health[key] ?? 'unknown'} />
            ))
          : <div style={{ color: '#999', fontSize: 13 }}>Checking services…</div>
        }
        {pending > 0 && (
          <div style={{ padding: '10px 14px', background: '#FFF3E0', borderRadius: 10, color: '#F57C00', fontSize: 13 }}>
            ⚠️ {pending} rider(s) awaiting approval
          </div>
        )}
      </div>
    </div>
  );
}

function StatusRow({ label, status }) {
  const isOk  = status === 'online';
  const color = isOk ? '#2E7D32' : status === 'unconfigured' ? '#F57C00' : '#D32F2F';
  return (
    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '6px 0', borderBottom: '1px solid #F5F5F5' }}>
      <span style={{ fontSize: 13, color: '#333' }}>{label}</span>
      <span style={{ fontSize: 12, fontWeight: 600, color, background: color + '15', padding: '2px 8px', borderRadius: 20 }}>
        {status.toUpperCase()}
      </span>
    </div>
  );
}

import React, { useEffect, useState } from 'react';
import { LineChart, Line, BarChart, Bar, PieChart, Pie, Cell, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Legend } from 'recharts';
import api from '../api/axios';
import { format } from 'date-fns';

const COLORS = ['#2E7D32', '#1565C0', '#F57C00', '#D32F2F', '#7B1FA2', '#00796B'];

export default function Analytics() {
  const [data, setData]       = useState(null);
  const [loading, setLoading] = useState(true);
  const [period, setPeriod]   = useState('30');

  useEffect(() => {
    api.get(`/admin/analytics?period=${period}`)
      .then(r => setData(r.data))
      .catch(() => {})
      .finally(() => setLoading(false));
  }, [period]);

  if (loading) return <div style={{ padding: 60, textAlign: 'center', color: '#999' }}>Loading analytics…</div>;

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 24 }}>
        <h1 style={{ margin: 0, fontSize: 22, fontWeight: 700 }}>Analytics</h1>
        <div style={{ display: 'flex', gap: 8 }}>
          {['7', '30', '90'].map(p => (
            <button key={p} onClick={() => setPeriod(p)} style={{
              padding: '7px 16px', borderRadius: 20, border: 'none', cursor: 'pointer',
              background: period === p ? '#2E7D32' : 'white', color: period === p ? 'white' : '#333',
              fontSize: 13, boxShadow: '0 1px 4px rgba(0,0,0,0.08)',
            }}>
              {p}d
            </button>
          ))}
        </div>
      </div>

      <div style={{ display: 'grid', gap: 20 }}>
        {/* Daily orders & revenue */}
        <div style={{ background: 'white', borderRadius: 16, padding: 24, boxShadow: '0 2px 8px rgba(0,0,0,0.06)' }}>
          <h3 style={{ margin: '0 0 20px', fontSize: 15, fontWeight: 600 }}>Daily Orders & Revenue</h3>
          <ResponsiveContainer width="100%" height={260}>
            <LineChart data={data?.daily_trend || []}>
              <CartesianGrid strokeDasharray="3 3" stroke="#F0F0F0" />
              <XAxis dataKey="date" tickFormatter={d => format(new Date(d), 'dd MMM')} tick={{ fontSize: 11 }} />
              <YAxis yAxisId="left" tick={{ fontSize: 11 }} />
              <YAxis yAxisId="right" orientation="right" tick={{ fontSize: 11 }} />
              <Tooltip />
              <Legend />
              <Line yAxisId="left"  type="monotone" dataKey="orders"  stroke="#2E7D32" strokeWidth={2} dot={false} name="Orders" />
              <Line yAxisId="right" type="monotone" dataKey="revenue" stroke="#F57C00" strokeWidth={2} dot={false} name="Revenue (GHS)" />
            </LineChart>
          </ResponsiveContainer>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 20 }}>
          {/* Waste type breakdown */}
          <div style={{ background: 'white', borderRadius: 16, padding: 24, boxShadow: '0 2px 8px rgba(0,0,0,0.06)' }}>
            <h3 style={{ margin: '0 0 20px', fontSize: 15, fontWeight: 600 }}>Orders by Waste Type</h3>
            <ResponsiveContainer width="100%" height={200}>
              <PieChart>
                <Pie data={data?.by_waste_type || []} dataKey="count" nameKey="waste_type" cx="50%" cy="50%" outerRadius={80} label={({ waste_type, percent }) => `${waste_type} ${(percent * 100).toFixed(0)}%`}>
                  {(data?.by_waste_type || []).map((_, i) => <Cell key={i} fill={COLORS[i % COLORS.length]} />)}
                </Pie>
                <Tooltip />
              </PieChart>
            </ResponsiveContainer>
          </div>

          {/* Order status breakdown */}
          <div style={{ background: 'white', borderRadius: 16, padding: 24, boxShadow: '0 2px 8px rgba(0,0,0,0.06)' }}>
            <h3 style={{ margin: '0 0 20px', fontSize: 15, fontWeight: 600 }}>Orders by Status</h3>
            <ResponsiveContainer width="100%" height={200}>
              <BarChart data={data?.by_status || []}>
                <CartesianGrid strokeDasharray="3 3" stroke="#F0F0F0" />
                <XAxis dataKey="status" tick={{ fontSize: 10 }} tickFormatter={s => s.replace(/_/g, ' ')} />
                <YAxis tick={{ fontSize: 11 }} />
                <Tooltip />
                <Bar dataKey="count" name="Orders" fill="#2E7D32" radius={[6, 6, 0, 0]}>
                  {(data?.by_status || []).map((_, i) => <Cell key={i} fill={COLORS[i % COLORS.length]} />)}
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* Top riders */}
        <div style={{ background: 'white', borderRadius: 16, padding: 24, boxShadow: '0 2px 8px rgba(0,0,0,0.06)' }}>
          <h3 style={{ margin: '0 0 16px', fontSize: 15, fontWeight: 600 }}>Top Riders</h3>
          <table style={{ width: '100%', borderCollapse: 'collapse' }}>
            <thead>
              <tr style={{ background: '#F5F5F5' }}>
                {['#', 'Rider', 'Jobs', 'Net Earnings'].map(h => (
                  <th key={h} style={{ padding: '8px 14px', textAlign: 'left', fontSize: 11, fontWeight: 600, color: '#757575' }}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {(data?.top_riders || []).map((r, i) => (
                <tr key={r.full_name} style={{ borderTop: '1px solid #F5F5F5' }}>
                  <td style={{ padding: '10px 14px', fontSize: 13, color: '#999' }}>{i + 1}</td>
                  <td style={{ padding: '10px 14px', fontWeight: 500 }}>{r.full_name}</td>
                  <td style={{ padding: '10px 14px', fontSize: 13 }}>{r.jobs}</td>
                  <td style={{ padding: '10px 14px', fontWeight: 600, color: '#2E7D32' }}>GHS {parseFloat(r.earnings).toFixed(2)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}

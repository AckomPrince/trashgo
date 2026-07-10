import React, { useEffect, useState } from 'react';
import api from '../api/axios';
import toast from 'react-hot-toast';
import { CheckCircle, XCircle, AlertTriangle, Eye, Truck } from 'lucide-react';

const G = '#2E7D32';

const STATUS_TABS = ['pending', 'approved', 'rejected', 'suspended'];

export default function Riders() {
  const [status, setStatus] = useState('pending');
  const [riders, setRiders] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selected, setSelected] = useState(null);
  const [actionNote, setActionNote] = useState('');
  const [acting, setActing] = useState(false);

  const load = async () => {
    setLoading(true);
    try {
      const { data } = await api.get(`/admin/riders?status=${status}`);
      setRiders(data.riders || []);
    } catch { toast.error('Failed to load riders'); }
    finally { setLoading(false); }
  };

  useEffect(() => { load(); }, [status]);

  const reviewRider = async (riderId, action) => {
    setActing(true);
    try {
      await api.patch(`/admin/riders/${riderId}/review`, { action, note: actionNote });
      toast.success(`Rider ${action} successfully`);
      setSelected(null);
      setActionNote('');
      load();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Action failed');
    } finally { setActing(false); }
  };

  const statusBadge = (s) => {
    const map = { pending: ['#F57C00', '#FFF3E0'], approved: [G, '#E8F5E9'], rejected: ['#D32F2F', '#FFEBEE'], suspended: ['#7B1FA2', '#F3E5F5'] };
    const [c, bg] = map[s] || ['#999', '#F5F5F5'];
    return <span style={{ background: bg, color: c, padding: '3px 10px', borderRadius: 20, fontSize: 12, fontWeight: 600 }}>{s.toUpperCase()}</span>;
  };

  return (
    <div>
      <h1 style={{ margin: '0 0 24px', fontSize: 22, fontWeight: 700 }}>Riders Management</h1>

      {/* Tabs */}
      <div style={{ display: 'flex', gap: 8, marginBottom: 20 }}>
        {STATUS_TABS.map(s => (
          <button key={s} onClick={() => setStatus(s)} style={{
            padding: '8px 18px', borderRadius: 20, border: 'none', cursor: 'pointer', fontSize: 13, fontWeight: 500,
            background: status === s ? G : 'white',
            color: status === s ? 'white' : '#333',
            boxShadow: '0 1px 4px rgba(0,0,0,0.08)',
          }}>
            {s.charAt(0).toUpperCase() + s.slice(1)}
          </button>
        ))}
      </div>

      {/* Table */}
      <div style={{ background: 'white', borderRadius: 16, boxShadow: '0 2px 8px rgba(0,0,0,0.06)', overflow: 'hidden' }}>
        <table style={{ width: '100%', borderCollapse: 'collapse' }}>
          <thead>
            <tr style={{ background: '#F5F5F5' }}>
              {['Name', 'Phone', 'Email', 'Vehicle', 'Rating', 'Registered', 'Status', 'Actions'].map(h => (
                <th key={h} style={{ padding: '12px 16px', textAlign: 'left', fontSize: 12, fontWeight: 600, color: '#757575', textTransform: 'uppercase' }}>{h}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr><td colSpan={8} style={{ padding: 40, textAlign: 'center', color: '#999' }}>Loading…</td></tr>
            ) : riders.length === 0 ? (
              <tr><td colSpan={8} style={{ padding: 40, textAlign: 'center', color: '#999' }}>No {status} riders</td></tr>
            ) : riders.map(r => (
              <tr key={r.id} style={{ borderTop: '1px solid #F5F5F5' }}>
                <td style={{ padding: '12px 16px' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                    <div style={{ width: 36, height: 36, background: G, borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'white', fontWeight: 700, fontSize: 14, flexShrink: 0 }}>
                      {r.full_name?.[0]?.toUpperCase()}
                    </div>
                    <span style={{ fontWeight: 500 }}>{r.full_name}</span>
                  </div>
                </td>
                <td style={{ padding: '12px 16px', fontSize: 13 }}>{r.phone}</td>
                <td style={{ padding: '12px 16px', fontSize: 13, color: '#555' }}>{r.email}</td>
                <td style={{ padding: '12px 16px', fontSize: 13 }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                    <Truck size={14} color="#999" />
                    {r.vehicle_type || '—'}
                  </div>
                </td>
                <td style={{ padding: '12px 16px', fontSize: 13 }}>
                  {Number(r.rating_count) > 0 ? `⭐ ${Number(r.rating_avg).toFixed(1)} (${r.rating_count})` : '—'}
                </td>
                <td style={{ padding: '12px 16px', fontSize: 12, color: '#757575' }}>
                  {new Date(r.created_at).toLocaleDateString()}
                </td>
                <td style={{ padding: '12px 16px' }}>{statusBadge(r.status)}</td>
                <td style={{ padding: '12px 16px' }}>
                  <div style={{ display: 'flex', gap: 6 }}>
                    <button onClick={() => setSelected(r)} style={{ background: '#E3F2FD', border: 'none', borderRadius: 8, padding: '6px 10px', cursor: 'pointer', color: '#1565C0' }}>
                      <Eye size={14} />
                    </button>
                    {r.status === 'pending' && (
                      <>
                        <button onClick={() => reviewRider(r.id, 'approved')} style={{ background: '#E8F5E9', border: 'none', borderRadius: 8, padding: '6px 10px', cursor: 'pointer', color: G }}>
                          <CheckCircle size={14} />
                        </button>
                        <button onClick={() => reviewRider(r.id, 'rejected')} style={{ background: '#FFEBEE', border: 'none', borderRadius: 8, padding: '6px 10px', cursor: 'pointer', color: '#D32F2F' }}>
                          <XCircle size={14} />
                        </button>
                      </>
                    )}
                    {r.status === 'approved' && (
                      <button onClick={() => reviewRider(r.id, 'suspended')} style={{ background: '#F3E5F5', border: 'none', borderRadius: 8, padding: '6px 10px', cursor: 'pointer', color: '#7B1FA2' }}>
                        <AlertTriangle size={14} />
                      </button>
                    )}
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Rider detail modal */}
      {selected && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.5)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 100 }} onClick={() => setSelected(null)}>
          <div style={{ background: 'white', borderRadius: 20, padding: 32, width: '90%', maxWidth: 520 }} onClick={e => e.stopPropagation()}>
            <h2 style={{ margin: '0 0 20px' }}>{selected.full_name}</h2>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginBottom: 20 }}>
              {[
                ['Email', selected.email],
                ['Phone', selected.phone],
                ['Vehicle', selected.vehicle_type || '—'],
                ['Plate', selected.vehicle_plate || '—'],
                ['Ghana Card', selected.ghana_card_number || '—'],
                ['Rating', Number(selected.rating_count) > 0 ? `⭐ ${Number(selected.rating_avg).toFixed(1)} (${selected.rating_count})` : 'No ratings'],
                ['Completed jobs', selected.completed_count ?? 0],
                ['Reliability', Number(selected.accepted_count) > 0 ? `${Math.round((selected.completed_count / selected.accepted_count) * 100)}%` : '—'],
                ['Status', selected.status],
                ['Joined', new Date(selected.created_at).toLocaleDateString()],
              ].map(([l, v]) => (
                <div key={l} style={{ padding: 12, background: '#F5F5F5', borderRadius: 10 }}>
                  <div style={{ fontSize: 11, color: '#999', marginBottom: 2 }}>{l}</div>
                  <div style={{ fontSize: 14, fontWeight: 500 }}>{v}</div>
                </div>
              ))}
            </div>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 14, marginBottom: 4 }}>
              {[
                ['ID Document', selected.id_document_url],
                ['Ghana Card', selected.ghana_card_url],
                ['Vehicle Photo', selected.vehicle_photo_url],
                ['License', selected.license_url],
              ].filter(([, url]) => !!url).map(([label, url]) => (
                <a key={label} href={url} target="_blank" rel="noreferrer" style={{ color: G, fontSize: 13, fontWeight: 500 }}>View {label} ↗</a>
              ))}
            </div>
            <div style={{ marginTop: 16 }}>
              <label style={{ fontSize: 13, fontWeight: 500 }}>Note (optional)</label>
              <textarea value={actionNote} onChange={e => setActionNote(e.target.value)} rows={2} style={{ width: '100%', marginTop: 6, padding: '10px 12px', border: '1px solid #E0E0E0', borderRadius: 10, fontSize: 13, resize: 'none', boxSizing: 'border-box' }} placeholder="Add a note..." />
            </div>
            <div style={{ display: 'flex', gap: 10, marginTop: 16 }}>
              {selected.status === 'pending' && (
                <>
                  <button onClick={() => reviewRider(selected.id, 'approved')} disabled={acting} style={{ flex: 1, padding: 12, background: G, color: 'white', border: 'none', borderRadius: 10, cursor: 'pointer', fontWeight: 600 }}>✅ Approve</button>
                  <button onClick={() => reviewRider(selected.id, 'rejected')} disabled={acting} style={{ flex: 1, padding: 12, background: '#D32F2F', color: 'white', border: 'none', borderRadius: 10, cursor: 'pointer', fontWeight: 600 }}>❌ Reject</button>
                </>
              )}
              {selected.status === 'approved' && (
                <button onClick={() => reviewRider(selected.id, 'suspended')} disabled={acting} style={{ flex: 1, padding: 12, background: '#7B1FA2', color: 'white', border: 'none', borderRadius: 10, cursor: 'pointer', fontWeight: 600 }}>⚠️ Suspend</button>
              )}
              <button onClick={() => setSelected(null)} style={{ padding: '12px 20px', background: '#F5F5F5', border: 'none', borderRadius: 10, cursor: 'pointer' }}>Close</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

import React, { useEffect, useState } from 'react';
import api from '../api/axios';
import toast from 'react-hot-toast';
import { format } from 'date-fns';

const G = '#2E7D32';

export default function Disputes() {
  const [disputes, setDisputes] = useState([]);
  const [loading, setLoading] = useState(true);
  const [status, setStatus] = useState('open');
  const [selected, setSelected] = useState(null);
  const [resolution, setResolution] = useState('');
  const [resolving, setResolving] = useState(false);

  const load = async () => {
    setLoading(true);
    try {
      const { data } = await api.get(`/admin/disputes?status=${status}`);
      setDisputes(data.disputes || []);
    } catch {}
    finally { setLoading(false); }
  };

  useEffect(() => { load(); }, [status]);

  const resolve = async (disputeId) => {
    if (!resolution.trim()) { toast.error('Please provide a resolution'); return; }
    setResolving(true);
    try {
      await api.patch(`/admin/disputes/${disputeId}`, { resolution, status: 'resolved' });
      toast.success('Dispute resolved');
      setSelected(null);
      setResolution('');
      load();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Failed');
    } finally { setResolving(false); }
  };

  return (
    <div>
      <h1 style={{ margin: '0 0 24px', fontSize: 22, fontWeight: 700 }}>Disputes</h1>

      <div style={{ display: 'flex', gap: 8, marginBottom: 20 }}>
        {['open', 'investigating', 'resolved', 'closed'].map(s => (
          <button key={s} onClick={() => setStatus(s)} style={{
            padding: '7px 16px', borderRadius: 20, border: 'none', cursor: 'pointer', fontSize: 13,
            background: status === s ? G : 'white', color: status === s ? 'white' : '#333',
            boxShadow: '0 1px 4px rgba(0,0,0,0.08)',
          }}>
            {s.charAt(0).toUpperCase() + s.slice(1)}
          </button>
        ))}
      </div>

      <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
        {loading ? <p style={{ color: '#999', padding: 20 }}>Loading…</p>
        : disputes.length === 0 ? <p style={{ color: '#999', padding: 20 }}>No {status} disputes</p>
        : disputes.map(d => (
          <div key={d.id} style={{ background: 'white', borderRadius: 14, padding: 20, boxShadow: '0 2px 8px rgba(0,0,0,0.06)' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
              <div style={{ flex: 1 }}>
                <div style={{ display: 'flex', gap: 10, alignItems: 'center', marginBottom: 8 }}>
                  <span style={{ background: '#FFEBEE', color: '#D32F2F', padding: '3px 10px', borderRadius: 20, fontSize: 11, fontWeight: 600 }}>{d.status.toUpperCase()}</span>
                  <span style={{ fontSize: 12, color: '#999' }}>{format(new Date(d.created_at), 'dd MMM yyyy')}</span>
                </div>
                <p style={{ margin: '0 0 6px', fontWeight: 500 }}>Raised by: {d.raised_by_name}</p>
                <p style={{ margin: '0 0 6px', fontSize: 13, color: '#555' }}>Order: {d.pickup_address}</p>
                <p style={{ margin: 0, fontSize: 13, color: '#D32F2F' }}>"{d.reason}"</p>
              </div>
              {d.status === 'open' && (
                <button onClick={() => setSelected(d)} style={{ padding: '8px 16px', background: G, color: 'white', border: 'none', borderRadius: 10, cursor: 'pointer', fontSize: 13, fontWeight: 500, marginLeft: 16 }}>
                  Resolve
                </button>
              )}
            </div>
            {d.resolution && <div style={{ marginTop: 12, padding: '10px 14px', background: '#E8F5E9', borderRadius: 10, fontSize: 13, color: '#2E7D32' }}>✅ Resolution: {d.resolution}</div>}
          </div>
        ))}
      </div>

      {selected && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.5)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 100 }} onClick={() => setSelected(null)}>
          <div style={{ background: 'white', borderRadius: 20, padding: 32, width: '90%', maxWidth: 460 }} onClick={e => e.stopPropagation()}>
            <h2 style={{ margin: '0 0 12px' }}>Resolve Dispute</h2>
            <p style={{ margin: '0 0 16px', fontSize: 13, color: '#555' }}>{selected.reason}</p>
            <label style={{ fontSize: 13, fontWeight: 500 }}>Resolution</label>
            <textarea value={resolution} onChange={e => setResolution(e.target.value)} rows={4} style={{ width: '100%', marginTop: 6, padding: '10px 12px', border: '1px solid #E0E0E0', borderRadius: 10, fontSize: 13, resize: 'none', boxSizing: 'border-box' }} placeholder="Describe how this was resolved..." />
            <div style={{ display: 'flex', gap: 10, marginTop: 16 }}>
              <button onClick={() => resolve(selected.id)} disabled={resolving} style={{ flex: 1, padding: 12, background: G, color: 'white', border: 'none', borderRadius: 10, cursor: 'pointer', fontWeight: 600 }}>
                {resolving ? 'Saving…' : 'Mark Resolved'}
              </button>
              <button onClick={() => setSelected(null)} style={{ padding: '12px 20px', background: '#F5F5F5', border: 'none', borderRadius: 10, cursor: 'pointer' }}>Cancel</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

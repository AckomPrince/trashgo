import React, { useEffect, useState } from 'react';
import api from '../api/axios';
import { format } from 'date-fns';

const STATUS_COLORS = {
  requested:          ['#F57C00','#FFF3E0'],
  accepted:           ['#1565C0','#E3F2FD'],
  rider_en_route:     ['#0288D1','#E1F5FE'],
  rider_arrived:      ['#7B1FA2','#F3E5F5'],
  size_confirmed:     ['#E65100','#FBE9E7'],
  price_approved:     ['#00796B','#E0F2F1'],
  payment_authorized: ['#2E7D32','#E8F5E9'],
  in_progress:        ['#2E7D32','#E8F5E9'],
  completed:          ['#1B5E20','#C8E6C9'],
  cancelled:          ['#D32F2F','#FFEBEE'],
};

function Badge({ status }) {
  const [c, bg] = STATUS_COLORS[status] || ['#999', '#F5F5F5'];
  const label = status?.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase());
  return <span style={{ background: bg, color: c, padding: '3px 10px', borderRadius: 20, fontSize: 11, fontWeight: 600, whiteSpace: 'nowrap' }}>{label}</span>;
}

const ALL_STATUSES = ['', 'requested', 'accepted', 'in_progress', 'completed', 'cancelled'];
const PAGE_SIZE = 30;

export default function Orders() {
  const [orders, setOrders]   = useState([]);
  const [total, setTotal]     = useState(0);   // FIX: track total for pagination display
  const [loading, setLoading] = useState(true);
  const [status, setStatus]   = useState('');
  const [page, setPage]       = useState(1);

  const load = async () => {
    setLoading(true);
    try {
      const params = new URLSearchParams({ page, limit: PAGE_SIZE });
      if (status) params.set('status', status);
      const { data } = await api.get(`/admin/orders?${params}`);
      setOrders(data.orders || []);
      setTotal(data.total || 0);  // FIX: store total from API
    } catch {}
    finally { setLoading(false); }
  };

  useEffect(() => { load(); }, [status, page]);

  // FIX: compute total pages so the UI can show "Page X of Y"
  const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE));

  return (
    <div>
      <h1 style={{ margin: '0 0 24px', fontSize: 22, fontWeight: 700 }}>Orders</h1>

      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginBottom: 20 }}>
        {ALL_STATUSES.map(s => (
          <button key={s} onClick={() => { setStatus(s); setPage(1); }} style={{
            padding: '7px 16px', borderRadius: 20, border: 'none', cursor: 'pointer', fontSize: 13,
            background: status === s ? '#2E7D32' : 'white', color: status === s ? 'white' : '#333',
            boxShadow: '0 1px 4px rgba(0,0,0,0.08)',
          }}>
            {s === '' ? 'All' : s.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase())}
          </button>
        ))}
      </div>

      <div style={{ background: 'white', borderRadius: 16, boxShadow: '0 2px 8px rgba(0,0,0,0.06)', overflow: 'hidden' }}>
        <div style={{ overflowX: 'auto' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', minWidth: 800 }}>
            <thead>
              <tr style={{ background: '#F5F5F5' }}>
                {['ID', 'Customer', 'Rider', 'Address', 'Type', 'Price', 'Status', 'Date'].map(h => (
                  <th key={h} style={{ padding: '12px 14px', textAlign: 'left', fontSize: 11, fontWeight: 600, color: '#757575', textTransform: 'uppercase' }}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr><td colSpan={8} style={{ padding: 40, textAlign: 'center', color: '#999' }}>Loading…</td></tr>
              ) : orders.length === 0 ? (
                <tr><td colSpan={8} style={{ padding: 40, textAlign: 'center', color: '#999' }}>No orders found</td></tr>
              ) : orders.map(o => (
                <tr key={o.id} style={{ borderTop: '1px solid #F5F5F5' }}>
                  <td style={{ padding: '11px 14px', fontSize: 11, color: '#999', fontFamily: 'monospace' }}>{o.id.slice(0, 8)}…</td>
                  <td style={{ padding: '11px 14px', fontSize: 13, fontWeight: 500 }}>{o.customer_name}</td>
                  <td style={{ padding: '11px 14px', fontSize: 13, color: '#555' }}>{o.rider_name || <span style={{ color: '#CCC' }}>—</span>}</td>
                  <td style={{ padding: '11px 14px', fontSize: 12, color: '#555', maxWidth: 180 }}>
                    <div style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{o.pickup_address}</div>
                  </td>
                  <td style={{ padding: '11px 14px' }}>
                    <span style={{ background: '#E8F5E9', color: '#2E7D32', padding: '2px 8px', borderRadius: 8, fontSize: 11, fontWeight: 500 }}>
                      {o.waste_type}
                    </span>
                  </td>
                  <td style={{ padding: '11px 14px', fontSize: 13, fontWeight: 600, color: o.final_price ? '#2E7D32' : '#999' }}>
                    {o.final_price ? `GHS ${parseFloat(o.final_price).toFixed(2)}` : '—'}
                  </td>
                  <td style={{ padding: '11px 14px' }}><Badge status={o.status} /></td>
                  <td style={{ padding: '11px 14px', fontSize: 12, color: '#757575' }}>
                    {format(new Date(o.created_at), 'dd MMM, HH:mm')}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {/* FIX: pagination now shows "Page X of Y (Z total)" */}
        <div style={{ padding: '12px 16px', borderTop: '1px solid #F5F5F5', display: 'flex', gap: 8, alignItems: 'center', justifyContent: 'flex-end' }}>
          <span style={{ fontSize: 12, color: '#999', marginRight: 8 }}>{total} total</span>
          <button
            onClick={() => setPage(p => Math.max(1, p - 1))}
            disabled={page === 1}
            style={{ padding: '6px 14px', border: '1px solid #E0E0E0', borderRadius: 8, cursor: page === 1 ? 'default' : 'pointer', background: 'white', opacity: page === 1 ? 0.4 : 1 }}
          >← Prev</button>
          <span style={{ padding: '6px 14px', fontSize: 13, color: '#555', whiteSpace: 'nowrap' }}>
            Page {page} of {totalPages}
          </span>
          <button
            onClick={() => setPage(p => p + 1)}
            disabled={page >= totalPages}
            style={{ padding: '6px 14px', border: '1px solid #E0E0E0', borderRadius: 8, cursor: page >= totalPages ? 'default' : 'pointer', background: 'white', opacity: page >= totalPages ? 0.4 : 1 }}
          >Next →</button>
        </div>
      </div>
    </div>
  );
}

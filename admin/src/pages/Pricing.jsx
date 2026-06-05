import React, { useEffect, useState } from 'react';
import api from '../api/axios';
import toast from 'react-hot-toast';

const G = '#2E7D32';
const SIZES = ['small', 'medium', 'large'];
const TYPES = ['general', 'recyclable', 'organic', 'hazardous', 'bulky'];

export default function Pricing() {
  const [pricing, setPricing] = useState([]);
  const [loading, setLoading] = useState(true);
  const [editing, setEditing] = useState(null); // { waste_size, waste_type, price }
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    api.get('/admin/pricing')
      .then(r => setPricing(r.data.pricing || []))
      .catch(() => {})
      .finally(() => setLoading(false));
  }, []);

  const getPrice = (size, type) => {
    const row = pricing.find(p => p.waste_size === size && p.waste_type === type);
    return row ? parseFloat(row.price).toFixed(2) : '—';
  };

  const save = async () => {
    if (!editing) return;
    setSaving(true);
    try {
      await api.patch('/admin/pricing', { waste_size: editing.waste_size, waste_type: editing.waste_type, price: parseFloat(editing.price) });
      toast.success('Price updated');
      const { data } = await api.get('/admin/pricing');
      setPricing(data.pricing || []);
      setEditing(null);
    } catch (err) {
      toast.error(err.response?.data?.error || 'Failed');
    } finally { setSaving(false); }
  };

  return (
    <div>
      <h1 style={{ margin: '0 0 8px', fontSize: 22, fontWeight: 700 }}>Pricing Configuration</h1>
      <p style={{ margin: '0 0 24px', color: '#757575', fontSize: 14 }}>Click any cell to edit the price for that waste type and size.</p>

      {loading ? <p>Loading…</p> : (
        <div style={{ background: 'white', borderRadius: 16, boxShadow: '0 2px 8px rgba(0,0,0,0.06)', overflow: 'hidden' }}>
          <table style={{ width: '100%', borderCollapse: 'collapse' }}>
            <thead>
              <tr style={{ background: '#F5F5F5' }}>
                <th style={{ padding: '12px 16px', textAlign: 'left', fontSize: 12, color: '#757575', fontWeight: 600 }}>WASTE TYPE</th>
                {SIZES.map(s => <th key={s} style={{ padding: '12px 16px', textAlign: 'center', fontSize: 12, color: '#757575', fontWeight: 600, textTransform: 'uppercase' }}>{s}</th>)}
              </tr>
            </thead>
            <tbody>
              {TYPES.map(type => (
                <tr key={type} style={{ borderTop: '1px solid #F5F5F5' }}>
                  <td style={{ padding: '14px 16px', fontWeight: 500, fontSize: 14, textTransform: 'capitalize' }}>{type}</td>
                  {SIZES.map(size => {
                    const price = getPrice(size, type);
                    return (
                      <td key={size} style={{ padding: '14px 16px', textAlign: 'center' }}>
                        <button onClick={() => setEditing({ waste_size: size, waste_type: type, price })} style={{
                          background: 'none', border: `1px solid ${G}30`, padding: '6px 16px', borderRadius: 10, cursor: 'pointer', fontSize: 14, fontWeight: 600, color: G,
                        }}>
                          GHS {price}
                        </button>
                      </td>
                    );
                  })}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {editing && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.5)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 100 }} onClick={() => setEditing(null)}>
          <div style={{ background: 'white', borderRadius: 20, padding: 32, width: 320 }} onClick={e => e.stopPropagation()}>
            <h3 style={{ margin: '0 0 4px' }}>Edit Price</h3>
            <p style={{ margin: '0 0 20px', color: '#757575', fontSize: 13 }}>{editing.waste_type} / {editing.waste_size}</p>
            <label style={{ fontSize: 13, fontWeight: 500 }}>Price (GHS)</label>
            <input type="number" step="0.01" min="0" value={editing.price}
              onChange={e => setEditing(ed => ({ ...ed, price: e.target.value }))}
              style={{ width: '100%', marginTop: 6, padding: '12px 14px', border: '1px solid #E0E0E0', borderRadius: 10, fontSize: 16, boxSizing: 'border-box' }} />
            <div style={{ display: 'flex', gap: 10, marginTop: 20 }}>
              <button onClick={save} disabled={saving} style={{ flex: 1, padding: 12, background: G, color: 'white', border: 'none', borderRadius: 10, cursor: 'pointer', fontWeight: 600 }}>
                {saving ? 'Saving…' : 'Save'}
              </button>
              <button onClick={() => setEditing(null)} style={{ padding: '12px 20px', background: '#F5F5F5', border: 'none', borderRadius: 10, cursor: 'pointer' }}>Cancel</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

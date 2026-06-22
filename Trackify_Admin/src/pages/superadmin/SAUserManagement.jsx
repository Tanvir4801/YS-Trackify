import React, { useState, useEffect } from 'react';
import { collection, query, getDocs, doc, updateDoc, setDoc } from 'firebase/firestore';
import { db } from '../../lib/firebase';
import { Users as UsersIcon, Shield, Search, Plus, Edit2 } from 'lucide-react';
import toast from 'react-hot-toast';
import { motion } from 'framer-motion';

export default function SAUserManagement() {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  
  // Dialog state
  const [isDialogOpen, setIsDialogOpen] = useState(false);
  const [editingUser, setEditingUser] = useState(null);
  
  const fetchUsers = async () => {
    try {
      setLoading(true);
      const snap = await getDocs(query(collection(db, 'users')));
      const data = snap.docs.map(d => ({ id: d.id, ...d.data() }));
      setUsers(data);
    } catch (err) {
      console.error(err);
      toast.error('Failed to load users');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchUsers();
  }, []);

  const handleSave = async (userData) => {
    try {
      if (editingUser) {
        await updateDoc(doc(db, 'users', editingUser.id), userData);
        toast.success('User updated successfully');
      } else {
        // Just storing in Firestore. Note: Real auth creation needs a Cloud Function
        const newDoc = doc(collection(db, 'users'));
        await setDoc(newDoc, { ...userData, createdAt: new Date() });
        toast.success('User record created (Requires Firebase Auth creation)');
      }
      setIsDialogOpen(false);
      setEditingUser(null);
      fetchUsers();
    } catch (err) {
      console.error(err);
      toast.error('Failed to save user');
    }
  };

  const filteredUsers = users.filter(u => 
    (u.name || '').toLowerCase().includes(searchTerm.toLowerCase()) || 
    (u.email || '').toLowerCase().includes(searchTerm.toLowerCase()) ||
    (u.role || '').toLowerCase().includes(searchTerm.toLowerCase())
  );

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold tracking-tight text-text-primary flex items-center gap-2">
            <Shield className="h-6 w-6 text-violet-500" />
            Global User Management
          </h1>
          <p className="text-sm text-text-muted mt-1">
            Manage all users, including TrackOps and Super Admins.
          </p>
        </div>
        <button
          onClick={() => { setEditingUser(null); setIsDialogOpen(true); }}
          className="flex items-center justify-center gap-2 px-4 py-2 bg-violet-600 hover:bg-violet-700 text-white text-sm font-medium rounded-lg transition-colors"
        >
          <Plus className="h-4 w-4" /> Add User
        </button>
      </div>

      <div className="bg-bg-card border border-border rounded-xl overflow-hidden shadow-sm">
        <div className="p-4 border-b border-border flex items-center justify-between">
          <div className="relative w-64">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-text-muted" />
            <input
              type="text"
              placeholder="Search users..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="w-full pl-9 pr-4 py-2 bg-bg-input border border-border rounded-lg text-sm text-text-primary focus:outline-none focus:border-violet-500 transition-colors"
            />
          </div>
          <div className="text-sm text-text-muted font-medium">
            Total Users: {filteredUsers.length}
          </div>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm whitespace-nowrap">
            <thead className="bg-bg-secondary text-text-muted font-medium border-b border-border">
              <tr>
                <th className="px-6 py-3">Name</th>
                <th className="px-6 py-3">Email</th>
                <th className="px-6 py-3">Role</th>
                <th className="px-6 py-3">Status</th>
                <th className="px-6 py-3 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-border">
              {loading ? (
                <tr>
                  <td colSpan="5" className="px-6 py-8 text-center text-text-muted">Loading users...</td>
                </tr>
              ) : filteredUsers.map((user) => (
                <tr key={user.id} className="hover:bg-bg-elevated transition-colors">
                  <td className="px-6 py-4 font-medium text-text-primary">{user.name || '—'}</td>
                  <td className="px-6 py-4 text-text-secondary">{user.email || '—'}</td>
                  <td className="px-6 py-4">
                    <span className={`px-2.5 py-1 rounded-full text-[11px] font-semibold tracking-wide uppercase ${
                      user.role === 'super_admin' ? 'bg-violet-500/10 text-violet-500' :
                      user.role === 'trackops' ? 'bg-emerald-500/10 text-emerald-500' :
                      user.role === 'contractor' ? 'bg-blue-500/10 text-blue-500' :
                      'bg-gray-500/10 text-gray-500'
                    }`}>
                      {user.role || 'user'}
                    </span>
                  </td>
                  <td className="px-6 py-4">
                    <span className={`px-2 py-1 rounded text-xs ${user.isActive === false ? 'bg-red-500/10 text-red-500' : 'bg-green-500/10 text-green-500'}`}>
                      {user.isActive === false ? 'Inactive' : 'Active'}
                    </span>
                  </td>
                  <td className="px-6 py-4 text-right">
                    <button 
                      onClick={() => { setEditingUser(user); setIsDialogOpen(true); }}
                      className="p-1.5 text-text-muted hover:text-violet-500 hover:bg-violet-500/10 rounded transition-colors"
                    >
                      <Edit2 className="h-4 w-4" />
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {isDialogOpen && (
        <UserDialog 
          user={editingUser} 
          onClose={() => { setIsDialogOpen(false); setEditingUser(null); }} 
          onSave={handleSave} 
        />
      )}
    </div>
  );
}

function UserDialog({ user, onClose, onSave }) {
  const [formData, setFormData] = useState({
    name: user?.name || '',
    email: user?.email || '',
    role: user?.role || 'contractor',
    isActive: user?.isActive !== false
  });

  const handleSubmit = (e) => {
    e.preventDefault();
    onSave(formData);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4">
      <motion.div 
        initial={{ opacity: 0, scale: 0.95 }}
        animate={{ opacity: 1, scale: 1 }}
        className="bg-bg-card border border-border rounded-xl shadow-2xl w-full max-w-md overflow-hidden"
      >
        <div className="p-5 border-b border-border flex justify-between items-center">
          <h2 className="text-lg font-bold text-text-primary">
            {user ? 'Edit User Role' : 'Add New User'}
          </h2>
        </div>
        
        <form onSubmit={handleSubmit} className="p-5 space-y-4">
          <div>
            <label className="block text-sm font-medium text-text-secondary mb-1">Name</label>
            <input 
              type="text" 
              value={formData.name}
              onChange={e => setFormData({...formData, name: e.target.value})}
              className="w-full px-3 py-2 bg-bg-input border border-border rounded-lg text-text-primary focus:outline-none focus:border-violet-500"
              required
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-text-secondary mb-1">Email</label>
            <input 
              type="email" 
              value={formData.email}
              onChange={e => setFormData({...formData, email: e.target.value})}
              className="w-full px-3 py-2 bg-bg-input border border-border rounded-lg text-text-primary focus:outline-none focus:border-violet-500"
              required
              disabled={!!user} // Email can't easily be changed in Auth via just firestore
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-text-secondary mb-1">Role</label>
            <select 
              value={formData.role}
              onChange={e => setFormData({...formData, role: e.target.value})}
              className="w-full px-3 py-2 bg-bg-input border border-border rounded-lg text-text-primary focus:outline-none focus:border-violet-500"
            >
              <option value="super_admin">Super Admin (Owner)</option>
              <option value="trackops">TrackOps (Mission Control)</option>
              <option value="contractor">Contractor</option>
              <option value="supervisor">Supervisor</option>
            </select>
          </div>
          <div className="flex items-center gap-2 pt-2">
            <input 
              type="checkbox" 
              id="isActive"
              checked={formData.isActive}
              onChange={e => setFormData({...formData, isActive: e.target.checked})}
              className="rounded border-border bg-bg-input text-violet-500 focus:ring-violet-500"
            />
            <label htmlFor="isActive" className="text-sm font-medium text-text-primary">Active Account</label>
          </div>

          <div className="flex justify-end gap-3 pt-4 border-t border-border mt-6">
            <button type="button" onClick={onClose} className="px-4 py-2 text-sm font-medium text-text-secondary hover:text-text-primary transition-colors">Cancel</button>
            <button type="submit" className="px-4 py-2 bg-violet-600 text-white text-sm font-medium rounded-lg hover:bg-violet-700 transition-colors">Save User</button>
          </div>
        </form>
      </motion.div>
    </div>
  );
}

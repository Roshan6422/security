import { useEffect, useState } from 'react';
import axios from 'axios';
import {
    Search, User as UserIcon, Shield, Trash2, Mail, Users, AlertTriangle, X,
    MoreVertical, Ban, Zap, UserCheck, ShieldCheck
} from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { getBaseUrl } from '../utils/api';
import { User } from '../types';

export default function UsersPage() {
    const [users, setUsers] = useState<User[]>([]);
    const [loading, setLoading] = useState(true);
    const [search, setSearch] = useState("");
    const [deleteTarget, setDeleteTarget] = useState<User | null>(null);
    const [deleting, setDeleting] = useState(false);
    const [activeMenu, setActiveMenu] = useState<string | null>(null);

    const fetchUsers = async () => {
        try {
            const token = localStorage.getItem('adminToken');
            const res = await axios.get(`${getBaseUrl()}/api/admin/users`, {
                headers: { Authorization: `Bearer ${token}` }
            });
            setUsers(res.data);
        } catch (err) {
            console.error(err);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        fetchUsers();
    }, []);

    const handleAction = async (userId: string, type: 'status' | 'subscription' | 'role', value: boolean | string) => {
        try {
            const token = localStorage.getItem('adminToken');
            const payload = type === 'status' ? { isSuspended: value } :
                type === 'subscription' ? { status: value } :
                    { role: value };

            const res = await axios.patch(`${getBaseUrl()}/api/admin/users/${userId}/${type}`, payload, {
                headers: { Authorization: `Bearer ${token}` }
            });

            setUsers(prev => prev.map(u => u._id === userId ? { ...u, ...res.data.user } : u));
            setActiveMenu(null);
        } catch (err: any) {
            alert(err.response?.data?.message || 'Action failed');
        }
    };

    const handleDelete = async (user: User) => {
        setDeleting(true);
        try {
            const token = localStorage.getItem('adminToken');
            await axios.delete(`${getBaseUrl()}/api/admin/users/${user._id}`, {
                headers: { Authorization: `Bearer ${token}` }
            });
            setUsers(prev => prev.filter(u => u._id !== user._id));
            setDeleteTarget(null);
        } catch (err: any) {
            alert(err.response?.data?.message || 'Failed to delete user');
        } finally {
            setDeleting(false);
        }
    };

    const [showAddModal, setShowAddModal] = useState(false);
    const [newData, setNewData] = useState({ name: '', email: '', password: '' });
    const [adding, setAdding] = useState(false);

    const handleAddUser = async (e: React.FormEvent) => {
        e.preventDefault();
        setAdding(true);
        try {
            const token = localStorage.getItem('adminToken');
            const res = await axios.post(`${getBaseUrl()}/api/auth/register`, newData, {
                headers: { Authorization: `Bearer ${token}` }
            });
            setUsers(prev => [res.data, ...prev]);
            setShowAddModal(false);
            setNewData({ name: '', email: '', password: '' });
        } catch (err: any) {
            alert(err.response?.data?.message || 'Failed to add user');
        } finally {
            setAdding(false);
        }
    };

    const filteredUsers = users.filter((user) =>
        user.name?.toLowerCase().includes(search.toLowerCase()) ||
        user.email?.toLowerCase().includes(search.toLowerCase())
    );

    const adminCount = users.filter(u => u.role === 'admin').length;
    const userCount = users.length - adminCount;

    return (
        <div className="space-y-6 pt-6" onClick={() => setActiveMenu(null)}>
            {/* Page Header */}
            <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
                <div>
                    <h2 className="text-3xl font-bold text-white tracking-tight">User Management</h2>
                    <p className="text-slate-400 mt-1">Manage and monitor all registered users</p>
                </div>
                <button
                    onClick={(e) => { e.stopPropagation(); setShowAddModal(true); }}
                    className="flex items-center gap-2 px-5 py-2.5 rounded-xl bg-blue-600 hover:bg-blue-500 text-white font-bold transition-all shadow-lg shadow-blue-500/25 active:scale-95"
                >
                    <UserIcon size={18} />
                    Add New User
                </button>
            </div>

            {/* Stats Row */}
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div className="glass-panel p-4 rounded-2xl flex items-center gap-4">
                    <div className="w-12 h-12 rounded-xl bg-blue-500/10 flex items-center justify-center text-blue-400 ring-1 ring-blue-500/20">
                        <Users size={24} />
                    </div>
                    <div>
                        <p className="text-sm text-slate-400">Total Users</p>
                        <p className="text-2xl font-bold text-white">{users.length}</p>
                    </div>
                </div>
                <div className="glass-panel p-4 rounded-2xl flex items-center gap-4">
                    <div className="w-12 h-12 rounded-xl bg-purple-500/10 flex items-center justify-center text-purple-400 ring-1 ring-purple-500/20">
                        <Shield size={24} />
                    </div>
                    <div>
                        <p className="text-sm text-slate-400">Admins</p>
                        <p className="text-2xl font-bold text-white">{adminCount}</p>
                    </div>
                </div>
                <div className="glass-panel p-4 rounded-2xl flex items-center gap-4">
                    <div className="w-12 h-12 rounded-xl bg-emerald-500/10 flex items-center justify-center text-emerald-400 ring-1 ring-emerald-500/20">
                        <UserIcon size={24} />
                    </div>
                    <div>
                        <p className="text-sm text-slate-400">Regular Users</p>
                        <p className="text-2xl font-bold text-white">{userCount}</p>
                    </div>
                </div>
            </div>

            {/* Search & Filter */}
            <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
                <div className="relative">
                    <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" size={20} />
                    <input
                        type="text"
                        placeholder="Search users..."
                        value={search}
                        onChange={(e) => setSearch(e.target.value)}
                        onClick={(e) => e.stopPropagation()}
                        className="pl-10 pr-4 py-2.5 bg-slate-900/50 border border-white/10 rounded-xl text-white focus:outline-none focus:border-blue-500/50 transition-colors w-full md:w-72"
                    />
                </div>
            </div>

            {/* Users Table */}
            <div className="glass-panel rounded-2xl overflow-hidden">
                <div className="overflow-x-auto">
                    <table className="w-full text-left">
                        <thead>
                            <tr className="border-b border-white/5 bg-white/5">
                                <th className="p-4 font-semibold text-slate-300 text-sm">User</th>
                                <th className="p-4 font-semibold text-slate-300 text-sm">Role</th>
                                <th className="p-4 font-semibold text-slate-300 text-sm">Plan</th>
                                <th className="p-4 font-semibold text-slate-300 text-sm">Status</th>
                                <th className="p-4 font-semibold text-slate-300 text-sm text-right">Actions</th>
                            </tr>
                        </thead>
                        <tbody className="divide-y divide-white/5">
                            <AnimatePresence>
                                {loading ? (
                                    <tr>
                                        <td colSpan={5} className="p-8 text-center text-slate-500">
                                            <div className="flex flex-col items-center justify-center gap-2">
                                                <div className="w-8 h-8 border-2 border-white/10 border-t-blue-500 rounded-full animate-spin"></div>
                                                <span>Loading users...</span>
                                            </div>
                                        </td>
                                    </tr>
                                ) : filteredUsers.length === 0 ? (
                                    <tr>
                                        <td colSpan={5} className="p-8 text-center text-slate-500">
                                            No users found
                                        </td>
                                    </tr>
                                ) : (
                                    filteredUsers.map((user, index) => (
                                        <motion.tr
                                            key={user._id}
                                            initial={{ opacity: 0, y: 10 }}
                                            animate={{ opacity: 1, y: 0 }}
                                            exit={{ opacity: 0 }}
                                            transition={{ duration: 0.2 }}
                                            className="group hover:bg-white/5 transition-colors"
                                        >
                                            <td className="p-4">
                                                <div className="flex items-center gap-3">
                                                    <div className="w-10 h-10 rounded-full bg-gradient-to-tr from-blue-500 to-purple-500 p-[1px]">
                                                        <div className="w-full h-full rounded-full bg-slate-900 flex items-center justify-center text-sm font-bold text-white">
                                                            {user.name?.charAt(0)?.toUpperCase() || '?'}
                                                        </div>
                                                    </div>
                                                    <div>
                                                        <div className="font-medium text-white">{user.name || 'Unknown'}</div>
                                                        <div className="text-xs text-slate-400 flex items-center gap-1">
                                                            <Mail size={10} />
                                                            {user.email}
                                                        </div>
                                                    </div>
                                                </div>
                                            </td>
                                            <td className="p-4">
                                                <span className={`inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-medium border ${user.role === 'admin'
                                                    ? 'bg-purple-500/10 text-purple-400 border-purple-500/20'
                                                    : 'bg-blue-500/10 text-blue-400 border-blue-500/20'
                                                    }`}>
                                                    {user.role === 'admin' && <Shield size={10} />}
                                                    <span className="capitalize">{user.role || 'user'}</span>
                                                </span>
                                            </td>
                                            <td className="p-4">
                                                <span className={`inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-xs font-medium border ${user.subscriptionStatus === 'pro'
                                                    ? 'bg-amber-500/10 text-amber-500 border-amber-500/20'
                                                    : 'bg-slate-500/10 text-slate-400 border-slate-500/20'
                                                    }`}>
                                                    {user.subscriptionStatus === 'pro' && <Zap size={10} className="fill-current" />}
                                                    <span className="capitalize">{user.subscriptionStatus || 'free'}</span>
                                                </span>
                                            </td>
                                            <td className="p-4">
                                                <span className={`inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-medium border ${user.isSuspended
                                                    ? 'bg-red-500/10 text-red-500 border-red-500/20'
                                                    : 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20'
                                                    }`}>
                                                    <span className={`w-1.5 h-1.5 rounded-full ${user.isSuspended ? 'bg-red-500' : 'bg-emerald-500'}`}></span>
                                                    {user.isSuspended ? 'Suspended' : 'Active'}
                                                </span>
                                            </td>
                                            <td className="p-4 text-right relative">
                                                <div className="flex items-center justify-end gap-2">
                                                    <div className="relative">
                                                        <button
                                                            onClick={(e) => {
                                                                e.stopPropagation();
                                                                setActiveMenu(activeMenu === user._id ? null : user._id);
                                                            }}
                                                            className="p-2 rounded-lg hover:bg-white/10 text-slate-400 hover:text-white transition-colors"
                                                        >
                                                            <MoreVertical size={16} />
                                                        </button>

                                                        <AnimatePresence>
                                                            {activeMenu === user._id && (
                                                                <motion.div
                                                                    initial={{ opacity: 0, scale: 0.95, y: -10 }}
                                                                    animate={{ opacity: 1, scale: 1, y: 0 }}
                                                                    exit={{ opacity: 0, scale: 0.95, y: -10 }}
                                                                    className="absolute right-0 top-full mt-2 w-48 bg-slate-900 border border-white/10 rounded-xl shadow-2xl z-50 overflow-hidden"
                                                                    onClick={(e) => e.stopPropagation()}
                                                                >
                                                                    <div className="p-1 px-2 text-[10px] font-bold text-slate-500 uppercase tracking-widest border-b border-white/5 bg-white/5 py-1.5">
                                                                        Quick Actions
                                                                    </div>
                                                                    <div className="p-1.5 space-y-1">
                                                                        <button
                                                                            onClick={() => handleAction(user._id, 'status', !user.isSuspended)}
                                                                            className={`w-full flex items-center gap-2 px-3 py-2 rounded-lg text-xs font-medium transition-colors ${user.isSuspended ? 'text-emerald-400 hover:bg-emerald-500/10' : 'text-red-400 hover:bg-red-500/10'}`}
                                                                        >
                                                                            {user.isSuspended ? <UserCheck size={14} /> : <Ban size={14} />}
                                                                            {user.isSuspended ? 'Unsuspend User' : 'Suspend User'}
                                                                        </button>
                                                                        <button
                                                                            onClick={() => handleAction(user._id, 'subscription', user.subscriptionStatus === 'pro' ? 'free' : 'pro')}
                                                                            className={`w-full flex items-center gap-2 px-3 py-2 rounded-lg text-xs font-medium transition-colors ${user.subscriptionStatus === 'pro' ? 'text-slate-400 hover:bg-white/5' : 'text-amber-500 hover:bg-amber-500/10'}`}
                                                                        >
                                                                            <Zap size={14} />
                                                                            {user.subscriptionStatus === 'pro' ? 'Revoke Pro Access' : 'Grant Pro Access'}
                                                                        </button>
                                                                        <button
                                                                            onClick={() => handleAction(user._id, 'role', user.role === 'admin' ? 'user' : 'admin')}
                                                                            className="w-full flex items-center gap-2 px-3 py-2 rounded-lg text-xs font-medium text-purple-400 hover:bg-purple-500/10 transition-colors"
                                                                        >
                                                                            <ShieldCheck size={14} />
                                                                            {user.role === 'admin' ? 'Remove Admin' : 'Make Admin'}
                                                                        </button>
                                                                        <div className="h-px bg-white/5 my-1" />
                                                                        <button
                                                                            onClick={() => { setDeleteTarget(user); setActiveMenu(null); }}
                                                                            className="w-full flex items-center gap-2 px-3 py-2 rounded-lg text-xs font-medium text-red-500 hover:bg-red-500/10 transition-colors"
                                                                        >
                                                                            <Trash2 size={14} />
                                                                            Permanently Delete
                                                                        </button>
                                                                    </div>
                                                                </motion.div>
                                                            )}
                                                        </AnimatePresence>
                                                    </div>
                                                </div>
                                            </td>
                                        </motion.tr>
                                    ))
                                )}
                            </AnimatePresence>
                        </tbody>
                    </table>
                </div>
            </div>

            {/* Add User Modal */}
            <AnimatePresence>
                {showAddModal && (
                    <motion.div
                        initial={{ opacity: 0 }}
                        animate={{ opacity: 1 }}
                        exit={{ opacity: 0 }}
                        className="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center z-50"
                        onClick={() => setShowAddModal(false)}
                    >
                        <motion.div
                            initial={{ scale: 0.9, opacity: 0, y: 20 }}
                            animate={{ scale: 1, opacity: 1, y: 0 }}
                            exit={{ scale: 0.9, opacity: 0, y: 20 }}
                            className="bg-slate-900 border border-white/10 rounded-2xl p-6 max-w-md w-full mx-4 shadow-2xl"
                            onClick={(e) => e.stopPropagation()}
                        >
                            <div className="flex items-center justify-between mb-6">
                                <h3 className="text-xl font-bold text-white">Add New User</h3>
                                <button
                                    onClick={() => setShowAddModal(false)}
                                    className="p-1 rounded-lg hover:bg-white/10 text-slate-400 hover:text-white transition-colors"
                                >
                                    <X size={18} />
                                </button>
                            </div>

                            <form onSubmit={handleAddUser} className="space-y-4">
                                <div>
                                    <label className="block text-xs font-bold text-slate-400 uppercase tracking-wider mb-1.5 ml-1">Full Name</label>
                                    <input
                                        type="text"
                                        required
                                        value={newData.name}
                                        onChange={e => setNewData({ ...newData, name: e.target.value })}
                                        className="w-full bg-slate-800/50 border border-white/5 rounded-xl px-4 py-3 text-white focus:outline-none focus:border-blue-500/50 transition-all"
                                        placeholder="John Doe"
                                    />
                                </div>
                                <div>
                                    <label className="block text-xs font-bold text-slate-400 uppercase tracking-wider mb-1.5 ml-1">Email Address</label>
                                    <input
                                        type="email"
                                        required
                                        value={newData.email}
                                        onChange={e => setNewData({ ...newData, email: e.target.value })}
                                        className="w-full bg-slate-800/50 border border-white/5 rounded-xl px-4 py-3 text-white focus:outline-none focus:border-blue-500/50 transition-all"
                                        placeholder="john@example.com"
                                    />
                                </div>
                                <div>
                                    <label className="block text-xs font-bold text-slate-400 uppercase tracking-wider mb-1.5 ml-1">Initial Password</label>
                                    <input
                                        type="password"
                                        required
                                        value={newData.password}
                                        onChange={e => setNewData({ ...newData, password: e.target.value })}
                                        className="w-full bg-slate-800/50 border border-white/5 rounded-xl px-4 py-3 text-white focus:outline-none focus:border-blue-500/50 transition-all"
                                        placeholder="••••••••"
                                    />
                                </div>

                                <div className="pt-4">
                                    <button
                                        type="submit"
                                        disabled={adding}
                                        className="w-full py-3.5 rounded-xl bg-blue-600 hover:bg-blue-500 text-white font-bold transition-all shadow-lg shadow-blue-500/20 flex items-center justify-center gap-2 disabled:opacity-50"
                                    >
                                        {adding ? (
                                            <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                                        ) : (
                                            <>
                                                <UserIcon size={18} />
                                                Create User Account
                                            </>
                                        )}
                                    </button>
                                </div>
                            </form>
                        </motion.div>
                    </motion.div>
                )}
            </AnimatePresence>

            {/* Delete Confirmation Modal */}
            <AnimatePresence>
                {deleteTarget && (
                    <motion.div
                        initial={{ opacity: 0 }}
                        animate={{ opacity: 1 }}
                        exit={{ opacity: 0 }}
                        className="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center z-50"
                        onClick={() => setDeleteTarget(null)}
                    >
                        <motion.div
                            initial={{ scale: 0.9, opacity: 0 }}
                            animate={{ scale: 1, opacity: 1 }}
                            exit={{ scale: 0.9, opacity: 0 }}
                            className="bg-slate-900 border border-white/10 rounded-2xl p-6 max-w-md w-full mx-4 shadow-2xl"
                            onClick={(e) => e.stopPropagation()}
                        >
                            <div className="flex items-center gap-3 mb-4">
                                <div className="w-12 h-12 rounded-full bg-red-500/10 flex items-center justify-center text-red-400">
                                    <AlertTriangle size={24} />
                                </div>
                                <div>
                                    <h3 className="text-lg font-bold text-white">Delete User</h3>
                                    <p className="text-sm text-slate-400">This action cannot be undone</p>
                                </div>
                                <button
                                    onClick={() => setDeleteTarget(null)}
                                    className="ml-auto p-1 rounded-lg hover:bg-white/10 text-slate-400 hover:text-white transition-colors"
                                >
                                    <X size={18} />
                                </button>
                            </div>

                            <p className="text-slate-300 mb-6">
                                Are you sure you want to delete <strong className="text-white">{deleteTarget.name}</strong> ({deleteTarget.email})?
                                All their data including payments and support tickets will be permanently removed.
                            </p>

                            <div className="flex gap-3 justify-end">
                                <button
                                    onClick={() => setDeleteTarget(null)}
                                    className="px-4 py-2 rounded-xl bg-white/5 border border-white/10 text-slate-300 hover:bg-white/10 transition-colors font-medium"
                                >
                                    Cancel
                                </button>
                                <button
                                    onClick={() => handleDelete(deleteTarget)}
                                    disabled={deleting}
                                    className="px-4 py-2 rounded-xl bg-red-600 hover:bg-red-500 text-white font-medium transition-colors disabled:opacity-50 flex items-center gap-2 shadow-lg shadow-red-500/20"
                                >
                                    {deleting ? (
                                        <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                                    ) : (
                                        <Trash2 size={16} />
                                    )}
                                    {deleting ? 'Deleting...' : 'Delete User'}
                                </button>
                            </div>
                        </motion.div>
                    </motion.div>
                )}
            </AnimatePresence>
        </div>
    );
}

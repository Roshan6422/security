import { useState, useEffect } from 'react';
import axios from 'axios';
import { User, Mail, Lock, Save, Shield, CheckCircle, AlertCircle } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { getBaseUrl } from '../utils/api';

export default function ProfilePage() {
    const [user, setUser] = useState({
        name: '',
        email: '',
        role: ''
    });
    const [passwords, setPasswords] = useState({
        currentPassword: '',
        newPassword: '',
        confirmPassword: ''
    });
    const [saving, setSaving] = useState(false);
    const [message, setMessage] = useState<{ type: 'success' | 'error', text: string } | null>(null);

    useEffect(() => {
        fetchProfile();
    }, []);

    const fetchProfile = async () => {
        try {
            const token = localStorage.getItem('adminToken');
            const res = await axios.get(`${getBaseUrl()}/api/auth/me`, {
                headers: { Authorization: `Bearer ${token}` }
            });
            setUser({
                name: res.data.name,
                email: res.data.email,
                role: res.data.role || 'admin'
            });
        } catch (err) {
            console.error(err);
            setMessage({ type: 'error', text: 'Failed to load profile' });
        } finally {
            // Loading done
        }
    };

    const handleUpdate = async (e: React.FormEvent) => {
        e.preventDefault();
        setMessage(null);
        setSaving(true);

        if (passwords.newPassword && passwords.newPassword !== passwords.confirmPassword) {
            setMessage({ type: 'error', text: 'New passwords do not match' });
            setSaving(false);
            return;
        }

        try {
            const token = localStorage.getItem('adminToken');
            const payload: any = {
                name: user.name,
                email: user.email
            };

            if (passwords.newPassword) {
                payload.password = passwords.newPassword;
            }

            const res = await axios.put(`${getBaseUrl()}/api/auth/profile`, payload, {
                headers: { Authorization: `Bearer ${token}` }
            });

            setUser({
                ...user,
                name: res.data.name,
                email: res.data.email
            });

            setPasswords({
                currentPassword: '',
                newPassword: '',
                confirmPassword: ''
            });

            setMessage({ type: 'success', text: 'Profile updated successfully' });
        } catch (err: any) {
            console.error(err);
            setMessage({ type: 'error', text: err.response?.data?.message || 'Failed to update profile' });
        } finally {
            setSaving(false);
        }
    };

    return (
        <div className="space-y-8 max-w-4xl mx-auto pt-6">
            <div>
                <h2 className="text-3xl font-bold text-white">Profile Settings</h2>
                <p className="text-slate-400">Manage your account credentials</p>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
                {/* Profile Card */}
                <div className="md:col-span-1">
                    <div className="glass-panel p-6 rounded-2xl flex flex-col items-center text-center space-y-4">
                        <div className="w-24 h-24 rounded-full bg-gradient-to-tr from-blue-500 to-violet-500 p-1">
                            <div className="w-full h-full rounded-full bg-slate-900 flex items-center justify-center">
                                <User size={40} className="text-white" />
                            </div>
                        </div>
                        <div>
                            <h3 className="text-xl font-bold text-white">{user.name || 'Loading...'}</h3>
                            <p className="text-slate-400 text-sm">{user.email || 'Loading...'}</p>
                        </div>
                        <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold border bg-purple-500/10 border-purple-500/20 text-purple-400">
                            <Shield size={12} />
                            <span className="capitalize">{user.role}</span>
                        </div>
                    </div>
                </div>

                {/* Settings Form */}
                <motion.div
                    initial={{ opacity: 0, y: 20 }}
                    animate={{ opacity: 1, y: 0 }}
                    className="md:col-span-2"
                >
                    <div className="glass-panel p-8 rounded-2xl">
                        <form onSubmit={handleUpdate} className="space-y-6">
                            <div className="space-y-4">
                                <h3 className="text-lg font-semibold text-white border-b border-white/10 pb-2">
                                    Account Information
                                </h3>

                                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                                    <div className="space-y-2">
                                        <label className="text-sm font-medium text-slate-300">Display Name</label>
                                        <div className="relative">
                                            <User className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" size={18} />
                                            <input
                                                type="text"
                                                value={user.name}
                                                onChange={(e) => setUser({ ...user, name: e.target.value })}
                                                className="w-full bg-slate-900/50 border border-slate-700 rounded-xl pl-10 pr-4 py-2.5 text-white focus:outline-none focus:border-blue-500 focus:ring-1 focus:ring-blue-500/50"
                                                placeholder="Your Name"
                                            />
                                        </div>
                                    </div>

                                    <div className="space-y-2">
                                        <label className="text-sm font-medium text-slate-300">Email Address</label>
                                        <div className="relative">
                                            <Mail className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" size={18} />
                                            <input
                                                type="email"
                                                value={user.email}
                                                onChange={(e) => setUser({ ...user, email: e.target.value })}
                                                className="w-full bg-slate-900/50 border border-slate-700 rounded-xl pl-10 pr-4 py-2.5 text-white focus:outline-none focus:border-blue-500 focus:ring-1 focus:ring-blue-500/50"
                                                placeholder="name@example.com"
                                            />
                                        </div>
                                    </div>
                                </div>
                            </div>

                            <div className="space-y-4 pt-4">
                                <h3 className="text-lg font-semibold text-white border-b border-white/10 pb-2">
                                    Change Password
                                </h3>

                                <div className="space-y-4">
                                    <div className="space-y-2">
                                        <label className="text-sm font-medium text-slate-300">New Password</label>
                                        <div className="relative">
                                            <Lock className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" size={18} />
                                            <input
                                                type="password"
                                                value={passwords.newPassword}
                                                onChange={(e) => setPasswords({ ...passwords, newPassword: e.target.value })}
                                                className="w-full bg-slate-900/50 border border-slate-700 rounded-xl pl-10 pr-4 py-2.5 text-white focus:outline-none focus:border-blue-500 focus:ring-1 focus:ring-blue-500/50"
                                                placeholder="Leave blank to keep current"
                                            />
                                        </div>
                                    </div>

                                    <div className="space-y-2">
                                        <label className="text-sm font-medium text-slate-300">Confirm New Password</label>
                                        <div className="relative">
                                            <Lock className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" size={18} />
                                            <input
                                                type="password"
                                                value={passwords.confirmPassword}
                                                onChange={(e) => setPasswords({ ...passwords, confirmPassword: e.target.value })}
                                                className="w-full bg-slate-900/50 border border-slate-700 rounded-xl pl-10 pr-4 py-2.5 text-white focus:outline-none focus:border-blue-500 focus:ring-1 focus:ring-blue-500/50"
                                                placeholder="Confirm new password"
                                            />
                                        </div>
                                    </div>
                                </div>
                            </div>

                            <AnimatePresence>
                                {message && (
                                    <motion.div
                                        initial={{ opacity: 0, height: 0 }}
                                        animate={{ opacity: 1, height: 'auto' }}
                                        exit={{ opacity: 0, height: 0 }}
                                        className={`flex items-center gap-2 p-3 rounded-xl text-sm font-medium ${message.type === 'success'
                                            ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/20'
                                            : 'bg-red-500/10 text-red-400 border border-red-500/20'
                                            }`}
                                    >
                                        {message.type === 'success' ? <CheckCircle size={16} /> : <AlertCircle size={16} />}
                                        {message.text}
                                    </motion.div>
                                )}
                            </AnimatePresence>

                            <div className="pt-4 flex justify-end">
                                <button
                                    type="submit"
                                    disabled={saving}
                                    className="flex items-center gap-2 px-6 py-2.5 rounded-xl bg-blue-600 hover:bg-blue-500 text-white font-bold shadow-lg shadow-blue-500/20 transition-all disabled:opacity-50 disabled:cursor-not-allowed"
                                >
                                    {saving ? (
                                        <>
                                            <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                                            <span>Saving...</span>
                                        </>
                                    ) : (
                                        <>
                                            <Save size={18} />
                                            <span>Save Changes</span>
                                        </>
                                    )}
                                </button>
                            </div>
                        </form>
                    </div>
                </motion.div>
            </div>
        </div>
    );
}

import { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import axios from 'axios';
import {
    AlertCircle,
    Mail,
    Lock,
    CheckCircle2,
    UserPlus,
} from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { getBaseUrl } from '../utils/api';

export default function PromotePage() {
    const navigate = useNavigate();
    const [email, setEmail] = useState('');
    const [secret, setSecret] = useState('');
    const [error, setError] = useState('');
    const [success, setSuccess] = useState(false);
    const [loading, setLoading] = useState(false);

    const handlePromote = async (e: React.FormEvent) => {
        e.preventDefault();
        setError('');
        setLoading(true);

        try {
            await axios.post(`${getBaseUrl()}/api/auth/make-admin`, { email, secret });
            setSuccess(true);
            setLoading(false);
        } catch (err: any) {
            setError(err.response?.data?.message || 'Promotion failed. Check secret or email.');
            setLoading(false);
        }
    };

    return (
        <div className="min-h-screen bg-[#0B0F14] flex items-center justify-center p-4 relative overflow-hidden">
            <div className="absolute inset-0">
                <div className="absolute top-[-20%] right-[-10%] w-[600px] h-[600px] rounded-full bg-[#4DA3FF]/15 blur-[120px]" />
                <div className="absolute bottom-[-20%] left-[-10%] w-[600px] h-[600px] rounded-full bg-[#8B5CF6]/15 blur-[120px]" />
            </div>

            <motion.div
                initial={{ opacity: 0, y: 30 }}
                animate={{ opacity: 1, y: 0 }}
                className="w-full max-w-[420px] relative z-10"
            >
                <div className="backdrop-blur-2xl bg-[#0E1419]/80 border border-white/[0.08] rounded-3xl shadow-2xl p-8 md:p-10">
                    <div className="flex flex-col items-center mb-8">
                        <div className="w-[64px] h-[64px] rounded-2xl bg-gradient-to-br from-[#8B5CF6] to-[#4DA3FF] flex items-center justify-center mb-5 shadow-lg shadow-purple-500/30">
                            <UserPlus size={32} className="text-white" />
                        </div>
                        <h1 className="text-2xl font-bold text-white tracking-tight">Admin Escalation</h1>
                        <p className="text-[#EAF2FF]/50 text-xs mt-1 text-center">
                            Promote an existing account to Admin status
                        </p>
                    </div>

                    <AnimatePresence mode="wait">
                        {!success ? (
                            <motion.form
                                key="form"
                                initial={{ opacity: 0 }}
                                animate={{ opacity: 1 }}
                                exit={{ opacity: 0 }}
                                onSubmit={handlePromote}
                                className="space-y-4"
                            >
                                <div className="space-y-1.5">
                                    <label className="text-[10px] font-bold text-[#EAF2FF]/60 uppercase tracking-widest ml-1">User Email</label>
                                    <div className="relative group">
                                        <Mail className="absolute left-4 top-1/2 -translate-y-1/2 text-[#EAF2FF]/30" size={18} />
                                        <input
                                            type="email"
                                            required
                                            value={email}
                                            onChange={(e) => setEmail(e.target.value)}
                                            className="w-full bg-white/[0.03] border border-white/[0.08] rounded-2xl pl-12 pr-4 py-3.5 text-white focus:outline-none focus:border-[#4DA3FF]/50 text-sm"
                                            placeholder="user@example.com"
                                        />
                                    </div>
                                </div>

                                <div className="space-y-1.5">
                                    <label className="text-[10px] font-bold text-[#EAF2FF]/60 uppercase tracking-widest ml-1">Admin Secret</label>
                                    <div className="relative group">
                                        <Lock className="absolute left-4 top-1/2 -translate-y-1/2 text-[#EAF2FF]/30" size={18} />
                                        <input
                                            type="password"
                                            required
                                            value={secret}
                                            onChange={(e) => setSecret(e.target.value)}
                                            className="w-full bg-white/[0.03] border border-white/[0.08] rounded-2xl pl-12 pr-4 py-3.5 text-white focus:outline-none focus:border-[#4DA3FF]/50 text-sm"
                                            placeholder="admin-secret-123"
                                        />
                                    </div>
                                </div>

                                {error && (
                                    <div className="flex items-center gap-2 text-red-400 text-xs bg-red-500/10 p-3 rounded-xl border border-red-500/20">
                                        <AlertCircle size={14} />
                                        <span>{error}</span>
                                    </div>
                                )}

                                <button
                                    type="submit"
                                    disabled={loading}
                                    className="w-full bg-gradient-to-r from-[#8B5CF6] to-[#4DA3FF] text-white font-bold py-4 rounded-2xl transition-all shadow-lg"
                                >
                                    {loading ? 'Processing...' : 'Promote to Admin'}
                                </button>
                                <div className="text-center">
                                    <Link to="/login" className="text-[#EAF2FF]/40 text-xs hover:text-[#4DA3FF]">Back to Login</Link>
                                </div>
                            </motion.form>
                        ) : (
                            <motion.div
                                key="success"
                                initial={{ opacity: 0, scale: 0.9 }}
                                animate={{ opacity: 1, scale: 1 }}
                                className="text-center space-y-6"
                            >
                                <div className="w-16 h-16 bg-emerald-500/20 rounded-2xl flex items-center justify-center mx-auto border border-emerald-500/30">
                                    <CheckCircle2 size={32} className="text-emerald-400" />
                                </div>
                                <h2 className="text-xl font-bold text-white">Promotion Successful!</h2>
                                <p className="text-[#EAF2FF]/50 text-sm">Account <b>{email}</b> has been upgraded. You can now log in to the dashboard.</p>
                                <button
                                    onClick={() => navigate('/login')}
                                    className="w-full bg-blue-600 hover:bg-blue-500 text-white font-bold py-4 rounded-2xl transition-all shadow-lg shadow-blue-500/20"
                                >
                                    Login Now
                                </button>
                            </motion.div>
                        )}
                    </AnimatePresence>
                </div>
            </motion.div>
        </div>
    );
}

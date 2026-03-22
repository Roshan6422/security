import { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import axios from 'axios';
import {
    Lock,
    ArrowRight,
    AlertCircle,
    Mail,
    User,
    Eye,
    EyeOff,
    Sparkles,
    CheckCircle2,
} from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { getBaseUrl } from '../utils/api';

export default function Register() {
    const navigate = useNavigate();
    const [name, setName] = useState('');
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');

    const [showPassword, setShowPassword] = useState(false);
    const [error, setError] = useState('');
    const [loading, setLoading] = useState(false);
    const [successData, setSuccessData] = useState<any>(null);

    const handleRegister = async (e: React.FormEvent) => {
        e.preventDefault();
        setError('');
        setLoading(true);

        try {
            const res = await axios.post(`${getBaseUrl()}/api/auth/register`, {
                name, email, password,
            });
            setSuccessData(res.data);
            setLoading(false);
        } catch (err: any) {
            console.error(err);
            const errorMessage = err.response?.data?.message || 'Registration failed';
            setError(errorMessage);
            setLoading(false);
        }
    };

    if (successData) {
        return (
            <div className="min-h-screen bg-[#0B0F14] flex items-center justify-center p-4 relative overflow-hidden">
                <div className="absolute inset-0">
                    <div className="absolute top-[-20%] right-[-10%] w-[600px] h-[600px] rounded-full bg-[#4DA3FF]/15 blur-[120px]" />
                    <div className="absolute bottom-[-20%] left-[-10%] w-[600px] h-[600px] rounded-full bg-[#8B5CF6]/15 blur-[120px]" />
                </div>

                <motion.div
                    initial={{ opacity: 0, scale: 0.9 }}
                    animate={{ opacity: 1, scale: 1 }}
                    className="w-full max-w-[480px] relative z-10"
                >
                    <div className="backdrop-blur-2xl bg-[#0E1419]/80 border border-white/[0.08] rounded-3xl p-8 md:p-10 shadow-2xl text-center">
                        <div className="w-20 h-20 bg-emerald-500/20 rounded-2xl flex items-center justify-center mx-auto mb-6 border border-emerald-500/30">
                            <CheckCircle2 size={40} className="text-emerald-400" />
                        </div>
                        <h1 className="text-2xl font-bold text-white mb-2">Registration Successful!</h1>
                        <p className="text-[#EAF2FF]/50 text-sm mb-8">
                            Your account has been created. Please remember your username, as you will need it to reset your password.
                        </p>

                        <div className="bg-black/40 border border-white/5 rounded-2xl p-6 mb-8 relative group">
                            <label className="text-[10px] font-bold text-[#EAF2FF]/40 uppercase tracking-[0.2em] mb-3 block">Your Username</label>
                            <div className="flex items-center justify-center gap-4">
                                <span className="text-2xl font-mono font-bold text-[#4DA3FF] tracking-wider select-all">
                                    {successData.user.name}
                                </span>
                            </div>
                        </div>

                        <button
                            onClick={() => navigate('/login')}
                            className="w-full bg-gradient-to-r from-[#4DA3FF] to-[#2B7FDB] text-white font-bold py-4 rounded-2xl shadow-lg shadow-[#4DA3FF]/20"
                        >
                            Back to Login
                        </button>
                    </div>
                </motion.div>
            </div>
        );
    }

    return (
        <div className="min-h-screen bg-[#0B0F14] flex items-center justify-center p-4 relative overflow-hidden">
            <div className="absolute inset-0">
                <div className="absolute top-[-20%] right-[-10%] w-[600px] h-[600px] rounded-full bg-[#4DA3FF]/15 blur-[120px]" />
                <div className="absolute bottom-[-20%] left-[-10%] w-[600px] h-[600px] rounded-full bg-[#8B5CF6]/15 blur-[120px]" />
                <div className="absolute inset-0 opacity-[0.04] bg-[linear-gradient(to_right,rgba(234,242,255,0.12)_1px,transparent_1px),linear-gradient(to_bottom,rgba(234,242,255,0.12)_1px,transparent_1px)] bg-[size:32px_32px]" />
            </div>

            <motion.div
                initial={{ opacity: 0, y: 30 }}
                animate={{ opacity: 1, y: 0 }}
                className="w-full max-w-[420px] relative z-10"
            >
                <div className="backdrop-blur-2xl bg-[#0E1419]/80 border border-white/[0.08] rounded-3xl shadow-2xl overflow-hidden p-8 md:p-10">
                    <div className="flex flex-col items-center mb-8">
                        <div className="w-[64px] h-[64px] rounded-2xl bg-gradient-to-br from-[#4DA3FF] to-[#2B7FDB] flex items-center justify-center mb-5 shadow-lg shadow-[#4DA3FF]/30 border border-white/10">
                            <User size={32} className="text-white" />
                        </div>
                        <h1 className="text-2xl font-bold text-white tracking-tight">Create Account</h1>
                        <p className="text-[#EAF2FF]/50 text-xs mt-1">Join the SafeShell secure ecosystem</p>
                    </div>

                    <form onSubmit={handleRegister} className="space-y-4">
                        <div className="space-y-1.5">
                            <label className="text-[10px] font-bold text-[#EAF2FF]/60 uppercase tracking-widest ml-1">Full Name</label>
                            <div className="relative group">
                                <User className="absolute left-4 top-1/2 -translate-y-1/2 text-[#EAF2FF]/30 group-focus-within:text-[#4DA3FF] transition-colors" size={18} />
                                <input
                                    type="text"
                                    required
                                    value={name}
                                    onChange={(e) => setName(e.target.value)}
                                    className="w-full bg-white/[0.03] border border-white/[0.08] rounded-2xl pl-12 pr-4 py-3.5 text-white placeholder:text-[#EAF2FF]/20 focus:outline-none focus:border-[#4DA3FF]/50 transition-all text-sm"
                                    placeholder="John Doe"
                                />
                            </div>
                        </div>

                        <div className="space-y-1.5">
                            <label className="text-[10px] font-bold text-[#EAF2FF]/60 uppercase tracking-widest ml-1">Email Address</label>
                            <div className="relative group">
                                <Mail className="absolute left-4 top-1/2 -translate-y-1/2 text-[#EAF2FF]/30 group-focus-within:text-[#4DA3FF] transition-colors" size={18} />
                                <input
                                    type="email"
                                    required
                                    value={email}
                                    onChange={(e) => setEmail(e.target.value)}
                                    className="w-full bg-white/[0.03] border border-white/[0.08] rounded-2xl pl-12 pr-4 py-3.5 text-white placeholder:text-[#EAF2FF]/20 focus:outline-none focus:border-[#4DA3FF]/50 transition-all text-sm"
                                    placeholder="john@example.com"
                                />
                            </div>
                        </div>

                        <div className="space-y-1.5">
                            <label className="text-[10px] font-bold text-[#EAF2FF]/60 uppercase tracking-widest ml-1">Password</label>
                            <div className="relative group">
                                <Lock className="absolute left-4 top-1/2 -translate-y-1/2 text-[#EAF2FF]/30 group-focus-within:text-[#4DA3FF] transition-colors" size={18} />
                                <input
                                    type={showPassword ? "text" : "password"}
                                    required
                                    value={password}
                                    onChange={(e) => setPassword(e.target.value)}
                                    className="w-full bg-white/[0.03] border border-white/[0.08] rounded-2xl pl-12 pr-12 py-3.5 text-white placeholder:text-[#EAF2FF]/20 focus:outline-none focus:border-[#4DA3FF]/50 transition-all text-sm"
                                    placeholder="••••••••"
                                />
                                <button
                                    type="button"
                                    onClick={() => setShowPassword(!showPassword)}
                                    className="absolute right-4 top-1/2 -translate-y-1/2 text-[#EAF2FF]/30 hover:text-white"
                                >
                                    {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                                </button>
                            </div>
                        </div>






                        <AnimatePresence>
                            {error && (
                                <motion.div
                                    initial={{ opacity: 0, height: 0 }}
                                    animate={{ opacity: 1, height: 'auto' }}
                                    className="flex items-center gap-2 text-red-400 text-xs bg-red-500/10 p-3 rounded-xl border border-red-500/20"
                                >
                                    <AlertCircle size={14} />
                                    <span>{error}</span>
                                </motion.div>
                            )}
                        </AnimatePresence>

                        <button
                            type="submit"
                            disabled={loading}
                            className="w-full bg-gradient-to-r from-[#4DA3FF] to-[#2B7FDB] hover:from-[#5BB0FF] hover:to-[#3B8CEB] text-white font-bold py-4 rounded-2xl transition-all shadow-lg shadow-[#4DA3FF]/20 mt-4 disabled:opacity-50"
                        >
                            {loading ? (
                                <div className="flex items-center justify-center gap-2">
                                    <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                                    <span>Creating...</span>
                                </div>
                            ) : (
                                <span className="flex items-center justify-center gap-2">
                                    <Sparkles size={18} />
                                    Create Account
                                    <ArrowRight size={18} />
                                </span>
                            )}
                        </button>

                        <div className="text-center mt-6">
                            <p className="text-[#EAF2FF]/40 text-sm">
                                Already have an account?{' '}
                                <Link to="/login" className="text-[#4DA3FF] font-bold hover:text-[#7BB7FF]">
                                    Sign In
                                </Link>
                            </p>
                        </div>
                    </form>
                </div>
            </motion.div >
        </div >
    );
}

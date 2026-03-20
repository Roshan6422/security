import { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import axios from 'axios';
import {
    Lock,
    AlertCircle,
    Mail,
    Key,
    CheckCircle2,
    Eye,
    EyeOff,
    User,
} from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { getBaseUrl } from '../utils/api';

export default function ForgotPassword() {
    const navigate = useNavigate();
    const [step, setStep] = useState(1);
    const [email, setEmail] = useState('');
    const [username, setUsername] = useState('');
    const [recoveryKey, setRecoveryKey] = useState('');
    const [newPassword, setNewPassword] = useState('');
    const [showPassword, setShowPassword] = useState(false);
    const [error, setError] = useState('');
    const [loading, setLoading] = useState(false);

    const handleVerifyKey = async (e: React.FormEvent) => {
        e.preventDefault();
        setError('');
        setLoading(true);

        try {
            await axios.post(`${getBaseUrl()}/api/auth/verify-recovery-key`, {
                email,
                name: username,
                recoveryKey
            });
            setStep(2);
            setLoading(false);
        } catch (err: any) {
            setError(err.response?.data?.message || 'Verification failed');
            setLoading(false);
        }
    };

    const handleResetPassword = async (e: React.FormEvent) => {
        e.preventDefault();
        setError('');
        setLoading(true);

        try {
            await axios.post(`${getBaseUrl()}/api/auth/reset-password-via-key`, {
                email,
                name: username,
                recoveryKey,
                newPassword
            });
            setStep(3);
            setLoading(false);
        } catch (err: any) {
            setError(err.response?.data?.message || 'Reset failed');
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
                        <div className="w-[64px] h-[64px] rounded-2xl bg-gradient-to-br from-[#4DA3FF] to-[#2B7FDB] flex items-center justify-center mb-5 shadow-lg shadow-[#4DA3FF]/30">
                            <Key size={32} className="text-white" />
                        </div>
                        <h1 className="text-2xl font-bold text-white tracking-tight">Recovery System</h1>
                        <p className="text-[#EAF2FF]/50 text-xs mt-1">
                            {step === 1 ? 'Verify your identity with recovery key' : 'Set your new secure password'}
                        </p>
                    </div>

                    <AnimatePresence mode="wait">
                        {step === 1 && (
                            <motion.form
                                key="step1"
                                initial={{ opacity: 0, x: 20 }}
                                animate={{ opacity: 1, x: 0 }}
                                exit={{ opacity: 0, x: -20 }}
                                onSubmit={handleVerifyKey}
                                className="space-y-4"
                            >
                                <div className="space-y-1.5">
                                    <label className="text-[10px] font-bold text-[#EAF2FF]/60 uppercase tracking-widest ml-1">Email Address</label>
                                    <div className="relative group">
                                        <Mail className="absolute left-4 top-1/2 -translate-y-1/2 text-[#EAF2FF]/30" size={18} />
                                        <input
                                            type="email"
                                            required
                                            value={email}
                                            onChange={(e) => setEmail(e.target.value)}
                                            className="w-full bg-white/[0.03] border border-white/[0.08] rounded-2xl pl-12 pr-4 py-3.5 text-white focus:outline-none focus:border-[#4DA3FF]/50 text-sm"
                                            placeholder="john@example.com"
                                        />
                                    </div>
                                </div>

                                <div className="space-y-1.5">
                                    <label className="text-[10px] font-bold text-[#EAF2FF]/60 uppercase tracking-widest ml-1">Username</label>
                                    <div className="relative group">
                                        <User className="absolute left-4 top-1/2 -translate-y-1/2 text-[#EAF2FF]/30" size={18} />
                                        <input
                                            type="text"
                                            required
                                            value={username}
                                            onChange={(e) => setUsername(e.target.value)}
                                            className="w-full bg-white/[0.03] border border-white/[0.08] rounded-2xl pl-12 pr-4 py-3.5 text-white focus:outline-none focus:border-[#4DA3FF]/50 font-medium text-sm"
                                            placeholder="Enter your username"
                                        />
                                    </div>
                                </div>

                                <div className="space-y-1.5">
                                    <label className="text-[10px] font-bold text-[#EAF2FF]/60 uppercase tracking-widest ml-1">Recovery Key</label>
                                    <div className="relative group">
                                        <Key className="absolute left-4 top-1/2 -translate-y-1/2 text-[#EAF2FF]/30" size={18} />
                                        <input
                                            type="text"
                                            required
                                            value={recoveryKey}
                                            onChange={(e) => setRecoveryKey(e.target.value)}
                                            className="w-full bg-white/[0.03] border border-white/[0.08] rounded-2xl pl-12 pr-4 py-3.5 text-white focus:outline-none focus:border-[#4DA3FF]/50 font-medium text-sm"
                                            placeholder="SAFE-XXXX-XXXX"
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
                                    className="w-full bg-blue-600 hover:bg-blue-500 text-white font-bold py-4 rounded-2xl transition-all shadow-lg"
                                >
                                    {loading ? 'Verifying...' : 'Verify Recovery Key'}
                                </button>
                                <div className="text-center">
                                    <Link to="/login" className="text-[#EAF2FF]/40 text-xs hover:text-[#4DA3FF]">Back to Login</Link>
                                </div>
                            </motion.form>
                        )}

                        {step === 2 && (
                            <motion.form
                                key="step2"
                                initial={{ opacity: 0, x: 20 }}
                                animate={{ opacity: 1, x: 0 }}
                                exit={{ opacity: 0, x: -20 }}
                                onSubmit={handleResetPassword}
                                className="space-y-4"
                            >
                                <div className="space-y-1.5">
                                    <label className="text-[10px] font-bold text-[#EAF2FF]/60 uppercase tracking-widest ml-1">New Password</label>
                                    <div className="relative group">
                                        <Lock className="absolute left-4 top-1/2 -translate-y-1/2 text-[#EAF2FF]/30" size={18} />
                                        <input
                                            type={showPassword ? "text" : "password"}
                                            required
                                            value={newPassword}
                                            onChange={(e) => setNewPassword(e.target.value)}
                                            className="w-full bg-white/[0.03] border border-white/[0.08] rounded-2xl pl-12 pr-12 py-3.5 text-white focus:outline-none focus:border-[#4DA3FF]/50 text-sm"
                                            placeholder="••••••••"
                                        />
                                        <button
                                            type="button"
                                            onClick={() => setShowPassword(!showPassword)}
                                            className="absolute right-4 top-1/2 -translate-y-1/2 text-[#EAF2FF]/30"
                                        >
                                            {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                                        </button>
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
                                    className="w-full bg-emerald-600 hover:bg-emerald-500 text-white font-bold py-4 rounded-2xl transition-all shadow-lg"
                                >
                                    {loading ? 'Resetting...' : 'Update Password'}
                                </button>
                            </motion.form>
                        )}

                        {step === 3 && (
                            <motion.div
                                key="step3"
                                initial={{ opacity: 0, scale: 0.9 }}
                                animate={{ opacity: 1, scale: 1 }}
                                className="text-center space-y-6"
                            >
                                <div className="w-16 h-16 bg-emerald-500/20 rounded-2xl flex items-center justify-center mx-auto border border-emerald-500/30">
                                    <CheckCircle2 size={32} className="text-emerald-400" />
                                </div>
                                <h2 className="text-xl font-bold text-white">Password Reset Complete</h2>
                                <p className="text-[#EAF2FF]/50 text-sm">Your password has been updated. You can now log in with your new credentials.</p>
                                <button
                                    onClick={() => navigate('/login')}
                                    className="w-full bg-blue-600 hover:bg-blue-500 text-white font-bold py-4 rounded-2xl transition-all"
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

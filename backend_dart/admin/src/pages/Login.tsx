
import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import axios from 'axios';
import {
    Lock,
    ShieldCheck,
    ArrowRight,
    AlertCircle,
    Mail,
    Eye,
    EyeOff,
    Sparkles,
    Fingerprint,
} from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { getBaseUrl } from '../utils/api';

export default function Login() {
    const navigate = useNavigate();
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [showPassword, setShowPassword] = useState(false);
    const [error, setError] = useState('');
    const [loading, setLoading] = useState(false);
    const [rememberMe, setRememberMe] = useState(false);

    const handleLogin = async (e: React.FormEvent) => {
        e.preventDefault();
        setError('');
        setLoading(true);

        try {
            const res = await axios.post(`${getBaseUrl()}/api/auth/login`, { email, password });

            localStorage.setItem('adminToken', res.data.token);

            if (res.data.role !== 'admin') {
                setError("Access denied. Admin privileges required.");
                setLoading(false);
                return;
            }

            // Simulating the premium feel "processing" delay slightly if API is too fast, 
            // or just proceed. The original had a 500ms delay.
            setTimeout(() => {
                navigate('/dashboard');
            }, 800);

        } catch (err: any) {
            console.error(err);
            const errorMessage = err.response?.data?.message || 'Invalid credentials';
            setError(errorMessage);
            setLoading(false);
        }
    };

    return (
        <div className="min-h-screen bg-[#0B0F14] flex items-center justify-center p-4 relative overflow-hidden">
            {/* Premium Background */}
            <div className="absolute inset-0">
                {/* Gradient orbs */}
                <div className="absolute top-[-20%] right-[-10%] w-[600px] h-[600px] rounded-full bg-[#4DA3FF]/15 blur-[120px]" />
                <div className="absolute bottom-[-20%] left-[-10%] w-[600px] h-[600px] rounded-full bg-[#8B5CF6]/15 blur-[120px]" />
                <div className="absolute top-[30%] left-[20%] w-[400px] h-[400px] rounded-full bg-[#0A2A4F]/30 blur-[100px]" />

                {/* Grid pattern */}
                <div className="absolute inset-0 opacity-[0.04] bg-[linear-gradient(to_right,rgba(234,242,255,0.12)_1px,transparent_1px),linear-gradient(to_bottom,rgba(234,242,255,0.12)_1px,transparent_1px)] bg-[size:32px_32px]" />

                {/* Radial gradient overlay */}
                <div className="absolute inset-0 bg-[radial-gradient(800px_circle_at_50%_30%,rgba(77,163,255,0.08),transparent_60%)]" />
            </div>

            {/* Floating particles */}
            <div className="absolute inset-0 overflow-hidden pointer-events-none">
                {[...Array(6)].map((_, i) => (
                    <motion.div
                        key={i}
                        className="absolute w-2 h-2 rounded-full bg-[#4DA3FF]/20"
                        style={{
                            left: `${20 + i * 15}%`,
                            top: `${10 + (i % 3) * 30}%`,
                        }}
                        animate={{
                            y: [-20, 20, -20],
                            opacity: [0.2, 0.5, 0.2],
                        }}
                        transition={{
                            duration: 4 + i,
                            repeat: Infinity,
                            ease: "easeInOut",
                        }}
                    />
                ))}
            </div>

            <motion.div
                initial={{ opacity: 0, y: 30 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.6, ease: "easeOut" }}
                className="w-full max-w-[420px] relative z-10"
            >
                {/* Main Card */}
                <div className="relative">
                    {/* Glow effect behind card */}
                    <div className="absolute inset-0 bg-gradient-to-br from-[#4DA3FF]/10 via-transparent to-[#8B5CF6]/10 rounded-3xl blur-xl" />

                    <div className="relative backdrop-blur-2xl bg-[#0E1419]/80 border border-white/[0.08] rounded-3xl shadow-2xl overflow-hidden">
                        {/* Top gradient line */}
                        <div className="absolute top-0 left-0 right-0 h-[1px] bg-gradient-to-r from-transparent via-[#4DA3FF]/50 to-transparent" />

                        {/* Content */}
                        <div className="p-8 md:p-10">
                            {/* Header */}
                            <motion.div
                                initial={{ scale: 0.9, opacity: 0 }}
                                animate={{ scale: 1, opacity: 1 }}
                                transition={{ delay: 0.1, duration: 0.5 }}
                                className="flex flex-col items-center mb-8"
                            >
                                {/* Logo */}
                                <div className="relative mb-5">
                                    <div className="absolute inset-0 bg-[#4DA3FF]/30 rounded-2xl blur-xl" />
                                    <motion.div
                                        whileHover={{ scale: 1.05 }}
                                        className="relative w-[72px] h-[72px] rounded-2xl bg-gradient-to-br from-[#4DA3FF] to-[#2B7FDB] flex items-center justify-center border border-white/20"
                                        style={{
                                            boxShadow: "0 8px 32px rgba(77,163,255,0.35)",
                                        }}
                                    >
                                        <ShieldCheck size={36} className="text-white" />
                                    </motion.div>
                                </div>

                                <h1 className="text-white font-bold text-[28px] tracking-tight">
                                    Welcome Back
                                </h1>
                                <p className="text-[#EAF2FF]/50 text-[14px] mt-2">
                                    Sign in to access your secure vault
                                </p>

                                {/* Trust badges */}
                                <div className="flex items-center gap-2 mt-4">
                                    <span className="px-3 py-1.5 rounded-full bg-[#4DA3FF]/10 border border-[#4DA3FF]/20 text-[#93C5FD] text-[11px] font-semibold flex items-center gap-1.5">
                                        <Lock size={12} />
                                        AES-256
                                    </span>
                                    <span className="px-3 py-1.5 rounded-full bg-[#8B5CF6]/10 border border-[#8B5CF6]/20 text-[#C4B5FD] text-[11px] font-semibold flex items-center gap-1.5">
                                        <Fingerprint size={12} />
                                        Secure
                                    </span>
                                </div>
                            </motion.div>

                            {/* Form */}
                            <form onSubmit={handleLogin} className="space-y-5">
                                {/* Email Field */}
                                <motion.div
                                    initial={{ x: -20, opacity: 0 }}
                                    animate={{ x: 0, opacity: 1 }}
                                    transition={{ delay: 0.2 }}
                                    className="space-y-2"
                                >
                                    <label className="text-[11px] font-bold text-[#EAF2FF]/60 uppercase tracking-wider ml-1">
                                        Email Address
                                    </label>
                                    <div className="relative group">
                                        <div className="absolute left-4 top-1/2 -translate-y-1/2 text-[#EAF2FF]/30 group-focus-within:text-[#4DA3FF] transition-colors">
                                            <Mail size={18} />
                                        </div>
                                        <input
                                            type="email"
                                            value={email}
                                            onChange={(e) => setEmail(e.target.value)}
                                            className="w-full bg-white/[0.03] border border-white/[0.08] rounded-2xl pl-12 pr-4 py-4 text-white placeholder:text-[#EAF2FF]/25 focus:outline-none focus:border-[#4DA3FF]/50 focus:bg-white/[0.05] transition-all"
                                            placeholder="admin@admin.com"
                                            required
                                        />
                                    </div>
                                </motion.div>

                                {/* Password Field */}
                                <motion.div
                                    initial={{ x: -20, opacity: 0 }}
                                    animate={{ x: 0, opacity: 1 }}
                                    transition={{ delay: 0.3 }}
                                    className="space-y-2"
                                >
                                    <label className="text-[11px] font-bold text-[#EAF2FF]/60 uppercase tracking-wider ml-1">
                                        Password
                                    </label>
                                    <div className="relative group">
                                        <div className="absolute left-4 top-1/2 -translate-y-1/2 text-[#EAF2FF]/30 group-focus-within:text-[#4DA3FF] transition-colors">
                                            <Lock size={18} />
                                        </div>
                                        <input
                                            type={showPassword ? "text" : "password"}
                                            value={password}
                                            onChange={(e) => setPassword(e.target.value)}
                                            className="w-full bg-white/[0.03] border border-white/[0.08] rounded-2xl pl-12 pr-12 py-4 text-white placeholder:text-[#EAF2FF]/25 focus:outline-none focus:border-[#4DA3FF]/50 focus:bg-white/[0.05] transition-all"
                                            placeholder="••••••••"
                                            required
                                        />
                                        <button
                                            type="button"
                                            onClick={() => setShowPassword(!showPassword)}
                                            className="absolute right-4 top-1/2 -translate-y-1/2 text-[#EAF2FF]/30 hover:text-[#EAF2FF]/60 transition-colors"
                                        >
                                            {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                                        </button>
                                    </div>
                                </motion.div>

                                {/* Remember Me & Forgot Password */}
                                <motion.div
                                    initial={{ opacity: 0 }}
                                    animate={{ opacity: 1 }}
                                    transition={{ delay: 0.4 }}
                                    className="flex items-center justify-between"
                                >
                                    <label className="flex items-center gap-2.5 cursor-pointer group">
                                        <div
                                            className={`w-5 h-5 rounded-md border transition-all flex items-center justify-center ${rememberMe
                                                ? "bg-[#4DA3FF] border-[#4DA3FF]"
                                                : "border-white/20 group-hover:border-white/40"
                                                }`}
                                            onClick={() => setRememberMe(!rememberMe)}
                                        >
                                            {rememberMe && (
                                                <motion.svg
                                                    initial={{ scale: 0 }}
                                                    animate={{ scale: 1 }}
                                                    className="w-3 h-3 text-white"
                                                    fill="none"
                                                    viewBox="0 0 24 24"
                                                    stroke="currentColor"
                                                    strokeWidth={3}
                                                >
                                                    <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                                                </motion.svg>
                                            )}
                                        </div>
                                        <span className="text-[#EAF2FF]/50 text-[13px] group-hover:text-[#EAF2FF]/70 transition-colors">
                                            Remember me
                                        </span>
                                    </label>

                                    <button
                                        type="button"
                                        onClick={() => navigate('/forgot-password')}
                                        className="text-[#4DA3FF] text-[13px] font-semibold hover:text-[#7BB7FF] transition-colors"
                                    >
                                        Forgot password?
                                    </button>
                                </motion.div>

                                {/* Error Message */}
                                <AnimatePresence>
                                    {error && (
                                        <motion.div
                                            initial={{ opacity: 0, height: 0, marginTop: 0 }}
                                            animate={{ opacity: 1, height: 'auto', marginTop: 8 }}
                                            exit={{ opacity: 0, height: 0, marginTop: 0 }}
                                            className="flex items-center gap-2.5 text-red-400 text-[13px] bg-red-500/10 p-3.5 rounded-xl border border-red-500/20"
                                        >
                                            <AlertCircle size={18} className="shrink-0" />
                                            <span>{error}</span>

                                        </motion.div>
                                    )}
                                </AnimatePresence>

                                {/* Submit Button */}
                                <motion.div
                                    initial={{ y: 20, opacity: 0 }}
                                    animate={{ y: 0, opacity: 1 }}
                                    transition={{ delay: 0.5 }}
                                    className="pt-2"
                                >
                                    <button
                                        type="submit"
                                        disabled={loading}
                                        className="w-full relative overflow-hidden bg-gradient-to-r from-[#4DA3FF] to-[#2B7FDB] hover:from-[#5BB0FF] hover:to-[#3B8CEB] text-white font-bold py-4 rounded-2xl transition-all shadow-lg shadow-[#4DA3FF]/25 group disabled:opacity-80 disabled:cursor-not-allowed"
                                        style={{
                                            boxShadow: "0 8px 32px rgba(77,163,255,0.3)",
                                        }}
                                    >
                                        <div className="absolute inset-0 bg-gradient-to-r from-white/0 via-white/20 to-white/0 translate-x-[-100%] group-hover:translate-x-[100%] transition-transform duration-700" />
                                        <span className="relative flex items-center justify-center gap-2">
                                            {loading ? (
                                                <>
                                                    <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                                                    <span>Signing in...</span>
                                                </>
                                            ) : (
                                                <>
                                                    <Sparkles size={18} />
                                                    <span>Sign In</span>
                                                    <ArrowRight size={18} className="group-hover:translate-x-1 transition-transform" />
                                                </>
                                            )}
                                        </span>
                                    </button>
                                </motion.div>

                                {/* Divider */}
                                <motion.div
                                    initial={{ opacity: 0 }}
                                    animate={{ opacity: 1 }}
                                    transition={{ delay: 0.6 }}
                                    className="relative py-4"
                                >
                                    <div className="absolute inset-0 flex items-center">
                                        <div className="w-full border-t border-white/[0.06]" />
                                    </div>
                                    <div className="relative flex justify-center">
                                        <span className="bg-[#0E1419] px-4 text-[#EAF2FF]/30 text-[12px]">
                                            New to SafeShell?
                                        </span>
                                    </div>
                                </motion.div>

                                {/* Register Link */}
                                <motion.div
                                    initial={{ opacity: 0 }}
                                    animate={{ opacity: 1 }}
                                    transition={{ delay: 0.7 }}
                                    className="text-center"
                                >
                                    <button
                                        type="button"
                                        onClick={() => navigate('/register')}
                                        className="text-[#EAF2FF]/60 text-[14px] hover:text-[#4DA3FF] transition-colors"
                                    >
                                        Create an account{' '}
                                        <span className="font-semibold text-[#4DA3FF]">→</span>
                                    </button>
                                </motion.div>

                                {/* Promote Link */}
                                <motion.div
                                    initial={{ opacity: 0 }}
                                    animate={{ opacity: 1 }}
                                    transition={{ delay: 0.75 }}
                                    className="text-center mt-3"
                                >
                                    <button
                                        type="button"
                                        onClick={() => navigate('/promote')}
                                        className="text-[#EAF2FF]/40 text-[12px] hover:text-[#8B5CF6] transition-colors flex items-center justify-center gap-1 mx-auto"
                                    >
                                        <ShieldCheck size={12} />
                                        Start Admin Access
                                    </button>
                                </motion.div>
                            </form>
                        </div>
                    </div>
                </div>

                {/* Footer */}
                <motion.p
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    transition={{ delay: 0.8 }}
                    className="text-center text-[#EAF2FF]/25 text-[11px] mt-6 flex items-center justify-center gap-2"
                >
                    <ShieldCheck size={12} />
                    Protected by SafeShell Security Systems
                </motion.p>
            </motion.div >
        </div >
    );
}

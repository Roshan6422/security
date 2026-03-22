
import { useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import { ShieldCheck, Lock, ArrowRight, Calculator, Eye, EyeOff, Smartphone, Shield, Fingerprint, Cloud } from 'lucide-react';

export default function LandingPage() {
    const navigate = useNavigate();

    return (
        <div className="min-h-screen bg-[#0B0F14] text-white overflow-x-hidden selection:bg-[#4DA3FF]/30">
            {/* Navbar */}
            <nav className="fixed top-0 left-0 right-0 z-50 backdrop-blur-xl bg-[#0B0F14]/70 border-b border-white/[0.06]">
                <div className="max-w-7xl mx-auto px-6 h-20 flex items-center justify-between">
                    <div className="flex items-center gap-3">
                        <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-[#4DA3FF] to-[#2B7FDB] flex items-center justify-center shadow-lg shadow-[#4DA3FF]/20">
                            <ShieldCheck size={20} className="text-white" />
                        </div>
                        <span className="font-bold text-xl tracking-tight">SafeShell</span>
                    </div>
                    <div className="flex items-center gap-6">
                        <button
                            onClick={() => navigate('/login')}
                            className="px-6 py-2.5 rounded-xl bg-white/[0.05] hover:bg-white/[0.1] border border-white/[0.08] text-sm font-semibold transition-all hover:scale-105 active:scale-95"
                        >
                            Log In
                        </button>
                        <button
                            onClick={() => navigate('/register')}
                            className="px-6 py-2.5 rounded-xl bg-[#4DA3FF] hover:bg-[#3B8CEB] text-white text-sm font-semibold shadow-lg shadow-[#4DA3FF]/25 transition-all hover:scale-105 active:scale-95"
                        >
                            Get Started
                        </button>
                    </div>
                </div>
            </nav>

            {/* Hero Section */}
            <section className="relative pt-40 pb-32 px-6">
                {/* Background Effects */}
                <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[800px] h-[500px] bg-[#4DA3FF]/20 blur-[120px] rounded-full opacity-50 pointer-events-none" />
                <div className="absolute bottom-0 right-0 w-[600px] h-[600px] bg-[#8B5CF6]/10 blur-[120px] rounded-full opacity-30 pointer-events-none" />

                <div className="max-w-7xl mx-auto relative z-10 text-center">
                    <motion.div
                        initial={{ opacity: 0, y: 20 }}
                        animate={{ opacity: 1, y: 0 }}
                        transition={{ duration: 0.6 }}
                    >
                        <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-white/[0.03] border border-white/[0.08] mb-8 backdrop-blur-sm">
                            <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
                            <span className="text-sm text-[#EAF2FF]/60 font-medium">Discreet Design for Added Privacy</span>
                        </div>
                        <h1 className="text-5xl md:text-7xl font-bold tracking-tight mb-8 bg-clip-text text-transparent bg-gradient-to-b from-white via-white to-white/40">
                            Looks Like a <span className="text-[#4DA3FF]">Calculator</span>. <br />
                            Works Like a <span className="text-[#8B5CF6]">Vault</span>.
                        </h1>
                        <p className="text-xl text-[#EAF2FF]/40 max-w-2xl mx-auto mb-12 leading-relaxed">
                            SafeShell uses a calculator-style interface to add an extra layer of privacy for your personal files. Smart concealment meets strong protection — only you know what's inside.
                        </p>
                        <div className="flex flex-col sm:flex-row items-center justify-center gap-4">
                            <button
                                onClick={() => navigate('/register')}
                                className="w-full sm:w-auto px-8 py-4 rounded-2xl bg-gradient-to-r from-[#4DA3FF] to-[#2B7FDB] hover:from-[#5BB0FF] hover:to-[#3B8CEB] text-white font-bold shadow-xl shadow-[#4DA3FF]/20 transition-all hover:scale-105 active:scale-95 flex items-center justify-center gap-2"
                            >
                                Download Now
                                <ArrowRight size={20} />
                            </button>
                            <button
                                onClick={() => navigate('/login')}
                                className="w-full sm:w-auto px-8 py-4 rounded-2xl bg-[#0E1419] border border-white/[0.08] hover:bg-white/[0.02] text-white font-semibold transition-all hover:scale-105 active:scale-95 flex items-center justify-center gap-2"
                            >
                                <Lock size={18} className="text-[#EAF2FF]/40" />
                                Admin Access
                            </button>
                        </div>
                    </motion.div>
                </div>
            </section>

            {/* How It Works Section */}
            <section className="py-24 px-6 relative">
                <div className="max-w-7xl mx-auto">
                    <motion.div
                        initial={{ opacity: 0 }}
                        whileInView={{ opacity: 1 }}
                        viewport={{ once: true }}
                        className="text-center mb-16"
                    >
                        <h2 className="text-3xl md:text-4xl font-bold mb-4">How It Works</h2>
                        <p className="text-[#EAF2FF]/40 max-w-lg mx-auto">A secure vault with a calculator-style interface. Your privacy stays invisible to everyone else.</p>
                    </motion.div>

                    <div className="grid md:grid-cols-3 gap-8">
                        {[
                            {
                                icon: <Calculator size={32} className="text-[#4DA3FF]" />,
                                step: "01",
                                title: "Open the Calculator",
                                description: "Launch the app — it appears and functions as a regular calculator on your device."
                            },
                            {
                                icon: <Fingerprint size={32} className="text-[#8B5CF6]" />,
                                step: "02",
                                title: "Enter Your Secret PIN",
                                description: "Type your private PIN on the calculator keypad. Only you know the combination that unlocks the vault."
                            },
                            {
                                icon: <Shield size={32} className="text-[#10B981]" />,
                                step: "03",
                                title: "Access Your Vault",
                                description: "Your encrypted files, photos, videos, and documents are instantly accessible. Secured with biometric lock."
                            }
                        ].map((feature, i) => (
                            <motion.div
                                key={i}
                                initial={{ opacity: 0, y: 20 }}
                                whileInView={{ opacity: 1, y: 0 }}
                                viewport={{ once: true }}
                                transition={{ delay: i * 0.15 }}
                                className="p-8 rounded-3xl bg-[#0E1419]/50 border border-white/[0.06] hover:bg-[#0E1419] hover:border-[#4DA3FF]/30 transition-all group relative"
                            >
                                <div className="absolute top-6 right-6 text-6xl font-black text-white/[0.03] group-hover:text-[#4DA3FF]/10 transition-colors">
                                    {feature.step}
                                </div>
                                <div className="w-16 h-16 rounded-2xl bg-white/[0.03] flex items-center justify-center mb-6 group-hover:scale-110 transition-transform">
                                    {feature.icon}
                                </div>
                                <h3 className="text-xl font-bold mb-3">{feature.title}</h3>
                                <p className="text-[#EAF2FF]/40 leading-relaxed">{feature.description}</p>
                            </motion.div>
                        ))}
                    </div>
                </div>
            </section>

            {/* Features Grid */}
            <section className="py-24 px-6 relative bg-[#0E1419]/30">
                <div className="max-w-7xl mx-auto">
                    <motion.div
                        initial={{ opacity: 0 }}
                        whileInView={{ opacity: 1 }}
                        viewport={{ once: true }}
                        className="text-center mb-16"
                    >
                        <h2 className="text-3xl md:text-4xl font-bold mb-4">Premium Features</h2>
                        <p className="text-[#EAF2FF]/40 max-w-lg mx-auto">Everything you need to keep your private files secure and accessible.</p>
                    </motion.div>

                    <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
                        {[
                            {
                                icon: <EyeOff size={24} className="text-[#4DA3FF]" />,
                                title: "Discreet Interface",
                                description: "Calculator-style design that blends seamlessly into your phone."
                            },
                            {
                                icon: <Lock size={24} className="text-[#8B5CF6]" />,
                                title: "Military-Grade Encryption",
                                description: "Your files are encrypted with AES-256 before being stored."
                            },
                            {
                                icon: <Fingerprint size={24} className="text-[#10B981]" />,
                                title: "Biometric Lock",
                                description: "Use fingerprint authentication for an extra layer of vault security."
                            },
                            {
                                icon: <Cloud size={24} className="text-[#F59E0B]" />,
                                title: "Cloud Backup",
                                description: "Encrypted cloud storage ensures your files are never lost."
                            },
                            {
                                icon: <Smartphone size={24} className="text-[#EC4899]" />,
                                title: "Private Browser",
                                description: "Browse privately without trace. No history, no cookies."
                            },
                            {
                                icon: <Eye size={24} className="text-[#06B6D4]" />,
                                title: "Stealth Mode",
                                description: "Switch app icons on demand for added discretion."
                            }
                        ].map((feature, i) => (
                            <motion.div
                                key={i}
                                initial={{ opacity: 0, y: 10 }}
                                whileInView={{ opacity: 1, y: 0 }}
                                viewport={{ once: true }}
                                transition={{ delay: i * 0.08 }}
                                className="p-6 rounded-2xl bg-[#0B0F14]/60 border border-white/[0.06] hover:border-[#4DA3FF]/20 transition-all group"
                            >
                                <div className="w-12 h-12 rounded-xl bg-white/[0.03] flex items-center justify-center mb-4 group-hover:scale-110 transition-transform">
                                    {feature.icon}
                                </div>
                                <h3 className="text-lg font-bold mb-2">{feature.title}</h3>
                                <p className="text-[#EAF2FF]/35 text-sm leading-relaxed">{feature.description}</p>
                            </motion.div>
                        ))}
                    </div>
                </div>
            </section>

            {/* CTA Section */}
            <section className="py-24 px-6 relative">
                <div className="absolute inset-0 bg-gradient-to-b from-transparent via-[#4DA3FF]/5 to-transparent pointer-events-none" />
                <div className="max-w-3xl mx-auto relative z-10 text-center">
                    <motion.div
                        initial={{ opacity: 0, y: 20 }}
                        whileInView={{ opacity: 1, y: 0 }}
                        viewport={{ once: true }}
                    >
                        <h2 className="text-3xl md:text-5xl font-bold mb-6">
                            Your Privacy. <span className="text-[#4DA3FF]">Your Control.</span>
                        </h2>
                        <p className="text-lg text-[#EAF2FF]/40 mb-10 leading-relaxed">
                            Smart concealment meets strong protection. SafeShell blends seamlessly into your phone while securing what matters most.
                        </p>
                        <button
                            onClick={() => navigate('/register')}
                            className="px-10 py-5 rounded-2xl bg-gradient-to-r from-[#4DA3FF] to-[#8B5CF6] hover:from-[#5BB0FF] hover:to-[#9D6FFF] text-white font-bold text-lg shadow-xl shadow-[#4DA3FF]/20 transition-all hover:scale-105 active:scale-95"
                        >
                            Get SafeShell Free
                        </button>
                    </motion.div>
                </div>
            </section>

            {/* Footer */}
            <footer className="py-12 px-6 border-t border-white/[0.06] bg-[#0E1419]/30">
                <div className="max-w-7xl mx-auto flex flex-col md:flex-row items-center justify-between gap-8">
                    <div className="flex items-center gap-3 opacity-50">
                        <ShieldCheck size={24} />
                        <span className="font-semibold text-lg">SafeShell</span>
                    </div>
                    <div className="flex items-center gap-8 text-sm text-[#EAF2FF]/40">
                        <a href="#" className="hover:text-white transition-colors">Privacy Policy</a>
                        <a href="#" className="hover:text-white transition-colors">Terms of Service</a>
                        <a href="#" className="hover:text-white transition-colors">Contact Support</a>
                    </div>
                    <div className="text-sm text-[#EAF2FF]/20">
                        © 2026 SafeShell Security. All rights reserved.
                    </div>
                </div>
            </footer>
        </div>
    );
}

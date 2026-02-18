import { motion } from 'framer-motion';
import { Shield, Cpu, Database, Zap, Server, HardDrive } from 'lucide-react';

export default function HealthPage() {
    return (
        <div className="space-y-8 pt-6">
            <header>
                <h2 className="text-3xl font-bold text-white tracking-tight">System Health</h2>
                <p className="text-slate-400 mt-1">Real-time infrastructure and service monitoring</p>
            </header>

            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
                <HealthStatCard title="API Server" status="Operational" load="12%" icon={Server} color="emerald" />
                <HealthStatCard title="Database" status="Operational" latency="4ms" icon={Database} color="emerald" />
                <HealthStatCard title="Storage" status="Optimal" used="45.2 GB" icon={HardDrive} color="blue" />
                <HealthStatCard title="Authentication" status="Operational" icon={Shield} color="emerald" />
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
                <div className="glass-panel p-6 rounded-2xl">
                    <h3 className="text-xl font-bold text-white mb-6 flex items-center gap-2">
                        <Cpu size={20} className="text-blue-400" />
                        CPU Usage History
                    </h3>
                    <div className="h-48 flex items-end gap-1 px-2">
                        {[...Array(20)].map((_, i) => (
                            <motion.div
                                key={i}
                                initial={{ height: 0 }}
                                animate={{ height: `${20 + Math.random() * 60}%` }}
                                transition={{ repeat: Infinity, duration: 2, repeatType: 'reverse', delay: i * 0.1 }}
                                className="flex-1 bg-gradient-to-t from-blue-600 to-blue-400 rounded-t-sm opacity-60"
                            />
                        ))}
                    </div>
                </div>

                <div className="glass-panel p-6 rounded-2xl">
                    <h3 className="text-xl font-bold text-white mb-6 flex items-center gap-2">
                        <Zap size={20} className="text-yellow-400" />
                        Service Latency (ms)
                    </h3>
                    <div className="space-y-4">
                        <LatencyBar label="User API" value={45} max={100} color="emerald" />
                        <LatencyBar label="Vault Service" value={120} max={200} color="yellow" />
                        <LatencyBar label="Payment Gateway" value={85} max={150} color="emerald" />
                        <LatencyBar label="Admin Service" value={30} max={100} color="emerald" />
                    </div>
                </div>
            </div>
        </div>
    );
}

function HealthStatCard({ title, status, load, latency, used, icon: Icon, color }: any) {
    return (
        <div className="glass-panel p-6 rounded-2xl group hover:border-white/20 transition-all">
            <div className="flex justify-between items-start mb-4">
                <div className={`p-3 rounded-xl bg-${color}-500/10 text-${color}-400 ring-1 ring-${color}-500/20`}>
                    <Icon size={24} />
                </div>
                <span className={`px-2 py-1 rounded-lg text-[10px] font-bold uppercase tracking-wider bg-${color}-500/10 text-${color}-400 border border-${color}-500/20`}>
                    {status}
                </span>
            </div>
            <h4 className="text-slate-400 text-sm font-medium">{title}</h4>
            <p className="text-2xl font-bold text-white mt-1">{load || latency || used || 'Healthy'}</p>
        </div>
    );
}

function LatencyBar({ label, value, max, color }: any) {
    const percentage = (value / max) * 100;
    return (
        <div>
            <div className="flex justify-between text-xs mb-1.5">
                <span className="text-slate-300 font-medium">{label}</span>
                <span className={`text-${color}-400 font-bold`}>{value}ms</span>
            </div>
            <div className="h-1.5 w-full bg-white/5 rounded-full overflow-hidden">
                <motion.div
                    initial={{ width: 0 }}
                    animate={{ width: `${percentage}%` }}
                    className={`h-full bg-${color}-500`}
                />
            </div>
        </div>
    );
}

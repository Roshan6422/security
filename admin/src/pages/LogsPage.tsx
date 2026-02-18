import { motion } from 'framer-motion';
import { Shield, AlertCircle, Info, Lock, Terminal, Search } from 'lucide-react';

export default function LogsPage() {
    const logs = [
        { id: 1, type: 'info', event: 'Admin Login', user: 'admin@safeshell.com', ip: '192.168.1.1', date: '2024-05-20 14:30:22', status: 'Success' },
        { id: 2, type: 'warning', event: 'Failed Login Attempt', user: 'unknown@user.com', ip: '45.12.33.21', date: '2024-05-20 14:15:05', status: 'Blocked' },
        { id: 3, type: 'critical', event: 'Database Backup Error', user: 'SYSTEM', ip: '127.0.0.1', date: '2024-05-20 12:00:00', status: 'Failed' },
        { id: 4, type: 'info', event: 'User Registered', user: 'newuser@gmail.com', ip: '102.44.2.19', date: '2024-05-20 11:45:30', status: 'Success' },
        { id: 5, type: 'info', event: 'Vault Key Updated', user: 'roshan@safeshell.com', ip: '192.168.1.10', date: '2024-05-20 10:20:15', status: 'Encrypted' },
        { id: 6, type: 'warning', event: 'Suspicious IP Detected', user: 'N/A', ip: '203.0.113.5', date: '2024-05-20 09:05:44', status: 'Flagged' },
    ];

    return (
        <div className="space-y-8 pt-6">
            <header className="flex flex-col md:flex-row md:items-center justify-between gap-4">
                <div>
                    <h2 className="text-3xl font-bold text-white tracking-tight flex items-center gap-3">
                        <Terminal size={32} className="text-blue-500" />
                        Security Logs
                    </h2>
                    <p className="text-slate-400 mt-1">Audit trail of all administrative and security actions</p>
                </div>
                <div className="flex items-center gap-2">
                    <div className="relative">
                        <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-500" size={16} />
                        <input type="text" placeholder="Search logs..." className="bg-white/5 border border-white/10 rounded-xl pl-9 pr-4 py-2 text-sm text-white focus:outline-none focus:border-blue-500/50" />
                    </div>
                </div>
            </header>

            <div className="glass-panel rounded-2xl overflow-hidden border border-white/10">
                <table className="w-full text-left">
                    <thead>
                        <tr className="bg-white/5 border-b border-white/5 text-xs font-bold text-slate-400 uppercase tracking-widest">
                            <th className="p-4">Type</th>
                            <th className="p-4">Event</th>
                            <th className="p-4">Actor</th>
                            <th className="p-4">Source IP</th>
                            <th className="p-4">Timestamp</th>
                            <th className="p-4 text-right">Status</th>
                        </tr>
                    </thead>
                    <tbody className="divide-y divide-white/5">
                        {logs.map((log, i) => (
                            <motion.tr
                                key={log.id}
                                initial={{ opacity: 0, x: -10 }}
                                animate={{ opacity: 1, x: 0 }}
                                transition={{ delay: i * 0.1 }}
                                className="group hover:bg-white/5 transition-colors"
                            >
                                <td className="p-4">
                                    <LogTypeIcon type={log.type} />
                                </td>
                                <td className="p-4 text-sm font-semibold text-white">{log.event}</td>
                                <td className="p-4 text-sm text-slate-300">{log.user}</td>
                                <td className="p-4 text-xs font-mono text-slate-400">{log.ip}</td>
                                <td className="p-4 text-xs text-slate-500">{log.date}</td>
                                <td className="p-4 text-right">
                                    <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold border ${log.status === 'Success' ? 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20' :
                                        log.status === 'Blocked' ? 'bg-orange-500/10 text-orange-400 border-orange-500/20' :
                                            'bg-rose-500/10 text-rose-400 border-rose-500/20'
                                        }`}>
                                        {log.status}
                                    </span>
                                </td>
                            </motion.tr>
                        ))}
                    </tbody>
                </table>
            </div>
        </div>
    );
}

function LogTypeIcon({ type }: any) {
    switch (type) {
        case 'info': return <Info size={16} className="text-blue-400" />;
        case 'warning': return <AlertCircle size={16} className="text-orange-400" />;
        case 'critical': return <Shield size={16} className="text-rose-400" />;
        default: return <Lock size={16} className="text-slate-400" />;
    }
}

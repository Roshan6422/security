import { useEffect, useState } from 'react';
import axios from 'axios';
import { motion } from 'framer-motion';
import { Users, DollarSign, MessageSquare, TrendingUp, ArrowUpRight, Calendar, ShieldCheck } from 'lucide-react';
import { AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';
import { getBaseUrl } from '../utils/api';

export default function OverviewPage() {
    const [stats, setStats] = useState({
        totalUsers: 0,
        totalRevenue: 0,
        activeTickets: 0,
        recentActivity: [] as any[]
    });
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        const fetchStats = async () => {
            try {
                const token = localStorage.getItem('adminToken');
                const headers = { Authorization: `Bearer ${token}` };

                const [usersRes, paymentsRes, ticketsRes] = await Promise.all([
                    axios.get(`${getBaseUrl()}/api/admin/users`, { headers }),
                    axios.get(`${getBaseUrl()}/api/admin/payments`, { headers }),
                    axios.get(`${getBaseUrl()}/api/admin/tickets`, { headers })
                ]);

                const totalUsers = usersRes.data.length;
                const totalRevenue = paymentsRes.data.reduce((acc: number, curr: any) => acc + curr.amount, 0);
                const activeTickets = ticketsRes.data.filter((t: any) => t.status === 'open').length;

                // Combine for recent activity
                const recentUsers = usersRes.data.slice(-3).map((u: any) => ({ type: 'user', title: `New user: ${u.name}`, date: u.createdAt }));
                const recentPayments = paymentsRes.data.slice(-3).map((p: any) => ({ type: 'payment', title: `New payment: $${p.amount}`, date: p.date }));
                const activity = [...recentUsers, ...recentPayments].sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());

                // Calculate chart data from real payments
                const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
                const last7Days = [...Array(7)].map((_, i) => {
                    const d = new Date();
                    d.setDate(d.getDate() - (6 - i));
                    return {
                        name: days[d.getDay()],
                        fullName: d.toLocaleDateString(),
                        amount: 0,
                        rawDate: d
                    };
                });

                paymentsRes.data.forEach((p: any) => {
                    const pDate = new Date(p.date);
                    const dayMatch = last7Days.find(d =>
                        d.rawDate.getDate() === pDate.getDate() &&
                        d.rawDate.getMonth() === pDate.getMonth() &&
                        d.rawDate.getFullYear() === pDate.getFullYear()
                    );
                    if (dayMatch) {
                        dayMatch.amount += p.amount;
                    }
                });

                setRealChartData(last7Days);

                setStats({
                    totalUsers,
                    totalRevenue,
                    activeTickets,
                    recentActivity: activity
                });
            } catch (err) {
                console.error(err);
            } finally {
                setLoading(false);
            }
        };
        fetchStats();
    }, []);

    const [realChartData, setRealChartData] = useState<any[]>([]);

    if (loading) {
        return (
            <div className="flex items-center justify-center h-full">
                <div className="w-12 h-12 border-4 border-blue-500/20 border-t-blue-500 rounded-full animate-spin" />
            </div>
        );
    }

    return (
        <div className="space-y-8 max-w-[1600px] mx-auto pt-6">
            <header className="flex flex-col md:flex-row md:items-center justify-between gap-4">
                <div>
                    <motion.h1
                        initial={{ opacity: 0, y: -20 }}
                        animate={{ opacity: 1, y: 0 }}
                        className="text-3xl font-bold text-white mb-2 tracking-tight"
                    >
                        Dashboard Overview
                    </motion.h1>
                    <motion.p
                        initial={{ opacity: 0 }}
                        animate={{ opacity: 1 }}
                        transition={{ delay: 0.1 }}
                        className="text-slate-400"
                    >
                        Welcome back! Here's your daily activity summary.
                    </motion.p>
                </div>
                <motion.div
                    initial={{ opacity: 0, x: 20 }}
                    animate={{ opacity: 1, x: 0 }}
                    className="flex items-center gap-2 px-4 py-2 rounded-xl bg-white/5 border border-white/10 text-sm font-medium text-slate-300"
                >
                    <Calendar size={16} className="text-blue-400" />
                    <span>{new Date().toLocaleDateString('en-US', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' })}</span>
                </motion.div>
            </header>

            {/* Stats Grid */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
                <StatCard
                    title="Total Users"
                    value={stats.totalUsers.toLocaleString()}
                    change="+12.5%"
                    icon={Users}
                    color="blue"
                    delay={0.1}
                />
                <StatCard
                    title="Total Revenue"
                    value={`$${stats.totalRevenue.toLocaleString()}`}
                    change="+20.1%"
                    icon={DollarSign}
                    color="emerald"
                    delay={0.2}
                />
                <StatCard
                    title="Active Tickets"
                    value={stats.activeTickets.toString()}
                    change="-5.2%"
                    icon={MessageSquare}
                    color="violet"
                    delay={0.3}
                />
                <StatCard
                    title="System Status"
                    value="Optimal"
                    change="Stable"
                    icon={ShieldCheck}
                    color="blue"
                    delay={0.4}
                />
            </div>

            {/* Charts Section */}
            <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
                <motion.div
                    initial={{ opacity: 0, y: 20 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ delay: 0.5 }}
                    className="lg:col-span-2 glass-panel p-6 rounded-2xl"
                >
                    <div className="flex items-center justify-between mb-8">
                        <div>
                            <h3 className="text-xl font-bold text-white">Revenue Analytics</h3>
                            <p className="text-sm text-slate-400">Real-time revenue performance</p>
                        </div>
                    </div>

                    <div className="h-[350px] w-full">
                        <ResponsiveContainer width="100%" height="100%">
                            <AreaChart data={realChartData}>
                                <defs>
                                    <linearGradient id="colorUv" x1="0" y1="0" x2="0" y2="1">
                                        <stop offset="5%" stopColor="#3b82f6" stopOpacity={0.3} />
                                        <stop offset="95%" stopColor="#3b82f6" stopOpacity={0} />
                                    </linearGradient>
                                </defs>
                                <CartesianGrid strokeDasharray="3 3" stroke="#334155" vertical={false} />
                                <XAxis
                                    dataKey="name"
                                    stroke="#94a3b8"
                                    axisLine={false}
                                    tickLine={false}
                                    tick={{ fontSize: 12, fill: '#94a3b8' }}
                                    dy={10}
                                />
                                <YAxis
                                    stroke="#94a3b8"
                                    axisLine={false}
                                    tickLine={false}
                                    tickFormatter={(value) => `$${value}`}
                                    tick={{ fontSize: 12, fill: '#94a3b8' }}
                                />
                                <Tooltip
                                    contentStyle={{
                                        backgroundColor: '#1e293b',
                                        borderColor: '#334155',
                                        borderRadius: '12px',
                                        color: '#f8fafc',
                                        boxShadow: '0 4px 6px -1px rgba(0, 0, 0, 0.5)'
                                    }}
                                    itemStyle={{ color: '#f8fafc' }}
                                    cursor={{ stroke: '#cbd5e1', strokeWidth: 1, strokeDasharray: '5 5' }}
                                />
                                <Area
                                    type="monotone"
                                    dataKey="amount"
                                    stroke="#3b82f6"
                                    strokeWidth={3}
                                    fillOpacity={1}
                                    fill="url(#colorUv)"
                                />
                            </AreaChart>
                        </ResponsiveContainer>
                    </div>
                </motion.div>

                <motion.div
                    initial={{ opacity: 0, y: 20 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ delay: 0.6 }}
                    className="glass-panel p-6 rounded-2xl flex flex-col h-full"
                >
                    <h3 className="text-xl font-bold text-white mb-6">Recent Activity</h3>
                    <div className="space-y-4 flex-1 overflow-y-auto custom-scrollbar pr-2">
                        {stats.recentActivity.map((activity, i) => (
                            <div key={i} className="flex items-center gap-4 p-3 hover:bg-white/5 rounded-xl transition-all cursor-pointer group border border-transparent hover:border-white/5">
                                <div className={`w-10 h-10 rounded-full flex items-center justify-center ${activity.type === 'user' ? 'bg-blue-500/10 text-blue-400' : 'bg-emerald-500/10 text-emerald-400'}`}>
                                    {activity.type === 'user' ? <Users size={18} /> : <DollarSign size={18} />}
                                </div>
                                <div className="flex-1">
                                    <p className="text-sm font-medium text-slate-200 group-hover:text-blue-400 transition-colors">{activity.title}</p>
                                    <p className="text-xs text-slate-500">{new Date(activity.date).toLocaleDateString()}</p>
                                </div>
                            </div>
                        ))}
                    </div>
                </motion.div>
            </div>
        </div>
    );
}

function StatCard({ title, value, change, icon: Icon, color, delay }: any) {
    const isPositive = change.startsWith('+');

    const colors: any = {
        blue: { bg: 'from-blue-500 to-cyan-500', text: 'text-blue-400' },
        emerald: { bg: 'from-emerald-500 to-teal-500', text: 'text-emerald-400' },
        violet: { bg: 'from-violet-500 to-purple-500', text: 'text-violet-400' },
        pink: { bg: 'from-pink-500 to-rose-500', text: 'text-pink-400' },
    };

    const scheme = colors[color] || colors.blue;

    return (
        <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay }}
            className="glass-card p-6 rounded-2xl relative overflow-hidden group hover:-translate-y-1"
        >
            <div className={`absolute top-0 right-0 w-24 h-24 bg-gradient-to-br ${scheme.bg} opacity-[0.03] rounded-bl-full -mr-4 -mt-4 transition-transform group-hover:scale-110 duration-500 group-hover:opacity-[0.08]`}></div>

            <div className="flex justify-between items-start mb-4 relative z-10">
                <div className={`w-12 h-12 rounded-xl flex items-center justify-center bg-gradient-to-br ${scheme.bg} shadow-lg opacity-90`}>
                    <Icon size={24} className="text-white" />
                </div>
                <div className={`flex items-center gap-1 px-2 py-1 rounded-lg text-xs font-bold ${isPositive ? 'bg-emerald-500/10 text-emerald-400' : 'bg-rose-500/10 text-rose-400'}`}>
                    {isPositive ? <ArrowUpRight size={12} /> : <TrendingUp size={12} className="rotate-180" />}
                    {change}
                </div>
            </div>

            <div className="relative z-10">
                <p className="text-slate-400 text-sm font-medium">{title}</p>
                <h3 className="text-2xl font-bold text-white mt-1">{value}</h3>
            </div>
        </motion.div>
    );
}

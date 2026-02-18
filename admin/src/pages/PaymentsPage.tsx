import { useEffect, useState } from 'react';
import axios from 'axios';
import { DollarSign, TrendingUp, Calendar, ArrowUpRight, ArrowDownRight, Download, Wallet, Activity, CheckCircle2 } from 'lucide-react';
import { motion } from 'framer-motion';
import { XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, BarChart, Bar, Cell } from 'recharts';
import { getBaseUrl } from '../utils/api';

import { Payment } from '../types';

interface BankData {
    bankName: string;
    accountHolder: string;
    accountNumber: string;
    branch: string;
    swiftCode: string;
    updatedAt?: string;
}

export default function PaymentsPage() {
    const [payments, setPayments] = useState<Payment[]>([]);
    const [loading, setLoading] = useState(true);
    const [realChartData, setRealChartData] = useState<any[]>([]);

    // Bank account settings state
    const [bankData, setBankData] = useState<BankData>({
        bankName: '', accountHolder: '', accountNumber: '', branch: '', swiftCode: ''
    });
    const [bankEditing, setBankEditing] = useState(false);
    const [bankSaving, setBankSaving] = useState(false);
    const [bankSuccess, setBankSuccess] = useState(false);

    useEffect(() => {
        const fetchPayments = async () => {
            try {
                const token = localStorage.getItem('adminToken');
                const res = await axios.get(`${getBaseUrl()}/api/admin/payments`, {
                    headers: { Authorization: `Bearer ${token}` }
                });
                setPayments(res.data);

                const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
                const last7Days = [...Array(7)].map((_, i) => {
                    const d = new Date();
                    d.setDate(d.getDate() - (6 - i));
                    return { name: days[d.getDay()], amount: 0, rawDate: d };
                });

                res.data.forEach((p: Payment) => {
                    const pDate = new Date(p.date);
                    const dayMatch = last7Days.find(d =>
                        d.rawDate.getDate() === pDate.getDate() &&
                        d.rawDate.getMonth() === pDate.getMonth() &&
                        d.rawDate.getFullYear() === pDate.getFullYear()
                    );
                    if (dayMatch) dayMatch.amount += p.amount;
                });
                setRealChartData(last7Days);
            } catch (err) {
                console.error(err);
            } finally {
                setLoading(false);
            }
        };

        const fetchBankSettings = async () => {
            try {
                const token = localStorage.getItem('adminToken');
                const res = await axios.get(`${getBaseUrl()}/api/admin/bank-settings`, {
                    headers: { Authorization: `Bearer ${token}` }
                });
                setBankData(res.data);
            } catch (err) {
                console.error('Failed to load bank settings:', err);
            }
        };

        fetchPayments();
        fetchBankSettings();
    }, []);

    const handleSaveBank = async () => {
        setBankSaving(true);
        try {
            const token = localStorage.getItem('adminToken');
            await axios.post(`${getBaseUrl()}/api/admin/bank-settings`, bankData, {
                headers: { Authorization: `Bearer ${token}` }
            });
            setBankEditing(false);
            setBankSuccess(true);
            setTimeout(() => setBankSuccess(false), 3000);
        } catch (err) {
            console.error('Failed to save bank settings:', err);
        } finally {
            setBankSaving(false);
        }
    };

    return (
        <div className="space-y-8 max-w-[1600px] mx-auto pt-6">
            <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
                <div>
                    <h2 className="text-3xl font-bold text-white tracking-tight">Payments & Transactions</h2>
                    <p className="text-slate-400 mt-1">Monitor revenue streams and financial data</p>
                </div>
                <button className="flex items-center gap-2 px-4 py-2 rounded-xl bg-white/5 border border-white/10 text-slate-300 hover:text-white hover:bg-white/10 transition-all">
                    <Download size={18} />
                    <span className="font-medium">Export Report</span>
                </button>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                <div className="glass-panel p-6 rounded-2xl relative overflow-hidden group hover:-translate-y-1 transition-transform duration-300">
                    <div className="absolute top-0 right-0 w-32 h-32 bg-emerald-500/5 rounded-bl-full -mr-10 -mt-10 transition-transform group-hover:scale-110 duration-500" />
                    <div className="relative z-10 flex justify-between items-start">
                        <div>
                            <p className="text-slate-400 text-sm font-medium uppercase tracking-wider">Total Revenue</p>
                            <h3 className="text-3xl font-bold text-white mt-1">
                                ${payments.reduce((acc, curr) => acc + curr.amount, 0).toFixed(2)}
                            </h3>
                        </div>
                        <div className="w-12 h-12 rounded-xl bg-emerald-500/10 flex items-center justify-center text-emerald-400 ring-1 ring-emerald-500/20">
                            <DollarSign size={24} />
                        </div>
                    </div>
                    <div className="flex items-center gap-2 mt-4">
                        <span className="flex items-center text-emerald-400 text-sm font-bold bg-emerald-500/10 px-2 py-1 rounded-lg border border-emerald-500/20">
                            <ArrowUpRight size={14} className="mr-1" />
                            +12.5%
                        </span>
                        <span className="text-slate-500 text-xs">vs last month</span>
                    </div>
                </div>

                <div className="glass-panel p-6 rounded-2xl relative overflow-hidden group hover:-translate-y-1 transition-transform duration-300">
                    <div className="absolute top-0 right-0 w-32 h-32 bg-blue-500/5 rounded-bl-full -mr-10 -mt-10 transition-transform group-hover:scale-110 duration-500" />
                    <div className="relative z-10 flex justify-between items-start">
                        <div>
                            <p className="text-slate-400 text-sm font-medium uppercase tracking-wider">Transactions</p>
                            <h3 className="text-3xl font-bold text-white mt-1">{payments.length}</h3>
                        </div>
                        <div className="w-12 h-12 rounded-xl bg-blue-500/10 flex items-center justify-center text-blue-400 ring-1 ring-blue-500/20">
                            <Activity size={24} />
                        </div>
                    </div>
                    <div className="flex items-center gap-2 mt-4">
                        <span className="flex items-center text-blue-400 text-sm font-bold bg-blue-500/10 px-2 py-1 rounded-lg border border-blue-500/20">
                            <TrendingUp size={14} className="mr-1" />
                            +8.2%
                        </span>
                        <span className="text-slate-500 text-xs">vs last month</span>
                    </div>
                </div>

                <div className="glass-panel p-6 rounded-2xl relative overflow-hidden group hover:-translate-y-1 transition-transform duration-300">
                    <div className="absolute top-0 right-0 w-32 h-32 bg-purple-500/5 rounded-bl-full -mr-10 -mt-10 transition-transform group-hover:scale-110 duration-500" />
                    <div className="relative z-10 flex justify-between items-start">
                        <div>
                            <p className="text-slate-400 text-sm font-medium uppercase tracking-wider">Avg. Order Value</p>
                            <h3 className="text-3xl font-bold text-white mt-1">
                                ${payments.length > 0 ? (payments.reduce((acc, curr) => acc + curr.amount, 0) / payments.length).toFixed(2) : '0.00'}
                            </h3>
                        </div>
                        <div className="w-12 h-12 rounded-xl bg-purple-500/10 flex items-center justify-center text-purple-400 ring-1 ring-purple-500/20">
                            <Wallet size={24} />
                        </div>
                    </div>
                    <div className="flex items-center gap-2 mt-4">
                        <span className="flex items-center text-rose-400 text-sm font-bold bg-rose-500/10 px-2 py-1 rounded-lg border border-rose-500/20">
                            <ArrowDownRight size={14} className="mr-1" />
                            -2.4%
                        </span>
                        <span className="text-slate-500 text-xs">vs last month</span>
                    </div>
                </div>
            </div>

            {/* Charts Area */}
            <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
                <div className="lg:col-span-2 glass-panel p-6 rounded-2xl">
                    <div className="flex items-center justify-between mb-6">
                        <h3 className="text-lg font-bold text-white">Revenue Overview</h3>
                        <div className="flex items-center gap-2">
                            <span className="w-3 h-3 rounded-full bg-blue-500"></span>
                            <span className="text-xs text-slate-400">Income</span>
                        </div>
                    </div>
                    <div className="h-[300px]">
                        <ResponsiveContainer width="100%" height="100%">
                            <BarChart data={realChartData} barSize={40}>
                                <CartesianGrid strokeDasharray="3 3" stroke="#334155" vertical={false} />
                                <XAxis
                                    dataKey="name"
                                    stroke="#94a3b8"
                                    axisLine={false}
                                    tickLine={false}
                                    dy={10}
                                    tick={{ fontSize: 12, fill: '#94a3b8' }}
                                />
                                <YAxis
                                    stroke="#94a3b8"
                                    axisLine={false}
                                    tickLine={false}
                                    tickFormatter={(value: any) => `$${value}`}
                                    tick={{ fontSize: 12, fill: '#94a3b8' }}
                                />
                                <Tooltip
                                    cursor={{ fill: 'rgba(255,255,255,0.05)' }}
                                    contentStyle={{
                                        backgroundColor: '#1e293b',
                                        borderColor: '#334155',
                                        borderRadius: '12px',
                                        color: '#f8fafc',
                                        boxShadow: '0 4px 6px -1px rgba(0, 0, 0, 0.5)'
                                    }}
                                    itemStyle={{ color: '#f8fafc' }}
                                />
                                <Bar dataKey="amount" radius={[8, 8, 8, 8]}>
                                    {realChartData.map((_: any, index: number) => (
                                        <Cell
                                            key={`cell-${index}`}
                                            fill="#3b82f6"
                                            fillOpacity={0.8}
                                            className="hover:fill-opacity-100 transition-all cursor-pointer"
                                        />
                                    ))}
                                </Bar>
                            </BarChart>
                        </ResponsiveContainer>
                    </div>
                </div>

                <div className="glass-panel p-6 rounded-2xl">
                    <div className="flex items-center justify-between mb-6">
                        <h3 className="text-lg font-bold text-white flex items-center gap-2">
                            <Wallet size={20} className="text-emerald-400" />
                            Bank Account
                        </h3>
                        <button
                            onClick={() => {
                                if (bankEditing) handleSaveBank();
                                else setBankEditing(true);
                            }}
                            className={`px-3 py-1.5 rounded-lg text-xs font-bold transition-all ${bankEditing
                                ? 'bg-emerald-500/20 text-emerald-400 border border-emerald-500/30 hover:bg-emerald-500/30'
                                : 'bg-white/5 text-slate-300 border border-white/10 hover:bg-white/10'
                                }`}
                        >
                            {bankSaving ? 'Saving...' : bankEditing ? '✓ Save' : 'Edit'}
                        </button>
                    </div>

                    <div className="space-y-3">
                        {[
                            { key: 'bankName', label: 'Bank Name', icon: '🏦', placeholder: 'e.g. Bank of Ceylon' },
                            { key: 'accountHolder', label: 'Account Holder', icon: '👤', placeholder: 'e.g. John Doe' },
                            { key: 'accountNumber', label: 'Account Number', icon: '🔢', placeholder: 'e.g. 1234567890' },
                            { key: 'branch', label: 'Branch', icon: '📍', placeholder: 'e.g. Colombo Main' },
                            { key: 'swiftCode', label: 'SWIFT / IFSC', icon: '🌐', placeholder: 'e.g. BCEYLKLX' },
                        ].map((field) => (
                            <div key={field.key}>
                                <label className="text-[10px] font-bold text-slate-400 uppercase tracking-wider mb-1 block">
                                    {field.icon} {field.label}
                                </label>
                                {bankEditing ? (
                                    <input
                                        type="text"
                                        value={(bankData as any)[field.key] || ''}
                                        onChange={(e) => setBankData({ ...bankData, [field.key]: e.target.value })}
                                        placeholder={field.placeholder}
                                        className="w-full bg-white/[0.03] border border-white/[0.08] rounded-xl px-3 py-2.5 text-white text-sm focus:outline-none focus:border-blue-500/50 placeholder-slate-600"
                                    />
                                ) : (
                                    <div className="bg-white/[0.02] border border-white/[0.05] rounded-xl px-3 py-2.5 text-sm">
                                        <span className={`${(bankData as any)[field.key] ? 'text-white' : 'text-slate-600 italic'}`}>
                                            {(bankData as any)[field.key] || 'Not set'}
                                        </span>
                                    </div>
                                )}
                            </div>
                        ))}
                    </div>

                    {bankData.updatedAt && (
                        <div className="mt-4 text-[10px] text-slate-500">
                            Last updated: {new Date(bankData.updatedAt).toLocaleString()}
                        </div>
                    )}

                    {bankSuccess && (
                        <div className="mt-3 p-2.5 rounded-lg bg-emerald-500/10 border border-emerald-500/20 text-emerald-400 text-xs font-medium flex items-center gap-2">
                            <CheckCircle2 size={14} /> Bank details saved successfully
                        </div>
                    )}
                </div>
            </div>

            <div className="glass-panel rounded-xl overflow-hidden">
                <div className="p-6 border-b border-white/5 flex justify-between items-center">
                    <h3 className="font-bold text-white">Recent Transactions</h3>
                    <button className="text-xs font-bold text-blue-400 hover:text-blue-300 transition-colors">View All</button>
                </div>
                <table className="w-full text-left">
                    <thead>
                        <tr className="bg-white/5">
                            <th className="p-5 font-semibold text-slate-400 text-xs uppercase tracking-wider">User</th>
                            <th className="p-5 font-semibold text-slate-400 text-xs uppercase tracking-wider">Plan</th>
                            <th className="p-5 font-semibold text-slate-400 text-xs uppercase tracking-wider">Amount</th>
                            <th className="p-5 font-semibold text-slate-400 text-xs uppercase tracking-wider">Status</th>
                            <th className="p-5 font-semibold text-slate-400 text-xs uppercase tracking-wider">Transaction ID</th>
                            <th className="p-5 font-semibold text-slate-400 text-xs uppercase tracking-wider">Date</th>
                        </tr>
                    </thead>
                    <tbody className="divide-y divide-white/5">
                        {loading ? (
                            <tr>
                                <td colSpan={6} className="p-12 text-center text-slate-500 animate-pulse">
                                    <div className="flex flex-col items-center justify-center gap-2">
                                        <div className="w-8 h-8 border-2 border-white/10 border-t-emerald-500 rounded-full animate-spin"></div>
                                        <span>Loading payments...</span>
                                    </div>
                                </td>
                            </tr>
                        ) : payments.length === 0 ? (
                            <tr><td colSpan={6} className="p-8 text-center text-slate-500">No payments found</td></tr>
                        ) : (
                            payments.map((payment, index) => (
                                <motion.tr
                                    key={payment._id}
                                    initial={{ opacity: 0, y: 10 }}
                                    animate={{ opacity: 1, y: 0 }}
                                    transition={{ delay: index * 0.05 }}
                                    className="hover:bg-white/5 transition-colors group"
                                >
                                    <td className="p-5">
                                        <div className="font-medium text-white">{payment.user?.name || 'Unknown'}</div>
                                        <div className="text-xs text-slate-400">{payment.user?.email}</div>
                                    </td>
                                    <td className="p-5 text-sm text-slate-300">
                                        {payment.plan || 'Pro Monthly'}
                                    </td>
                                    <td className="p-5 font-mono font-bold text-emerald-400">${payment.amount.toFixed(2)}</td>
                                    <td className="p-5">
                                        <div className="flex items-center gap-2">
                                            {payment.status === 'completed' && <CheckCircle2 size={14} className="text-emerald-400" />}
                                            <span className={`px-2.5 py-0.5 rounded-full text-xs font-bold capitalize border ${payment.status === 'completed'
                                                ? 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20'
                                                : 'bg-yellow-500/10 text-yellow-400 border-yellow-500/20'
                                                }`}>
                                                {payment.status}
                                            </span>
                                        </div>
                                    </td>
                                    <td className="p-5">
                                        <span className="text-xs font-mono text-slate-400 bg-white/5 px-2 py-1 rounded select-all">
                                            {payment.transactionId || 'N/A'}
                                        </span>
                                    </td>
                                    <td className="p-5 text-slate-400 text-sm">
                                        <div className="flex items-center gap-2">
                                            <Calendar size={14} />
                                            {new Date(payment.date).toLocaleDateString()}
                                        </div>
                                    </td>
                                </motion.tr>
                            ))
                        )}
                    </tbody>
                </table>
            </div>
        </div>
    );
}

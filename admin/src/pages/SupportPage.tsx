import { useEffect, useState, useRef } from 'react';
import axios from 'axios';
import { MessageSquare, Send, Search, Clock, MoreHorizontal, CheckCircle2, Shield } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { getBaseUrl } from '../utils/api';

import { SupportTicket, TicketReply } from '../types';

export default function SupportPage() {
    const [tickets, setTickets] = useState<SupportTicket[]>([]);
    const [loading, setLoading] = useState(true);
    const [selectedTicket, setSelectedTicket] = useState<SupportTicket | null>(null);
    const [reply, setReply] = useState("");
    const [searchTerm, setSearchTerm] = useState("");
    const [sending, setSending] = useState(false);
    const messagesEndRef = useRef<HTMLDivElement>(null);


    const fetchTickets = async () => {
        try {
            const token = localStorage.getItem('adminToken');
            const res = await axios.get(`${getBaseUrl()}/api/admin/tickets`, {
                headers: { Authorization: `Bearer ${token}` }
            });
            setTickets(res.data);
        } catch (err) {
            console.error(err);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        fetchTickets();
    }, []);

    useEffect(() => {
        scrollToBottom();
    }, [selectedTicket, selectedTicket?.replies]);

    const scrollToBottom = () => {
        messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
    };

    const handleReply = async () => {
        if (!reply.trim() || !selectedTicket) return;
        setSending(true);

        try {
            const token = localStorage.getItem('adminToken');
            await axios.post(`${getBaseUrl()}/api/admin/tickets/${selectedTicket._id}/reply`,
                { message: reply },
                { headers: { Authorization: `Bearer ${token}` } }
            );

            const newReply: TicketReply = { sender: 'admin', message: reply, date: new Date().toISOString() };

            setSelectedTicket((prev) => prev ? ({
                ...prev,
                replies: [...prev.replies, newReply]
            }) : null);

            // Also update the ticket in the list
            setTickets(prev => prev.map(t =>
                t._id === selectedTicket._id
                    ? { ...t, replies: [...t.replies, newReply] }
                    : t
            ));

            setReply("");
            setTimeout(scrollToBottom, 100);

        } catch (err) {
            alert("Failed to send reply");
        } finally {
            setSending(false);
        }
    };

    const handleStatusUpdate = async (newStatus: 'open' | 'closed' | 'pending') => {
        if (!selectedTicket) return;
        try {
            const token = localStorage.getItem('adminToken');
            await axios.patch(`${getBaseUrl()}/api/admin/tickets/${selectedTicket._id}/status`,
                { status: newStatus },
                { headers: { Authorization: `Bearer ${token}` } }
            );

            setSelectedTicket((prev) => prev ? ({ ...prev, status: newStatus }) : null);
            setTickets(prev => prev.map(t =>
                t._id === selectedTicket._id ? { ...t, status: newStatus } : t
            ));
        } catch (err) {
            alert("Failed to update ticket status");
        }
    };

    const filteredTickets = tickets.filter(t =>
        t.subject.toLowerCase().includes(searchTerm.toLowerCase()) ||
        t.user?.email.toLowerCase().includes(searchTerm.toLowerCase())
    );

    return (
        <div className="flex flex-col h-[calc(100vh-100px)] gap-6 pt-6">
            <header className="flex-shrink-0">
                <h2 className="text-3xl font-bold text-white">Support Center</h2>
                <p className="text-slate-400">Manage support tickets and inquiries</p>
            </header>

            <div className="flex-1 glass-panel rounded-2xl border border-white/10 overflow-hidden flex shadow-2xl">
                {/* Sidebar List */}
                <div className="w-80 border-r border-white/5 flex flex-col bg-slate-900/40">
                    <div className="p-4 border-b border-white/5">
                        <div className="relative">
                            <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-500" size={16} />
                            <input
                                type="text"
                                placeholder="Search tickets..."
                                value={searchTerm}
                                onChange={(e) => setSearchTerm(e.target.value)}
                                className="w-full bg-black/20 border border-white/5 rounded-xl pl-9 pr-4 py-2.5 text-sm text-white focus:outline-none focus:border-blue-500/50 transition-colors placeholder:text-slate-600"
                            />
                        </div>
                    </div>

                    <div className="flex-1 overflow-y-auto custom-scrollbar">
                        {loading ? (
                            <div className="p-8 text-center text-slate-500 text-sm animate-pulse">Loading tickets...</div>
                        ) : filteredTickets.length === 0 ? (
                            <div className="p-8 text-center text-slate-500 text-sm">No tickets found</div>
                        ) : (
                            filteredTickets.map((ticket) => (
                                <motion.div
                                    key={ticket._id}
                                    initial={{ opacity: 0, x: -10 }}
                                    animate={{ opacity: 1, x: 0 }}
                                    onClick={() => setSelectedTicket(ticket)}
                                    className={`p-4 border-b border-white/5 cursor-pointer transition-all hover:bg-white/5 ${selectedTicket?._id === ticket._id ? 'bg-blue-600/10 border-l-2 border-l-blue-500' : 'border-l-2 border-l-transparent'
                                        }`}
                                >
                                    <div className="flex justify-between mb-1.5">
                                        <div className="flex items-center gap-2">
                                            {ticket.status === 'open' ? (
                                                <span className="w-2 h-2 rounded-full bg-emerald-500 shadow-[0_0_8px_rgba(16,185,129,0.5)]"></span>
                                            ) : (
                                                <span className="w-2 h-2 rounded-full bg-slate-500"></span>
                                            )}
                                            <span className={`text-[10px] uppercase font-bold tracking-wider ${ticket.status === 'open' ? 'text-emerald-400' : 'text-slate-400'}`}>
                                                {ticket.status}
                                            </span>
                                        </div>
                                        <span className="text-[10px] text-slate-500 font-mono">{new Date(ticket.createdAt).toLocaleDateString()}</span>
                                    </div>
                                    <h4 className={`text-sm font-semibold mb-1 truncate ${selectedTicket?._id === ticket._id ? 'text-blue-200' : 'text-slate-200'}`}>
                                        {ticket.subject}
                                    </h4>
                                    <p className="text-xs text-slate-400 truncate line-clamp-1 opacity-70">{ticket.message}</p>
                                </motion.div>
                            ))
                        )}
                    </div>
                </div>

                {/* Main Chat Area */}
                <div className="flex-1 flex flex-col bg-slate-900/50 relative">
                    {/* Background Pattern */}
                    <div className="absolute inset-0 opacity-[0.03] pointer-events-none"
                        style={{ backgroundImage: 'radial-gradient(circle at 2px 2px, white 1px, transparent 0)', backgroundSize: '32px 32px' }}
                    ></div>

                    {selectedTicket ? (
                        <>
                            {/* Chat Header */}
                            <div className="p-4 border-b border-white/5 bg-slate-900/80 backdrop-blur-md flex items-center justify-between z-10 shadow-sm">
                                <div className="flex items-center gap-4">
                                    <div className="w-10 h-10 rounded-full bg-gradient-to-tr from-blue-500 to-cyan-500 flex items-center justify-center text-white font-bold text-lg shadow-lg ring-2 ring-white/10">
                                        {selectedTicket.user?.name?.charAt(0)}
                                    </div>
                                    <div>
                                        <h3 className="font-bold text-white text-lg leading-tight">{selectedTicket.subject}</h3>
                                        <div className="flex items-center gap-2 text-xs text-slate-400 mt-0.5">
                                            <span>{selectedTicket.user?.email}</span>
                                            <span className="w-1 h-1 rounded-full bg-slate-600"></span>
                                            <span className="flex items-center gap-1"><Clock size={10} /> {new Date(selectedTicket.createdAt).toLocaleTimeString()}</span>
                                        </div>
                                    </div>
                                </div>
                                <div className="flex items-center gap-3">
                                    <button
                                        onClick={() => handleStatusUpdate(selectedTicket.status === 'open' ? 'closed' : 'open')}
                                        className={`px-4 py-2 rounded-xl border text-sm font-bold transition-all flex items-center gap-2 ${selectedTicket.status === 'open'
                                            ? 'bg-emerald-500/10 border-emerald-500/20 text-emerald-400 hover:bg-emerald-500 hover:text-white shadow-lg shadow-emerald-500/10'
                                            : 'bg-blue-500/10 border-blue-500/20 text-blue-400 hover:bg-blue-500 hover:text-white shadow-lg shadow-blue-500/10'
                                            }`}
                                    >
                                        <CheckCircle2 size={16} />
                                        {selectedTicket.status === 'open' ? 'Resolve Ticket' : 'Reopen Ticket'}
                                    </button>
                                    <button className="p-2 rounded-lg hover:bg-white/5 text-slate-400 hover:text-white transition-colors">
                                        <MoreHorizontal size={20} />
                                    </button>
                                </div>
                            </div>

                            {/* Chat Messages */}
                            <div className="flex-1 overflow-y-auto p-6 space-y-6 scroll-smooth custom-scrollbar">
                                {/* Original Ticket Message */}
                                <div className="flex gap-4">
                                    <div className="w-8 h-8 rounded-full bg-slate-800 border border-slate-700 flex-shrink-0 flex items-center justify-center text-xs font-bold text-slate-300 mt-1 shadow-sm">
                                        {selectedTicket.user?.name?.charAt(0)}
                                    </div>
                                    <div className="bg-slate-800/80 border border-white/5 p-4 rounded-2xl rounded-tl-none max-w-[80%] shadow-lg">
                                        <p className="text-slate-200 text-sm whitespace-pre-wrap leading-relaxed">{selectedTicket.message}</p>
                                        <div className="text-[10px] text-slate-500 mt-2 text-right">{new Date(selectedTicket.createdAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</div>
                                    </div>
                                </div>

                                {/* Replies */}
                                <AnimatePresence>
                                    {selectedTicket.replies.map((r: any, i: number) => (
                                        <motion.div
                                            key={i}
                                            initial={{ opacity: 0, y: 10, scale: 0.95 }}
                                            animate={{ opacity: 1, y: 0, scale: 1 }}
                                            className={`flex gap-4 ${r.sender === 'admin' ? 'flex-row-reverse' : ''}`}
                                        >
                                            <div className={`w-8 h-8 rounded-full flex-shrink-0 flex items-center justify-center text-xs font-bold mt-1 shadow-lg ring-2 ring-white/5 ${r.sender === 'admin' ? 'bg-blue-600 text-white' : 'bg-slate-800 border border-slate-700 text-slate-300'
                                                }`}>
                                                {r.sender === 'admin' ? <Shield size={14} /> : 'U'}
                                            </div>
                                            <div className={`p-4 rounded-2xl max-w-[80%] shadow-lg backdrop-blur-sm ${r.sender === 'admin'
                                                ? 'bg-gradient-to-br from-blue-600 to-blue-700 text-white rounded-tr-none border border-blue-500/50'
                                                : 'bg-slate-800/80 border border-white/5 text-slate-200 rounded-tl-none'
                                                }`}>
                                                <p className="text-sm whitespace-pre-wrap leading-relaxed font-medium">{r.message}</p>
                                                <div className={`text-[10px] mt-2 text-right flex items-center justify-end gap-1 ${r.sender === 'admin' ? 'text-blue-200/70' : 'text-slate-500'}`}>
                                                    {new Date(r.date).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                                                    {r.sender === 'admin' && <CheckCircle2 size={10} />}
                                                </div>
                                            </div>
                                        </motion.div>
                                    ))}
                                </AnimatePresence>
                                <div ref={messagesEndRef} />
                            </div>

                            {/* Reply Input */}
                            <div className="p-4 bg-slate-900/80 backdrop-blur-md border-t border-white/5">
                                <div className="flex gap-3 bg-black/20 p-2 pr-2 pl-4 rounded-2xl border border-white/5 focus-within:border-blue-500/50 focus-within:ring-1 focus-within:ring-blue-500/20 transition-all shadow-inner">
                                    <input
                                        type="text"
                                        value={reply}
                                        onChange={(e) => setReply(e.target.value)}
                                        placeholder="Type your reply here..."
                                        className="flex-1 bg-transparent text-white focus:outline-none placeholder:text-slate-600 font-normal"
                                        onKeyDown={(e) => e.key === 'Enter' && !sending && handleReply()}
                                        disabled={sending}
                                    />
                                    <button
                                        onClick={handleReply}
                                        disabled={!reply.trim() || sending}
                                        className="bg-blue-600 hover:bg-blue-500 disabled:opacity-50 disabled:hover:bg-blue-600 text-white p-3 rounded-xl transition-all shadow-lg shadow-blue-500/20 hover:scale-105 active:scale-95 flex items-center justify-center min-w-[44px]"
                                    >
                                        {sending ? (
                                            <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                                        ) : (
                                            <Send size={18} />
                                        )}
                                    </button>
                                </div>
                            </div>
                        </>
                    ) : (
                        <div className="flex-1 flex flex-col items-center justify-center text-slate-500">
                            <motion.div
                                initial={{ scale: 0.8, opacity: 0 }}
                                animate={{ scale: 1, opacity: 1 }}
                                transition={{ duration: 0.5 }}
                                className="w-24 h-24 rounded-full bg-slate-800/50 flex items-center justify-center mb-6 ring-4 ring-slate-800/30"
                            >
                                <MessageSquare size={48} className="opacity-40" />
                            </motion.div>
                            <h3 className="text-xl font-bold text-slate-400 mb-2">No Ticket Selected</h3>
                            <p className="text-slate-600 max-w-xs text-center">Select a ticket from the sidebar to view the conversation details and reply.</p>
                        </div>
                    )}
                </div>
            </div>
        </div>
    );
}

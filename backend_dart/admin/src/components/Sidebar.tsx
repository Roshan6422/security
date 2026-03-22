import React from 'react';
import { NavLink } from 'react-router-dom';
import { LayoutDashboard, Users, CreditCard, HelpCircle, Shield, LogOut, Activity } from 'lucide-react';

const Sidebar = () => {
    return (
        <div className="h-screen w-64 bg-slate-900/50 backdrop-blur-xl border-r border-white/10 flex flex-col fixed left-0 top-0 overflow-y-auto z-50">
            <div className="p-6 flex items-center gap-3">
                <div className="w-8 h-8 rounded-lg bg-gradient-to-tr from-blue-600 to-violet-600 flex items-center justify-center text-white font-bold text-xl shadow-lg shadow-blue-500/20">
                    S
                </div>
                <span className="text-xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-white to-slate-400">SafeShell</span>
            </div>

            <div className="flex-1 px-4 py-4 space-y-8">
                <nav className="space-y-1">
                    <NavItem to="/dashboard" icon={<LayoutDashboard size={20} />} label="Overview" />
                    <NavItem to="/users" icon={<Users size={20} />} label="Users" />
                    <NavItem to="/payments" icon={<CreditCard size={20} />} label="Payments" />
                    <NavItem to="/support" icon={<HelpCircle size={20} />} label="Support" />
                    <NavItem to="/profile" icon={<Shield size={20} />} label="My Account" />
                </nav>

                <div className="pt-4 border-t border-white/5">
                    <nav className="space-y-1">
                        <NavItem to="/health" icon={<Activity size={20} />} label="System Health" />
                        <NavItem to="/logs" icon={<Shield size={20} />} label="Security Logs" />
                    </nav>
                </div>
            </div>

            <div className="p-4 border-t border-white/5">
                <button
                    onClick={() => {
                        localStorage.removeItem('adminToken');
                        window.location.href = '/login';
                    }}
                    className="flex items-center gap-3 w-full px-4 py-3 text-slate-400 hover:bg-white/5 hover:text-white rounded-lg transition-all group font-medium text-sm"
                >
                    <LogOut size={18} />
                    Sign Out
                </button>
            </div>
        </div>
    );
};

const NavItem = ({ to, icon, label }: { to: string; icon: React.ReactNode; label: string }) => (
    <NavLink
        to={to}
        className={({ isActive }) =>
            `flex items-center gap-3 px-4 py-3 rounded-lg transition-all duration-200 ${isActive
                ? 'bg-blue-600/10 text-blue-400 border border-blue-600/20 shadow-lg shadow-blue-900/20'
                : 'text-slate-400 hover:text-white hover:bg-white/5'
            }`
        }
    >
        <span className="flex items-center gap-3 font-medium text-sm">
            {icon}
            {label}
        </span>
    </NavLink>
);

export default Sidebar;

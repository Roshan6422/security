
import { BrowserRouter, Routes, Route, Navigate, Outlet, useLocation } from 'react-router-dom';
import { useState } from 'react';
import { AnimatePresence } from 'framer-motion';

// Components
import Sidebar from './components/Sidebar';

// Pages
import LandingPage from './pages/LandingPage';
import Login from './pages/Login';
import Register from './pages/Register';
import ForgotPassword from './pages/ForgotPassword';
import PromotePage from './pages/PromotePage';
import UsersPage from './pages/UsersPage';
import PaymentsPage from './pages/PaymentsPage';
import SupportPage from './pages/SupportPage';
import ProfilePage from './pages/ProfilePage';
import OverviewPage from './pages/OverviewPage';
import HealthPage from './pages/HealthPage';
import LogsPage from './pages/LogsPage';

function AdminLayout() {
    const [token] = useState(localStorage.getItem('adminToken'));
    const location = useLocation();

    if (!token) return <Navigate to="/login" replace />;

    return (
        <div className="flex h-screen bg-slate-950 text-slate-100 overflow-hidden font-sans selection:bg-blue-500/30">
            <Sidebar />
            <main className="flex-1 ml-64 p-8 overflow-y-auto h-full relative">
                <AnimatePresence mode="wait">
                    <Outlet key={location.pathname} />
                </AnimatePresence>
            </main>
        </div>
    );
}

export default function App() {
    return (
        <BrowserRouter>
            <Routes>
                {/* Public Routes */}
                <Route path="/" element={<LandingPage />} />
                <Route path="/login" element={<Login />} />
                <Route path="/register" element={<Register />} />
                <Route path="/forgot-password" element={<ForgotPassword />} />
                <Route path="/promote" element={<PromotePage />} />

                {/* Protected Admin Routes */}
                <Route element={<AdminLayout />}>
                    <Route path="/dashboard" element={<OverviewPage />} />
                    <Route path="/users" element={<UsersPage />} />
                    <Route path="/payments" element={<PaymentsPage />} />
                    <Route path="/support" element={<SupportPage />} />
                    <Route path="/profile" element={<ProfilePage />} />
                    <Route path="/health" element={<HealthPage />} />
                    <Route path="/logs" element={<LogsPage />} />
                </Route>
            </Routes>
        </BrowserRouter>
    );
}

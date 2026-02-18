export const getBaseUrl = () => {
    // If using Vite proxy, we can just use relative path /api
    // But for direct URL usage:
    const apiUrl = import.meta.env.VITE_API_URL;
    if (apiUrl) return apiUrl;

    const isLocal = window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1';

    // Updated for local IP connectivity
    if (isLocal) return "http://localhost:8000";

    // Fallback or explicit IP
    return "http://localhost:8000";
};

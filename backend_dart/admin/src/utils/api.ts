export const getBaseUrl = () => {
    if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
        return 'http://localhost:8000';
    }
    return "https://fair-madelin-safeshellmobile-5ea64b9b.koyeb.app";
};

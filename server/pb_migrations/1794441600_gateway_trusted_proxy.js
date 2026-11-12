// Public gateway binds only to loopback and overwrites X-Real-IP.
// Tailscale overwrites X-Forwarded-For before the gateway reads it.
migrate((app) => {
    const settings = app.settings();
    const headers = settings.trustedProxy.headers || [];
    if (headers.length !== 0 && JSON.stringify(headers) !== '["X-Real-IP"]') {
        throw new Error("Review existing trusted proxy headers before enabling the PACE gateway.");
    }
    settings.trustedProxy.headers = ["X-Real-IP"];
    settings.trustedProxy.useLeftmostIP = false;
    app.save(settings);
}, (app) => {
    const settings = app.settings();
    if (JSON.stringify(settings.trustedProxy.headers) === '["X-Real-IP"]') {
        settings.trustedProxy.headers = [];
        app.save(settings);
    }
});

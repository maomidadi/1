const SERVER_URL = 'http://localhost:8080/';
const SCRIPT_PATH = 'sh /storage/emulated/0/performance-ai/start.sh --ext_setup';

const ASSETS_TO_PRELOAD = [
    'styles.css',
    'script.js',
    'assets/fonts/Rajdhani-Bold.woff2',
    'assets/fonts/Rajdhani-Medium.woff2',
    'assets/fonts/Inter-Regular.woff2',
    'img/running.webp',
    'img/stopped.webp'
];

let progressContainer, progressBar, statusText;

const executeRootCommand = async (cmd) => {
    try {
        const { exec } = await import('ax://kernelsu.js');
        return await exec(cmd);
    } catch (e) {
        try {
             const { exec } = await import('https://cdn.jsdelivr.net/npm/kernelsu@1.0.6/+esm');
             return await exec(cmd);
        } catch (err) {
             throw new Error("Gagal Akses Root: " + e.message);
        }
    }
};

const checkServer = async () => {
    try {
        const ctrl = new AbortController();
        setTimeout(() => ctrl.abort(), 300);
        await fetch(SERVER_URL, { method: 'HEAD', mode: 'cors', signal: ctrl.signal });
        return true;
    } catch { return false; }
};

const startServer = async () => {
    if (statusText) statusText.textContent = "Menjalankan Service...";
    const { errno, stderr } = await executeRootCommand(SCRIPT_PATH);
    if (errno !== 0) throw new Error(stderr || `Exit code ${errno}`);
};

const preloadAssets = async () => {
    if (statusText) statusText.textContent = "Memperbarui UI...";
    if (progressContainer) progressContainer.style.display = 'block';
    
    let loadedCount = 0;
    const total = ASSETS_TO_PRELOAD.length;

    const promises = ASSETS_TO_PRELOAD.map(async (file) => {
        try {
            await fetch(`${SERVER_URL}${file}`, { 
                mode: 'cors', 
                cache: 'reload' 
            });
        } catch (e) { 
            console.warn(`Gagal memuat aset: ${file}`, e); 
        } finally {
            loadedCount++;
            if (progressBar) progressBar.style.width = `${Math.round((loadedCount / total) * 100)}%`;
        }
    });

    await Promise.all(promises);
    
    if (progressBar) progressBar.style.width = '100%';
};

const initLauncher = async () => {
    progressContainer = document.getElementById('progressContainer');
    progressBar = document.getElementById('progressBar');
    statusText = document.getElementById('statusText');
    const mainContent = document.getElementById('mainContent');
    const msgDiv = document.getElementById('statusMessage');

    if (mainContent) mainContent.style.opacity = '1';

    try {
        let isServerUp = await checkServer();
        
        if (!isServerUp) {
            await startServer();
            if (statusText) statusText.textContent = "Menunggu Koneksi...";
            
            let retries = 50; 
            while (retries--) {
                if (await checkServer()) { isServerUp = true; break; }
                await new Promise(r => setTimeout(r, 200));
            }

            if (!isServerUp) {
                if (statusText) statusText.textContent = "Server Stuck? Memperbaiki...";
                try {
                    const { stdout } = await executeRootCommand('pidof -s server');
                    if (stdout && stdout.trim().length > 0) {
                        await executeRootCommand(`kill -9 ${stdout.trim()}`);
                    }
                } catch (ign) {}
                await startServer();
                let retryFinal = 30;
                while (retryFinal--) {
                    if (await checkServer()) { isServerUp = true; break; }
                    await new Promise(r => setTimeout(r, 200));
                }
            }

            if (!isServerUp) throw new Error('Server timeout. Gagal menjalankan daemon.');
        }

        await preloadAssets();
        window.location.replace(`${SERVER_URL}?t=${Date.now()}`);
        
    } catch (e) {
        if (progressContainer) progressContainer.style.display = 'none';
        if (statusText) statusText.textContent = "Gagal Memuat";
        if (msgDiv) {
            msgDiv.textContent = e.message;
            msgDiv.className = 'status error';
            msgDiv.style.display = 'block';
        }
    }
};

if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initLauncher);
} else {
    initLauncher();
}
// ====================================================================
// MOVY PERFORMANCE VISUALIZER - SYNTHWAVE EDITION
// ====================================================================

// Synthwave color scheme for charts
const COLORS = {
    cyan: 'rgba(0, 240, 255, 1)',
    cyanTransparent: 'rgba(0, 240, 255, 0.2)',
    magenta: 'rgba(255, 0, 255, 1)',
    magentaTransparent: 'rgba(255, 0, 255, 0.2)',
    purple: 'rgba(176, 38, 255, 1)',
    purpleTransparent: 'rgba(176, 38, 255, 0.2)',
    pink: 'rgba(255, 0, 110, 1)',
    pinkTransparent: 'rgba(255, 0, 110, 0.2)',
    yellow: 'rgba(255, 237, 78, 1)',
    yellowTransparent: 'rgba(255, 237, 78, 0.2)',
    grid: 'rgba(0, 240, 255, 0.15)',
    text: 'rgba(224, 224, 255, 0.9)'
};

// Store loaded benchmark data
let benchmarkData = {};
let embeddedData = {}; // Data embedded in HTML
let currentCharts = [];

// ====================================================================
// INITIALIZATION
// ====================================================================

document.addEventListener('DOMContentLoaded', () => {
    console.log('MOVY Visualizer loaded');

    // Load embedded benchmark data
    const dataElement = document.getElementById('benchmark-data');
    if (dataElement) {
        try {
            embeddedData = JSON.parse(dataElement.textContent);
            console.log('Loaded embedded data for', Object.keys(embeddedData).length, 'runs');
        } catch (e) {
            console.error('Failed to parse embedded data:', e);
        }
    } else {
        console.warn('No embedded benchmark data found');
    }

    // Add visual indicator that JS is working
    const indicator = document.createElement('div');
    indicator.style.cssText = 'position:fixed;top:10px;right:10px;background:#00f0ff;color:#0a0e27;padding:10px;border-radius:5px;font-family:Orbitron;z-index:10000;';
    indicator.textContent = '✓ JavaScript Loaded';
    document.body.appendChild(indicator);
    setTimeout(() => indicator.remove(), 3000);

    console.log('Initializing run selector...');
    initializeRunSelector();
    console.log('Setting up event listeners...');
    setupEventListeners();
    console.log('Loading available runs...');
    loadAvailableRuns();
    console.log('Initialization complete');
});

// ====================================================================
// RUN SELECTOR & DATA LOADING
// ====================================================================

function initializeRunSelector() {
    console.log('initializeRunSelector called');
    const selector = document.getElementById('run-selector');
    console.log('Selector element:', selector);

    const rows = document.querySelectorAll('.run-list tbody tr');
    console.log(`Found ${rows.length} rows`);

    rows.forEach((row, index) => {
        const date = row.dataset.date;
        const timestamp = row.dataset.timestamp;
        console.log(`Row ${index}: date=${date}, timestamp=${timestamp}`);
        const runKey = `${date}/${timestamp}`;

        const option = document.createElement('option');
        option.value = runKey;
        option.textContent = `${date} - ${timestamp}`;
        selector.appendChild(option);
        console.log(`Added option: ${runKey}`);
    });

    console.log(`Selector now has ${selector.options.length} options`);
}

function loadAvailableRuns() {
    const rows = document.querySelectorAll('.run-list tbody tr');

    rows.forEach(row => {
        const date = row.dataset.date;
        const timestamp = row.dataset.timestamp;
        const files = JSON.parse(row.dataset.files || '[]');

        const runKey = `${date}/${timestamp}`;
        benchmarkData[runKey] = {
            date,
            timestamp,
            files,
            loaded: false,
            data: {}
        };
    });
}

async function loadRunData(runKey) {
    console.log('loadRunData called for:', runKey);

    // Check if data is embedded
    if (embeddedData[runKey]) {
        console.log('Using embedded data for:', runKey);
        return embeddedData[runKey];
    }

    // Fallback to fetch (won't work with file:// but kept for http:// servers)
    if (!benchmarkData[runKey]) return null;
    if (benchmarkData[runKey].loaded) return benchmarkData[runKey].data;

    const run = benchmarkData[runKey];
    const data = {};

    for (const filename of run.files) {
        try {
            const response = await fetch(`${run.date}/${filename}`);
            const json = await response.json();
            data[json.test_name] = json;
        } catch (error) {
            console.error(`Failed to load ${filename}:`, error);
        }
    }

    benchmarkData[runKey].data = data;
    benchmarkData[runKey].loaded = true;

    return data;
}

// ====================================================================
// EVENT LISTENERS
// ====================================================================

function setupEventListeners() {
    const selector = document.getElementById('run-selector');
    selector.addEventListener('change', async (e) => {
        const runKey = e.target.value;
        if (!runKey) return;

        console.log('Loading data for run:', runKey);
        const data = await loadRunData(runKey);
        if (data) {
            console.log('Data loaded, rendering charts...');
            // Extract date and timestamp from runKey
            const [date, timestamp] = runKey.split('/');
            const runInfo = {
                date: date,
                timestamp: timestamp,
                files: benchmarkData[runKey] ? benchmarkData[runKey].files : []
            };
            renderCharts(data, runInfo);
        } else {
            console.error('No data loaded for run:', runKey);
        }
    });

    // Expand buttons in run list
    document.querySelectorAll('.btn-expand').forEach(btn => {
        btn.addEventListener('click', async (e) => {
            const row = e.target.closest('tr');
            const date = row.dataset.date;
            const timestamp = row.dataset.timestamp;
            const runKey = `${date}/${timestamp}`;

            const selector = document.getElementById('run-selector');
            selector.value = runKey;

            const data = await loadRunData(runKey);
            if (data) {
                const runInfo = {
                    date: date,
                    timestamp: timestamp,
                    files: benchmarkData[runKey] ? benchmarkData[runKey].files : []
                };
                renderCharts(data, runInfo);
                document.getElementById('charts').scrollIntoView({ behavior: 'smooth' });
            }
        });
    });
}

// ====================================================================
// CHART RENDERING
// ====================================================================

function clearCharts() {
    currentCharts.forEach(chart => chart.destroy());
    currentCharts = [];
}

function renderCharts(data, runInfo) {
    clearCharts();

    const container = document.getElementById('charts-container');
    container.innerHTML = '';

    // Header with system info
    const header = document.createElement('div');
    header.className = 'chart-header';
    header.innerHTML = `
        <h3 class="text-cyan glow-cyan">${runInfo.date} - ${runInfo.timestamp}</h3>
        ${Object.values(data)[0] ? `
            <p class="text-secondary">
                <span class="badge badge-cpu">${Object.values(data)[0].system_info.cpu_model}</span>
                <span class="badge badge-os">${Object.values(data)[0].system_info.os}</span>
                <span class="badge">${Object.values(data)[0].system_info.cpu_cores} cores</span>
                <span class="badge">${Object.values(data)[0].system_info.build_mode}</span>
            </p>
        ` : ''}
    `;
    container.appendChild(header);

    // Create charts for each test type
    if (data['RenderSurface.toAnsi']) {
        renderToAnsiCharts(container, data['RenderSurface.toAnsi']);
    }

    if (data['RenderEngine.render_stable']) {
        renderRenderStableCharts(container, data['RenderEngine.render_stable']);
    }

    if (data['RenderEngine.render_stable_with_toAnsi']) {
        renderCombinedCharts(container, data['RenderEngine.render_stable_with_toAnsi']);
    }

    // Comparison chart if we have multiple test types
    if (Object.keys(data).length > 1) {
        renderComparisonChart(container, data);
    }
}

// ====================================================================
// CHART: RenderSurface.toAnsi
// ====================================================================

function renderToAnsiCharts(container, testData) {
    const section = createChartSection(container, 'RenderSurface.toAnsi Performance', 'cyan');

    // Chart 1: Throughput vs Sprite Size
    const throughputCanvas = createCanvas(section, 'toAnsi-throughput');
    const ctx1 = throughputCanvas.getContext('2d');

    const labels = testData.results.map(r => r.name);
    const mpData = testData.results.map(r => r.megapixels_per_sec);

    currentCharts.push(new Chart(ctx1, {
        type: 'line',
        data: {
            labels,
            datasets: [{
                label: 'Megapixels/sec',
                data: mpData,
                borderColor: COLORS.cyan,
                backgroundColor: createGradient(ctx1, COLORS.cyan, COLORS.cyanTransparent),
                borderWidth: 3,
                pointRadius: 6,
                pointHoverRadius: 8,
                pointBackgroundColor: COLORS.cyan,
                pointBorderColor: '#0a0e27',
                pointBorderWidth: 2,
                tension: 0.4,
                fill: true
            }]
        },
        options: getSynthwaveChartOptions('Sprite Size', 'MP/sec')
    }));

    // Chart 2: Time per Iteration
    const timeCanvas = createCanvas(section, 'toAnsi-time');
    const ctx2 = timeCanvas.getContext('2d');

    const timeData = testData.results.map(r => r.time_per_iter_us);

    currentCharts.push(new Chart(ctx2, {
        type: 'bar',
        data: {
            labels,
            datasets: [{
                label: 'Time per Iteration (µs)',
                data: timeData,
                backgroundColor: createGradient(ctx2, COLORS.magenta, COLORS.magentaTransparent),
                borderColor: COLORS.magenta,
                borderWidth: 2
            }]
        },
        options: getSynthwaveChartOptions('Sprite Size', 'Microseconds')
    }));
}

// ====================================================================
// CHART: RenderEngine.render_stable
// ====================================================================

function renderRenderStableCharts(container, testData) {
    const section = createChartSection(container, 'RenderEngine.render_stable Performance', 'magenta');

    // Separate by aspect ratio
    const square = testData.results.filter(r => r.width === r.height);
    const horizontal = testData.results.filter(r => r.width > r.height);
    const vertical = testData.results.filter(r => r.width < r.height);

    // Chart: Throughput by Output Size (All Aspect Ratios)
    const canvas = createCanvas(section, 'render-stable-throughput');
    const ctx = canvas.getContext('2d');

    currentCharts.push(new Chart(ctx, {
        type: 'line',
        data: {
            labels: testData.results.map(r => r.name),
            datasets: [
                {
                    label: 'Square',
                    data: square.map(r => r.megapixels_per_sec),
                    borderColor: COLORS.cyan,
                    backgroundColor: COLORS.cyanTransparent,
                    pointRadius: 5,
                    tension: 0.3
                },
                {
                    label: '16:9 Horizontal',
                    data: horizontal.map((r, i) =>
                        testData.results.indexOf(r) >= 0 ? r.megapixels_per_sec : null
                    ),
                    borderColor: COLORS.magenta,
                    backgroundColor: COLORS.magentaTransparent,
                    pointRadius: 5,
                    tension: 0.3,
                    spanGaps: true
                },
                {
                    label: '9:16 Vertical',
                    data: vertical.map((r, i) =>
                        testData.results.indexOf(r) >= 0 ? r.megapixels_per_sec : null
                    ),
                    borderColor: COLORS.purple,
                    backgroundColor: COLORS.purpleTransparent,
                    pointRadius: 5,
                    tension: 0.3,
                    spanGaps: true
                }
            ]
        },
        options: getSynthwaveChartOptions('Output Size', 'MP/sec')
    }));

    // Chart: Throughput vs Pixel Count (scatter)
    const scatterCanvas = createCanvas(section, 'render-stable-scatter');
    const ctx2 = scatterCanvas.getContext('2d');

    currentCharts.push(new Chart(ctx2, {
        type: 'scatter',
        data: {
            datasets: [{
                label: 'All Sizes',
                data: testData.results.map(r => ({
                    x: r.pixels,
                    y: r.megapixels_per_sec
                })),
                backgroundColor: COLORS.purple,
                borderColor: COLORS.cyan,
                pointRadius: 8,
                pointHoverRadius: 12
            }]
        },
        options: {
            ...getSynthwaveChartOptions('Pixels', 'MP/sec'),
            scales: {
                x: {
                    type: 'linear',
                    position: 'bottom',
                    title: {
                        display: true,
                        text: 'Total Pixels',
                        color: COLORS.text,
                        font: { size: 14, family: 'Orbitron' }
                    },
                    grid: { color: COLORS.grid },
                    ticks: { color: COLORS.text }
                },
                y: {
                    title: {
                        display: true,
                        text: 'MP/sec',
                        color: COLORS.text,
                        font: { size: 14, family: 'Orbitron' }
                    },
                    grid: { color: COLORS.grid },
                    ticks: { color: COLORS.text }
                }
            }
        }
    }));
}

// ====================================================================
// CHART: Combined render_stable_with_toAnsi
// ====================================================================

function renderCombinedCharts(container, testData) {
    const section = createChartSection(container, 'RenderEngine.render_stable_with_toAnsi Performance', 'purple');

    const canvas = createCanvas(section, 'combined-throughput');
    const ctx = canvas.getContext('2d');

    const labels = testData.results.map(r => r.name);
    const mpData = testData.results.map(r => r.megapixels_per_sec);
    const timeData = testData.results.map(r => r.time_per_iter_us);

    currentCharts.push(new Chart(ctx, {
        type: 'bar',
        data: {
            labels,
            datasets: [{
                label: 'Megapixels/sec',
                data: mpData,
                backgroundColor: createGradient(ctx, COLORS.purple, COLORS.purpleTransparent),
                borderColor: COLORS.purple,
                borderWidth: 2,
                yAxisID: 'y'
            }]
        },
        options: getSynthwaveChartOptions('Output Size', 'MP/sec')
    }));
}

// ====================================================================
// CHART: Cross-Test Comparison
// ====================================================================

function renderComparisonChart(container, allData) {
    const section = createChartSection(container, 'Performance Comparison Across Tests', 'yellow');

    // Extract comparable data points (64x64 sprite/surface)
    const comparison = [];

    if (allData['RenderSurface.toAnsi']) {
        const test = allData['RenderSurface.toAnsi'].results.find(r => r.name === '64x64');
        if (test) {
            comparison.push({
                name: 'toAnsi (64x64)',
                mp: test.megapixels_per_sec,
                time: test.time_per_iter_us
            });
        }
    }

    if (allData['RenderEngine.render_stable']) {
        const test = allData['RenderEngine.render_stable'].results.find(r => r.name === '64x64');
        if (test) {
            comparison.push({
                name: 'render_stable (64x64)',
                mp: test.megapixels_per_sec,
                time: test.time_per_iter_us
            });
        }
    }

    if (allData['RenderEngine.render_stable_with_toAnsi']) {
        const test = allData['RenderEngine.render_stable_with_toAnsi'].results.find(r => r.name === '64x64');
        if (test) {
            comparison.push({
                name: 'combined (64x64)',
                mp: test.megapixels_per_sec,
                time: test.time_per_iter_us
            });
        }
    }

    if (comparison.length < 2) return; // Not enough data

    const canvas = createCanvas(section, 'comparison-chart');
    const ctx = canvas.getContext('2d');

    currentCharts.push(new Chart(ctx, {
        type: 'radar',
        data: {
            labels: comparison.map(c => c.name),
            datasets: [{
                label: 'Megapixels/sec',
                data: comparison.map(c => c.mp),
                backgroundColor: COLORS.cyanTransparent,
                borderColor: COLORS.cyan,
                pointBackgroundColor: COLORS.cyan,
                pointBorderColor: '#0a0e27',
                pointHoverBackgroundColor: COLORS.magenta,
                pointHoverBorderColor: COLORS.cyan,
                borderWidth: 3,
                pointRadius: 6
            }]
        },
        options: {
            ...getSynthwaveChartOptions(),
            scales: {
                r: {
                    beginAtZero: true,
                    grid: { color: COLORS.grid },
                    angleLines: { color: COLORS.grid },
                    pointLabels: {
                        color: COLORS.text,
                        font: { size: 12, family: 'Share Tech Mono' }
                    },
                    ticks: { color: COLORS.text }
                }
            }
        }
    }));
}

// ====================================================================
// CHART UTILITIES
// ====================================================================

function createChartSection(container, title, color) {
    const section = document.createElement('div');
    section.className = 'chart-section';
    section.innerHTML = `<h3 class="text-${color} glow-${color}">${title}</h3>`;
    container.appendChild(section);
    return section;
}

function createCanvas(parent, id) {
    const wrapper = document.createElement('div');
    wrapper.className = 'chart-container';

    const canvas = document.createElement('canvas');
    canvas.id = id;

    wrapper.appendChild(canvas);
    parent.appendChild(wrapper);

    return canvas;
}

function createGradient(ctx, colorStart, colorEnd) {
    const gradient = ctx.createLinearGradient(0, 0, 0, 400);
    gradient.addColorStop(0, colorStart);
    gradient.addColorStop(1, colorEnd);
    return gradient;
}

function getSynthwaveChartOptions(xLabel = '', yLabel = '') {
    return {
        responsive: true,
        maintainAspectRatio: true,
        plugins: {
            legend: {
                display: true,
                labels: {
                    color: COLORS.text,
                    font: {
                        size: 14,
                        family: 'Orbitron'
                    },
                    padding: 15,
                    usePointStyle: true
                }
            },
            tooltip: {
                backgroundColor: 'rgba(26, 31, 58, 0.95)',
                titleColor: COLORS.cyan,
                bodyColor: COLORS.text,
                borderColor: COLORS.cyan,
                borderWidth: 2,
                padding: 12,
                titleFont: {
                    size: 14,
                    family: 'Orbitron'
                },
                bodyFont: {
                    size: 12,
                    family: 'Share Tech Mono'
                },
                callbacks: {
                    label: (context) => {
                        let label = context.dataset.label || '';
                        if (label) label += ': ';
                        label += context.parsed.y !== null ?
                            context.parsed.y.toFixed(2) : '';
                        return label;
                    }
                }
            }
        },
        scales: {
            x: {
                grid: {
                    color: COLORS.grid,
                    lineWidth: 1
                },
                ticks: {
                    color: COLORS.text,
                    font: {
                        size: 11,
                        family: 'Share Tech Mono'
                    }
                },
                title: {
                    display: xLabel !== '',
                    text: xLabel,
                    color: COLORS.text,
                    font: {
                        size: 14,
                        family: 'Orbitron'
                    }
                }
            },
            y: {
                grid: {
                    color: COLORS.grid,
                    lineWidth: 1
                },
                ticks: {
                    color: COLORS.text,
                    font: {
                        size: 11,
                        family: 'Share Tech Mono'
                    }
                },
                title: {
                    display: yLabel !== '',
                    text: yLabel,
                    color: COLORS.text,
                    font: {
                        size: 14,
                        family: 'Orbitron'
                    }
                }
            }
        },
        animation: {
            duration: 1000,
            easing: 'easeInOutQuart'
        }
    };
}

// ====================================================================
// SMOOTH SCROLL
// ====================================================================

document.querySelectorAll('nav a').forEach(link => {
    link.addEventListener('click', (e) => {
        e.preventDefault();
        const target = document.querySelector(link.getAttribute('href'));
        if (target) {
            target.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }
    });
});

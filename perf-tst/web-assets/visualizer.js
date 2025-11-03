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
    console.log('Setting up hamburger menu...');
    setupHamburgerMenu();
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

    // IMPORTANT: Render alpha comparison charts FIRST
    if (data['RenderEngine.alpha_comparison']) {
        renderAlphaComparisonCharts(container, data['RenderEngine.alpha_comparison']);
    }

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
// CHART: RenderEngine.alpha_comparison
// ====================================================================

function renderAlphaComparisonCharts(container, testData) {
    const section = createChartSection(container, 'Alpha Blending Performance Comparison', 'pink');

    // Parse measurement names to extract: method, size, surface_count
    // Example: "render()_10x10_3surf" -> { method: "render()", size: "10x10", surfCount: 3 }
    const parsed = testData.results.map(r => {
        const parts = r.name.split('_');
        return {
            method: parts[0],
            size: parts[1],
            surfCount: parseInt(parts[2].replace('surf', '')),
            data: r
        };
    });

    // Group by surface count
    const bySurfaceCount = {
        3: parsed.filter(p => p.surfCount === 3),
        5: parsed.filter(p => p.surfCount === 5),
        10: parsed.filter(p => p.surfCount === 10)
    };

    // Color mapping for each method
    const methodColors = {
        'render()': { line: COLORS.cyan, fill: COLORS.cyanTransparent },
        'renderWithAlphaToBg()': { line: COLORS.magenta, fill: COLORS.magentaTransparent },
        'renderWithAlpha()': { line: COLORS.purple, fill: COLORS.purpleTransparent }
    };

    // Create one chart per surface count scenario
    Object.keys(bySurfaceCount).forEach(surfCount => {
        const data = bySurfaceCount[surfCount];
        if (data.length === 0) return;

        // Group by method
        const byMethod = {};
        data.forEach(item => {
            if (!byMethod[item.method]) {
                byMethod[item.method] = [];
            }
            byMethod[item.method].push(item);
        });

        // Sort by size (extract numeric part)
        Object.keys(byMethod).forEach(method => {
            byMethod[method].sort((a, b) => {
                const aNum = parseInt(a.size.split('x')[0]);
                const bNum = parseInt(b.size.split('x')[0]);
                return aNum - bNum;
            });
        });

        // Get unique sizes (sorted)
        const sizes = [...new Set(data.map(d => d.size))].sort((a, b) => {
            const aNum = parseInt(a.split('x')[0]);
            const bNum = parseInt(b.split('x')[0]);
            return aNum - bNum;
        });

        // Chart 1: Throughput Comparison (Line Chart)
        const canvas1 = createCanvas(section, `alpha-throughput-${surfCount}surf`);
        const ctx1 = canvas1.getContext('2d');

        const datasets = Object.keys(byMethod).map(method => {
            const methodData = byMethod[method];
            const color = methodColors[method] || { line: COLORS.yellow, fill: COLORS.yellowTransparent };

            return {
                label: method,
                data: sizes.map(size => {
                    const item = methodData.find(d => d.size === size);
                    return item ? item.data.megapixels_per_sec : null;
                }),
                borderColor: color.line,
                backgroundColor: color.fill,
                borderWidth: 3,
                pointRadius: 6,
                pointHoverRadius: 8,
                pointBackgroundColor: color.line,
                pointBorderColor: '#0a0e27',
                pointBorderWidth: 2,
                tension: 0.4,
                fill: true,
                spanGaps: false
            };
        });

        currentCharts.push(new Chart(ctx1, {
            type: 'line',
            data: {
                labels: sizes,
                datasets: datasets
            },
            options: getSynthwaveChartOptions(`Surface Size (${surfCount} overlapping surfaces)`, 'MP/sec')
        }));

        // Chart 2: Time per Iteration Comparison (Grouped Bar Chart)
        const canvas2 = createCanvas(section, `alpha-time-${surfCount}surf`);
        const ctx2 = canvas2.getContext('2d');

        const barDatasets = Object.keys(byMethod).map(method => {
            const methodData = byMethod[method];
            const color = methodColors[method] || { line: COLORS.yellow, fill: COLORS.yellowTransparent };

            return {
                label: method,
                data: sizes.map(size => {
                    const item = methodData.find(d => d.size === size);
                    return item ? item.data.time_per_iter_us : null;
                }),
                backgroundColor: color.fill,
                borderColor: color.line,
                borderWidth: 2
            };
        });

        currentCharts.push(new Chart(ctx2, {
            type: 'bar',
            data: {
                labels: sizes,
                datasets: barDatasets
            },
            options: getSynthwaveChartOptions(`Surface Size (${surfCount} overlapping surfaces)`, 'Time per Iteration (µs)')
        }));
    });

    // Chart 3: Performance Ratio Chart (shows overhead of alpha blending)
    // Only create if we have render() as baseline
    const baselineData = parsed.filter(p => p.method === 'render()');
    if (baselineData.length > 0) {
        renderAlphaOverheadChart(section, parsed, baselineData);
    }
}

function renderAlphaOverheadChart(section, allData, baselineData) {
    const canvas = createCanvas(section, 'alpha-overhead');
    const ctx = canvas.getContext('2d');

    // Calculate overhead ratios for each surface count
    const surfCounts = [3, 5, 10];
    const methods = ['renderWithAlphaToBg()', 'renderWithAlpha()'];

    const datasets = methods.map((method, idx) => {
        const color = idx === 0 ? COLORS.magenta : COLORS.purple;
        const colorTransparent = idx === 0 ? COLORS.magentaTransparent : COLORS.purpleTransparent;

        return {
            label: `${method} overhead`,
            data: surfCounts.map(surfCount => {
                // Find matching baseline and method data
                const baseline = baselineData.find(b => b.surfCount === surfCount);
                const methodItem = allData.find(d => d.method === method && d.surfCount === surfCount);

                if (!baseline || !methodItem) return null;

                // Calculate slowdown ratio (higher = slower)
                const ratio = methodItem.data.time_per_iter_us / baseline.data.time_per_iter_us;
                return (ratio - 1) * 100; // Convert to percentage overhead
            }),
            backgroundColor: colorTransparent,
            borderColor: color,
            borderWidth: 2
        };
    });

    currentCharts.push(new Chart(ctx, {
        type: 'bar',
        data: {
            labels: surfCounts.map(c => `${c} surfaces`),
            datasets: datasets
        },
        options: {
            ...getSynthwaveChartOptions('Surface Count', 'Overhead vs render() (%)'),
            plugins: {
                ...getSynthwaveChartOptions('', '').plugins,
                tooltip: {
                    ...getSynthwaveChartOptions('', '').plugins.tooltip,
                    callbacks: {
                        label: function(context) {
                            let label = context.dataset.label || '';
                            if (label) {
                                label += ': ';
                            }
                            label += '+' + context.parsed.y.toFixed(1) + '%';
                            return label;
                        }
                    }
                }
            }
        }
    }));
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

    // Create aligned data arrays - each dataset gets the full label array length
    // with null for positions where that aspect ratio doesn't have data
    const labels = testData.results.map(r => r.name);

    const squareData = testData.results.map(r => {
        const found = square.find(s => s.name === r.name);
        return found ? found.megapixels_per_sec : null;
    });

    const horizontalData = testData.results.map(r => {
        const found = horizontal.find(h => h.name === r.name);
        return found ? found.megapixels_per_sec : null;
    });

    const verticalData = testData.results.map(r => {
        const found = vertical.find(v => v.name === r.name);
        return found ? found.megapixels_per_sec : null;
    });

    currentCharts.push(new Chart(ctx, {
        type: 'line',
        data: {
            labels: labels,
            datasets: [
                {
                    label: 'Square',
                    data: squareData,
                    borderColor: COLORS.cyan,
                    backgroundColor: COLORS.cyanTransparent,
                    pointRadius: 5,
                    tension: 0.3,
                    spanGaps: true
                },
                {
                    label: '16:9 Horizontal',
                    data: horizontalData,
                    borderColor: COLORS.magenta,
                    backgroundColor: COLORS.magentaTransparent,
                    pointRadius: 5,
                    tension: 0.3,
                    spanGaps: true
                },
                {
                    label: '9:16 Vertical',
                    data: verticalData,
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
// CHART: Cross-Test Comparisons
// ====================================================================

function renderComparisonChart(container, allData) {
    // Extract comparable data points (64x64 - the only size common to all tests)
    const data = {
        toAnsi: null,
        render_stable: null,
        combined: null
    };

    if (allData['RenderSurface.toAnsi']) {
        const test = allData['RenderSurface.toAnsi'].results.find(r => r.name === '64x64');
        if (test) {
            data.toAnsi = test;
        }
    }

    if (allData['RenderEngine.render_stable']) {
        const test = allData['RenderEngine.render_stable'].results.find(r => r.name === '64x64');
        if (test) {
            data.render_stable = test;
        }
    }

    if (allData['RenderEngine.render_stable_with_toAnsi']) {
        const test = allData['RenderEngine.render_stable_with_toAnsi'].results.find(r => r.name === '64x64');
        if (test) {
            data.combined = test;
        }
    }

    // Count how many tests we have data for
    const validTests = Object.values(data).filter(d => d !== null).length;
    if (validTests < 2) return; // Not enough data for comparison

    // Create all three comparison charts
    renderSimpleBarComparison(container, data);
    renderGroupedBarComparison(container, data);
    renderRadarComparison(container, data);
}

// Chart 1: Simple Bar Chart - Throughput Comparison
function renderSimpleBarComparison(container, data) {
    const section = createChartSection(container, 'Throughput Comparison (64x64)', 'cyan');

    const labels = [];
    const mpData = [];
    const colors = [];

    if (data.toAnsi) {
        labels.push('toAnsi');
        mpData.push(data.toAnsi.megapixels_per_sec);
        colors.push(COLORS.cyan);
    }
    if (data.render_stable) {
        labels.push('render_stable');
        mpData.push(data.render_stable.megapixels_per_sec);
        colors.push(COLORS.magenta);
    }
    if (data.combined) {
        labels.push('combined');
        mpData.push(data.combined.megapixels_per_sec);
        colors.push(COLORS.purple);
    }

    const canvas = createCanvas(section, 'comparison-bar-simple');
    const ctx = canvas.getContext('2d');

    currentCharts.push(new Chart(ctx, {
        type: 'bar',
        data: {
            labels: labels,
            datasets: [{
                label: 'Megapixels/sec',
                data: mpData,
                backgroundColor: colors.map(c => c.replace('1)', '0.6)')),
                borderColor: colors,
                borderWidth: 2
            }]
        },
        options: getSynthwaveChartOptions('Test Type', 'MP/sec')
    }));
}

// Chart 2: Grouped Bar Chart - Multi-Metric Comparison
function renderGroupedBarComparison(container, data) {
    const section = createChartSection(container, 'Multi-Metric Comparison (64x64)', 'magenta');

    const labels = [];
    const mpData = [];
    const iterData = [];
    const speedData = [];

    if (data.toAnsi) {
        labels.push('toAnsi');
        mpData.push(data.toAnsi.megapixels_per_sec);
        iterData.push(data.toAnsi.iter_per_sec);
        // Normalize inverted time to 0-1000 scale for visibility
        speedData.push((1 / data.toAnsi.time_per_iter_us) * 1000);
    }
    if (data.render_stable) {
        labels.push('render_stable');
        mpData.push(data.render_stable.megapixels_per_sec);
        iterData.push(data.render_stable.iter_per_sec);
        speedData.push((1 / data.render_stable.time_per_iter_us) * 1000);
    }
    if (data.combined) {
        labels.push('combined');
        mpData.push(data.combined.megapixels_per_sec);
        iterData.push(data.combined.iter_per_sec);
        speedData.push((1 / data.combined.time_per_iter_us) * 1000);
    }

    const canvas = createCanvas(section, 'comparison-bar-grouped');
    const ctx = canvas.getContext('2d');

    currentCharts.push(new Chart(ctx, {
        type: 'bar',
        data: {
            labels: labels,
            datasets: [
                {
                    label: 'Megapixels/sec (Left)',
                    data: mpData,
                    backgroundColor: COLORS.cyanTransparent,
                    borderColor: COLORS.cyan,
                    borderWidth: 2,
                    yAxisID: 'y'
                },
                {
                    label: 'Iterations/sec (Right)',
                    data: iterData,
                    backgroundColor: COLORS.magentaTransparent,
                    borderColor: COLORS.magenta,
                    borderWidth: 2,
                    yAxisID: 'y1'
                },
                {
                    label: 'Speed Index (Left)',
                    data: speedData,
                    backgroundColor: COLORS.purpleTransparent,
                    borderColor: COLORS.purple,
                    borderWidth: 2,
                    yAxisID: 'y'
                }
            ]
        },
        options: {
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
                        display: true,
                        text: 'Test Type',
                        color: COLORS.text,
                        font: {
                            size: 14,
                            family: 'Orbitron'
                        }
                    }
                },
                y: {
                    type: 'linear',
                    position: 'left',
                    grid: {
                        color: COLORS.grid,
                        lineWidth: 1
                    },
                    ticks: {
                        color: COLORS.cyan,
                        font: {
                            size: 11,
                            family: 'Share Tech Mono'
                        }
                    },
                    title: {
                        display: true,
                        text: 'MP/sec & Speed Index',
                        color: COLORS.cyan,
                        font: {
                            size: 14,
                            family: 'Orbitron'
                        }
                    }
                },
                y1: {
                    type: 'linear',
                    position: 'right',
                    grid: {
                        drawOnChartArea: false
                    },
                    ticks: {
                        color: COLORS.magenta,
                        font: {
                            size: 11,
                            family: 'Share Tech Mono'
                        }
                    },
                    title: {
                        display: true,
                        text: 'Iterations/sec',
                        color: COLORS.magenta,
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
        }
    }));
}

// Chart 3: Radar Chart - Performance Profile
function renderRadarComparison(container, data) {
    const section = createChartSection(container, 'Performance Profile Comparison (64x64)', 'purple');

    // Collect all values for normalization
    const allMp = [];
    const allIter = [];
    const allSpeed = [];
    const allEfficiency = [];

    [data.toAnsi, data.render_stable, data.combined].forEach(test => {
        if (test) {
            allMp.push(test.megapixels_per_sec);
            allIter.push(test.iter_per_sec);
            allSpeed.push(1 / test.time_per_iter_us);
            allEfficiency.push(test.pixels / test.elapsed_ns);
        }
    });

    const maxMp = Math.max(...allMp);
    const maxIter = Math.max(...allIter);
    const maxSpeed = Math.max(...allSpeed);
    const maxEfficiency = Math.max(...allEfficiency);

    // Create normalized datasets for each test
    const datasets = [];
    const testConfigs = [
        { key: 'toAnsi', label: 'toAnsi', color: COLORS.cyan, colorTrans: COLORS.cyanTransparent },
        { key: 'render_stable', label: 'render_stable', color: COLORS.magenta, colorTrans: COLORS.magentaTransparent },
        { key: 'combined', label: 'combined', color: COLORS.purple, colorTrans: COLORS.purpleTransparent }
    ];

    testConfigs.forEach(config => {
        if (data[config.key]) {
            const test = data[config.key];
            datasets.push({
                label: config.label,
                data: [
                    (test.megapixels_per_sec / maxMp) * 100,
                    (test.iter_per_sec / maxIter) * 100,
                    ((1 / test.time_per_iter_us) / maxSpeed) * 100,
                    ((test.pixels / test.elapsed_ns) / maxEfficiency) * 100,
                    // Overall performance index (average of normalized metrics)
                    ((test.megapixels_per_sec / maxMp) +
                     (test.iter_per_sec / maxIter) +
                     ((1 / test.time_per_iter_us) / maxSpeed) +
                     ((test.pixels / test.elapsed_ns) / maxEfficiency)) / 4 * 100
                ],
                backgroundColor: config.colorTrans,
                borderColor: config.color,
                pointBackgroundColor: config.color,
                pointBorderColor: '#0a0e27',
                pointHoverBackgroundColor: COLORS.yellow,
                pointHoverBorderColor: config.color,
                borderWidth: 3,
                pointRadius: 6
            });
        }
    });

    const canvas = createCanvas(section, 'comparison-radar');
    const ctx = canvas.getContext('2d');

    currentCharts.push(new Chart(ctx, {
        type: 'radar',
        data: {
            labels: [
                'Throughput\n(MP/sec)',
                'Iteration Rate\n(iter/sec)',
                'Speed\n(1/time)',
                'Efficiency\n(px/ns)',
                'Overall\nPerformance'
            ],
            datasets: datasets
        },
        options: {
            ...getSynthwaveChartOptions(),
            scales: {
                r: {
                    beginAtZero: true,
                    max: 100,
                    grid: { color: COLORS.grid },
                    angleLines: { color: COLORS.grid },
                    pointLabels: {
                        color: COLORS.text,
                        font: { size: 11, family: 'Share Tech Mono' }
                    },
                    ticks: {
                        color: COLORS.text,
                        stepSize: 20
                    }
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
// HAMBURGER MENU
// ====================================================================

function setupHamburgerMenu() {
    const menuToggle = document.getElementById('menu-toggle');
    const mainNav = document.getElementById('main-nav');
    const navOverlay = document.getElementById('nav-overlay');

    if (!menuToggle || !mainNav || !navOverlay) {
        console.warn('Hamburger menu elements not found');
        return;
    }

    // Toggle menu on button click
    menuToggle.addEventListener('click', () => {
        const isActive = mainNav.classList.contains('active');

        menuToggle.classList.toggle('active');
        mainNav.classList.toggle('active');
        navOverlay.classList.toggle('active');

        console.log('Menu toggled:', !isActive ? 'opened' : 'closed');
    });

    // Close menu when clicking overlay
    navOverlay.addEventListener('click', () => {
        menuToggle.classList.remove('active');
        mainNav.classList.remove('active');
        navOverlay.classList.remove('active');
        console.log('Menu closed via overlay');
    });

    // Close menu on Escape key
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && mainNav.classList.contains('active')) {
            menuToggle.classList.remove('active');
            mainNav.classList.remove('active');
            navOverlay.classList.remove('active');
            console.log('Menu closed via Escape key');
        }
    });

    // Close menu when clicking nav link
    mainNav.querySelectorAll('a').forEach(link => {
        link.addEventListener('click', () => {
            menuToggle.classList.remove('active');
            mainNav.classList.remove('active');
            navOverlay.classList.remove('active');
            console.log('Menu closed after navigation');
        });
    });
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

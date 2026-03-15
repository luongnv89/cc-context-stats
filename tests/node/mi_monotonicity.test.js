/**
 * Tests that MI always reflects context length: more free context = better MI.
 *
 * Verifies monotonicity property across CPS, composite MI, different beta
 * values, ES/PS scenarios, and zone alignment.
 */

const path = require('path');
const fs = require('fs');
const { computeMI } = require('../../scripts/statusline');

const VECTORS_PATH = path.join(__dirname, '..', 'fixtures', 'mi_monotonicity_vectors.json');
const vectors = JSON.parse(fs.readFileSync(VECTORS_PATH, 'utf8'));

// --- CPS monotonicity ---

describe('CPS monotonicity', () => {
    test('CPS decreases as utilization increases', () => {
        const steps = vectors.utilization_steps;
        const beta = vectors.beta;
        const cw = vectors.context_window;

        let prevCPS = null;
        for (const step of steps) {
            const used = step.used;
            // computeMI returns { mi, cps, es, ps }
            const result = computeMI(used, cw, 0, used, 0, null, beta);

            if (prevCPS !== null) {
                expect(result.cps).toBeLessThanOrEqual(prevCPS + 1e-9);
            }
            prevCPS = result.cps;
        }
    });

    test('CPS strictly decreases between non-zero utilization steps', () => {
        const steps = vectors.utilization_steps.filter(s => s.used > 0);
        const beta = vectors.beta;
        const cw = vectors.context_window;

        let prevCPS = null;
        for (const step of steps) {
            const result = computeMI(step.used, cw, 0, step.used, 0, null, beta);

            if (prevCPS !== null) {
                expect(result.cps).toBeLessThan(prevCPS);
            }
            prevCPS = result.cps;
        }
    });

    test.each([1.0, 1.5, 2.0, 3.0])('CPS monotonic for beta=%s', (beta) => {
        const cw = 200000;
        let prevCPS = null;

        for (let pct = 0; pct <= 100; pct += 5) {
            const used = Math.floor(pct / 100 * cw);
            const result = computeMI(used, cw, 0, used, 0, null, beta);

            if (prevCPS !== null) {
                expect(result.cps).toBeLessThanOrEqual(prevCPS + 1e-9);
            }
            prevCPS = result.cps;
        }
    });

    test('CPS boundary values', () => {
        const cw = 200000;
        const empty = computeMI(0, cw, 0, 0, 0, null, 1.5);
        const full = computeMI(cw, cw, 0, cw, 0, 100, 1.5);

        expect(empty.cps).toBe(1.0);
        expect(full.cps).toBe(0.0);
    });
});

// --- Composite MI monotonicity ---

describe('MI monotonicity', () => {
    test('MI decreases with utilization (no cache, no prev)', () => {
        const steps = vectors.utilization_steps;
        const cw = vectors.context_window;

        let prevMI = null;
        for (const step of steps) {
            // No cache (ES=0.3), no prev (PS=0.5 via null deltaOutput)
            const result = computeMI(step.used, cw, 0, step.used, 0, null, 1.5);

            if (prevMI !== null) {
                expect(result.mi).toBeLessThanOrEqual(prevMI + 1e-9);
            }
            prevMI = result.mi;
        }
    });

    test('MI decreases with utilization (high cache)', () => {
        const steps = vectors.utilization_steps;
        const cw = vectors.context_window;

        let prevMI = null;
        for (const step of steps) {
            const used = step.used;
            const cacheRead = Math.floor(used * 0.8);
            const result = computeMI(used, cw, cacheRead, used, 0, null, 1.5);

            if (prevMI !== null) {
                expect(result.mi).toBeLessThanOrEqual(prevMI + 1e-9);
            }
            prevMI = result.mi;
        }
    });

    test('MI decreases with utilization (with productivity)', () => {
        const steps = vectors.utilization_steps;
        const cw = vectors.context_window;

        let prevMI = null;
        for (const step of steps) {
            const used = step.used;
            // deltaLines=120, deltaOutput=1000 => productive
            const result = computeMI(used, cw, 0, used, 120, 1000, 1.5);

            if (prevMI !== null) {
                expect(result.mi).toBeLessThanOrEqual(prevMI + 1e-9);
            }
            prevMI = result.mi;
        }
    });

    test('MI decreases across all ES/PS scenarios', () => {
        const steps = vectors.utilization_steps;
        const cw = vectors.context_window;

        for (const scenario of vectors.varying_es_ps_scenarios) {
            let prevMI = null;

            for (const step of steps) {
                const used = step.used;
                const cacheRead = Math.floor(used * scenario.cache_read_ratio);
                const dl = scenario.delta_lines;
                const dOutput = scenario.delta_output;

                const result = computeMI(used, cw, cacheRead, used, dl, dOutput, 1.5);

                if (prevMI !== null) {
                    expect(result.mi).toBeLessThanOrEqual(prevMI + 1e-9);
                }
                prevMI = result.mi;
            }
        }
    });

    test.each([1.0, 1.5, 2.0, 3.0])('MI decreases for beta=%s', (beta) => {
        const cw = 200000;
        let prevMI = null;

        for (let pct = 0; pct <= 100; pct += 5) {
            const used = Math.floor(pct / 100 * cw);
            const result = computeMI(used, cw, 0, used, 0, null, beta);

            if (prevMI !== null) {
                expect(result.mi).toBeLessThanOrEqual(prevMI + 1e-9);
            }
            prevMI = result.mi;
        }
    });
});

// --- Fine-grained resolution ---

describe('MI fine-grained monotonicity', () => {
    test('MI monotonic at 1% resolution', () => {
        const cw = 200000;
        let prevMI = null;

        for (let pct = 0; pct <= 100; pct++) {
            const used = Math.floor(pct / 100 * cw);
            const result = computeMI(used, cw, 0, used, 0, null, 1.5);

            if (prevMI !== null) {
                expect(result.mi).toBeLessThanOrEqual(prevMI + 1e-9);
            }
            prevMI = result.mi;
        }
    });

    test('CPS monotonic at 1% resolution', () => {
        const cw = 200000;
        let prevCPS = null;

        for (let pct = 0; pct <= 100; pct++) {
            const used = Math.floor(pct / 100 * cw);
            const result = computeMI(used, cw, 0, used, 0, null, 1.5);

            if (prevCPS !== null) {
                expect(result.cps).toBeLessThanOrEqual(prevCPS + 1e-9);
            }
            prevCPS = result.cps;
        }
    });
});

// --- MI reflects context zones ---

describe('MI reflects context zones', () => {
    test('smart zone MI > dumb zone MI > wrap up zone MI', () => {
        const cw = 200000;
        const smart = computeMI(Math.floor(0.20 * cw), cw, 0, Math.floor(0.20 * cw), 0, null, 1.5);
        const dumb = computeMI(Math.floor(0.60 * cw), cw, 0, Math.floor(0.60 * cw), 0, null, 1.5);
        const wrap = computeMI(Math.floor(0.90 * cw), cw, 0, Math.floor(0.90 * cw), 0, null, 1.5);

        expect(smart.mi).toBeGreaterThan(dumb.mi);
        expect(dumb.mi).toBeGreaterThan(wrap.mi);
    });

    test('empty context has highest MI', () => {
        const cw = 200000;
        const result = computeMI(0, cw, 0, 0, 0, null, 1.5);

        // CPS=1.0, ES=1.0 (no tokens => default 1.0... wait, totalContext=0 => ES=1.0)
        // Actually: totalContext (4th arg) = 0, so ES=1.0
        // PS=0.5 (null deltaOutput)
        // MI = 0.60*1.0 + 0.25*1.0 + 0.15*0.5 = 0.925
        // But if totalContext is passed as used (0), ES=1.0
        expect(result.cps).toBe(1.0);
        expect(result.mi).toBeGreaterThan(0.7);
    });

    test('full context has lowest MI', () => {
        const cw = 200000;
        const result = computeMI(cw, cw, 0, cw, 0, 100, 1.5);

        expect(result.cps).toBe(0.0);
        expect(result.mi).toBeLessThan(0.3);
    });

    test('MI spread covers meaningful range (>= 0.5)', () => {
        const cw = 200000;
        const empty = computeMI(0, cw, 0, 0, 0, null, 1.5);
        const full = computeMI(cw, cw, 0, cw, 0, null, 1.5);

        const spread = empty.mi - full.mi;
        expect(spread).toBeGreaterThanOrEqual(0.5);
    });
});

// --- MI sensitivity to context ---

describe('MI sensitivity', () => {
    test('worst-case ES/PS still monotonic', () => {
        const cw = 200000;
        let prevMI = null;

        for (let pct = 0; pct <= 100; pct += 5) {
            const used = Math.floor(pct / 100 * cw);
            // No cache (ES=0.3), zero lines (PS=0.2)
            const result = computeMI(used, cw, 0, used, 0, 1000, 1.5);

            if (prevMI !== null) {
                expect(result.mi).toBeLessThanOrEqual(prevMI + 1e-9);
            }
            prevMI = result.mi;
        }
    });

    test('best-case ES/PS still monotonic', () => {
        const cw = 200000;
        let prevMI = null;

        for (let pct = 0; pct <= 100; pct += 5) {
            const used = Math.floor(pct / 100 * cw);
            // All cache (ES=1.0), super productive (PS=1.0)
            const result = computeMI(used, cw, used, used, 60, 100, 1.5);

            if (prevMI !== null) {
                expect(result.mi).toBeLessThanOrEqual(prevMI + 1e-9);
            }
            prevMI = result.mi;
        }
    });
});

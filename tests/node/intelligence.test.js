/**
 * Tests for Model Intelligence (MI) score computation.
 * Uses shared test vectors for cross-implementation parity.
 */

const path = require('path');
const fs = require('fs');
const { computeMI, getContextZone } = require('../../scripts/statusline');

const VECTORS_PATH = path.join(__dirname, '..', 'fixtures', 'mi_test_vectors.json');
const vectors = JSON.parse(fs.readFileSync(VECTORS_PATH, 'utf8'));

describe('computeMI', () => {
    test('guard clause: context_window=0 returns MI=1.0', () => {
        const result = computeMI(50000, 0, 'claude-opus-4-6');
        expect(result.mi).toBe(1.0);
    });

    test('empty context returns MI=1.0', () => {
        const result = computeMI(0, 200000, 'claude-sonnet-4-6');
        expect(result.mi).toBe(1.0);
    });

    test('full context is always MI=0.0 regardless of model', () => {
        for (const model of ['claude-opus-4-6', 'claude-sonnet-4-6', 'claude-haiku-4-5']) {
            const result = computeMI(200000, 200000, model);
            expect(result.mi).toBe(0);
        }
    });

    test('unknown model uses default (sonnet) profile', () => {
        const result = computeMI(100000, 200000, 'unknown-model');
        const sonnet = computeMI(100000, 200000, 'claude-sonnet-4-6');
        expect(result.mi).toBeCloseTo(sonnet.mi, 2);
    });

    test('beta override takes precedence', () => {
        // Opus with beta_override=1.0: MI = 1 - 0.5^1.0 = 0.5
        const result = computeMI(100000, 200000, 'claude-opus-4-6', 1.0);
        expect(result.mi).toBeCloseTo(0.5, 2);
    });

    test('MI is always between 0 and 1', () => {
        const utilizations = [0, 0.1, 0.3, 0.5, 0.7, 0.9, 1.0];
        for (const u of utilizations) {
            const used = Math.floor(u * 200000);
            const result = computeMI(used, 200000, 'claude-sonnet-4-6');
            expect(result.mi).toBeGreaterThanOrEqual(0);
            expect(result.mi).toBeLessThanOrEqual(1);
        }
    });

    test('opus degrades less than sonnet at same utilization', () => {
        const opus = computeMI(140000, 200000, 'claude-opus-4-6');
        const sonnet = computeMI(140000, 200000, 'claude-sonnet-4-6');
        expect(opus.mi).toBeGreaterThan(sonnet.mi);
    });
});

// --- Context zone tests ---

describe('getContextZone', () => {
    // 1M model tests
    test('1M model, 50k used → P (green)', () => {
        const z = getContextZone(50000, 1000000);
        expect(z.zone).toBe('Plan');
        expect(z.colorName).toBe('green');
    });

    test('1M model, 85k used → C (yellow)', () => {
        const z = getContextZone(85000, 1000000);
        expect(z.zone).toBe('Code');
        expect(z.colorName).toBe('yellow');
    });

    test('1M model, 150k used → D (orange)', () => {
        const z = getContextZone(150000, 1000000);
        expect(z.zone).toBe('Dump');
        expect(z.colorName).toBe('orange');
    });

    test('1M model, 250k used → X (dark_red)', () => {
        const z = getContextZone(250000, 1000000);
        expect(z.zone).toBe('ExDump');
        expect(z.colorName).toBe('dark_red');
    });

    test('1M model, 300k used → Z (gray)', () => {
        const z = getContextZone(300000, 1000000);
        expect(z.zone).toBe('Dead');
        expect(z.colorName).toBe('gray');
    });

    // Boundary tests
    test('boundary: 70k → C (not P)', () => {
        expect(getContextZone(70000, 1000000).zone).toBe('Code');
        expect(getContextZone(69999, 1000000).zone).toBe('Plan');
    });

    test('boundary: 100k → D (not C)', () => {
        expect(getContextZone(100000, 1000000).zone).toBe('Dump');
        expect(getContextZone(99999, 1000000).zone).toBe('Code');
    });

    test('boundary: 275k → Z (past X), X is 250k–275k range', () => {
        expect(getContextZone(275000, 1000000).zone).toBe('Dead');
        expect(getContextZone(274999, 1000000).zone).toBe('ExDump');
        // 250001 is now within X range (not Z)
        expect(getContextZone(250001, 1000000).zone).toBe('ExDump');
    });

    // Standard model tests
    test('200k model, 20k used → P', () => {
        expect(getContextZone(20000, 200000).zone).toBe('Plan');
    });

    test('200k model, 60k used → C', () => {
        expect(getContextZone(60000, 200000).zone).toBe('Code');
    });

    test('200k model, 100k (50%) → D', () => {
        expect(getContextZone(100000, 200000).zone).toBe('Dump');
    });

    test('200k model, 140k (70%) → X', () => {
        expect(getContextZone(140000, 200000).zone).toBe('ExDump');
    });

    test('200k model, 150k (75%) → Z', () => {
        expect(getContextZone(150000, 200000).zone).toBe('Dead');
    });

    // Guard clause
    test('context_window=0 → P', () => {
        expect(getContextZone(50000, 0).zone).toBe('Plan');
    });

    // Large model threshold
    test('500k context is treated as 1M-class', () => {
        expect(getContextZone(50000, 500000).zone).toBe('Plan');
    });
});

// --- Configurable zone threshold tests ---

describe('getContextZone with config overrides', () => {
    // 1M model overrides
    test('custom zone_1m_plan_max shifts P→C boundary', () => {
        const zone = getContextZone(80000, 1000000, { zone_1m_plan_max: 90000 });
        expect(zone.zone).toBe('Plan');
        // Default would be Code
        expect(getContextZone(80000, 1000000).zone).toBe('Code');
    });

    test('custom zone_1m_code_max shifts C→D boundary', () => {
        const zone = getContextZone(95000, 1000000, { zone_1m_code_max: 80000 });
        expect(zone.zone).toBe('Dump');
        expect(getContextZone(95000, 1000000).zone).toBe('Code');
    });

    test('custom zone_1m_dump_max shifts D→X boundary', () => {
        const zone = getContextZone(200000, 1000000, { zone_1m_dump_max: 180000 });
        expect(zone.zone).toBe('ExDump');
        expect(getContextZone(200000, 1000000).zone).toBe('Dump');
    });

    test('custom zone_1m_xdump_max shifts X→Z boundary', () => {
        const zone = getContextZone(260000, 1000000, { zone_1m_xdump_max: 255000 });
        expect(zone.zone).toBe('Dead');
        expect(getContextZone(260000, 1000000).zone).toBe('ExDump');
    });

    // Standard model overrides
    test('custom zone_std_dump_ratio shifts dump zone start', () => {
        const zone = getContextZone(70000, 200000, { zone_std_dump_ratio: 0.30 });
        expect(zone.zone).toBe('Dump');
        expect(getContextZone(70000, 200000).zone).toBe('Code');
    });

    test('custom zone_std_hard_limit shifts hard limit', () => {
        const zone = getContextZone(110000, 200000, { zone_std_hard_limit: 0.50 });
        expect(zone.zone).toBe('ExDump');
        expect(getContextZone(110000, 200000).zone).toBe('Dump');
    });

    test('custom zone_std_dead_ratio shifts dead zone start', () => {
        // Default: dead at 75% (150k). With 0.72 → dead at 144k.
        const zone = getContextZone(145000, 200000, { zone_std_dead_ratio: 0.72 });
        expect(zone.zone).toBe('Dead');
        // Default: 145k between hard_limit (140k) and dead (150k) → ExDump
        expect(getContextZone(145000, 200000).zone).toBe('ExDump');
    });

    // Large model threshold override
    test('custom large_model_threshold changes model classification', () => {
        const zone = getContextZone(80000, 400000, { large_model_threshold: 300000 });
        expect(zone.zone).toBe('Code'); // 1M thresholds: 70k-100k
    });

    // Zero override = use default
    test('zero override uses default', () => {
        const zone = getContextZone(80000, 1000000, { zone_1m_plan_max: 0 });
        expect(zone.zone).toBe('Code'); // Same as default
    });
});

describe('shared test vectors', () => {
    vectors.forEach((vec) => {
        test(vec.description, () => {
            const inp = vec.input;
            const exp = vec.expected;

            const betaOverride = inp.beta_override || 0;

            const result = computeMI(
                inp.current_used,
                inp.context_window,
                inp.model_id,
                betaOverride
            );

            expect(result.mi).toBeCloseTo(exp.mi, 1);
        });
    });
});

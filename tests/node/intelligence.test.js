/**
 * Tests for Model Intelligence (MI) score computation.
 * Uses shared test vectors for cross-implementation parity.
 */

const path = require('path');
const fs = require('fs');
const { computeMI } = require('../../scripts/statusline');

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

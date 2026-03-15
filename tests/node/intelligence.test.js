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
    test('guard clause: context_window=0 returns defaults', () => {
        const result = computeMI(50000, 0, 30000, 50000, 0, null, 1.5);
        expect(result.mi).toBe(1.0);
        expect(result.cps).toBe(1.0);
        expect(result.es).toBe(1.0);
        expect(result.ps).toBe(0.5);
    });

    test('empty context returns CPS=1', () => {
        const result = computeMI(0, 200000, 0, 0, 0, null, 1.5);
        expect(result.cps).toBe(1.0);
    });

    test('full context returns CPS=0', () => {
        const result = computeMI(200000, 200000, 0, 200000, 0, 100, 1.5);
        expect(result.cps).toBe(0);
    });

    test('no cache returns ES=0.3', () => {
        const result = computeMI(100000, 200000, 0, 100000, 0, null, 1.5);
        expect(result.es).toBeCloseTo(0.3, 1);
    });

    test('all cache returns ES=1.0', () => {
        const result = computeMI(100000, 200000, 100000, 100000, 0, null, 1.5);
        expect(result.es).toBeCloseTo(1.0, 1);
    });

    test('no previous returns PS=0.5', () => {
        const result = computeMI(100000, 200000, 50000, 100000, 0, null, 1.5);
        expect(result.ps).toBe(0.5);
    });

    test('no output returns PS=0.5', () => {
        const result = computeMI(100000, 200000, 50000, 100000, 100, 0, 1.5);
        expect(result.ps).toBe(0.5);
    });

    test('MI is always between 0 and 1', () => {
        const utilizations = [0, 0.1, 0.3, 0.5, 0.7, 0.9, 1.0];
        for (const u of utilizations) {
            const used = Math.floor(u * 200000);
            const result = computeMI(used, 200000, used / 2, used, 50, 500, 1.5);
            expect(result.mi).toBeGreaterThanOrEqual(0);
            expect(result.mi).toBeLessThanOrEqual(1);
        }
    });
});

describe('shared test vectors', () => {
    vectors.forEach((vec) => {
        test(vec.description, () => {
            const inp = vec.input;
            const exp = vec.expected;

            const hasPrev = inp.prev_output !== null;
            let deltaLines, deltaOutput;

            if (hasPrev) {
                const deltaLA = inp.cur_lines_added - inp.prev_lines_added;
                const deltaLR = inp.cur_lines_removed - inp.prev_lines_removed;
                deltaLines = deltaLA + deltaLR;
                deltaOutput = inp.cur_output - inp.prev_output;
            } else {
                deltaLines = 0;
                deltaOutput = null;
            }

            const result = computeMI(
                inp.current_used,
                inp.context_window,
                inp.cache_read,
                inp.current_used,
                deltaLines,
                deltaOutput,
                inp.beta
            );

            expect(result.cps).toBeCloseTo(exp.cps, 1);
            expect(result.es).toBeCloseTo(exp.es, 1);
            expect(result.ps).toBeCloseTo(exp.ps, 1);
            expect(result.mi).toBeCloseTo(exp.mi, 1);
        });
    });
});

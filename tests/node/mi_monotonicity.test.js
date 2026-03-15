/**
 * Tests that MI always reflects context length: more free context = better MI.
 *
 * Verifies monotonicity property across model profiles, beta values,
 * and zone alignment.
 */

const path = require('path');
const fs = require('fs');
const { computeMI } = require('../../scripts/statusline');

const VECTORS_PATH = path.join(__dirname, '..', 'fixtures', 'mi_monotonicity_vectors.json');
const vectors = JSON.parse(fs.readFileSync(VECTORS_PATH, 'utf8'));

// --- MI monotonicity ---

describe('MI monotonicity', () => {
    test('MI decreases with utilization (default/sonnet profile)', () => {
        const steps = vectors.utilization_steps;
        const cw = vectors.context_window;

        let prevMI = null;
        for (const step of steps) {
            const result = computeMI(step.used, cw, 'claude-sonnet-4-6');

            if (prevMI !== null) {
                expect(result.mi).toBeLessThanOrEqual(prevMI + 1e-9);
            }
            prevMI = result.mi;
        }
    });

    test.each(['claude-opus-4-6', 'claude-sonnet-4-6', 'claude-haiku-4-5', 'unknown-model'])(
        'MI decreases for model %s',
        (modelId) => {
            const steps = vectors.utilization_steps;
            const cw = vectors.context_window;

            let prevMI = null;
            for (const step of steps) {
                const result = computeMI(step.used, cw, modelId);

                if (prevMI !== null) {
                    expect(result.mi).toBeLessThanOrEqual(prevMI + 1e-9);
                }
                prevMI = result.mi;
            }
        }
    );

    test.each([1.0, 1.5, 2.0, 3.0])('MI decreases for beta_override=%s', (beta) => {
        const cw = 200000;
        let prevMI = null;

        for (let pct = 0; pct <= 100; pct += 5) {
            const used = Math.floor(pct / 100 * cw);
            const result = computeMI(used, cw, 'claude-opus-4-6', beta);

            if (prevMI !== null) {
                expect(result.mi).toBeLessThanOrEqual(prevMI + 1e-9);
            }
            prevMI = result.mi;
        }
    });
});

// --- Fine-grained resolution ---

describe('MI fine-grained monotonicity', () => {
    test.each(['claude-opus-4-6', 'claude-sonnet-4-6', 'claude-haiku-4-5'])(
        'MI monotonic at 1%% resolution for %s',
        (modelId) => {
            const cw = 200000;
            let prevMI = null;

            for (let pct = 0; pct <= 100; pct++) {
                const used = Math.floor(pct / 100 * cw);
                const result = computeMI(used, cw, modelId);

                if (prevMI !== null) {
                    expect(result.mi).toBeLessThanOrEqual(prevMI + 1e-9);
                }
                prevMI = result.mi;
            }
        }
    );
});

// --- MI reflects context zones ---

describe('MI reflects context zones', () => {
    test('smart zone MI > dumb zone MI > wrap up zone MI', () => {
        const cw = 200000;
        const smart = computeMI(Math.floor(0.20 * cw), cw, 'claude-sonnet-4-6');
        const dumb = computeMI(Math.floor(0.60 * cw), cw, 'claude-sonnet-4-6');
        const wrap = computeMI(Math.floor(0.90 * cw), cw, 'claude-sonnet-4-6');

        expect(smart.mi).toBeGreaterThan(dumb.mi);
        expect(dumb.mi).toBeGreaterThan(wrap.mi);
    });

    test('empty context has MI=1.0', () => {
        const cw = 200000;
        const result = computeMI(0, cw, 'claude-opus-4-6');
        expect(result.mi).toBe(1.0);
    });

    test('opus retains higher MI than sonnet at 50% context', () => {
        const cw = 200000;
        const opus = computeMI(cw / 2, cw, 'claude-opus-4-6');
        const sonnet = computeMI(cw / 2, cw, 'claude-sonnet-4-6');
        expect(opus.mi).toBeGreaterThan(sonnet.mi);
    });

    test('all models reach MI=0 at full context', () => {
        const cw = 200000;
        for (const model of ['claude-opus-4-6', 'claude-sonnet-4-6', 'claude-haiku-4-5']) {
            const result = computeMI(cw, cw, model);
            expect(result.mi).toBe(0);
        }
    });

    test('MI spread is 1.0 for all models (0 to full)', () => {
        const cw = 200000;
        for (const model of ['claude-opus-4-6', 'claude-sonnet-4-6', 'claude-haiku-4-5']) {
            const empty = computeMI(0, cw, model);
            const full = computeMI(cw, cw, model);
            expect(empty.mi - full.mi).toBe(1.0);
        }
    });
});

const fs = require('fs');
const path = require('path');
const os = require('os');

// Import rotation function from statusline.js
// The script reads stdin on require, so we mock stdin to prevent hanging
const originalStdin = process.stdin;

// Prevent the script's stdin listener from blocking
jest.spyOn(process.stdin, 'setEncoding').mockImplementation(() => {});
jest.spyOn(process.stdin, 'on').mockImplementation(() => {});

const { maybeRotateStateFile, ROTATION_THRESHOLD, ROTATION_KEEP } = require('../../scripts/statusline.js');

function makeCsvLine(index) {
    return `${1710288000 + index},100,200,300,400,500,600,0.01,10,5,sess-${index},model,/tmp/proj,200000`;
}

describe('maybeRotateStateFile', () => {
    let tmpDir;
    let stateFile;

    beforeEach(() => {
        tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'rotation-test-'));
        stateFile = path.join(tmpDir, 'test.state');
    });

    afterEach(() => {
        fs.rmSync(tmpDir, { recursive: true, force: true });
    });

    test('file below threshold is not rotated', () => {
        const lines = Array.from({ length: 9999 }, (_, i) => makeCsvLine(i));
        fs.writeFileSync(stateFile, lines.join('\n') + '\n');

        maybeRotateStateFile(stateFile);

        const result = fs.readFileSync(stateFile, 'utf8').trim().split('\n');
        expect(result.length).toBe(9999);
    });

    test('file at exactly threshold is not rotated', () => {
        const lines = Array.from({ length: ROTATION_THRESHOLD }, (_, i) => makeCsvLine(i));
        fs.writeFileSync(stateFile, lines.join('\n') + '\n');

        maybeRotateStateFile(stateFile);

        const result = fs.readFileSync(stateFile, 'utf8').trim().split('\n');
        expect(result.length).toBe(ROTATION_THRESHOLD);
    });

    test('file exceeding threshold is truncated to ROTATION_KEEP lines', () => {
        const lines = Array.from({ length: 10001 }, (_, i) => makeCsvLine(i));
        fs.writeFileSync(stateFile, lines.join('\n') + '\n');

        maybeRotateStateFile(stateFile);

        const result = fs.readFileSync(stateFile, 'utf8').trim().split('\n');
        expect(result.length).toBe(ROTATION_KEEP);
    });

    test('retained lines are the most recent', () => {
        const total = 10001;
        const lines = Array.from({ length: total }, (_, i) => makeCsvLine(i));
        fs.writeFileSync(stateFile, lines.join('\n') + '\n');

        maybeRotateStateFile(stateFile);

        const result = fs.readFileSync(stateFile, 'utf8').trim().split('\n');
        // First retained line should be index (total - ROTATION_KEEP)
        expect(result[0]).toContain(`sess-${total - ROTATION_KEEP}`);
        // Last retained line should be the last original line
        expect(result[result.length - 1]).toContain(`sess-${total - 1}`);
    });

    test('non-existent file does not throw', () => {
        expect(() => maybeRotateStateFile('/tmp/nonexistent-rotation-test.state')).not.toThrow();
    });

    test('no temp files remain after rotation', () => {
        const lines = Array.from({ length: 10001 }, (_, i) => makeCsvLine(i));
        fs.writeFileSync(stateFile, lines.join('\n') + '\n');

        maybeRotateStateFile(stateFile);

        const tmpFiles = fs.readdirSync(tmpDir).filter(f => f.endsWith('.tmp'));
        expect(tmpFiles.length).toBe(0);
    });
});

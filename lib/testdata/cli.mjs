import { parseArgs } from 'node:util';
import * as fs from 'node:fs';
import * as path from 'node:path';
import engine from './engine.mjs';
import * as primitives from './primitives.mjs';

const { values, positionals } = parseArgs({
    allowPositionals: true,
    options: {
        output: { type: 'string', short: 'o' },
        help: { type: 'boolean', short: 'h' },
    },
});

if (values.help || positionals.length === 0) {
    console.log('Usage: nbt testdata <config.yaml> [options]');
    console.log('Options:');
    console.log('  -o, --output <file>  Write output to file');
    process.exit(0);
}

const configPath = positionals[0];
const absoluteConfigPath = path.resolve(process.cwd(), configPath);

try {
    const output = await engine.execute(absoluteConfigPath, {});

    if (values.output) {
        fs.writeFileSync(values.output, output);
        console.log(`Wrote: ${values.output}`);
    } else {
        console.log(output);
    }
} catch (err) {
    console.error("Error generating test data:", err.message);
    process.exit(1);
} finally {
    await primitives.destroy();
}

/**
 * Build the non-default renderer variants into dist/<backend>/.
 *
 * Every sample hard-codes one backend, so the plain build publishes only that. This publishes the
 * others alongside it, which is what makes the gallery's backend chips real links rather than
 * decoration — the same scene, actually running on Canvas, WebGPU, or the DOM.
 *
 * Two things keep this cheap. Asset URLs are root-absolute, so variants set `publicDir: false` and
 * share the single asset copy the default build emitted rather than duplicating it per backend.
 * And a variant only includes samples that actually have that `render.<backend>.ts`, so nothing
 * gets published under /canvas/ that is secretly still WebGL.
 *
 * Run after `npm run build` — variants write into its output directory.
 *
 *   npm run build:renderers
 */
import { execFileSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, readdirSync, renameSync, rmSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const tsDir = resolve(here, '..');
const srcDir = join(tsDir, 'src');

const samples = readdirSync(srcDir, { withFileTypes: true })
  .filter((e) => e.isDirectory() && existsSync(join(srcDir, e.name, 'index.html')))
  .map((e) => e.name);

/** The backend `render.ts` re-exports; it is already published at the top level. */
function primaryFor(sample: string): string | null {
  const entry = join(srcDir, sample, 'render.ts');
  if (!existsSync(entry)) return null;
  return /render\.([a-z0-9]+)'/.exec(readFileSync(entry, 'utf8'))?.[1] ?? null;
}

const coverage = new Map<string, string[]>();
for (const sample of samples) {
  const primary = primaryFor(sample);
  for (const f of readdirSync(join(srcDir, sample))) {
    const backend = /^render\.([a-z0-9]+)\.ts$/.exec(f)?.[1];
    if (!backend || backend === primary) continue;
    coverage.set(backend, [...(coverage.get(backend) ?? []), sample]);
  }
}

if (coverage.size === 0) {
  console.log('no alternate renderers to build');
  process.exit(0);
}

if (!existsSync(join(tsDir, 'dist'))) {
  console.error('build:renderers: dist/ is missing — run `npm run build` first.');
  process.exit(1);
}

for (const [backend, covered] of [...coverage].sort()) {
  process.stdout.write(`  ${backend.padEnd(8)} ${covered.length} samples ... `);
  try {
    execFileSync('npx', ['vite', 'build', '--logLevel', 'error'], {
      cwd: tsDir,
      env: { ...process.env, RENDERER: backend },
      stdio: 'pipe',
    });
    // Vite lays a variant out as dist/<backend>/<sample>/, but the published URL is
    // /<sample>/<backend>/ so that truncating it lands on the sample rather than a dead path.
    // Chunk references are absolute (base=/<backend>/), so the HTML still resolves after moving.
    const stage = join(tsDir, 'dist', backend);
    for (const sample of covered) {
      const from = join(stage, sample);
      if (!existsSync(from)) continue;
      const to = join(tsDir, 'dist', sample, backend);
      rmSync(to, { recursive: true, force: true });
      mkdirSync(join(tsDir, 'dist', sample), { recursive: true });
      renameSync(from, to);
    }
    console.log('ok');
  } catch {
    console.log('FAILED');
  }
}

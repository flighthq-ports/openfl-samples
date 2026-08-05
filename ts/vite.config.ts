import { cpSync, readdirSync, existsSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { defineConfig, type Plugin } from 'vite';

const here = dirname(fileURLToPath(import.meta.url));
const srcDir = resolve(here, 'src');
const outDir = resolve(here, 'dist');

/**
 * Every directory under src/ that has an index.html is a sample. No denylist, no registry — the
 * filesystem is the list. (thumbs/ lives here too but has no index.html, so it is excluded.)
 */
export function listSamples(): string[] {
  return readdirSync(srcDir, { withFileTypes: true })
    .filter((e) => e.isDirectory() && existsSync(resolve(srcDir, e.name, 'index.html')))
    .map((e) => e.name)
    .sort();
}

/** A sample supports a backend iff the file exists — nothing declares it anywhere else. */
export function hasRenderer(sample: string, renderer: string): boolean {
  return existsSync(resolve(srcDir, sample, `render.${renderer}.ts`));
}

/**
 * Each sample hard-codes its renderer via `render.ts` re-exporting one `render.<backend>.ts`,
 * which is what lets Rollup drop every backend the sample never registered. Setting RENDERER
 * redirects that single import so the other backends can be built without editing a sample —
 * each build still tree-shakes against exactly one set of opt-ins.
 */
function selectRenderer(renderer?: string): Plugin {
  return {
    name: 'flight-renderer-select',
    enforce: 'pre',
    async resolveId(source, importer) {
      if (!renderer || !importer || source !== './render') return null;
      const hit = await this.resolve(`./render.${renderer}`, importer, { skipSelf: true });
      return hit?.id ?? null;
    },
  };
}

/**
 * Every page gets a <base href> so the relative URLs in sample code resolve against the site root
 * rather than the page's own depth. Samples live at /<sample>/ and their variants a level deeper at
 * /<sample>/<backend>/, and on GitHub Pages the whole site hangs off /<repo>/ -- one base tag makes
 * `images/openfl.png` correct in all of those without the samples knowing where they are deployed.
 */
function injectBase(sitePath: string): Plugin {
  return {
    name: 'flight-base-href',
    transformIndexHtml: {
      order: 'post',
      handler(html, ctx) {
        // A base tag governs the page's own <script src="./app.ts"> as well, and Vite leaves that
        // relative in dev — so anchor it to the page's own directory first, or every module 404s
        // at the site root. In a build Vite has already swapped it for an absolute chunk URL, so
        // the rewrite matches nothing and is a no-op.
        const dir = sitePath + ctx.path.replace(/^\//, '').replace(/index\.html$/, '');
        const anchored = html.replace(/src="\.\/([^"]+)"/g, `src="${dir}$1"`);
        return anchored.replace('<head>', `<head>\n    <base href="${sitePath}" />`);
      },
    },
  };
}

/** thumbs/ is generated for publishing and gitignored; copy it into the build when it exists. */
function copyThumbs(): Plugin {
  return {
    name: 'flight-copy-thumbs',
    apply: 'build',
    closeBundle() {
      const from = resolve(srcDir, 'thumbs');
      if (existsSync(from)) cpSync(from, resolve(outDir, 'thumbs'), { recursive: true });
    },
  };
}

/** sizes.json is generated for publishing and gitignored; the gallery fetches it if it is there. */
function copySizes(): Plugin {
  return {
    name: 'flight-copy-sizes',
    apply: 'build',
    closeBundle() {
      const from = resolve(srcDir, 'sizes.json');
      if (existsSync(from)) cpSync(from, resolve(outDir, 'sizes.json'));
    },
  };
}

/**
 * Renderer variants only exist once they are built, so in dev a chip link like /canvas/<sample>/
 * would otherwise fall through to Vite's HTML fallback and quietly re-serve the gallery. Say what
 * is actually going on instead.
 */
function explainVariantsInDev(): Plugin {
  return {
    name: 'flight-explain-variants',
    apply: 'serve',
    configureServer(server) {
      server.middlewares.use((req, res, next) => {
        const path = (req.url ?? '').split('?')[0];
        const match = /^\/([a-z0-9][a-z0-9-]*)\/([a-z0-9]+)\/?$/.exec(path);
        if (!match) return next();
        const [, sample, backend] = match;
        if (!hasRenderer(sample, backend)) return next();
        res.statusCode = 200;
        res.setHeader('content-type', 'text/html; charset=utf-8');
        res.end(
          `<!doctype html><meta charset="utf-8"><title>${backend} — dev</title>` +
            `<style>body{margin:0;padding:3rem 1.5rem;background:#131417;color:#e8eaed;` +
            `font:15px/1.6 ui-sans-serif,system-ui,sans-serif}main{max-width:34rem;margin:0 auto}` +
            `code{background:#24272d;padding:.15rem .4rem;border-radius:.25rem;` +
            `font-family:ui-monospace,monospace}a{color:#7fb2ff}</style>` +
            `<main><h1>Not built in dev</h1>` +
            `<p>The <code>${backend}</code> variant of <code>${sample}</code> is a build artifact — ` +
            `the dev server runs one backend at a time.</p>` +
            `<p>To see this sample on <code>${backend}</code>:</p>` +
            `<p><code>RENDERER=${backend} npm run dev</code> &nbsp;then open ` +
            `<a href="/${sample}/">/${sample}/</a></p>` +
            `<p>Or build everything: <code>npm run dist</code></p>` +
            `<p><a href="/">← back to the gallery</a></p></main>`,
        );
      });
    },
  };
}

export default defineConfig(() => {
  // GitHub Pages serves a project site from /<repo>/, so the deployed base is not the domain root.
  // BASE_PATH is set by the publish workflow; locally it stays '/'.
  const sitePath = process.env.BASE_PATH ?? '/';

  const renderer = process.env.RENDERER;

  // Building one sample alone is what makes a per-sample bundle size meaningful; with every entry
  // in the graph, Rollup shares chunks across samples and the total describes the gallery rather
  // than any one program. `npm run sizes` sets this per build.
  const single = process.env.SAMPLE;

  // A RENDERER build is a variant: it goes to dist/<renderer>/ and covers only the samples that
  // actually have that backend. Without the filter, a sample lacking render.canvas.ts would fall
  // through to its default and get published under /canvas/ while really being WebGL.
  const variant = Boolean(renderer);

  let names = listSamples();
  if (renderer) names = names.filter((s) => hasRenderer(s, renderer));
  if (single) names = names.filter((s) => s === single);

  const entries = Object.fromEntries(names.map((s) => [s, resolve(srcDir, s, 'index.html')]));
  // Vite types this as `string | false`; a bare ternary widens to boolean and fails to match.
  // Measurement builds skip the asset copy too -- `npm run sizes` runs 64 of them and only reads
  // the emitted JS, so copying 11 MB each time is pure waste.
  const publicDir: string | false = variant || single ? false : resolve(here, '../assets');
  // The gallery only belongs in the default build; variants are just the samples.
  const input = single || variant ? entries : { index: resolve(srcDir, 'index.html'), ...entries };

  return {
    // src/ is the web root, so a sample is served at /<name>/ rather than /src/<name>/ — the
    // directory layout should not show up in the URL a visitor sees.
    root: srcDir,
    base: variant ? `${sitePath}${renderer}/` : sitePath,
    // Assets are referenced by root-absolute URL, so variant builds share the single copy emitted
    // by the default build instead of duplicating 11 MB four times over.
    publicDir,
    plugins: [
      injectBase(sitePath),
      selectRenderer(renderer),
      explainVariantsInDev(),
      copyThumbs(),
      copySizes(),
    ],
    build: {
      target: 'es2022',
      outDir: variant ? resolve(outDir, renderer!) : outDir,
      // Variants are written into the default build's output, so they must not wipe it.
      emptyOutDir: !variant,
      rollupOptions: { input },
    },
  };
});

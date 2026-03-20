import { cpSync, mkdtempSync, mkdirSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { execFileSync } from 'node:child_process';

const repoRoot = new URL('..', import.meta.url).pathname;
const tempRoot = mkdtempSync(join(tmpdir(), 'cgt2026-upstream-'));

const sparsePatterns = [
  'meta',
  'by_geography',
  'by_industry',
  '/docs/states-10m.json',
  '/docs/us-counties-2023-topo.json',
  '/docs/us-counties-2023.json',
  '/docs/rmi_logo_dark.svg',
  '/docs/rmi_logo_white.svg',
];

function run(command, args, cwd = repoRoot) {
  execFileSync(command, args, {
    cwd,
    stdio: 'inherit',
  });
}

try {
  run('git', ['clone', '--depth', '1', '--filter=blob:none', '--sparse', 'https://github.com/bsf-rmi/RMI_Clean_Growth_Tool.git', tempRoot], repoRoot);
  run('git', ['-C', tempRoot, 'sparse-checkout', 'set', '--no-cone', ...sparsePatterns], repoRoot);

  mkdirSync(join(repoRoot, 'public', 'data', 'topology'), { recursive: true });
  mkdirSync(join(repoRoot, 'public', 'data', 'branding'), { recursive: true });

  cpSync(join(tempRoot, 'meta'), join(repoRoot, 'public', 'data', 'meta'), { force: true, recursive: true });
  cpSync(join(tempRoot, 'by_geography'), join(repoRoot, 'public', 'data', 'by_geography'), { force: true, recursive: true });
  cpSync(join(tempRoot, 'by_industry'), join(repoRoot, 'public', 'data', 'by_industry'), { force: true, recursive: true });
  cpSync(join(tempRoot, 'docs', 'states-10m.json'), join(repoRoot, 'public', 'data', 'topology', 'states-10m.json'), { force: true });
  cpSync(join(tempRoot, 'docs', 'us-counties-2023-topo.json'), join(repoRoot, 'public', 'data', 'topology', 'us-counties-2023-topo.json'), {
    force: true,
  });
  cpSync(join(tempRoot, 'docs', 'us-counties-2023.json'), join(repoRoot, 'public', 'data', 'topology', 'us-counties-2023.json'), { force: true });
  cpSync(join(tempRoot, 'docs', 'rmi_logo_dark.svg'), join(repoRoot, 'public', 'data', 'branding', 'rmi_logo_dark.svg'), { force: true });
  cpSync(join(tempRoot, 'docs', 'rmi_logo_white.svg'), join(repoRoot, 'public', 'data', 'branding', 'rmi_logo_white.svg'), { force: true });
} finally {
  rmSync(tempRoot, { force: true, recursive: true });
}

'use strict'

const assert = require('node:assert/strict')
const { test, after } = require('node:test')
const fs = require('node:fs')
const os = require('node:os')
const path = require('node:path')
const { spawnSync } = require('node:child_process')

const PROJECT_ROOT = path.join(__dirname, '..')
const SCRIPT_PATH = path.join(PROJECT_ROOT, 'bin', 'omarchy-install-predator-rgb')
const PIN_PATH = path.join(PROJECT_ROOT, 'udev', 'pinned-digests.sha256')
const SCRIPT_SOURCE = fs.readFileSync(SCRIPT_PATH, 'utf8')

const KERNEL_RELEASE = '6.9.1-arch1-test'
const BASH = findExecutable('bash')
const REAL_TOOLS = [
  'awk',
  'basename',
  'cat',
  'chmod',
  'cut',
  'dirname',
  'grep',
  'mkdir',
  'mktemp',
  'rm',
  'cp', 'sha256sum',
  'tr',
]

const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'predator-rgb-installer-'))
let sandboxSequence = 0

after(() => fs.rmSync(tempRoot, { recursive: true, force: true }))

function findExecutable(name) {
  for (const directory of (process.env.PATH || '').split(':')) {
    const candidate = path.join(directory, name)
    try {
      fs.accessSync(candidate, fs.constants.X_OK)
      if (fs.statSync(candidate).isFile()) return candidate
    } catch {
      // Not this one; keep looking.
    }
  }
  return null
}

function writeStub(filePath, body) {
  fs.writeFileSync(filePath, `#!/usr/bin/env bash\n${body}`)
  fs.chmodSync(filePath, 0o755)
}

function createSandbox(options = {}) {
  const settings = {
    headers: true,
    swapHelper: false,
    corruptModule: false,
    sudoUser: 'tester',
    pkexecUid: '0',
    groups: 'sys video',
    omarchy: false,
    tamperedUdev: false,
    ...options,
  }

  sandboxSequence += 1
  const base = path.join(tempRoot, `sandbox-${sandboxSequence}`)
  const binDir = path.join(base, 'bin')
  const pluginDir = path.join(base, 'plugin')
  const logDir = path.join(base, 'logs')
  const runDir = path.join(base, 'run')
  const moduleDest = path.join(base, 'lib/modules', KERNEL_RELEASE, 'extra', 'acer_rgb.ko')
  const helperDest = path.join(base, 'usr/libexec/acer-rgb-set-perms')
  const rulesDest = path.join(base, 'etc/udev/rules.d/90-acer-rgb.rules')
  const statePath = path.join(base, 'var/lib/predator-rgb/installed-module.sha256')
  const modulesLoadPath = path.join(base, 'etc/modules-load.d/acer_rgb.conf')

  fs.mkdirSync(binDir, { recursive: true })
  fs.mkdirSync(logDir, { recursive: true })
  fs.mkdirSync(runDir, { recursive: true })
  fs.mkdirSync(path.join(base, 'etc/modules-load.d'), { recursive: true })
  fs.mkdirSync(path.join(base, 'var/lib'), { recursive: true })
  fs.mkdirSync(path.join(pluginDir, 'bin'), { recursive: true })
  fs.mkdirSync(path.join(pluginDir, 'udev'), { recursive: true })
  fs.mkdirSync(path.join(pluginDir, 'kernel-module/src'), { recursive: true })

  for (const tool of [...REAL_TOOLS, 'bash', 'env', 'rsync']) {
    const candidate = findExecutable(tool)
    assert.ok(candidate, `required tool not found on PATH: ${tool}`)
    fs.symlinkSync(candidate, path.join(binDir, tool))
  }

  for (const name of ['90-acer-rgb.rules', 'acer-rgb-set-perms', 'pinned-digests.sha256']) {
    fs.copyFileSync(path.join(PROJECT_ROOT, 'udev', name), path.join(pluginDir, 'udev', name))
  }
  fs.writeFileSync(path.join(pluginDir, 'kernel-module/src/acer_rgb.c'), '/* module source */\n')
  fs.writeFileSync(path.join(pluginDir, 'kernel-module/Makefile'), 'obj-m += src/acer_rgb.o\n')

  if (settings.tamperedUdev) {
    fs.appendFileSync(path.join(pluginDir, 'udev/acer-rgb-set-perms'), '\n# tampered\n')
  }

  // The system paths are absolute, so the sandbox redirects them into its own
  // tree. The generic rewrites come first; they also cover MODULE_DEST and the
  // kernel header lookup, which build their paths from /lib/modules.
  const script = path.join(pluginDir, 'bin/omarchy-install-predator-rgb')
  fs.writeFileSync(
    script,
    SCRIPT_SOURCE.replaceAll('/lib/modules/', `${base}/lib/modules/`)
      .replaceAll('/sys/module/', `${path.join(base, 'sys/module')}/`)
      .replaceAll('/sys/devices/platform/acer_rgb', path.join(base, 'sys/devices/platform/acer_rgb'))
      .replaceAll('/etc/modules-load.d/', `${path.join(base, 'etc/modules-load.d')}/`)
      .replaceAll('/etc/udev/rules.d/90-acer-rgb.rules', rulesDest)
      .replaceAll('/usr/libexec/acer-rgb-set-perms', helperDest)
      .replaceAll('/var/lib/predator-rgb', path.join(base, 'var/lib/predator-rgb'))
      .replace(/^SCRIPT_PATH=.*$/m, `SCRIPT_PATH="$0"`)
      .replace(/^SCRIPT_DIR=.*$/m, `SCRIPT_DIR="${path.join(pluginDir, 'bin')}"`)
      .replace(/^KERNEL_RELEASE=.*$/m, `KERNEL_RELEASE="${KERNEL_RELEASE}"`)
      .replace(/^STAGING_PREFIX=.*$/m, `STAGING_PREFIX="${runDir}"`)
      // The stubs cannot actually raise privileges, so require_root would hand
      // the script straight back to sudo or pkexec and loop forever. It is
      // neutralised here and asserted separately at the source level; the tests
      // below exercise what runs once privileges are held.
      .replaceAll(
        'require_root "$@"',
        'export SUDO_USER="$TEST_SUDO_USER" PKEXEC_UID="$TEST_PKEXEC_UID"'
      )
  )
  fs.chmodSync(script, 0o755)

  writeStub(
    path.join(binDir, 'sudo'),
    `
echo "sudo $*" >> "$TEST_LOG_DIR/sudo.log"
if [ "$1" = "-u" ]; then
  shift 2
  [ "$1" = "--" ] && shift
  exec "$@"
fi
exec "$@"
`
  )

  writeStub(path.join(binDir, 'pkexec'), `echo "pkexec $*" >> "$TEST_LOG_DIR/pkexec.log"\nexec "$@"\n`)

  writeStub(
    path.join(binDir, 'make'),
    `
echo "$*" >> "$TEST_LOG_DIR/make.log"
build_dir=""
for arg in "$@"; do
  case "$arg" in BUILD_DIR=*) build_dir="\${arg#BUILD_DIR=}" ;; esac
done
if [ -z "$build_dir" ]; then
  echo "make: BUILD_DIR was not passed" >&2
  exit 1
fi
mkdir -p "$build_dir/src"
printf 'fake acer_rgb module\\n' > "$build_dir/src/acer_rgb.ko"
`
  )

  writeStub(
    path.join(binDir, 'install'),
    `
set -euo pipefail
echo "$*" >> "$TEST_LOG_DIR/install.log"
mode=""
src=""
dst=""
while [ $# -gt 0 ]; do
  case "$1" in
    -m) mode="$2"; shift 2 ;;
    -o|-g) shift 2 ;;
    -T) shift ;;
    *) if [ -z "$src" ]; then src="$1"; else dst="$1"; fi; shift ;;
  esac
done
# Simulates a process running as the same user rewriting the source after the
# digest was decided but before root copies it into root-only storage.
if [ "$TEST_SWAP_HELPER" = "1" ] && case "$dst" in *set-perms) true ;; *) false ;; esac; then
  printf '#!/bin/sh\\nchmod 0777 /\\n' > "$src"
fi
mkdir -p "$(dirname "$dst")"
cp "$src" "$dst"
chmod "$mode" "$dst"
# Simulates a process corrupting the destination after it was installed, which
# the post-install digest re-read is meant to catch.
if [ "$TEST_CORRUPT_MODULE" = "1" ] && [ "$mode" = "0644" ] && case "$dst" in *acer_rgb.ko) true ;; *) false ;; esac; then
  printf 'corrupted\n' >> "$dst"
fi
`
  )

  writeStub(
    path.join(binDir, 'uname'),
    `
if [ "$1" = "-r" ]; then
  if [ "$TEST_HEADERS" = "1" ]; then echo "$TEST_KERNEL_RELEASE"; else echo "0.0.0-no-headers"; fi
else
  echo "$TEST_KERNEL_RELEASE"
fi
`
  )

  writeStub(
    path.join(binDir, 'getent'),
    `
case "$1" in
  group)
    if [ "$2" = "$TEST_GROUP" ]; then echo "$TEST_GROUP:x:1000:"; else exit 2; fi
    ;;
  passwd)
    echo "tester:x:1000:1000::/home/tester:/bin/bash"
    ;;
  *) exit 2 ;;
esac
`
  )

  writeStub(
    path.join(binDir, 'id'),
    `
case "$1" in
  -nG) echo "$TEST_GROUPS" ;;
  -un) echo "tester" ;;
  *) exit 1 ;;
esac
`
  )

  for (const [name, logName] of [
    ['modprobe', 'modprobe.log'],
    ['depmod', 'depmod.log'],
    ['udevadm', 'udevadm.log'],
    ['groupadd', 'groupadd.log'],
    ['groupdel', 'groupdel.log'],
    ['usermod', 'usermod.log'],
    ['gpasswd', 'gpasswd.log'],
  ]) {
    writeStub(path.join(binDir, name), `echo "$*" >> "$TEST_LOG_DIR/${logName}"\n`)
  }

  if (settings.omarchy) {
    writeStub(path.join(binDir, 'omarchy'), `echo "$*" >> "$TEST_LOG_DIR/omarchy.log"\n`)
  }

  if (settings.headers) {
    fs.mkdirSync(path.join(base, 'lib/modules', KERNEL_RELEASE, 'build'), { recursive: true })
  }

  const env = {
    PATH: binDir,
    HOME: base,
    TEST_BASH: BASH,
    TEST_SCRIPT: script,
    TEST_LOG_DIR: logDir,
    TEST_KERNEL_RELEASE: KERNEL_RELEASE,
    TEST_SUDO_USER: settings.sudoUser,
    TEST_PKEXEC_UID: settings.pkexecUid,
    TEST_SWAP_HELPER: settings.swapHelper ? '1' : '',
    TEST_CORRUPT_MODULE: settings.corruptModule ? '1' : '',
    TEST_HEADERS: settings.headers ? '1' : '',
    TEST_GROUPS: settings.groups,
    TEST_GROUP: 'acer_rgb',
  }

  return {
    base,
    logDir,
    moduleDest,
    helperDest,
    rulesDest,
    statePath,
    modulesLoadPath,
    log(name) {
      const file = path.join(logDir, name)
      return fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : null
    },
    run(args) {
      const result = spawnSync(BASH, [script, ...args], { encoding: 'utf8', env })
      if (result.error) throw result.error
      return { status: result.status, stdout: result.stdout, stderr: result.stderr }
    },
  }
}

test('the udev files match the digests pinned in version control', () => {
  const result = spawnSync('sha256sum', ['--check', '--strict', PIN_PATH], {
    cwd: path.join(PROJECT_ROOT, 'udev'),
    encoding: 'utf8',
  })
  assert.equal(result.status, 0, result.stdout + result.stderr)
})

test('the Makefile has no target that writes to a system path', () => {
  const makefile = fs.readFileSync(path.join(PROJECT_ROOT, 'kernel-module', 'Makefile'), 'utf8')
  const recipes = makefile
    .split('\n')
    .filter((line) => /^\t/.test(line) && !/^\t@(?:mkdir|rsync|case|\s)/.test(line) && !/^\t\s*(echo|\*|esac)/.test(line))
    .join('\n')

  for (const systemPath of ['/lib/modules', '/etc/', '/usr/']) {
    assert.ok(
      !recipes.includes(systemPath),
      `the Makefile compiles into a system path (${systemPath}), which would make make privileged`
    )
  }
  assert.ok(!/^install:/m.test(makefile), 'the Makefile must not define an install target')
  assert.ok(!/^uninstall:/m.test(makefile), 'the Makefile must not define an uninstall target')

  // A fixed build directory is the bug this replaced: /tmp/acer-rgb-build could
  // be pre-created by another local user as a symlink and written through.
  const assignment = makefile.match(/^BUILD_DIR\s*:?=.*$/m)
  assert.ok(assignment, 'the Makefile must set a default build directory')
  assert.match(
    assignment[0],
    /\$\(shell\s+mktemp\s+-d\b/,
    `the default build directory must come from mktemp, got: ${assignment[0]}`
  )
  assert.doesNotMatch(
    assignment[0],
    /\/tmp\/|\/var\/tmp\/|\$\(CURDIR\)/,
    `the default build directory must not be a predictable path, got: ${assignment[0]}`
  )
})

test('bin/omarchy-install-predator-rgb', async (t) => {
  await t.test('builds the module as the invoking user, never as root', () => {
    const sandbox = createSandbox()
    const result = sandbox.run(['--install'])

    assert.equal(result.status, 0, result.stderr)
    assert.match(
      sandbox.log('sudo.log'),
      /-u tester -- bash -c/,
      'the build must run as the invoking user through sudo -u'
    )
    assert.match(sandbox.log('make.log'), /BUILD_DIR=\S*acer-rgb-build\./, 'the build needs an unpredictable build dir')
    assert.doesNotMatch(sandbox.log('make.log'), /BUILD_DIR=\/tmp\/acer-rgb-build$/m, 'the build dir must not be a fixed path')
  })

  await t.test('stages the module in root-only storage and installs from the copy', () => {
    const sandbox = createSandbox()
    const result = sandbox.run(['--install'])

    assert.equal(result.status, 0, result.stderr)
    const installLog = sandbox.log('install.log')
    // install logs "-T <source> <destination>", so the staged copy is the
    // destination of the 0600 call and the source of the 0644 call.
    const staged = installLog.match(/^-m 0600 .*-T \S+ (\S*\/run\.[^ ]*\/acer_rgb\.ko)$/m)

    assert.ok(staged, `the module must be copied into root-only storage first:\n${installLog}`)
    const stagedPath = staged[1]
    assert.ok(
      installLog.includes(`-m 0644 -o root -g root -T ${stagedPath} ${sandbox.moduleDest}`),
      'the install must read the staged copy, not the build output'
    )
    assert.ok(fs.existsSync(sandbox.moduleDest))
    assert.equal(
      fs.readFileSync(sandbox.moduleDest, 'utf8'),
      'fake acer_rgb module\n',
      'the installed module must be the staged bytes'
    )
  })

  await t.test('removes the staging directory after the install', () => {
    const sandbox = createSandbox()
    const result = sandbox.run(['--install'])

    assert.equal(result.status, 0, result.stderr)
    assert.deepEqual(
      fs.readdirSync(sandbox.base).filter((entry) => entry.startsWith('run.')),
      [],
      'the staged copies must not outlive the install'
    )
  })

  await t.test('refuses a udev file that does not match the pinned digest', () => {
    const sandbox = createSandbox({ tamperedUdev: true })
    const result = sandbox.run(['--install'])

    assert.equal(result.status, 1, result.stderr)
    assert.match(result.stderr, /do not match the digests pinned/)
    assert.equal(fs.existsSync(sandbox.moduleDest), false, 'nothing may be installed')
    assert.equal(fs.existsSync(sandbox.helperDest), false, 'the root-executed helper must never be installed')
  })

  await t.test('refuses a udev helper substituted between staging and install', () => {
    const sandbox = createSandbox({ swapHelper: true })
    const result = sandbox.run(['--install'])

    assert.equal(result.status, 1, result.stderr)
    assert.match(result.stderr, /staged udev files do not match the pinned digests/)
    assert.equal(fs.existsSync(sandbox.helperDest), false, 'the substituted helper must never reach /usr/libexec')
    assert.doesNotMatch(sandbox.log('install.log'), /-m 0755/, 'the helper must not be installed once staging fails')
  })

  await t.test('removes an installed module that does not match the staged copy', () => {
    const sandbox = createSandbox({ corruptModule: true })
    const result = sandbox.run(['--install'])

    assert.equal(result.status, 1, result.stderr)
    assert.match(result.stderr, /installed module does not match the staged copy/)
    assert.equal(
      fs.existsSync(sandbox.moduleDest),
      false,
      'a module that failed the re-check must not be left loadable at boot'
    )
  })

  await t.test('records the digest of what was installed', () => {
    const sandbox = createSandbox()
    const result = sandbox.run(['--install'])

    assert.equal(result.status, 0, result.stderr)
    const recorded = fs.readFileSync(sandbox.statePath, 'utf8')
    const actual = spawnSync('sha256sum', [sandbox.moduleDest], { encoding: 'utf8' }).stdout

    assert.equal(recorded.split(/\s+/)[0], actual.split(/\s+/)[0])
  })

  await t.test('adds the invoking user to the group and loads the module at boot', () => {
    const sandbox = createSandbox()
    const result = sandbox.run(['--install'])

    assert.equal(result.status, 0, result.stderr)
    assert.match(sandbox.log('usermod.log'), /-aG acer_rgb tester/)
    assert.equal(fs.readFileSync(sandbox.modulesLoadPath, 'utf8').trim(), 'acer_rgb')
    assert.match(sandbox.log('modprobe.log'), /^acer_rgb$/m)
  })

  await t.test('does not re-add a user who is already in the group', () => {
    const sandbox = createSandbox({ groups: 'sys video acer_rgb' })
    const result = sandbox.run(['--install'])

    assert.equal(result.status, 0, result.stderr)
    assert.equal(sandbox.log('usermod.log'), null)
    assert.match(result.stdout, /already in the acer_rgb group/)
  })

  await t.test('refuses to install as root when there is no invoking user', () => {
    const sandbox = createSandbox({ sudoUser: '' })
    const result = sandbox.run(['--install'])

    assert.equal(result.status, 1, result.stderr)
    assert.match(result.stderr, /cannot tell which user to build as/)
    assert.equal(sandbox.log('make.log'), null, 'a root shell must never be used to build')
  })

  await t.test('refuses when the kernel headers are missing', () => {
    const sandbox = createSandbox({ headers: false })
    const result = sandbox.run(['--install'])

    assert.equal(result.status, 1, result.stderr)
    assert.match(result.stderr, /Kernel headers not found/)
    assert.equal(sandbox.log('make.log'), null)
  })

  await t.test('uninstall removes the module, the rules and the group membership', () => {
    const sandbox = createSandbox({ groups: 'sys video acer_rgb' })
    const installed = sandbox.run(['--install'])
    assert.equal(installed.status, 0, installed.stderr)

    const removed = sandbox.run(['--uninstall'])

    assert.equal(removed.status, 0, removed.stderr)
    assert.equal(fs.existsSync(sandbox.moduleDest), false)
    assert.equal(fs.existsSync(sandbox.helperDest), false)
    assert.equal(fs.existsSync(sandbox.rulesDest), false)
    assert.equal(fs.existsSync(sandbox.modulesLoadPath), false)
    assert.equal(fs.existsSync(sandbox.statePath), false)
    assert.match(
      sandbox.log('gpasswd.log'),
      /-d tester acer_rgb/,
      'the group membership granted for the sysfs access must be revoked'
    )
  })

  await t.test('uninstall is a no-op when nothing was installed', () => {
    const sandbox = createSandbox()
    const result = sandbox.run(['--uninstall'])

    assert.equal(result.status, 0, result.stderr)
    assert.match(result.stdout, /removed/)
  })

  await t.test('check reports the module state and the pinned digests', () => {
    const sandbox = createSandbox()
    const result = sandbox.run(['--check'])

    assert.equal(result.status, 0, result.stderr)
    assert.match(result.stdout, /Kernel headers found for/)
    assert.match(result.stdout, /Module NOT installed/)
    assert.match(result.stdout, /udev files match the pinned digests/)
  })

  await t.test('check fails when a udev file drifted from its pin', () => {
    const sandbox = createSandbox({ tamperedUdev: true })
    const result = sandbox.run(['--check'])

    assert.equal(result.status, 1)
    assert.match(result.stderr, /do not match the digests pinned/)
  })

  await t.test('prints usage for an unknown or missing flag', () => {
    const sandbox = createSandbox()
    for (const args of [[], ['--nope']]) {
      const result = sandbox.run(args)
      assert.equal(result.status, 1)
      assert.match(result.stdout + result.stderr, /Usage: omarchy-install-predator-rgb/)
    }
  })
})

'use strict'

const assert = require('node:assert/strict')
const { test } = require('node:test')
const fs = require('node:fs')
const path = require('node:path')

const root = path.join(__dirname, '..')

function manifestVersion() {
  const manifest = JSON.parse(fs.readFileSync(path.join(root, 'manifest.json'), 'utf8'))
  return manifest.version
}

function moduleVersion() {
  const moduleSource = fs.readFileSync(path.join(root, 'kernel-module', 'src', 'acer_rgb.c'), 'utf8')
  const match = moduleSource.match(/^MODULE_VERSION\("([^"]+)"\)/m)
  assert.ok(match, 'kernel-module/src/acer_rgb.c must declare MODULE_VERSION')
  return match[1]
}

function bootstrapUrls() {
  const script = fs.readFileSync(path.join(root, 'bootstrap.sh'), 'utf8')
  return {
    repo: script.match(/^REPO="([^"]+)"/m)?.[1],
    apiUrl: script.match(/^API_URL="([^"]+)"/m)?.[1],
  }
}

test('manifest.json and kernel module declare the same version', () => {
  assert.equal(manifestVersion(), moduleVersion())
})

test('versions are plain semver so release tags resolve to download URLs', () => {
  for (const version of [manifestVersion(), moduleVersion()]) {
    assert.match(version, /^\d+\.\d+\.\d+$/, `unexpected version: ${version}`)
  }
})

test('bootstrap.sh downloads from the correct release channel', () => {
  const urls = bootstrapUrls()
  assert.equal(
    urls.repo,
    'skvggor/predator-rgb-omarchy-plugin'
  )
  assert.match(
    urls.apiUrl,
    /^https:\/\/api\.github\.com\/repos\/skvggor\/predator-rgb-omarchy-plugin\/releases\/latest$/
  )
})
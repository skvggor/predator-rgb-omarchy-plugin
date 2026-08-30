'use strict'

const assert = require('node:assert/strict')
const { test } = require('node:test')

const Model = require('../Model.js')

test('parseAccentHex strips leading hash and lowercases', () => {
  assert.equal(Model.parseAccentHex('#819890'), '819890')
  assert.equal(Model.parseAccentHex('  #FFAA00  '), 'ffaa00')
  assert.equal(Model.parseAccentHex('819890'), '819890')
})

test('parseAccentHex rejects malformed input', () => {
  assert.equal(Model.parseAccentHex(''), '')
  assert.equal(Model.parseAccentHex('nope'), '')
  assert.equal(Model.parseAccentHex('#12345'), '')
  assert.equal(Model.parseAccentHex('#1234567'), '')
  assert.equal(Model.parseAccentHex(undefined), '')
  assert.equal(Model.parseAccentHex(null), '')
  assert.equal(Model.parseAccentHex(123), '')
  assert.equal(Model.parseAccentHex('#GGHHII'), '')
})

test('hexToRgb converts to channel values', () => {
  assert.deepEqual(Model.hexToRgb('#819890'), { red: 129, green: 152, blue: 144 })
  assert.deepEqual(Model.hexToRgb('ff0000'), { red: 255, green: 0, blue: 0 })
  assert.deepEqual(Model.hexToRgb('000000'), { red: 0, green: 0, blue: 0 })
})

test('hexToRgb returns null for invalid input', () => {
  assert.equal(Model.hexToRgb(''), null)
  assert.equal(Model.hexToRgb('zzzzzz'), null)
  assert.equal(Model.hexToRgb(null), null)
  assert.equal(Model.hexToRgb(undefined), null)
  assert.equal(Model.hexToRgb(123), null)
})

test('clampByte clamps values correctly', () => {
  assert.equal(Model.clampByte(0), 0)
  assert.equal(Model.clampByte(128), 128)
  assert.equal(Model.clampByte(255), 255)
  assert.equal(Model.clampByte(256), 255)
  assert.equal(Model.clampByte(-1), 0)
  assert.equal(Model.clampByte(999), 255)
  assert.equal(Model.clampByte('nope'), 0)
  assert.equal(Model.clampByte(NaN), 0)
  assert.equal(Model.clampByte(Infinity), 0)
  assert.equal(Model.clampByte(-Infinity), 0)
  assert.equal(Model.clampByte(undefined), 0)
  assert.equal(Model.clampByte(null), 0)
})

test('rgbPayload builds the static zone write', () => {
  const rgb = Model.hexToRgb('#819890')
  assert.deepEqual(Model.rgbPayload(1, rgb), [1, 129, 152, 144])
  assert.deepEqual(Model.rgbPayload(2, rgb), [2, 129, 152, 144])
  assert.deepEqual(Model.rgbPayload(3, rgb), [4, 129, 152, 144])
  assert.deepEqual(Model.rgbPayload(4, rgb), [8, 129, 152, 144])
})

test('rgbPayload rejects out of range zones', () => {
  const rgb = Model.hexToRgb('#819890')
  assert.deepEqual(Model.rgbPayload(0, rgb), [])
  assert.deepEqual(Model.rgbPayload(5, rgb), [])
  assert.deepEqual(Model.rgbPayload(-1, rgb), [])
  assert.deepEqual(Model.rgbPayload(1, null), [])
  assert.deepEqual(Model.rgbPayload(1, undefined), [])
  assert.deepEqual(Model.rgbPayload('nope', rgb), [])
  assert.deepEqual(Model.rgbPayload(NaN, rgb), [])
})

test('brightnessPayload sets byte 2 and the commit flag', () => {
  const payload = Model.brightnessPayload(100)
  assert.equal(payload.length, 16)
  assert.equal(payload[2], 100)
  assert.equal(payload[9], 1)
  assert.equal(payload[0], 0)
  assert.equal(payload[15], 0)
})

test('brightnessPayload clamps to 0..255', () => {
  assert.equal(Model.brightnessPayload(999)[2], 255)
  assert.equal(Model.brightnessPayload(-1)[2], 0)
  assert.equal(Model.brightnessPayload('nope')[2], 0)
  assert.equal(Model.brightnessPayload(NaN)[2], 0)
  assert.equal(Model.brightnessPayload(Infinity)[2], 0)
})

test('defaultStatus returns expected shape', () => {
  const status = Model.defaultStatus()
  assert.equal(status.ok, true)
  assert.equal(status.available, false)
  assert.equal(status.applied, false)
  assert.equal(status.themeName, '')
  assert.equal(status.accent, '')
})

test('parseStatus returns defaults for empty input', () => {
  assert.deepEqual(Model.parseStatus(''), Model.defaultStatus())
  assert.deepEqual(Model.parseStatus(null), Model.defaultStatus())
  assert.deepEqual(Model.parseStatus(undefined), Model.defaultStatus())
})

test('parseStatus normalizes status payload', () => {
  const parsed = Model.parseStatus(JSON.stringify({
    available: true,
    applied: true,
    themeName: 'dos-moos',
    accent: '#819890'
  }))
  assert.equal(parsed.available, true)
  assert.equal(parsed.applied, true)
  assert.equal(parsed.themeName, 'dos-moos')
  assert.equal(parsed.accent, '819890')
})

test('parseStatus flags invalid JSON', () => {
  const parsed = Model.parseStatus('not json')
  assert.equal(parsed.ok, false)
  assert.equal(parsed.lastError, 'Failed to parse LED status')
})

test('parseStatus keeps real booleans as given', () => {
  const parsed = Model.parseStatus('{"available":false,"accent":"#FF0000"}')
  assert.equal(parsed.available, false)
  assert.equal(parsed.accent, 'ff0000')
})

test('parseStatus handles non-object JSON', () => {
  assert.deepEqual(Model.parseStatus('"just a string"'), Model.defaultStatus())
  assert.deepEqual(Model.parseStatus('123'), Model.defaultStatus())
  assert.deepEqual(Model.parseStatus('null'), Model.defaultStatus())
  assert.deepEqual(Model.parseStatus('[1,2,3]'), Model.defaultStatus())
})

test('parseStatus adds lastError on failure', () => {
  const parsed = Model.parseStatus('invalid')
  assert.equal(parsed.ok, false)
  assert.equal(typeof parsed.lastError, 'string')
  assert.ok(parsed.lastError.length > 0)
})

test('formatThemeName fallback', () => {
  assert.equal(Model.formatThemeName('tokyo-night'), 'tokyo-night')
  assert.equal(Model.formatThemeName(''), 'unknown theme')
  assert.equal(Model.formatThemeName(null), 'unknown theme')
  assert.equal(Model.formatThemeName(undefined), 'unknown theme')
  assert.equal(Model.formatThemeName(123), '123')
  assert.equal(Model.formatThemeName('  trimmed  '), 'trimmed')
})

test('constants are exported', () => {
  assert.equal(Model.DEFAULT_BRIGHTNESS, 100)
  assert.equal(Model.ZONE_COUNT, 4)
})

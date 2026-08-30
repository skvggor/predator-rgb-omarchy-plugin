const DEFAULT_BRIGHTNESS = 100
const ZONE_COUNT = 4

function parseAccentHex(raw) {
  const value = String(raw || "").trim().replace(/^#/, "")
  if (/^[0-9A-Fa-f]{6}$/.test(value)) return value.toLowerCase()
  return ""
}

function hexToRgb(hex) {
  const value = parseAccentHex(hex)
  if (value === "") return null
  return {
    red: parseInt(value.substring(0, 2), 16),
    green: parseInt(value.substring(2, 4), 16),
    blue: parseInt(value.substring(4, 6), 16)
  }
}

function clampByte(value) {
  const number = Number(value)
  if (!isFinite(number)) return 0
  return Math.max(0, Math.min(255, number))
}

function rgbPayload(zone, rgb) {
  const zoneNumber = Number(zone)
  if (!isFinite(zoneNumber) || !rgb || zoneNumber < 1 || zoneNumber > ZONE_COUNT) return []
  const bitmask = 1 << (zoneNumber - 1)
  return [bitmask, clampByte(rgb.red), clampByte(rgb.green), clampByte(rgb.blue)]
}

function brightnessPayload(brightness) {
  const payload = new Array(16).fill(0)
  payload[2] = clampByte(brightness)
  payload[9] = 1
  return payload
}

function defaultStatus() {
  return {
    ok: true,
    available: false,
    applied: false,
    themeName: "",
    accent: ""
  }
}

function parseStatus(raw) {
  const text = String(raw || "").trim()
  if (text === "") return defaultStatus()
  try {
    const parsed = JSON.parse(text)
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return defaultStatus()
    parsed.available = parsed.available === true
    parsed.applied = parsed.applied === true
    parsed.themeName = String(parsed.themeName || "")
    parsed.accent = parseAccentHex(parsed.accent)
    return parsed
  } catch (error) {
    const failed = defaultStatus()
    failed.ok = false
    failed.lastError = "Failed to parse LED status"
    return failed
  }
}

function formatThemeName(raw) {
  const value = String(raw || "").trim()
  if (value === "") return "unknown theme"
  return value
}

if (typeof module !== "undefined") {
  module.exports = {
    DEFAULT_BRIGHTNESS,
    ZONE_COUNT,
    parseAccentHex,
    hexToRgb,
    clampByte,
    rgbPayload,
    brightnessPayload,
    defaultStatus,
    parseStatus,
    formatThemeName
  }
}

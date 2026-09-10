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

function defaultStatus() {
  return {
    ok: true,
    loaded: false,
    available: false,
    installed: false,
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
    parsed.loaded = parsed.loaded === true
    parsed.available = parsed.available === true
    parsed.installed = parsed.installed === true
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
    ZONE_COUNT,
    parseAccentHex,
    hexToRgb,
    defaultStatus,
    parseStatus,
    formatThemeName
  }
}

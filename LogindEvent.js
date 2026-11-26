// Logind sleep and lock event detection (B7, Q14; PrepareForSleep, Session.Lock)

function shouldDismiss(line) {
  var s = String(line || "")
  if (s.indexOf("PrepareForSleep") >= 0 && s.indexOf("true") >= 0) return true
  if (s.indexOf(".Session.Lock") >= 0 || (s.indexOf("member 'Lock'") >= 0 && s.indexOf("org.freedesktop.login1") >= 0)) return true
  return false
}

if (typeof module !== "undefined") module.exports = { shouldDismiss }

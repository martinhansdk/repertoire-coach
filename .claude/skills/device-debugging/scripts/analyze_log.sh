#!/bin/bash
# Analyse a captured device log against the healthy-run sequence and known
# failure signatures. Usage: analyze_log.sh <logfile>
LOG="$1"
[ -f "$LOG" ] || { echo "usage: analyze_log.sh <logfile>" >&2; exit 2; }

step() { # number description pattern
  if grep -qE "$3" "$LOG"; then echo "  [ok] $1. $2"; else echo "  [--] $1. $2  MISSING"; MISS=1; fi
}
echo "=== Healthy-run sequence ==="
MISS=0
step 1 "cold start (Start proc)"           "ActivityManager.*Start proc.*repertoirecoach|Start proc.*repertoire_coach"
step 2 "plugin re-register warning"        "FlutterEngineCxnRegstry.*already registered"
step 3 "media session recognised"          "MediaSessionService.*session is changed"
step 4 "AudioService.init SUCCESS"         "AudioService\.init.*SUCCESS"
step 5 "media notification (actions=3)"    "Notification.*audio.*actions=3"
step 6 "wake lock held"                    "PARTIAL_WAKE_LOCK.*audioservice\.AudioService"
step 7 "playing (MediaTimeout state=3)"    "MediaTimeout.*state=3"
step 8 "audio stream confirmed"            "AS\.AudioService.*is using audio"
[ $MISS -eq 0 ] && echo "  All steps present." || echo "  First missing step above is where the failure begins."

echo; echo "=== Failure signatures ==="
flag() { local n; n=$(grep -cE "$2" "$LOG"); [ "$n" -gt 0 ] && echo "  [!!] $1 (x$n)"; }
flag "wrongEngineDetected / wrong FlutterEngine (see SKILL.md: engine cache)" "wrongEngineDetected|PlatformException.*wrong.*FlutterEngine"
flag "AudioServiceConfig flag inconsistency"                                   "androidNotificationOngoing.*androidStopForegroundOnPause"
flag "process frozen by Samsung (foreground service not protecting us)"       "reezeStateChanged.*repertoire"
flag "AudioService.init FAILED"                                                "AudioService\.init.*FAIL"
flag "service-level kill (adj 1001 - abnormal)"                                "Killing.*repertoire.*adj 1001"

echo; echo "=== Kill events for our package ==="
grep -nE "ActivityManager.*Killing.*repertoire" "$LOG" | tail -5 || echo "  none"

echo; echo "=== Our Dart debug output (flutter :) — last 15 lines ==="
grep -n "flutter :" "$LOG" | tail -15 || echo "  none"

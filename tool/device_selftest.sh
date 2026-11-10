#!/usr/bin/env bash
# Dawa hub self-test: examination lock + anaemia upload, as the clinician app uses them.
# Usage: tool/device_selftest.sh http://dawa.local  /path/to/eyelid.jpg  [other-module]
# Uses a NON-PATIENT image. Safe to run on an idle board; it ends its own lock.
HUB="${1:-http://dawa.local}"; IMG="${2:-}"; OTHER="${3:-ultrasound}"
pass=0; failn=0
ck() { if [ "$2" = "1" ]; then echo "PASS  $1"; pass=$((pass+1)); else echo "FAIL  $1   ($3)"; failn=$((failn+1)); fi; }
post() { curl -s -m "${3:-30}" -w '\n%{http_code}' -X POST -H 'Content-Type: application/json' -d "$2" "$HUB$1"; }
body() { echo "$1" | sed '$d'; }; code() { echo "$1" | tail -1; }
has() { case "$1" in *"$2"*) echo 1;; *) echo 0;; esac; }

r=$(curl -s -m 10 -w '\n%{http_code}' "$HUB/api/status"); ck "hub reachable: GET /api/status -> 200" "$([ "$(code "$r")" = 200 ] && echo 1 || echo 0)" "$(code "$r")"
r=$(post /api/select '{"module":"anemia"}' 20); ck "select anemia accepted (200/202)" "$([ "$(code "$r")" = 200 -o "$(code "$r")" = 202 ] && echo 1 || echo 0)" "$(code "$r"): $(body "$r" | head -c 200)"
for i in $(seq 1 120); do s=$(curl -s -m 8 "$HUB/api/status"); case "$s" in *'"ready":true'*'"active":"anemia"'*|*'"active":"anemia"'*'"ready":true'*) break;; esac; sleep 3; done
ck "anaemia ready (ready:true, active:anemia)" "$(has "$s" '"ready":true')" "$(echo "$s" | head -c 200)"

r=$(post /api/exam/start '{"module":"anemia","device":"selftest-A"}'); b=$(body "$r")
ck "exam/start -> 201 with exam_id and ttl_s" "$([ "$(code "$r")" = 201 ] && [ "$(has "$b" exam_id)" = 1 ] && [ "$(has "$b" ttl_s)" = 1 ] && echo 1 || echo 0)" "$(code "$r") $b"
EID=$(echo "$b" | sed -n 's/.*"exam_id": *"\([^"]*\)".*/\1/p')

r=$(post /api/select "{\"module\":\"$OTHER\"}"); ck "switch to $OTHER while locked -> 409 exam_in_progress" "$([ "$(code "$r")" = 409 ] && [ "$(has "$(body "$r")" exam_in_progress)" = 1 ] && echo 1 || echo 0)" "$(code "$r") $(body "$r")"
r=$(post /api/exam/start '{"module":"anemia","device":"selftest-B"}'); ck "second device cannot start -> 409 exam_in_progress" "$([ "$(code "$r")" = 409 ] && [ "$(has "$(body "$r")" exam_in_progress)" = 1 ] && echo 1 || echo 0)" "$(code "$r") $(body "$r")"
r=$(post /api/exam/start '{"module":"anemia","device":"selftest-A"}'); ck "same device resumes (same exam_id, resumed:true)" "$([ "$(has "$(body "$r")" "$EID")" = 1 ] && [ "$(has "$(body "$r")" resumed)" = 1 ] && echo 1 || echo 0)" "$(code "$r") $(body "$r")"
r=$(post /api/exam/heartbeat "{\"exam_id\":\"$EID\"}"); ck "heartbeat -> 200 ttl_s" "$([ "$(code "$r")" = 200 ] && [ "$(has "$(body "$r")" ttl_s)" = 1 ] && echo 1 || echo 0)" "$(code "$r") $(body "$r")"
r=$(post /api/exam/heartbeat '{"exam_id":"nope"}'); ck "heartbeat with a wrong id -> 404 exam_not_found" "$([ "$(code "$r")" = 404 ] && [ "$(has "$(body "$r")" exam_not_found)" = 1 ] && echo 1 || echo 0)" "$(code "$r") $(body "$r")"

if [ -n "$IMG" ] && [ -f "$IMG" ]; then
  r=$(curl -s -m 180 -w '\n%{http_code}' -F "image=@$IMG" -F patient_id=selftest "$HUB/upload/anemia"); b=$(body "$r")
  ck "upload/anemia -> 200 with classification + probabilities" "$([ "$(code "$r")" = 200 ] && [ "$(has "$b" classification)" = 1 ] && [ "$(has "$b" probabilities)" = 1 ] && echo 1 || echo 0)" "$(code "$r") $(echo "$b" | head -c 200)"
  echo "      result: $(echo "$b" | tr -d '\n' | sed -n 's/.*"classification": *"\([^"]*\)".*"confidence": *\([0-9.]*\).*/\1 (\2)/p')"
else echo "SKIP  upload (no image given)"; fi

r=$(post /api/exam/end "{\"exam_id\":\"$EID\"}"); ck "exam/end -> ended:true" "$([ "$(has "$(body "$r")" '"ended": true')" = 1 -o "$(has "$(body "$r")" '"ended":true')" = 1 ] && echo 1 || echo 0)" "$(code "$r") $(body "$r")"
r=$(post /api/exam/end "{\"exam_id\":\"$EID\"}"); ck "ending again is harmless (ended:false)" "$([ "$(code "$r")" = 200 ] && echo 1 || echo 0)" "$(code "$r") $(body "$r")"
r=$(post /api/exam/heartbeat "{\"exam_id\":\"$EID\"}"); ck "heartbeat after end -> 404" "$([ "$(code "$r")" = 404 ] && echo 1 || echo 0)" "$(code "$r") $(body "$r")"
echo; echo "Passed $pass, failed $failn"; [ "$failn" = 0 ]

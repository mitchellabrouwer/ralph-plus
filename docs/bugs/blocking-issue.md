

• I found a concrete bug in run-monitored.sh: it scans the entire activity
  log for ITERATION_*, so stale signals from older runs get treated as the
  current run’s result. I’m patching it to only look at log lines created
  after the current iteration’s pipeline: iteration X/Y started marker.

• Explored
  └ Read run-monitored.sh

• Edited ralph-plus/run-monitored.sh (+13 -4)
    168
    169 +current_iteration_log() {
    170 +  local marker escaped_marker
    171 +  marker="pipeline: iteration $i/$MAX_ITERATIONS started"
    172 +  escaped_marker=$(printf '%s\n' "$marker" | sed 's/[][\/.^$*]/\\
         &/g')
    173 +  sed "/$escaped_marker/q" "$ACTIVITY_LOG" 2>/dev/null || true
    174 +}
    175 +
    176  # Initialize progress file if missing
        ⋮
    264        ELAPSED=$((ELAPSED + 10))
    258 -      if grep -qE "$SIGNAL_PATTERN" "$ACTIVITY_LOG" 2>/dev/null;
         then
    259 -        RESULT=$(grep -oE "ITERATION_(DONE|FAIL|BLOCKED)" "$ACTIV
         ITY_LOG" | head -1)
    265 +      ITER_LOG=$(current_iteration_log)
    266 +      if printf '%s\n' "$ITER_LOG" | grep -qE "$SIGNAL_PATTERN";
         then
    267 +        RESULT=$(printf '%s\n' "$ITER_LOG" | grep -oE "ITERATION_
         (DONE|FAIL|BLOCKED)" | head -1)
    268          sleep 15
        ⋮
    294          ELAPSED=$((ELAPSED + 10))
    287 -        if grep -qE "$SIGNAL_PATTERN" "$ACTIVITY_LOG" 2>/dev/null
         ; then
    288 -          grep -oE "ITERATION_(DONE|FAIL|BLOCKED)" "$ACTIVITY_LOG
         " | head -1 > "$RESULT_FILE"
    295 +        ITER_LOG=$(current_iteration_log)
    296 +        if printf '%s\n' "$ITER_LOG" | grep -qE "$SIGNAL_PATTERN"
         ; then
    297 +          printf '%s\n' "$ITER_LOG" | grep -oE "ITERATION_(DONE|F
         AIL|BLOCKED)" | head -1 > "$RESULT_FILE"
    298            sleep 15

──────────────────────────────────────────────────────────────────────────

• I’ve limited monitored-mode signal detection to the current iteration
  slice of the activity log. Next I’m running a shell syntax check and a
  quick diff review to make sure the fix is clean.

• Ran bash -n /home/vin/Documents/projects/ask-flash/ralph-plus/
  │ run-monitored.sh
  └ (no output)

• Ran git diff -- /home/vin/Documents/projects/ask-flash/ralph-plus/
  │ run-monitored.sh
  └ (no output)

• Explored
  └ Read run-monitored.sh, activity-classic-and-library-mobile-polish.log

──────────────────────────────────────────────────────────────────────────

• run-monitored.sh was misreading old activity-log entries as if they
  belonged to the current run.

  In the current version, the monitor loop grepped the entire log for
  ITERATION_*, so a fresh 1/10 run could immediately match stale signals
  from an older 1/10 run and then pick the newest ITERATION_* anywhere in
  the file, which is why you kept getting an immediate false BLOCKED/stuck
  state. You can see the pattern in activity-classic-and-library-mobile-
  polish.log:1: the new monitored runs at 12:05 and 12:07 only wrote
  pipeline: started / iteration 1/10 started, but the latest real
  orchestrator signal in the file is still the old [4/10] ...
  ITERATION_BLOCKED at line 11.

  I fixed that in run-monitored.sh:169 and run-monitored.sh:265 so
  monitored mode now only inspects the slice of the activity log above the
  current iteration’s pipeline: iteration X/Y started marker, matching
  what run-unmonitored.sh already did. bash -n passes.

  One separate point: once the monitor is no longer tripping on stale log
  entries, the task may still genuinely block for the reason already
  recorded at activity-classic-and-library-mobile-polish.log:11: spawnSync
  git EPERM, Playwright webServer exit 1, and diff complexity on
  TestPage.tsx. The script bug was masking that by failing before the new
  run had a chance to produce its own signal.


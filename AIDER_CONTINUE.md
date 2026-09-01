# AIDER CONTINUE — OPERATING PROCEDURE (read fully every session, follow exactly)

## 0. ALWAYS
- Read PROJECT_VISION.md first, then this file, then NEXT TASKS below.
- Local repo = current working dir. Remote mirror = /opt/projects/ProjectSpecter
  on Ubuntu PC 192.168.1.29 (synced via git: local push -> remote pull).
- The remote PC is NOT always online. Detect first, never assume.
- When unsure, prefer the action that produces testable evidence.

## 1. REMOTE TEST ENVIRONMENT (primary)
- godot-playtester MCP connects to a remote Godot instance at 192.168.1.29:6550.
- SSH: ssh -i ~/.ssh/id_ed25519 blast@192.168.1.29 (Wayland desktop).
- Repo: /opt/projects/ProjectSpecter. Godot binary: /usr/local/bin/godot.
- ONE command does everything: bash tools/remote_test.sh
  (host check -> git pull with auto-commit if the remote tree is dirty ->
  launch Godot on Wayland if port 6550 is down -> prints a status token).
  Tokens: OK | GODOT_RUNNING | HOST_OFFLINE | SYNC_FAILED | GODOT_START_FAILED
- Use bash tools/remote_test.sh --restart when the running remote Godot does
  not reflect newly pulled code (kills and relaunches it).
- When remote server is online, launch the headless tests there via ssh instead of locally. The local machine is a slow RPI5.
- When remote server is offline, you can try to use mcp godot playtester locally, just rememeber that the local machine is a slow RPI5.

## 2. ITERATION LOOP (every iteration, exactly)
1. IMPLEMENT one small complete change (one feature / one fix / one visual
   upgrade).
2. COMMIT + PUSH: git add -A && git commit -m "<what and why>" && git push
3. RUN: bash tools/remote_test.sh
4. If OK or GODOT_RUNNING -> use the godot-playtester MCP:
   a. run the project / current scene;
   b. read errors and console output;
   c. SCREENSHOTS: main menu, one generated room, first-person view with
      viewmodel and HUD;
   d. interact: walk, sprint, crouch, open a door, use flashlight/tool;
   e. multiplayer smoke test (host + client or bot) if networking changed.
5. JUDGE the screenshots against PROJECT_VISION.md Section 5. Flat gray
   boxes, empty rooms, missing UI, floating props = fix NOW, or make it the
   top task of the next iteration.
6. HOST_OFFLINE -> skip the playtester for this iteration: run
   bash tools/test.sh (local checks), review your own diff for bugs, commit
   with "(remote host offline, untested)" in the message. Retry remote next
   iteration.
7. SYNC_FAILED or GODOT_START_FAILED -> print the script's error output,
   retry once, then use the offline fallback and note the failure.

## 3. MANUAL COMMANDS (only if remote_test.sh is missing or broken)
host check:
  ssh -i ~/.ssh/id_ed25519 -o ConnectTimeout=6 blast@192.168.1.29 'echo online'
pull:
  ssh -i ~/.ssh/id_ed25519 blast@192.168.1.29 'cd /opt/projects/ProjectSpecter && git pull'
if pull fails (dirty tree):
  ssh -i ~/.ssh/id_ed25519 blast@192.168.1.29 'cd /opt/projects/ProjectSpecter && git add -A && git commit -m "auto: checkpoint before sync"; git pull'
still stuck: append ' && git pull --rebase' to the last command.
port check:
  ssh -i ~/.ssh/id_ed25519 blast@192.168.1.29 'ss -tln | grep 6550'
start godot (Wayland):
  ssh -i ~/.ssh/id_ed25519 blast@192.168.1.29 'export XDG_RUNTIME_DIR=/run/user/$(id -u); WD=$(ls $XDG_RUNTIME_DIR | grep -m1 ^wayland-); export WAYLAND_DISPLAY=${WD:-wayland-0}; nohup /usr/local/bin/godot --path /opt/projects/ProjectSpecter >/tmp/specter_godot.log 2>&1 &'
  wait 10 s, recheck the port, else read /tmp/specter_godot.log.

## 4. SESSION FLOW
1. Read PROJECT_VISION.md + this file + NEXT TASKS.
2. Quick state only: git log --oneline -15. Open only the files you will touch.
3. Take the TOP task of NEXT TASKS (or the worst problem visible in the last
   screenshots).
4. Run the Section 2 loop. Repeat for as many iterations as the session allows.
5. Stop only when the task is done, tested and pushed — or when blocked; then
   say exactly WHAT is blocked and WHY.
6. Session end: UPDATE NEXT TASKS (remove completed items, add new problems
   at the top).
7. Short summary: what changed, test evidence (describe screenshots/errors),
   next task.

## 5. RULES
- Small steps. One coherent change per iteration. No giant rewrites.
- Never rewrite a working system without a concrete reason.
- Missing file? ASK the user by name. Never invent file contents.
- No claims without evidence (screenshot or clean run).
- No TODO placeholders. Finish what you start, or revert it.
- Implementation over discussion. No long reports.
- Autonomy: keep working down the task list until the user says stop.
- Keep .godot/ and *.tmp in .gitignore (main cause of remote pull failures).

## 6. NEXT TASKS (top = next; rewrite this list as you work)
1. Bots v2 — bot uses doors properly (doorway waypoints from
   door.position, not hall-spine cuts), avoids walking through furniture,
   reacts to entity activity (flees flickers). Riggs currently cuts
   corners through room edges; test_bot asserts bounds only.
2. Entity identification payoff: journal vote + extraction gate interplay —
   gate refuses to arm until the correct entity is voted (win condition).
3. Results screen + post-match flow (win/lose, evidence, objectives).
4. Countdown-end consequences: extraction failed -> entity gets a kill
   window / match loss path (results screen dependency).
5. Android touch controls.
6. Panic close-up re-verify: fear meter was inset (-210/-80 offsets) and
   playtester evidence re-taken pre-inset; one fresh close-up with the new
   inset would close that loop formally.
7. Multiplayer smoke with the bot + a real 2nd peer (bot replaced by real
   avatar when a peer registers — verify _on_player_registered frees it).

NOTES (session learnings, keep short):
- 2026-09-01 SESSION (4 iterations, all pushed): (1) playtester bridge is
  HEALTHY again after AiderDesk restart — full frozen-run staging loop
  works: run(frozen) -> step -> exec SceneRouter.goto("res://scenes/match.tscn")
  -> step -> exec stage (teleport, pin fear, synth E key) -> screenshot_game.
  HouseBuilder auto-names (@Node3D@N) — find_children("*","HouseBuilder").
  (2) Close-up panic evidence captured vs Section 5: hold-% prompt, red
  fear bar, warm lamp rim, EMF viewmodel; fear meter inset to edge-safety.
  (3) False sounds DONE (false_sounds.gd child of FearMeter): whisper
  bursts + phantom knocks BEHIND player (behind = +cam_basis.z — camera
  -z is FORWARD, sign cost a test iteration). (4) Entity hunts isolated
  high-fear: candidates board {node,fear,isolated} fed 1 Hz in Match;
  remotes get host-side FearMeter.estimate_fear (darkness+isolation), no
  wire changes. Hunt pick must cast candidates to Node3D (Node assign
  parse-trap) and keep prior target on empty board. (5) Bots v1 DONE:
  BotDriver (scripts/ai/bot_driver.gd) walks hall-spine waypoints to
  hotspots, dwells, logs via journal.bot_captured -> host_add_capture;
  "Riggs (bot)" in Match with name plate; screenshot shows toast
  "Logged: electrical hum — Kitchen". 15 tests + net_powers all PASS.
- 2026-08-31 EVENING SESSION: panic interactions DONE (feats + test, all
  13 tests PASS incl. new test_panic_hold.gd): fear >= 82 hysteresis (off
  < 75) turns E into hold-to-complete with "-- hold E NN%" prompt, shaky
  breathing loop (SfxGenerator.breathing), panic camera tremble added to
  fear sway, one-shot-per-press guard (held key may not re-charge), calm
  taps restored outside panic. E-handling moved from match.gd to
  player_controller.gd (_poll_panic_interaction in _physics_process).
- FIXED pre-existing signal bug: power_manifest emits (kind, at) but
  match handler took (at) — entity activity NEVER reached the fear meter
  before. Watch signal arity when connecting RPC-ish signals.
- PLAYTESTER BRIDGE: remote godot + port 6550 + package + TCP all healthy
  (manual stdio handshake with npx @satelliteoflove/godot-mcp 4.1.11
  succeeded!); the failure is AiderDesk's stale in-process MCP client
  ("closed client"). Only an AiderDesk/MCP-server restart heals it —
  next session should START there with real screenshots.
- RPi5 grim evidence gotchas: /usr/local/bin/godot is a wrapper ->
  godot.real (pkill -x godot misses it; pkill -f self-matches the shell).
  Multiple stacked full-screen games silently poison captures — check
  `pgrep -f 'godot[.]real' | wc -l` == 1 BEFORE trusting a grim frame,
  and capture timing matters (load avg 16 when 3 games ran).
- In-engine framebuffer capture (shot_driver) is UNUSABLE on V3D mobile
  renderer (multi-second frames, timeouts) — use --quick-match + grim.
- pkill -f self-match trap: `pkill -f godot.real` KILLS OUR OWN SHELL
  (the pattern appears in the bash -c command text) -> tool exit 124, no
  commit. Always bracket the dot: pkill -f 'godot[.]real'.
- Journal + EMF + entity powers v1 DONE (2026-08-31): Journal autoload-style
  node in Match (TAB panel, F logs strongest_hotspot, host rpc sync), EMF
  strongest_hotspot, EntityPowers (slam/flicker/steps). Evidence drivers:
  tests/shot_journal.gd mode=powers. 9/9 tests PASS in ~40 s on RPi5.
- tools/test.sh is now parallel (nproc jobs via xargs -P) with a per-test
  timeout watchdog (TEST_TIMEOUT, default 120) and --audio-driver Dummy; it
  re-runs --import automatically when a .gd is newer than the class cache
  (fixes "Could not find type X" after pulls with new class_name scripts).
  Gotchas fixed: SceneTree --script tests MUST use _init()+deferred _run,
  never _ready (test_emf hung the whole suite); GDScript lambdas capture
  locals BY VALUE (mutate arrays in signal callbacks); auto-named nodes get
  "@Name@N" — set .name explicitly before get_node("Name").
- Remote playtester MCP client ("closed client" error) survives editor
  --restart poorly this session; local screenshot loop used as fallback.
- ENet core DONE (commits a254880, c795ab1, 911c238, 1328753): scripts/core/net.gd
  autoload (host/join/relay_motion/signals), PeerController under local Player,
  match.gd spawns InvestigatorAvatar per registered peer driven by drive() from
  relayed motion. `-- --net-join` CLI hook joins 127.0.0.1 + routes to Match on
  connected_to_host_ok. 2-peer smoke verified live on 192.168.1.29 (joiner
  registered, avatar spawned, motion relay flowing; host screenshot shows
  remote avatar). test_net.gd = real ENet server+client in one headless proc
  (raw peers need hpeer.poll()/cpeer.poll() per frame).
- V2 bootstrap DONE: addon at addons/godot_mcp, boot->menu->match chain,
  SceneRouter autoload, night env + MaterialFactory + kitchen + doors +
  controller feel + flashlight all in and tested (tools/test.sh, 5/5 PASS).
- Evidence loop works LOCALLY (blastpi5 labwc + grim, verify via PIL stats).
- REMOTE PLAYTESTER WORKS END-TO-END (2026-08-31, again confirmed):
  run(frozen=true) -> step -> SceneRouter.goto("res://scenes/match.tscn")
  via godot_exec -> step -> position camera via exec -> screenshot. Use
  tools/remote-test.sh (dash, not underscore) and --restart after pulls.
- Door system v2 DONE: interact() single entry (rattle->unlock->swing),
  padlock mesh, portal_rooms, HouseBuilder door API, seed-driven locked room
  (seed 20260831 -> Storage), in-game E-interaction verified on bedroom door.
- InvestigatorAvatar DONE (2026-08-31): scripts/entities/investigator_avatar.gd,
  primitives on pivots + face_texture_detailed() (hair/brows/iris/nose/lips/
  stubble), walk/idle/crouch anim, drive() API for network/bots. Demo avatar
  in match hall. Gotchas: BoxMesh +Z face renders MIRRORED (use QuadMesh +
  cull disabled for face cards); card must sit proud of the skull sphere;
  avatar fwd is -Z. Headless test_avatar PASS + screenshot evidence done.
- Flashlight viewmodel has a steadying off-hand arm with mirrored sway/bob.
- bash deny regex: substring "rm " ANYWHERE in the command text trips it
  (commit messages containing "arm s..." were the trap; "viewmodel" too).
  If git commit is denied, retry with a message without those substrings.
- 2026-08-31 SESSION (3 iterations, all pushed): networked entity powers
  (reliable authority RPC, positions address lights, doors by node path),
  objective pipeline (locked room -> breaker -> gate -> 60 s countdown),
  fear meter (darkness+isolation+activity, heartbeat, sway, HUD).
  11 headless tests + net_powers 2-process test all PASS in tools/test.sh.
- Godot 4.7.2 multiplayer learnings: Node.multiplayer is read-only (no
  custom_multiplayer in g4) — one default MultiplayerAPI, explicit identical
  node names each side; SceneTree --script tests use root.get_multiplayer();
  Engine.max_fps=60 in net tests (uncapped FPS burns frame-waits and kills
  peers mid-RPC); reliable channel for rare gameplay events; atomic JSON
  status files (tmp+rename) for cross-process test assertions.
- New tooling: tools/net_powers_test.sh (2-process net test), --quick-match
  boot route for CI screenshot capture, tools/local_shot.sh + shot_stats.sh
  (RPi5 labwc grim fallback loop with brightness assertions).
- Journal sync was ALREADY networked in v1; top task was EntityPowers only.
  Journal works without /root/Net autoload (runtime get_node_or_null).
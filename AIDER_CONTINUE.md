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
1. Lobby polish over the working ENet core: name/color entry (LineEdit exists
   in UITheme), join-IP field, lobby status line; swap demo avatar away when a
   real peer joins; avatar name labels (Vision 5.2 polish).
2. EMF evidence + journal/deduction UI (Vision 6).
5. Entity powers v1: door slam, light flicker, fake footsteps (Vision 6) —
   doors now expose portal_rooms + lock()/unlock() for entity blocking.
6. Objectives + extraction activation + countdown (Vision 6) — seed-driven
   locked room (house.locked_room()) is the first objective hook.
7. Bots v1 (Vision 6) — InvestigatorAvatar gives bots a full body already.
8. Fear meter HUD + heartbeat audio (Vision 6).
9. Android touch controls.
10. Results screen + post-match flow.

NOTES (session learnings, keep short):
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
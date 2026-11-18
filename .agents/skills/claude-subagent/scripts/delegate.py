#!/usr/bin/env python3
"""Dispatch Caliber work to a subagent and track it, in either direction.

  --agent claude  Codex leads, Claude Code runs headless (`claude -p`).
  --agent codex   Claude leads, Codex runs headless (`codex exec`).

Each delegation ("slug") gets its own Git worktree on branch <agent>/<slug>,
a task brief, a dispatch-log line, and a state folder under
<git-common-dir>/claude-delegate/<slug>/ that every worktree can read.
See docs/parallel/DELEGATION.md for the protocol both agents follow.

Subcommands: doctor, start, resume, status, wait, check, list.
"""
from __future__ import annotations

import argparse
import datetime as dt
import fnmatch
import json
import os
import re
import shutil
import signal
import subprocess
import sys
import time
from pathlib import Path

SKILL_DIR = Path(__file__).resolve().parents[1]
SCHEMA_PATH = SKILL_DIR / 'references' / 'result.schema.json'
PROTOCOL_REL = Path('docs/parallel/DELEGATION.md')
BUNDLED_PROTOCOL = SKILL_DIR / 'references' / 'DELEGATION.md'
SLUG_RE = re.compile(r'^[a-z0-9][a-z0-9-]{1,48}$')
PERMISSION_PROMPTS_MIN = (2, 1, 259)

READ_TOOLS = ['Read', 'Glob', 'Grep', 'Bash(git status *)', 'Bash(git diff *)',
              'Bash(git log *)', 'Bash(git show *)', 'Bash(ls *)']
WRITE_TOOLS = ['Edit', 'Write', 'Bash(git add *)', 'Bash(git commit *)',
               'Bash(python3 scripts/*)', 'Bash(python3 -m unittest *)',
               'Bash(swift build *)', 'Bash(swift test *)', 'Bash(swift format *)',
               'Bash(swift-format *)', 'Bash(mkdir *)']
DENIED_TOOLS = ['Bash(git push *)', 'Bash(git merge *)', 'Bash(git rebase *)',
                'Bash(git reset *)', 'Bash(git checkout *)', 'Bash(git switch *)',
                'Bash(git worktree *)', 'Bash(git branch -D *)', 'Bash(git stash *)',
                'Bash(git clean *)', 'Bash(rm -rf *)', 'Bash(xcrun simctl *)',
                'Bash(gh *)', 'Bash(supabase *)']
SIMULATOR_TOOLS = ['Bash(xcodebuild *)', 'Bash(python3 scripts/test_ios.py *)']
AGENTS = {
    'claude': {'name': 'Claude Code', 'lead': 'Codex', 'task': 'CLAUDE_TASK.md', 'handoff': 'CLAUDE_HANDOFF.md'},
    'codex': {'name': 'Codex', 'lead': 'Claude', 'task': 'CODEX_TASK.md', 'handoff': 'CODEX_HANDOFF.md'},
}
DEFAULT_MODELS = {'claude': 'opus', 'codex': None}


class DelegateError(Exception):
    pass


# ---------------------------------------------------------------- helpers

def git(*args: str, cwd: Path, check: bool = True) -> str:
    proc = subprocess.run(['git', *args], cwd=cwd, capture_output=True, text=True)
    if check and proc.returncode != 0:
        raise DelegateError(f'git {" ".join(args)} failed: {proc.stderr.strip()}')
    return proc.stdout.strip()


def repo_root(cwd: Path) -> Path:
    return Path(git('rev-parse', '--show-toplevel', cwd=cwd))


def state_root(cwd: Path) -> Path:
    common = Path(git('rev-parse', '--git-common-dir', cwd=cwd))
    if not common.is_absolute():
        common = (cwd / common).resolve()
    return common / 'claude-delegate'


def now() -> str:
    return dt.datetime.now().astimezone().isoformat(timespec='seconds')


def parse_version(text: str) -> tuple[int, ...]:
    match = re.search(r'(\d+)\.(\d+)\.(\d+)', text or '')
    return tuple(int(x) for x in match.groups()) if match else (0, 0, 0)


def claude_bin() -> str:
    found = os.environ.get('CLAUDE_BIN') or shutil.which('claude')
    if not found:
        raise DelegateError('claude CLI not found on PATH. Install Claude Code and run `claude auth login`.')
    return found


def codex_bin() -> str:
    found = os.environ.get('CODEX_BIN') or shutil.which('codex')
    if not found:
        raise DelegateError('codex CLI not found on PATH. Install it (`brew install codex` or '
                            '`npm i -g @openai/codex`) and run `codex login`.')
    return found


def agent_bin(agent: str) -> str:
    return codex_bin() if agent == 'codex' else claude_bin()


def claude_version(binary: str) -> tuple[int, ...]:
    proc = subprocess.run([binary, '--version'], capture_output=True, text=True)
    return parse_version(proc.stdout)


def load_meta(root: Path, slug: str) -> dict:
    path = root / slug / 'meta.json'
    if not path.exists():
        raise DelegateError(f'no delegation named {slug!r} (looked in {path.parent})')
    return json.loads(path.read_text())


def save_meta(root: Path, meta: dict) -> None:
    folder = root / meta['slug']
    folder.mkdir(parents=True, exist_ok=True)
    tmp = folder / 'meta.json.tmp'
    tmp.write_text(json.dumps(meta, indent=2) + '\n')
    tmp.replace(folder / 'meta.json')


def pid_alive(pid: int | None) -> bool:
    if not pid:
        return False
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    try:  # a finished child that was never reaped still answers kill(0)
        done, _ = os.waitpid(pid, os.WNOHANG)
        return done == 0
    except ChildProcessError:
        return True


def matches_owned(path: str, owned: list[str]) -> bool:
    """fnmatch globs; '*' crosses '/', and a trailing '/' owns the whole folder."""
    for pattern in owned:
        if pattern.endswith('/') and path.startswith(pattern):
            return True
        if fnmatch.fnmatchcase(path, pattern):
            return True
    return False


def changed_paths(worktree: Path, seed: str) -> list[str]:
    paths: set[str] = set()
    committed = git('diff', '--name-only', '-z', f'{seed}...HEAD', cwd=worktree)
    paths.update(p for p in committed.split('\0') if p)
    status = subprocess.run(['git', 'status', '--porcelain', '-z', '--untracked-files=all'],
                            cwd=worktree, capture_output=True, text=True).stdout
    entries = status.split('\0')
    i = 0
    while i < len(entries):
        entry = entries[i]
        if len(entry) > 3:
            paths.add(entry[3:])
            if entry[0] in 'RC':  # rename/copy: the next entry is the old path
                i += 1
        i += 1
    return sorted(paths)


def ownership_violations(meta: dict) -> list[str]:
    worktree = Path(meta['worktree'])
    owned = meta['owned'] + [meta['handoff_path']]
    return [p for p in changed_paths(worktree, meta['seed']) if not matches_owned(p, owned)]


# ---------------------------------------------------------------- prompt / command

def agent_of(meta: dict) -> str:
    return meta.get('agent', 'claude')


def protocol_path(meta: dict) -> Path:
    path = Path(meta['worktree']) / PROTOCOL_REL
    return path if path.exists() else BUNDLED_PROTOCOL  # branch predates the protocol


def build_prompt(meta: dict, task: str) -> str:
    owned = '\n'.join(f'  - {p}' for p in meta['owned']) or '  - (none: read-only review)'
    mode = 'READ-ONLY REVIEW: do not edit or commit anything except your handoff file.' \
        if meta['read_only'] else 'Implement the task inside your owned paths.'
    sims = 'You MAY run xcodebuild / scripts/test_ios.py for this task.' if meta['allow_simulator'] \
        else 'Do NOT run xcodebuild, simulator, or scripts/test_ios.py; list them as UNTESTED.'
    info = AGENTS[agent_of(meta)]
    header = f"""You are {info['name']} working as a delegated subagent for {info['lead']} (the lead) on the
Caliber iOS app. Follow docs/parallel/DELEGATION.md. Nobody can answer questions mid-run."""
    if agent_of(meta) == 'codex':  # codex has no append-system-prompt flag: inline the protocol
        header += '\n\nShared protocol (docs/parallel/DELEGATION.md)\n' + '-' * 45 + '\n' + \
            protocol_path(meta).read_text().strip() + '\n'
    return header + f"""

Assignment
- Batch: {meta['batch']}    Slug: {meta['slug']}
- Worktree: {meta['worktree']}
- Branch: {meta['branch']}  (seed {meta['seed']})
- Owned paths (edit nothing else):
{owned}
- Handoff file you must write and commit: {meta['handoff_path']}
- Mode: {mode}
- {sims}
- Never push, merge, rebase, reset, switch branches, or touch other worktrees.
- If `git commit` is refused by your sandbox, leave the changes in the worktree, say so in
  `questions`, and the lead will commit them on your branch.

Finish by committing your work and the handoff, then return the structured result
(status, summary, head, commits, files_changed, checks, untested, questions, handoff_path).

Task from Codex
---------------
{task.strip()}
"""


def build_command(binary: str, meta: dict, prompt: str, resume_id: str | None = None,
                  last_message: Path | None = None) -> list[str]:
    if agent_of(meta) == 'codex':
        return build_codex_command(binary, meta, prompt, resume_id, last_message)
    allowed = list(READ_TOOLS)
    if meta['read_only']:
        allowed += ['Edit', 'Write', 'Bash(git add *)', 'Bash(git commit *)']  # handoff only
    else:
        allowed += WRITE_TOOLS
    if meta['allow_simulator']:
        allowed += SIMULATOR_TOOLS
    allowed += meta.get('extra_tools', [])
    denied = [t for t in DENIED_TOOLS if t not in meta.get('extra_tools', [])]
    if not meta['allow_simulator']:
        denied += SIMULATOR_TOOLS
    cmd = [binary, '-p', prompt,
           '--output-format', 'json',
           '--json-schema', SCHEMA_PATH.read_text(),
           '--permission-mode', 'acceptEdits',
           '--allowedTools', *allowed,
           '--disallowedTools', *denied,
           '--model', meta['model'],
           '--max-budget-usd', str(meta['max_budget_usd']),
           '--max-turns', str(meta['max_turns']),
           '--name', f"caliber-{meta['slug']}"]
    if meta.get('effort'):
        cmd += ['--effort', meta['effort']]
    if meta.get('fallback_model'):
        cmd += ['--fallback-model', meta['fallback_model']]
    protocol = protocol_path(meta)
    if protocol.exists():
        cmd += ['--append-system-prompt-file', str(protocol)]
    if claude_version(binary) >= PERMISSION_PROMPTS_MIN:
        cmd += ['--permission-prompts', 'none']
    if resume_id:
        cmd += ['--resume', resume_id]
    return cmd


def build_codex_command(binary: str, meta: dict, prompt: str, resume_id: str | None,
                        last_message: Path | None) -> list[str]:
    """`codex exec` in workspace-write. The worktree's git dir lives in the main repo's
    common dir, so that is added as a writable root for commits; network stays off."""
    common = git('rev-parse', '--git-common-dir', cwd=Path(meta['worktree']))
    common = str((Path(meta['worktree']) / common).resolve()) if not Path(common).is_absolute() else common
    cmd = [binary, 'exec']
    if resume_id:
        cmd += ['resume', resume_id]
    cmd += ['--json', '--skip-git-repo-check', '--output-schema', str(SCHEMA_PATH),
            '-c', 'sandbox_mode="workspace-write"',
            '-c', f'sandbox_workspace_write.writable_roots={json.dumps([common])}',
            '-c', 'approval_policy="never"']
    if not resume_id:
        cmd += ['-C', meta['worktree']]
    if last_message:
        cmd += ['-o', str(last_message)]
    if meta.get('model'):
        cmd += ['-m', meta['model']]
    if meta.get('network'):
        cmd += ['-c', 'sandbox_workspace_write.network_access=true']
    if meta.get('effort'):
        effort = {'max': 'xhigh'}.get(meta['effort'], meta['effort'])
        cmd += ['-c', f'model_reasoning_effort="{effort}"']
    return cmd + [prompt]


def launch(meta: dict, root: Path, prompt: str, wait: bool, resume_id: str | None = None) -> dict:
    binary = agent_bin(agent_of(meta))
    run_no = len(meta['runs']) + 1
    folder = root / meta['slug']
    out_path, err_path = folder / f'run-{run_no}.json', folder / f'run-{run_no}.stderr'
    last_path = folder / f'run-{run_no}.last.json'
    (folder / f'run-{run_no}.prompt.md').write_text(prompt)
    cmd = build_command(binary, meta, prompt, resume_id, last_path)
    with open(out_path, 'w') as out, open(err_path, 'w') as err:
        proc = subprocess.Popen(cmd, cwd=meta['worktree'], stdout=out, stderr=err,
                                stdin=subprocess.DEVNULL, start_new_session=True)
    run = {'n': run_no, 'pid': proc.pid, 'started': now(), 'kind': 'resume' if resume_id else 'start',
           'output': str(out_path), 'stderr': str(err_path), 'last_message': str(last_path)}
    meta['runs'].append(run)
    save_meta(root, meta)
    if wait:
        proc.wait()
        finish_run(meta, root)
    return run


def read_codex_result(run: dict) -> dict:
    """Normalise `codex exec --json` events + last message into the claude result shape."""
    result: dict = {'is_error': False}
    usage: dict = {}
    path = Path(run['output'])
    for line in (path.read_text().splitlines() if path.exists() else []):
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        kind = event.get('type', '')
        if kind == 'thread.started':
            result['session_id'] = event.get('thread_id')
        elif kind == 'turn.completed':
            usage = event.get('usage') or usage
        elif kind in ('turn.failed', 'error'):
            result['is_error'] = True
            err = event.get('error')
            result['result'] = (err.get('message') if isinstance(err, dict) else None) or event.get('message') or line
    last = Path(run.get('last_message', ''))
    text = last.read_text().strip() if last.is_file() else ''
    if text:
        try:
            result['structured_output'] = json.loads(text)
        except json.JSONDecodeError:
            result['result'] = text
    elif 'result' not in result:
        result['is_error'] = True
        result['result'] = 'no final message (see stderr)'
    if usage:
        result['usage'] = usage
    return result


def read_result(run: dict) -> dict | None:
    path = Path(run['output'])
    if not path.exists() or not path.read_text().strip():
        return None
    text = path.read_text().strip()
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        try:  # some versions print one JSON value per line; keep the last
            return json.loads(text.splitlines()[-1])
        except json.JSONDecodeError:
            return {'is_error': True, 'result': text[-2000:]}


def finish_run(meta: dict, root: Path) -> None:
    """Record session id and outcome of the latest run once its process has exited."""
    if not meta['runs']:
        return
    run = meta['runs'][-1]
    if run.get('finished') or pid_alive(run.get('pid')):
        return
    if agent_of(meta) == 'codex':
        result = read_codex_result(run)
    else:
        result = read_result(run) or {'is_error': True, 'result': 'no output (see stderr)'}
    run['finished'] = now()
    run['is_error'] = bool(result.get('is_error'))
    run['cost_usd'] = result.get('total_cost_usd')
    if result.get('usage'):
        run['usage'] = result['usage']
    run['structured'] = result.get('structured_output')
    if not run['structured'] and result.get('result'):
        run['text'] = str(result['result'])[-2000:]
    if result.get('session_id'):
        meta['session_id'] = result['session_id']
    save_meta(root, meta)


def append_dispatch_log(caller_root: Path, meta: dict, kind: str, note: str = '') -> Path:
    log = caller_root / 'docs' / 'parallel' / meta['batch'] / 'DISPATCH_LOG.md'
    log.parent.mkdir(parents=True, exist_ok=True)
    if not log.exists():
        log.write_text(f'# {meta["batch"]} dispatch log\n\nAppended by delegate.py; '
                       'the lead commits it.\n\n')
    line = (f"- {now()} {kind} `{meta['slug']}` branch `{meta['branch']}` seed `{meta['seed'][:7]}` "
            f"worktree `{meta['worktree']}` agent {agent_of(meta)} model {meta.get('model') or 'default'}"
            f"{' budget $' + str(meta['max_budget_usd']) if agent_of(meta) == 'claude' else ''}"
            f"{' session ' + meta['session_id'] if meta.get('session_id') else ''}{' ' + note if note else ''}\n")
    with open(log, 'a') as fh:
        fh.write(line)
    return log


# ---------------------------------------------------------------- subcommands

def doctor_codex() -> bool:
    try:
        binary = codex_bin()
    except DelegateError as exc:
        print(f'codex: {exc}')
        return False
    version = subprocess.run([binary, '--version'], capture_output=True, text=True).stdout.strip()
    print(f'codex: {binary} ({version or "?"})')
    login = subprocess.run([binary, 'login', 'status'], capture_output=True, text=True)
    text = (login.stdout + login.stderr).strip().splitlines()
    if login.returncode == 0 and not any('not logged in' in line.lower() for line in text):
        print(f'codex auth: {text[0] if text else "logged in"}')
        return True
    print('codex auth: NOT logged in. Run `codex login` in a terminal.')
    return False


def cmd_doctor(args, cwd: Path) -> int:
    ok = True
    agents = ['claude', 'codex'] if args.agent == 'both' else [args.agent]
    if 'codex' in agents:
        ok = doctor_codex() and ok
    if 'claude' not in agents:
        return cmd_doctor_repo(cwd, ok)
    try:
        binary = claude_bin()
        version = claude_version(binary)
        print(f'claude: {binary} v{".".join(map(str, version))}')
        if version < PERMISSION_PROMPTS_MIN:
            print('  note: older than 2.1.259; --permission-prompts none is skipped. Run `claude update`.')
        auth = subprocess.run([binary, 'auth', 'status'], capture_output=True, text=True)
        if auth.returncode == 0:
            method = json.loads(auth.stdout or '{}').get('authMethod', '?') if auth.stdout.strip().startswith('{') else '?'
            print(f'auth: logged in ({method})')
        else:
            ok = False
            print('auth: NOT logged in. Run `claude auth login` in a terminal.')
    except DelegateError as exc:
        ok = False
        print(exc)
    return cmd_doctor_repo(cwd, ok)


def cmd_doctor_repo(cwd: Path, ok: bool) -> int:
    try:
        root = repo_root(cwd)
        print(f'repo: {root} on {git("branch", "--show-current", cwd=root) or "(detached)"}')
        print(f'state: {state_root(root)}')
        if not (root / PROTOCOL_REL).exists():
            print(f'  note: {PROTOCOL_REL} not on this branch; using the copy bundled with the skill')
    except DelegateError as exc:
        ok = False
        print(exc)
    return 0 if ok else 1


def cmd_start(args, cwd: Path) -> int:
    if not SLUG_RE.match(args.slug):
        raise DelegateError('slug must be lowercase letters, digits and dashes (2-49 chars)')
    if not SLUG_RE.match(args.batch):
        raise DelegateError('batch must be lowercase letters, digits and dashes')
    if not args.own and not args.read_only:
        raise DelegateError('give at least one --own path/glob, or use --read-only')
    caller = repo_root(cwd)
    root = state_root(caller)
    if (root / args.slug / 'meta.json').exists():
        raise DelegateError(f'{args.slug!r} already exists; use `resume {args.slug}` or pick a new slug')
    task = Path(args.task_file).read_text() if args.task_file else args.task
    if not task or not task.strip():
        raise DelegateError('give --task or --task-file')
    seed = git('rev-parse', args.seed, cwd=caller)
    agent = args.agent
    branch = f'{agent}/{args.slug}'
    worktree = Path(args.worktree).expanduser().resolve() if args.worktree \
        else (caller.parent / f'Caliber-{agent}-{args.slug}').resolve()
    if worktree.exists():
        current = git('branch', '--show-current', cwd=worktree, check=False)
        if current != branch:
            raise DelegateError(f'{worktree} exists and is on {current or "?"}, not {branch}')
    else:
        exists = git('rev-parse', '--verify', '--quiet', f'refs/heads/{branch}', cwd=caller, check=False)
        if exists and not args.reuse_branch:
            raise DelegateError(f'branch {branch} already exists; pick another slug or pass --reuse-branch')
        if exists:
            git('worktree', 'add', str(worktree), branch, cwd=caller)
        else:
            git('worktree', 'add', '-b', branch, str(worktree), seed, cwd=caller)
    handoff = f'docs/parallel/{args.batch}/{AGENTS[agent]["handoff"]}'
    model = args.model if args.model is not None else DEFAULT_MODELS[agent]
    meta = {
        'agent': agent, 'slug': args.slug, 'batch': args.batch, 'branch': branch, 'seed': seed,
        'worktree': str(worktree), 'caller_checkout': str(caller), 'owned': args.own,
        'handoff_path': handoff, 'read_only': args.read_only, 'allow_simulator': args.allow_simulator,
        'extra_tools': args.allow_tool, 'model': model, 'effort': args.effort,
        'fallback_model': args.fallback_model, 'max_budget_usd': args.max_budget_usd,
        'max_turns': args.max_turns, 'network': args.network, 'created': now(), 'session_id': None, 'runs': [],
    }
    save_meta(root, meta)
    prompt = build_prompt(meta, task)
    brief = caller / 'docs' / 'parallel' / args.batch / AGENTS[agent]['task']
    if not args.no_docs:
        brief.parent.mkdir(parents=True, exist_ok=True)
        with open(brief, 'a') as fh:
            fh.write(f'\n<!-- {args.slug} dispatched {now()} -->\n{prompt}\n')
    run = launch(meta, root, prompt, wait=args.wait)
    meta = load_meta(root, args.slug)
    if not args.no_docs:
        append_dispatch_log(caller, meta, 'start')
    print(f'started {args.slug}: run {run["n"]} pid {run["pid"]} in {worktree} on {branch}')
    if args.wait:
        return print_status(meta, root, args.json)
    print(f'follow with: {Path(__file__).name} wait {args.slug}   (or status {args.slug})')
    return 0


def cmd_resume(args, cwd: Path) -> int:
    root = state_root(repo_root(cwd))
    meta = load_meta(root, args.slug)
    finish_run(meta, root)
    if meta['runs'] and not meta['runs'][-1].get('finished'):
        raise DelegateError(f'{args.slug} is still running (pid {meta["runs"][-1]["pid"]}); wait first')
    if not meta.get('session_id'):
        raise DelegateError(f'{args.slug} has no session id to resume; check its last run stderr')
    message = Path(args.message_file).read_text() if args.message_file else args.message
    if not message:
        raise DelegateError('give --message or --message-file')
    for key in ('max_budget_usd', 'max_turns'):
        if getattr(args, key) is not None:
            meta[key] = getattr(args, key)
    if args.network:
        meta['network'] = True
    lead = AGENTS[agent_of(meta)]['lead']
    prompt = (f'Follow-up from {lead} for {meta["slug"]} (same rules, same owned paths, '
              f'same worktree {meta["worktree"]}). Update and commit {meta["handoff_path"]}, then '
              f'return the structured result again.\n\n{message.strip()}\n')
    run = launch(meta, root, prompt, wait=args.wait, resume_id=meta['session_id'])
    meta = load_meta(root, args.slug)
    if not args.no_docs:
        append_dispatch_log(Path(meta['caller_checkout']), meta, 'resume')
    print(f'resumed {args.slug}: run {run["n"]} pid {run["pid"]}')
    return print_status(meta, root, args.json) if args.wait else 0


def status_dict(meta: dict, root: Path) -> dict:
    finish_run(meta, root)
    worktree = Path(meta['worktree'])
    last = meta['runs'][-1] if meta['runs'] else {}
    state = 'not started'
    if last:
        state = 'running' if not last.get('finished') else ('error' if last.get('is_error') else 'finished')
    info = {'slug': meta['slug'], 'agent': agent_of(meta), 'batch': meta['batch'], 'branch': meta['branch'],
            'worktree': meta['worktree'], 'seed': meta['seed'][:7], 'state': state,
            'session_id': meta.get('session_id'), 'runs': len(meta['runs']),
            'cost_usd_total': max([r.get('cost_usd') or 0 for r in meta['runs']] or [0])}  # resume reports the running total
    usage = [r['usage'] for r in meta['runs'] if r.get('usage')]
    if usage:
        info['codex_usage_last_turn'] = usage[-1]
    if worktree.exists():
        info['head'] = git('rev-parse', '--short', 'HEAD', cwd=worktree)
        log = git('log', '--format=%h %s', f'{meta["seed"]}..HEAD', cwd=worktree)
        info['commits'] = log.splitlines() if log else []
        info['handoff_exists'] = (worktree / meta['handoff_path']).exists()
        info['ownership_violations'] = ownership_violations(meta)
        dirty = git('status', '--porcelain', cwd=worktree)
        info['uncommitted'] = dirty.splitlines() if dirty else []
    else:
        info['worktree_missing'] = True
    if last.get('finished'):
        info['result'] = last.get('structured') or {'text': last.get('text')}
        if last.get('is_error'):
            info['stderr_tail'] = Path(last['stderr']).read_text()[-1500:] if Path(last['stderr']).exists() else ''
    return info


def print_status(meta: dict, root: Path, as_json: bool) -> int:
    info = status_dict(meta, root)
    if as_json:
        print(json.dumps(info, indent=2))
    else:
        spend = f"~${info['cost_usd_total']:.2f}" if info['agent'] == 'claude' else \
            f"tokens {info.get('codex_usage_last_turn', {}).get('input_tokens', '?')} in / " \
            f"{info.get('codex_usage_last_turn', {}).get('output_tokens', '?')} out (last turn)"
        print(f"{info['slug']} [{info['state']}] {info['branch']} @ {info.get('head', '?')} "
              f"(seed {info['seed']}, runs {info['runs']}, {spend})")
        print(f"  worktree: {info['worktree']}")
        for c in info.get('commits', []):
            print(f'  commit: {c}')
        for u in info.get('uncommitted', []):
            print(f'  uncommitted: {u}')
        for v in info.get('ownership_violations', []):
            print(f'  OUTSIDE OWNERSHIP: {v}')
        if 'handoff_exists' in info and not info['handoff_exists']:
            print(f"  handoff missing: {meta['handoff_path']}")
        if 'result' in info:
            print('  result: ' + json.dumps(info['result'], indent=2).replace('\n', '\n  '))
        if info.get('stderr_tail'):
            print('  stderr: ' + info['stderr_tail'].replace('\n', '\n  '))
    return 1 if info['state'] == 'error' else 0


def cmd_status(args, cwd: Path) -> int:
    root = state_root(repo_root(cwd))
    return print_status(load_meta(root, args.slug), root, args.json)


def cmd_wait(args, cwd: Path) -> int:
    root = state_root(repo_root(cwd))
    deadline = time.monotonic() + args.timeout
    while True:
        meta = load_meta(root, args.slug)
        finish_run(meta, root)
        if not meta['runs'] or meta['runs'][-1].get('finished'):
            return print_status(meta, root, args.json)
        if time.monotonic() >= deadline:
            print(f'{args.slug} still running after {args.timeout}s (pid {meta["runs"][-1]["pid"]}); '
                  'run wait again later')
            return 2
        time.sleep(min(15, max(1, deadline - time.monotonic())))


def cmd_check(args, cwd: Path) -> int:
    root = state_root(repo_root(cwd))
    meta = load_meta(root, args.slug)
    bad = ownership_violations(meta)
    for path in bad:
        print(f'outside ownership: {path}')
    if not (Path(meta['worktree']) / meta['handoff_path']).exists():
        print(f"missing handoff: {meta['handoff_path']}")
        return 1
    if not bad:
        print(f'{args.slug}: all changes inside owned paths')
    return 1 if bad else 0


def cmd_stop(args, cwd: Path) -> int:
    root = state_root(repo_root(cwd))
    meta = load_meta(root, args.slug)
    run = meta['runs'][-1] if meta['runs'] else None
    if not run or not pid_alive(run.get('pid')):
        print(f'{args.slug} is not running')
        return 0
    os.killpg(run['pid'], signal.SIGINT)  # SIGINT lets Claude end the turn cleanly
    print(f'sent SIGINT to {args.slug} (pid {run["pid"]})')
    return 0


def cmd_list(args, cwd: Path) -> int:
    root = state_root(repo_root(cwd))
    if not root.exists():
        print('no delegations yet')
        return 0
    for folder in sorted(p for p in root.iterdir() if (p / 'meta.json').exists()):
        meta = json.loads((folder / 'meta.json').read_text())
        info = status_dict(meta, root)
        print(f"{info['slug']:<28} {info['state']:<11} {info['branch']:<36} {info['batch']}")
    return 0


def parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest='command', required=True)
    d = sub.add_parser('doctor', help='check the agent CLI, login and repo')
    d.add_argument('--agent', choices=['claude', 'codex', 'both'], default='claude')

    s = sub.add_parser('start', help='create worktree claude/<slug> and dispatch Claude')
    s.add_argument('slug')
    s.add_argument('--agent', choices=sorted(AGENTS), default=os.environ.get('DELEGATE_AGENT', 'claude'),
                   help='subagent to dispatch: claude (Codex leads) or codex (Claude leads)')
    s.add_argument('--network', action='store_true',
                   help='codex only: allow network inside its sandbox (e.g. SwiftPM resolve)')
    s.add_argument('--reuse-branch', action='store_true', help='allow an existing <agent>/<slug> branch')
    s.add_argument('--batch', required=True, help='docs/parallel/<batch> folder name')
    task = s.add_mutually_exclusive_group(required=True)
    task.add_argument('--task')
    task.add_argument('--task-file')
    s.add_argument('--own', action='append', default=[], help='path or glob Claude may edit (repeat)')
    s.add_argument('--seed', default='HEAD', help='commit to branch from (default HEAD)')
    s.add_argument('--worktree', help='default ../Caliber-claude-<slug>')
    s.add_argument('--read-only', action='store_true', help='review only; Claude edits just its handoff')
    s.add_argument('--allow-simulator', action='store_true', help='let Claude run xcodebuild/test_ios.py')
    s.add_argument('--allow-tool', action='append', default=[], help='extra permission rule, e.g. "Bash(npm test *)"')
    s.add_argument('--model', default=os.environ.get('DELEGATE_MODEL'),
                   help='claude default opus; codex default is your Codex config')
    s.add_argument('--fallback-model', default='sonnet')
    s.add_argument('--effort', default=os.environ.get('CLAUDE_DELEGATE_EFFORT', 'high'))
    s.add_argument('--max-budget-usd', type=float, default=float(os.environ.get('CLAUDE_DELEGATE_BUDGET', '15')))
    s.add_argument('--max-turns', type=int, default=200)
    s.add_argument('--wait', action='store_true', help='block until Claude finishes (default: detach)')
    s.add_argument('--no-docs', action='store_true', help='skip CLAUDE_TASK.md / DISPATCH_LOG.md')
    s.add_argument('--json', action='store_true')

    r = sub.add_parser('resume', help='send a follow-up to the same Claude session')
    r.add_argument('slug')
    msg = r.add_mutually_exclusive_group(required=True)
    msg.add_argument('--message')
    msg.add_argument('--message-file')
    r.add_argument('--max-budget-usd', type=float)
    r.add_argument('--max-turns', type=int)
    r.add_argument('--network', action='store_true', help='codex only: allow network from now on')
    r.add_argument('--wait', action='store_true')
    r.add_argument('--no-docs', action='store_true')
    r.add_argument('--json', action='store_true')

    for name, helptext in (('status', 'show run state, result, commits, ownership'),
                           ('check', 'exit 1 if Claude changed paths it does not own'),
                           ('stop', 'interrupt a running delegation')):
        c = sub.add_parser(name, help=helptext)
        c.add_argument('slug')
        if name == 'status':
            c.add_argument('--json', action='store_true')
    w = sub.add_parser('wait', help='block until the latest run finishes')
    w.add_argument('slug')
    w.add_argument('--timeout', type=int, default=540, help='seconds (default 540, under typical tool timeouts)')
    w.add_argument('--json', action='store_true')
    sub.add_parser('list', help='list delegations in this repository')
    return p


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    handlers = {'doctor': cmd_doctor, 'start': cmd_start, 'resume': cmd_resume, 'status': cmd_status,
                'wait': cmd_wait, 'check': cmd_check, 'stop': cmd_stop, 'list': cmd_list}
    try:
        return handlers[args.command](args, Path.cwd())
    except DelegateError as exc:
        print(f'error: {exc}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())

import json
from unittest import mock
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT_DIR = Path(__file__).resolve().parents[1] / '.agents/skills/claude-subagent/scripts'
sys.path.insert(0, str(SCRIPT_DIR))
import delegate as subject  # noqa: E402


def git(cwd, *args):
    subprocess.run(['git', *args], cwd=cwd, check=True, capture_output=True)


class OwnershipTests(unittest.TestCase):
    def test_globs_and_folder_prefixes(self):
        owned = ['Caliber (DEV)/Views/Today/*', 'docs/parallel/x/', 'Packages/A/Sources/A/Foo.swift']
        self.assertTrue(subject.matches_owned('Caliber (DEV)/Views/Today/Cards/Pager.swift', owned))
        self.assertTrue(subject.matches_owned('docs/parallel/x/CLAUDE_HANDOFF.md', owned))
        self.assertTrue(subject.matches_owned('Packages/A/Sources/A/Foo.swift', owned))
        self.assertFalse(subject.matches_owned('Caliber (DEV).xcodeproj/project.pbxproj', owned))
        self.assertFalse(subject.matches_owned('docs/parallel/xy/README.md', owned))

    def test_changed_paths_and_violations_in_a_worktree(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            git(repo, 'init', '-q', '-b', 'main')
            git(repo, 'config', 'user.email', 't@example.com')
            git(repo, 'config', 'user.name', 't')
            (repo / 'Owned Dir').mkdir()
            (repo / 'Owned Dir' / 'a.swift').write_text('a')
            (repo / 'shared.txt').write_text('s')
            git(repo, 'add', '.')
            git(repo, 'commit', '-qm', 'seed')
            seed = subject.git('rev-parse', 'HEAD', cwd=repo)
            (repo / 'Owned Dir' / 'a.swift').write_text('b')
            git(repo, 'commit', '-qam', 'owned change')
            (repo / 'shared.txt').write_text('changed')
            (repo / 'new file.md').write_text('n')
            meta = {'worktree': str(repo), 'seed': seed, 'owned': ['Owned Dir/*'],
                    'handoff_path': 'docs/parallel/b/CLAUDE_HANDOFF.md'}
            self.assertEqual(subject.changed_paths(repo, seed),
                             ['Owned Dir/a.swift', 'new file.md', 'shared.txt'])
            self.assertEqual(subject.ownership_violations(meta), ['new file.md', 'shared.txt'])


class CommandTests(unittest.TestCase):
    def meta(self, **extra):
        base = {'slug': 'today-cards', 'batch': 'cards-v3', 'branch': 'claude/today-cards',
                'seed': 'a' * 40, 'worktree': '/nonexistent', 'owned': ['Views/Today/*'],
                'handoff_path': 'docs/parallel/cards-v3/CLAUDE_HANDOFF.md', 'read_only': False,
                'allow_simulator': False, 'extra_tools': [], 'model': 'opus', 'effort': 'high',
                'fallback_model': 'sonnet', 'max_budget_usd': 15.0, 'max_turns': 200}
        base.update(extra)
        return base

    def test_prompt_names_assignment(self):
        prompt = subject.build_prompt(self.meta(), 'Build the pager.')
        for text in ('claude/today-cards', 'Views/Today/*', 'CLAUDE_HANDOFF.md', 'Build the pager.',
                     'Do NOT run xcodebuild'):
            self.assertIn(text, prompt)

    def test_command_keeps_prompt_before_variadic_flags_and_denies_push(self):
        with mock.patch.object(subject, 'claude_version', return_value=(2, 1, 300)):
            cmd = subject.build_command('claude', self.meta(), 'PROMPT')
        self.assertEqual(cmd[:3], ['claude', '-p', 'PROMPT'])
        denied = cmd[cmd.index('--disallowedTools') + 1:cmd.index('--model')]
        self.assertIn('Bash(git push *)', denied)
        self.assertIn('Bash(xcodebuild *)', denied)
        self.assertIn('--permission-prompts', cmd)
        json.loads(cmd[cmd.index('--json-schema') + 1])

    def test_simulator_opt_in_and_old_cli(self):
        with mock.patch.object(subject, 'claude_version', return_value=(2, 1, 100)):
            cmd = subject.build_command('claude', self.meta(allow_simulator=True), 'P', resume_id='sid')
        allowed = cmd[cmd.index('--allowedTools') + 1:cmd.index('--disallowedTools')]
        self.assertIn('Bash(xcodebuild *)', allowed)
        self.assertNotIn('--permission-prompts', cmd)
        self.assertEqual(cmd[-2:], ['--resume', 'sid'])

    def test_bundled_protocol_matches_docs_copy(self):
        docs = Path(__file__).resolve().parents[1] / 'docs/parallel/DELEGATION.md'
        self.assertEqual(subject.BUNDLED_PROTOCOL.read_text(), docs.read_text())
        with mock.patch.object(subject, 'claude_version', return_value=(2, 1, 300)):
            cmd = subject.build_command('claude', self.meta(), 'P')
        self.assertEqual(cmd[cmd.index('--append-system-prompt-file') + 1], str(subject.BUNDLED_PROTOCOL))


class CodexTests(unittest.TestCase):
    def make_repo(self, tmp):
        repo = Path(tmp)
        git(repo, 'init', '-q', '-b', 'main')
        return repo

    def test_codex_command_is_workspace_write_with_git_dir_and_schema(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo = self.make_repo(tmp)
            meta = CommandTests.meta(self, agent='codex', worktree=str(repo), model=None, effort='max')
            cmd = subject.build_command('codex', meta, 'PROMPT', last_message=Path('/tmp/last.json'))
            self.assertEqual(cmd[:2], ['codex', 'exec'])
            self.assertEqual(cmd[-1], 'PROMPT')
            self.assertIn('sandbox_mode="workspace-write"', cmd)
            self.assertIn(f'sandbox_workspace_write.writable_roots={json.dumps([str((repo / ".git").resolve())])}', cmd)
            self.assertIn('model_reasoning_effort="xhigh"', cmd)
            self.assertNotIn('-m', cmd)
            self.assertEqual(cmd[cmd.index('-C') + 1], str(repo))
            resumed = subject.build_command('codex', meta, 'MORE', resume_id='tid')
            self.assertEqual(resumed[:4], ['codex', 'exec', 'resume', 'tid'])
            self.assertNotIn('-C', resumed)

    def test_codex_prompt_inlines_protocol(self):
        meta = CommandTests.meta(self, agent='codex', handoff_path='docs/parallel/b/CODEX_HANDOFF.md')
        prompt = subject.build_prompt(meta, 'Do it.')
        self.assertIn('You are Codex working as a delegated subagent for Claude', prompt)
        self.assertIn('Shared protocol', prompt)
        self.assertIn('CODEX_HANDOFF.md', prompt)

    def test_reads_codex_events_and_last_message(self):
        with tempfile.TemporaryDirectory() as tmp:
            out, last = Path(tmp, 'run.json'), Path(tmp, 'last.json')
            out.write_text('\n'.join([
                json.dumps({'type': 'thread.started', 'thread_id': 'abc'}),
                'not json',
                json.dumps({'type': 'turn.completed', 'usage': {'input_tokens': 5, 'output_tokens': 2}})]))
            last.write_text(json.dumps({'status': 'done'}))
            result = subject.read_codex_result({'output': str(out), 'last_message': str(last)})
            self.assertEqual(result['session_id'], 'abc')
            self.assertEqual(result['structured_output'], {'status': 'done'})
            self.assertFalse(result['is_error'])
            last.unlink()
            out.write_text(json.dumps({'type': 'turn.failed', 'error': {'message': 'quota'}}))
            failed = subject.read_codex_result({'output': str(out), 'last_message': str(last)})
            self.assertTrue(failed['is_error'])
            self.assertEqual(failed['result'], 'quota')


if __name__ == '__main__':
    unittest.main()

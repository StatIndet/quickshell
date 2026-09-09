#!/usr/bin/env python3
"""Black-box configuration contracts, all writes confined to temporary dirs."""
import concurrent.futures
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts/system'))
import niri_config as config


class ConfigurationContracts(unittest.TestCase):
    def setUp(self):
        environment = mock.patch.dict(os.environ)
        environment.start()
        self.addCleanup(environment.stop)
        os.environ.pop('NIRI_SOCKET', None)
        self.temp = tempfile.TemporaryDirectory(prefix='clavis-config-test-')
        self.addCleanup(self.temp.cleanup)
        self.main = Path(self.temp.name) / 'config.kdl'
        self.main.write_text('// User configuration\ninput {}\n')

    def run_config(self, operation='status', feature='binds', **kwargs):
        return config.run(dict(main=str(self.main), operation=operation, feature=feature, **kwargs))

    def fragment(self, feature='binds'):
        return self.main.parent / 'clavis' / (feature + '.kdl')

    def setup_binds(self):
        # Editing contracts start from an explicitly empty user fragment.
        self.fragment().parent.mkdir(exist_ok=True)
        if not self.fragment().exists():
            self.fragment().write_text('binds {}\n')
        self.run_config('setup')
        return self.run_config()

    def test_mouse_bindings_remain_visible_after_save_and_reload(self):
        self.setup_binds()
        keys = ['MouseLeft', 'MouseMiddle', 'MouseRight', 'MouseBack', 'Ctrl+MouseForward']
        for key in keys:
            self.run_config('save', key=key, action='close-window')
        rows = self.run_config()['bindings']
        self.assertEqual({row['key'] for row in rows}, set(keys))
        self.assertTrue(all(row['managed'] and row['editable'] for row in rows))
        forward = next(row for row in rows if row['key'] == 'Ctrl+MouseForward')
        self.run_config('delete', id=forward['id'])
        self.assertEqual({row['key'] for row in self.run_config()['bindings']}, set(keys[:-1]))

    def test_first_setup_defaults_are_unique_direct_ipc_and_not_restored(self):
        state = self.run_config('setup')
        rows = state['bindings']
        self.assertEqual(len(rows), len(config.DEFAULT_BINDINGS))
        self.assertEqual(len({row['identity'] for row in rows}), len(rows))
        self.assertTrue(all(not row.get('collision') for row in rows))
        for row in rows:
            action = config.parse(row['action']).nodes[0]
            self.assertEqual(action.name, 'spawn')
            self.assertEqual(action.args[:5], ['qs', '-c', 'clavis', 'ipc', 'call'])
            self.assertIs(row['props']['repeat'], False)
        self.run_config('delete', id=rows[0]['id'])
        remaining = self.fragment().read_bytes()
        self.run_config('setup')
        self.assertEqual(self.fragment().read_bytes(), remaining)

    def test_conflicts_follow_includes_and_clear_independently_of_unrelated_saves(self):
        self.main.write_text('binds { Control+F1 { close-window; }; }\n')
        self.setup_binds()
        self.main.parent.joinpath('unused.kdl').write_text('binds { F9 { quit; }; F9 { quit; }; }')
        state = self.run_config('save', key='Ctrl+F1', action='close-window', patch={'hotkey-overlay-title': 'Title'})
        self.assertFalse(state['diagnostics']['conflicts'])
        state = self.run_config('save', key='Ctrl+F1', action='quit')
        self.assertTrue(state['diagnostics']['conflicts'])
        self.assertTrue(state['diagnostics']['invalid'])
        self.assertTrue(all(row['collision'] for row in state['bindings']))
        duplicate = state['bindings'][-1]
        state = self.run_config('save', key='F2', action='close-window')
        self.assertTrue(state['diagnostics']['conflicts'])
        state = self.run_config('delete', id=duplicate['id'])
        self.assertFalse(state['diagnostics']['conflicts'])
        self.assertFalse(state['diagnostics']['invalid'])
        self.assertEqual(state['fragments']['binds']['state'], 'ready')
        self.main.write_text(self.main.read_text().replace('close-window', 'quit'))
        self.assertTrue(self.run_config()['diagnostics']['conflicts'])
        self.main.write_text(self.main.read_text().replace('quit', 'close-window'))
        self.assertFalse(self.run_config()['diagnostics']['conflicts'])

    def test_default_conflict_is_diagnostic_and_keeps_user_binding(self):
        self.main.write_text('binds { Super+Space { spawn "user-launcher"; }; }\n')
        state = self.run_config('setup')
        self.assertTrue(state['diagnostics']['conflicts'])
        self.assertIn('spawn "user-launcher"', self.main.read_text())
        self.assertTrue(self.fragment().exists())
        self.assertEqual(state['fragments']['binds']['state'], 'ready')

    def test_later_include_override_and_invalid_duplicate_are_distinct(self):
        self.setup_binds()
        self.run_config('save', key='F1', action='close-window')
        later = self.main.parent / 'later.kdl'
        later.write_text('binds { F1 { quit; }; }\n')
        with self.main.open('a') as out:
            out.write('include "later.kdl"\n')
        state = self.run_config()
        self.assertEqual(state['error'], '')
        later.write_text('binds { F1 { quit; }; F1 { close-window; }; }\n')
        state = self.run_config()
        self.assertTrue(state['diagnostics']['invalid'])
        self.assertTrue(all(row['collision'] for row in state['bindings']))
        self.assertEqual(state['fragments']['binds']['state'], 'ready')

    def test_group_deletion_keeps_external_binding(self):
        self.main.write_text('binds { F1 { spawn "never-run"; }; }\n')
        self.setup_binds()
        state = self.run_config('save', key='F2', action='spawn "never-run"')
        original = self.main.read_bytes()
        state = self.run_config('delete-group', group=state['bindings'][0]['group'])
        self.assertEqual(len(state['bindings']), 1)
        self.assertFalse(state['bindings'][0]['managed'])
        self.assertEqual(original, self.main.read_bytes())

    def test_edit_during_validation_is_not_overwritten(self):
        self.setup_binds()
        before = self.fragment().read_bytes()
        validator = self.main.parent / 'validator'
        validator.write_text('#!/usr/bin/env python3\nimport subprocess,sys,pathlib\nr=subprocess.run(["niri"]+sys.argv[1:])\npathlib.Path(' + repr(str(self.main)) + ').write_text("// edited externally\\n")\nsys.exit(r.returncode)\n')
        validator.chmod(0o700)
        with self.assertRaises(ValueError):
            self.run_config('save', key='F1', action='quit', niri=str(validator))
        self.assertEqual(self.fragment().read_bytes(), before)
        self.assertEqual(self.main.read_text(), '// edited externally\n')

    def test_mod_aliases_nested_mapping_and_typed_identity(self):
        self.main.write_text('input { mod-key "Alt"; mod-key-nested "Super"; }\nbinds { Mod+Q { close-window; }; }\n')
        graph = config.Graph(self.main)
        with mock.patch.object(config, 'session_nested', return_value=True):
            rows, mod = config.bindings(graph, self.fragment())
        self.assertEqual(mod, 'Super')
        self.assertEqual(rows[0]['identity'], config.key_identity('win+q'))
        self.assertEqual(config.key_identity('Control+Mod5+F1'), config.key_identity('ctrl+ISO_Level3_Shift+F1'))
        self.assertNotEqual(config.action_identity(config.parse('focus-workspace 1').nodes[0]), config.action_identity(config.parse('focus-workspace "1"').nodes[0]))

    def test_setup_preserves_crlf_and_unrelated_missing_include(self):
        original = b'// user formatting\r\ninput { }\r\n'
        self.main.write_bytes(original)
        self.setup_binds()
        self.assertTrue(self.main.read_bytes().startswith(original))
        self.main.write_text('include "unrelated-missing.kdl"\ninclude "clavis/effects.kdl"\n')
        before = self.main.read_bytes()
        with self.assertRaises(ValueError):
            self.run_config('setup', 'effects')
        self.assertFalse(self.fragment('effects').exists())
        self.assertEqual(before, self.main.read_bytes())

    def test_mod_spelling_collision_does_not_masquerade_as_include_override(self):
        self.main.write_text('binds { Mod+Q { close-window; }; }\n')
        self.setup_binds()
        state = self.run_config('save', key='Super+Q', action='quit')
        self.assertEqual(state['error'], '')
        first, last = state['bindings']
        self.assertTrue(first['collision'])
        self.assertTrue(last['collision'])
        self.assertFalse(last['override'])

    def test_read_linked_external_include_uses_its_logical_parent(self):
        elsewhere = self.main.parent / 'elsewhere'
        elsewhere.mkdir()
        real = elsewhere / 'shared.kdl'
        real.write_text('include "neighbor.kdl"\n')
        link = self.main.parent / 'linked.kdl'
        link.symlink_to(real)
        neighbor = self.main.parent / 'neighbor.kdl'
        neighbor.write_text('binds { F1 { close-window; }; }\n')
        self.main.write_text('include "linked.kdl"\n')
        native = subprocess.run(['niri', 'validate', '-c', str(self.main)], capture_output=True, text=True)
        self.assertEqual(native.returncode, 0, native.stderr)
        state = self.setup_binds()
        self.assertEqual(state['error'], '')
        self.assertEqual(state['bindings'][0]['key'], 'F1')
        self.assertIn(str(link), state['files'])

    def test_cursor_wrapper(self):
        script = str(ROOT / 'scripts/theme/write_niri_cursor_config.sh')
        args = [script, str(self.fragment('cursor')), str(self.main), 'Quoted "theme', '32', 'true', '1000', 'niri']
        self.assertNotEqual(subprocess.run(args, capture_output=True).returncode, 0)
        self.assertFalse(self.fragment('cursor').exists())
        result = subprocess.run(args + ['configure'], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        before = self.main.read_bytes()
        args[3] = 'Another theme'
        self.assertEqual(subprocess.run(args, capture_output=True).returncode, 0)
        self.assertEqual(before, self.main.read_bytes())

    def test_effects_wrapper(self):
        script = str(ROOT / 'scripts/system/manage-niri-effects.sh')
        args = [str(self.main), str(self.fragment('effects')), 'true', 'niri']
        self.assertNotEqual(subprocess.run([script, 'write'] + args, capture_output=True).returncode, 0)
        self.assertFalse(self.fragment('effects').exists())
        self.assertEqual(subprocess.run([script, 'configure'] + args, capture_output=True).returncode, 0)
        before = self.main.read_bytes()
        args[2] = 'false'
        self.assertEqual(subprocess.run([script, 'write'] + args, capture_output=True).returncode, 0)
        self.assertEqual(before, self.main.read_bytes())

    def test_read_does_not_initialize(self):
        before = self.main.read_bytes()
        for feature in config.FRAGMENTS:
            result = self.run_config(feature=feature)
            self.assertEqual(result['fragments'][feature]['state'], 'not-connected')
            with self.assertRaises(ValueError):
                self.run_config('update', feature)
        self.assertFalse(self.fragment().parent.exists())
        self.assertEqual(before, self.main.read_bytes())

    def test_individual_setup_empty_and_deleted_fragment(self):
        for feature in config.FRAGMENTS:
            with self.subTest(feature=feature):
                self.run_config('setup', feature)
                path = self.fragment(feature)
                self.assertTrue(path.exists())
                text = self.main.read_bytes()
                path.write_text('')
                self.run_config('setup', feature)
                self.assertEqual(path.read_text(), '')
                self.assertEqual(text, self.main.read_bytes())
                path.unlink()
                self.assertEqual(self.run_config(feature=feature)['fragments'][feature]['state'], 'missing')
                self.assertFalse(path.exists())
                self.run_config('setup', feature)
                self.assertEqual(text, self.main.read_bytes())
        self.assertTrue(list(self.main.parent.glob('config.kdl.clavis-backup-*')))

    def test_include_graph_comments_optional_and_equivalent_paths(self):
        self.fragment().parent.mkdir()
        self.fragment().write_text('')
        other = self.main.parent / 'other.kdl'
        other.write_text('include optional=true "./clavis/../clavis/binds.kdl"\n')
        self.main.write_text('/* include "missing.kdl" */\n/- include "missing.kdl"\ninclude "other.kdl"\n')
        self.assertEqual(self.run_config()['fragments']['binds']['state'], 'ready')
        before = self.main.read_bytes()
        self.run_config('setup')
        self.assertEqual(before, self.main.read_bytes())
        other.write_text('include "config.kdl"\n')
        self.assertIn('Recursive', self.run_config()['error'])
        with self.assertRaises(ValueError):
            self.run_config('setup')

    def test_generated_update_never_changes_main(self):
        for feature in ('cursor', 'effects', 'layer-rules'):
            self.run_config('setup', feature)
            before = self.main.read_bytes()
            self.run_config('update', feature, theme='A "quoted" \\ theme', xray=False)
            self.assertEqual(before, self.main.read_bytes())
            timestamp = self.fragment(feature).stat().st_mtime_ns
            self.run_config('update', feature, theme='A "quoted" \\ theme', xray=False)
            self.assertEqual(timestamp, self.fragment(feature).stat().st_mtime_ns)
        self.main.write_text('input {}\n')
        with self.assertRaises(ValueError):
            self.run_config('update', 'cursor')

    def test_external_override_preserves_properties_and_falls_back(self):
        self.main.write_text('binds { Mod+Q repeat=false cooldown-ms=100 hotkey-overlay-title=null { close-window; }; }\n')
        state = self.setup_binds()
        original = self.main.read_bytes()
        external = state['bindings'][0]
        state = self.run_config('save', id=external['id'], revision=state['revision'], patch={'hotkey-overlay-title': 'Close'})
        self.assertEqual(original, self.main.read_bytes())
        managed = state['bindings'][-1]
        self.assertTrue(managed['override'])
        self.assertFalse(managed['props']['repeat'])
        self.assertEqual(managed['props']['cooldown-ms'], 100)
        state = self.run_config('delete', id=managed['id'], revision=state['revision'])
        self.assertEqual(len(state['bindings']), 1)
        with self.assertRaises(ValueError):
            self.run_config('delete', id=external['id'])

    def test_roundtrip_argv_typed_values_and_untouched_special_sections(self):
        self.setup_binds()
        preserved = '// preserve me\nbinds { Mod+WheelScrollDown { focus-workspace-down; }; }\nswitch-events { lid-close { spawn "never-run"; }; }\n'
        self.fragment().write_text(preserved)
        expressions = ['spawn "never-run" "" "a b" "\\\\" "\\\""', 'spawn-sh "pkill qs || exit 1"', 'focus-workspace 1', 'focus-workspace "1"']
        identities = []
        for index, expression in enumerate(expressions):
            state = self.run_config('save', key='F' + str(index + 1), action=expression)
            row = state['bindings'][-1]
            identities.append(row['group'])
            self.assertEqual(config.parse(expression).nodes[0], config.parse(row['action']).nodes[0])
        self.assertNotEqual(identities[-2], identities[-1])
        self.assertIn('Mod+WheelScrollDown { focus-workspace-down; };', self.fragment().read_text())
        self.assertIn('switch-events { lid-close { spawn "never-run"; }; }', self.fragment().read_text())

    def test_invalid_candidate_rename_conflict_and_injection_preserve_file(self):
        self.setup_binds()
        state = self.run_config('save', key='Mod+Q', action='close-window')
        row = state['bindings'][0]
        before = self.fragment().read_bytes()
        for action in ['close-window; spawn "never"', 'close-window; }\nbinds { F1 { quit; } }']:
            with self.assertRaises(Exception):
                self.run_config('save', id=row['id'], key='F5', action=action)
            self.assertEqual(before, self.fragment().read_bytes())
        state = self.run_config('save', key='Super+q', action='quit')
        self.assertEqual(len(state['bindings']), 2)
        self.assertTrue(state['diagnostics']['conflicts'])

    def test_external_changes_and_parse_failure_do_not_overwrite(self):
        state = self.setup_binds()
        self.fragment().write_text('// new user content\n')
        with self.assertRaises(ValueError):
            self.run_config('save', revision=state['revision'], key='F1', action='quit')
        self.assertEqual(self.fragment().read_text(), '// new user content\n')
        self.fragment().write_text('binds { broken')
        with self.assertRaises(Exception):
            self.run_config('save', key='F1', action='quit')
        self.assertEqual(self.fragment().read_text(), 'binds { broken')

    def test_concurrent_setup_serializes_features(self):
        def setup(feature):
            request = dict(main=str(self.main), operation='setup', feature=feature)
            return subprocess.run([sys.executable, str(ROOT / 'scripts/system/niri_config.py'), json.dumps(request)], capture_output=True, text=True)
        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
            results = list(executor.map(setup, config.FRAGMENTS))
        for result in results:
            self.assertEqual(result.returncode, 0, result.stderr)
        state = self.run_config()
        self.assertTrue(all(f['state'] == 'ready' for f in state['fragments'].values()))

    def test_symlink_write_is_rejected(self):
        self.setup_binds()
        outside = self.main.parent / 'user.kdl'
        outside.write_text('')
        self.fragment().unlink()
        self.fragment().symlink_to(outside)
        with self.assertRaises(ValueError):
            self.run_config('save', key='F1', action='quit')
        self.assertEqual(outside.read_text(), '')

    def test_same_action_multiple_chips_have_independent_title_and_options(self):
        self.setup_binds()
        self.run_config('save', key='F1', action='close-window', patch={'hotkey-overlay-title': '', 'repeat': False})
        state = self.run_config('save', key='F2', action='close-window', patch={'hotkey-overlay-title': None, 'repeat': True})
        first, second = state['bindings']
        state = self.run_config('save', id=first['id'], patch={'hotkey-overlay-title': 'First'})
        self.assertIsNone(state['bindings'][1]['props']['hotkey-overlay-title'])
        self.assertTrue(state['bindings'][1]['props']['repeat'])
        self.assertEqual(first['group'], second['group'])


if __name__ == '__main__':
    if not shutil.which('niri'):
        raise SystemExit('niri is required for real isolated validation')
    unittest.main()

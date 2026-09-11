#!/usr/bin/env python3
"""On-demand niri configuration editor. JSON requests; never executes bindings."""
import copy
from contextlib import contextmanager
import ctypes
import fcntl
import hashlib
import json
import os
import re
from pathlib import Path
import stat
import socket
import struct
import subprocess
import sys
import tempfile
import niri_outputs

sys.path.insert(0, str(Path(__file__).parent / 'vendor'))
import kdl

PRINT = kdl.PrintConfig(indent='    ', semicolons=True)
FRAGMENTS = ('effects', 'cursor', 'layer-rules', 'binds', 'outputs')

# Stable first-setup defaults. Existing fragments, including empty ones, are preserved.
DEFAULT_BINDINGS = (
    ('Mod+Space', 'spotlight', 'toggle'),
    ('Mod+Slash', 'shortcut-map', 'toggle'),
    ('Mod+BackSpace', 'power-menu', 'toggle'),
    ('Mod+Shift+Space', 'spotlight', 'web'),
    ('Mod+Alt+V', 'spotlight', 'openMode', 'clipboard'),
    ('Mod+Alt+W', 'spotlight', 'openMode', 'wallpapers'),
    ('Mod+N', 'sidebar', 'toggle', 'left'),
    ('Mod+A', 'sidebar', 'toggle', 'right'),
    ('Mod+Ctrl+Comma', 'control-center', 'toggle', 'general'),
    ('Mod+Shift+W', 'keystone', 'hub'),
    ('Mod+Shift+T', 'keystone', 'tools'),
    ('Alt+Shift+L', 'lock', 'open'),
)


def read_text(path):
    # Preserve CRLF and every other untouched byte when appending/splicing.
    return path.read_bytes().decode('utf-8')


def parse(text):
    return kdl.parse(text, kdl.ParseConfig(nativeTaggedValues=False))


def render(node):
    return node.print(PRINT)


def canonical(node):
    # Types, empty arguments and action properties are part of the identity.
    return render(node).strip()


def path_key(path):
    return Path(os.path.realpath(path))


def main_path(request):
    if request.get('main'):
        return Path(request['main']).absolute()
    configured = os.environ.get('NIRI_CONFIG')
    if configured:
        return Path(configured).expanduser().absolute()
    # A known custom session config takes precedence over the XDG default.
    candidates = set()
    for entry in Path('/proc').iterdir():
        if not entry.name.isdigit():
            continue
        try:
            if entry.stat().st_uid != os.getuid():
                continue
            args = (entry / 'cmdline').read_bytes().decode().split('\0')
            if Path(args[0]).name != 'niri' or 'validate' in args or 'msg' in args:
                continue
            for i, arg in enumerate(args):
                if arg in ('-c', '--config'):
                    p = Path(args[i + 1]).expanduser()
                    if not p.is_absolute():
                        p = (entry / 'cwd').resolve() / p
                    candidates.add(str(p))
                elif arg.startswith('--config='):
                    p = Path(arg.split('=', 1)[1]).expanduser()
                    if not p.is_absolute():
                        p = (entry / 'cwd').resolve() / p
                    candidates.add(str(p))
        except (OSError, UnicodeError, IndexError):
            continue
    if len(candidates) > 1:
        raise ValueError('Multiple niri configuration paths are in use')
    if candidates:
        return Path(candidates.pop())
    return Path(os.environ.get('XDG_CONFIG_HOME', str(Path.home() / '.config'))) / 'niri/config.kdl'


class Graph:
    def __init__(self, main, repair=None, replacements=None, tolerant=False):
        self.main = main
        self.files = {}
        self.documents = {}
        self.references = set()
        self.include_targets = {}
        self.logical_paths = set()
        self.logical_targets = {}
        self.ordered = []
        self.missing = set()
        self.repair = repair
        self.replacements = replacements or {}
        self.error = None
        try:
            self.visit(main, [])
        except (ValueError, OSError, kdl.ParseError, subprocess.TimeoutExpired) as error:
            if not tolerant:
                raise
            self.error = error

    def visit(self, path, stack, optional=False):
        logical = Path(os.path.abspath(path))
        self.logical_paths.add(logical)
        path = path_key(logical)
        if logical in self.logical_targets and self.logical_targets[logical] != path:
            raise ValueError('Include link changed while reading; reload before saving')
        self.logical_targets[logical] = path
        if path in stack:
            raise ValueError('Recursive include: ' + str(path))
        if len(stack) > 64:
            raise ValueError('Include depth exceeds 64')
        self.files.setdefault(path, None)
        if path in self.replacements:
            text = self.replacements[path]
        else:
            try:
                if not stat.S_ISREG(path.stat().st_mode):
                    raise ValueError('Configuration is not a regular file: ' + str(path))
                text = read_text(path)
            except FileNotFoundError:
                self.files[path] = None
                self.missing.add(path)
                if optional or path == self.repair or (isinstance(self.repair, set) and path in self.repair):
                    return
                raise ValueError('Included configuration is missing: ' + str(path))
        if path in self.documents and self.files[path] != text:
            raise ValueError('Configuration changed while reading; reload before saving')
        self.files[path] = text
        doc = parse(text)
        self.documents[path] = doc
        for node in doc.nodes:
            if node.name == 'include':
                if len(node.args) != 1 or not isinstance(node.args[0], str) or node.nodes or set(node.props) - {'optional'}:
                    raise ValueError('Invalid include in ' + str(path))
                child = Path(node.args[0]).expanduser()
                child = child if child.is_absolute() else logical.parent / child
                target = path_key(child)
                key = (path, node.source_start)
                if key in self.include_targets and self.include_targets[key] != target:
                    raise ValueError('The same linked file has different relative include contexts; manage it manually')
                self.include_targets[key] = target
                self.references.add(target)
                self.visit(child, stack + [path], node.props.get('optional') is True)
            else:
                self.ordered.append((path, node))

    def revision(self):
        return hashlib.sha256(json.dumps([(str(p), t) for p, t in sorted(self.files.items())]).encode()).hexdigest()

    def unchanged(self):
        for logical, target in self.logical_targets.items():
            if path_key(logical) != target:
                raise ValueError('Include link changed externally; reload before saving')
        for path, text in self.files.items():
            try:
                current = read_text(path)
            except FileNotFoundError:
                current = None
            if text != current:
                raise ValueError('Configuration changed externally; reload before saving')

    def validate(self, command='niri'):
        # Mirror only the effective include graph. Absolute includes must point at
        # staged candidates too; flattening would change duplicate/merge semantics.
        with tempfile.TemporaryDirectory(prefix='clavis-niri-validate-') as directory:
            paths = {p: Path(directory) / (str(i) + '.kdl') for i, p in enumerate(self.files)}
            for path, text in self.files.items():
                if text is None:
                    continue
                changes = []
                for node in self.documents[path].nodes:
                    if node.name != 'include':
                        continue
                    child = self.include_targets[(path, node.source_start)]
                    replacement = copy.deepcopy(node)
                    replacement.args = [str(paths[child])]
                    changes.append((node.source_start, node.source_end, render(replacement)))
                for start, end, value in reversed(changes):
                    text = text[:start] + value + text[end:]
                paths[path].write_text(text)
            result = subprocess.run([command, 'validate', '-c', str(paths[path_key(self.main)])], capture_output=True, text=True, timeout=20)
            if result.returncode:
                raise ValueError(result.stderr.strip() or result.stdout.strip() or 'niri validation failed')


def safe_target(path, missing=False):
    for parent in [path, *path.parents]:
        if parent.is_symlink():
            raise ValueError('Symbolic links are read-only: ' + str(parent))
    if path.exists():
        info = path.stat()
        if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1:
            raise ValueError('Special or hard-linked files are read-only: ' + str(path))
        if not os.access(path, os.W_OK):
            raise ValueError('Configuration is not writable: ' + str(path))
    elif not missing:
        raise ValueError('Managed fragment is missing; use Set up')
    parent = path.parent
    while not parent.exists():
        parent = parent.parent
    if not os.access(parent, os.W_OK):
        raise ValueError('Configuration directory is not writable: ' + str(parent))


def replace_file(path, text):
    fd, name = tempfile.mkstemp(prefix='.clavis-', dir=path.parent)
    try:
        if path.exists():
            os.fchmod(fd, stat.S_IMODE(path.stat().st_mode))
        with os.fdopen(fd, 'w') as out:
            out.write(text)
            out.flush()
            os.fsync(out.fileno())
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def initial(feature, request):
    header = '// Managed by Clavis.\n'
    if feature == 'outputs':
        return header
    if feature == 'binds':
        section = kdl.Node('binds')
        for key, *command in DEFAULT_BINDINGS:
            section.nodes.append(kdl.Node(key, props={'repeat': False}, nodes=[
                kdl.Node('spawn', args=['qs', '-c', 'clavis', 'ipc', 'call', *command])]))
        return header + render(section)
    if feature == 'layer-rules':
        return header + 'layer-rule {\n    match namespace="^clavis-overview-wallpaper$";\n    place-within-backdrop true;\n}\nlayout {\n    background-color "transparent";\n}\n'
    if feature == 'effects':
        if request.get('xray', True):
            return header + "// X-Ray is niri's default for client-requested effects.\n"
        return header + 'layer-rule {\n    match namespace="^clavis-shell-";\n    background-effect { xray false; };\n}\nwindow-rule {\n    match title="^(clavis-control-center(-[a-z-]+)?|clavis-file-picker)$";\n    background-effect { xray false; };\n}\n'
    size = int(request.get('size', 24))
    hide = int(request.get('hideAfter', 0))
    if not 12 <= size <= 128 or not 0 <= hide <= 5000:
        raise ValueError('Invalid cursor size or inactivity interval')
    node = kdl.Node('cursor')
    if request.get('theme'):
        node.nodes.append(kdl.Node('xcursor-theme', args=[request['theme']]))
    node.nodes.append(kdl.Node('xcursor-size', args=[size]))
    if request.get('hideTyping'):
        node.nodes.append(kdl.Node('hide-when-typing'))
    if hide:
        node.nodes.append(kdl.Node('hide-after-inactive-ms', args=[hide]))
    return header + render(node)


_xkb = ctypes.CDLL('libxkbcommon.so.0')
_xkb.xkb_keysym_from_name.argtypes = [ctypes.c_char_p, ctypes.c_int]
_xkb.xkb_keysym_from_name.restype = ctypes.c_uint32
_xkb.xkb_keysym_to_lower.argtypes = [ctypes.c_uint32]
_xkb.xkb_keysym_to_lower.restype = ctypes.c_uint32


def key_identity(key, mod='Super'):
    parts = key.split('+')
    aliases = {'control': 'Ctrl', 'ctrl': 'Ctrl', 'win': 'Super', 'super': 'Super', 'shift': 'Shift', 'alt': 'Alt', 'mod5': 'ISO_Level3_Shift', 'iso_level3_shift': 'ISO_Level3_Shift', 'iso_level5_shift': 'ISO_Level5_Shift', 'mod': mod}
    modifiers = set()
    for part in parts[:-1]:
        if part.lower() not in aliases:
            raise ValueError('Invalid key modifier: ' + part)
        modifiers.add(aliases[part.lower()])
    mouse = {name.lower(): name for name in ('MouseLeft', 'MouseMiddle', 'MouseRight', 'MouseBack', 'MouseForward')}
    if parts[-1].lower() in mouse:
        return '+'.join(sorted(modifiers)) + ':' + mouse[parts[-1].lower()]
    sym = _xkb.xkb_keysym_from_name(parts[-1].encode(), 1)
    if parts[-1].lower() == 'xf86screensaver':
        sym = _xkb.xkb_keysym_from_name(parts[-1].encode(), 0) or _xkb.xkb_keysym_from_name(b'XF86ScreenSaver', 0)
    if not sym:
        raise ValueError('Unknown XKB key name: ' + parts[-1])
    return '+'.join(sorted(modifiers)) + ':' + str(_xkb.xkb_keysym_to_lower(sym))


def action_identity(action):
    action = copy.deepcopy(action)
    action.props = dict(sorted(action.props.items()))
    if action.name == 'spawn' and action.args[:3] == ['key', 'ipc', 'call']:
        entries = json.loads((Path(__file__).parent / 'niri-actions.json').read_text())
        if any(e.get('target') == action.args[3] and e.get('method') == action.args[4] for e in entries) if len(action.args) >= 5 else False:
            action.args = ['qs', '-c', 'clavis', 'ipc', 'call'] + action.args[3:]
    return canonical(action)


def session_nested():
    endpoint = os.environ.get('NIRI_SOCKET')
    if not endpoint:
        return False  # Offline configuration uses niri's normal TTY default.
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as peer:
        peer.settimeout(2)
        peer.connect(endpoint)
        pid, _, _ = struct.unpack('3i', peer.getsockopt(socket.SOL_SOCKET, socket.SO_PEERCRED, 12))
    process = Path('/proc') / str(pid)
    arguments = (process / 'cmdline').read_bytes().split(b'\0')
    if b'--headless' in arguments:
        return False
    # Inspect only the names needed by niri's backend selection. No environment
    # values are returned, logged, or persisted.
    names = {entry.split(b'=', 1)[0] for entry in (process / 'environ').read_bytes().split(b'\0')}
    return bool(names & {b'DISPLAY', b'WAYLAND_DISPLAY', b'WAYLAND_SOCKET'})


def bindings(graph, managed):
    mod = 'Super'
    nested_mod = None
    for _, node in graph.ordered:
        if node.name == 'input':
            for child in node.nodes:
                if child.name == 'mod-key' and child.args:
                    mod = child.args[0]
                if child.name == 'mod-key-nested' and child.args:
                    nested_mod = child.args[0]
    if session_nested():
        mod = nested_mod or ('Super' if mod.lower() == 'alt' else 'Alt')
    rows = []
    for path, section in graph.ordered:
        if section.name != 'binds':
            continue
        for node in section.nodes:
            if any(node.name.split('+')[-1].lower().startswith(p) for p in ('wheelscroll', 'touchpadscroll', 'tabletstylusbutton')):
                continue
            identity = key_identity(node.name, mod)
            action = node.nodes[0] if len(node.nodes) == 1 else None
            row = dict(id=str(path) + ':' + str(node.source_start), key=node.name, identity=identity,
                       symbolicIdentity=key_identity(node.name, 'Mod'),
                       action=canonical(action) if action else '', group=action_identity(action) if action else '', source=str(path), managed=path == managed,
                       props={key: str(value) if isinstance(value, kdl.Value) else value for key, value in node.props.items()},
                       editable=action is not None and not node.tag and not node.args and not action.tag and not action.nodes and not any(isinstance(value, kdl.Value) for value in node.props.values()),
                       start=node.source_start, end=node.source_end,
                       raw=graph.files[path][node.source_start:node.source_end], override=False, section=str(path) + ':' + str(section.source_start))
            for previous in rows:
                if previous['symbolicIdentity'] == row['symbolicIdentity']:
                    if previous['source'] != str(managed) and row['managed']:
                        row['override'] = True
            rows.append(row)
    # Diagnose disk definitions, not which command the compositor will execute.
    by_key = {}
    for row in rows:
        by_key.setdefault(row['identity'], []).append(row)
    for matches in by_key.values():
        different_actions = len({row['group'] or row['action'] for row in matches}) > 1
        sections = [row['section'] for row in matches]
        duplicate_section = len(set(sections)) < len(sections)
        for row in matches:
            row['collision'] = different_actions or duplicate_section
    return rows, mod


def status(request):
    main = main_path(request)
    managed_dir = main.parent / 'clavis'
    state = dict(schemaVersion=1, main=str(main), fragments={}, files=[str(main)], bindings=[], revision='', error='', diagnostics=dict(conflicts=False, invalid=False, writable=True, details=''))
    # Inspect missing managed fragments without initializing them.
    try:
        graph = Graph(main, repair={path_key(managed_dir / (f + ".kdl")) for f in FRAGMENTS}, tolerant=True)
        state['files'] = sorted(set([str(p) for p in graph.files] + [str(p) for p in graph.logical_paths] + [str(managed_dir / (f + '.kdl')) for f in FRAGMENTS] + [str(main)]))
        if graph.error:
            raise graph.error
        state['revision'] = graph.revision()
        state['outputs'] = niri_outputs.inspect(graph, path_key(managed_dir / 'outputs.kdl'))
        state['bindings'], state['modKey'] = bindings(graph, path_key(managed_dir / 'binds.kdl'))
        state['diagnostics']['conflicts'] = any(row['collision'] for row in state['bindings'])
        try:
            safe_target(managed_dir / 'binds.kdl', missing=True)
        except (OSError, ValueError):
            state['diagnostics']['writable'] = False
        for feature in FRAGMENTS:
            path = path_key(managed_dir / (feature + '.kdl'))
            included = path in graph.references
            state['fragments'][feature] = dict(path=str(path), state=('ready' if path.exists() else 'missing') if included else 'not-connected')
        state['keymap'] = {}
        for _, node in graph.ordered:
            if node.name == 'input':
                for keyboard in node.nodes:
                    if keyboard.name == 'keyboard':
                        for xkb in keyboard.nodes:
                            if xkb.name == 'xkb':
                                for option in xkb.nodes:
                                    if option.args and option.name in ('rules', 'model', 'layout', 'variant', 'options', 'file'):
                                        state['keymap'][option.name] = option.args[0]
        if state['keymap'].get('file'):
            keymap_path = Path(state['keymap']['file']).expanduser()
            if keymap_path.is_absolute():
                state['files'].append(str(keymap_path))
        transparent = False
        backdrop = False
        for _, node in graph.ordered:
            if node.name == 'layout':
                for child in node.nodes:
                    if child.name == 'background-color':
                        transparent = child.args == ['transparent'] or child.args == ['#00000000']
            if node.name == 'layer-rule':
                matches = [c for c in node.nodes if c.name == 'match']
                if any(c.props == {'namespace': '^clavis-overview-wallpaper$'} for c in matches) and not any(c.name == 'exclude' for c in node.nodes):
                    for child in node.nodes:
                        if child.name == 'place-within-backdrop':
                            backdrop = child.args == [True]
        if not graph.missing:
            try:
                graph.validate(request.get('niri', 'niri'))
            except ValueError as error:
                state['diagnostics']['invalid'] = True
                state['diagnostics']['details'] = str(error)
        state['overviewSatisfied'] = transparent and backdrop
        state['overviewBackdrop'] = backdrop
        state['overviewTransparent'] = transparent
    except (ValueError, OSError, kdl.ParseError, subprocess.TimeoutExpired) as error:
        state['error'] = str(error)
        for feature in FRAGMENTS:
            state['fragments'][feature] = dict(path=str(managed_dir / (feature + '.kdl')), state='error')
    try:
        version = subprocess.run([request.get('niri', 'niri'), '--version'], capture_output=True, text=True, timeout=5)
        match = re.search(r'\b(\d+)\.(\d+)', version.stdout)
        if not match:
            raise ValueError('Unable to determine the niri version')
        current = tuple(map(int, match.groups()))
        state['niriVersion'] = version.stdout.strip()
        for feature, fragment in state['fragments'].items():
            if current < ((26, 4) if feature == 'effects' else (25, 11)):
                fragment['state'] = 'unsupported'
    except (OSError, ValueError, subprocess.TimeoutExpired) as error:
        state['error'] = str(error)
        for fragment in state['fragments'].values():
            fragment['state'] = 'unsupported'
    return state


def edit_bindings(graph, path, request):
    rows, mod = bindings(graph, path)
    selected = next((r for r in rows if r['id'] == request.get('id')), None)
    if request.get('id') and selected is None:
        raise ValueError('Binding changed externally; reload before saving')
    text = graph.files[path]
    parse(text)  # Never recover a parse failure as an empty managed document.
    if request['operation'] == 'delete-group':
        owned = [row for row in rows if row['managed'] and row['group'] == request.get('group')]
        if not owned:
            raise ValueError('This action has no Clavis bindings to delete')
        for row in sorted(owned, key=lambda row: row['start'], reverse=True):
            text = text[:row['start']] + text[row['end']:]
        return text
    if request['operation'] == 'delete':
        if not selected or not selected['managed']:
            raise ValueError('Bindings in user configuration cannot be deleted here')
        return text[:selected['start']] + text[selected['end']:]
    if selected and not selected['editable']:
        raise ValueError('This binding is read-only')
    key = request.get('key', selected['key'] if selected else '')
    if selected and not selected['managed'] and key != selected['key']:
        raise ValueError('Use + to add another key; the external key remains configured')
    key_identity(key, mod)
    action_text = request.get('action', selected['action'] if selected else '')
    actions = parse(action_text + '\n').nodes
    if len(actions) != 1 or actions[0].nodes or actions[0].tag:
        raise ValueError('Enter exactly one niri action expression without a binds wrapper')
    node = parse(selected['raw']).nodes[0] if selected else kdl.Node(key)
    node.name = key
    node.nodes = actions
    for name, value in request.get('patch', {}).items():
        if name not in ('hotkey-overlay-title', 'repeat', 'allow-when-locked', 'cooldown-ms', 'allow-inhibiting'):
            raise ValueError('Unsupported binding option: ' + name)
        node.props[name] = value
    for name in request.get('unset', []):
        node.props.pop(name, None)
    if 'allow-when-locked' in node.props and actions[0].name not in ('spawn', 'spawn-sh'):
        raise ValueError('Remove allow-when-locked before switching to a non-spawn action')
    for name in request.get('unset', []):
        node.props.pop(name, None)
    value = render(node)
    if selected and selected['managed']:
        return text[:selected['start']] + value + text[selected['end']:]
    sections = [n for n in graph.documents[path].nodes if n.name == 'binds']
    if len(sections) > 1:
        raise ValueError('Duplicate binds sections; fix the managed file before saving')
    if sections:
        section = sections[0]
        if not hasattr(section, 'children_end'):
            raise ValueError('The binds section needs a child block')
        at = section.children_end
        return text[:at] + '\n' + value + text[at:]
    return text + '\nbinds {\n' + value + '}\n'


@contextmanager
def configuration_lock(main, nonblocking=False):
    # Share the same lock across the editor and the ephemeral preview guardian.
    lock_dir = Path(os.environ.get('XDG_RUNTIME_DIR', tempfile.gettempdir()))
    lock_path = lock_dir / ('clavis-niri-' + str(os.getuid()) + '-' + hashlib.sha256(str(main).encode()).hexdigest()[:20] + '.lock')
    fd = os.open(lock_path, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    info = os.fstat(fd)
    if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or info.st_nlink != 1:
        os.close(fd)
        raise ValueError('Unsafe configuration lock file')
    with os.fdopen(fd, 'w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | (fcntl.LOCK_NB if nonblocking else 0))
        yield


def restore_output_publication(main, candidate, previous):
    path = main.parent / 'clavis/outputs.kdl'
    with configuration_lock(main, nonblocking=True):
        safe_target(path)
        if read_text(path) != candidate:
            raise ValueError('Output configuration changed externally; the preview will not overwrite it')
        replace_file(path, previous)


def mutate(request):
    if request.get('operation') not in ('setup', 'update', 'save', 'delete', 'delete-group'):
        raise ValueError('Unknown write operation')
    feature = request['feature']
    if feature not in FRAGMENTS:
        raise ValueError('Unknown managed fragment')
    main = main_path(request)
    path = main.parent / 'clavis' / (feature + '.kdl')
    safe_target(main)
    safe_target(path, missing=request['operation'] == 'setup')
    with configuration_lock(main, nonblocking=feature == 'outputs' and request['operation'] != 'setup'):
        safe_target(main)
        safe_target(path, missing=request['operation'] == 'setup')
        graph = Graph(main, repair=path_key(path))
        if request.get('revision') and request['revision'] != graph.revision():
            raise ValueError('Configuration changed externally; reload before saving')
        included = path_key(path) in graph.references
        exists = path.exists()
        if request['operation'] != 'setup' and (not included or not exists):
            raise ValueError('Fragment is not connected; use Set up')
        previous = read_text(path) if exists else None
        if exists:
            parse(previous)
        if request['operation'] == 'setup':
            candidate = previous if exists else initial(feature, request)
        elif feature == 'outputs':
            candidate = niri_outputs.edit(graph, path_key(path), request, sys.modules[__name__])
        elif feature == 'binds':
            candidate = edit_bindings(graph, path_key(path), request)
        else:
            candidate = initial(feature, request)
        main_text = graph.files[path_key(main)]
        main_candidate = main_text
        if request['operation'] == 'setup' and not included:
            main_candidate += '\n' + render(kdl.Node('include', args=['clavis/' + feature + '.kdl']))
        replacements = {path_key(main): main_candidate, path_key(path): candidate}
        candidate_graph = Graph(main, replacements=replacements)
        try:
            candidate_graph.validate(request.get('niri', 'niri'))
        except ValueError:
            if feature != 'binds':
                raise
            # A parseable binding may still be rejected by niri. Publish the
            # user's edit and expose validation as current diagnostics instead.

        graph.unchanged()
        if (read_text(path) if path.exists() else None) != previous:
            raise ValueError('Managed fragment changed externally; reload before saving')
        safe_target(main)
        safe_target(path, missing=not exists)
        if main_candidate != main_text:
            backup_fd, backup_name = tempfile.mkstemp(prefix=main.name + '.clavis-backup-', dir=main.parent)
            with os.fdopen(backup_fd, 'w') as backup:
                backup.write(main_text)
                backup.flush()
                os.fsync(backup.fileno())
        path.parent.mkdir(exist_ok=True)
        published = False
        try:
            if candidate != previous:
                replace_file(path, candidate)
                published = True
            if main_candidate != main_text:
                # Detect main/include edits after fragment publication too.
                for source, text in graph.files.items():
                    if source != path_key(path) and (read_text(source) if source.exists() else None) != text:
                        raise ValueError('Configuration changed during setup; retry')
                replace_file(main, main_candidate)
        except Exception:
            if published and read_text(path) == candidate:
                if previous is None:
                    path.unlink()
                else:
                    replace_file(path, previous)
            raise
    return status(dict(request, operation='status'))


def catalog(request):
    entries = json.loads((Path(__file__).parent / 'niri-actions.json').read_text())
    with tempfile.TemporaryDirectory(prefix='clavis-actions-') as directory:
        path = Path(directory) / 'config.kdl'
        for entry in entries:
            if entry['category'] == 'clavis':
                entry['supported'] = True
                continue
            path.write_text('binds { F24 { ' + entry['expression'] + '; }; }\n')
            result = subprocess.run([request.get('niri', 'niri'), 'validate', '-c', str(path)], capture_output=True, text=True, timeout=20)
            entry['supported'] = result.returncode == 0
            entry['error'] = result.stderr.strip() if result.returncode else ''
    return dict(schemaVersion=1, catalog=entries)


def run(request):
    if request.get('operation') == 'catalog':
        return catalog(request)
    if request.get('operation', 'status') == 'status':
        return status(request)
    return mutate(request)


def legacy(args):
    kind, *values = args
    if kind == '--effects':
        mode, main, fragment, xray, *command = values
        if xray not in ('true', 'false'):
            raise ValueError('Invalid X-Ray value')
        request = dict(operation={'write': 'update', 'configure': 'setup'}[mode], feature='effects', main=main, xray=xray == 'true', niri=command[0] if command else 'niri')
    elif kind == '--cursor':
        fragment, main, theme, size, typing, hide, *rest = values
        if typing not in ('true', 'false'):
            raise ValueError('Invalid hide-when-typing value')
        request = dict(operation='setup' if len(rest) > 1 and rest[1] == 'configure' else 'update', feature='cursor', main=main, theme=theme, size=int(size), hideTyping=typing == 'true', hideAfter=int(hide), niri=rest[0] if rest else 'niri')
    else:
        mode, main, fragment, *rest = values
        if mode != 'configure':
            raise ValueError('Expected configure')
        request = dict(operation='setup', feature=Path(fragment).stem, main=main, niri=rest[0] if rest else 'niri')
    if Path(fragment).absolute() != main_path(request).parent / 'clavis' / (request['feature'] + '.kdl'):
        raise ValueError('Only the corresponding clavis fragment can be written')
    return request


if __name__ == '__main__':
    try:
        request = legacy(sys.argv[1:]) if len(sys.argv) > 1 and sys.argv[1].startswith('--') else json.loads(sys.argv[1]) if len(sys.argv) > 1 else json.load(sys.stdin)
        print(json.dumps(run(request), ensure_ascii=False))
    except Exception as error:
        print(json.dumps(dict(schemaVersion=1, error=str(error))), flush=True)
        print(str(error), file=sys.stderr)
        sys.exit(1)

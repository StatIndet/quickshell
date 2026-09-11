"""Structured output settings for the existing niri configuration graph.

The first matching output block wins in niri 26.04. Never shadow external
blocks by relying on include order, nor rewrite unknown output children.
"""
import copy
import math

TRANSFORMS = ('normal', '90', '180', '270', 'flipped', 'flipped-90', 'flipped-180', 'flipped-270')
BASIC = ('off', 'mode', 'scale', 'transform', 'position', 'variable-refresh-rate', 'focus-at-startup', 'hot-corners')
LAYOUT = ('gaps', 'default-column-width', 'preset-column-widths', 'always-center-single-column')


def identity(output):
    return ' '.join(str(output.get(key) or 'Unknown') for key in ('make', 'model', 'serial'))


def matches(name, output):
    return name.lower() in (output['name'].lower(), identity(output).lower())


def number(value, low, high):
    if isinstance(value, bool) or not isinstance(value, (float, int)) or not math.isfinite(value) or not low <= value <= high:
        raise ValueError('Output value is outside its allowed range')
    return value


def inspect(graph, managed):
    rows = []
    for path, node in graph.ordered:
        if node.name != 'output':
            continue
        if len(node.args) != 1 or not isinstance(node.args[0], str):
            raise ValueError('Invalid output identifier')
        settings = {}
        editable = not node.tag and not node.props
        seen = set()
        for child in node.nodes:
            if child.name not in BASIC + ('layout',):
                continue
            if child.name in seen or child.tag:
                editable = False
            seen.add(child.name)
            name = child.name
            if name in ('off', 'focus-at-startup') and (child.args or child.nodes or child.props): editable = False
            if name == 'off': settings['enabled'] = False
            elif name in ('mode', 'scale', 'transform'):
                if len(child.args) == 1 and not child.props and not child.nodes:
                    settings[name] = child.args[0]
                else: editable = False
            elif name == 'position':
                if set(child.props) == {'x', 'y'} and not child.args and not child.nodes:
                    settings['position'] = dict(child.props)
                else: editable = False
            elif name == 'variable-refresh-rate':
                if child.args or child.nodes or set(child.props)-{'on-demand'} or not isinstance(child.props.get('on-demand', False), bool): editable = False
                settings['vrr'] = 'on-demand' if child.props.get('on-demand') else 'on'
            elif name == 'focus-at-startup': settings['focusAtStartup'] = True
            elif name == 'hot-corners':
                if child.args or child.props: editable = False
                corners = [c.name for c in child.nodes]
                if any(c.args or c.props or c.nodes or c.tag for c in child.nodes) or any(c not in ('off', 'top-left', 'top-right', 'bottom-left', 'bottom-right') for c in corners):
                    editable = False
                settings['hotCorners'] = corners
            elif name == 'layout':
                if child.args or child.props: editable = False
                layout_seen = set()
                for option in child.nodes:
                    if option.name not in LAYOUT: continue
                    if option.name in layout_seen or option.tag or option.props: editable = False
                    layout_seen.add(option.name)
                    if option.name in ('gaps', 'always-center-single-column'):
                        settings[option.name] = option.args[0] if option.args else True
                    else:
                        widths = []
                        for width in option.nodes:
                            if width.name not in ('proportion', 'fixed') or len(width.args) != 1 or width.nodes or width.props or width.tag:
                                editable = False
                                continue
                            widths.append(dict(kind=width.name, value=width.args[0]))
                        settings[option.name] = widths
        # modeline overrides mode; do not expose a misleading editable mode.
        if any(c.name == 'modeline' for c in node.nodes): editable = False
        rows.append(dict(identifier=node.args[0], source=str(path), managed=path == managed,
                         settings=settings, editable=editable, start=node.source_start, end=node.source_end))
    return rows


def encode(settings, api):
    kdl = api.kdl
    nodes = []
    if settings.get('enabled') is False: nodes.append(kdl.Node('off'))
    if settings.get('mode') is not None:
        mode = settings['mode']
        if not isinstance(mode, str) or len(mode) > 100: raise ValueError('Invalid output mode')
        nodes.append(kdl.Node('mode', args=[mode]))
    if settings.get('scale') is not None:
        nodes.append(kdl.Node('scale', args=[number(settings['scale'], 0.1, 10)]))
    if settings.get('transform') is not None:
        if settings['transform'] not in TRANSFORMS: raise ValueError('Invalid output transform')
        nodes.append(kdl.Node('transform', args=[settings['transform']]))
    if settings.get('position') is not None:
        position = settings['position']
        nodes.append(kdl.Node('position', props={key: int(number(position[key], -2147483648, 2147483647)) for key in ('x', 'y')}))
    if settings.get('vrr', 'off') not in ('off', 'on', 'on-demand'): raise ValueError('Invalid VRR policy')
    if settings.get('vrr', 'off') != 'off':
        nodes.append(kdl.Node('variable-refresh-rate', props={'on-demand': settings['vrr'] == 'on-demand'}))
    if settings.get('focusAtStartup') is True: nodes.append(kdl.Node('focus-at-startup'))
    corners = settings.get('hotCorners')
    if corners is not None:
        if not corners or len(set(corners)) != len(corners) or any(c not in ('off', 'top-left', 'top-right', 'bottom-left', 'bottom-right') for c in corners) or ('off' in corners and len(corners) > 1):
            raise ValueError('Invalid hot corners override')
        nodes.append(kdl.Node('hot-corners', nodes=[kdl.Node(c) for c in corners]))
    layout = []
    for key in LAYOUT:
        value = settings.get(key)
        if value is None: continue
        if key == 'gaps': layout.append(kdl.Node(key, args=[number(value, 0, 65535)]))
        elif key == 'always-center-single-column':
            if not isinstance(value, bool): raise ValueError('Invalid boolean override')
            layout.append(kdl.Node(key, args=[value]))
        else:
            if not isinstance(value, list) or len(value) > 32 or (key == 'default-column-width' and len(value) > 1):
                raise ValueError('Invalid column widths')
            widths = []
            for item in value:
                kind = item['kind']
                if kind not in ('fixed', 'proportion'): raise ValueError('Invalid column width type')
                numeric = number(item['value'], 1 if kind == 'fixed' else 0.01, 65535 if kind == 'fixed' else 100)
                if kind == 'fixed' and int(numeric) != numeric: raise ValueError('Fixed widths must be whole pixels')
                widths.append(kdl.Node(kind, args=[int(numeric) if kind == 'fixed' else numeric]))
            layout.append(kdl.Node(key, nodes=widths))
    return nodes, layout


def edit(graph, path, request, api):
    text = graph.files[path]
    rows = inspect(graph, path)
    patches = request.get('outputs', [])
    if not isinstance(patches, list) or len(patches) > 64: raise ValueError('Invalid output configuration')
    ids = [p['identifier'].lower() for p in patches]
    if len(set(ids)) != len(ids): raise ValueError('Duplicate output identifiers')
    changes = []
    for patch in patches:
        identifier = patch['identifier']
        if not isinstance(identifier, str) or not identifier or len(identifier) > 512: raise ValueError('Invalid output identifier')
        candidates = [r for r in rows if r['identifier'].lower() == identifier.lower()]
        if len(candidates) > 1: raise ValueError('Duplicate output blocks; resolve the conflict before editing')
        selected = candidates[0] if candidates else None
        # Runtime metadata identifies alternative connector/make/model matches.
        live = patch.get('identity')
        if live and sum(matches(r['identifier'], live) for r in rows) > 1:
            raise ValueError('Multiple output blocks match this display; resolve the conflict before editing')
        if any(not r['managed'] and (r['identifier'].lower() == identifier.lower() or (live and matches(r['identifier'], live))) for r in rows):
            raise ValueError('Output is configured in another file; edit that file to resolve the conflict')
        if selected and not selected['managed']: raise ValueError('External output blocks are read-only')
        if selected and not selected['editable']: raise ValueError('This output contains unsupported syntax; edit it manually')
        if patch.get('delete'):
            if selected: changes.append((selected['start'], selected['end'], ''))
            continue
        basic, layout = encode(patch['settings'], api)
        if selected:
            node = next(n for n in graph.documents[path].nodes if n.source_start == selected['start'])
            # Splice only managed children; unknown nodes and their comments stay byte-for-byte.
            edits = [(c.source_start, c.source_end, '') for c in node.nodes if c.name in BASIC]
            section = next((c for c in node.nodes if c.name == 'layout'), None)
            if section:
                edits += [(c.source_start, c.source_end, '') for c in section.nodes if c.name in LAYOUT]
                if not hasattr(section, 'children_end'): raise ValueError('Layout override needs a child block')
                edits.append((section.children_end, section.children_end, '\n'+''.join(api.render(n) for n in layout)))
            elif layout:
                basic.append(api.kdl.Node('layout', nodes=layout))
            if not hasattr(node, 'children_end'): raise ValueError('Output configuration needs a child block')
            edits.append((node.children_end, node.children_end, '\n'+''.join(api.render(n) for n in basic)))
            changes.extend(edits)
        else:
            if layout: basic.append(api.kdl.Node('layout', nodes=layout))
            changes.append((len(text), len(text), '\n'+api.render(api.kdl.Node('output', args=[identifier], nodes=basic))))
    for start, end, value in reversed(sorted(changes, key=lambda change: (change[0], change[1]))):
        text = text[:start]+value+text[end:]
    return text

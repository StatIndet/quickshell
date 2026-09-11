#!/usr/bin/env python3
"""Ephemeral display preview guardian. Runs only while a preview is owned.

No disk output changes until Keep; EOF/shell death, deadlines, unplug and
external edits restore connected outputs. Control is via a private Unix socket.
"""
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import select
import signal
import socket
import stat
import sys
import tempfile
import time

import niri_config as config
import niri_outputs as outputs


def copy_settings(value):
    return json.loads(json.dumps(value))


def ipc(request):
    with socket.socket(socket.AF_UNIX) as peer:
        peer.settimeout(2)
        peer.connect(os.environ['NIRI_SOCKET'])
        peer.sendall((json.dumps(request)+'\n').encode())
        data = bytearray()
        while b'\n' not in data:
            chunk = peer.recv(65536)
            if not chunk: raise ValueError('Niri disconnected before replying')
            data.extend(chunk)
            if len(data) > 8*1024*1024: raise ValueError('Niri reply exceeds size limit')
        result = json.loads(data.split(b'\n')[0])
        if 'Err' in result: raise ValueError(result['Err'])
        if 'Ok' not in result: raise ValueError('Invalid Niri reply')
        value = result['Ok']
        return value.get(request, value) if isinstance(request, str) and isinstance(value, dict) else value


def connection_key(live):
    return sorted((name, outputs.identity(dict(data, name=name))) for name, data in live.items())


def live_settings(data):
    settings = dict(enabled=data.get('current_mode') is not None)
    logical = data.get('logical')
    index = data.get('current_mode')
    modes = data.get('modes', [])
    if index is not None and 0 <= index < len(modes):
        mode = modes[index]
        settings['mode'] = '{}x{}@{:.3f}'.format(mode['width'], mode['height'], mode['refresh_rate']/1000)
    if logical:
        settings.update(scale=logical['scale'], position=dict(x=logical['x'], y=logical['y']),
                        transform=transform_name(logical['transform']))
    return settings


def transform_name(value):
    return {'Normal':'normal', 'Flipped':'flipped', 'Flipped90':'flipped-90', 'Flipped180':'flipped-180', 'Flipped270':'flipped-270'}.get(value, str(value))


def parse_mode(mode):
    parts = mode.split('@')
    width, height = map(int, parts[0].split('x'))
    return dict(width=width, height=height, refresh=float(parts[1]) if len(parts)>1 else None)


def logical_size(settings):
    mode = parse_mode(settings['mode'])
    width, height = mode['width'], mode['height']
    if settings.get('transform') in ('90', '270', 'flipped-90', 'flipped-270'): width, height = height, width
    scale = math.floor(settings.get('scale', 1)*120+0.5)/120
    return math.ceil(width/scale), math.ceil(height/scale)


def actions(settings):
    result = []
    if settings.get('mode'):
        result.append({'Mode': {'mode': {'Specific': parse_mode(settings['mode'])}}})
    elif settings.get('_reset'):
        result.append({'Mode': {'mode': 'Automatic'}})
    if settings.get('scale') is not None:
        result.append({'Scale': {'scale': {'Specific': settings['scale']}}})
    elif settings.get('_reset'):
        result.append({'Scale': {'scale': 'Automatic'}})
    if settings.get('transform') or settings.get('_reset'):
        transform = settings.get('transform', 'normal')
        value = {'normal':'Normal', 'flipped':'Flipped', 'flipped-90':'Flipped90', 'flipped-180':'Flipped180', 'flipped-270':'Flipped270'}.get(transform, transform)
        result.append({'Transform': {'transform': value}})
    if settings.get('position'):
        result.append({'Position': {'position': {'Specific': settings['position']}}})
    elif settings.get('_reset'):
        result.append({'Position': {'position': 'Automatic'}})
    if settings.get('vrr') is not None or settings.get('_reset'):
        result.append({'Vrr': {'vrr': {'vrr': settings.get('vrr','off') != 'off', 'on_demand': settings.get('vrr') == 'on-demand'}}})
    return result


def verified(settings, data, position=True):
    actual = live_settings(data)
    if settings.get('enabled', True) != actual['enabled']: return False
    if not actual['enabled']: return True
    if settings.get('mode') and parse_mode(settings['mode'])['refresh'] is None:
        if parse_mode(settings['mode'])['width'] != parse_mode(actual.get('mode','0x0'))['width'] or parse_mode(settings['mode'])['height'] != parse_mode(actual.get('mode','0x0'))['height']: return False
    for key in ('transform',) + (('mode',) if settings.get('mode') and '@' in settings['mode'] else ()):
        if settings.get(key) is not None and settings[key] != actual.get(key): return False
    if settings.get('scale') is not None and abs(math.floor(settings['scale']*120+0.5)/120-actual.get('scale', 0)) > 0.0001: return False
    if position and settings.get('position') is not None and settings['position'] != actual.get('position'): return False
    if settings.get('vrr') == 'off' and data.get('vrr_enabled'): return False
    if settings.get('vrr') == 'on' and not data.get('vrr_enabled'): return False
    return True


class Preview:
    def __init__(self, request, directory, parent):
        self.request, self.directory, self.parent = request, directory, parent
        self.deadline = time.monotonic()+25
        self.original = ipc('Outputs')
        self.combination = connection_key(self.original)
        self.main = config.main_path(request)
        self.path = self.main.parent/'clavis/outputs.kdl'
        self.graph = config.Graph(self.main)
        self.original_graph = self.graph
        if request.get('revision') != self.graph.revision(): raise ValueError('Configuration changed externally; reload before applying')
        if config.path_key(self.path) not in self.graph.references: raise ValueError('Connect the outputs fragment first')
        config.safe_target(self.path)
        self.original_text = config.read_text(self.path)
        self.candidate = outputs.edit(self.graph, config.path_key(self.path), request, config)
        config.Graph(self.main, replacements={config.path_key(self.path):self.candidate}).validate()
        self.graph.unchanged()
        self.desired = {}
        self.before = {}
        self.changed = False
        self.published = False
        rows = outputs.inspect(self.graph, config.path_key(self.path))
        for patch in request['outputs']:
            if patch.get('delete'): continue
            matches = [name for name, data in self.original.items() if outputs.matches(patch['identifier'], dict(data,name=name))]
            if not matches:
                if patch.get('identity'): raise ValueError('A display was disconnected; reload before applying')
                continue # Retain disconnected configurations without live requests.
            if len(matches) != 1: raise ValueError('Ambiguous display identity; use its current connector')
            name = matches[0]
            if patch.get('identity') and outputs.identity(patch['identity']) != outputs.identity(self.original[name]):
                raise ValueError('The display connected to this output changed; reload before applying')
            self.desired[name] = patch['settings']
            prior = live_settings(self.original[name])
            row = next((r for r in rows if outputs.matches(r['identifier'], dict(self.original[name],name=name))), None)
            # Saved policy is authoritative. A live VRR bool cannot identify on-demand.
            prior['vrr'] = row['settings'].get('vrr','off') if row else 'on' if self.original[name].get('vrr_enabled') else 'off'
            self.before[name] = prior
            settings = patch['settings']
            if settings.get('enabled',True):
                if not settings.get('mode'): raise ValueError('Select an available display mode')
                wanted = parse_mode(settings['mode'])
                if not any(m['width']==wanted['width'] and m['height']==wanted['height'] and (wanted['refresh'] is None or m['refresh_rate']==round(wanted['refresh']*1000)) for m in self.original[name]['modes']):
                    raise ValueError('The selected mode is no longer available')
                if settings.get('vrr','off')!='off' and not self.original[name].get('vrr_supported'): raise ValueError('Variable refresh rate is not supported')
        final = {name:self.desired.get(name,live_settings(data)) for name,data in self.original.items()}
        enabled = [s for s in final.values() if s.get('enabled',True)]
        if not enabled: raise ValueError('At least one connected display must remain enabled')
        rectangles=[]
        for settings in enabled:
            if not settings.get('position') or not settings.get('mode'): continue
            width,height=logical_size(settings)
            x,y=settings['position']['x'],settings['position']['y']
            if any(x<rx+rw and x+width>rx and y<ry+rh and y+height>ry for rx,ry,rw,rh in rectangles):
                raise ValueError('Display rectangles overlap; adjust their logical positions')
            rectangles.append((x,y,width,height))

    def publish(self, phase, error='', **extra):
        config.replace_file(self.directory/'status.json', json.dumps(dict(schemaVersion=1,phase=phase,error=error,**extra)))

    def check(self):
        if time.monotonic() >= self.deadline: raise ValueError('Display preview timed out')
        if not Path('/proc',str(self.parent)).exists(): raise ValueError('The shell exited')
        self.graph.unchanged()
        live=ipc('Outputs')
        if connection_key(live)!=self.combination: raise ValueError('Connected displays changed during preview')
        return live

    def command(self,name,action):
        self.check()
        self.changed=True
        ipc({'Output':{'output':name,'action':action}})

    def wait(self, desired, position=True):
        end=min(self.deadline,time.monotonic()+7)
        while time.monotonic()<end:
            live=self.check()
            if all(name in live and verified(settings,live[name],position) for name,settings in desired.items()): return
            time.sleep(0.15)
        raise ValueError('The compositor did not report the requested output state')

    def apply(self):
        # Keep an existing usable output until every enabled replacement is verified.
        for name,settings in self.desired.items():
            if not settings.get('enabled',True): continue
            self.command(name,'On')
            for action in actions(settings): self.command(name,action)
        self.wait({name:s for name,s in self.desired.items() if s.get('enabled',True)},False)
        for name,settings in self.desired.items():
            if not settings.get('enabled',True): self.command(name,'Off')
        # Positioning may have changed when another output was disabled.
        for name,settings in self.desired.items():
            if settings.get('enabled',True) and settings.get('position'):
                self.command(name,{'Position':{'position':{'Specific':settings['position']}}})
        self.wait(self.desired)

    def restore(self):
        errors=[]
        if not self.changed: return errors
        try:
            live=ipc('Outputs')
            connected={name for name,data in live.items() if (name,outputs.identity(dict(data,name=name))) in self.combination}
            restore=copy_settings(self.before)
            try:
                current_graph=config.Graph(self.main)
                current_rows=outputs.inspect(current_graph,config.path_key(self.path))
                original_rows=outputs.inspect(self.original_graph,config.path_key(self.path))
                for name in restore:
                    data=dict(self.original[name],name=name)
                    before=next((r['settings'] for r in original_rows if outputs.matches(r['identifier'],data)),{})
                    current=next((r['settings'] for r in current_rows if outputs.matches(r['identifier'],data)),{})
                    if before!=current:
                        # Respect new external output preferences instead of installing
                        # an old IPC override over the user's new configuration.
                        restore[name]=dict(current,_reset=True)
            except Exception as error:
                errors.append('Unable to read external output changes: '+str(error))
            enabled=[]
            for name,settings in restore.items():
                if name not in connected or not settings.get('enabled',True): continue
                try:
                    ipc({'Output':{'output':name,'action':'On'}})
                    for action in actions(settings): ipc({'Output':{'output':name,'action':action}})
                    enabled.append(name)
                except Exception as error: errors.append(str(error))
            # Never disable an output until a restored alternative is actually usable.
            fresh=ipc('Outputs')
            safe=any(fresh.get(name,{}).get('current_mode') is not None for name in enabled)
            if safe:
                for name,settings in restore.items():
                    if name in connected and not settings.get('enabled',True):
                        ipc({'Output':{'output':name,'action':'Off'}})
        except Exception as error: errors.append(str(error))
        return errors

    def keep(self):
        self.check()
        self.publish('saving')
        self.published=True
        response=config.mutate(dict(self.request,operation='save',feature='outputs'))
        if response.get('error') or response.get('diagnostics',{}).get('invalid'): raise ValueError(response.get('error') or 'Saved configuration did not validate')
        self.published=True
        self.graph=config.Graph(self.main)
        self.deadline=time.monotonic()+8
        # Disk output changes clear niri transient overrides. Recheck after reload.
        ipc({'Action':{'LoadConfigFile':{'path':None}}})
        time.sleep(0.3)
        self.wait(self.desired)
        self.publish('kept')


def run_guard(request,directory,parent,lock_fd):
    preview=None
    control=socket.socket(socket.AF_UNIX)
    def deadline_expired(_signal, _frame):
        raise TimeoutError('The display transaction exceeded its recovery deadline')
    signal.signal(signal.SIGALRM, deadline_expired)
    signal.setitimer(signal.ITIMER_REAL, 45)
    try:
        control.bind(str(directory/'control'))
        control.listen(2)
        control.setblocking(False)
        preview=Preview(request,directory,parent)
        preview.publish('applying')
        preview.apply()
        preview.deadline=time.monotonic()+10
        while True:
            remaining=max(0,math.ceil(preview.deadline-time.monotonic()))
            preview.publish('confirming',remaining=remaining)
            preview.check()
            readable,_,_=select.select([control],[],[],0.25)
            if not readable: continue
            peer,_=control.accept()
            with peer:
                peer.settimeout(1)
                command=peer.recv(64).decode().strip()
            if command=='keep':
                signal.setitimer(signal.ITIMER_REAL, 45)
                preview.keep()
                return
            if command=='revert': raise ValueError('Changes reverted')
    except Exception as error:
        signal.setitimer(signal.ITIMER_REAL, 0)
        restore_errors=[]
        if preview and preview.published:
            try:
                config.restore_output_publication(preview.main,preview.candidate,preview.original_text)
                ipc({'Action':{'LoadConfigFile':{'path':None}}})
            except Exception as rollback_error: restore_errors.append(str(rollback_error))
        if preview: restore_errors.extend(preview.restore())
        config.replace_file(directory/'status.json',json.dumps(dict(schemaVersion=1,phase='reverted',error=str(error),restoreErrors=restore_errors)))
    finally:
        signal.setitimer(signal.ITIMER_REAL, 0)
        control.close()
        (directory/'control').unlink(missing_ok=True)
        os.close(lock_fd)


def directory_for(token):
    if not isinstance(token,str) or not token.startswith('clavis-display-') or '/' in token: raise ValueError('Invalid preview token')
    directory=Path(os.environ.get('XDG_RUNTIME_DIR',tempfile.gettempdir()))/token
    info=directory.lstat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid!=os.getuid() or info.st_mode&0o077: raise ValueError('Unsafe preview directory')
    return directory


def run(request):
    operation=request['operation']
    if operation=='start':
        runtime=Path(os.environ.get('XDG_RUNTIME_DIR',tempfile.gettempdir()))
        lock_path=runtime/('clavis-display-preview-'+str(os.getuid())+'.lock')
        fd=os.open(lock_path,os.O_CREAT|os.O_RDWR|os.O_NOFOLLOW,0o600)
        info=os.fstat(fd)
        if info.st_uid!=os.getuid() or not stat.S_ISREG(info.st_mode) or info.st_nlink!=1:
            os.close(fd); raise ValueError('Unsafe preview lock')
        try: fcntl.flock(fd,fcntl.LOCK_EX|fcntl.LOCK_NB)
        except BlockingIOError:
            os.close(fd); raise ValueError('Another display preview is still active')
        directory=Path(tempfile.mkdtemp(prefix='clavis-display-',dir=runtime))
        config.replace_file(directory/'status.json',json.dumps(dict(schemaVersion=1,phase='validating')))
        parent=os.getppid()
        pid=os.fork()
        if pid==0:
            os.setsid()
            null=os.open(os.devnull,os.O_RDWR)
            for stream in (0,1,2): os.dup2(null,stream)
            os.close(null)
            run_guard(request,directory,parent,fd)
            os._exit(0)
        os.close(fd)
        return dict(schemaVersion=1,token=directory.name)
    directory=directory_for(request['token'])
    if operation=='status': return json.loads((directory/'status.json').read_text())
    if operation in ('keep','revert'):
        with socket.socket(socket.AF_UNIX) as peer:
            peer.settimeout(1)
            peer.connect(str(directory/'control'))
            peer.sendall(operation.encode()+b'\n')
        return dict(schemaVersion=1)
    if operation=='cleanup':
        state=json.loads((directory/'status.json').read_text())
        if state['phase'] not in ('kept','reverted'): raise ValueError('Preview is still active')
        (directory/'status.json').unlink()
        directory.rmdir()
        return dict(schemaVersion=1)
    raise ValueError('Unknown preview operation')


if __name__=='__main__':
    try: print(json.dumps(run(json.loads(sys.argv[1]))),flush=True)
    except Exception as error:
        print(json.dumps(dict(schemaVersion=1,error=str(error))),flush=True)
        sys.exit(1)

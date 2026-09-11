#!/usr/bin/env python3
"""Preview public contract against a temporary simulated Niri IPC peer."""
import copy
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from unittest import mock

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts/system'))
import niri_config as config
import display_preview as preview


class PreviewContracts(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(prefix='clavis-preview-test-')
        self.addCleanup(self.temp.cleanup)
        self.directory=Path(self.temp.name)
        self.main=self.directory/'config.kdl'
        self.main.write_text('')
        self.environment=mock.patch.dict(os.environ,{'XDG_RUNTIME_DIR':str(self.directory),'NIRI_CONFIG':str(self.main)})
        self.environment.start(); self.addCleanup(self.environment.stop)
        os.environ.pop('NIRI_SOCKET',None)
        config.run(dict(operation='setup',feature='outputs',main=str(self.main)))
        self.before_file=(self.directory/'clavis/outputs.kdl').read_bytes()
        self.peer=socket.socket(socket.AF_UNIX)
        self.peer.bind(str(self.directory/'niri.sock'));self.peer.listen()
        self.peer.settimeout(0.1)
        self.addCleanup(self.peer.close)
        os.environ['NIRI_SOCKET']=str(self.directory/'niri.sock')
        self.state={}
        for index,name in enumerate(('DP-1','DP-2')):
            self.state[name]=dict(name=name,make='Test',model='Panel',serial=str(index),modes=[dict(width=1920,height=1080,refresh_rate=59951,is_preferred=True)],current_mode=0,
                vrr_supported=True,vrr_enabled=False,logical=dict(x=index*1920,y=0,width=1920,height=1080,scale=1,transform='Normal'))
        self.initial=copy.deepcopy(self.state)
        self.actions=[]
        self.fail_mode=False
        self.stop=threading.Event()
        self.addCleanup(self.stop.set)
        self.thread=threading.Thread(target=self.serve,daemon=True);self.thread.start()
        self.token=None
        self.addCleanup(self.finish)

    def serve(self):
        while not self.stop.is_set():
            try: connection,_=self.peer.accept()
            except (TimeoutError,OSError): continue
            with connection:
                connection.settimeout(2)
                try:
                    data=bytearray()
                    while b'\n' not in data:
                        part=connection.recv(65536)
                        if not part: break
                        data.extend(part)
                    if not data:continue
                    request=json.loads(data.split(b'\n')[0])
                    if request=='Outputs': response={'Ok':{'Outputs':copy.deepcopy(self.state)}}
                    elif isinstance(request,dict) and 'Output' in request:
                        name=request['Output']['output'];action=request['Output']['action']
                        self.actions.append((name,action))
                        if self.fail_mode and isinstance(action,dict) and 'Scale' in action:
                            self.fail_mode=False
                            response={'Err':'Simulated mode failure'}
                        else:
                            self.apply_action(name,action)
                            response={'Ok':'Handled'}
                    elif isinstance(request,dict) and 'Action' in request:
                        for row in config.status(dict(main=str(self.main)))['outputs']:
                            name=row['identifier']
                            if name not in self.state:continue
                            settings=row['settings']
                            self.apply_action(name,'Off' if settings.get('enabled') is False else 'On')
                            for action in preview.actions(settings):self.apply_action(name,action)
                        response={'Ok':'Handled'}
                    else:response={'Err':'Unsupported test request'}
                    connection.sendall((json.dumps(response)+'\n').encode())
                except (OSError,ValueError): pass

    def apply_action(self,name,action):
        if name not in self.state:return
        row=self.state[name]
        if action=='Off':row['current_mode']=None;return
        if action=='On':row['current_mode']=0;return
        if 'Scale' in action:row['logical']['scale']=1 if action['Scale']['scale']=='Automatic' else round(action['Scale']['scale']['Specific']*120)/120
        if 'Position' in action and action['Position']['position']!='Automatic':row['logical'].update(action['Position']['position']['Specific'])
        if 'Transform' in action:row['logical']['transform']=action['Transform']['transform']
        if 'Vrr' in action:row['vrr_enabled']=action['Vrr']['vrr']['vrr'] and not action['Vrr']['vrr']['on_demand']

    def request(self):
        graph=config.Graph(self.main)
        settings=[dict(identifier=name,identity=dict(name=name,make=row['make'],model=row['model'],serial=row['serial']),settings=dict(preview.live_settings(row),vrr='off')) for name,row in self.initial.items()]
        settings[0]['settings']['scale']=1.25
        return dict(operation='start',main=str(self.main),revision=graph.revision(),outputs=settings)

    def start(self,request=None):
        process=subprocess.run([sys.executable,str(ROOT/'scripts/system/display_preview.py'),json.dumps(request or self.request())],capture_output=True,text=True,check=True)
        self.token=json.loads(process.stdout)['token']
        return self.until('confirming','reverted')

    def status(self):return preview.run(dict(operation='status',token=self.token))

    def until(self,*phases):
        deadline=time.monotonic()+15
        while time.monotonic()<deadline:
            state=self.status()
            if state['phase'] in phases:return state
            time.sleep(0.05)
        self.fail_test('Preview did not reach '+str(phases))

    def fail_test(self,message):raise AssertionError(message)

    def finish(self):
        if not self.token:return
        try:
            if self.status()['phase'] not in ('kept','reverted'):
                preview.run(dict(operation='revert',token=self.token));self.until('reverted')
            preview.run(dict(operation='cleanup',token=self.token))
        except (OSError,ValueError):pass

    def test_revert_and_timeout_leave_disk_untouched(self):
        self.assertEqual(self.start()['phase'],'confirming')
        preview.run(dict(operation='revert',token=self.token));self.until('reverted')
        self.assertEqual(self.state,self.initial)
        self.finish();self.token=None
        self.assertEqual(self.start()['phase'],'confirming')
        self.until('reverted')
        self.assertEqual(self.state,self.initial)
        self.assertEqual((self.directory/'clavis/outputs.kdl').read_bytes(),self.before_file)

    def test_keep_persists_and_verifies(self):
        self.assertEqual(self.start()['phase'],'confirming')
        preview.run(dict(operation='keep',token=self.token))
        state=self.until('kept','reverted')
        self.assertEqual(state['phase'],'kept',state)
        self.assertEqual(self.state['DP-1']['logical']['scale'],1.25)
        rows=config.status(dict(main=str(self.main)))['outputs']
        self.assertEqual(next(row for row in rows if row['identifier']=='DP-1')['settings']['scale'],1.25)

    def test_partial_failure_and_last_output(self):
        self.fail_mode=True
        self.assertEqual(self.start()['phase'],'reverted')
        self.assertEqual(self.state,self.initial)
        self.finish();self.token=None
        request=self.request()
        for patch in request['outputs']:patch['settings']['enabled']=False
        state=self.start(request)
        self.assertEqual(state['phase'],'reverted')
        self.assertIn('At least one',state['error'])
        self.assertEqual(self.state,self.initial)

    def test_external_edit_and_unplug_do_not_overwrite(self):
        self.assertEqual(self.start()['phase'],'confirming')
        self.main.write_text(self.main.read_text()+'// user edit\n')
        self.until('reverted')
        self.assertTrue(self.main.read_text().endswith('// user edit\n'))
        self.finish();self.token=None
        self.assertEqual(self.start()['phase'],'confirming')
        del self.state['DP-2']
        self.until('reverted')
        self.assertEqual(self.state['DP-1'],self.initial['DP-1'])

    def test_external_output_setting_is_not_replaced_by_old_snapshot(self):
        self.assertEqual(self.start()['phase'],'confirming')
        self.main.write_text(self.main.read_text()+'output "DP-1" { scale 1.5; }\n')
        state=self.until('reverted')
        self.assertEqual(self.state['DP-1']['logical']['scale'],1.5,state)
        self.assertIn('scale 1.5',self.main.read_text())

    def test_recovery_publication_preserves_external_edits(self):
        path=self.directory/'clavis/outputs.kdl'
        path.write_text('// external edit\n')
        with self.assertRaises(ValueError):
            config.restore_output_publication(self.main,'// candidate\n','// original\n')
        self.assertEqual(path.read_text(),'// external edit\n')

    def test_shell_exit_is_recovered_by_independent_guard(self):
        # This disposable parent stands in for the shell. Only this test process
        # is terminated; the guardian and simulated compositor are separate.
        code='import subprocess,sys,time; subprocess.run(sys.argv[1:]); time.sleep(30)'
        parent=subprocess.Popen([sys.executable,'-c',code,sys.executable,str(ROOT/'scripts/system/display_preview.py'),json.dumps(self.request())],stdout=subprocess.PIPE,text=True)
        try:
            self.token=json.loads(parent.stdout.readline())['token']
            self.until('confirming')
            parent.terminate();parent.wait(timeout=2)
            self.until('reverted')
            self.assertEqual(self.state,self.initial)
        finally:
            if parent.poll() is None:parent.terminate();parent.wait(timeout=2)
            parent.stdout.close()


if __name__=='__main__':unittest.main()

"""Exercise editable wrappers with stubbed hardware/build tools: no SHA gate."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[2]
BASH=shutil.which('bash') or r'C:/Program Files/Git/bin/bash.exe'

class EditableWorkflowTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory(prefix='wr-editable-test-')
        self.root=Path(self.tmp.name)
        self.env=dict(os.environ,PATH=str(self.root/'bin')+os.pathsep+os.environ.get('PATH',''))
        self.put('bin/pgrep','#!/usr/bin/env bash\nexit 1\n')
        self.put('bin/sha256sum','#!/usr/bin/env bash\necho SHA_MUST_NOT_RUN >&2\nexit 77\n')
        self.put('scripts/build/current_experiment.env','CURRENT_EXPERIMENT=TEST\nCURRENT_BUILD_POLICY=editable\n')
    def tearDown(self): self.tmp.cleanup()
    def put(self,path,body):
        target=self.root/path; target.parent.mkdir(parents=True,exist_ok=True)
        target.write_text(body,newline='\n'); target.chmod(0o755)
    def copy(self,path): self.put(path,(ROOT/path).read_text())
    def run_script(self,path):
        return subprocess.run([BASH,(self.root/path).as_posix()],cwd=self.root,env=self.env,text=True,capture_output=True)
    def test_build_accepts_unpinned_firmware(self):
        self.copy('scripts/build/build_current.sh')
        for role in ('master','slave'):
            self.put(f'firmware/scripts/build_{role}_firmware.sh',f'#!/usr/bin/env bash\nroot=$(cd "$(dirname "$0")/../.." && pwd)\nmkdir -p "$root/build/firmware/{role}"\nprintf new > "$root/build/firmware/{role}/wrc.mif"\n')
        result=self.run_script('scripts/build/build_current.sh')
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertIn('sha_verification=disabled',result.stdout)
    def test_program_requires_only_existing_sofs_not_sha_files(self):
        self.copy('scripts/program/program_current.sh')
        self.put('output/DE5a_wr_master_jtag.sof','new master')
        self.put('output/DE5a_wr_slave_jtag.sof','new slave')
        for role in ('master','slave'):
            self.put(f'scripts/program/program_{role}.sh','#!/usr/bin/env bash\necho "Programmer was successful"\n')
        result=self.run_script('scripts/program/program_current.sh')
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertIn('CURRENT_PROGRAM=PASS',result.stdout)
        self.assertNotIn('SHA_MUST_NOT_RUN',result.stderr)
    def test_missing_sof_stops_program(self):
        self.copy('scripts/program/program_current.sh')
        result=self.run_script('scripts/program/program_current.sh')
        self.assertNotEqual(result.returncode,0)
    def make_pipeline(self,failed=None):
        self.copy('scripts/run_current.sh')
        for step,path in [('build','scripts/build/build_current.sh'),('compile','scripts/build/compile_current.sh'),('program','scripts/program/program_current.sh'),('dashboard','scripts/monitor/step1_6_dashboard.sh')]:
            body=f'#!/usr/bin/env bash\necho STEP={step}\n'
            if step==failed: body+='exit 9\n'
            self.put(path,body)
    def test_pipeline_order(self):
        self.make_pipeline(); result=self.run_script('scripts/run_current.sh')
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual([x for x in result.stdout.splitlines() if x.startswith('STEP=')],['STEP=build','STEP=compile','STEP=program','STEP=dashboard'])
    def test_failed_compile_never_programs(self):
        self.make_pipeline('compile'); result=self.run_script('scripts/run_current.sh')
        self.assertEqual(result.returncode,9,result.stderr)
        self.assertNotIn('STEP=program',result.stdout)
        self.assertNotIn('STEP=dashboard',result.stdout)
    def test_settling_wait_is_after_program(self):
        self.make_pipeline(); self.env['POST_PROGRAM_WAIT_S']='1'
        result=self.run_script('scripts/run_current.sh')
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertLess(result.stdout.index('STEP=program'),result.stdout.index('POST_PROGRAM_SETTLING elapsed_s='))
        self.assertLess(result.stdout.index('POST_PROGRAM_SETTLING_DONE'),result.stdout.index('STEP=dashboard'))
    def test_invalid_wait_never_builds(self):
        self.make_pipeline(); self.env['POST_PROGRAM_WAIT_S']='bad'
        result=self.run_script('scripts/run_current.sh')
        self.assertEqual(result.returncode,2)
        self.assertNotIn('STEP=build',result.stdout)

if __name__=='__main__': unittest.main()

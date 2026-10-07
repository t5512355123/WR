"""Exercise editable wrappers with stubbed hardware/build tools: no SHA gate."""
from pathlib import Path
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from scripts.tests.test_post_settling_cko import capture

ROOT=Path(__file__).resolve().parents[2]
BASH=shutil.which('bash') or r'C:/Program Files/Git/bin/bash.exe'

class EditableWorkflowTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory(prefix='wr-editable-test-')
        self.root=Path(self.tmp.name)
        self.env=dict(os.environ,PATH=str(self.root/'bin')+os.pathsep+os.environ.get('PATH',''))
        self.put('bin/pgrep','#!/usr/bin/env bash\nexit 1\n')
        self.put('bin/flock','#!/usr/bin/env bash\nexit 0\n')
        self.put('bin/sha256sum','#!/usr/bin/env bash\necho SHA_MUST_NOT_RUN >&2\nexit 77\n')
        self.put('scripts/build/current_experiment.env','CURRENT_EXPERIMENT=TEST\nCURRENT_BUILD_POLICY=editable\n')
    def tearDown(self): self.tmp.cleanup()
    def put(self,path,body):
        target=self.root/path; target.parent.mkdir(parents=True,exist_ok=True)
        with target.open('w',newline='\n') as stream: stream.write(body)
        target.chmod(0o755)
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
    def test_step7_program_logs_use_step7_group(self):
        self.copy('scripts/program/program_current.sh')
        self.put('scripts/build/current_experiment.env',
                 'CURRENT_EXPERIMENT=TEST\nCURRENT_EXPERIMENT_GROUP=step7\nCURRENT_BUILD_POLICY=editable\n')
        for role in ('master','slave'):
            self.put(f'output/DE5a_wr_{role}_jtag.sof', 'fresh')
            self.put(f'scripts/program/program_{role}.sh',
                     '#!/usr/bin/env bash\necho "Programmer was successful"\n')
        result=self.run_script('scripts/program/program_current.sh')
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual(len(list((self.root/'experiments/step7/TEST/raw/program').glob('*.log'))),2)
        self.assertFalse((self.root/'experiments/step6').exists())
    def test_invalid_experiment_group_never_programs(self):
        self.copy('scripts/program/program_current.sh')
        self.put('scripts/build/current_experiment.env',
                 'CURRENT_EXPERIMENT=TEST\nCURRENT_EXPERIMENT_GROUP=../outside\nCURRENT_BUILD_POLICY=editable\n')
        for role in ('master','slave'):
            self.put(f'output/DE5a_wr_{role}_jtag.sof','fresh')
            self.put(f'scripts/program/program_{role}.sh','#!/usr/bin/env bash\necho MUST_NOT_PROGRAM\n')
        result=self.run_script('scripts/program/program_current.sh')
        self.assertEqual(result.returncode,2)
        self.assertNotIn('MUST_NOT_PROGRAM',result.stdout)
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
    def test_competing_pipeline_never_builds(self):
        self.make_pipeline(); self.put('bin/flock','#!/usr/bin/env bash\nexit 1\n')
        result=self.run_script('scripts/run_current.sh')
        self.assertEqual(result.returncode,2)
        self.assertNotIn('STEP=build',result.stdout)

    def make_cko_observer(self, text=None):
        self.copy('scripts/monitor/observe_cko_no_correction.sh')
        self.copy('scripts/analysis/step6_post_settling_cko.py')
        self.put('scripts/build/current_experiment.env',
                 'CURRENT_EXPERIMENT=EXP-S6-WRH-NO-PHASE-CORRECTION-CKO-OBSERVATION-20261004\nCURRENT_BUILD_POLICY=editable\n')
        self.put('bin/python3', '#!/usr/bin/env bash\nexec "'+Path(sys.executable).as_posix()+'" "$@"\n')
        self.put('bin/git', '#!/usr/bin/env bash\necho MOCK_SOURCE\n')
        self.put('fixture.log', text or capture(offset=2000))
        self.put('bin/quartus_stp', '#!/usr/bin/env bash\necho "MOCK_READER_ARGS=$*"\ncat "$CKO_CAPTURE_FIXTURE"\n')
        self.env['QUARTUS_STP']=(self.root/'bin/quartus_stp').as_posix()
        self.env['CKO_CAPTURE_FIXTURE']=(self.root/'fixture.log').as_posix()

    def test_cko_observer_preserves_other_jtag_owner(self):
        self.make_cko_observer(); self.put('bin/pgrep', '#!/usr/bin/env bash\nexit 0\n')
        result=self.run_script('scripts/monitor/observe_cko_no_correction.sh')
        self.assertEqual(result.returncode,2,result.stderr)
        self.assertFalse((self.root/'experiments').exists())

    def test_cko_observer_rejects_bad_duration_before_reading(self):
        self.make_cko_observer(); self.env['DURATION_MS']='-1'
        result=self.run_script('scripts/monitor/observe_cko_no_correction.sh')
        self.assertEqual(result.returncode,2,result.stderr)
        self.assertFalse((self.root/'experiments').exists())

    def test_cko_observer_mock_complete_without_hardware(self):
        self.make_cko_observer(); result=self.run_script('scripts/monitor/observe_cko_no_correction.sh')
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertIn('loaded_mode_not_automatically_verified=1', result.stdout)
        self.assertIn('SAMPLED_SETP_CONSTANT=True', result.stdout)
        self.assertIn('"cko_peak_to_peak_ps": 0', result.stdout)
        raw=list((self.root/'experiments').glob('**/*-cko.log'))
        self.assertEqual(len(raw),1)
        self.assertIn('303000 500 1-11.2 2', raw[0].read_text())

    def test_cko_observer_incomplete_is_not_success(self):
        self.make_cko_observer(capture(short=True)); result=self.run_script('scripts/monitor/observe_cko_no_correction.sh')
        self.assertEqual(result.returncode,2,result.stderr)
        self.assertEqual(len(list((self.root/'experiments').glob('**/*-cko.log'))),1)
        self.assertIn('"diagnostic_capture_complete": false', result.stdout)

if __name__=='__main__': unittest.main()

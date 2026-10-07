from pathlib import Path
import unittest
ROOT = Path(__file__).resolve().parents[2]

class FixedSetpointContracts(unittest.TestCase):
    def test_independent_boot_latch_and_all_writes_guarded(self):
        text=(ROOT/'vendor/wrpc-sw/ppsi/proto-ext-common/wrh-servo.c').read_text()
        self.assertEqual(text.count('fixed_diag.latched = 1;'),1)
        self.assertNotIn('fixed_diag.latched = 0',text)
        self.assertEqual(text.count('WRH_OPER()->adjust_phase(s->cur_setpoint_ps);'),3)
        self.assertEqual(text.count('fixed_diag.phase_writes++;'),3)
        self.assertIn('if (!FIXED_SETP && s->cur_setpoint_ps >',text)
        self.assertIn('if(wrh_tracking_enabled && !FIXED_SETP)',text)
        self.assertIn('fixed_diag.revoked = 1;',text)
        self.assertIn('WRPC_ARCH_I(ppi)->timingMode == WRH_TM_BOUNDARY_CLOCK',text)
        for name,next_name in [('WRH_SYNC_PHASE','WRH_WAIT_OFFSET_STABLE'),
                               ('WRH_WAIT_OFFSET_STABLE','WRH_TRACK_PHASE')]:
            block=text.split('case '+name+':',1)[1].split('case '+next_name+':',1)[0]
            self.assertIn('if (FIXED_SETP)',block)

    def test_read_only_query_and_no_shared_abi_mutation(self):
        text=(ROOT/'vendor/wrpc-sw/shell/cmd_pll.c').read_text()
        block=text.split('case CMD_FIXED:',1)[1].split('case CMD_RXTS:',1)[0]
        self.assertIn('wrh_fixed_diag_get',block)
        self.assertIn('spll_get_phase_shift',block)
        self.assertNotIn('spll_set',block)
        self.assertNotIn('wrh_servo_enable_tracking',block)

if __name__=='__main__': unittest.main()

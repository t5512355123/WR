#include <assert.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include "../../../vendor/wrpc-sw/shell/cmd_calib.c"
static unsigned status_calls, measure_calls, get_calls, load_calls, set_calls;
static unsigned set_id, set_value;
static int storage_result, loaded;
static wrc_cal_data_t data;
void calib_t24p_show_state(void) { ++status_calls; }
int measure_t24p(void) { ++measure_calls; return -7; }
int storage_get_calibration_parameter(unsigned id, uint32_t *p) {
    assert(id==CAL_PARAM_T24P); ++get_calls; *p=7625; return storage_result;
}
int storage_set_calibration_parameter_and_save(unsigned id, unsigned v) {
    ++set_calls; set_id=id; set_value=v; return 0;
}
void storage_load_calibration(void) { ++load_calls; }
int storage_is_calibration_loaded(void) { return loaded; }
wrc_cal_data_t *storage_get_calibration_data(void) { return &data; }
int pp_printf(const char *fmt, ...) { (void)fmt; return 0; }
int sub_cmd(const char *const *names, unsigned count, const char **args) {
    unsigned i;
    for(i=0;i<count;i++) if(!strcmp(args[0],names[i])) return i;
    return -EINVAL;
}
int main(void) {
    const char *status[]={"status",NULL};
    const char *extra[]={"status","force",NULL};
    const char *none[]={NULL};
    const char *force[]={"force",NULL};
    const char *load[]={"load",NULL};
    const char *setp[]={"setp","T24P","7625",NULL};
    const char *show[]={"show",NULL};
    const char *bad[]={"unknown",NULL};
    assert(test_command_calibration.exec(status)==0);
    assert(status_calls==1 && !measure_calls && !get_calls && !load_calls && !set_calls);
    assert(cmd_calibration(extra)==-EINVAL && status_calls==1);
    assert(cmd_calibration(none)==0 && get_calls==1 && !measure_calls);
    storage_result=-1;
    assert(cmd_calibration(none)==-7 && get_calls==2 && measure_calls==1);
    assert(cmd_calibration(force)==-7 && measure_calls==2);
    assert(cmd_calibration(load)==0 && load_calls==1);
    assert(cmd_calibration(setp)==0 && set_calls==1 && set_id==CAL_PARAM_T24P && set_value==7625);
    assert(cmd_calibration(show)==0); loaded=1; data.param_count=1;
    data.params[0].id=CAL_PARAM_T24P; data.params[0].value=7625;
    assert(cmd_calibration(show)==0);
    assert(cmd_calibration(bad)==-EINVAL);
    puts("ACTUAL_CALIBRATION_DISPATCH=PASS status_read_only=1 legacy_branches=unchanged");
    return 0;
}

#define CAL_PARAM_T24P 0x54323450u
typedef struct { unsigned id, value; } test_cal_param;
typedef struct { unsigned param_count; test_cal_param params[2]; } wrc_cal_data_t;
int storage_get_calibration_parameter(unsigned, uint32_t *);
int storage_set_calibration_parameter_and_save(unsigned, unsigned);
void storage_load_calibration(void);
int storage_is_calibration_loaded(void);
wrc_cal_data_t *storage_get_calibration_data(void);

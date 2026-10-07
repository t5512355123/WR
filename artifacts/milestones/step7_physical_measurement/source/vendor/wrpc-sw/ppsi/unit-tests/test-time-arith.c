#include <inttypes.h>
#include "pp-printf.h"
#include "ppsi/ppsi.h"
#include "ppsi/ieee1588_types.h"

static int64_t vals[] =
  {
   0, 1,
   1000,
   2000,
    -1,
    -2000,
    50765654,
   12345678912345, // 12_345_678_912_345
    -12345678912345,
  };

static void
test_picos_to_interval(void)
{
  unsigned i;

  for (i = 0; i < sizeof(vals)/sizeof(*vals); i++)
    pp_printf("picos_to_interval(%"PRId64") = %ld\n", vals[i],
	      picos_to_interval(vals[i]));
}

static void
test_fixedDelta_to_pp_time(void)
{
  struct FixedDelta fd;
  struct pp_time t;
  unsigned i;
  
  for (i = 0; i < sizeof(vals)/sizeof(*vals); i++) {
    fd.scaledPicoseconds.lsb = vals[i];
    fd.scaledPicoseconds.msb = vals[i] >> 32;
    fixedDelta_to_pp_time(fd, &t);
    pp_printf("fixedDelta_to_pp_time(%ld) = %ld sec + %ld nsec\n",
	      vals[i],
	      t.secs, t.scaled_nsecs);
  }
}
  

static void
test_picos_to_pp_time(void)
{
  unsigned i;
  struct pp_time t;

  for (i = 0; i < sizeof(vals)/sizeof(*vals); i++) {
    picos_to_pp_time(vals[i], &t);
    pp_printf("picos_to_pp_time(%ld) = %ld sec + %ld nsec\n",
	      vals[i],
	      t.secs, t.scaled_nsecs);
  }
}

static void
test_pp_time_hardwarize(void)
{
  static int periods[] = { 540, 123 };
  unsigned i, j;
  struct pp_time t;

  for (j = 0; j < sizeof(periods)/sizeof(*periods); j++) {
    for (i = 0; i < sizeof(vals)/sizeof(*vals); i++) {
      int32_t ticks, picos;
    
      picos_to_pp_time(vals[i], &t);
      pp_time_hardwarize(&t, periods[j], &ticks, &picos);
      pp_printf("pp_time_hardwarize(%lds+%ldns, %dps) = %d ticks + %d picos\n",
		t.secs, t.scaled_nsecs, periods[j], ticks, picos);
    }
  }
}

int
main(void)
{
  test_picos_to_interval();
  test_fixedDelta_to_pp_time();
  test_picos_to_pp_time();
  test_pp_time_hardwarize();
  return 0;
}

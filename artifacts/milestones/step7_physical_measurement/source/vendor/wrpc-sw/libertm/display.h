#include "board-state.h"
#include "libertm.h"

/* can all this go to private.h? */
void display_dds_state(struct ertm14_dds_state *dds);
void display_ertm_clkab(struct ertm14_board_state *bs);
void display_ertm_state(struct ertm_state *st);
void display_wrc_diags(struct ertm_wr_status *diags);
void display_wrc_diags_cooked(struct ertm_wr_status *diags);

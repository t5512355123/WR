/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2019 CERN (www.cern.ch)
 * Author: Tomasz Wlostowski <tomasz.wlostowski@cern.ch>
 *
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation, either version 3 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

/* wr_rf_frame_transceiver - driver BE-RF-FB RF Frame Transceiver Core */

#ifndef __RF_FRAME_TRANSCEIVER_H__
#define __RF_FRAME_TRANSCEIVER_H__

#include "board.h"



struct wr_rf_frame_transceiver_device {
    void* base;
};

void wr_rf_frame_transceiver_create( struct wr_rf_frame_transceiver_device *dev, uint32_t base );
void wr_rf_frame_transceiver_send_single( struct wr_rf_frame_transceiver_device *dev );

#endif

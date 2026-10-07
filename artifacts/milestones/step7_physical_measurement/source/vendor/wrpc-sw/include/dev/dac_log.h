/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2020 CERN (www.cern.ch)
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

#ifndef __DAC_LOG_H
#define __DAC_LOG_H

#ifdef CONFIG_DAC_LOG
#define HAS_DAC_LOG 1
#else
#define HAS_DAC_LOG 0
#endif

void daclog_init(void);
int daclog_poll(void);


#endif

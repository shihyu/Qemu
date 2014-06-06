/* *INDENT-OFF* */ /* THIS FILE IS GENERATED */

/* A register protocol for GDB, the GNU debugger.
   Copyright (C) 2001-2013 Free Software Foundation, Inc.

   This file is part of GDB.

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.  */

/* This file was created with the aid of ``regdat.sh'' and ``./../regformats/arm-with-neon.dat''.  */

#include "server.h"
#include "regdef.h"
#include "tdesc.h"

static struct reg regs_arm_with_neon[] = {
  { "r0", 0, 32 },
  { "r1", 32, 32 },
  { "r2", 64, 32 },
  { "r3", 96, 32 },
  { "r4", 128, 32 },
  { "r5", 160, 32 },
  { "r6", 192, 32 },
  { "r7", 224, 32 },
  { "r8", 256, 32 },
  { "r9", 288, 32 },
  { "r10", 320, 32 },
  { "r11", 352, 32 },
  { "r12", 384, 32 },
  { "sp", 416, 32 },
  { "lr", 448, 32 },
  { "pc", 480, 32 },
  { "", 512, 0 },
  { "", 512, 0 },
  { "", 512, 0 },
  { "", 512, 0 },
  { "", 512, 0 },
  { "", 512, 0 },
  { "", 512, 0 },
  { "", 512, 0 },
  { "", 512, 0 },
  { "cpsr", 512, 32 },
  { "d0", 544, 64 },
  { "d1", 608, 64 },
  { "d2", 672, 64 },
  { "d3", 736, 64 },
  { "d4", 800, 64 },
  { "d5", 864, 64 },
  { "d6", 928, 64 },
  { "d7", 992, 64 },
  { "d8", 1056, 64 },
  { "d9", 1120, 64 },
  { "d10", 1184, 64 },
  { "d11", 1248, 64 },
  { "d12", 1312, 64 },
  { "d13", 1376, 64 },
  { "d14", 1440, 64 },
  { "d15", 1504, 64 },
  { "d16", 1568, 64 },
  { "d17", 1632, 64 },
  { "d18", 1696, 64 },
  { "d19", 1760, 64 },
  { "d20", 1824, 64 },
  { "d21", 1888, 64 },
  { "d22", 1952, 64 },
  { "d23", 2016, 64 },
  { "d24", 2080, 64 },
  { "d25", 2144, 64 },
  { "d26", 2208, 64 },
  { "d27", 2272, 64 },
  { "d28", 2336, 64 },
  { "d29", 2400, 64 },
  { "d30", 2464, 64 },
  { "d31", 2528, 64 },
  { "fpscr", 2592, 32 },
};

static const char *expedite_regs_arm_with_neon[] = { "r11", "sp", "pc", 0 };
static const char *xmltarget_arm_with_neon = "arm-with-neon.xml";

const struct target_desc *tdesc_arm_with_neon;

void
init_registers_arm_with_neon (void)
{
  static struct target_desc tdesc_arm_with_neon_s;
  struct target_desc *result = &tdesc_arm_with_neon_s;

  result->reg_defs = regs_arm_with_neon;
  result->num_registers = sizeof (regs_arm_with_neon) / sizeof (regs_arm_with_neon[0]);
  result->expedite_regs = expedite_regs_arm_with_neon;
  result->xmltarget = xmltarget_arm_with_neon;

  init_target_desc (result);

  tdesc_arm_with_neon = result;
}

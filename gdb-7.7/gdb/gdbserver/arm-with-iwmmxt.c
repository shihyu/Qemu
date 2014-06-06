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

/* This file was created with the aid of ``regdat.sh'' and ``./../regformats/arm-with-iwmmxt.dat''.  */

#include "server.h"
#include "regdef.h"
#include "tdesc.h"

static struct reg regs_arm_with_iwmmxt[] = {
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
  { "wR0", 544, 64 },
  { "wR1", 608, 64 },
  { "wR2", 672, 64 },
  { "wR3", 736, 64 },
  { "wR4", 800, 64 },
  { "wR5", 864, 64 },
  { "wR6", 928, 64 },
  { "wR7", 992, 64 },
  { "wR8", 1056, 64 },
  { "wR9", 1120, 64 },
  { "wR10", 1184, 64 },
  { "wR11", 1248, 64 },
  { "wR12", 1312, 64 },
  { "wR13", 1376, 64 },
  { "wR14", 1440, 64 },
  { "wR15", 1504, 64 },
  { "wCSSF", 1568, 32 },
  { "wCASF", 1600, 32 },
  { "wCGR0", 1632, 32 },
  { "wCGR1", 1664, 32 },
  { "wCGR2", 1696, 32 },
  { "wCGR3", 1728, 32 },
};

static const char *expedite_regs_arm_with_iwmmxt[] = { "r11", "sp", "pc", 0 };
static const char *xmltarget_arm_with_iwmmxt = "arm-with-iwmmxt.xml";

const struct target_desc *tdesc_arm_with_iwmmxt;

void
init_registers_arm_with_iwmmxt (void)
{
  static struct target_desc tdesc_arm_with_iwmmxt_s;
  struct target_desc *result = &tdesc_arm_with_iwmmxt_s;

  result->reg_defs = regs_arm_with_iwmmxt;
  result->num_registers = sizeof (regs_arm_with_iwmmxt) / sizeof (regs_arm_with_iwmmxt[0]);
  result->expedite_regs = expedite_regs_arm_with_iwmmxt;
  result->xmltarget = xmltarget_arm_with_iwmmxt;

  init_target_desc (result);

  tdesc_arm_with_iwmmxt = result;
}

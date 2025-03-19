// Copyright 2025 David Mallasén Quintana
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the “License”); you
// may not use this file except in compliance with the License, or, at your
// option, the Apache License version 2.0. You may obtain a copy of the
// License at https://solderpad.org/licenses/SHL-2.1/
//
// Unless required by applicable law or agreed to in writing, any work
// distributed under the License is distributed on an “AS IS” BASIS, WITHOUT
// WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
// License for the specific language governing permissions and limitations
// under the License.
//
// Author: David Mallasén <david.mallasen@epfl.ch>
// Description: XIF coprocessor instruction package. Contains the bit pattern
// of every instruction supported by the coprocessor.

package xif_copro_instr_pkg;

  // Bit reversal operation
  localparam logic [31:0] BITREV = 32'b 00000_10_?????_?????_111_?????_0101011;

  // Rotate right operation FUNCT7 = 3
  localparam logic [31:0] ROTRIGHT = 32'b 00000_11_?????_?????_111_?????_0101011;

  // Rotate left operation FUNCT7 = 4
  localparam logic [31:0] ROTLEFT = 32'b 00001_00_?????_?????_111_?????_0101011;

endpackage  // xif_copro_instr_pkg

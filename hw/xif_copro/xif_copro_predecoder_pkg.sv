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
// Description: XIF coprocessor predecoder package. Contains the description
// of every instruction that can be offloaded to the coprocessor.

package xif_copro_predecoder_pkg;

  // Predecoder internal instruction metadata
  typedef struct packed {
    logic [31:0]  instr;
    logic [31:0]  instr_mask;
    xif_copro_pkg::prd_rsp_t prd_rsp;
  } offload_instr_t;

  // Update this when adding new operations to OFFLOAD_INSTR
  localparam int unsigned NUM_INSTR = 3;

  localparam offload_instr_t OFFLOAD_INSTR[NUM_INSTR] = '{
      '{
          instr: 32'b00000_10_00000_00000_111_00000_0101011,  // BITREV
          instr_mask: 32'b11111_11_00000_00000_111_00000_1111111,
          prd_rsp : '{accept : 1'b1, loadstore : 1'b0, writeback : 1'b0, use_gprs : 2'b01}
      },
      '{
          instr: 32'b00000_11_00000_00000_111_00000_0101011,  // ROTRIGHT
          instr_mask: 32'b11111_11_00000_00000_111_00000_1111111,
          prd_rsp : '{accept : 1'b1, loadstore : 1'b0, writeback : 1'b0, use_gprs : 2'b10}
      },
      '{
          instr: 32'b00001_00_00000_00000_111_00000_0101011,  // ROTLEFT
          instr_mask: 32'b11111_11_00000_00000_111_00000_1111111,
          prd_rsp : '{accept : 1'b1, loadstore : 1'b0, writeback : 1'b0, use_gprs : 2'b10}
      }
  };

endpackage  // xif_copro_predecoder_pkg

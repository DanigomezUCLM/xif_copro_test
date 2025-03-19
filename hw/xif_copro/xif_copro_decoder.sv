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
// Based on: FPU Subsystem Decoder
// Contributor: Moritz Imfeld <moimfeld@student.eth.ch>
//
// Author: David Mallasén <david.mallasen@epfl.ch>
// Description: XIF coprocessor decoder module.

module xif_copro_decoder (
  input  logic [31:0]             instr_i,
  output xif_copro_pkg::decoder_t decoder_o
);

  always_comb begin

    decoder_o.copro_op = xif_copro_pkg::NONE;
    decoder_o.use_copro = 1'b1;

    decoder_o.op_select[0] = xif_copro_pkg::None;
    decoder_o.op_select[1] = xif_copro_pkg::None;

    decoder_o.is_store = 1'b0;
    decoder_o.is_load  = 1'b0;

    decoder_o.rd_is_copro = 1'b0;

    unique casez (instr_i)

      xif_copro_instr_pkg::BITREV: begin
        decoder_o.copro_op = xif_copro_pkg::BITREV;
        decoder_o.op_select[0] = xif_copro_pkg::CPU;
      end

      xif_copro_instr_pkg::ROTRIGHT: begin
        decoder_o.copro_op = xif_copro_pkg::ROTRIGHT;
        decoder_o.op_select[0] = xif_copro_pkg::CPU;
        decoder_o.op_select[1] = xif_copro_pkg::CPU;
      end

      xif_copro_instr_pkg::ROTLEFT: begin
        decoder_o.copro_op = xif_copro_pkg::ROTLEFT;
        decoder_o.op_select[0] = xif_copro_pkg::CPU;
        decoder_o.op_select[1] = xif_copro_pkg::CPU;
      end

      default: begin
        decoder_o.use_copro = 1'b0;
      end
    endcase
  end

endmodule  // xif_copro_decoder

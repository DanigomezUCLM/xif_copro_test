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
// Based on: FPU Subsystem Predecoder
// Contributor: Noam Gallmann <gnoam@live.com>
//              Moritz Imfeld <moimfeld@student.eth.ch>
//
// Author: David Mallasén <david.mallasen@epfl.ch>
// Description: XIF coprocessor predecoder module. Decides if the coprocessor
// can accept the instruction the core is currently trying to offload. This
// predecoding step is needed to meet the timing requirements of the
// coprocessor in the interaction with the core.

module xif_copro_predecoder
  import xif_copro_predecoder_pkg::NUM_INSTR;
  import xif_copro_predecoder_pkg::OFFLOAD_INSTR;
(
  input  xif_copro_pkg::prd_req_t prd_req_i,
  output xif_copro_pkg::prd_rsp_t prd_rsp_o
);

  xif_copro_pkg::prd_rsp_t [NUM_INSTR-1:0] instr_rsp;
  logic [NUM_INSTR-1:0] instr_sel;

  // Decides if the instruction that has been offloaded to the coprocessor
  // matches any of the instructions in the coprocessor
  for (genvar i = 0; i < NUM_INSTR; i++) begin : gen_predecoder_selector
    assign instr_sel[i] = ((OFFLOAD_INSTR[i].instr_mask & prd_req_i.instr) 
                           == OFFLOAD_INSTR[i].instr);
  end

  // Generates the response for the core by checking all the instructions
  // in parallel
  for (genvar i = 0; i < NUM_INSTR; i++) begin : gen_predecoder_mux
    assign instr_rsp[i].accept    = instr_sel[i] ? OFFLOAD_INSTR[i].prd_rsp.accept : 1'b0;
    assign instr_rsp[i].writeback = instr_sel[i] ? OFFLOAD_INSTR[i].prd_rsp.writeback : 1'b0;
    assign instr_rsp[i].loadstore = instr_sel[i] ? OFFLOAD_INSTR[i].prd_rsp.loadstore : '0;
    assign instr_rsp[i].use_gprs  = instr_sel[i] ? OFFLOAD_INSTR[i].prd_rsp.use_gprs : '0;
  end

  always_comb begin
    prd_rsp_o.accept    = 1'b0;
    prd_rsp_o.writeback = 1'b0;
    prd_rsp_o.loadstore = '0;
    prd_rsp_o.use_gprs  = '0;
    for (int unsigned i = 0; i < NUM_INSTR; i++) begin
      prd_rsp_o.accept |= instr_rsp[i].accept;
      prd_rsp_o.writeback |= instr_rsp[i].writeback;
      prd_rsp_o.loadstore |= instr_rsp[i].loadstore;
      prd_rsp_o.use_gprs |= instr_rsp[i].use_gprs;
    end
  end

endmodule  // xif_copro_predecoder

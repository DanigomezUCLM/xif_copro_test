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
// Description: XIF coprocessor execution stage

module xif_copro_ex_stage #(
  parameter int unsigned XLEN = 64,
  parameter type         tag_t = logic
) (
  input  logic clk_i,
  input  logic rst_ni,

  // Input signals
  input  logic [XLEN-1:0]          operand_a_i,
  input  logic [XLEN-1:0]          operand_b_i,
  input  xif_copro_pkg::copro_op_e operator_i,
  input  tag_t                     tag_i,

  // Handshakes
  input  logic in_valid_i,
  output logic in_ready_o,
  output logic out_valid_o,
  input  logic out_ready_i,

  // Output signals
  output tag_t            tag_o,
  output logic [XLEN-1:0] result_o
);

  // Data signals
  logic [XLEN-1:0] bitrev_result;

  // Register signals
  logic [XLEN-1:0] operand_a;
  logic [XLEN-1:0] operand_b;
  xif_copro_pkg::copro_op_e operator;

  // Handshake signals
  logic input_hs;
  logic output_hs;

  assign input_hs = in_valid_i & in_ready_o;
  assign output_hs = out_valid_o & out_ready_i;

  // =====================
  // Bit reverse operation
  // =====================

  always_comb begin
    case (operator)
      xif_copro_pkg::BITREV: begin
        bitrev_result = '0;
        for (int i = 0; i < XLEN; i++) begin
          bitrev_result[i] = operand_a_i[XLEN - 1 - i];
        end
      end
      default: begin
        bitrev_result = '0;
      end
    endcase
  end

  // =============
  // Result output
  // =============

  always_comb begin : result_mux
    result_o = '0;

    unique case (operator)
      // Bit reverse result
      xif_copro_pkg::BITREV: result_o = bitrev_result;
      default: ;
    endcase
  end

  // =======
  // Control
  // =======

  logic       instr_in_flight;
  logic [3:0] latency_d, latency_q;

  // Instruction in flight calculation
  // If both input_hs and output_hs are set, the input_hs has priority
  // and instr_in_flight stays set as there is a new instruction coming
  always_ff @(posedge clk_i or negedge rst_ni) begin : instr_in_flight_reg
    if (~rst_ni) begin
      instr_in_flight <= 1'b0;
    end else if (input_hs) begin
      instr_in_flight <= 1'b1;
    end else if (output_hs) begin
      instr_in_flight <= 1'b0;
    end
  end

  // Input ready when there is no instruction in flight. The input is
  // also ready when the output handshake is set (shortcut one cycle).
  assign in_ready_o = ~instr_in_flight | output_hs;

  // Output valid when there is an instruction in flight and the current
  // instruction is finished
  assign out_valid_o = instr_in_flight & (latency_q == 0);

  // FF with handshake enable for input signals
  always_ff @(posedge clk_i or negedge rst_ni) begin : input_reg
    if (~rst_ni) begin
      operand_a <= '0;
      operand_b <= '0;
      operator  <= NONE;
      tag_o     <= '0;
    end else if (input_hs) begin
      operand_a <= operand_a_i;
      operand_b <= operand_b_i;
      operator  <= operator_i;
      tag_o     <= tag_i;
    end else if (output_hs) begin
      operand_a <= '0;
      operand_b <= '0;
      operator  <= NONE;
      tag_o     <= '0;
    end
  end

  // Latency calculation
  // If an instruction takes more than one cycle to execute, the latency
  // counter is set to the corresponding value. The counter is decremented
  // every cycle until it reaches zero and the output is set to valid.
  always_comb begin : set_latency
    latency_d = 4'b0000;
  
    case (operator)
      xif_copro_pkg::BITREV: latency_d = 4'b0000;
      default: ;
    endcase
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : latency_reg
    if (~rst_ni) begin
      latency_q <= 0;
    end else if (input_hs) begin
      latency_q <= latency_d;
    end else if (latency_q > 0) begin
      latency_q <= latency_q - 1;
    end
  end

endmodule  // xif_copro_ex_stage

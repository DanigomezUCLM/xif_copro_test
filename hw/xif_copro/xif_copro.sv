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
// Description: XIF coprocessor top-level module

module xif_copro #(
  parameter int unsigned XLEN  = 32,
  parameter int unsigned INPUT_BUFFER_DEPTH = 1,
  parameter bit          FORWARDING = 1
) (
  // Clock and Reset
  input logic clk_i,
  input logic rst_ni,

  // eXtension interface
  if_xif.coproc_compressed xif_compressed_if,
  if_xif.coproc_issue      xif_issue_if,
  if_xif.coproc_commit     xif_commit_if,
  if_xif.coproc_mem        xif_mem_if,
  if_xif.coproc_mem_result xif_mem_result_if,
  if_xif.coproc_result     xif_result_if
);

  // Predecoder
  xif_copro_pkg::prd_req_t prd_req;
  xif_copro_pkg::prd_rsp_t prd_rsp;

  // Decoder
  xif_copro_pkg::decoder_t decoded_data;

  // Input buffer
  logic in_buf_push_valid;
  logic in_buf_push_ready;
  logic in_buf_pop_valid;
  logic in_buf_pop_ready;
  xif_copro_pkg::offloaded_data_t in_buf_push_data;
  xif_copro_pkg::offloaded_data_t in_buf_pop_data;

  // Forwarding
  logic [xif_copro_pkg::X_NUM_RS-1:0] ex_fwd;
  logic [xif_copro_pkg::X_NUM_RS-1:0] lsu_fwd;

  // Instruction data, operands and adresses
  logic [xif_copro_pkg::X_NUM_RS-1:0][XLEN-1:0] operands;
  logic [xif_copro_pkg::X_NUM_RS-1:0][xif_copro_pkg::X_RFR_WIDTH-1:0] copreg_operands;
  logic [31:0] offset;
  logic [xif_copro_pkg::X_NUM_RS-1:0][4:0] copreg_raddr;
  logic [4:0] copreg_wb_addr;
  logic [xif_copro_pkg::X_RFR_WIDTH-1:0] copreg_wb_data;
  logic copreg_we;

  // Memory buffer
  logic mem_push_valid;
  logic mem_push_ready;
  logic mem_pop_ready;
  xif_copro_pkg::mem_metadata_t mem_push_data;
  xif_copro_pkg::mem_metadata_t mem_pop_data;

  // Execution stage
  xif_copro_pkg::copro_tag_t ex_tag_in;
  xif_copro_pkg::copro_tag_t ex_tag_out;
  logic ex_in_valid;
  logic ex_in_ready;
  logic ex_out_valid;
  logic ex_out_ready;
  logic [XLEN-1:0] data_result;

  // Result buffer
  logic result_push_valid;
  logic result_pop_valid;
  xif_copro_pkg::x_result_t result_push_data;
  xif_copro_pkg::x_result_t result_pop_data;

  // ==========
  // Compressed
  // ==========

  // Compressed instructions are not supported here. Nothing besides
  // engineering time prevents them from being added.
  assign xif_compressed_if.compressed_ready = xif_compressed_if.compressed_valid;
  assign xif_compressed_if.compressed_resp.instr  = '0;
  assign xif_compressed_if.compressed_resp.accept = '0;

  // ==========
  // Predecoder
  // ==========

  // Issue interface
  assign prd_req.instr = xif_issue_if.issue_req.instr;

  assign xif_issue_if.issue_resp.accept    = prd_rsp.accept;
  assign xif_issue_if.issue_resp.writeback = prd_rsp.writeback;
  assign xif_issue_if.issue_resp.dualwrite = '0;
  assign xif_issue_if.issue_resp.dualread  = '0;
  assign xif_issue_if.issue_resp.loadstore = prd_rsp.loadstore;
  assign xif_issue_if.issue_resp.ecswrite  = '0;
  assign xif_issue_if.issue_resp.exc       = '0;

  xif_copro_predecoder xif_copro_predecoder_i (
    .prd_req_i(prd_req),
    .prd_rsp_o(prd_rsp)
  );

  // =======
  // Decoder
  // =======

  xif_copro_decoder xif_copro_decoder_i (
    .instr_i(in_buf_pop_data.instr),
    .decoder_o(decoded_data)
  );

  // =================
  // Input Stream FIFO
  // =================

  assign in_buf_push_valid = xif_issue_if.issue_valid & xif_issue_if.issue_ready
                           & xif_issue_if.issue_resp.accept;

  // Only the X_NUM_RS least significant registers are used. Selecting
  // them explicitly allows to connect xif_copro to a core with a larger
  // value of X_NUM_RS
  assign in_buf_push_data.rs = xif_issue_if.issue_req.rs[xif_copro_pkg::X_NUM_RS-1:0];
  assign in_buf_push_data.instr = xif_issue_if.issue_req.instr;
  assign in_buf_push_data.id = xif_issue_if.issue_req.id;
  assign in_buf_push_data.mode = xif_issue_if.issue_req.mode;

  stream_fifo #(
    .FALL_THROUGH(1),
    .DATA_WIDTH(XLEN),
    .DEPTH(INPUT_BUFFER_DEPTH),
    .T(xif_copro_pkg::offloaded_data_t)
  ) input_stream_fifo_i (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .flush_i(1'b0),
    .testmode_i(1'b0),
    .usage_o(  /* unused */),

    .data_i(in_buf_push_data),
    .valid_i(in_buf_push_valid),
    .ready_o(in_buf_push_ready),

    .data_o(in_buf_pop_data),
    .valid_o(in_buf_pop_valid),
    .ready_i(in_buf_pop_ready)
  );

  // =================================
  // Memory request/response interface
  // =================================

  assign xif_mem_if.mem_req.id   = in_buf_pop_data.id;
  assign xif_mem_if.mem_req.mode = in_buf_pop_data.mode;
  assign xif_mem_if.mem_req.size = 3'b010;  // 32-bit word
  assign xif_mem_if.mem_req.be   = '1;
  assign xif_mem_if.mem_req.attr = 2'b00;
  // Memory transactions can be done in one 32-bit request
  assign xif_mem_if.mem_req.last = 1'b1;
  // We wait for the commit interface before issuing the memory request
  assign xif_mem_if.mem_req.spec = 1'b0;

  always_comb begin
    if (ex_fwd[1]) begin
      xif_mem_if.mem_req.wdata = data_result;
    end else if (lsu_fwd[1]) begin
      xif_mem_if.mem_req.wdata = xif_mem_result_if.mem_result.rdata;
    end else begin
      xif_mem_if.mem_req.wdata = copreg_operands[1];
    end
  end

  // Load and store address calculation for memory instructions
  always_comb begin
    if (~xif_mem_if.mem_req.we) begin  // The instruction is a load
      offset = {
        {20{in_buf_pop_data.instr[31]}}, in_buf_pop_data.instr[31:20]
      };  // Sign-extend the imm value
    end else begin  // The instruction is a store
      offset = {
        {20{in_buf_pop_data.instr[31]}}, in_buf_pop_data.instr[31:25], in_buf_pop_data.instr[11:7]
      };  // Sign-extend the imm value
    end

    xif_mem_if.mem_req.addr = in_buf_pop_data.rs[0] + offset;
  end

  // ==============================
  // Memory Instruction Stream FIFO
  // ==============================

  assign mem_push_data.id      = in_buf_pop_data.id;
  assign mem_push_data.rd      = in_buf_pop_data.instr[11:7];
  assign mem_push_data.we      = decoded_data.is_load;
  assign mem_push_data.exc     = xif_mem_if.mem_resp.exc;
  assign mem_push_data.exccode = xif_mem_if.mem_resp.exccode;
  assign mem_push_data.dbg     = xif_mem_if.mem_resp.dbg;

  stream_fifo #(
    .FALL_THROUGH(0),
    .DATA_WIDTH(XLEN),
    .DEPTH(3),  // TODO: Why explicitly 3?
    .T(xif_copro_pkg::mem_metadata_t)
  ) mem_stream_fifo_i (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .flush_i(1'b0),
    .testmode_i(1'b0),
    .usage_o(  /* unused */),

    .data_i(mem_push_data),
    .valid_i(mem_push_valid),
    .ready_o(mem_push_ready),

    .data_o(mem_pop_data),
    .valid_o(),  // TODO: Not used?
    .ready_i(mem_pop_ready)
  );

  // ==========
  // Controller
  // ==========

  xif_copro_controller #(
    .FORWARDING(FORWARDING)
  ) xif_copro_controller_i (
    // Clock and Reset
    .clk_i(clk_i),
    .rst_ni(rst_ni),

    // Predecoder
    .prd_rsp_use_gprs_i(prd_rsp.use_gprs),

    // Issue Interface
    .xif_issue_req_rs_valid_i(xif_issue_if.issue_req.rs_valid[xif_copro_pkg::X_NUM_RS-1:0]),
    .xif_issue_ready_o(xif_issue_if.issue_ready),

    // Commit Interface
    .xif_commit_if(xif_commit_if),

    // Input Buffer
    .in_buf_push_ready_i(in_buf_push_ready),
    .in_buf_pop_valid_i(in_buf_pop_valid),
    .in_buf_pop_ready_o(in_buf_pop_ready),

    // Register
    .rd_is_copro_i(ex_tag_out.rd_is_copro),
    .ex_out_addr_i(ex_tag_out.addr),
    .copreg_wb_addr_i(copreg_wb_addr),
    .rd_i(in_buf_pop_data.instr[11:7]),
    .copreg_we_o(copreg_we),

    // Dependency Check and Forwarding
    .rd_in_is_copro_i(decoded_data.rd_is_copro),
    .rs1_i(copreg_raddr[0]),
    .rs2_i(copreg_raddr[1]),
    .ex_fwd_o(ex_fwd),
    .lsu_fwd_o(lsu_fwd),
    .op_select_i(decoded_data.op_select),

    // Memory Instruction
    .is_load_i(decoded_data.is_load),
    .is_store_i(decoded_data.is_store),

    // Memory Request/Repsonse Interface
    .xif_mem_valid_o(xif_mem_if.mem_valid),
    .xif_mem_ready_i(xif_mem_if.mem_ready),
    .xif_mem_req_we_o(xif_mem_if.mem_req.we),
    .xif_mem_req_id_i(xif_mem_if.mem_req.id),

    // Memory Buffer
    .mem_push_valid_o(mem_push_valid),
    .mem_push_ready_i(mem_push_ready),
    .mem_pop_ready_o(mem_pop_ready),
    .mem_pop_data_i(mem_pop_data),

    // Memory Result Interface
    .xif_mem_result_valid_i(xif_mem_result_if.mem_result_valid),

    // Execution stage
    .use_copro_i(decoded_data.use_copro),
    .ex_in_valid_o(ex_in_valid),
    .ex_in_ready_i(ex_in_ready),
    .ex_in_id_i(in_buf_pop_data.id),
    .ex_out_valid_i(ex_out_valid),
    .ex_out_ready_o(ex_out_ready),

    // Result Interface
    .xif_result_valid_o(xif_result_if.result_valid),
    .xif_result_id_i(xif_result_if.result.id),
    .result_push_valid_o(result_push_valid),
    .result_pop_valid_i(result_pop_valid)
  );

  // ============================
  // Posit specific Register File
  // ============================

  // Posit register address selection
  assign copreg_raddr[0] = in_buf_pop_data.instr[19:15];
  assign copreg_raddr[1] = in_buf_pop_data.instr[24:20];

  // Posit register writeback data mux
  always_comb begin
    copreg_wb_data = data_result;
    if (xif_mem_result_if.mem_result_valid) begin
        copreg_wb_data = xif_mem_result_if.mem_result.rdata;
    end
  end

  // Posit register addr writeback mux
  always_comb begin
    copreg_wb_addr = ex_tag_out.addr;
    if (xif_mem_result_if.mem_result_valid) begin
      copreg_wb_addr = mem_pop_data.rd;
    end else if (~decoded_data.use_copro & ~ex_out_valid) begin
      // TODO: This is the rd/addr of the intermediate buffer
      copreg_wb_addr = in_buf_pop_data.instr[11:7];
    end
  end

  xif_copro_regfile #(
    .DATA_WIDTH(xif_copro_pkg::X_RFR_WIDTH),
    .NR_READ_PORTS(xif_copro_pkg::X_NUM_RS),
    .NR_WRITE_PORTS(1)
  ) xif_copro_regfile_i (
    .clk_i(clk_i),
    .rst_ni(rst_ni),

    .raddr_i(copreg_raddr),
    .rdata_o(copreg_operands),

    .waddr_i(copreg_wb_addr),
    .wdata_i(copreg_wb_data),
    .we_i(copreg_we)
  );

  // =================
  // Operand Selection
  // =================

  for (genvar i = 0; i < xif_copro_pkg::X_NUM_RS; i++) begin : gen_operand_select
    always_comb begin
      unique case (decoded_data.op_select[i])
        xif_copro_pkg::CPU: begin
          if (ex_fwd[i]) begin
            operands[i] = data_result;
          end else begin
            operands[i] = {{XLEN - xif_copro_pkg::X_RFR_WIDTH{1'b0}}, in_buf_pop_data.rs[i]};
          end
        end
        xif_copro_pkg::RegA, xif_copro_pkg::RegB: begin
          if (ex_fwd[i] & (decoded_data.copro_op != xif_copro_pkg::NONE)) begin
            operands[i] = data_result;
          end else if (lsu_fwd[i] & (decoded_data.copro_op != xif_copro_pkg::NONE)) begin
            operands[i] = xif_mem_result_if.mem_result.rdata;
          end else begin
            operands[i] = {{XLEN - xif_copro_pkg::X_RFR_WIDTH{1'b0}}, copreg_operands[i]};
          end
        end
        default: begin
          operands[i] = '1;
        end
      endcase
    end
  end

  // ========================
  // Execution stage
  // ========================

  assign ex_tag_in.addr        = in_buf_pop_data.instr[11:7];  // rd
  assign ex_tag_in.rd_is_copro = decoded_data.rd_is_copro;
  assign ex_tag_in.id          = in_buf_pop_data.id;

  xif_copro_ex_stage #(
    .XLEN(XLEN),
    .tag_t(xif_copro_pkg::copro_tag_t)
  ) xif_copro_ex_stage_i (
    .clk_i(clk_i),
    .rst_ni(rst_ni),

    .operand_a_i(operands[0]),
    .operand_b_i(operands[1]),
    .operator_i(decoded_data.copro_op),
    .tag_i(ex_tag_in),

    .in_valid_i(ex_in_valid),
    .in_ready_o(ex_in_ready),
    .out_valid_o(ex_out_valid),
    .out_ready_i(ex_out_ready),

    .tag_o(ex_tag_out),
    .result_o(data_result)
  );

  // ========================
  // Result Interface Signals
  // ========================

  assign result_push_data.id      = xif_mem_result_if.mem_result_valid ? mem_pop_data.id
                                                                       : ex_tag_out.id;
  assign result_push_data.data    = data_result;
  assign result_push_data.rd      = ex_tag_out.addr;

  // Propagate these signals from the memory response and memory result interface
  assign result_push_data.exc     = mem_pop_data.exc;
  assign result_push_data.exccode = mem_pop_data.exccode;
  assign result_push_data.dbg     = mem_pop_data.dbg | (xif_mem_result_if.mem_result_valid
                                                        & xif_mem_result_if.mem_result.dbg);
  assign result_push_data.err     = xif_mem_result_if.mem_result_valid
                                  & xif_mem_result_if.mem_result.err;

  always_comb begin
    result_push_data.we = 1'b0;
    if (ex_out_valid & ~ex_tag_out.rd_is_copro) begin
      result_push_data.we = 1'b1;
    end
  end

  // Signal that there are some dirty bits in the coprocessor's register file
  always_comb begin
    result_push_data.ecswe   = '0;
    result_push_data.ecsdata = '0;
    if (ex_out_valid & ex_tag_out.rd_is_copro) begin
      result_push_data.ecswe   = 3'b010;
      result_push_data.ecsdata = 6'b001100;
    end
  end

  stream_fifo #(
    .FALL_THROUGH(1),
    .DATA_WIDTH(XLEN),
    .DEPTH(1),
    .T(xif_copro_pkg::x_result_t)
  ) result_fifo_i (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .flush_i(1'b0),
    .testmode_i(1'b0),
    .usage_o(  /* unused */),

    .data_i(result_push_data),
    .valid_i(result_push_valid),
    .ready_o(),  // TODO: Not used

    .data_o(result_pop_data),
    .valid_o(result_pop_valid),
    .ready_i(xif_result_if.result_ready)
  );

  assign xif_result_if.result = result_pop_data;

endmodule  // xif_copro

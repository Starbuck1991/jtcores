/* SPDX-FileCopyrightText: 2026 J. M. Artés
 * SPDX-License-Identifier: GPL-3.0-or-later */

// Arbitrates a memory transaction for the high-score system.
// This block is independent of the game memory map and persistence transport.
module jtframe_hiscore_bus #(
    parameter AW = 32
)(
    input               rst,
    input               clk,

    input               cmd_valid,
    output              cmd_ready,
    input               cmd_write,
    input      [AW-1:0] cmd_addr,
    input         [7:0] cmd_wdata,
    output reg    [7:0] cmd_rdata,
    output reg          cmd_done,
    output              busy,

    output reg          takeover_req,
    input               takeover_ack,

    output reg          mem_valid,
    output reg          mem_write,
    output reg [AW-1:0] mem_addr,
    output reg    [7:0] mem_wdata,
    input               mem_ready,
    input         [7:0] mem_rdata
);

localparam [1:0] ST_IDLE    = 2'd0,
                 ST_TAKE    = 2'd1,
                 ST_ACCESS  = 2'd2,
                 ST_RELEASE = 2'd3;

reg [1:0] state;

assign cmd_ready = state == ST_IDLE;
assign busy      = state != ST_IDLE;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state        <= ST_IDLE;
        cmd_rdata    <= 8'd0;
        cmd_done     <= 1'b0;
        takeover_req <= 1'b0;
        mem_valid    <= 1'b0;
        mem_write    <= 1'b0;
        mem_addr     <= {AW{1'b0}};
        mem_wdata    <= 8'd0;
    end else begin
        cmd_done <= 1'b0;
        case (state)
            ST_IDLE: begin
                takeover_req <= 1'b0;
                mem_valid    <= 1'b0;
                if (cmd_valid) begin
                    mem_write    <= cmd_write;
                    mem_addr     <= cmd_addr;
                    mem_wdata    <= cmd_wdata;
                    takeover_req <= 1'b1;
                    state        <= ST_TAKE;
                end
            end

            ST_TAKE: begin
                if (takeover_ack) begin
                    mem_valid <= 1'b1;
                    state     <= ST_ACCESS;
                end
            end

            ST_ACCESS: begin
                if (mem_ready) begin
                    if (!mem_write)
                        cmd_rdata <= mem_rdata;
                    mem_valid    <= 1'b0;
                    takeover_req <= 1'b0;
                    state        <= ST_RELEASE;
                end
            end

            ST_RELEASE: begin
                if (!takeover_ack) begin
                    cmd_done <= 1'b1;
                    state    <= ST_IDLE;
                end
            end

            default: state <= ST_IDLE;
        endcase
    end
end

endmodule

/* SPDX-FileCopyrightText: 2026 J. M. Artés
 * SPDX-License-Identifier: GPL-3.0-or-later */

`timescale 1ns/1ps

module test;

reg clk = 1'b0;
reg rst = 1'b1;
always #5 clk = ~clk;

reg         cmd_valid;
wire        cmd_ready;
reg         cmd_write;
reg  [31:0] cmd_addr;
reg   [7:0] cmd_wdata;
wire  [7:0] cmd_rdata;
wire        cmd_done;
wire        busy;
wire        takeover_req;
reg         takeover_ack;
wire        mem_valid;
wire        mem_write;
wire [31:0] mem_addr;
wire  [7:0] mem_wdata;
reg         mem_ready;
reg   [7:0] mem_rdata;

reg         ioctl_download, ioctl_upload, ioctl_wr;
reg   [7:0] ioctl_index, ioctl_dout, base_din, hs_din;
reg  [26:0] ioctl_addr;
wire  [7:0] ioctl_din, hs_dout, ioctl_upload_index;
wire [26:0] hs_addr;
wire        cfg_download, data_download, data_upload, hs_wr;
reg         hs_upload_req;
wire        ioctl_upload_req;

reg [7:0] memory [0:255];
integer failures = 0;
integer transactions = 0;
reg finished = 1'b0;

task check;
    input condition;
    input [8*96-1:0] message;
    begin
        if (condition !== 1'b1) begin
            failures = failures + 1;
            $display("FAIL: %0s", message);
        end
    end
endtask

task issue;
    input        write_op;
    input [31:0] address;
    input  [7:0] write_data;
    input  [7:0] read_data;
    input integer latency;
    integer k;
    begin
        wait (cmd_ready);
        @(negedge clk);
        cmd_write = write_op;
        cmd_addr  = address;
        cmd_wdata = write_data;
        cmd_valid = 1'b1;
        @(negedge clk);
        cmd_valid = 1'b0;

        wait (takeover_req);
        @(posedge clk); #1;
        check(!mem_valid, "memory access before takeover_ack");
        @(negedge clk);
        takeover_ack = 1'b1;
        wait (mem_valid);

        check(takeover_req && takeover_ack,
              "transaction must retain memory ownership");
        check(mem_write == write_op, "wrong memory operation");
        check(mem_addr == address, "wrong memory address");
        check(mem_wdata == write_data, "wrong write data");

        for (k = 0; k < latency; k = k + 1) begin
            @(posedge clk); #1;
            check(mem_valid, "mem_valid dropped while waiting");
            check(mem_addr == address, "address changed while waiting");
            check(mem_write == write_op, "operation changed while waiting");
            check(mem_wdata == write_data, "write data changed while waiting");
        end

        @(negedge clk);
        mem_rdata = read_data;
        mem_ready = 1'b1;
        @(posedge clk); #1;
        if (write_op)
            memory[address[7:0]] = write_data;
        transactions = transactions + 1;
        @(negedge clk);
        mem_ready = 1'b0;

        wait (!takeover_req);
        takeover_ack = 1'b0;
        wait (cmd_done);
        if (!write_op)
            check(cmd_rdata == read_data, "wrong read data");
        @(posedge clk);
    end
endtask

always @(posedge clk) begin
    if (!rst && mem_valid && !takeover_ack) begin
        failures = failures + 1;
        $display("FAIL: memory access without takeover_ack");
    end
end

initial begin
    cmd_valid       = 1'b0;
    cmd_write       = 1'b0;
    cmd_addr        = 32'd0;
    cmd_wdata       = 8'd0;
    takeover_ack    = 1'b0;
    mem_ready       = 1'b0;
    mem_rdata       = 8'd0;
    ioctl_download  = 1'b0;
    ioctl_upload    = 1'b0;
    ioctl_wr        = 1'b0;
    ioctl_index     = 8'd0;
    ioctl_addr      = 27'd0;
    ioctl_dout      = 8'd0;
    base_din        = 8'h3c;
    hs_din          = 8'ha5;
    hs_upload_req   = 1'b0;

    repeat (3) @(posedge clk);
    @(negedge clk);
    rst = 1'b0;
    @(posedge clk);

    // Configuration: only index 5 reaches the engine.
    ioctl_download = 1'b1;
    ioctl_wr       = 1'b1;
    ioctl_index    = 8'd5;
    ioctl_addr     = 27'h12345;
    ioctl_dout     = 8'h56;
    #1;
    check(cfg_download && !data_download, "index 5 decoding");
    check(hs_wr && hs_addr == ioctl_addr && hs_dout == ioctl_dout,
          "configuration transfer");

    // Persistent data: index 6.
    ioctl_index = 8'd6;
    #1;
    check(!cfg_download && data_download, "index 6 decoding");
    check(hs_wr, "data download must assert hs_wr");

    // Existing NVRAM traffic must remain separate from high scores.
    ioctl_index = 8'd2;
    #1;
    check(!cfg_download && !data_download && !hs_wr,
          "index 2 must bypass the high-score front end");

    ioctl_download = 1'b0;
    ioctl_wr       = 1'b0;
    ioctl_upload   = 1'b1;
    ioctl_index    = 8'd6;
    #1;
    check(data_upload, "index 6 upload decoding");
    check(ioctl_din == hs_din, "upload must select high-score data");

    ioctl_index = 8'd2;
    #1;
    check(!data_upload && ioctl_din == base_din,
          "other uploads must preserve the existing channel");

    hs_upload_req = 1'b1;
    #1;
    check(ioctl_upload_req && ioctl_upload_index == 8'd6,
          "upload request and persistent index");
    hs_upload_req = 1'b0;
    ioctl_upload  = 1'b0;

    // Write and read with no additional wait cycles.
    issue(1'b1, 32'h0000e800, 8'h42, 8'h00, 0);
    check(memory[8'h00] == 8'h42, "zero-latency write");
    issue(1'b0, 32'h0000e800, 8'h00, memory[8'h00], 0);

    // One and multiple adapter wait cycles.
    issue(1'b1, 32'h0000e9c0, 8'h1e, 8'h00, 1);
    check(memory[8'hc0] == 8'h1e, "one-cycle-latency write");
    issue(1'b0, 32'h0000e9c0, 8'h00, memory[8'hc0], 4);

    check(transactions == 4, "completed transaction count");
    check(!busy && cmd_ready, "master must return to idle");

    if (failures == 0)
        $display("PASS: IOCTL front end and high-score memory contract");
    else
        $display("FAIL: %0d checks failed", failures);
    finished = 1'b1;
    $finish;
end

initial begin
    #5000;
    if (!finished) begin
        $display("FAIL: simulation timeout");
        $finish;
    end
end

jtframe_hiscore_bus u_bus(
    .rst          ( rst          ),
    .clk          ( clk          ),
    .cmd_valid    ( cmd_valid    ),
    .cmd_ready    ( cmd_ready    ),
    .cmd_write    ( cmd_write    ),
    .cmd_addr     ( cmd_addr     ),
    .cmd_wdata    ( cmd_wdata    ),
    .cmd_rdata    ( cmd_rdata    ),
    .cmd_done     ( cmd_done     ),
    .busy         ( busy         ),
    .takeover_req ( takeover_req ),
    .takeover_ack ( takeover_ack ),
    .mem_valid    ( mem_valid    ),
    .mem_write    ( mem_write    ),
    .mem_addr     ( mem_addr     ),
    .mem_wdata    ( mem_wdata    ),
    .mem_ready    ( mem_ready    ),
    .mem_rdata    ( mem_rdata    )
);

jtframe_hiscore_ioctl u_ioctl(
    .ioctl_download    ( ioctl_download    ),
    .ioctl_upload      ( ioctl_upload      ),
    .ioctl_wr          ( ioctl_wr          ),
    .ioctl_index       ( ioctl_index       ),
    .ioctl_addr        ( ioctl_addr        ),
    .ioctl_dout        ( ioctl_dout        ),
    .base_din          ( base_din          ),
    .ioctl_din         ( ioctl_din         ),
    .cfg_download      ( cfg_download      ),
    .data_download     ( data_download     ),
    .data_upload       ( data_upload       ),
    .hs_wr             ( hs_wr             ),
    .hs_addr           ( hs_addr           ),
    .hs_dout           ( hs_dout           ),
    .hs_din            ( hs_din            ),
    .hs_upload_req     ( hs_upload_req     ),
    .ioctl_upload_req  ( ioctl_upload_req  ),
    .ioctl_upload_index( ioctl_upload_index)
);

endmodule

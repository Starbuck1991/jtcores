/* SPDX-FileCopyrightText: 2026 J. M. Artés
 * SPDX-License-Identifier: GPL-3.0-or-later */

// Minimal top level for elaborating the engine and its MiSTer transport.
module lint_top(
    input         clk,
    input         rst,
    input         autosave,
    input         osd_status,
    input         ioctl_download,
    input         ioctl_upload,
    input         ioctl_wr,
    input   [7:0] ioctl_index,
    input  [26:0] ioctl_addr,
    input   [7:0] ioctl_dout,
    input   [7:0] base_din,
    output  [7:0] ioctl_din,
    output        ioctl_upload_req,
    output  [7:0] ioctl_upload_index,
    output        takeover_req,
    input         takeover_ack,
    output        mem_valid,
    output        mem_write,
    output [31:0] mem_addr,
    output  [7:0] mem_wdata,
    input         mem_ready,
    input   [7:0] mem_rdata,
    output        save_busy,
    output        configured
);

wire        cfg_download;
wire        data_download;
wire        data_upload;
wire        hs_wr;
wire [26:0] hs_addr;
wire  [7:0] hs_dout;
wire  [7:0] hs_din;
wire        hs_upload_req;

jtframe_hiscore u_hiscore(
    .clk              ( clk              ),
    .reset            ( rst              ),
    .autosave         ( autosave         ),
    .cfg_download     ( cfg_download     ),
    .data_download    ( data_download    ),
    .data_upload      ( data_upload      ),
    .ioctl_upload_req ( hs_upload_req    ),
    .ioctl_wr         ( hs_wr            ),
    .ioctl_addr       ( hs_addr          ),
    .OSD_STATUS       ( osd_status       ),
    .data_from_hps    ( hs_dout          ),
    .data_to_hps      ( hs_din           ),
    .takeover_req     ( takeover_req     ),
    .takeover_ack     ( takeover_ack     ),
    .mem_valid        ( mem_valid        ),
    .mem_write        ( mem_write        ),
    .mem_addr         ( mem_addr         ),
    .mem_wdata        ( mem_wdata        ),
    .mem_ready        ( mem_ready        ),
    .mem_rdata        ( mem_rdata        ),
    .save_busy        ( save_busy        ),
    .configured       ( configured       )
);

jtframe_hiscore_ioctl u_ioctl(
    .ioctl_download     ( ioctl_download      ),
    .ioctl_upload       ( ioctl_upload        ),
    .ioctl_wr           ( ioctl_wr            ),
    .ioctl_index        ( ioctl_index         ),
    .ioctl_addr         ( ioctl_addr          ),
    .ioctl_dout         ( ioctl_dout          ),
    .base_din           ( base_din            ),
    .ioctl_din          ( ioctl_din           ),
    .cfg_download       ( cfg_download        ),
    .data_download      ( data_download       ),
    .data_upload        ( data_upload         ),
    .hs_wr              ( hs_wr               ),
    .hs_addr            ( hs_addr             ),
    .hs_dout            ( hs_dout             ),
    .hs_din             ( hs_din              ),
    .hs_upload_req      ( hs_upload_req       ),
    .ioctl_upload_req   ( ioctl_upload_req    ),
    .ioctl_upload_index ( ioctl_upload_index  )
);

endmodule

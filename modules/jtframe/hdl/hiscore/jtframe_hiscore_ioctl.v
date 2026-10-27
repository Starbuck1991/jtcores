/* SPDX-FileCopyrightText: 2026 J. M. Artés
 * SPDX-License-Identifier: GPL-3.0-or-later */

// IOCTL front end independent from the high-score engine.
// Separates the MiSTer transport from the game memory interface.
module jtframe_hiscore_ioctl #(
    parameter [7:0] CFG_INDEX  = 8'd5,
    parameter [7:0] DATA_INDEX = 8'd6
)(
    input             ioctl_download,
    input             ioctl_upload,
    input             ioctl_wr,
    input      [ 7:0] ioctl_index,
    input      [26:0] ioctl_addr,
    input      [ 7:0] ioctl_dout,
    input      [ 7:0] base_din,
    output     [ 7:0] ioctl_din,

    output            cfg_download,
    output            data_download,
    output            data_upload,
    output            hs_wr,
    output     [26:0] hs_addr,
    output     [ 7:0] hs_dout,
    input      [ 7:0] hs_din,

    input             hs_upload_req,
    output            ioctl_upload_req,
    output     [ 7:0] ioctl_upload_index
);

assign cfg_download   = ioctl_download && ioctl_index == CFG_INDEX;
assign data_download  = ioctl_download && ioctl_index == DATA_INDEX;
assign data_upload    = ioctl_upload   && ioctl_index == DATA_INDEX;
assign hs_wr          = ioctl_wr && (cfg_download || data_download);
assign hs_addr        = ioctl_addr;
assign hs_dout        = ioctl_dout;

assign ioctl_din          = data_upload ? hs_din : base_din;
assign ioctl_upload_req   = hs_upload_req;
assign ioctl_upload_index = DATA_INDEX;

endmodule

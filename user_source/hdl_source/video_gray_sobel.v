`timescale 1ns/1ps

// Grayscale / Sobel edge detector.
//
// patch_v2 changes (see PATCH_NOTES.md):
//   * y is now 0 on the first ACTIVE line.  It used to be counted from the
//     vsync rising edge and therefore started at ~24 on the first active line.
//   * new input in_win: Sobel is only evaluated when the whole 3x3 window lies
//     inside the camera image window.  This removes the rectangle that used to
//     appear around the image where it meets the black HDMI border.
//   * removed the unused avg_gray (/3) and sharp_detail logic.
//   * advanced item 6 (resource optimisation): the two 1280 x 8 line buffers (distributed RAM with
//     asynchronous read) are replaced by ONE 1280 x 16 synchronous-read block RAM that holds {current line,
//     previous line}.  The input is registered one clock so that the RAM read of the next pixel is issued
//     while the previous pixel is processed; the module therefore has one clock more latency.
module video_gray_sobel #(
    parameter integer H_ACTIVE = 1280,
    parameter integer V_ACTIVE = 720,
    parameter integer EDGE_THRESHOLD = 32,
    parameter integer BIN_THRESHOLD  = 112,  // binarize: gray >= threshold -> white
    parameter integer SPLIT_X        = 624   // split-screen compare: columns left of this show the original (window centre)
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        in_vs,
    input  wire        in_hs,
    input  wire        in_de,
    input  wire [23:0] in_rgb,
    input  wire        in_win,     // high while the pixel belongs to the camera image window
    input  wire [2:0]  mode,     // 0 original, 1 gray, 2 edge, 3 edge overlay, 5 binarize, 6 invert
    input  wire        split,    // split-screen compare in modes 1, 2, 5, 6: left of SPLIT_X original, right processed
    output reg         out_vs,
    output reg         out_hs,
    output reg         out_de,
    output reg [23:0]  out_rgb,
    output reg [13:0]  out_x,
    output reg [13:0]  out_y,
    output reg         edge_flag,
    output reg         fill_edge,
    output reg  [10:0] mag,        // |gx| + |gy| of the 3x3 window ending at the current pixel (used by the focus meter)
    output reg         mag_v       // mag is valid (whole window inside the image window)
);

    // ---- input register stage + read-address counter (xa follows the raw input, x follows the registered input) ----
    reg        r_vs, r_hs, r_de, r_win;
    reg [23:0] r_rgb;
    reg [13:0] xa;
    reg        vsa_d, hsa_d;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_vs <= 0; r_hs <= 0; r_de <= 0; r_win <= 0; r_rgb <= 0;
            xa <= 0; vsa_d <= 0; hsa_d <= 0;
        end else begin
            r_vs <= in_vs; r_hs <= in_hs; r_de <= in_de; r_win <= in_win; r_rgb <= in_rgb;
            vsa_d <= in_vs; hsa_d <= in_hs;
            if (in_vs && !vsa_d)           xa <= 0;
            else if (!in_hs && hsa_d)      xa <= 0;
            else if (in_de)                xa <= xa + 1'b1;
        end
    end

    reg [13:0] x;
    reg [13:0] y;
    // ---- line RAM: {current line, previous line} at column x, synchronous read ----
    (* ram_style = "bram" *) reg [15:0] line_ram [0:H_ACTIVE-1];
    reg [15:0] line_q;
    wire       ram_we = r_de && (x < H_ACTIVE);
    wire [15:0] ram_wd;
    always @(posedge clk) begin
        line_q <= line_ram[xa];
        if (ram_we) line_ram[x] <= ram_wd;
    end
    reg [7:0] top_d1;
    reg [7:0] top_d2;
    reg [7:0] mid_d1;
    reg [7:0] mid_d2;
    reg [7:0] bottom_d1;
    reg [7:0] bottom_d2;

    reg        vs_d;
    reg        hs_d;

    // window bookkeeping
    reg        line_has_de;   // current line has produced at least one DE pixel
    reg        line_has_win;  // current line has produced at least one window pixel
    reg [1:0]  win_run;       // consecutive window pixels before the current one (saturates at 3)
    reg [1:0]  win_rows;      // consecutive previous lines containing window pixels (saturates at 2)

    wire [7:0] top_gray = line_q[7:0];
    wire [7:0] mid_gray = line_q[15:8];
    wire [15:0] luma_sum = r_rgb[23:16] * 16'd77 +
                            r_rgb[15:8]  * 16'd150 +
                            r_rgb[7:0]   * 16'd29;
    wire [7:0] bottom_gray = luma_sum[15:8];
    assign ram_wd = {bottom_gray, mid_gray};

    wire signed [10:0] gx = -$signed({3'b0, top_d2}) +
                             $signed({3'b0, top_gray}) -
                             2 * $signed({3'b0, mid_d2}) +
                             2 * $signed({3'b0, mid_gray}) -
                             $signed({3'b0, bottom_d2}) +
                             $signed({3'b0, bottom_gray});

    wire signed [10:0] gy = $signed({3'b0, top_d2}) +
                             2 * $signed({3'b0, top_d1}) +
                             $signed({3'b0, top_gray}) -
                             $signed({3'b0, bottom_d2}) -
                             2 * $signed({3'b0, bottom_d1}) -
                             $signed({3'b0, bottom_gray});

    wire [10:0] abs_gx = gx[10] ? (~gx + 1'b1) : gx;
    wire [10:0] abs_gy = gy[10] ? (~gy + 1'b1) : gy;

    // The 3x3 window covers the current pixel, the two before it, and the
    // current line plus the two previous lines: all of them must be in the window.
    wire        win_ok   = r_win && (win_run == 2'd3 || win_run == 2'd2) && (win_rows == 2'd2);
    wire        edge_now = (x >= 2) && (y >= 2) && win_ok &&
                           ((abs_gx + abs_gy) >= EDGE_THRESHOLD);
    wire        fill_edge_now = edge_now && (abs_gx >= abs_gy);
    wire        mag_valid_now = (x >= 2) && (y >= 2) && win_ok;

    // processed pixel for the selected mode
    // pseudo colour (blue - cyan - green - yellow - red) of an 8 bit gray value
    function [23:0] pc;
        input [7:0] g;
        reg [7:0] t;
        begin
            t = {g[5:0], 2'b00};
            case (g[7:6])
                2'd0:   pc = {8'd0, t, 8'd255};
                2'd1:   pc = {8'd0, 8'd255, ~t};
                2'd2:   pc = {t, 8'd255, 8'd0};
                default: pc = {8'd255, ~t, 8'd0};
            endcase
        end
    endfunction
    reg [23:0] proc_rgb;
    always @(*) begin
        case (mode)
            3'd1:    proc_rgb = split ? pc(bottom_gray) : {3{bottom_gray}};
            3'd2:    proc_rgb = edge_now ? 24'hFFFFFF : 24'h000000;
            3'd3:    proc_rgb = edge_now ? 24'h00FF00 : r_rgb;
            3'd5:    proc_rgb = (bottom_gray >= BIN_THRESHOLD) ? 24'hFFFFFF : 24'h000000;
            3'd6:    proc_rgb = ~r_rgb;
            default: proc_rgb = r_rgb;
        endcase
    end
    // split-screen compare (original | processed) with a 2-pixel white divider inside the image window
    wire        split_ok   = split && (mode == 3'd1 || mode == 3'd2 || mode == 3'd5 || mode == 3'd6);
    wire        split_left = (x < SPLIT_X);
    wire        split_line = r_win && (x == SPLIT_X || x == SPLIT_X + 1);


    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x <= 0;
            y <= 0;
            vs_d <= 0;
            hs_d <= 0;
            line_has_de <= 0;
            line_has_win <= 0;
            win_run <= 0;
            win_rows <= 0;
            top_d1 <= 0;
            top_d2 <= 0;
            mid_d1 <= 0;
            mid_d2 <= 0;
            bottom_d1 <= 0;
            bottom_d2 <= 0;
            out_vs <= 0;
            out_hs <= 0;
            out_de <= 0;
            out_rgb <= 0;
            out_x <= 0;
            out_y <= 0;
            edge_flag <= 0;
            fill_edge <= 0;
            mag <= 0;
            mag_v <= 0;
        end else begin
            vs_d <= r_vs;
            hs_d <= r_hs;

            if (r_vs && !vs_d) begin
                // new frame
                x <= 0;
                y <= 0;
                line_has_de <= 1'b0;
                line_has_win <= 1'b0;
                win_rows <= 2'd0;
            end else if (!r_hs && hs_d) begin
                // end of a line: y only advances after lines that carried active pixels,
                // so blanking lines before the first active line do not move it.
                x <= 0;
                if (line_has_de)
                    y <= y + 1'b1;
                if (line_has_win)
                    win_rows <= (win_rows == 2'd2) ? 2'd2 : (win_rows + 1'b1);
                else
                    win_rows <= 2'd0;
                line_has_de <= 1'b0;
                line_has_win <= 1'b0;
            end else if (r_de) begin
                x <= x + 1'b1;
                line_has_de <= 1'b1;
                if (r_win)
                    line_has_win <= 1'b1;
            end

            if (r_de && r_win)
                win_run <= (win_run == 2'd3) ? 2'd3 : (win_run + 1'b1);
            else
                win_run <= 2'd0;

            if (r_de && (x < H_ACTIVE)) begin
                top_d1 <= top_gray;
                top_d2 <= top_d1;
                mid_d1 <= mid_gray;
                mid_d2 <= mid_d1;
                bottom_d1 <= bottom_gray;
                bottom_d2 <= bottom_d1;
            end

            out_vs <= r_vs;
            out_hs <= r_hs;
            out_de <= r_de;
            out_x <= x;
            out_y <= y;
            edge_flag <= edge_now;
            fill_edge <= fill_edge_now;
            mag <= abs_gx + abs_gy;
            mag_v <= mag_valid_now;

            out_rgb <= (split_ok && split_line) ? 24'hFFFFFF :
                       (split_ok && split_left)  ? r_rgb :
                                                   proc_rgb;
        end
    end

endmodule

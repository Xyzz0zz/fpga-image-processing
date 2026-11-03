`timescale 1ns/1ps

// Robust scanline region filling for real-time FPGA video.
// Only vertically coherent horizontal-gradient edges are used as region
// boundaries, preventing noisy texture edges from producing green stripes.
module video_region_fill #(
    parameter integer H_ACTIVE = 1280,
    parameter integer MIN_EDGE_GAP = 32
)(
    input  wire        clk,
    input  wire        rst_n,

    input  wire        in_vs,
    input  wire        in_hs,
    input  wire        in_de,
    input  wire [13:0] in_x,
    input  wire [13:0] in_y,
    input  wire [23:0] in_rgb,
    input  wire        in_edge,
    input  wire        in_fill_edge,
    input  wire        fill_mode,

    output reg         out_vs,
    output reg         out_hs,
    output reg         out_de,
    output reg  [13:0] out_x,
    output reg  [13:0] out_y,
    output reg  [23:0] out_rgb
);

    localparam integer ADDR_LAST = H_ACTIVE - 1;

    reg [23:0] rgb_line [0:H_ACTIVE-1];
    reg [1:0]  mask_line [0:H_ACTIVE-1];
    reg        edge_line0 [0:H_ACTIVE-1];
    reg        edge_line1 [0:H_ACTIVE-1];

    reg [23:0] rgb_line_q;
    reg [1:0]  mask_line_q;

    reg        in_vs_d1;
    reg        in_hs_d1;
    reg        in_de_d1;
    reg [13:0] in_x_d1;
    reg [13:0] in_y_d1;
    reg [23:0] in_rgb_d1;
    reg        fill_mode_d1;
    reg        prev_line_valid_d1;
    reg [11:0] prev_edge_count_d1;
    reg [13:0] prev_last_edge_x_d1;

    reg        in_de_d0;
    reg        edge_bank;
    reg        edge_prev_valid;
    reg        fill_inside;
    reg        fill_edge_have;
    reg [13:0] fill_edge_last_x;
    reg [11:0] edge_count;
    reg [13:0] last_edge_x;

    reg        prev_line_valid;
    reg [11:0] prev_edge_count;
    reg [13:0] prev_last_edge_x;

    wire [10:0] ram_addr = in_x[10:0];
    wire        row_first = in_de && (in_x == 14'd0);

    wire prev_edge_center = edge_bank ? edge_line0[ram_addr] : edge_line1[ram_addr];
    wire prev_edge_left   = (in_x == 0) ? 1'b0 :
                            (edge_bank ? edge_line0[ram_addr - 1'b1] :
                                         edge_line1[ram_addr - 1'b1]);
    wire prev_edge_right  = (in_x >= ADDR_LAST) ? 1'b0 :
                            (edge_bank ? edge_line0[ram_addr + 1'b1] :
                                         edge_line1[ram_addr + 1'b1]);

    wire edge_vertical_ok = edge_prev_valid &&
                            (prev_edge_center || prev_edge_left || prev_edge_right);
    wire fill_gap_ok = row_first ? 1'b1 :
                       (!fill_edge_have ||
                        ((in_x - fill_edge_last_x) >= MIN_EDGE_GAP));
    wire accepted_fill_edge = in_de && in_fill_edge &&
                              edge_vertical_ok && fill_gap_ok;

    wire fill_state_now = row_first ? 1'b0 : fill_inside;
    wire pixel_edge = in_de && in_edge;
    wire pixel_fill = in_de && !in_edge && fill_state_now;
    wire [1:0] pixel_mask = {pixel_edge, pixel_fill};

    function [23:0] style_background;
        input [23:0] rgb;
        reg [8:0] gray;
        reg [7:0] gray_dim;
        begin
            gray = {1'b0, rgb[23:16]} + {1'b0, rgb[15:8]} + {1'b0, rgb[7:0]};
            gray_dim = {1'b0, gray[8:2]};
            style_background = {gray_dim, gray_dim, gray_dim};
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            in_de_d0          <= 1'b0;
            edge_bank         <= 1'b0;
            edge_prev_valid   <= 1'b0;
            fill_inside       <= 1'b0;
            fill_edge_have    <= 1'b0;
            fill_edge_last_x  <= 14'd0;
            edge_count        <= 12'd0;
            last_edge_x       <= 14'd0;
            prev_line_valid   <= 1'b0;
            prev_edge_count   <= 12'd0;
            prev_last_edge_x  <= 14'd0;
        end
        else begin
            in_de_d0 <= in_de;

            if(in_vs) begin
                edge_bank         <= 1'b0;
                edge_prev_valid   <= 1'b0;
                fill_inside       <= 1'b0;
                fill_edge_have    <= 1'b0;
                fill_edge_last_x  <= 14'd0;
                edge_count        <= 12'd0;
                last_edge_x       <= 14'd0;
                prev_line_valid   <= 1'b0;
            end
            else begin
                if(in_de) begin
                    if(row_first) begin
                        fill_inside      <= accepted_fill_edge;
                        edge_count       <= {11'd0, accepted_fill_edge};
                        fill_edge_have   <= accepted_fill_edge;
                        if(accepted_fill_edge) begin
                            fill_edge_last_x <= in_x;
                            last_edge_x      <= in_x;
                        end
                    end
                    else if(accepted_fill_edge) begin
                        fill_inside      <= ~fill_state_now;
                        edge_count       <= edge_count + 12'd1;
                        fill_edge_have   <= 1'b1;
                        fill_edge_last_x <= in_x;
                        last_edge_x      <= in_x;
                    end
                    else begin
                        fill_inside <= fill_state_now;
                    end
                end

                if(in_de_d0 && !in_de) begin
                    edge_bank        <= ~edge_bank;
                    edge_prev_valid  <= 1'b1;
                    prev_line_valid  <= 1'b1;
                    prev_edge_count  <= edge_count;
                    prev_last_edge_x <= last_edge_x;
                end
            end
        end
    end

    always @(posedge clk) begin
        if(in_de) begin
            rgb_line[in_x[10:0]]  <= in_rgb;
            mask_line[in_x[10:0]] <= pixel_mask;
            if(edge_bank)
                edge_line1[in_x[10:0]] <= in_fill_edge;
            else
                edge_line0[in_x[10:0]] <= in_fill_edge;
        end

        rgb_line_q  <= rgb_line[in_x[10:0]];
        mask_line_q <= mask_line[in_x[10:0]];

        in_vs_d1             <= in_vs;
        in_hs_d1             <= in_hs;
        in_de_d1             <= in_de;
        in_x_d1              <= in_x;
        in_y_d1              <= in_y;
        in_rgb_d1            <= in_rgb;
        fill_mode_d1         <= fill_mode;
        prev_line_valid_d1   <= prev_line_valid;
        prev_edge_count_d1   <= prev_edge_count;
        prev_last_edge_x_d1  <= prev_last_edge_x;
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            out_vs  <= 1'b0;
            out_hs  <= 1'b0;
            out_de  <= 1'b0;
            out_x   <= 14'd0;
            out_y   <= 14'd0;
            out_rgb <= 24'd0;
        end
        else begin
            out_vs <= in_vs_d1;
            out_hs <= in_hs_d1;
            out_de <= in_de_d1;
            out_x  <= in_x_d1;
            out_y  <= in_y_d1;

            if(!fill_mode_d1)
                out_rgb <= in_rgb_d1;
            else if(!prev_line_valid_d1)
                out_rgb <= style_background(in_rgb_d1);
            else if(mask_line_q[1])
                out_rgb <= 24'hFFFFFF;
            else if(mask_line_q[0] &&
                    (prev_edge_count_d1 >= 12'd2) &&
                    (in_x_d1 < prev_last_edge_x_d1))
                out_rgb <= 24'h18D068;
            else
                out_rgb <= style_background(rgb_line_q);
        end
    end

endmodule

module hdmi_mixer #(
    parameter H_OFFSET = 0,
    parameter V_OFFSET = 0,
    parameter IMG_WIDTH = 1600,
    parameter IMG_HEIGHT = 900,
    parameter integer DEBUG_MODE = 0
)(
    input wire        I_clk,
    input wire        I_rst_n,

    input wire        I_video_vsync,
    input wire        I_video_hsync,
    input wire        I_video_de,
    input wire        I_video_user,
    input wire        I_video_last,

    input wire[3:0]   I_debug_status,

    output wire       O_video_rd_en,
    input wire[23:0]  I_video_rd_data,
    // patch_v2: digital gain in 1/16 steps (16 = 1x), driven by the auto-gain loop in the top level
    input wire[7:0]   I_gain,

    output reg        O_hdmi_vsync,
    output reg        O_hdmi_hsync,
    output reg        O_hdmi_de,
    output reg[23:0]  O_hdmi_data,
    // patch_v2: high while O_hdmi_data carries camera image pixels (aligned with O_hdmi_data)
    output reg        O_hdmi_win
);

    reg        S_video_vsync_1d;
    reg        S_video_vsync_2d;
    reg        S_video_hsync_1d;
    reg        S_video_hsync_2d;
    reg        S_video_de_1d;
    reg        S_video_de_2d;
    reg [23:0] S_video_data_1d;
    reg [23:0] S_video_data_2d;
    reg        S_window_active_1d;
    reg        S_window_active_2d;
    reg [11:0] S_x;
    function [7:0] gainq;
        input [7:0] value;
        input [7:0] g;
        reg [15:0] prod;
        begin
            prod = value * g;
            if(prod[15:12] != 4'd0)
                gainq = 8'hff;
            else
                gainq = prod[11:4];
        end
    endfunction
    function [7:0] gain8;
        input [7:0] value;
        reg [9:0] scaled;
        begin
            scaled = value * 10'd8;
            if(scaled >= 10'd255)
                gain8 = 8'hff;
            else
                gain8 = scaled[7:0];
        end
    endfunction
    function [7:0] gain6;
        input [7:0] value;
        reg [10:0] scaled6;
        begin
            scaled6 = value * 11'd6;
            if(scaled6 < 11'd245)
                gain6 = scaled6[7:0];
            else if(scaled6 < 11'd600)
                gain6 = 8'd245 + ((scaled6 - 11'd245) >> 3);
            else
                gain6 = 8'hff;
        end
    endfunction

    function [7:0] gain10;
        input [7:0] value;
        reg [9:0] scaled10;
        begin
            scaled10 = value * 10'd10;
            if(scaled10 >= 10'd255)
                gain10 = 8'hff;
            else
                gain10 = scaled10[7:0];
        end
    endfunction
    reg [11:0] S_y;

    wire S_window_active;
    wire S_display_active;
    assign S_display_active = S_window_active && (S_x < (H_OFFSET + IMG_WIDTH - 32)) && (S_y < (V_OFFSET + IMG_HEIGHT - 4));
    assign S_window_active = I_video_de &&
                             (S_x >= H_OFFSET) &&
                             (S_x < (H_OFFSET + IMG_WIDTH)) &&
                             (S_y >= V_OFFSET) &&
                             (S_y < (V_OFFSET + IMG_HEIGHT));

    // Read exactly IMG_WIDTH pixels on each of IMG_HEIGHT lines.  The HDMI
    // active area may be larger than the stored frame, in which case remaining
    // pixels are emitted as black borders without consuming DDR data.
    assign O_video_rd_en = S_window_active;

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_x <= 12'd0;
            S_y <= 12'd0;
        end
        else begin
            if(I_video_user)
                S_y <= 12'd0;
            else if(I_video_last)
                S_y <= S_y + 12'd1;

            if(!I_video_de || I_video_last)
                S_x <= 12'd0;
            else
                S_x <= S_x + 12'd1;
        end
    end

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_video_vsync_1d <= 1'b0;
            S_video_vsync_2d <= 1'b0;
            S_video_hsync_1d <= 1'b0;
            S_video_hsync_2d <= 1'b0;
            S_video_de_1d    <= 1'b0;
            S_video_de_2d    <= 1'b0;
            S_window_active_1d <= 1'b0;
            S_window_active_2d <= 1'b0;
            O_hdmi_vsync     <= 1'b0;
            O_hdmi_hsync     <= 1'b0;
            O_hdmi_win       <= 1'b0;
            O_hdmi_de        <= 1'b0;
            O_hdmi_data      <= 24'd0;
        end
        else begin
            S_video_vsync_1d <= I_video_vsync;
            S_video_vsync_2d <= S_video_vsync_1d;
            O_hdmi_vsync     <= S_video_vsync_2d;
            O_hdmi_win       <= S_display_active;

            S_video_hsync_1d <= I_video_hsync;
            S_video_hsync_2d <= S_video_hsync_1d;
            O_hdmi_hsync     <= S_video_hsync_2d;

            S_video_de_1d    <= I_video_de;
            S_video_de_2d    <= S_video_de_1d;
            S_window_active_1d <= S_window_active;
            S_window_active_2d <= S_window_active_1d;
            O_hdmi_de        <= S_video_de_2d;
            S_video_data_1d  <= I_video_rd_data;
            S_video_data_2d  <= S_video_data_1d;

            if(DEBUG_MODE == 1) begin
                if(S_video_de_2d) begin
                    if(S_x < 12'd128)
                        O_hdmi_data <= 24'hff0000;
                    else if(S_x < 12'd256)
                        O_hdmi_data <= 24'h00ff00;
                    else if(S_x < 12'd384)
                        O_hdmi_data <= 24'h0000ff;
                    else if(S_x < 12'd512)
                        O_hdmi_data <= 24'hffff00;
                    else if(S_x < 12'd640)
                        O_hdmi_data <= 24'h00ffff;
                    else if(S_x < 12'd768)
                        O_hdmi_data <= 24'hff00ff;
                    else if(S_x < 12'd896)
                        O_hdmi_data <= 24'hffffff;
                    else
                        O_hdmi_data <= 24'h202020;
                end
                else begin
                    O_hdmi_data <= 24'd0;
                end
            end
            else if(DEBUG_MODE == 2) begin
                if(S_video_de_2d) begin
                    case (I_debug_status)
                        4'b0000: O_hdmi_data <= 24'h000000;
                        4'b0001: O_hdmi_data <= 24'hff0000;
                        4'b0011: O_hdmi_data <= 24'hffff00;
                        4'b0111: O_hdmi_data <= 24'h00ff00;
                        4'b1111: O_hdmi_data <= I_video_rd_data;
                        default: O_hdmi_data <= 24'h0000ff;
                    endcase
                end
                else begin
                    O_hdmi_data <= 24'd0;
                end
            end
            else if(DEBUG_MODE == 3) begin
                if(S_video_de_2d) begin
                    if(S_x < 12'd256)
                        O_hdmi_data <= I_debug_status[0] ? 24'hff8000 : 24'h201000;
                    else if(S_x < 12'd512)
                        O_hdmi_data <= I_debug_status[1] ? 24'hffff00 : 24'h202000;
                    else if(S_x < 12'd768)
                        O_hdmi_data <= I_debug_status[2] ? 24'hff0000 : 24'h200000;
                    else
                        O_hdmi_data <= I_debug_status[3] ? 24'h00ffff : 24'h002020;
                end
                else begin
                    O_hdmi_data <= 24'd0;
                end
            end


            else if(DEBUG_MODE == 5) begin
                // Pipeline stage diagnostic:
                // 0=no ISP valid, 1=no DDR write, 2=no DDR read,
                // 3=DDR read but all-zero output, 4=nonzero video data.
                if(S_video_de_2d) begin
                    case (I_debug_status)
                        4'd0: O_hdmi_data <= 24'h0000ff;
                        4'd1: O_hdmi_data <= 24'hff0000;
                        4'd2: O_hdmi_data <= 24'hffff00;
                        4'd3: O_hdmi_data <= 24'hff00ff;
                        4'd4: O_hdmi_data <= 24'h00ff00;
                        default: O_hdmi_data <= 24'hffffff;
                    endcase
                end
                else begin
                    O_hdmi_data <= 24'd0;
                end
            end

            else if(DEBUG_MODE == 6) begin
                // DDR read-path diagnostic:
                // 0=no DDR init, 1=no read request, 2=no DDR user ready,
                // 3=no read valid, 4=read data all zero, 5=nonzero read data.
                if(S_video_de_2d) begin
                    case (I_debug_status)
                        4'd0: O_hdmi_data <= 24'h0000ff;
                        4'd1: O_hdmi_data <= 24'hff0000;
                        4'd2: O_hdmi_data <= 24'hffff00;
                        4'd3: O_hdmi_data <= 24'h00ffff;
                        4'd4: O_hdmi_data <= 24'hff00ff;
                        4'd5: O_hdmi_data <= 24'h00ff00;
                        default: O_hdmi_data <= 24'hffffff;
                    endcase
                end
                else begin
                    O_hdmi_data <= 24'd0;
                end
            end

            else if(DEBUG_MODE == 7) begin
                // Window-alignment diagnostic: green rectangle means the
                // 1024x600 read window is active in the HDMI output timing.
                O_hdmi_data <= S_window_active_2d ? 24'h00ff00 : 24'h000000;
            end

            else if(DEBUG_MODE == 8) begin
                // Raw-data visibility diagnostic: white = nonzero DDR pixel,
                // dark gray = zero pixel. This distinguishes an all-black
                // image from a data-delay/channel-format problem.
                if(S_video_de_2d)
                    O_hdmi_data <= (I_video_rd_data != 24'd0) ? 24'hffffff : 24'h202020;
                else
                    O_hdmi_data <= 24'd0;
            end            else if(DEBUG_MODE == 4) begin
                // Full-screen MIPI receive diagnostic.  The status is
                // generated and synchronized in design_top_wrapper.
                if(S_video_de_2d) begin
                    case (I_debug_status)
                        4'd0: O_hdmi_data <= 24'h000080; // blue: sensor config incomplete
                        4'd1: O_hdmi_data <= 24'h000000; // black: no MIPI HS traffic
                        4'd2: O_hdmi_data <= 24'h00ffff; // cyan: HS present, no complete frame
                        4'd3: O_hdmi_data <= 24'hff0000; // red: D-PHY lane error
                        4'd4: O_hdmi_data <= 24'hff00ff; // magenta: RAW10 line length error
                        4'd5: O_hdmi_data <= 24'hffff00; // yellow: not 720 lines per frame
                        4'd6: O_hdmi_data <= 24'h00ff00; // green: MIPI frame structure passed
                        4'd7: O_hdmi_data <= 24'hff8000; // orange: sensor I2C transaction error
                        default: O_hdmi_data <= 24'hffffff;
                    endcase
                end
                else begin
                    O_hdmi_data <= 24'd0;
                end
            end
            else begin
                O_hdmi_data <= S_display_active ? {gainq(I_video_rd_data[23:16], I_gain), gainq(I_video_rd_data[15:8], I_gain), gainq(I_video_rd_data[7:0], I_gain)} : 24'd0;
            end
        end
    end

endmodule























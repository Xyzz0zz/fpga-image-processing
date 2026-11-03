`timescale 1ns/1ps

module axis_2x_decimate_rgb96 (
    input  wire        I_clk,
    input  wire        I_rst_n,
    input  wire        I_tuser,
    input  wire        I_tlast,
    input  wire        I_tvalid,
    input  wire [95:0] I_tdata,

    output reg         O_tuser,
    output reg         O_tlast,
    output reg         O_tvalid,
    output reg  [95:0] O_tdata
);

    function [23:0] avg24;
        input [23:0] a;
        input [23:0] b;
        reg [8:0] sr;
        reg [8:0] sg;
        reg [8:0] sb;
        begin
            sr = {1'b0, a[23:16]} + {1'b0, b[23:16]} + 9'd1;
            sg = {1'b0, a[15:8]}  + {1'b0, b[15:8]}  + 9'd1;
            sb = {1'b0, a[7:0]}   + {1'b0, b[7:0]}   + 9'd1;
            avg24 = {sr[8:1], sg[8:1], sb[8:1]};
        end
    endfunction

    reg [95:0] S_line_buf [0:239];
    reg        S_row_phase;
    reg        S_pair_phase;
    reg [95:0] S_first_beat;
    reg [8:0]  S_out_x;
    reg        S_frame_start_pending;

    wire [23:0] S_curr_p0 = I_tdata[23:0];
    wire [23:0] S_curr_p1 = I_tdata[47:24];
    wire [23:0] S_curr_p2 = I_tdata[71:48];
    wire [23:0] S_curr_p3 = I_tdata[95:72];

    wire [23:0] S_first_p0 = S_first_beat[23:0];
    wire [23:0] S_first_p1 = S_first_beat[47:24];
    wire [23:0] S_first_p2 = S_first_beat[71:48];
    wire [23:0] S_first_p3 = S_first_beat[95:72];

    wire [95:0] S_current_pair = {
        avg24(S_curr_p2, S_curr_p3),
        avg24(S_curr_p0, S_curr_p1),
        avg24(S_first_p2, S_first_p3),
        avg24(S_first_p0, S_first_p1)
    };

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_row_phase           <= 1'b0;
            S_pair_phase          <= 1'b0;
            S_first_beat          <= 96'd0;
            S_out_x               <= 9'd0;
            S_frame_start_pending <= 1'b0;
            O_tuser               <= 1'b0;
            O_tlast               <= 1'b0;
            O_tvalid              <= 1'b0;
            O_tdata               <= 96'd0;
        end
        else begin
            O_tuser  <= 1'b0;
            O_tlast  <= 1'b0;
            O_tvalid <= 1'b0;

            if(I_tuser) begin
                S_frame_start_pending <= 1'b1;
                S_row_phase           <= 1'b0;
                S_pair_phase          <= 1'b0;
                S_out_x               <= 9'd0;
            end

            if(I_tvalid) begin
                if(!S_pair_phase) begin
                    S_first_beat <= I_tdata;
                    S_pair_phase <= 1'b1;
                end
                else begin
                    if(!S_row_phase) begin
                        S_line_buf[S_out_x] <= S_current_pair;
                    end
                    else begin
                        O_tdata <= {
                            avg24(S_line_buf[S_out_x][95:72], S_current_pair[95:72]),
                            avg24(S_line_buf[S_out_x][71:48], S_current_pair[71:48]),
                            avg24(S_line_buf[S_out_x][47:24], S_current_pair[47:24]),
                            avg24(S_line_buf[S_out_x][23:0],  S_current_pair[23:0])
                        };
                        O_tvalid <= 1'b1;
                        O_tuser  <= S_frame_start_pending;
                        O_tlast  <= I_tlast && (S_out_x == 9'd239);
                        S_frame_start_pending <= 1'b0;
                    end
                    S_out_x      <= (S_out_x == 9'd239) ? 9'd0 : S_out_x + 1'b1;
                    S_pair_phase <= 1'b0;
                end
            end

            if(I_tlast) begin
                S_row_phase  <= ~S_row_phase;
                S_pair_phase <= 1'b0;
                S_out_x      <= 9'd0;
            end
        end
    end

endmodule

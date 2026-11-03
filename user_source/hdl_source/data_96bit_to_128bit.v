`timescale 1ns/1ps

module data_96bit_to_128bit (
    input  wire         I_clk,
    input  wire         I_rst_n,
    input  wire         I_96b_frame_start,
    input  wire         I_96b_last,
    input  wire         I_96b_valid,
    input  wire [95:0]  I_96b_data,

    output reg          O_128b_frame_start,
    output reg          O_128b_last,
    output reg          O_128b_valid,
    output reg [127:0]  O_128b_data
);

    reg [95:0] S_prev_data;
    reg [1:0]  S_cnt;
    reg        S_frame_start_pending;

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_prev_data         <= 96'd0;
            S_cnt               <= 2'd0;
            S_frame_start_pending <= 1'b0;
            O_128b_frame_start  <= 1'b0;
            O_128b_last         <= 1'b0;
            O_128b_valid        <= 1'b0;
            O_128b_data         <= 128'd0;
        end
        else begin
            O_128b_frame_start <= 1'b0;
            O_128b_last        <= 1'b0;
            O_128b_valid       <= 1'b0;

            if(I_96b_frame_start) begin
                S_cnt                 <= 2'd0;
                S_frame_start_pending <= 1'b1;
            end

            if(I_96b_valid) begin
                S_prev_data <= I_96b_data;
                case(S_cnt)
                    2'd0: begin
                        S_cnt <= 2'd1;
                    end
                    2'd1: begin
                        O_128b_data        <= {S_prev_data, I_96b_data[95:64]};
                        O_128b_valid       <= 1'b1;
                        O_128b_frame_start <= S_frame_start_pending;
                        S_frame_start_pending <= 1'b0;
                        S_cnt              <= 2'd2;
                    end
                    2'd2: begin
                        O_128b_data  <= {S_prev_data[63:0], I_96b_data[95:32]};
                        O_128b_valid <= 1'b1;
                        S_cnt        <= 2'd3;
                    end
                    default: begin
                        O_128b_data  <= {S_prev_data[31:0], I_96b_data};
                        O_128b_valid <= 1'b1;
                        O_128b_last  <= I_96b_last;
                        S_cnt        <= 2'd0;
                    end
                endcase
            end
        end
    end

endmodule

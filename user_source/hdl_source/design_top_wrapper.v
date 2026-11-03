

module design_top_wrapper (
    input wire        I_sys_clk,
    input wire        I_rst_n,
      
    output wire       O_cam_scl,
    inout  wire       IO_cam_sda,
    output wire       O_cam_24m,
    output wire       O_cam_rst,
      
    inout wire [1:0]  I_button,

    output wire       O_screen_pwm,
    // patch_v2: on-board LED1..LED4 (active high): left, centre, right, target found (mode 4 only)
    output wire [3:0] O_led,
    output wire       O_tmds_ch0_p,
    output wire       O_tmds_ch1_p,
    output wire       O_tmds_ch2_p,
    output wire       O_tmds_clk_p,

    inout wire        IO_rx_clk_pad_n, 
    inout wire        IO_rx_clk_pad_p, 
    inout wire[3:0]   IO_rx_data_pad_n,
    inout wire[3:0]   IO_rx_data_pad_p,

    output wire[12:0] ddr_addr,
    output wire[ 1:0] ddr_ba,
    output wire[ 0:0] ddr_cke,
    output wire[ 0:0] ddr_odt,
    output wire[ 0:0] ddr_cs_n,
    output wire       ddr_ras_n,
    output wire       ddr_cas_n,
    output wire       ddr_we_n,
    output wire[ 0:0] ddr_ck_p,
    output wire[ 0:0] ddr_ck_n,
    inout wire[1:0]   ddr_dm,
    inout wire[15:0]  ddr_dq,
    inout wire[1:0]   ddr_dqs_p,
    inout wire[1:0]   ddr_dqs_n   
);


    wire        	S_100m_clk;
    wire        	S_24m_clk;
    wire        	S_aux_50m_clk;
	wire        	S_10m_clk;
		
	wire        	S_pll_lock;
    wire        	S_rst_n;
	reg  [17:0] 	S_cam_power_cnt;
	reg         	S_cam_pwdnb;
	reg         	S_cam_i2c_ready;
	(* keep = "true" *) wire [15:0] S_cam_sensor_id;
	(* keep = "true" *) wire        S_cam_sensor_id_ok;
	(* keep = "true" *) wire        S_cam_i2c_error;
	localparam integer CAM_PWDNB_LOW_CYCLES = 23810;  // >= 1 ms at 23.809524 MHz
	localparam integer CAM_I2C_START_CYCLES = 142857; // release + >= 5 ms
	
	wire [15:0] 	S_ae;
    wire [15:0] 	S_ag;
    wire 			S_cam_cfg_done;
    wire 			S_ae_cfg_done;
    wire 			S_ae_req; 
	
	wire        	S_csi_rx_clk;  
    wire        	S_hs_rx_valid;  
    wire[15:0]  	S_hs_rx_data;   
	wire[1:0]   	S_lane_error;
	
	wire        	S_csi_frame_start;       
	wire        	S_csi_frame_end;         
	wire        	S_csi_valid;             
	wire[31:0]  	S_csi_data;  
	(* keep = "true" *) wire [15:0] S_csi_data_length;
		
	wire        	S_raw10_frame_start; 
	wire        	S_raw10_frame_end;   
	wire        	S_raw10_valid;       
	wire [39:0] 	S_raw10_data;

	wire 			S_axis_tlast;  
	wire 			S_axis_tuser;  
	wire [39:0]		S_axis_tdata;  
	wire 			S_axis_tvalid; 
	
	wire [39:0]		S_raw_tdata ;
	wire			S_raw_tlast ;
	wire 			S_raw_tvalid;
	wire 			S_raw_tuser ;
	
	wire			S_ISP_O_tready;
	wire [127:0]	S_ISP_O_tdata ;
	wire 			S_ISP_O_tlast ;
	wire 			S_ISP_O_tuser ;
	wire 			S_ISP_O_tvalid; 
	

    wire        S_ddr_clk;
    wire        S_hdmi_pixel_clk;
    wire        S_hdmi_serial_clk;
    wire        S_hdmi_rst_n;
    wire        S_video_out_rst_n;


    wire        S_vi_128b_frame_start;
    wire        S_vi_128b_valid;      
    wire[127:0] S_vi_128b_data;    
    
    wire        S_video_out_rd_busy;
    wire        S_video_in_wr_busy; 
    wire[1:0]   S_video_out_rp;     

    wire        S_ddr_user_wr_en;       
    wire        S_ddr_user_rd_en;       
    wire[24:0]  S_ddr_user_addr;        
    wire[127:0] S_ddr_user_wr_data;     
    wire        S_ddr_user_ready;       
    wire        S_ddr_user_rd_valid;    
    wire[127:0] S_ddr_user_rd_data;     

    wire        S_vi_ddr_wr_en;   
    wire[24:0]  S_vi_ddr_wr_addr; 
    wire[127:0] S_vi_ddr_wr_data;
    wire        S_vi_ddr_wr_ready;

    wire        S_vo_ddr_rd_en;   
    wire[24:0]  S_vo_ddr_rd_addr; 
    wire        S_vo_ddr_rd_ready;
    wire        S_vo_dbg_fifo_rst;
    wire        S_vo_dbg_ddr_rd_valid;
    wire        S_vo_dbg_fifo_rd_en;
    wire        S_vo_dbg_fifo_empty;

    wire        S_init_calib_complete; 
    wire[24:0]  S_mc_app_addr;          
    wire[2:0]   S_mc_app_cmd;           
    wire        S_mc_app_en;            
    wire[127:0] S_mc_app_wdf_data;      
    wire        S_mc_app_wdf_end;       
    wire[15:0]  S_mc_app_wdf_mask;      
    wire        S_mc_app_wdf_wren;      
    wire[127:0] S_mc_app_rd_data;       
    wire        S_mc_app_rd_data_end;   
    wire        S_mc_app_rd_data_valid; 
    wire        S_mc_app_rdy;           
    wire        S_mc_app_wdf_rdy;       
    wire        S_mc_dbg_fifo_afull;
    wire        S_mc_dbg_app_rdy;
    wire        S_mc_dbg_wdf_rdy;
    wire        S_mc_dbg_cmd_pop;

    wire        S_hdmi_vsync;
    wire        S_hdmi_hsync;
    wire        S_hdmi_de;
    wire        S_hdmi_user;
    wire        S_hdmi_last;
    wire        S_video_out_vsync;
    wire        S_hdmi_window_rd_en;
    wire        S_hdmi_out_vsync;
    wire        S_hdmi_out_hsync;
    wire        S_hdmi_out_de;
    wire[23:0]  S_hdmi_out_data;
    wire        S_sobel_vsync;
    wire        S_sobel_hsync;
    wire        S_sobel_de;
    wire[23:0]  S_sobel_data;
    wire [13:0] S_sobel_x;
    wire [13:0] S_sobel_y;
    wire        S_hdmi_proc_vsync;
    wire        S_hdmi_proc_hsync;
    wire        S_hdmi_proc_de;
    wire[23:0]  S_hdmi_proc_data;
    wire        S_edge_flag;
    wire        S_fill_edge;
    wire [10:0] S_mag;
    wire        S_mag_v;
    wire [13:0] S_foc_score;
    wire [6:0]  S_foc_bar;
    wire        S_foc_upd;
    wire [2:0]  S_vision_mode;
    wire [2:0]  S_pre_vision_mode;
    wire        S_region_fill_mode;
    wire [13:0] S_proc_x;
    wire [13:0] S_proc_y;
    wire        S_osd_vsync;
    wire        S_osd_hsync;
    wire        S_osd_de;
    wire [23:0] S_osd_data;

    wire[23:0]  S_video_rd_data;
    reg         S_dbg_raw_seen;
    reg         S_dbg_isp_seen;
    reg         S_dbg_ddr_wr_seen;
    reg         S_dbg_ddr_rd_seen;
    reg         S_dbg_cam_cfg_seen;
    reg         S_dbg_hs_seen;
    reg         S_dbg_csi_seen;
    reg         S_dbg_raw10_seen;
    reg         S_dbg_isp_fs_seen;
    reg         S_dbg_isp_valid_seen;
    reg         S_dbg_ddr_req_seen;
    reg         S_dbg_ddr_ready_seen;
    reg [1:0]   S_dbg_raw_seen_sync;
    reg [1:0]   S_dbg_isp_seen_sync;
    reg [1:0]   S_dbg_ddr_wr_seen_sync;
    reg [1:0]   S_dbg_ddr_rd_seen_sync;
    reg [1:0]   S_dbg_cam_cfg_seen_sync;
    reg [1:0]   S_dbg_hs_seen_sync;
    reg [1:0]   S_dbg_csi_seen_sync;
    reg [1:0]   S_dbg_raw10_seen_sync;
    reg [1:0]   S_dbg_isp_fs_seen_sync;
    reg [1:0]   S_dbg_isp_valid_seen_sync;
    reg [1:0]   S_dbg_ddr_req_seen_sync;
    reg [1:0]   S_dbg_ddr_ready_seen_sync;
    reg         S_dbg_video_nonzero_seen;
    reg         S_dbg_rd_req_seen;
    reg         S_dbg_rd_valid_seen;
    reg         S_dbg_rd_nonzero_seen;
    reg [1:0]   S_dbg_rd_req_seen_sync;
    reg [1:0]   S_dbg_rd_valid_seen_sync;
    reg [1:0]   S_dbg_rd_nonzero_seen_sync;
    reg         S_dbg_mc_init_seen;
    reg         S_dbg_mc_app_rdy_seen;
    reg         S_dbg_mc_wdf_rdy_seen;
    reg         S_dbg_mc_cmd_pop_seen;
    reg [1:0]   S_dbg_mc_init_seen_sync;
    reg [1:0]   S_dbg_mc_app_rdy_seen_sync;
    reg [1:0]   S_dbg_mc_wdf_rdy_seen_sync;
    reg [1:0]   S_dbg_mc_cmd_pop_seen_sync;
    wire[3:0]   S_hdmi_debug_status;
    wire        S_lane_error_any;
    wire        S_csi_packet_start;
    reg         S_csi_length_active_d;
    reg [10:0]  S_mipi_line_count;
    reg         S_mipi_length_error;
    reg         S_mipi_lane_error;
    reg         S_mipi_frame_seen;
    reg         S_mipi_frame_done;
    reg         S_mipi_last_length_error;
    reg         S_mipi_last_line_error;
    reg         S_mipi_last_lane_error;
    wire[3:0]   S_mipi_diag_status_async;
    reg [3:0]   S_mipi_diag_status_sync1;
    reg [3:0]   S_mipi_diag_status_sync2;

    // patch_v2: optional bad-frame drop.  Set to 1 only after DEBUG_MODE=4 shows a green screen
    // (MIPI frame structure OK), otherwise every frame could be flagged as bad.
    localparam ENABLE_BAD_FRAME_DROP = 0;
    reg  [1:0]  S_bad_frame_sync;
    wire        S_bad_frame_async;
    wire        S_bad_frame_ddr;
    wire        S_hdmi_out_win;
    wire [1:0]  S_target_color;
    wire        S_tgt_found;
    wire [10:0] S_tgt_x0;
    wire [10:0] S_tgt_x1;
    wire [9:0]  S_tgt_y0;
    wire [9:0]  S_tgt_y1;
    wire [10:0] S_tgt_cx;
    wire [9:0]  S_tgt_cy;
    (* keep = "true" *) wire [1:0]  S_tgt_dir;   // 0 none, 1 left, 2 right, 3 centre (for an external controller)
    wire        S_tgt_upd;
    wire        S_ovl_vsync;
    // patch_v2: read-pointer offset (3 = newest complete frame, 2 = original behaviour) and latency meter
    localparam integer VIDEO_READ_OFFSET = 3;
    reg         S_cam_tuser_d;
    reg         S_cam_start_tog;
    wire [9:0]  S_lat_ms;
    wire [7:0]  S_st_r0, S_st_g0, S_st_b0, S_st_r1, S_st_g1, S_st_b1;
    wire        S_st_upd;
    wire [7:0]  S_agc_gain;
    wire        S_lat_upd;
    wire        S_ovl_hsync;
    wire        S_ovl_de;
    wire [23:0] S_ovl_data;


    assign O_screen_pwm = 1'b1;
    assign S_video_out_vsync = ~S_hdmi_vsync;
    // patch_v2: BTN0 = next mode (0->1->2->3->4->0), BTN1 = back to original image;
    // in mode 4 (target tracking) BTN1 cycles the target colour instead.
    // Debounced, synchronised to the pixel clock and latched at vsync.
    wire S_he_flag;
    wire S_split_flag;
    vision_mode_ctrl u_vision_mode_ctrl (
        .clk      ( S_hdmi_pixel_clk ),
        .rst_n    ( S_hdmi_rst_n     ),
        .I_button ( I_button         ),
        .in_vs    ( S_hdmi_out_vsync ),
        .mode     ( S_vision_mode    ),
        .color_sel( S_target_color   ),
        .he_flag  ( S_he_flag        ),
        .split_flag( S_split_flag    )
    );
    wire S_he_apply = S_he_flag && (S_vision_mode == 3'd0);
    assign S_region_fill_mode = (S_vision_mode == 3'd3);
    // ---- v21 diagnostics (shown on the LEDs, ~0.7 s windows) ----
    wire S_dbg_ovf;   // camera clock domain
    wire S_dbg_unf;   // pixel clock domain
    reg [26:0] S_dbg_cnt_c;
    reg        S_dbg_ovf_acc;
    reg        S_dbg_ovf_led;
    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n) begin
            S_dbg_cnt_c <= 27'd0; S_dbg_ovf_acc <= 1'b0; S_dbg_ovf_led <= 1'b0;
        end else begin
            S_dbg_cnt_c <= S_dbg_cnt_c + 27'd1;
            if(S_dbg_ovf) S_dbg_ovf_acc <= 1'b1;
            if(S_dbg_cnt_c == 27'd0) begin
                S_dbg_ovf_led <= S_dbg_ovf_acc;
                S_dbg_ovf_acc <= 1'b0;
            end
        end
    end
    reg [26:0] S_dbg_cnt_p;
    reg        S_dbg_unf_acc;
    reg        S_dbg_unf_led;
    always @(posedge S_hdmi_pixel_clk or negedge S_hdmi_rst_n) begin
        if(!S_hdmi_rst_n) begin
            S_dbg_cnt_p <= 27'd0; S_dbg_unf_acc <= 1'b0; S_dbg_unf_led <= 1'b0;
        end else begin
            S_dbg_cnt_p <= S_dbg_cnt_p + 27'd1;
            if(S_dbg_unf) S_dbg_unf_acc <= 1'b1;
            if(S_dbg_cnt_p == 27'd0) begin
                S_dbg_unf_led <= S_dbg_unf_acc;
                S_dbg_unf_acc <= 1'b0;
            end
        end
    end
    reg        S_dbg_mis_acc;
    reg        S_dbg_mis_led;
    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n) begin
            S_dbg_mis_acc <= 1'b0; S_dbg_mis_led <= 1'b0;
        end else begin
            if(S_dbg_mis) S_dbg_mis_acc <= 1'b1;
            if(S_dbg_cnt_c == 27'd0) begin
                S_dbg_mis_led <= S_dbg_mis_acc;
                S_dbg_mis_acc <= 1'b0;
            end
        end
    end
    // LED[2] C6: 96->128 bit packer was out of phase at a frame start (bug condition seen; now corrected in hardware)
    // LED[0] D10: write FIFO overflow seen, LED[1] E10: read FIFO underflow seen, LED[3] D6: DDR calibrated
    // v30: in colour-tracking mode the LEDs show the target position (found, right, centre, left);
    // in the other modes they are the diagnostics (DDR2 calibrated, packer misalignment, read underflow, write overflow)
    assign O_led = (S_vision_mode == 3'd4) ?
                   {S_tgt_found, (S_tgt_dir == 2'd2), (S_tgt_dir == 2'd3), (S_tgt_dir == 2'd1)} :
                   {S_init_calib_complete, S_dbg_mis_led, S_dbg_unf_led, S_dbg_ovf_led};
    // modes 3 (region fill) and 4 (target tracking) use the original image in the gray/Sobel stage;
    // modes 5 (binarize) and 6 (invert) are produced inside video_gray_sobel
    assign S_pre_vision_mode = (S_region_fill_mode || S_vision_mode == 3'd4 || S_vision_mode == 3'd7) ? 3'd0 : S_vision_mode;
	
	
    assign S_rst_n 		= S_pll_lock;
    assign S_hdmi_rst_n = S_pll_lock;

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_raw_seen <= 1'b0;
        else if(S_raw10_frame_start | S_axis_tvalid)
            S_dbg_raw_seen <= 1'b1;
    end

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_isp_seen <= 1'b0;
        else if(S_ISP_O_tuser | S_ISP_O_tvalid)
            S_dbg_isp_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_ddr_wr_seen <= 1'b0;
        else if(S_vi_ddr_wr_en)
            S_dbg_ddr_wr_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_ddr_rd_seen <= 1'b0;
        else if(S_ddr_user_rd_valid)
            S_dbg_ddr_rd_seen <= 1'b1;
    end

    always @(posedge S_24m_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_cam_cfg_seen <= 1'b0;
        else if(S_cam_cfg_done)
            S_dbg_cam_cfg_seen <= 1'b1;
    end

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_hs_seen <= 1'b0;
        else if(S_hs_rx_valid)
            S_dbg_hs_seen <= 1'b1;
    end

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_csi_seen <= 1'b0;
        else if(S_csi_frame_start | S_csi_valid)
            S_dbg_csi_seen <= 1'b1;
    end

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_raw10_seen <= 1'b0;
        else if(S_raw10_frame_start | S_raw10_valid)
            S_dbg_raw10_seen <= 1'b1;
    end

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_isp_fs_seen <= 1'b0;
        else if(S_ISP_O_tuser)
            S_dbg_isp_fs_seen <= 1'b1;
    end

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_isp_valid_seen <= 1'b0;
        else if(S_ISP_O_tvalid)
            S_dbg_isp_valid_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_ddr_req_seen <= 1'b0;
        else if(S_vi_ddr_wr_en)
            S_dbg_ddr_req_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_ddr_ready_seen <= 1'b0;
        else if(S_ddr_user_ready)
            S_dbg_ddr_ready_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_video_out_rst_n) begin
        if(!S_video_out_rst_n)
            S_dbg_rd_req_seen <= 1'b0;
        else if(S_vo_ddr_rd_en)
            S_dbg_rd_req_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_video_out_rst_n) begin
        if(!S_video_out_rst_n)
            S_dbg_rd_valid_seen <= 1'b0;
        else if(S_ddr_user_rd_valid)
            S_dbg_rd_valid_seen <= 1'b1;
    end

    always @(posedge S_hdmi_pixel_clk or negedge S_video_out_rst_n) begin
        if(!S_video_out_rst_n)
            S_dbg_rd_nonzero_seen <= 1'b0;
        else if(S_hdmi_window_rd_en && (S_video_rd_data != 24'd0))
            S_dbg_rd_nonzero_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_mc_init_seen <= 1'b0;
        else if(S_init_calib_complete)
            S_dbg_mc_init_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_mc_app_rdy_seen <= 1'b0;
        else if(S_mc_dbg_app_rdy)
            S_dbg_mc_app_rdy_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_mc_wdf_rdy_seen <= 1'b0;
        else if(S_mc_dbg_wdf_rdy)
            S_dbg_mc_wdf_rdy_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_mc_cmd_pop_seen <= 1'b0;
        else if(S_mc_dbg_cmd_pop)
            S_dbg_mc_cmd_pop_seen <= 1'b1;
    end

    always @(posedge S_hdmi_pixel_clk or negedge S_hdmi_rst_n) begin
        if(!S_hdmi_rst_n) begin
            S_dbg_cam_cfg_seen_sync <= 2'b00;
            S_dbg_hs_seen_sync      <= 2'b00;
            S_dbg_csi_seen_sync     <= 2'b00;
            S_dbg_raw10_seen_sync   <= 2'b00;
            S_dbg_raw_seen_sync    <= 2'b00;
            S_dbg_isp_seen_sync    <= 2'b00;
            S_dbg_ddr_wr_seen_sync <= 2'b00;
            S_dbg_ddr_rd_seen_sync <= 2'b00;
            S_dbg_isp_fs_seen_sync  <= 2'b00;
            S_dbg_isp_valid_seen_sync <= 2'b00;
            S_dbg_ddr_req_seen_sync <= 2'b00;
            S_dbg_ddr_ready_seen_sync <= 2'b00;
            S_dbg_video_nonzero_seen <= 1'b0;
            S_dbg_rd_req_seen_sync <= 2'b00;
            S_dbg_rd_valid_seen_sync <= 2'b00;
            S_dbg_rd_nonzero_seen_sync <= 2'b00;
            S_dbg_mc_init_seen_sync <= 2'b00;
            S_dbg_mc_app_rdy_seen_sync <= 2'b00;
            S_dbg_mc_wdf_rdy_seen_sync <= 2'b00;
            S_dbg_mc_cmd_pop_seen_sync <= 2'b00;
        end
        else begin
            S_dbg_cam_cfg_seen_sync <= {S_dbg_cam_cfg_seen_sync[0], S_dbg_cam_cfg_seen};
            S_dbg_hs_seen_sync      <= {S_dbg_hs_seen_sync[0],      S_dbg_hs_seen};
            S_dbg_csi_seen_sync     <= {S_dbg_csi_seen_sync[0],     S_dbg_csi_seen};
            S_dbg_raw10_seen_sync   <= {S_dbg_raw10_seen_sync[0],   S_dbg_raw10_seen};
            S_dbg_raw_seen_sync    <= {S_dbg_raw_seen_sync[0],    S_dbg_raw_seen};
            S_dbg_isp_seen_sync    <= {S_dbg_isp_seen_sync[0],    S_dbg_isp_seen};
            S_dbg_ddr_wr_seen_sync <= {S_dbg_ddr_wr_seen_sync[0], S_dbg_ddr_wr_seen};
            S_dbg_ddr_rd_seen_sync <= {S_dbg_ddr_rd_seen_sync[0], S_dbg_ddr_rd_seen};
            S_dbg_isp_fs_seen_sync  <= {S_dbg_isp_fs_seen_sync[0],  S_dbg_isp_fs_seen};
            S_dbg_isp_valid_seen_sync <= {S_dbg_isp_valid_seen_sync[0], S_dbg_isp_valid_seen};
            S_dbg_ddr_req_seen_sync <= {S_dbg_ddr_req_seen_sync[0], S_dbg_ddr_req_seen};
            S_dbg_ddr_ready_seen_sync <= {S_dbg_ddr_ready_seen_sync[0], S_dbg_ddr_ready_seen};
            S_dbg_rd_req_seen_sync <= {S_dbg_rd_req_seen_sync[0], S_dbg_rd_req_seen};
            S_dbg_rd_valid_seen_sync <= {S_dbg_rd_valid_seen_sync[0], S_dbg_rd_valid_seen};
            S_dbg_rd_nonzero_seen_sync <= {S_dbg_rd_nonzero_seen_sync[0], S_dbg_rd_nonzero_seen};
            S_dbg_mc_init_seen_sync <= {S_dbg_mc_init_seen_sync[0], S_dbg_mc_init_seen};
            S_dbg_mc_app_rdy_seen_sync <= {S_dbg_mc_app_rdy_seen_sync[0], S_dbg_mc_app_rdy_seen};
            S_dbg_mc_wdf_rdy_seen_sync <= {S_dbg_mc_wdf_rdy_seen_sync[0], S_dbg_mc_wdf_rdy_seen};
            S_dbg_mc_cmd_pop_seen_sync <= {S_dbg_mc_cmd_pop_seen_sync[0], S_dbg_mc_cmd_pop_seen};
            if(S_hdmi_window_rd_en && (S_video_rd_data != 24'd0))
                S_dbg_video_nonzero_seen <= 1'b1;
        end
    end

    assign S_lane_error_any = |S_lane_error;

    assign S_bad_frame_async = S_mipi_last_length_error | S_mipi_last_line_error | S_mipi_last_lane_error;
    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_bad_frame_sync <= 2'b00;
        else
            S_bad_frame_sync <= {S_bad_frame_sync[0], S_bad_frame_async};
    end
    assign S_bad_frame_ddr = (ENABLE_BAD_FRAME_DROP != 0) ? S_bad_frame_sync[1] : 1'b0;

    // A RAW10 line contains 1920 * 10 / 8 = 2400 bytes.  The CSI parser
    // reports the number of 16-bit lane words, therefore the expected value
    // is 2400 / 2 = 1200 = 16'h04b0.  Count one long packet whenever that
    // decoded length changes from zero to non-zero.
    assign S_csi_packet_start = (S_csi_data_length != 16'd0) &&
                                !S_csi_length_active_d;

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n) begin
            S_csi_length_active_d      <= 1'b0;
            S_mipi_line_count          <= 11'd0;
            S_mipi_length_error        <= 1'b0;
            S_mipi_lane_error          <= 1'b0;
            S_mipi_frame_seen          <= 1'b0;
            S_mipi_frame_done          <= 1'b0;
            S_mipi_last_length_error   <= 1'b0;
            S_mipi_last_line_error     <= 1'b0;
            S_mipi_last_lane_error     <= 1'b0;
        end
        else begin
            S_csi_length_active_d <= (S_csi_data_length != 16'd0);

            if(S_csi_frame_start) begin
                S_mipi_line_count   <= 11'd0;
                S_mipi_length_error <= 1'b0;
                S_mipi_lane_error   <= 1'b0;
                S_mipi_frame_seen   <= 1'b1;
            end
            else begin
                if(S_csi_packet_start) begin
                    S_mipi_line_count <= S_mipi_line_count + 11'd1;
                    if(S_csi_data_length != 16'h04b0)
                        S_mipi_length_error <= 1'b1;
                end

                if(S_lane_error_any)
                    S_mipi_lane_error <= 1'b1;
            end

            // Publish only a completed frame, so the HDMI-domain diagnostic
            // sees a stable result rather than counters changing every line.
            if(S_csi_frame_end) begin
                S_mipi_frame_done        <= 1'b1;
                S_mipi_last_length_error <= S_mipi_length_error;
                S_mipi_last_line_error   <= (S_mipi_line_count != 11'd1080);
                S_mipi_last_lane_error   <= S_mipi_lane_error |
                                            S_lane_error_any;
            end
        end
    end

    // Diagnostic result codes consumed by hdmi_mixer DEBUG_MODE=4:
    // 0=config incomplete, 1=no HS traffic, 2=no completed CSI frame,
    // 3=lane error, 4=wrong RAW10 line length, 5=wrong lines/frame,
    // 6=the observed MIPI frame structure is correct, 7=I2C error.
    // I2C error has the highest priority because O_cfg_done only indicates
    // that the write sequencer reached its end; it does not prove that every
    // sensor register write was acknowledged successfully.
    assign S_mipi_diag_status_async =
        S_cam_i2c_error              ? 4'd7 :
        !S_cam_cfg_done              ? 4'd0 :
        !S_dbg_hs_seen               ? 4'd1 :
        !(S_mipi_frame_seen &&
          S_mipi_frame_done)         ? 4'd2 :
        S_mipi_last_lane_error       ? 4'd3 :
        S_mipi_last_length_error     ? 4'd4 :
        S_mipi_last_line_error       ? 4'd5 : 4'd6;

    always @(posedge S_hdmi_pixel_clk or negedge S_hdmi_rst_n) begin
        if(!S_hdmi_rst_n) begin
            S_mipi_diag_status_sync1 <= 4'd0;
            S_mipi_diag_status_sync2 <= 4'd0;
        end
        else begin
            S_mipi_diag_status_sync1 <= S_mipi_diag_status_async;
            S_mipi_diag_status_sync2 <= S_mipi_diag_status_sync1;
        end
    end

    assign S_vo_dbg_fifo_rst = 1'b0;
    assign S_vo_dbg_ddr_rd_valid = 1'b0;
    assign S_vo_dbg_fifo_rd_en = 1'b0;
    assign S_vo_dbg_fifo_empty = 1'b0;
    assign S_mc_dbg_fifo_afull = 1'b0;
    assign S_mc_dbg_app_rdy = 1'b0;
    assign S_mc_dbg_wdf_rdy = 1'b0;
    assign S_mc_dbg_cmd_pop = 1'b0;

    assign S_hdmi_debug_status =
        !S_dbg_mc_init_seen_sync[1]   ? 4'd0 :
        !S_dbg_rd_req_seen_sync[1]    ? 4'd1 :
        !S_dbg_ddr_ready_seen_sync[1] ? 4'd2 :
        !S_dbg_rd_valid_seen_sync[1]  ? 4'd3 :
        !S_dbg_video_nonzero_seen     ? 4'd4 :
                                       4'd5;
	
	// J9 pin 37 is connected to the module's PWDNB/XSHUTDN input.
	// Hold the sensor in power-down after PLL lock, then allow its internal
	// power-up sequence to finish before the first I2C transaction.
	always @(posedge S_24m_clk or negedge S_pll_lock) begin
		if (!S_pll_lock) begin
			S_cam_power_cnt <= 18'd0;
			S_cam_pwdnb <= 1'b0;
			S_cam_i2c_ready <= 1'b0;
		end else begin
			if (S_cam_power_cnt < CAM_I2C_START_CYCLES)
				S_cam_power_cnt <= S_cam_power_cnt + 1'b1;
			if (S_cam_power_cnt >= CAM_PWDNB_LOW_CYCLES)
				S_cam_pwdnb <= 1'b1;
			if (S_cam_power_cnt >= CAM_I2C_START_CYCLES - 1)
				S_cam_i2c_ready <= 1'b1;
		end
	end

	assign O_cam_rst 	= S_cam_pwdnb;
    assign O_cam_24m 	= S_24m_clk;
	
	
	
	
    PLL u_PLL(
        .refclk      ( I_sys_clk         ),
        .reset    	 ( ~I_rst_n          ),
        
        .clk0_out    ( S_100m_clk        ),
        .clk1_out    ( S_24m_clk         ),

        .clk4_out    ( S_hdmi_pixel_clk  ),
        .clk5_out    ( S_hdmi_serial_clk ),

        .lock        ( S_pll_lock        )

    );


	

  
  ae_set u_ae_set (
      .I_clk(S_24m_clk),
      .I_rst(~S_rst_n),
      .I_btn(4'b1111),   // patch_v2: mode buttons no longer change sensor gain
      .I_cam_cfg_done(S_cam_cfg_done),
      .I_ae_cfg_done(S_ae_cfg_done),
      .O_ae_req(S_ae_req),
      .O_ae(S_ae),
      .O_ag(S_ag)
  );
  
    uicfgcs500 #(
      .CLK_DIV(23809524 / 100000 - 1)
  ) u_uicfgcs500 (
      .I_clk(S_24m_clk),
      .I_rst_n(S_cam_i2c_ready),
      .I_ae_req(S_ae_req),
      .I_ae(S_ae),
      .I_ag(S_ag),
      .O_cam_scl(O_cam_scl),
      .IO_cam_sda(IO_cam_sda),
      .O_cfg_done(S_cam_cfg_done),
      .O_ae_cfg_done(S_ae_cfg_done)
  );

  assign S_cam_sensor_id    = 16'h0000;
  assign S_cam_sensor_id_ok = 1'b0;
  assign S_cam_i2c_error    = 1'b0;
	
    mipi_dphy_rx_ph1p_mipiio_wrapper#(
        .DPHY_RX_LOCATION      ( "DPHY0" ),
        .HS_EQUALIZER          ( "3dB"   ),// 828 Mbps/Lane????
        .HS_VGA_GAIN           ( "8dB" ),//"-3dB","-1.5dB","0dB","1.5dB","3dB","4.5dB","6dB","7.5dB"
        .LANE_NUM              ( 2       ),
        .BYTE_NUM              ( 1       )
    )u_mipi_dphy_rx_ph1p_mipiio_wrapper(
        .I_lp_clk              ( S_100m_clk       ),
        .I_rst                 ( ~S_rst_n         ),

        .I_clk_lane_in_delay   ( 6'd0             ),
        .I_data_lane0_in_delay ( 6'd0             ),
        .I_data_lane1_in_delay ( 6'd0             ),
        .I_data_lane2_in_delay ( 6'd0             ),
        .I_data_lane3_in_delay ( 6'd0             ),

        .I_lane_invert         ( 4'b0000          ),
     
        .O_hs_rx_clk           ( S_csi_rx_clk     ),
        .O_hs_rx_valid         ( S_hs_rx_valid    ),
        .O_hs_rx_data          ( S_hs_rx_data     ),
      
        .O_lp_rx_lane0_p       (  ),
        .O_lp_rx_lane0_n       (  ),
      
        .I_lp_tx_en            ( 1'b0             ),
        .I_lp_tx_lane0_p       ( 1'b1             ),
        .I_lp_tx_lane0_n       ( 1'b1             ),
      
        .O_lane_match_error    (                  ),
        .O_lane_error          ( S_lane_error     ),
      
        .IO_rx_clk_pad_n       ( IO_rx_clk_pad_n  ),
        .IO_rx_clk_pad_p       ( IO_rx_clk_pad_p  ),
        .IO_rx_data_pad_n      ( IO_rx_data_pad_n ),
        .IO_rx_data_pad_p      ( IO_rx_data_pad_p )
    );
	
	
 //  cwc cwc_inst
 //(
 //    .probe0(S_hs_rx_valid),
 //    .probe1(S_hs_rx_data),
 //    .probe2(S_lane_error),
 //    .clk(S_csi_rx_clk)
 //);

 //csi ???RAW??
csi_unpacket_2lane u_csi_unpacket(
.I_clk                 ( S_csi_rx_clk       ),
.I_rst_n               ( S_rst_n        	),
.I_hs_valid            ( S_hs_rx_valid     ),
.I_hs_data             ( S_hs_rx_data      ),

.O_csi_frame_start     ( S_csi_frame_start ),
.O_csi_frame_end       ( S_csi_frame_end   ),
.O_csi_valid           ( S_csi_valid       ),
.O_csi_data            ( S_csi_data        ),
.O_data_length         ( S_csi_data_length )
);


//???RAW8
raw10_unpacket_2lane u_raw10_unpacket (
.I_clk  (S_csi_rx_clk),
.I_rst_n(S_rst_n),

.I_csi_frame_start(S_csi_frame_start),
.I_csi_frame_end  (S_csi_frame_end),
.I_csi_valid      (S_csi_valid),
.I_csi_data       (S_csi_data),

.O_raw10_frame_start(S_raw10_frame_start),
.O_raw10_frame_end  (S_raw10_frame_end),
.O_raw10_valid      (S_raw10_valid),
.O_raw10_data       (S_raw10_data)
  );


//?????stream?
uial2axis #(
.IMG_WIDTH(1920),
.IMG_HEIGHT(1080),
.INPUT_DATA_WIDTH(40)
) 
u_uial2axis (
.I_native_clk(S_csi_rx_clk),
.I_rst_n     (S_rst_n),
.I_data      (S_raw10_data       ),
.I_data_valid(S_raw10_valid      ),
.I_data_start(S_raw10_frame_start),
.I_data_end  (S_raw10_frame_end  ),
.axis_tvalid (S_axis_tvalid),
.axis_tdata  (S_axis_tdata ),
.axis_tuser  (S_axis_tuser ),
.axis_tlast  (S_axis_tlast )
);
	

// SC520CS??HD????????1280x720 RAW10???FPGA?????
assign S_raw_tdata  = S_axis_tdata;
assign S_raw_tlast  = S_axis_tlast;
assign S_raw_tvalid = S_axis_tvalid;
assign S_raw_tuser  = S_axis_tuser;


//cwc1 cwc1_Inst
//  (
//      .probe0(S_axis_tuser),
//      .probe1(S_axis_tvalid),
//      .probe2(S_axis_tlast),
//      .probe3(S_axis_tdata),
//      .probe4(S_ISP_O_tuser),
//      .probe5(S_ISP_O_tvalid),
//      .probe6(S_ISP_O_tlast),
//      .probe7(S_ISP_O_tdata),
//      .probe8 (S_raw_tdata ),
//      .probe9 (S_raw_tlast ),
//      .probe10(S_raw_tvalid),
//      .probe11(S_raw_tuser ),
//      .clk(S_csi_rx_clk)
//  );


//ISP??????
wire S_dbg_mis;
isp_top u_isp_top (
.axi4s_video_aclk(S_csi_rx_clk),
.I_rst_n         (S_rst_n),
.I_tlast         (S_raw_tlast	),
.I_tuser         (S_raw_tuser	),
.I_tdata         (S_raw_tdata	),
.I_tvalid        (S_raw_tvalid	),
.I_tdest         (),
.O_tready        (S_ISP_O_tready),
.I_awb_lock      (S_vision_mode == 3'd4),
.O_dbg_misalign  (S_dbg_mis),
.O_tdata         (S_ISP_O_tdata ),
.O_tlast         (S_ISP_O_tlast ),
.O_tuser         (S_ISP_O_tuser ),
.O_tvalid        (S_ISP_O_tvalid),
.I_tready        ()
  );


    video_in #(.READ_OFFSET(VIDEO_READ_OFFSET)) u_video_in(
        .I_rst_n              (  S_rst_n             ),

        .I_camera_clk         ( S_csi_rx_clk          ),
        .O_dbg_ovf            ( S_dbg_ovf             ),
        .I_camera_frame_start ( S_ISP_O_tuser  ),
        .I_camera_valid       ( S_ISP_O_tvalid ),
        .I_camera_data        ( S_ISP_O_tdata  ),
        .I_mipi_rx_error      ( S_bad_frame_ddr ),

        .I_ddr_clk            ( S_ddr_clk             ),
		.I_display_pause      ( 1'b0                  ),
        .I_video_out_rd_busy  ( S_video_out_rd_busy   ),
        .O_video_in_wr_busy   ( S_video_in_wr_busy    ),
        .O_video_out_rp       ( S_video_out_rp        ),

        .O_ddr_user_wr_en     ( S_vi_ddr_wr_en        ),
        .O_ddr_user_addr      ( S_vi_ddr_wr_addr      ),
        .O_ddr_user_wr_data   ( S_vi_ddr_wr_data      ),
        .I_ddr_user_ready     ( S_ddr_user_ready && !S_vo_ddr_rd_en )
    );



    assign S_ddr_user_wr_en    = S_vi_ddr_wr_en && !S_vo_ddr_rd_en;

    assign S_ddr_user_rd_en    = S_vo_ddr_rd_en;

    assign S_ddr_user_addr     = S_vo_ddr_rd_en ? S_vo_ddr_rd_addr :
                                 S_vi_ddr_wr_en ? S_vi_ddr_wr_addr : 'd0;

    assign S_ddr_user_wr_data  = S_vi_ddr_wr_data;


    assign S_video_out_rst_n = S_hdmi_rst_n;

    video_out u_video_out(
        .I_rst_n             ( S_video_out_rst_n    ),
        .I_ddr_clk           ( S_ddr_clk            ),
 
        .O_video_out_rd_busy ( S_video_out_rd_busy  ),
        .I_video_in_wr_busy  ( S_video_in_wr_busy   ),
        .I_video_out_rp      ( S_video_out_rp       ),
 
        .O_ddr_user_rd_en    ( S_vo_ddr_rd_en       ),
        .O_ddr_user_addr     ( S_vo_ddr_rd_addr     ),
        .I_ddr_user_ready    ( S_ddr_user_ready     ),
        .I_ddr_user_rd_valid ( S_ddr_user_rd_valid  ),
        .I_ddr_user_rd_data  ( S_ddr_user_rd_data   ),

        .I_dsi_clk           ( S_hdmi_pixel_clk     ),
        .I_video_vsync       ( S_video_out_vsync    ),
        .I_video_rd_en       ( S_hdmi_window_rd_en  ),
        .O_dbg_unf           ( S_dbg_unf            ),
        .O_vdieo_data        ( S_video_rd_data      )
    );



    mc_to_user_interface u_mc_to_user_interface(
        .I_clk                   ( S_ddr_clk               ),
        .I_rst_n                 ( S_rst_n                 ),

        .I_ddr_user_wr_en        ( S_ddr_user_wr_en        ),
        .I_ddr_user_rd_en        ( S_ddr_user_rd_en        ),
        .I_ddr_user_addr         ( S_ddr_user_addr         ),
        .I_ddr_user_wr_data      ( S_ddr_user_wr_data      ),
        .O_ddr_user_ready        ( S_ddr_user_ready        ),
        .O_ddr_user_rd_valid     ( S_ddr_user_rd_valid     ),
        .O_ddr_user_rd_data      ( S_ddr_user_rd_data      ),
            
        .O_mc_app_en             ( S_mc_app_en             ),
        .O_mc_app_addr           ( S_mc_app_addr           ),
        .O_mc_app_cmd            ( S_mc_app_cmd            ),
        .I_mc_app_rdy            ( S_mc_app_rdy            ),
        .O_mc_app_wdf_wren       ( S_mc_app_wdf_wren       ),
        .O_mc_app_wdf_data       ( S_mc_app_wdf_data       ),
        .O_mc_app_wdf_end        ( S_mc_app_wdf_end        ),
        .O_mc_app_wdf_mask       ( S_mc_app_wdf_mask       ),
        .I_mc_app_wdf_rdy        ( S_mc_app_wdf_rdy        ),
        .I_mc_app_rd_data        ( S_mc_app_rd_data        ),
        .I_mc_app_rd_data_end    ( S_mc_app_rd_data_end    ),
        .I_mc_app_rd_data_valid  ( S_mc_app_rd_data_valid  )
    );



    ph1p35_324_ddr_wrapper u_ph1p35_324_ddr_wrapper(
        .I_sys_clk              ( I_sys_clk              ),
        .I_sys_rst_n            ( S_rst_n                ),

        .O_ddr_clk              ( S_ddr_clk              ),
        .O_init_calib_complete  ( S_init_calib_complete  ),
        .I_mc_app_addr          ( S_mc_app_addr          ),
        .I_mc_app_cmd           ( S_mc_app_cmd           ),
        .I_mc_app_en            ( S_mc_app_en            ),
        .I_mc_app_wdf_data      ( S_mc_app_wdf_data      ),
        .I_mc_app_wdf_end       ( S_mc_app_wdf_end       ),
        .I_mc_app_wdf_mask      ( S_mc_app_wdf_mask      ),
        .I_mc_app_wdf_wren      ( S_mc_app_wdf_wren      ),
        .O_mc_app_rd_data       ( S_mc_app_rd_data       ),
        .O_mc_app_rd_data_end   ( S_mc_app_rd_data_end   ),
        .O_mc_app_rd_data_valid ( S_mc_app_rd_data_valid ),
        .O_mc_app_rdy           ( S_mc_app_rdy           ),
        .O_mc_app_wdf_rdy       ( S_mc_app_wdf_rdy       ),

        .ddr_addr               ( ddr_addr               ),
        .ddr_ba                 ( ddr_ba                 ),
        .ddr_cke                ( ddr_cke                ),
        .ddr_odt                ( ddr_odt                ),
        .ddr_cs_n               ( ddr_cs_n               ),
        .ddr_ras_n              ( ddr_ras_n              ),
        .ddr_cas_n              ( ddr_cas_n              ),
        .ddr_we_n               ( ddr_we_n               ),
        .ddr_ck_p               ( ddr_ck_p               ),
        .ddr_ck_n               ( ddr_ck_n               ),
        .ddr_dm                 ( ddr_dm                 ),
        .ddr_dq                 ( ddr_dq                 ),
        .ddr_dqs_p              ( ddr_dqs_p              ),
        .ddr_dqs_n              ( ddr_dqs_n              )
    );



    uivtc #(
        .H_ActiveSize ( 1920 ),
        .H_FrameSize  ( 2200 ),
        .H_SyncStart  ( 2008 ),
        .H_SyncEnd    ( 2052 ),
        .V_ActiveSize ( 1080 ),
        .V_FrameSize  ( 1125 ),
        .V_SyncStart  ( 1084 ),
        .V_SyncEnd    ( 1089 )
    )u_hdmi_vtc(
        .I_vtc_rstn    ( S_hdmi_rst_n    ),
        .I_vtc_clk     ( S_hdmi_pixel_clk ),
        .O_vtc_vs      ( S_hdmi_vsync     ),
        .O_vtc_hs      ( S_hdmi_hsync     ),
        .O_vtc_de_valid( S_hdmi_de        ),
        .O_vtc_user    ( S_hdmi_user      ),
        .O_vtc_last    ( S_hdmi_last      )
    );

    hdmi_mixer #(
        .H_OFFSET   ( 0    ),
        .V_OFFSET   ( 0    ),
        .IMG_WIDTH  ( 1920 ),
        .IMG_HEIGHT ( 1080 ),
        // Normal camera display.  Set to 4 only when the MIPI diagnostic
        // full-screen status page is needed.
        .DEBUG_MODE ( 0    )
    )u_hdmi_mixer(
        .I_clk           ( S_hdmi_pixel_clk   ),
        .I_rst_n         ( S_hdmi_rst_n       ),
        .I_video_vsync   ( S_hdmi_vsync       ),
        .I_video_hsync   ( S_hdmi_hsync       ),
        .I_video_de      ( S_hdmi_de          ),
        .I_video_user    ( S_hdmi_user        ),
        .I_video_last    ( S_hdmi_last        ),
        .I_debug_status  ( S_hdmi_debug_status),
        .O_video_rd_en   ( S_hdmi_window_rd_en),
        .I_video_rd_data ( S_video_rd_data    ),
        .I_gain          ( S_agc_gain         ),
        .O_hdmi_vsync    ( S_hdmi_out_vsync   ),
        .O_hdmi_hsync    ( S_hdmi_out_hsync   ),
        .O_hdmi_de       ( S_hdmi_out_de      ),
        .O_hdmi_data     ( S_hdmi_out_data    ),
        .O_hdmi_win      ( S_hdmi_out_win     )
    );


    // advanced item 5: histogram equalisation of the displayed image (mode 0, toggled with BTN1)
    wire        S_he_vsync;
    wire        S_he_hsync;
    wire        S_he_de;
    wire        S_he_win;
    wire [23:0] S_he_data;
    hist_eq u_hist_eq (
        .clk     ( S_hdmi_pixel_clk ),
        .rst_n   ( S_hdmi_rst_n     ),
        .en      ( S_he_apply       ),
        .in_vs   ( S_hdmi_out_vsync ),
        .in_hs   ( S_hdmi_out_hsync ),
        .in_de   ( S_hdmi_out_de    ),
        .in_win  ( S_hdmi_out_win   ),
        .in_rgb  ( S_hdmi_out_data  ),
        .out_vs  ( S_he_vsync       ),
        .out_hs  ( S_he_hsync       ),
        .out_de  ( S_he_de          ),
        .out_win ( S_he_win         ),
        .out_rgb ( S_he_data        )
    );

    wire        S_sh_vsync;
    wire        S_sh_hsync;
    wire        S_sh_de;
    wire        S_sh_win;
    wire [23:0] S_sh_data;
    video_sharpen u_video_sharpen (
        .clk     ( S_hdmi_pixel_clk ),
        .rst_n   ( S_hdmi_rst_n     ),
        .en      ( S_pre_vision_mode <= 3'd1 ),
        .in_vs   ( S_he_vsync       ),
        .in_hs   ( S_he_hsync       ),
        .in_de   ( S_he_de          ),
        .in_win  ( S_he_win         ),
        .in_rgb  ( S_he_data        ),
        .out_vs  ( S_sh_vsync       ),
        .out_hs  ( S_sh_hsync       ),
        .out_de  ( S_sh_de          ),
        .out_win ( S_sh_win         ),
        .out_rgb ( S_sh_data        )
    );
    video_gray_sobel #(
        .H_ACTIVE        (1920),
        .V_ACTIVE        (1080),
        .EDGE_THRESHOLD  (32),
        .SPLIT_X         (944)
    ) u_video_gray_sobel (
        .clk       (S_hdmi_pixel_clk),
        .rst_n     (S_hdmi_rst_n),
        .in_vs     (S_sh_vsync),
        .in_hs     (S_sh_hsync),
        .in_de     (S_sh_de),
        .in_rgb    (S_sh_data),
        .in_win    (S_sh_win),
        .mode      (S_pre_vision_mode),
        .split     (S_split_flag),
        .out_vs    (S_sobel_vsync),
        .out_hs    (S_sobel_hsync),
        .out_de    (S_sobel_de),
        .out_rgb   (S_sobel_data),
        .out_x     (S_sobel_x),
        .out_y     (S_sobel_y),
        .edge_flag (S_edge_flag),
        .fill_edge (S_fill_edge),
        .mag       (S_mag),
        .mag_v     (S_mag_v)
    );

    // focus meter: sharpness number + bar on the OSD (use it to set the lens focus)
    focus_meter u_focus_meter (
        .clk   ( S_hdmi_pixel_clk ),
        .rst_n ( S_hdmi_rst_n     ),
        .in_vs ( S_sobel_vsync    ),
        .mag   ( S_mag            ),
        .mag_v ( S_mag_v          ),
        .score ( S_foc_score      ),
        .bar   ( S_foc_bar        ),
        .upd   ( S_foc_upd        )
    );

    video_region_fill #(
        .H_ACTIVE(1920)
    ) u_video_region_fill (
        .clk       (S_hdmi_pixel_clk),
        .rst_n     (S_hdmi_rst_n),
        .in_vs     (S_sobel_vsync),
        .in_hs     (S_sobel_hsync),
        .in_de     (S_sobel_de),
        .in_x      (S_sobel_x),
        .in_y      (S_sobel_y),
        .in_rgb    (S_sobel_data),
        .in_edge   (S_edge_flag),
        .in_fill_edge (S_fill_edge),
        .fill_mode (S_region_fill_mode),
        .out_vs    (S_hdmi_proc_vsync),
        .out_hs    (S_hdmi_proc_hsync),
        .out_de    (S_hdmi_proc_de),
        .out_x     (S_proc_x),
        .out_y     (S_proc_y),
        .out_rgb   (S_hdmi_proc_data)
    );

    osd_anlogic #(
        .OSD_X(32),
        .OSD_Y(24)
    ) u_osd_anlogic (
        .clk     (S_hdmi_pixel_clk),
        .rst_n   (S_hdmi_rst_n),
        .in_vs   (S_hdmi_proc_vsync),
        .in_hs   (S_hdmi_proc_hsync),
        .in_de   (S_hdmi_proc_de),
        .in_x    (S_proc_x),
        .in_y    (S_proc_y),
        .in_rgb  (S_hdmi_proc_data),
        .enable  (1'b1),
        .mode    (S_vision_mode),
        .he      (S_he_apply),
        .out_vs  (S_osd_vsync),
        .out_hs  (S_osd_hsync),
        .out_de  (S_osd_de),
        .out_rgb (S_osd_data)
    );
    // brightness statistics over the camera image window: before / after the digital gain
    rgb_stats u_rgb_stats (
        .clk   ( S_hdmi_pixel_clk ),
        .rst_n ( S_hdmi_rst_n     ),
        .vs    ( S_hdmi_out_vsync ),
        .win   ( S_hdmi_out_win   ),
        .pre   ( S_video_rd_data  ),
        .post  ( S_hdmi_out_data  ),
        .a_r0  ( S_st_r0 ), .a_g0 ( S_st_g0 ), .a_b0 ( S_st_b0 ),
        .a_r1  ( S_st_r1 ), .a_g1 ( S_st_g1 ), .a_b1 ( S_st_b1 ),
        .upd   ( S_st_upd )
    );

    auto_gain u_auto_gain (
        .clk   ( S_hdmi_pixel_clk ),
        .rst_n ( S_hdmi_rst_n     ),
        .upd   ( S_st_upd         ),
        .avg   ( S_st_g1          ),
        .gain  ( S_agc_gain       )
    );

    // camera frame-start marker (toggle) for the latency meter
    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n) begin
            S_cam_tuser_d   <= 1'b0;
            S_cam_start_tog <= 1'b0;
        end
        else begin
            S_cam_tuser_d <= S_ISP_O_tuser;
            if(S_ISP_O_tuser && !S_cam_tuser_d)
                S_cam_start_tog <= ~S_cam_start_tog;
        end
    end

    wire [12:0] S_mot_cnt;
    wire [13:0] S_mot_ev;
    wire        S_mot_upd;
    wire [13:0] S_frm_cnt;
    wire [7:0]  S_fper;
    latency_meter #(.HIST(4 - VIDEO_READ_OFFSET), .PIX_PER_MS(75000), .EXTRA_MS(2)) u_latency_meter (
        .clk        ( S_hdmi_pixel_clk ),
        .rst_n      ( S_hdmi_rst_n     ),
        .cam_toggle ( S_cam_start_tog  ),
        .vs         ( S_hdmi_vsync     ),
        .lat_ms     ( S_lat_ms         ),
        .lat_upd    ( S_lat_upd        ),
        .frm_cnt    ( S_frm_cnt        ),
        .fper       ( S_fper           )
    );

    // patch_v2: colour target detection (runs on the camera image, results used in mode 4)
    wire [19:0] S_tgt_cnt;
    wire [19:0] S_tgt_cnt_top;
    wire [19:0] S_tgt_cnt_left;
    target_detect #(.CENTER_X(944), .DEAD_X(192)) u_target_detect (
        .clk       ( S_hdmi_pixel_clk ),
        .rst_n     ( S_hdmi_rst_n     ),
        .in_vs     ( S_hdmi_out_vsync ),
        .in_hs     ( S_hdmi_out_hsync ),
        .in_de     ( S_hdmi_out_de    ),
        .in_rgb    ( S_hdmi_out_data  ),
        .in_win    ( S_hdmi_out_win   ),
        .color_sel ( S_target_color   ),
        .found     ( S_tgt_found      ),
        .x0        ( S_tgt_x0         ),
        .x1        ( S_tgt_x1         ),
        .y0        ( S_tgt_y0         ),
        .y1        ( S_tgt_y1         ),
        .cx        ( S_tgt_cx         ),
        .cy        ( S_tgt_cy         ),
        .dir       ( S_tgt_dir        ),
        .cnt_pub   ( S_tgt_cnt        ),
        .cnt_top_pub( S_tgt_cnt_top   ),
        .cnt_left_pub( S_tgt_cnt_left ),
        .upd       ( S_tgt_upd        )
    );

    // advanced item 2: shape recognition (rectangle / circle / triangle) from the box fill ratio
    wire [1:0]  S_tgt_shape;
    wire [6:0]  S_tgt_conf;
    wire        S_tgt_shape_done;
    shape_classify u_shape_classify (
        .clk   ( S_hdmi_pixel_clk ),
        .rst_n ( S_hdmi_rst_n     ),
        .start ( S_tgt_upd        ),
        .x0    ( S_tgt_x0         ),
        .x1    ( S_tgt_x1         ),
        .y0    ( S_tgt_y0         ),
        .y1    ( S_tgt_y1         ),
        .cnt   ( S_tgt_cnt        ),
        .cnt_top ( S_tgt_cnt_top  ),
        .cnt_left( S_tgt_cnt_left ),
        .shape ( S_tgt_shape      ),
        .conf  ( S_tgt_conf       ),
        .done  ( S_tgt_shape_done )
    );

    target_overlay u_target_overlay (
        .clk       ( S_hdmi_pixel_clk ),
        .rst_n     ( S_hdmi_rst_n     ),
        .in_vs     ( S_osd_vsync      ),
        .in_hs     ( S_osd_hsync      ),
        .in_de     ( S_osd_de         ),
        .in_rgb    ( S_osd_data       ),
        .enable    ( S_vision_mode == 3'd4 ),
        .found     ( S_tgt_found      ),
        .x0        ( S_tgt_x0         ),
        .x1        ( S_tgt_x1         ),
        .y0        ( S_tgt_y0         ),
        .y1        ( S_tgt_y1         ),
        .cx        ( S_tgt_cx         ),
        .cy        ( S_tgt_cy         ),
        .color_sel ( S_target_color   ),
        .upd       ( S_tgt_upd        ),
        .shape     ( S_tgt_shape      ),
        .conf      ( S_tgt_conf       ),
        .shape_upd ( S_tgt_shape_done ),
        .lat_enable( 1'b1             ),
        .foc_score ( S_foc_score      ),
        .foc_bar   ( S_foc_bar        ),
        .foc_upd   ( S_foc_upd        ),
        .lat_ms    ( S_lat_ms         ),
        .mot_enable( S_vision_mode == 3'd7 ),
        .mot_cnt   ( S_mot_cnt        ),
        .mot_ev    ( S_mot_ev         ),
        .mot_upd   ( S_mot_upd        ),
        .lat_upd   ( S_lat_upd        ),
        .frm_cnt   ( S_frm_cnt        ),
        .fper      ( S_fper           ),
        .stat_enable( 1'b1            ),
        .stat_upd  ( S_st_upd         ),
        .st_r0     ( S_st_r0 ), .st_g0 ( S_st_g0 ), .st_b0 ( S_st_b0 ),
        .st_r1     ( S_st_r1 ), .st_g1 ( S_st_g1 ), .st_b1 ( S_st_b1 ),
        .out_vs    ( S_ovl_vsync      ),
        .out_hs    ( S_ovl_hsync      ),
        .out_de    ( S_ovl_de         ),
        .out_rgb   ( S_ovl_data       )
    );

    // advanced item 4: frame-difference motion detection (analyses the clean video, tints moving blocks in mode 7)
    wire        S_mot_vsync;
    wire        S_mot_hsync;
    wire        S_mot_de;
    wire [23:0] S_mot_data;
    motion_detect u_motion_detect (
        .clk     ( S_hdmi_pixel_clk ),
        .rst_n   ( S_hdmi_rst_n     ),
        .m_vs    ( S_hdmi_out_vsync ),
        .m_hs    ( S_hdmi_out_hsync ),
        .m_de    ( S_hdmi_out_de    ),
        .m_rgb   ( S_hdmi_out_data  ),
        .o_vs    ( S_ovl_vsync      ),
        .o_hs    ( S_ovl_hsync      ),
        .o_de    ( S_ovl_de         ),
        .o_rgb   ( S_ovl_data       ),
        .enable  ( S_vision_mode == 3'd7 ),
        .out_vs  ( S_mot_vsync      ),
        .out_hs  ( S_mot_hsync      ),
        .out_de  ( S_mot_de         ),
        .out_rgb ( S_mot_data       ),
        .mot_cnt ( S_mot_cnt        ),
        .mot_ev  ( S_mot_ev         ),
        .mot_upd ( S_mot_upd        )
    );

    hdmi_tx u_hdmi_tx(
        .I_pixel_clk        ( S_hdmi_pixel_clk  ),
        .I_serial_clk       ( S_hdmi_serial_clk ),
        .I_rst              ( ~S_hdmi_rst_n     ),
        .I_key_in           ( 1'b0              ),
        .I_edid_read_trig   ( 1'b0              ),
        .O_edid_read_valid  (                   ),
        .O_edid_read_data   (                   ),
        .I_video_rgb_enable ( 1'b1              ),
        .I_video_in_vs      ( S_mot_vsync      ),
        .I_video_in_de      ( S_mot_de         ),
        .I_video_in_user    ( 1'b0              ),
        .I_video_in_valid   ( 1'b0              ),
        .I_video_in_last    ( 1'b0              ),
        .O_video_in_ready   (                   ),
        .I_video_in_data    ( S_mot_data       ),
        .I_audio_valid      ( 1'b0              ),
        .I_audio_left_data  ( 24'd0             ),
        .I_audio_right_data ( 24'd0             ),
        .I_i2s_BCLK         ( 1'b0              ),
        .I_i2s_LRCK         ( 1'b0              ),
        .I_i2s_DOUT         ( 1'b0              ),
        .O_ddc_scl          (                   ),
        .O_hdmi_clk_p       (                   ),
        .O_hdmi_tx_p        (                   ),
        .O_tmds_ch0_p       ( O_tmds_ch0_p      ),
        .O_tmds_ch1_p       ( O_tmds_ch1_p      ),
        .O_tmds_ch2_p       ( O_tmds_ch2_p      ),
        .O_tmds_clk_p       ( O_tmds_clk_p      )
    );

    
endmodule


// patch_v2: push-button mode / target-colour selector.
//   BTN0 (active low)  : next mode, 0 -> 1 -> 2 -> 3 -> 4 -> 0
//   BTN1 (active low)  : back to mode 0 (original image); in mode 4 it cycles the
//                        target colour instead (red, green, blue, yellow).
// Inputs are synchronised to clk, debounced (~10 ms at 74.25 MHz) and the new
// mode / colour is applied at the next vsync so a frame is never processed twice.
module vision_mode_ctrl #(
    parameter integer DEBOUNCE_CYCLES = 740000
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire [1:0] I_button,
    input  wire       in_vs,
    output reg  [2:0] mode,
    output reg  [1:0] color_sel,
    output reg        he_flag,
    output reg        split_flag   // modes 1, 2, 5, 6: BTN1 toggles the split-screen compare
);
    reg [1:0]  sync1;
    reg [1:0]  sync2;
    reg [1:0]  stable;
    reg [19:0] cnt0;
    reg [19:0] cnt1;
    reg [1:0]  press;
    reg [2:0]  mode_next;
    reg [1:0]  color_next;
    reg        he_next;
    reg        split_next;
    reg        vs_d;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            sync1      <= 2'b00;
            sync2      <= 2'b00;
            stable     <= 2'b00;
            cnt0       <= 20'd0;
            cnt1       <= 20'd0;
            press      <= 2'b00;
            mode_next  <= 3'd0;
            color_next <= 2'd0;
            mode       <= 3'd0;
            color_sel  <= 2'd0;
            he_next    <= 1'b0;
            he_flag    <= 1'b0;
            split_next <= 1'b0;
            split_flag <= 1'b0;
            vs_d       <= 1'b0;
        end
        else begin
            sync1 <= ~I_button;          // 1 = pressed
            sync2 <= sync1;
            press <= 2'b00;

            if(sync2[0] == stable[0])
                cnt0 <= 20'd0;
            else if(cnt0 == DEBOUNCE_CYCLES - 1) begin
                cnt0      <= 20'd0;
                stable[0] <= sync2[0];
                press[0]  <= sync2[0];
            end
            else
                cnt0 <= cnt0 + 20'd1;

            if(sync2[1] == stable[1])
                cnt1 <= 20'd0;
            else if(cnt1 == DEBOUNCE_CYCLES - 1) begin
                cnt1      <= 20'd0;
                stable[1] <= sync2[1];
                press[1]  <= sync2[1];
            end
            else
                cnt1 <= cnt1 + 20'd1;

            if(press[1]) begin
                if(mode_next == 3'd4)
                    color_next <= color_next + 2'd1;
                else if(mode_next == 3'd0)
                    he_next <= ~he_next;          // mode 0: BTN1 toggles histogram equalisation
                else if(mode_next == 3'd1 || mode_next == 3'd2 || mode_next == 3'd5 || mode_next == 3'd6)
                    split_next <= ~split_next;    // modes 1, 2, 5, 6: BTN1 toggles split-screen compare
                else
                    mode_next <= 3'd0;
            end
            else if(press[0]) begin
                if(mode_next == 3'd7)
                    mode_next <= 3'd0;
                else
                    mode_next <= mode_next + 3'd1;
            end

            vs_d <= in_vs;
            if(in_vs && !vs_d) begin
                mode      <= mode_next;
                color_sel <= color_next;
                he_flag   <= he_next;
                split_flag <= split_next;
            end
        end
    end
endmodule

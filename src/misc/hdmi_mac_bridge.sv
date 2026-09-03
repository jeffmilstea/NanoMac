module hdmi_mac_bridge (
    input  wire        mac_clk,
    input  wire        mac_hs_n,
    input  wire        mac_vs_n,
    input  wire        mac_pix,
    input  wire [15:0] mac_audio_16,
    
    input  wire        hdmi_clk,
    input  wire [10:0] hdmi_x,
    input  wire [9:0]  hdmi_y,
    
    output wire [7:0]  hdmi_r,
    output wire [7:0]  hdmi_g,
    output wire [7:0]  hdmi_b,
    output wire [31:0] hdmi_audio_sample,
    output wire        hdmi_audio_clk,
    output wire        genlock_sync,
    input  wire [1:0]  video_mode,
    input  wire        wide
);

    // --- MAC ACTIVE SYNTHESIS ---
    reg [9:0] mac_x_cnt = 0;
    reg [8:0] mac_y_cnt = 0;
    reg hs_n_last = 1'b1, vs_n_last = 1'b1;
    
    always @(posedge mac_clk) begin
        hs_n_last <= mac_hs_n;
        vs_n_last <= mac_vs_n;
        
        // HSync falling edge = Start of horizontal sync / raster line reset
        if (mac_hs_n == 1'b0 && hs_n_last == 1'b1) begin
            mac_x_cnt <= 0;
            if (mac_y_cnt == 369)
                mac_y_cnt <= 0;
            else
                mac_y_cnt <= mac_y_cnt + 1'b1;
        end else begin
            mac_x_cnt <= mac_x_cnt + 1'b1;
        end
    
        // VSync falling edge = Start of vertical frame
        if (mac_vs_n == 1'b0 && vs_n_last == 1'b1) begin
            mac_y_cnt <= 0;
        end
    end
    
    // Active visible region: 512 pixels x 342 lines
    wire mac_h_active = (mac_x_cnt >= 184 && mac_x_cnt < 696);
    wire mac_v_active = (mac_y_cnt >= 28 && mac_y_cnt < 370);

    // --- MAC CRT CHAMFERED CORNER MASKING ---
    // Authentic Mac 128K/512K/Plus rounded CRT screen corners:
    // Row 0 & 341: mask 3 pixels at left/right (x < 3 || x >= 509)
    // Row 1 & 340: mask 2 pixels at left/right (x < 2 || x >= 510)
    // Row 2 & 339: mask 1 pixel at left/right  (x < 1 || x >= 511)
    reg [9:0] mac_px_q, mac_px_q2;
    reg [9:0] mac_py_q, mac_py_q2;
    always @(posedge hdmi_clk) begin
        mac_px_q  <= read_x[9:0];
        mac_px_q2 <= mac_px_q;
        mac_py_q  <= read_y[9:0];
        mac_py_q2 <= mac_py_q;
    end

    wire is_corner = (mac_py_q2 == 0   || mac_py_q2 == 341) ? (mac_px_q2 < 3 || mac_px_q2 >= 509) :
                     (mac_py_q2 == 1   || mac_py_q2 == 340) ? (mac_px_q2 < 2 || mac_px_q2 >= 510) :
                     (mac_py_q2 == 2   || mac_py_q2 == 339) ? (mac_px_q2 < 1 || mac_px_q2 >= 511) : 1'b0;

    // --- GENLOCK SYNC ---
    reg mac_frame_toggle = 1'b0;
    always @(posedge mac_clk) begin
        if (mac_y_cnt == 284 && mac_x_cnt == 231)
            mac_frame_toggle <= ~mac_frame_toggle;
    end
    
    reg [2:0] genlock_sync_reg = 3'b0;
    always @(posedge hdmi_clk) begin
        genlock_sync_reg <= {genlock_sync_reg[1:0], mac_frame_toggle};
    end
    assign genlock_sync = (genlock_sync_reg[2] ^ genlock_sync_reg[1]);

    // --- MAC AUDIO STROBE ---
    reg hs_prev;
    always @(posedge mac_clk) hs_prev <= mac_hs_n;
    wire mac_audio_stb = hs_prev & ~mac_hs_n;

    // --- AUDIO REQUEST CLOCK (48 kHz) ---
    // 78.336 MHz / (48000 * 2) = 816 clocks per tick
    reg [9:0] audio_req_cnt = 0;
    reg       clk_audio_74 = 0;
    reg       hdmi_sample_req = 0;
    always @(posedge hdmi_clk) begin
        if (audio_req_cnt >= 10'd815) begin
            audio_req_cnt <= 10'd0;
            clk_audio_74 <= ~clk_audio_74;
            hdmi_sample_req <= ~clk_audio_74;
        end else begin
            audio_req_cnt <= audio_req_cnt + 10'd1;
            hdmi_sample_req <= 1'b0;
        end
    end
    
    assign hdmi_audio_clk = clk_audio_74;

    // --- VIDEO FRAMEBUFFER ---
    // 512 x 342 = 175,104 bits -> 8192 words of 32 bits (Power-of-two depth for clean BSRAM inference)
    reg [31:0] frame_buf [0:8191];
    
    reg [9:0] w_x;
    reg [8:0] w_y;
    reg w_active_prev;
    reg [31:0] shift_reg;
    
    wire [12:0] w_addr = {w_y[8:0], w_x[8:5]};

    always @(posedge mac_clk) begin
        if (mac_v_active && mac_h_active) begin
            shift_reg <= {shift_reg[30:0], mac_pix};
            if (w_x[4:0] == 5'd31) begin
                frame_buf[w_addr] <= {shift_reg[30:0], mac_pix};
            end
            w_x <= w_x + 1;
        end else if (!mac_h_active) begin
            w_x <= 0;
            if (mac_v_active && w_active_prev) w_y <= w_y + 1;
        end
        
        if (!mac_v_active) w_y <= 0;
        w_active_prev <= mac_h_active;
    end
    
    // Read side
    // 1x window (512x342): centered at (384, 185)
    wire in_window_1x = (hdmi_x >= 384 && hdmi_x < 896) && (hdmi_y >= 185 && hdmi_y < 527);
    wire [10:0] read_x_1x = hdmi_x - 11'd384;
    wire [9:0]  read_y_1x = hdmi_y - 10'd185;

    // 2x window (1024x684): centered at (128, 18)
    wire in_window_2x = (hdmi_x >= 128 && hdmi_x < 1152) && (hdmi_y >= 18 && hdmi_y < 702);
    wire [10:0] read_x_2x = (hdmi_x - 11'd128) >> 1;
    wire [9:0]  read_y_2x = (hdmi_y - 10'd18) >> 1;

    // Native 512x342 window (0..511, 0..341)
    wire in_window_native = (hdmi_x < 512) && (hdmi_y < 342);
    wire [10:0] read_x_native = hdmi_x;
    wire [9:0]  read_y_native = hdmi_y;

    wire in_window = (video_mode == 2'b10) ? in_window_native : (wide ? in_window_2x : in_window_1x);
    wire [10:0] read_x = in_window ? ((video_mode == 2'b10) ? read_x_native : (wide ? read_x_2x : read_x_1x)) : 11'd0;
    wire [9:0]  read_y = in_window ? ((video_mode == 2'b10) ? read_y_native : (wide ? read_y_2x : read_y_1x)) : 10'd0;
    
    wire [12:0] r_addr = {read_y[8:0], read_x[8:5]};
    
    // Pipelined read side (2 clock stages for maximum timing margin)
    reg [12:0] r_addr_q;
    reg [31:0] r_word;
    reg in_window_q, in_window_q2;
    reg [4:0] read_x_q, read_x_q2;
    
    always @(posedge hdmi_clk) begin
        r_addr_q    <= r_addr;
        r_word      <= frame_buf[r_addr_q];
        
        in_window_q <= in_window;
        in_window_q2 <= in_window_q;
        
        read_x_q    <= read_x[4:0];
        read_x_q2   <= read_x_q;
    end
    
    wire pixel_bit = r_word[31 - read_x_q2];
    wire [7:0] active_pixel = is_corner ? 8'h02 : (pixel_bit ? 8'hFF : 8'h00); // Mask corners to border color
    
    assign hdmi_r = (in_window_q2 && !is_corner) ? active_pixel : 8'h02; // Dark blue borders
    assign hdmi_g = (in_window_q2 && !is_corner) ? active_pixel : 8'h02;
    assign hdmi_b = (in_window_q2 && !is_corner) ? active_pixel : 8'h10;
    
    // --- AUDIO INTERPOLATOR ---
    reg [2:0] audio_stb_sync;
    reg [15:0] audio_data_sync;
    
    always @(posedge hdmi_clk) begin
        audio_stb_sync <= {audio_stb_sync[1:0], mac_audio_stb};
        if (audio_stb_sync[1] && !audio_stb_sync[2]) begin
            audio_data_sync <= mac_audio_16;
        end
    end
    
    reg [15:0] phase_acc;
    reg [15:0] current_sample, next_sample;
    
    wire [16:0] audio_phase_sum = phase_acc + 17'd30385;
    
    always @(posedge hdmi_clk) begin
        if (audio_stb_sync[1] && !audio_stb_sync[2]) begin
            next_sample <= audio_data_sync;
        end
        
        if (hdmi_sample_req) begin
            phase_acc <= audio_phase_sum[15:0];
            if (audio_phase_sum[16]) begin
                current_sample <= next_sample;
            end
        end
    end
    
    reg [15:0] hdmi_audio_reg;
    always @(posedge hdmi_clk) begin
        if (audio_req_cnt == 10'd407) begin
            hdmi_audio_reg <= current_sample;
        end
    end

    assign hdmi_audio_sample = {hdmi_audio_reg, hdmi_audio_reg};

endmodule

module hdmi_mac_bridge (
    input  wire        mac_clk,
    input  wire        mac_h_active,
    input  wire        mac_v_active,
    input  wire        mac_pix,
    input  wire        mac_audio_stb,
    input  wire [15:0] mac_audio_16,
    
    input  wire        hdmi_clk,
    input  wire        hdmi_sample_req,
    input  wire [10:0] hdmi_x,
    input  wire [9:0]  hdmi_y,
    
    output wire [7:0]  hdmi_r,
    output wire [7:0]  hdmi_g,
    output wire [7:0]  hdmi_b,
    output wire [15:0] hdmi_audio,
    input  wire        wide
);

    // --- VIDEO FRAMEBUFFER ---
    // 512 x 342 = 175,104 bits = 5472 words of 32 bits
    reg [31:0] frame_buf [0:5471];
    
    reg [9:0] w_x;
    reg [8:0] w_y;
    reg w_active_prev;
    reg [31:0] shift_reg;
    
    always @(posedge mac_clk) begin
        if (mac_v_active && mac_h_active) begin
            shift_reg <= {shift_reg[30:0], mac_pix};
            if (w_x[4:0] == 5'd31) begin
                frame_buf[w_y * 16 + (w_x >> 5)] <= {shift_reg[30:0], mac_pix};
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

    wire in_window = wide ? in_window_2x : in_window_1x;
    wire [10:0] read_x = in_window ? (wide ? read_x_2x : read_x_1x) : 11'd0;
    wire [9:0]  read_y = in_window ? (wide ? read_y_2x : read_y_1x) : 10'd0;
    
    reg [31:0] r_word;
    wire [12:0] r_addr = read_y * 16 + (read_x >> 5);
    
    always @(posedge hdmi_clk) begin
        r_word <= frame_buf[r_addr];
    end
    
    // The word is delayed by 1 clock. So we must delay in_window and read_x by 1 clock too.
    reg in_window_q;
    reg [4:0] read_x_q;
    always @(posedge hdmi_clk) begin
        in_window_q <= in_window;
        read_x_q <= read_x[4:0];
    end
    
    wire pixel_bit = r_word[31 - read_x_q];
    wire [7:0] active_pixel = pixel_bit ? 8'hFF : 8'h00; // White or Black
    
    assign hdmi_r = in_window_q ? active_pixel : 8'h02; // Dark blue borders
    assign hdmi_g = in_window_q ? active_pixel : 8'h02;
    assign hdmi_b = in_window_q ? active_pixel : 8'h10;
    
    // --- AUDIO INTERPOLATOR ---
    // Cross domain (mac_clk to hdmi_clk). Since they are mathematically locked (hdmi_clk = 5*mac_clk),
    // a simple synchronizer on the strobe is enough.
    reg [2:0] audio_stb_sync;
    reg [15:0] audio_data_sync;
    
    always @(posedge hdmi_clk) begin
        audio_stb_sync <= {audio_stb_sync[1:0], mac_audio_stb};
        if (audio_stb_sync[1] && !audio_stb_sync[2]) begin
            audio_data_sync <= mac_audio_16;
        end
    end
    
    // Phase accumulator: 22.2545 kHz / 48.0 kHz * 65536 = 30385
    reg [15:0] phase_acc;
    reg [15:0]  current_sample, next_sample;
    
    always @(posedge hdmi_clk) begin
        if (audio_stb_sync[1] && !audio_stb_sync[2]) begin
            next_sample <= audio_data_sync;
        end
        
        if (hdmi_sample_req) begin
            {current_sample, phase_acc} <= phase_acc + 16'd30385 < phase_acc ? 
                                           {next_sample, phase_acc + 16'd30385} : 
                                           {current_sample, phase_acc + 16'd30385};
        end
    end
    
    assign hdmi_audio = current_sample;

endmodule

//============================================================================
//  Macintosh Plus
//
//  Port to MiSTer
//  Copyright (C) 2017-2019 Sorgelig
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

module macplus
(
	//Master input clocks
	input		       CLKIN,
	input		       CLKCPU,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input		       RESET,

        // video and audio outputs
        output		       pixelOut,
	output		       vsync,
	output		       hsync,

	output [11:0]	       audio,

	output [4:0]	       leds,

	//ADC
	inout [3:0]	       ADC_BUS,

        //MOUSE
	input [5:0]	       MOUSE,
	input		       kbd_strobe,
	input [9:0]	       kbd_data,

        // set the real-world inputs to sane defaults
	input		       configROMSize,     // 64k or 128K ROM
	input		       configFastboot,    // disable rom/ram check
	input [1:0]	       configRAMSize,     // 128k, 512k, 1MB or 4MB
	input		       configMachineType, // 0 = Plus, 1 = SE
	input [1:0]	       configFloppyWProt,
	input		       configSCSIWProt,
	input [1:0]	       configTurbo,
	input		       configCache,      // OSD cache enable
			  
        // interface to sd card
	input [31:0]	       sdc_image_size,
	input [SCSI_DEVS+1:0]  sdc_image_mounted,
	output [31:0]	       sdc_lba,
	output [SCSI_DEVS+1:0] sdc_rd,
	output [SCSI_DEVS+1:0] sdc_wr,
	input		       sdc_done,
	input		       sdc_busy,
	output [7:0]	       sdc_data_out,
	input [7:0]	       sdc_data_in,
	input		       sdc_data_en,
	input [8:0]	       sdc_addr,

        // serial port
	output		       UART_TXD,
	input		       UART_RXD,
	output		       UART_RTS,
	input		       UART_CTS,

        // interface to toplevel rom
	output		       _romOE,
        output [17:0]	       romAddr, 
        input [15:0]	       romData, 

	output [2:0]	       busPhase, // used to synchronize ram state machine
  
        // interface to (sd)ram
	output [20:0]	       ram_addr,
	output [15:0]	       sdram_din,
	output [1:0]	       sdram_ds,
	output		       sdram_we,
	output		       sdram_oe,
	input [15:0]	       sdram_do,
	input       	       sdram_rd_done, // SDRAM FSM read-data-valid pulse (clk_sys)
	input [20:0]	       sdram_rd_addr, // CPU-domain word addr FSM read (= cpuAddr[21:1]);
	                                   // board/tb invert the controller's mapped address here

	// ILA / ICE debug probe and execution control interface
	output [47:0]	       mac_probes,
	output		       _cpuAS_probe,
	output		       cache_hit_probe,   // ILA: 1 when cache hit in progress
	output		       cache_en_probe,    // ILA: 1 when cache is enabled
	output		       osd_cache_probe,   // ILA: raw configCache from OSD/MCU
	output		       cache_sweep_probe, // ILA: 1 while tag invalidation sweep runs
	output [15:0]	       cache_data_dbg,  // debug/tb: word currently served by cache
	output [15:0]	       cpu_data_in_dbg, // debug/tb: CPU data in (for oracle cross-check)
	output [15:0]	       cache_hits,      // stat: cache hits since last clear
	output [15:0]	       cache_misses,    // stat: cache misses since last clear
	output [15:0]	       cache_fills,     // stat: miss fills since last clear
	output [23:1]	       last_fill_addr,  // snapshot: address of last miss fill
	output		       last_fill_is_rom,
	// ICE poke/peek (companion ila domain == clk_sys, no CDC needed)
	input		       ice_poke_valid,
	input [2:0]	       ice_poke_idx,
	input [15:0]	       ice_poke_data,
	output [15:0]	       ice_peek_data,
	input		       ice_peek_req,
	input [2:0]	       ice_peek_idx,
	// Hardware turbo override (written via $F80008 or ICE poke) -> top DCS
	output		       hw_turbo_en_o,
	output		       hw_turbo_ovr_o,
	output		       enPhi1_raw,
	output		       enPhi2_raw,
	input		       enPhi1_gated,
	input		       enPhi2_gated,
	input		       cpu_reset_override
);

assign ADC_BUS  = 'Z;

////////////////////   CLOCKS   ///////////////////

wire clk_sys = CLKIN;
wire clk_cpu = CLKCPU;

wire clk8_en_p, clk8_en_n;
wire videoBusControl;
wire cpuBusControl;
   
clocks clocks (
       .clk             ( clk_sys         ),
       .clk8_en_p       ( clk8_en_p       ),
       .clk8_en_n       ( clk8_en_n       ),
       .busPhase        ( busPhase        ),
       .videoBusControl ( videoBusControl ),
       .cpuBusControl   ( cpuBusControl   )
);
   

reg       n_reset = 0;
always @(posedge clk_sys) begin
	reg [15:0] rst_cnt;

	if (clk8_en_p) begin
		// various sources can reset the mac
		if(RESET || ~_cpuReset_o ) begin
			rst_cnt <= '1;
			n_reset <= 0;
		end
		else if(rst_cnt) begin
			rst_cnt    <= rst_cnt - 1'd1;
		end
		else begin
			n_reset <= 1;
		end
	end
end

// Blank screen during reset. Otherwise the image
// would freeze during reset which looks somehow confusing
wire pixel;   
assign pixelOut = n_reset?pixel:1'b0;  
   
///////////////////////////////////////////////////

localparam SCSI_DEVS = 2;

// the status register is controlled by the on screen display (OSD)
wire  [1:0] buttons;
wire [32:0] TIMESTAMP;

//
// Serial Ports
//
wire serialOut;
wire serialIn = UART_RXD;
wire serialRTS;
wire serialCTS = UART_CTS;

assign UART_TXD = serialOut;
assign UART_RTS = serialRTS;

// interconnects
// CPU
wire _cpuReset, _cpuReset_o, _cpuUDS, _cpuLDS, _cpuRW;
wire _cpuAS;
wire _cpuVMA, _cpuVPA, _cpuDTACK;
wire [2:0] _cpuIPL;
wire [2:0] cpuFC;
wire [23:1] cpuAddr;
wire [15:0] cpuDataOut;

// RAM/ROM
wire _ramOE, _ramWE;
wire _memoryUDS, _memoryLDS;

// peripherals
wire vid_alt, loadPixels, _hblank, _vblank;
wire memoryOverlayOn, selectSCSI, selectSCC, selectIWM, selectVIA, selectRAM, selectROM, selectSEOverlay, selectHardwareRegs;
wire [15:0] dataControllerDataOut;
wire hw_turbo_en, hw_turbo_ovr, hw_cache_en;
wire [1:0] hw_fillph_turbo; // turbo fill phase = 4 + value (00->4 .. 11->7)
assign hw_turbo_en_o  = hw_turbo_en;
assign hw_turbo_ovr_o = hw_turbo_ovr;

// audio
wire snd_alt;
wire loadSound;

// only accept /AS for ram or rom if it comes in phase 2. Don't accept any later as as we would not
// Memory cycle synchronization for normal and turbo modes
wire	refreshCycle;
wire	cpu_slot = cpuBusControl || (!loadPixels && !loadSound && !refreshCycle);

reg ram_req;
reg rom_req;
reg io_req;
reg io_synced;
reg [2:0] io_sync_cnt;

wire req_rst = !_cpuReset || _cpuAS;
always @(posedge clk_sys or posedge req_rst) begin
   if (req_rst) begin
      ram_req     <= 1'b0;
      rom_req     <= 1'b0;
      io_req      <= 1'b0;
      io_synced   <= 1'b0;
      io_sync_cnt <= 3'd0;
   end else begin
      if (busPhase == 3'd2 && selectRAM && cpu_slot)
         ram_req <= 1'b1;
      if (busPhase == 3'd2 && selectROM)
         rom_req <= 1'b1;
      if (cpuFC != 3'b111 && !selectVIA && !selectRAM && !selectROM) begin
         io_req <= 1'b1;
         if (clk8_en_n) begin
            if (io_sync_cnt < 3'd3)
               io_sync_cnt <= io_sync_cnt + 3'd1;
            if (_cpuRW ? (io_sync_cnt >= 3'd1) : (io_sync_cnt >= 3'd2))
               io_synced <= 1'b1;
         end
      end
   end
end

assign      _cpuVPA = (cpuFC == 3'b111) ? 1'b0 : ~(!_cpuAS && selectVIA);

// Turbo Mode Clock & DTACK Logic:
// configTurbo = 0: Off (Stock 7.8336 MHz)
// configTurbo != 0: Turbo (19.584 MHz nominal, 2.50x speedup)
// If hw_turbo_ovr is asserted by software, software controls turbo; otherwise follow configTurbo.
wire effective_turbo = hw_turbo_ovr ? hw_turbo_en : (configTurbo != 2'b00);
wire cpu_turbo_active = effective_turbo;

// -------------------------------------------------------------------------
// CPU Clock Enable & Turbo Mode Generator
// -------------------------------------------------------------------------
// In Stock Mode (configTurbo == 0):
//   clk_cpu is clk_pixel (15.6672 MHz) via DCS in top.sv.
//   enPhi1 is clk8_en_p (Phase 1, 3, 5, 7)
//   enPhi2 is clk8_en_n (Phase 0, 2, 4, 6)
// In Turbo Mode (configTurbo != 0):
//   clk_cpu is clk_cpu_raw (39.168 MHz) via DCS in top.sv.
//   enPhi1 and enPhi2 alternate every cycle -> 19.584 MHz (2.50x nominal speedup)
reg turbo_phase = 1'b0;
always @(posedge clk_cpu) begin
    if (!cpu_turbo_active) begin
        // Keep turbo_phase aligned with Stock mode Phase 7:
        // When turbo_synced activates at Phase 7, the first cycle into Phase 0
        // toggles from 1 to 0 -> turbo_enPhi2 = 1, ensuring seamless alternation.
        turbo_phase <= 1'b1;
    end else begin
        turbo_phase <= !turbo_phase;
    end
end

wire turbo_enPhi1 = turbo_phase;
wire turbo_enPhi2 = !turbo_phase;

wire gen_enPhi1 = cpu_turbo_active ? turbo_enPhi1 : clk8_en_p;
wire gen_enPhi2 = cpu_turbo_active ? turbo_enPhi2 : clk8_en_n;

assign enPhi1_raw = gen_enPhi1;
assign enPhi2_raw = gen_enPhi2;
assign      _cpuAS_probe = _cpuAS;
assign      cache_hit_probe = cache_hit;
assign      cache_en_probe  = cache_cacheable;
assign      osd_cache_probe   = configCache;
assign      cache_sweep_probe = cache_in_sweep;

// -------------------------------------------------------------------------
// VIA 6522 E-Clock Strobe Synchronizer
// -------------------------------------------------------------------------
// In Stock Mode: fx68k.E_PosClkEn / fx68k.E_NegClkEn are directly on clk_sys.
// In Turbo Mode: fx68k is on clk_cpu (39.168 MHz), so toggle synchronizer bridges
// the single-cycle E-clock phase enables cleanly into the clk_sys domain.
wire fx68k_e_pos, fx68k_e_neg;

reg e_pos_toggle = 1'b0;
reg e_neg_toggle = 1'b0;
always @(posedge clk_cpu or negedge _cpuReset) begin
    if (!_cpuReset) begin
        e_pos_toggle <= 1'b0;
        e_neg_toggle <= 1'b0;
    end else begin
        if (fx68k_e_pos) e_pos_toggle <= ~e_pos_toggle;
        if (fx68k_e_neg) e_neg_toggle <= ~e_neg_toggle;
    end
end

reg [2:0] e_pos_sync = 3'b000;
reg [2:0] e_neg_sync = 3'b000;
always @(posedge clk_sys or negedge _cpuReset) begin
    if (!_cpuReset) begin
        e_pos_sync <= 3'b000;
        e_neg_sync <= 3'b000;
    end else begin
        e_pos_sync <= {e_pos_sync[1:0], e_pos_toggle};
        e_neg_sync <= {e_neg_sync[1:0], e_neg_toggle};
    end
end

wire turbo_e_rising  = (e_neg_sync[2] ^ e_neg_sync[1]);
wire turbo_e_falling = (e_pos_sync[2] ^ e_pos_sync[1]);

wire via_e_rising  = cpu_turbo_active ? turbo_e_rising  : fx68k_e_neg;
wire via_e_falling = cpu_turbo_active ? turbo_e_falling : fx68k_e_pos;

// -------------------------------------------------------------------------
// Fixed 783.36 kHz VIA Timer Tick Generator
// -------------------------------------------------------------------------
// In both Stock (7.83 MHz) and Turbo (19.58 MHz) modes, the 6522 VIA timers
// (Timer 1 and Timer 2) must decrement at the standard 783.36 kHz rate.
// clk_sys is 15.6672 MHz. 15.6672 MHz / 20 = 783.36 kHz.
reg [4:0] via_timer_div = 5'd0;
reg via_timer_tick = 1'b0;

always @(posedge clk_sys or negedge _cpuReset) begin
    if (!_cpuReset) begin
        via_timer_div  <= 5'd0;
        via_timer_tick <= 1'b0;
    end else begin
        if (via_timer_div == 5'd19) begin
            via_timer_div  <= 5'd0;
            via_timer_tick <= 1'b1;
        end else begin
            via_timer_div  <= via_timer_div + 5'd1;
            via_timer_tick <= 1'b0;
        end
    end
end

assign mac_probes = {
    cpuAddr[23:1], 1'b0, // [47:24] 24-bit CPU address
    _cpuVMA,             // [23]
    _cpuVPA,             // [22]
    selectVIA,           // [21]
    selectROM,           // [20]
    selectRAM,           // [19]
    refreshCycle,        // [18]
    loadSound,           // [17]
    loadPixels,          // [16]
    videoBusControl,     // [15]
    cpuBusControl,       // [14]
    cpu_slot,            // [13]
    rom_req,             // [12]
    ram_req,             // [11]
    _cpuDTACK,           // [10]
    _cpuRW,              // [9]
    _cpuLDS,             // [8]
    _cpuUDS,             // [7]
    _cpuAS,              // [6]
    cpu_turbo_active,    // [5]
    enPhi2_gated,        // [4]
    enPhi1_gated,        // [3]
    busPhase[2:0]        // [2:0]
};

// -------------------------------------------------------------------------
// BRAM Cache — 2KB direct-mapped, write-through (historical 68030 approach)
// -------------------------------------------------------------------------
// cacheable: ROM and RAM only; disabled during memory overlay boot window
// cacheable: OSD or CSR enable, ROM/RAM only, overlay off
// While the tag-invalidation sweep (declared below) runs the tag array is
// being cleared, so the cache must not serve hits or accept fills: on cold
// boot the FPGA BRAM starts with RANDOM contents, and a stale valid+tag in
// a not-yet-swept line aliases a live address -> false hit -> the boot ROM
// reads garbage in its first ~1024 grid cycles -> stripey-bars crash.
wire cache_in_sweep = (cache_inv_cnt != 11'd0);
wire        cache_cacheable = (configCache || hw_cache_en) && (selectROM || selectRAM) &&
                              !memoryOverlayOn && !cache_in_sweep;

// CPU RAM write invalidate -> invalidate the line just written.
// Phase-2 gated pulse (the form proven on the board at 631431f): at
// busPhase==2, _cpuAS is already asserted so cpuAddr holds the write
// address (stable through the whole request). The 996f7f8 "delayed"
// variant (posedge after sdram_we&&ram_req) proved wrong on the board
// (RAM test failure 0200F8): on a 63.8ns grid cycle a 204ns write request
// straddles grid edges and the next posedge's cpuAddr can belong to an
// already-terminated cycle. Known gap: this is phase-aligned, so in
// turbo (~half the write requests don't overlap phase 2) it misses
// invalidations - to be reworked once stock is green.
wire        cache_wr_evt   = !_cpuRW && selectRAM && !_cpuAS && (busPhase == 3'd2);
wire        cache_wr_pulse = cache_wr_evt;

wire        cache_hit;
wire [15:0] cache_data;
assign      cache_data_dbg = cache_data;
assign      cpu_data_in_dbg = dataControllerDataOut; // iEdb: what the 68k latches

// Invalidate-all sweep: at power-on (BRAM contents are random on the FPGA,
// a stale valid+tag could alias a live address) and whenever the cache is
// enabled at runtime (cleared-by-reset hw regs could alias stale lines).
// 1024 posedge cycles to sweep the whole tag array.
reg [10:0] cache_inv_cnt = 11'd0;
reg        reset_hi_d = 1'b0;
reg        cache_en_d = 1'b0;
wire       cache_en_cfg = configCache || hw_cache_en;
always @(posedge clk_sys) begin
    reset_hi_d <= _cpuReset;
    cache_en_d <= cache_en_cfg;
end
wire cache_inv_start = _cpuReset && ((_cpuReset && !reset_hi_d) || (cache_en_cfg && !cache_en_d));
always @(posedge clk_sys or negedge _cpuReset) begin
    if (!_cpuReset)
        cache_inv_cnt <= 11'd0;
    else if (cache_inv_start)
        cache_inv_cnt <= 11'd1;
    else if (cache_inv_cnt != 11'd0 && cache_inv_cnt < 11'd1024)
        cache_inv_cnt <= cache_inv_cnt + 11'd1;
    else if (cache_inv_cnt == 11'd1024)
        cache_inv_cnt <= 11'd0;
end
wire cache_invalidate_all = (cache_inv_cnt != 11'd0); // high for cnt=1..1024 (1024 lines)

bram_cache cache0 (
    .clk_sys      ( clk_sys           ),
    .reset_n      ( _cpuReset         ),
    .invalidate_all ( cache_invalidate_all ),
    .cpu_addr     ( cpuAddr           ),
    .cacheable    ( cache_cacheable   ),
    .rom_req      ( rom_req           ),
    .ram_req      ( ram_req           ),
    .cpu_wr_pulse ( cache_wr_pulse    ),
    .cpu_wr_addr  ( cpuAddr           ),
    .fill_pulse   ( cache_fill_pulse  ),
    .fill_addr    ( fill_addr         ),
    .fill_data    ( cache_fill_data   ),
    .cache_hit    ( cache_hit         ),
    .cache_data   ( cache_data        )
);

// DTACK completion conditions:
// Cache hit (Phase 3): asserts one cycle earlier than normal in both modes.
// Stock Mode (7.83 MHz): DTACK at Phase 4 on miss (unchanged).
// Turbo Mode (19.58 MHz): DTACK at Phase 7 on miss (unchanged).
// All other non-VIA accesses (and non-IACK) wait for io_done.
wire ram_done = cache_hit || (cpu_turbo_active ? (busPhase >= 3'd7) : (busPhase >= 3'd4));
wire rom_done = cache_hit || (cpu_turbo_active ? (busPhase >= 3'd7) : (busPhase >= 3'd4));
wire io_done  = cpu_turbo_active ? io_synced : 1'b1;

// _cpuDTACK_int is the computed signal; also used by fill_pulse to detect
// the exact cycle when miss data becomes valid (DTACK falling edge).
wire _cpuDTACK_int = ~((!_cpuAS && ram_req && ram_done) ||
                       (!_cpuAS && rom_req && rom_done) ||
                       (!_cpuAS && (cpuFC != 3'b111) && !selectVIA && !selectRAM && !selectROM && io_done));
assign _cpuDTACK = _cpuDTACK_int;

// ---------------------------------------------------------------------------
// Cache miss fill + hit/miss/fill statistics  (E-cycle based / phase-agnostic)
// ---------------------------------------------------------------------------
// NOTE: fx68k.eRWn is /RW (active LOW): _cpuRW==1 means READ, ==0 means WRITE.
//
// In turbo mode the CPU E-cycle (2.5 busPhase grid slots) is NOT aligned to
// any fixed phase (the 15.667MHz phase grid and the 39.168MHz E-cycles are
// phase-locked 5:2), so fixed-phase latches (req@2, miss@3, fill@6, count@7)
// misfire. Everything below is keyed on level/edge events instead:
//   * RAM fill   : sdram_rd_done (the SDRAM FSM's own data-valid pulse) with
//                  an address match to the in-flight miss. In stock mode this
//                  is phase 6 (the old FILLPH=6) -- behavior unchanged.
//   * ROM fill   : rising edge of the miss-DTACK condition, i.e. the exact
//                  moment the 68k latches romDataMod.
//   * write-invalidate : /AS-assert edge of a cacheable RAM write.
//   * counters   : 0->1 edges of the hit / miss level conditions.
// ---------------------------------------------------------------------------
wire cacheable_rd = cache_cacheable && !_cpuAS && _cpuRW && (ram_req || rom_req);

// Miss tracking: valid from the first grid cycle of a cacheable read until
// the next cycle starts (/AS re-assert) or a write to the same word lands
// (write-through invalidation supersedes the pending fill).
reg        miss_pending;
reg [23:1] miss_addr;
always @(posedge clk_sys or negedge _cpuReset or posedge _cpuAS) begin
    if (!_cpuReset)
        miss_pending <= 1'b0;
    else if (_cpuAS)                 // new cycle starts: previous is over
        miss_pending <= 1'b0;
    else if (cacheable_rd && !cache_hit &&
             !(cache_wr_evt && (miss_addr == cpuAddr)))
        miss_pending <= 1'b1;
end
always @(posedge clk_sys or negedge _cpuReset) begin
    if (!_cpuReset)
        miss_addr <= 23'b0;
    else if (cacheable_rd && !cache_hit)
        miss_addr <= cpuAddr;
end

// --- RAM fill: sdram_rd_done is the SDRAM FSM's read-data-valid pulse (clk_sys
// domain). The FSM read the word identified by sdram_rd_addr (21-bit CPU
// word address = cpuAddr[21:1], de-mapped at the instantiation); fill that
// line if it matches the in-flight miss (1-word lines: line == word address).
wire ram_fill_evt = sdram_rd_done && miss_pending &&
                    (sdram_rd_addr == miss_addr[21:1]);

// --- ROM fill: rising edge of the ROM miss-DTACK condition. At that edge
// the 68k latches romDataMod and /AS is still low (cpuAddr stable).
wire rom_miss_dtack = cacheable_rd && rom_req && rom_done && !cache_hit;
reg        rom_md_prev = 1'b0;
always @(posedge clk_sys or negedge _cpuReset) begin
    if (!_cpuReset)
        rom_md_prev <= 1'b0;
    else
        rom_md_prev <= rom_miss_dtack;
end
wire rom_fill_evt = rom_miss_dtack && !rom_md_prev;

reg        cache_fill_pulse;
reg [15:0] cache_fill_data;
reg [23:1] fill_addr;
reg        fill_is_rom;
always @(posedge clk_sys) begin
    if (ram_fill_evt) begin
        cache_fill_pulse <= 1'b1;
        cache_fill_data  <= sdram_do;      // == rd data, rd_addr matched
        fill_addr        <= {2'b0, sdram_rd_addr}; // 21-bit CPU word addr -> [23:1]
        fill_is_rom      <= 1'b0;
    end else if (rom_fill_evt) begin
        cache_fill_pulse <= 1'b1;
        cache_fill_data  <= romDataMod;    // word the CPU latches
        fill_addr        <= cpuAddr;
        fill_is_rom      <= 1'b1;
    end else begin
        cache_fill_pulse <= 1'b0;
    end
end

// Last-fill snapshot (readout via $F8001C)
reg [23:1] last_fill_addr_r;
reg        last_fill_is_rom_r;
always @(posedge clk_sys) begin
    if (cache_fill_pulse) begin
        last_fill_addr_r   <= fill_addr;
        last_fill_is_rom_r <= fill_is_rom;
    end
end
assign last_fill_addr   = last_fill_addr_r;
assign last_fill_is_rom = last_fill_is_rom_r;

// Hit / miss counters: 0->1 edges of the level conditions (one count per
// cycle, since both conditions are low outside a cycle).
wire cyc_hit_cnd  = cacheable_rd &&  cache_hit;
wire cyc_miss_cnd = cacheable_rd && !cache_hit;
reg  hit_prev = 1'b0, miss_prev = 1'b0;
always @(posedge clk_sys or negedge _cpuReset) begin
    if (!_cpuReset) begin
        hit_prev  <= 1'b0;
        miss_prev <= 1'b0;
    end else begin
        hit_prev  <= cyc_hit_cnd;
        miss_prev <= cyc_miss_cnd;
    end
end
wire hit_evt  = cyc_hit_cnd  && !hit_prev;
wire miss_evt = cyc_miss_cnd && !miss_prev;

// Saturating counters (outputs driven by *_r registers).
// Cleared by writing 0x55xx to $F80010 (the hits slot, idx 4).
reg [15:0] cache_hits_r   = 16'd0;
reg [15:0] cache_misses_r = 16'd0;
reg [15:0] cache_fills_r  = 16'd0;
assign cache_hits   = cache_hits_r;
assign cache_misses = cache_misses_r;
assign cache_fills  = cache_fills_r;
// cpuAddr is [23:1] (A0 not present): $F80010 => A5=1, A4/A3/A2/A1=0
// $F80010 (hits slot, reg-index 4): A4=1, A3=0, A2=0.
// cpuAddr[23:1] has cpuAddr[3]=A4, cpuAddr[2]=A3, cpuAddr[1]=A2 (no A1/A0).
wire cache_clr = selectHardwareRegs && !_cpuAS && !_cpuRW && !_cpuLDS &&
                 (cpuAddr[3]) && (cpuAddr[2:1] == 2'b00) &&
                 (cpuDataOut[15:8] == 8'h55) ||
                 (ice_poke_valid && (ice_poke_idx == 3'd4) && (ice_poke_data[15:8] == 8'h55));
always @(posedge clk_sys or negedge _cpuReset) begin
    if (!_cpuReset || cache_clr) begin
        cache_hits_r   <= 16'd0;
        cache_misses_r <= 16'd0;
    end else begin
        if (hit_evt  && (cache_hits_r   != 16'hFFFF))
            cache_hits_r   <= cache_hits_r   + 1'b1;
        if (miss_evt && (cache_misses_r != 16'hFFFF))
            cache_misses_r <= cache_misses_r + 1'b1;
    end
end

always @(posedge clk_sys or negedge _cpuReset) begin
    if (!_cpuReset || cache_clr)
        cache_fills_r <= 16'd0;
    else if (cache_fill_pulse && (cache_fills_r != 16'hFFFF))
        cache_fills_r <= cache_fills_r + 1'b1;
end

fx68k fx68k (
	.clk        ( clk_cpu ),
	.extReset   ( (!_cpuReset) || cpu_reset_override ),
	.pwrUp      ( (!_cpuReset) || cpu_reset_override ),
	.enPhi1     ( enPhi1_gated ),
	.enPhi2     ( enPhi2_gated ),

	.eRWn       ( _cpuRW ),
	.ASn        ( _cpuAS ),
	.LDSn       ( _cpuLDS ),
	.UDSn       ( _cpuUDS ),
	.E          ( ),
	.E_div      ( 1'b0 ),
	.E_PosClkEn ( fx68k_e_pos ),
	.E_NegClkEn ( fx68k_e_neg ),
	.VMAn       ( _cpuVMA ),
	.FC0        ( cpuFC[0] ),
	.FC1        ( cpuFC[1] ),
	.FC2        ( cpuFC[2] ),
	.BGn        ( ),
	.oRESETn    ( _cpuReset_o ),
	.oHALTEDn   ( ),
	.DTACKn     ( _cpuDTACK ),
	.VPAn       ( _cpuVPA ),
	.HALTn      ( 1'b1 ),
	.BERRn      ( 1'b1 ),
	.BRn        ( 1'b1 ),
	.BGACKn     ( 1'b1 ),
	.IPL0n      ( _cpuIPL[0] ),
	.IPL1n      ( _cpuIPL[1] ),
	.IPL2n      ( _cpuIPL[2] ),
	.iEdb       ( dataControllerDataOut ),
	.oEdb       ( cpuDataOut ),
	.eab        ( cpuAddr )
);

addrController ac0
(
	.clk(clk_sys),
	.clk8_en_p(clk8_en_p),
	.clk8_en_n(clk8_en_n),
	.cpuAddr(cpuAddr), 
	._cpuUDS(_cpuUDS),
	._cpuLDS(_cpuLDS),
	._cpuRW(_cpuRW),
	._cpuAS(_cpuAS),
	.configROMSize({configMachineType,~configMachineType}),
	.configRAMSize(configRAMSize), 
	.romAddr(romAddr),
	.ramAddr(ram_addr),
	._memoryUDS(_memoryUDS),
	._memoryLDS(_memoryLDS),
	._romOE(_romOE), 
	._ramOE(_ramOE), 
	._ramWE(_ramWE),
	.videoBusControl(videoBusControl),	
	.cpuBusControl(cpuBusControl),	
	.cycleReady(busPhase == 3'd7),
	.selectSCSI(selectSCSI),
	.selectSCC(selectSCC),
	.selectIWM(selectIWM),
	.selectVIA(selectVIA),
	.selectRAM(selectRAM),
	.selectROM(selectROM),
	.selectSEOverlay(selectSEOverlay),
	.selectHardwareRegs(selectHardwareRegs),
	.hsync(hsync), 
	.vsync(vsync),
	._hblank(_hblank),
	._vblank(_vblank),
	.loadPixels(loadPixels),
	.vid_alt(vid_alt),
	.memoryOverlayOn(memoryOverlayOn),
	.refresh(refreshCycle),

	.snd_alt(snd_alt),
	.loadSound(loadSound)
);

/* fastboot patches the rom check and the ramcheck away */
wire [15:0] romDataMod =
	    configFastboot?romDataPatched:
	    romData;   

wire	    trigger = (cpuAddr == 0);   
   
wire [15:0] romDataPatched =
	    ({ romAddr, 1'b0 } == 18'hd7a)?16'h6022:   // 7000, disable rom checksum test
	    ({ romAddr, 1'b0 } == 18'hea8)?16'h4e71:   // 6EEC, shorten ram test read
	    ({ romAddr, 1'b0 } == 18'he90)?16'h4e71:   // 6AF0, shorten ram test write
	    romData;
   
dataController #(SCSI_DEVS) dc0
(
	.clk(clk_sys), 
	.clk8_en_p(clk8_en_p),
	.clk8_en_n(clk8_en_n),
	.E_rising(via_e_rising),
	.E_falling(via_e_falling),
	.timer_tick(via_timer_tick),
	.machineType(configMachineType),
	.floppy_wprot(configFloppyWProt),
	.scsi_wprot(configSCSIWProt),
	._systemReset(n_reset),
	._cpuReset(_cpuReset), 
	._cpuIPL(_cpuIPL),
	._cpuUDS(_cpuUDS), 
	._cpuLDS(_cpuLDS), 
	._cpuRW(_cpuRW), 
	._cpuAS(_cpuAS),
	._cpuVMA(_cpuVMA),
	.cpuDataIn(cpuDataOut),
	.cpuDataOut(dataControllerDataOut), 	
	.cpuAddrRegHi(cpuAddr[12:9]),
	.cpuAddrRegMid(cpuAddr[6:4]),  // for SCSI
	.cpuAddrRegLo(cpuAddr[2:1]),
	.cpuAddrRegA3(cpuAddr[3]),
	.selectSCSI(selectSCSI),
	.selectSCC(selectSCC),
	.selectIWM(selectIWM),
	.selectVIA(selectVIA),
	.selectSEOverlay(selectSEOverlay),
	.selectHardwareRegs(selectHardwareRegs),
	.cpu_turbo_active(cpu_turbo_active),
	.hw_turbo_en(hw_turbo_en),
	.hw_turbo_ovr(hw_turbo_ovr),
	.hw_cache_en(hw_cache_en),
	.hw_fillph_turbo(hw_fillph_turbo),
	.cache_hits(cache_hits),
	.cache_misses(cache_misses),
	.cache_fills(cache_fills),
	.last_fill_addr(last_fill_addr_r),
	.last_fill_is_rom(last_fill_is_rom_r),
	.ice_poke_valid(ice_poke_valid),
	.ice_poke_idx(ice_poke_idx),
	.ice_poke_data(ice_poke_data),
	.ice_peek_data(ice_peek_data),
	.ice_peek_req(ice_peek_req),
	.ice_peek_idx(ice_peek_idx),
	.cpuBusControl(cpuBusControl),
	.videoBusControl(videoBusControl),
	.cycleReady(busPhase == 3'd7),
	.memoryDataOut(sdram_din),
        .romSel(!_romOE), 
	.ramDataIn( (cache_hit && ram_req) ? cache_data : sdram_do   ),
	.romDataIn( (cache_hit && rom_req) ? cache_data : romDataMod ),

        // interface to sd card
	.sdc_img_mounted( sdc_image_mounted ),
	.sdc_img_size( sdc_image_size ),
        .sdc_lba     ( sdc_lba      ),
	.sdc_rd      ( sdc_rd       ),
	.sdc_wr      ( sdc_wr       ),
	.sdc_busy    ( sdc_busy     ),
	.sdc_done    ( sdc_done     ),
	.sdc_data_in ( sdc_data_in  ),
        .sdc_data_out( sdc_data_out ),
	.sdc_data_en ( sdc_data_en  ),
	.sdc_addr    ( sdc_addr     ),
	 
	// peripherals
	.mouse(MOUSE),
        .kbd_strobe(kbd_strobe),
	.kbd_data(kbd_data),
 
	// serial uart
	.serialIn(serialIn),
	.serialOut(serialOut),
	.serialCTS(serialCTS),
	.serialRTS(serialRTS),

	// rtc unix ticks
	.timestamp(TIMESTAMP),

	// video
	._hblank(_hblank),
	._vblank(_vblank), 
	.pixelOut(pixel),
	.loadPixels(loadPixels),
	.vid_alt(vid_alt),

	.memoryOverlayOn(memoryOverlayOn),

	.audioOut(audio),
	.snd_alt(snd_alt),
	.loadSound(loadSound),

	// floppy disk interface
	.diskLED(leds)
);

////////////////////////// SDRAM /////////////////////////////////

assign sdram_ds   = { !_memoryUDS, !_memoryLDS };
assign sdram_we   = !_ramWE;
assign sdram_oe   = !_ramOE;

endmodule

module addrController (
	// clocks:
	input	      clk,
	input	      clk8_en_p,
	input	      clk8_en_n,

	input	      videoBusControl,
	input	      cpuBusControl,
	input	      cycleReady,
			  
	// system config:
	input [1:0]   configROMSize, // 0 = 64K ROM, 1 = 128K ROM, 2 = 256K ROM
	input [1:0]   configRAMSize, // 0 = 128K, 1 = 512K, 2 = 1MB, 3 = 4MB RAM

	// 68000 CPU memory interface:
	input [23:1]  cpuAddr,
	input	      _cpuUDS,
	input	      _cpuLDS,
	input	      _cpuRW, 
	input	      _cpuAS,
	
	// RAM/ROM:
	output [17:0] romAddr,
	output [20:0] ramAddr,
	output	      _memoryUDS,
	output	      _memoryLDS, 
	output	      _romOE,
	output	      _ramOE, 
	output	      _ramWE, 
	
	// peripherals:
	output	      selectSCSI,
	output	      selectSCC,
	output	      selectIWM,
	output	      selectVIA,
	output	      selectRAM,
	output	      selectROM,
	output	      selectSEOverlay,
	output	      selectHardwareRegs,
	
	// video:
	output	      hsync,
	output	      vsync,
	output	      _hblank,
	output	      _vblank,
	output	      loadPixels,
	input	      vid_alt,
		
	input	      snd_alt,
	output	      loadSound,
		
	// debug/test: drop ALL video/audio SDRAM fetches (hw poke $F80008 bit3).
	// Makes a true "display-off" test possible (no OSD video-off exists;
	// unplugging HDMI does not stop the DMA).
	input	      video_dma_off,
		
	// misc
	input	      memoryOverlayOn,
	output	      refresh
);

	// -------------- audio engine (may be moved into seperate module) ---------------

        // A new audio byte is read at the end of each hblank. Each hblank thus raises
        // the sndReq which in turn activates the request for a full video cycle to be
        // used for audio transfer
        reg sndReq, sndReqCycle;   
	assign loadSound = videoBusControl & sndReqCycle;

	reg [20:0] audioAddr;
	reg vblankD, hblankD;
	always @(posedge clk) begin
	        if(cycleReady) begin
	                sndReqCycle <= sndReq;
	                // (loadSound is already 0 on collision ticks after the
	                // Option-A gate below -> the byte is simply re-sampled
	                // on the next fetch: a smooth double sample, no gap)
	                if(loadSound) begin
	   sndReq <= 1'b0;
	   audioAddr <= audioAddr + 21'd1;
	  end
	 end
	   
		if(clk8_en_p) begin	   
			vblankD <= _vblank;
			hblankD <= _hblank;
		
			// falling adge of _vblank = begin of vblank phase
			if(vblankD && !_vblank)
				audioAddr <= snd_alt?21'h1FD080:21'h1FFE80;
		        // falling edge of _hblank = audio cycle
			else if(hblankD && !_hblank)
			        sndReq <= 1'b1; // request next audio byte
		   
		end
	end

	// interconnects
	wire [20:0] videoAddr;
		
	       // cpu is allowed to access rom anytime
	       assign _romOE = ~(selectROM && _cpuRW);

	       // ------------------------------------------------------------------
	       // Phase-2 SDRAM fetch-slot arbitration (Option A, 2026-11-03):
	       // The SDRAM FSM (sdram.v) accepts EXACTLY ONE request per phase-2
	       // tick. Historically the video/audio demand won the slot (addrMux
	       // priority), so a CPU RAM read/write whose address-valid moment
	       // landed on a phase-2 tick inside a video half (loadPixels=1) was
	       // never fetched: the FSM read the video framebuffer word and the
	       // 68k latched it as if it were the CPU's data. Board evidence:
	       // the $00003E vector read in hang.vcd was never serviced
	       // (SADR walked the video RAM instead of 00001F) -> hard hang.
	       //
	       // Fix: when the CPU has an address-valid RAM access
	       // (selectRAM && !_cpuAS) the CPU owns the slot; the video pixel
	       // fetch (and audio byte fetch) for that one E-cycle is dropped.
	       // Video loses at most one 16-bit pixel word per collision
	       // (invisible: the shifter just shifts an extra blank bit, the
	       // next word arrives re-aligned); audio loses at most one byte
	       // per collision (re-sampled next fetch, inaudible). The CPU is
	       // always serviced, so neither a poisoned read nor a dropped
	       // cache fill can happen any more.
	       // ------------------------------------------------------------------
	       wire cpu_mem_acc = selectRAM && !_cpuAS;   // CPU RAM access address-valid
	       wire lpx = loadPixels && !cpu_mem_acc && !video_dma_off; // effective video fetch
	       wire lsnd = loadSound  && !cpu_mem_acc && !video_dma_off; // effective audio fetch

	       // ram is being used for video or audio access
	       wire va_ram_access = videoBusControl && (lpx || lsnd);
	       // CPU gets the slot when it controls the half, or when a video
	       // half has no (effective) DMA demand, or now ALWAYS when the CPU
	       // has a RAM access (cpu_mem_acc => lpx/lsnd are both 0 by the
	       // definitions above, so this is what makes the CPU win).
	       wire cpu_ram_access = selectRAM & (cpuBusControl || (videoBusControl && !lpx && !lsnd));

	assign _ramOE = ~((cpu_ram_access &&  _cpuRW) || va_ram_access);
	assign _ramWE = ~( cpu_ram_access && !_cpuRW);
	
	assign _memoryUDS = va_ram_access?1'b0:_cpuUDS;
	assign _memoryLDS = va_ram_access?1'b0:_cpuLDS;

	       // three sources may address ram: video, audio or CPU (CPU wins ties)
	wire [20:0] addrMux = lpx?videoAddr:lsnd?audioAddr:cpuAddr[21:1];

	// simulate smaller RAM/ROM sizes
	assign ramAddr = { configRAMSize != 2'b11   ? 2'b00 : addrMux[20:19],  // force A20/A19 to 0 for all but 4MB RAM access
			   configRAMSize[1] == 1'b0 ?  1'b0 :    addrMux[18],  // force A18 to 0 for 128K or 512K RAM access
			   configRAMSize == 2'b00   ? 2'b00 : addrMux[17:16],  // force A17/A16 to 0 for 128K RAM access
			   addrMux[15:0] };
   
        assign romAddr = { configROMSize != 2'b11 ? 1'b0 : cpuAddr[18],  // force A18 to 0 for 64K/128K/256K ROM access
			   configROMSize == 2'b01 ? 1'b0 :               // force A17 to 0 for 128K ROM access
			   configROMSize == 2'b00 ? 1'b1 : cpuAddr[17],  // force A17 to 1 for 64K ROM access (64K ROM image is at $20000)
			   configROMSize == 2'b00 ? 1'b0 : cpuAddr[16],  // force A16 to 0 for 64K ROM access
			   cpuAddr[15:1] };   
    
	// address decoding
	addrDecoder ad(
		.configROMSize(configROMSize),
		.address(cpuAddr),
		._cpuAS(_cpuAS),
		.memoryOverlayOn(memoryOverlayOn),
		.selectRAM(selectRAM),
		.selectROM(selectROM),
		.selectSCSI(selectSCSI),
		.selectSCC(selectSCC),
		.selectIWM(selectIWM),
		.selectVIA(selectVIA),
		.selectSEOverlay(selectSEOverlay),
		.selectHardwareRegs(selectHardwareRegs));

	// video
	videoTimer vt(
		.clk(clk),
		.clk8_en_p(clk8_en_p),
		.clk8_en_n(clk8_en_n),
		.videoCycle(videoBusControl), 
		.vid_alt(vid_alt),
		.videoAddr(videoAddr), 
		.hsync(hsync), 
		.vsync(vsync), 
		._hblank(_hblank),
		._vblank(_vblank), 
		.refresh(refresh), 
		.loadPixels(loadPixels));
		
endmodule

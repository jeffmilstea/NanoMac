// videoFifo.sv
//
// Option B: lossless video via a run-ahead prefetch FIFO (2026-11-05).
//
// The video pipeline is LOCKSTEP (measured): a video word is fetched from
// SDRAM at phase 2 of its 16-tick slot, data returns (rd_done) at phase 6,
// and the videoShifter loads it at phase 7 (loadPixels & cycleReady) -- the
// word is fetched AND consumed in the same slot. With Option A (the CPU wins
// the SDRAM slot while it has an address-valid RAM access), a colliding video
// word is DROPPED (lpx=0) while the shifter still loads (it has no word
// memory) -> the line desyncs -> the board's full-screen 50/50 tear.
//
// This module decouples the video FETCH from the video DISPLAY:
//   * A prefetch pointer runs AHEAD of the display (up to RUNAHEAD words)
//     and the arbiter issues one SDRAM read per free phase-2 slot while the
//     FIFO is below TARGET and the pointer is within RUNAHEAD of the display.
//   * The shifter drains the FIFO at the fixed display cadence (1 word per
//     visible 16-tick slot). A CPU collision only dips the FILL rate; the
//     FIFO headroom absorbs it, so no word is ever dropped/duplicated and
//     the shifter never desyncs -> lossless.
//   * Lossless guarantee: when the FIFO drains to HALL or less, `halt`
//     freezes the videoTimer (xpos hold) + the shifter load, so the display
//     waits for the prefetcher to catch up (a short frozen line) instead of
//     showing garbage. The stream is a single in-order FIFO, so resuming
//     never desyncs.
//
// Word stream: within the visible field the framebuffer words are sequential
//   word index = ypos*32 + (xpos>>4)      (512 px / 16 px per word = 32/line)
//   at base BASE (videoTimer.v:62, vid_alt=0: 0x1FD380-0x4000 = 0x1F9380).
//
// This module does NOT drive the SDRAM directly; it exposes `pf_addr` and
// `pf_want`. A small arbiter (see macplus.sv) grants it the phase-2 slot
// when free (CPU wins per Option A) and latches whether the in-flight read
// is a video prefetch so only video words are pushed here.

module videoFifo (
    input             clk,        // clk_sys (16 MHz)
    input             reset,      // active-high

    // display position (from the videoTimer)
    input  [8:0]      xpos,
    input  [8:0]      ypos,
    input             vblank,     // 1 during vertical blank (no video words)

    // back-pressure (frozen upstream: videoTimer xpos-hold + shifter load gate)
    output            halt,       // 1 when the FIFO is low (display must wait)

    // prefetch request (granted by the arbiter when a slot is free)
    output            pf_want,    // FIFO wants a prefetch read
    output [20:0]     pf_addr,    // run-ahead video word address

    // FIFO push (a video word returned from the SDRAM)
    input             push,       // 1 tick: video_rd_done
    input  [15:0]     push_data,

    // FIFO drain (the shifter takes the head word)
    input             pop,        // 1 tick: shifter load edge
    output [15:0]     data_out,   // FIFO head
    output            empty,      // depth == 0 (shifter must not pop)
    output [7:0]      depth       // current occupancy (debug/ILA)
);

    localparam DEPTH_LOG2 = 7;               // 128 entries (2Kbit, 1 SDPB)
    localparam DEPTH      = 1 << DEPTH_LOG2;
    localparam TARGET     = 64;              // stop prefetching at this depth
    localparam RUNAHEAD   = 64;              // = TARGET: words ahead of display
    localparam HALL       = 2;               // halt (freeze display) at this depth
    localparam LINES      = 342;             // visible lines
    localparam WPL        = 5;               // log2(words per line = 32)
    localparam FRAMESIZE  = LINES << WPL;    // 10944 words per visible field
    localparam [20:0] BASE = 21'h1F9380;     // framebuffer base word (vid_alt=0)

    // ---- FIFO storage ----
    reg  [15:0] mem [0:DEPTH-1];
    reg  [DEPTH_LOG2-1:0] head, tail;
    reg  [7:0]  depth_r = 8'd0;              // 0..128
    assign depth = depth_r;

    assign empty    = (depth_r == 8'd0);
    assign data_out = mem[head];

    always @(posedge clk) begin
        if (reset) begin
            head    <= '0;
            tail    <= '0;
            depth_r <= 8'd0;
        end else begin
            if (push) begin
                mem[tail] <= push_data;
                tail      <= tail + 1'b1;
            end
            if (pop && !empty)
                head <= head + 1'b1;
            // depth accounting (push and pop can coincide)
            if (push && pop)
                depth_r <= depth_r;
            else if (push)
                depth_r <= depth_r + 8'd1;
            else if (pop && !empty)
                depth_r <= depth_r - 8'd1;
        end
    end

    // ---- display position -> visible word index ----
    wire [13:0] disp_idx = ( {5'd0, ypos} << WPL ) + ( {5'd0, xpos} >> 4 );
    wire [13:0] idx_mod = (disp_idx < FRAMESIZE[13:0]) ? disp_idx
                                                       : FRAMESIZE[13:0] - 1;

    // ---- prefetch pointer: next word to request ----
    // Prefetch runs in visible time AND during vblank (the frame wrap sends
    // the pointer back to word 0, so the FIFO is prefilled before the next
    // frame's first line starts draining).
    reg  [13:0] pf_idx = 14'd0;

    // ahead distance = (pf_idx - idx_mod) mod FRAMESIZE, in [0,FRAMESIZE)
    wire [13:0] ahead = (pf_idx >= idx_mod) ? (pf_idx - idx_mod)
                                            : (pf_idx + FRAMESIZE[13:0] - idx_mod);
    wire ahead_ok = (ahead <= RUNAHEAD[13:0]);

    // back-pressure: freeze the display (videoTimer xpos-hold + shifter load
    // gate) when the FIFO is nearly empty, so the display WAITS for the
    // prefetcher instead of popping stale/absent words. This is the
    // lossless guarantee: a low FIFO costs a frozen line, never a tear.
    assign halt    = (depth <= HALL[7:0]);
    // Note: prefetch MUST continue while halt (that is how the FIFO refills
    // and the frozen display catches up) - do NOT gate pf_want on !halt.
    assign pf_want = (depth < TARGET[7:0]) && ahead_ok;
    assign pf_addr = BASE + {7'd0, pf_idx};

    // advance the prefetch pointer only when a word actually enters the
    // FIFO. The pointer starts at 0 (= the display start); because pushes
    // and pops are both in-order and the display is FROZEN (hold) while the
    // FIFO is low, the FIFO head always holds the word for the current
    // display position when the display is (re)running - no re-sync needed.
    always @(posedge clk) begin
        if (reset)
            pf_idx <= 14'd0;
        else if (push)
            pf_idx <= (pf_idx == FRAMESIZE[13:0] - 1) ? 14'd0
                                                       : pf_idx + 14'd1;
    end

endmodule

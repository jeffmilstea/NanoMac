# NanoMac verilator simulation

The entire NanoMac can be run in a [verilator
simulation](https://www.veripool.org/verilator/) on a regular PC. The
simulation includes video, audio, RAM, ROM, SD card etc.  and can thus
be used to verify the general timing and operation of all of these in
a convenient way.

Video is displayed "live" (as live as it can be when running at 1/100
of the speed on a decent PC) in a window as well as captured frame by
frame into the screenshots directory. This captures the entire frama
including blanking areas and vertical and horizontal sync:

![Screenshot](screenshots/frame0682.png)

Audio is captured into a file named ```audio.s16``` which contains
a single audio channel captured as 16 bit signed values at 22250 Hertz.
This can be read with tools like [audacity](https://www.audacityteam.org/).

The simulation can be configured inside [nanomac_tb.cpp](nanomac_tb.cpp)
to write traces for a certain time or to enable the use of disk images
or ROMs.

![trace](trace.png)

The current configuration expects a ROM named ```plusrom.bin``` as
well as a disk image named ```system30.dsk``` to be present and boots
a 128k RAM setup. Any later system and bigger RAM size will significantly
increase boot and thus simulation times which is not necessary in most
cases.

## Top-Level (`top.sv`) Testbench

In addition to the core Mac simulation above, there is a skeleton testbench specifically for Verilating the entire top-level SoC (including the HDMI CDC bridge and Gowin IP wrappers).

### How to Run

1. **Path Warning:** GNU Make (which Verilator uses under the hood) fails if your project path contains spaces (e.g. `Mobile Documents`). If you are running from a directory with spaces, copy the project to a spaceless path (like `/tmp/NanoMac`) before running.
2. Run the build script from inside the `sim/` directory:
   ```bash
   ./run_top_tb.sh
   ```

### Expected Behavior

Currently, `top_tb.cpp` is a basic clock driver intended to prove that the top-level Verilog logic is syntactically sound, synthesizable, and capable of executing the boot ROM.

When you run it, you should expect to see:
1. `plusrom.bin` automatically being converted to a hex file and loaded into a simulated internal ROM (bypassing the SPI flash).
2. Verilator successfully parsing `top.sv` and all submodules.
3. The C++ build completing successfully.
4. The simulation executing the CPU instructions from the firmware!

*(Note: Ensure you copy both `plusrom.bin` and `src/companion/macplus_xml.hex` into your execution directory before running, otherwise the simulation will crash with a `$readmem` file not found error.)*
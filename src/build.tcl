set_device GW2AR-LV18QN88C8/I7 -name GW2AR-18C

add_file macplus/macplus.sv
add_file macplus/clocks.v
add_file macplus/iwm.v
add_file macplus/addrController.v
add_file macplus/addrDecoder.v
add_file macplus/videoTimer.v
add_file macplus/dataController.sv
add_file macplus/ncr5380.sv
add_file macplus/floppy.v
add_file macplus/rtc.v
add_file macplus/scc.v
add_file macplus/videoShifter.v
add_file macplus/adb.sv
add_file macplus/floppy_track_codec.v
add_file macplus/floppy_track_buffer.v
add_file macplus/scsi.v
add_file macplus/uart/rxuart.v
add_file macplus/uart/txuart.v
add_file macplus/via6522.v
add_file macplus/bram_cache.sv
add_file macplus/keyboard.v

add_file fx68k/fx68k.sv
add_file fx68k/fx68kAlu.sv
add_file fx68k/uaddrPla.sv
add_file fx68k/microrom.mem
add_file fx68k/nanorom.mem

add_file companion/mcu_spi.v
add_file companion/sysctrl.v
add_file companion/hid.v
add_file companion/macplus_keymap.v
add_file companion/osd_u8g2.v
add_file companion/ila.sv
add_file companion/ila_uart.sv

add_file misc/video_analyzer.v
add_file misc/ws2812.v
add_file misc/sd_card.v
add_file misc/sd_rw.v
add_file misc/sdcmd_ctrl.v
add_file misc/hdmi_mac_bridge.sv
add_file misc/hdmi_pll.sv
add_file misc/hdmi_720p.sv

add_file hdmi/audio_clock_regeneration_packet.sv
add_file hdmi/audio_info_frame.sv
add_file hdmi/audio_sample_packet.sv
add_file hdmi/auxiliary_video_information_info_frame.sv
add_file hdmi/hdmi.sv
add_file hdmi/packet_assembler.sv
add_file hdmi/packet_picker.sv
add_file hdmi/serializer.sv
add_file hdmi/source_product_description_info_frame.sv
add_file hdmi/tmds_channel.sv

add_file tang/nano20k/gowin_clkdiv/gowin_clkdiv.v
add_file tang/nano20k/gowin_rpll/pll_80m.v
add_file tang/nano20k/top.sv
add_file tang/nano20k/nanomac.cst
add_file tang/nano20k/nanomac.sdc
add_file tang/nano20k/sdram.v
add_file tang/nano20k/flash_dspi.v
add_file tang/nano20k/gowin_dpb/sector_dpram.v

set_option -synthesis_tool gowinsynthesis
set_option -output_base_name nanomac
set_option -verilog_std sysv2017
set_option -top_module top
set_option -use_mspi_as_gpio 1
set_option -use_sspi_as_gpio 1
set_option -loading_rate 25.000

# Inject git short hash (first 4 hex digits = 16 bits) as a synthesis-time define.
# This value appears in the $F80006 CSR so you can verify which build is running.
catch {
    set git_short [exec git rev-parse --short=4 HEAD]
    set_option -verilog_define "GIT_HASH=16'h${git_short}"
    puts "Build hash: 0x${git_short}"
} err
if {$err ne ""} {
    set_option -verilog_define "GIT_HASH=16'hDEAD"
    puts "Warning: could not get git hash ($err), using 0xDEAD"
}

run syn
run pnr

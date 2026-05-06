transcript on
if {[file exists work]} {vdel -lib work -all}
vlib work
vmap work work

# Compile RTL + TB
vlog -sv ../rtl/01_iir4_df2t_fixed.v
vlog -sv ../rtl/filtfilt68_hw.v
vlog -sv ../tb/tb_filtfilt68_hw.sv

# Run simulation
vsim -voptargs=+acc work.tb_filtfilt68_hw
run -all

# Save waveform (optional)
# add wave -r sim:/tb_filtfilt68_hw/*
# write format wave -window .main_pane.wave.interior.cs.body.pw.wf wave.wlf

quit -f

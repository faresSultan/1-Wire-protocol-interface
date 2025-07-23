vlib work
vlog -f src_files.list 
vsim -voptargs=+acc Master_tb 

add wave -position insertpoint sim:/Master_tb/*
add wave -position insertpoint  \
sim:/Master_tb/DUT/load_en \
sim:/Master_tb/DUT/counter_out \
sim:/Master_tb/DUT/load_value \
sim:/Master_tb/DUT/current_state \
sim:/Master_tb/DUT/next_state
run
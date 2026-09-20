set ROOT [pwd]
if {![file isdirectory $ROOT/scripts]} {
    error "sram.do: run the ps1 script inside the code folder"
}

if {![info exists GUI_MODE]} {
    set GUI_MODE 0
}

set TB $ROOT/simulations
set SIM $ROOT/sim

file mkdir $SIM
cd $SIM
transcript file transcript.log

if {[file isdirectory work]} {vdel -all -lib work}

vlib work
vmap work work

set ok [expr {![catch {vlog -sv -work work -suppress 2275 $ROOT/ahb_pkg.sv $ROOT/ahb_if.sv $ROOT/*.sv $TB/tb_sram_isolated.sv} msg]}]

if {!$ok} {
    puts $msg
    quit -code 1
} else {
    puts "Compilation Successful! Running SRAM Isolated Simulation..."
    if {$GUI_MODE == 1} {
        vsim work.tb_sram_isolated -voptargs="+acc"
        add wave -r /*
        run -all
    } else {
        vsim -c work.tb_sram_isolated -voptargs="+acc"
        run -all
        quit -code 0
    }
}

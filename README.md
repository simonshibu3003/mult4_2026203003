# 4-bit Array Multiplier, RTL to GDSII (SKY130)

Name: Simon Shibu
Roll number: 2026203003

Name: Akshat Agrawal
Roll number: 2026203014

Environment: IIC-OSIC-TOOLS Docker container on macOS (Apple Silicon).
PDK sky130A, standard cell library sky130_fd_sc_hd.
Commands run inside the container from /foss/designs/mult4_2026203003 unless stated.

## Step 0: Environment setup

On the Mac, from the IIC-OSIC-TOOLS folder (DVD_project):

    ./start_shell.sh
    ./start_x.sh

Inside the container (the PDK defaults to ihp-sg13g2, so it is switched to sky130A in every new shell):

    sak-pdk sky130A
    echo $PDK_ROOT $PDK
    iverilog -V | head -1
    yosys -V
    sta -version
    ls $PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
    librelane --version

## Step 1: Repository

    cd /foss/designs
    mkdir -p mult4_2026203003/{rtl,tb,synth,sta,pnr,report}
    cd mult4_2026203003
    touch README.md
    git init
    git config user.name "Simon Shibu"
    git config user.email "simonshibu3003@gmail.com"
    git branch -m main
    git add README.md
    git commit -m "Initial repo structure"

## Part A: RTL design and verification

Task 1, rtl/full_adder.v (written on the device, copied into ~/eda/designs/mult4_2026203003/rtl/):

    iverilog -g2012 -o /tmp/fa_check rtl/full_adder.v
    git add rtl/full_adder.v
    git commit -m "Add full_adder module"

Task 2, rtl/mult_array.v (12 full_adder instances, no * operator):

    iverilog -g2012 -o /tmp/ma_check rtl/full_adder.v rtl/mult_array.v
    git add rtl/mult_array.v
    git commit -m "Add mult_array"

Tasks 3 and 4, tb/tb_mult.v (256 vectors, 2-cycle latency, writes mult.vcd):

    iverilog -g2012 -o sim tb/tb_mult.v rtl/full_adder.v rtl/mult_array.v
    vvp sim

    git add tb/tb_mult.v
    git commit -m "Add testbench"

Result: PASS: 256 vectors checked, 0 errors

Task 5, waveform in GTKWave (started from the container with the X display):

    gtkwave mult.vcd &

Task 6, error test: sum in rtl/full_adder.v was temporarily changed to "a ^ b", then the same two commands were run:

    iverilog -g2012 -o sim tb/tb_mult.v rtl/full_adder.v rtl/mult_array.v
    vvp sim

Result: FAIL: 256 vectors checked, 95 errors

The change was then undone (sum = a ^ b ^ cin) and the PASS result above was confirmed again.

Build outputs are kept out of Git without extra files:

    printf 'sim\ngls\nmult.vcd\n.DS_Store\n' >> .git/info/exclude

## Part B: Logic synthesis with Yosys

- synth/synth.tcl (written on the device, copied into ~/eda/designs/mult4_2026203003/synth/)

synth/synth.tcl contains the seven steps from the assignment (read_verilog, synth -top mult_array -flatten, dfflibmap, abc, opt_clean -purge, tee stat, write_verilog).

    yosys -c synth/synth.tcl
    cat synth/mult_array_stat.rpt

Result: 67 cells, 16 flip-flops (sky130_fd_sc_hd__dfrtp_1), total area 746.966 um^2 (of which 400.384 um^2, 53.6 %, is sequential).

The synthesis was run a second time from synth/synth.tcl and gave the same netlist and report.

Netlist simulation with the same testbench:

    CELLS=$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/verilog
    iverilog -g2012 -DFUNCTIONAL -DUNIT_DELAY=#1 -o gls tb/tb_mult.v $CELLS/primitives.v $CELLS/sky130_fd_sc_hd.v synth/mult_array_netlist.v
    vvp gls

    git add synth/synth.tcl synth/mult_array_netlist.v
    git commit -m "Adding the tcl script and the gate level netlist"

(synth/mult_array_stat.rpt was committed later, in the "Add the synthesis report" commit listed at the end of Part D.)

The first netlist-simulation run failed because the testbench checked p 1 ns after the clock edge, while the cell models with UNIT_DELAY=#1 update the flip-flop outputs 1 ns after the edge. The check delay in tb/tb_mult.v was changed from #1 to #3 (the committed testbench, from the "Add testbench" commit, already uses #3), and then both the RTL and the netlist simulation print PASS: 256 vectors checked, 0 errors.

## Part C: Static timing analysis with OpenSTA

- sta/sta.tcl (written on the device, copied into ~/eda/designs/mult4_2026203003/sta/)

sta/sta.tcl has the seven steps from the assignment. The clock period T can be set from the shell (T=<value>); without it the script uses the default value set at the top of the file (10 ns at first, 2.6 ns in the final version).
The worst slack was obtained using:

    sta -exit sta/sta.tcl

Worst slack at T = 10 ns is 7.396 ns, so T_min = 10 - 7.396 = 2.604 ns and F_max = 1000 / 2.604 = 384.0 MHz.

The T value was then changed to T_min rounded to 0.01 ns (2.60 ns) by editing sta/sta.tcl, and the same command was run again. At T = 2.60 ns the setup slack is -0.004 ns (VIOLATED), which is expected because T_min is 2.604 ns, so the slack is close to zero. The committed sta/mult_array_timing.rpt is the T = 2.60 ns report. The report from the T = 10 ns run is kept outside the repository (it was used only to find T_min).

The critical path runs from flip-flop _106_ to flip-flop _100_ (arrival 2.471 ns at T = 10 ns): dfrtp_1 (clk-to-Q), and2_0, or3_1, a32oi_1, o21ba_1, xnor2_1, maj3_1, maj3_1, xnor3_1, followed by the flip-flop setup time of 0.134 ns.

The cells on the critical path were listed from the report with:

    awk '/Path Group: clk/,/data arrival time/' sta/mult_array_timing.rpt > /foss/designs/mult4_notes/critical_path_cells.txt

    git add sta/mult_array_timing.rpt
    git commit -m "Adding the synthesis report"
    git add sta/sta.tcl
    git commit -m "Add OpenSTA script and timing report"

(The first of these two commits holds the T = 10 ns timing report; its message should have said "timing report".)

The T = 2.60 ns report was first saved as sta/mult_array_timing_T2.6.rpt:

    git add sta/mult_array_timing_T2.6.rpt
    git commit -m "Add timing report for T=T_min"

It then replaced sta/mult_array_timing.rpt in the "Update LibreLane config (7.0 ns), metrics and GDS" commit (see Part D), and the default clock period in sta/sta.tcl was set to T_min:

    git add sta/sta.tcl
    git commit -m "Set default clock period in sta.tcl to T_min = 2.6 ns"

## Part D: Physical design with LibreLane

- pnr/config.json (written on the device, copied into ~/eda/designs/mult4_2026203003/pnr/)

pnr/config.json was first written with CLOCK_PERIOD 3.5 ns; after each failed run the period was increased in 0.5 ns steps until the flow completed at 7.0 ns (eight runs, listed below in the order they were made):

    {
      "DESIGN_NAME": "mult_array",
      "VERILOG_FILES": ["dir::../rtl/full_adder.v", "dir::../rtl/mult_array.v"],
      "CLOCK_PORT": "clk",
      "CLOCK_PERIOD": 3.5,
      "FP_SIZING": "absolute",
      "DIE_AREA": [0, 0, 150, 150]
    }

CLOCK_PERIOD = 1.2 x T_min = 1.2 x 2.604 = 3.1248 ns, rounded up to the next 0.5 ns, so 3.5 ns.

Run 1: CLOCK_PERIOD = 3.5 ns (runs/RUN_2026-10-19_12-15-30).

    echo "pnr/runs" >> .git/info/exclude
    sak-pdk sky130A
    cd pnr
    librelane config.json

Result: Setup violations found in the following corners:
                    * max_ss_100C_1v60
                    * min_ss_100C_1v60
                    * nom_ss_100C_1v60

    grep -E "\"timing__setup__ws\"" runs/<run folder name>/final/metrics.json

output:

    "timing__setup__ws": -2.1179485431597547

In this setup LibreLane checks setup timing at every corner (TIMING_VIOLATION_CORNERS = ["*"] in runs/<run>/resolved.json), so the flow stops when any slow corner has a setup violation. The clock period was then increased in 0.5 ns steps to remove the violations (CLOCK_PERIOD edited in pnr/config.json, then librelane config.json run again). Run 3 was made at 5.0 ns before run 4 at 4.5 ns.

Run 2: CLOCK_PERIOD = 4.0 ns (runs/RUN_2026-10-19_12-27-42).

Result: Setup violations found in max_ss_100C_1v60, min_ss_100C_1v60 and nom_ss_100C_1v60.

    "timing__setup__ws": -1.5941133309034252

Run 3: CLOCK_PERIOD = 5.0 ns (runs/RUN_2026-10-19_12-33-50).

Result: Setup violations found in max_ss_100C_1v60, min_ss_100C_1v60 and nom_ss_100C_1v60.

    "timing__setup__ws": -0.6216338730830749

Run 4: CLOCK_PERIOD = 4.5 ns (runs/RUN_2026-10-19_12-40-44).

Result: Setup violations found in max_ss_100C_1v60, min_ss_100C_1v60 and nom_ss_100C_1v60.

    "timing__setup__ws": -1.123404068234753

Run 5: CLOCK_PERIOD = 5.5 ns (runs/RUN_2026-10-19_12-44-33).

Result: Setup violations found in max_ss_100C_1v60, min_ss_100C_1v60 and nom_ss_100C_1v60.

    "timing__setup__ws": -0.1216338175719222

Run 6: CLOCK_PERIOD = 6.0 ns (runs/RUN_2026-10-19_12-47-47).

Result: Setup violations found in max_ss_100C_1v60, min_ss_100C_1v60 and nom_ss_100C_1v60.

    "timing__setup__ws": -0.16627588665466367

(The slack at 6.0 ns is worse than at 5.5 ns because timing repair runs before detailed routing: at 5.5 ns the post-CTS repair step still saw violations and kept speeding up the path ("[RSZ-0062] Unable to repair all setup violations" in its log), while at 6.0 ns it saw none and stopped, so after routing, with the real wire parasitics, the 6.0 ns layout ended slightly worse.)

Run 7: CLOCK_PERIOD = 6.5 ns (runs/RUN_2026-10-19_12-52-00).

Result: Setup violations found in max_ss_100C_1v60.

    "timing__setup__ws": -0.0346909177869835

Run 8: CLOCK_PERIOD = 7.0 ns (runs/RUN_2026-10-19_12-56-23).

Result: Flow complete (no setup or hold violations, DRC 0, LVS 0).

    "timing__setup__ws": 0.4653095818133917   (worst corner: max_ss_100C_1v60)

The committed pnr/config.json is the final one (CLOCK_PERIOD = 7.0 ns), and pnr/metrics.json and pnr/mult_array.gds are the files from the final/ folder of this run (RUN_2026-10-19_12-56-23).


The two deliverables were copied by hand from the final/ folder of this run into pnr/ (the runs/ folder is not committed). The equivalent commands, run from pnr/, are:

    R=runs/RUN_2026-10-19_12-56-23
    cp $R/final/metrics.json metrics.json
    cp $R/final/gds/mult_array.gds mult_array.gds

Reading the results in the terminal:

    grep -E "instance__count|core__area|die__area|wirelength|setup__ws|hold__ws|drc|lvs" $R/final/metrics.json
    grep -o "sky130_fd_sc_hd__[a-z0-9_]*" $R/final/nl/mult_array.nl.v | sort | uniq -c | sort -rn
    grep -i "cells" $R/06-yosys-synthesis/reports/stat.rpt

Layout screenshots were taken in KLayout (full hierarchy view; texts, grid and cell frames hidden for the zoomed view):

    klayout /foss/designs/mult4_2026203003/pnr/mult_array.gds

    git add pnr/config.json
    git commit -m "Add LibreLane config (6.0 ns) and final metrics and GDS"

    git add pnr/metrics.json pnr/mult_array.gds
    git commit -m "Add final LibreLane metrics and GDS"

    git add synth/mult_array_stat.rpt
    git commit -m "Add the synthesis report"

    git add pnr/config.json pnr/metrics.json pnr/mult_array.gds sta/
    git commit -m "Update LibreLane config (7.0 ns), metrics and GDS"

(The first two pnr commits contain the intermediate files from an earlier, failing run; the last commit replaces them with the final 7.0 ns run. The same commit also replaced sta/mult_array_timing.rpt with the T = 2.60 ns report and removed sta/mult_array_timing_T2.6.rpt; see Part C.)

## Report

    git add report/report.pdf
    git commit -m "Add the final report"
    git add README.md
    git commit -m "Add the README file"
    git add README.md
    git commit -m "Add the final readme"
    git add report/report.pdf
    git commit -m "Add the updated report"

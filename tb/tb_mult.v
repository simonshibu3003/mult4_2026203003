`timescale 1ns/1ps

module tb_mult;

    reg        clk, rst_n;
    reg  [3:0] a, b;
    wire [7:0] p;

    reg  [7:0] expected;
    integer    i, j;
    integer    errors;
    integer    checked;

    // device under test
    mult_array dut (.clk(clk), .rst_n(rst_n), .a(a), .b(b), .p(p));

    // 10 ns clock
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // waveform dump
    initial begin
        $dumpfile("mult.vcd");
        $dumpvars(0, tb_mult);
    end

    // stimulus and checking
    initial begin
        errors  = 0;
        checked = 0;
        a = 4'd0;
        b = 4'd0;

        // hold reset low for the first 2 clock cycles
        rst_n = 1'b0;
        repeat (2) @(posedge clk);
        #1 rst_n = 1'b1;

        for (i = 0; i < 16; i = i + 1) begin
            for (j = 0; j < 16; j = j + 1) begin
                a = i;
                b = j;
                @(posedge clk);     // edge 1: a, b captured into input registers
                @(posedge clk);     // edge 2: product captured into p
                #3;                 // let p settle before checking

                expected = a * b;   // * is allowed in the testbench only
                checked  = checked + 1;
                if (p !== expected) begin
                    errors = errors + 1;
                    $display("MISMATCH: a=%0d b=%0d expected=%0d got=%0d",
                             a, b, expected, p);
                end
            end
        end

        if (errors == 0)
            $display("PASS: %0d vectors checked, 0 errors", checked);
        else
            $display("FAIL: %0d vectors checked, %0d errors", checked, errors);

        $finish;
    end

endmodule

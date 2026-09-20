`timescale 1ns/1ps

module tb_sram_isolated import ahb_pkg::*; ();

    logic clk;
    logic rstn;

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Interface and DUT
    ahb_if mem_if(clk, rstn);
    ahb_sram dut(clk, rstn, mem_if);

    initial begin
        // 1. Initialize
        rstn = 0;
        mem_if.hsel = 0;
        mem_if.haddr = 0;
        mem_if.hwrite = 0;
        mem_if.htrans = IDLE;
        mem_if.hwdata = 0;
        
        @(posedge clk);
        rstn = 1;
        @(posedge clk);

        $display("========================================");
        $display("   ISOLATED SRAM TEST (STALL/IDLE BUG)");
        $display("========================================");

        // 2. Write 0xAABBCCDD to address 0x1004
        // Address Phase
        mem_if.hsel = 1;
        mem_if.haddr = 32'h0000_1004;
        mem_if.hwrite = 1;
        mem_if.htrans = NONSEQ;
        @(posedge clk);
        // Data Phase
        mem_if.hwdata = 32'hAABBCCDD;
        mem_if.htrans = IDLE; // Drop request
        @(posedge clk);

        $display("[TEST] Wrote 0xAABBCCDD to 0x1004.");
        
        // Let it settle
        mem_if.hsel = 0;
        mem_if.hwrite = 0;
        @(posedge clk);

        // 3. The Problematic Read Sequence
        $display("\n[TEST] Starting Read from 0x1004...");
        
        // Address Phase for Read
        mem_if.hsel = 1;
        mem_if.haddr = 32'h0000_1004;
        mem_if.hwrite = 0;
        mem_if.htrans = NONSEQ;
        @(posedge clk);

        // Data Phase for Read (Master drops htrans to IDLE, Arbiter changes haddr to 0)
        // This simulates exactly what happens when the DMA stalls or goes IDLE!
        $display("[TEST] Entering Data Phase. Simulating Arbiter changing the live haddr to 0x0000...");
        mem_if.haddr = 32'h0000_0000; 
        mem_if.htrans = IDLE;
        
        // Sample the data exactly when the data phase is active
        #1; 
        $display("       -> Cycle 1 of Data Phase: hrdata = %h (Expected: aabbccdd)", mem_if.hrdata);

        // Wait another cycle (simulating a stalled pipeline or multi-cycle check)
        @(posedge clk);
        #1;
        $display("       -> Cycle 2 of Data Phase: hrdata = %h (Expected: aabbccdd. If xxxxxxxx, SRAM IS BROKEN!)", mem_if.hrdata);

        $display("========================================");
        $stop;
    end

endmodule

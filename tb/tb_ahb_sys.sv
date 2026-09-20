`timescale 1ns/1ps

module tb_ahb_sys import ahb_pkg::*; ();

    logic clk = 0, rstn = 1;

    initial forever #5 clk = ~clk;

    logic [31:0] data, rslt_data;
    logic data_valid, ready, rd_image, rd_weight, wrt_result, start_r, int_en_r, reset_r, busy_w, done_w;
    
    ahb_if cpu_ahb_data(clk, rstn);
    ahb_if cpu_ahb_inst(clk, rstn);

    ahb_sys_top dut(.*);


    task cpu_write(input logic [31:0] addr, input logic [31:0] wr_data);
        // 1. Address Phase
        @(posedge clk);
        cpu_ahb_data.haddr <= addr;
        cpu_ahb_data.hwrite <= 1;
        cpu_ahb_data.htrans <= NONSEQ;
        cpu_ahb_data.hsize <= 3'b010; // 32-bit transfer

        // 2. Wait for Address Phase to be accepted by the bus
        do begin
            @(posedge clk);
        end while (cpu_ahb_data.hready == 0);

        // 3. Move to Data Phase
        cpu_ahb_data.hwdata <= wr_data;
        cpu_ahb_data.htrans <= IDLE;

        // 4. Wait for Data Phase to complete
        do begin
            @(posedge clk);
        end while (cpu_ahb_data.hready == 0);
    endtask


    task cpu_rd(input logic [31:0] addr, output logic [31:0] rd_data);
        // 1. Drive the Address Phase
        @(posedge clk);
        cpu_ahb_data.haddr <= addr;
        cpu_ahb_data.hwrite <= 0;
        cpu_ahb_data.htrans <= NONSEQ;
        cpu_ahb_data.hsize <= 3'b010;
        
        // 2. Wait for Address Phase to be accepted by the bus
        do begin
            @(posedge clk);
        end while (cpu_ahb_data.hready == 0);
        
        // 3. We are now in the Data Phase! Drop htrans
        cpu_ahb_data.htrans <= IDLE;
        
        // 4. Wait for the Data Phase to complete
        do begin
            @(posedge clk);
        end while (cpu_ahb_data.hready == 0);
        
        // 5. Capture the data!
        rd_data = cpu_ahb_data.hrdata;
    endtask


    logic [31:0] read_val, captured_data;

    initial begin
        // Initialize Master Signals
        cpu_ahb_data.haddr = '0;
        cpu_ahb_data.hwrite = 0;
        cpu_ahb_data.htrans = IDLE;
        cpu_ahb_data.hwdata = '0;
        cpu_ahb_data.hsize = 3'b010;
        cpu_ahb_data.hburst = 0;
        cpu_ahb_data.hprot = 0;
        cpu_ahb_data.hmastlock = 0;

        cpu_ahb_inst.haddr = '0;
        cpu_ahb_inst.hwrite = 0;
        cpu_ahb_inst.htrans = IDLE;
        cpu_ahb_inst.hwdata = '0;
        cpu_ahb_inst.hsize = 3'b010;
        cpu_ahb_inst.hburst = 0;
        cpu_ahb_inst.hprot = 0;
        cpu_ahb_inst.hmastlock = 0;

        // Initialize DMA external pins (that mock the CNN engine)
        rd_image = 0;
        rd_weight = 0;
        wrt_result = 0;
        rslt_data = '0;

        // Reset Sequence
        rstn = 0;
        #25 rstn = 1;
        #20;

        $display("========================================");
        $display("   AHB SUBSYSTEM INTEGRATION TESTS");
        $display("========================================");






        

        // ----------------------------------------------------
        // Test 1: Arbiter & SRAM Validation
        // ----------------------------------------------------
        $display("\n[TEST 1] Writing to SRAM at 0x0000_0004...");
        cpu_write(32'h0000_0004, 32'hDEADBEEF);
        
        $display("[TEST 1] Reading from SRAM at 0x0000_0004...");
        cpu_rd(32'h0000_0004, read_val);
        if (read_val == 32'hDEADBEEF) $display("  -> SUCCESS: Read %h", read_val);
        else $display("  -> ERROR: Expected DEADBEEF, got %h", read_val);







        // ----------------------------------------------------
        // Test 2: Control Register Validation
        // ----------------------------------------------------
        $display("\n[TEST 2] Writing to IMAGE_ADDR (0x4000_0008)...");
        cpu_write(32'h4000_0008, 32'h0000_1000);

        $display("[TEST 2] Reading from IMAGE_ADDR...");
        cpu_rd(32'h4000_0008, read_val);
        if (read_val == 32'h0000_1000) $display("  -> SUCCESS: Read %h", read_val);
        else $display("  -> ERROR: Expected 00001000, got %h", read_val);








        // ----------------------------------------------------
        // Test 3: The DMA Fetch (Full Integration)
        // ----------------------------------------------------
        // We will pre-load the SRAM with some image data
        $display("\n[TEST 3] Pre-loading SRAM at 0x0000_1000 with image data 0x11223344...");
        cpu_write(32'h0000_1000, 32'h11223344);

        cpu_write(32'h4000_0008, 32'h0000_1000);

        $display("[TEST 3] Asserting rd_image on DMA Engine...");
        @(posedge clk);
        rd_image = 1;
        
        // Wait for DMA to fetch the data
        // The DMA FSM should see rd_image, request bus, do a read from img_addr (0x10000), and output to 'data'
        wait(data_valid == 1);
        @(posedge clk);
        if (data == 32'h11223344) $display("  -> SUCCESS: DMA successfully fetched %h", data);
        else $display("  -> ERROR: DMA fetched %h instead of 11223344", data);
        
        rd_image = 0;
                
        // Wait for DMA pipeline to flush and reach SIDLE
        repeat(50) @(posedge clk); 
        
        $display("\n[INTERLUDE] Pulsing soft reset (reset_r) to clear DMA offsets...");
        cpu_write(32'h4000_0000, 32'h0000_0004); // Assert reset_r


        // rstn = 0;
        // #25 rstn = 1;
        // #20;




        // ----------------------------------------------------
        // Test 4: Arbitration and Stalling (The Stress Test)
        // ----------------------------------------------------
        $display("\n[TEST 4] Forcing Concurrent Access (CPU Write vs DMA Fetch)...");
        // Change the DMA target address
        cpu_write(32'h4000_0008, 32'h0000_1004); 
        // Load the new pixel into SRAM
        cpu_write(32'h0000_1004, 32'hAABBCCDD);  
        
        @(posedge clk);
        $display("         Launching CPU Write and DMA Fetch simultaneously!");
        fork
            begin
                // The DMA requests the bus to read the pixel
                rd_image = 1;
                wait(data_valid == 1);

                #1;

                captured_data = data;
                rd_image = 0;
            end
            begin
                // The CPU simultaneously requests the bus to spam the SRAM with writes
                // This forces the Arbiter to heavily stall the DMA
                cpu_write(32'h0000_1008, 32'h99887766);
                cpu_write(32'h0000_100C, 32'h55443322);
            end
        join

        // VERIFY: Did the DMA actually hold its state and fetch the correct data despite being stalled?
        if (captured_data === 32'hAABBCCDD) $display("  -> SUCCESS: DMA fetched %h despite being stalled!", captured_data);
        else $display("  -> FATAL ERROR: DMA fetched %h instead of AABBCCDD. The stall corrupted the fetch!", captured_data);
        






        // ----------------------------------------------------
        // Test 5: Unmapped Memory (Error Response)
        // ----------------------------------------------------
        $display("\n[TEST 5] Accessing Unmapped Memory (0x8000_0000)...");
        cpu_rd(32'h8000_0000, read_val);
        // The arbiter should return hresp = 1 for unmapped memory.
        if (cpu_ahb_data.hresp == 1) $display("  -> SUCCESS: Arbiter correctly flagged an ERROR (hresp=1) for unmapped address!");
        else $display("  -> ERROR: Arbiter failed to flag an error for an invalid address!");

        #50;
        $display("\n========================================");
        $display("           TESTS COMPLETE");
        $display("========================================");
        $stop;
    end

endmodule
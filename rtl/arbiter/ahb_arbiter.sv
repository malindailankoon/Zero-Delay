module ahb_arbiter import ahb_pkg::*; (
    input logic clk, rstn,

    // the signals from the outer components
    // from the perspective of the arbiter, the arbiter is a slave to the cpu
    // and a master to memory
    ahb_if.slave cpu_data,
    ahb_if.slave accel_dma,
    ahb_if.inst_slave cpu_instr,
    ahb_if.master uart,
    ahb_if.master control_reg,
    ahb_if.master sram

);

    // choosing the master based on priority ----------------
    //--------------------------------------------
    logic req_cpu_data, req_cpu_inst, req_dma;
    logic grant_cpu_data, grant_cpu_inst, grant_dma;

    assign req_cpu_data = (cpu_data.htrans == SEQ) || (cpu_data.htrans == NONSEQ);
    assign req_cpu_inst = (cpu_instr.htrans == SEQ) || (cpu_instr.htrans == NONSEQ);
    assign req_dma = (accel_dma.htrans == SEQ) || (accel_dma.htrans == NONSEQ);

    always_comb begin
        grant_cpu_data = 0;
        grant_cpu_inst = 0;
        grant_dma = 0;

        if (req_cpu_data) begin
            grant_cpu_data = 1;
        end else if (req_cpu_inst) begin
            grant_cpu_inst = 1;
        end else if (req_dma) begin
            grant_dma = 1;
        end
    end


    // getting the address based on the active master----
    //--------------------------------------------------
    logic [31:0] active_address;
    logic active_hwrite;
    htrans_t active_htrans;

    always_comb begin
        unique case ({grant_cpu_data, grant_cpu_inst, grant_dma})
            3'b100: begin
                active_address = cpu_data.haddr;
                active_hwrite = cpu_data.hwrite;
                active_htrans = cpu_data.htrans;
            end
            3'b010: begin
                active_address = cpu_instr.haddr;
                active_hwrite = '0; // cpu instructions is read only
                active_htrans = cpu_instr.htrans;
            end
            3'b001: begin
                active_address = accel_dma.haddr;
                active_hwrite = accel_dma.hwrite;
                active_htrans = accel_dma.htrans;
            end
            default: active_address = '0;
        endcase
    end


    // decoding the destination based on the address---
    //-----------------------------------------------
    logic sel_control, sel_sram, sel_uart;
    assign sel_control = (active_address[31:16] == CNN_CRTL_BASE[31:16]);
    assign sel_sram = (active_address[31:16] == SRAM_BASE[31:16]);
    assign sel_uart = (active_address[31:16] == UART_BASE[31:16]);



    // saving select signals for the data phase ------
    //--------------------------------------------------
    logic reg_grant_cpu_data, reg_grant_cpu_inst, reg_grant_dma;
    logic reg_sel_control, reg_sel_sram, reg_sel_uart;
    always_ff @(posedge clk) begin
        if (~rstn) begin
            reg_sel_control <= 0;
            reg_sel_sram <= 0;
            reg_sel_uart <= 0;
            reg_grant_cpu_data <= 0;
            reg_grant_cpu_inst <= 0;
            reg_grant_dma <= 0;
        end else begin
            reg_sel_control <= sel_control;
            reg_sel_sram <= sel_sram;
            reg_sel_uart <= sel_uart;
            reg_grant_cpu_data <= grant_cpu_data;
            reg_grant_cpu_inst <= grant_cpu_inst;
            reg_grant_dma <= grant_dma;
        end
    end

    

    // route addressphase data to all slaves, choose slave using hsel-------
    //--------------------------------------------------------
    assign control_reg.hsel = sel_control;
    assign sram.hsel = sel_sram;
    assign uart.hsel = sel_uart;

    assign control_reg.haddr = active_address;
    assign control_reg.hwrite = active_hwrite;
    assign control_reg.htrans = active_htrans;

    assign sram.haddr = active_address;
    assign sram.hwrite = active_hwrite;
    assign sram.htrans = active_htrans;

    assign uart.haddr = active_address;
    assign uart.hwrite = active_hwrite;
    assign uart.htrans = active_htrans;



    // data phase signal routing------
    //-------------------------
    // master to slave signals------
    logic [31:0] active_hwdata;
    logic [2:0] active_hsize;
    logic [2:0] active_hburst;
    logic [3:0] active_hprot;
    logic active_hmastlock;

    always_comb begin
        unique case ({reg_grant_cpu_data, reg_grant_cpu_inst, reg_grant_dma})
            3'b100: begin
                active_hwdata = cpu_data.hwdata;
                active_hsize = cpu_data.hsize;
                active_hburst = cpu_data.hburst;
                active_hprot = cpu_data.hprot;
                active_hmastlock = cpu_data.hmastlock;
            end
            3'b010: begin
                active_hwdata = '0;
                active_hsize = cpu_instr.hsize;
                active_hburst = cpu_instr.hburst;
                active_hprot = cpu_instr.hprot;
                active_hmastlock = cpu_instr.hmastlock;
            end
            3'b001: begin
                active_hwdata = accel_dma.hwdata;
                active_hsize = accel_dma.hsize;
                active_hburst = accel_dma.hburst;
                active_hprot = accel_dma.hprot;
                active_hmastlock = accel_dma.hmastlock;
            end
            default: begin
                active_hwdata = '0;
                active_hsize = '0;
                active_hburst = '0;
                active_hprot = '0;
                active_hmastlock = '0;
            end
        endcase
    end

    assign sram.hwdata = active_hwdata;
    assign sram.hsize = active_hsize;
    assign sram.hburst = active_hburst;
    assign sram.hprot = active_hprot;
    assign sram.hmastlock = active_hmastlock;

    assign control_reg.hwdata = active_hwdata;
    assign control_reg.hsize = active_hsize;
    assign control_reg.hburst = active_hburst;
    assign control_reg.hprot = active_hprot;
    assign control_reg.hmastlock = active_hmastlock;

    assign uart.hwdata = active_hwdata;
    assign uart.hsize = active_hsize;
    assign uart.hburst = active_hburst;
    assign uart.hprot = active_hprot;
    assign uart.hmastlock = active_hmastlock;

    
    // slave to master signals
    logic [31:0] active_hrdata;
    logic active_hready, active_hresp;

    always_comb begin
        unique case ({reg_sel_control, reg_sel_sram, reg_sel_uart})
            3'b100: begin
                active_hrdata = control_reg.hrdata;
                active_hready = control_reg.hready;
                active_hresp = control_reg.hresp;
            end
            3'b010: begin
                active_hrdata = sram.hrdata;
                active_hready = sram.hready;
                active_hresp = sram.hresp;
            end
            3'b001: begin
                active_hrdata = uart.hrdata;
                active_hready = uart.hready;
                active_hresp = uart.hresp;
            end
            default: begin
                active_hrdata = '0;
                active_hready = '1; // if a master tries to access a unmapped memory, give error 
                active_hresp = '1;
            end
        endcase
    end

    assign cpu_data.hrdata = active_hrdata;
    assign cpu_data.hresp = active_hresp;
    assign cpu_data.hready = (reg_grant_cpu_data)?active_hready:1'b0;
    
    assign cpu_instr.hrdata = active_hrdata;
    assign cpu_instr.hresp = active_hresp;
    assign cpu_instr.hready = (reg_grant_cpu_instr)?active_hready:1'b0;

    assign accel_dma.hrdata = active_hrdata;
    assign accel_dma.hresp = active_hrdata;
    assign accel_dma.hready = (reg_grant_dma)?active_hready:1'b0;

    


endmodule
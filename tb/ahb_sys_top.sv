module ahb_sys_top (
    input logic clk, rstn,
    ahb_if.slave cpu_ahb_data,
    ahb_if.inst_slave cpu_ahb_inst,

    // wires from cma
    output logic [31:0] data, 
    output logic data_valid, ready,
    input logic [31:0] rslt_data,
    input logic rd_image, rd_weight, wrt_result,
    
    // wires from control registers
    output logic start_r, int_en_r, reset_r,
    input logic busy_w, done_w
);

    ahb_if sram_bus(clk, rstn);    
    ahb_if dma_bus(clk, rstn);
    ahb_if ctrl_bus(clk, rstn);
    ahb_if uart_bus(clk, rstn);
    logic [31:0] w_imm_addr, w_wei_addr, w_rs_addr;
    logic w_reset_r;

    ahb_arbiter u_arbiter(
        .clk(clk),
        .rstn(rstn),
        .cpu_data(cpu_ahb_data),
        .cpu_instr(cpu_ahb_inst),
        .accel_dma(dma_bus),
        .uart(uart_bus),
        .control_reg(ctrl_bus),
        .sram(sram_bus)
    );


    ahb_cnn_ctrl u_ctrl(
        .clk(clk),
        .rstn(rstn),
        .ctrl(ctrl_bus),
        .start_r(start_r),
        .int_en_r(int_en_r),
        .reset_r(reset_r),
        .busy_w(busy_w),
        .done_w(done_w),
        .im_addr(w_imm_addr),
        .wei_addr(w_wei_addr),
        .rs_addr(w_rs_addr)
    );

    
    ahb_cnn_dma u_dma(
        .clk(clk),
        .rstn(rstn),
        .dma(dma_bus),
        .data(data),
        .data_valid(data_valid),
        .im_addr(w_imm_addr),
        .wei_addr(w_wei_addr),
        .rs_addr(w_rs_addr),
        .rslt_data(rslt_data),
        .rd_image(rd_image),
        .rd_weight(rd_weight),
        .wrt_result(wrt_result),
        .ready(ready),
        .reset_r(w_reset_r)
    );


    ahb_sram u_sram(
        .clk(clk),
        .rstn(rstn),
        .mem_if(sram_bus)
    );



endmodule
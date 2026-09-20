module ahb_sram import ahb_pkg::*; (
    input logic clk, rstn,

    ahb_if.slave mem_if
); 

    logic [31:0] buff [0:16383];
    
    logic [13:0] reg_addr;
    logic reg_hwrite;

    always_ff @(posedge clk) begin
        if (~rstn) begin
            reg_addr <= '0;
            reg_hwrite <= '0;
        end else if (mem_if.hsel & (mem_if.htrans == SEQ | mem_if.htrans == NONSEQ)) begin
            reg_addr <= mem_if.haddr[15:2];
            reg_hwrite <= mem_if.hwrite;
        end else begin
            reg_addr <= '0;
            reg_hwrite <= '0;
        end
    end

    assign mem_if.hready = 1;
    assign mem_if.hresp = 0;

    // // In AHB, read data must be valid during the Data Phase, 
    // // which uses the address latched from the previous Address Phase.
    // assign mem_if.hrdata = buff[reg_addr];

    always_ff @(posedge clk) begin
        if (reg_hwrite) begin
            buff[reg_addr] <= mem_if.hwdata;
        end
        if (mem_if.hsel & (mem_if.htrans == SEQ | mem_if.htrans == NONSEQ) & (mem_if.hwrite == 0)) begin
            mem_if.hrdata <= buff[mem_if.haddr[15:2]];
        end
    end

endmodule
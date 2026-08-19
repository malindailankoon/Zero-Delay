module data_mem(
    input logic HCLK,
    input logic HRESETn,
    input logic HWRITE,
    input logic HSEL,
    input logic [31:0] HWDATA,
    input logic [31:0] HADDR,
    input logic [1:0] HTRANS,
    input logic [2:0] HSIZE,
    input logic [2:0] HBURST,
    input logic [3:0] HPROT,
    input logic HMASTLOCK,
    output logic[31:0] HRDATA,
    output logic HREADY,
    output logic HRESP
);

    logic [31:0] buff[0:1024];


    // no errors or need to wait
    assign HREADY = 1;
    assign HRESP = 0;


    always_ff @(posedge HCLK) begin
        if (~HRESETn)
            HRDATA <= '0;
    end


endmodule
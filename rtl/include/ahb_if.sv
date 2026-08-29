

interface ahb_if(input logic clk, input logic resetn);

    import ahb_pkg::*;

    logic hwrite, hready, hresp, hmastlock, hsel;
    logic [31:0] hwdata, hrdata, haddr;
    logic [2:0] hsize, hburst;
    logic [3:0] hprot;

    htrans_t htrans;
    

    modport master(
        input hrdata, hready, hresp,
        output haddr, hwrite, htrans, hsize, hwdata, hburst, hprot, hmastlock
    );

    modport slave(
        input resetn, haddr, hwrite, htrans, hwdata, hburst, hprot, hmastlock, hsel,
        output hrdata, hready, hresp
    );

    modport inst_master(
        input hrdata, hready, hresp,
        output haddr, htrans, hsize, hburst, hprot, hmastlock
    );

    modport inst_slave(
        output hrdata, hready, hresp,
        input haddr, htrans, hsize, hburst, hprot, hmastlock
    );
endinterface
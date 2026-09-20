module ahb_cnn_ctrl import ahb_pkg::*; (
    input logic clk, rstn,

    ahb_if.slave ctrl,

    output logic start_r, int_en_r, reset_r,
    input logic busy_w, done_w,
    output logic [31:0] im_addr,
    output logic [31:0] wei_addr,
    output logic [31:0] rs_addr

);

    logic [31:0] ctrl_reg;
    // logic [31:0] status_reg;
    logic [31:0] img_addr;
    logic [31:0] weight_addr;
    logic [31:0] rslt_addr;


    logic [31:0] reg_addr;
    logic reg_hwrite;

    assign start_r = ctrl_reg[0];
    assign int_en_r = ctrl_reg[1];
    assign reset_r = ctrl_reg[2];
    assign im_addr = img_addr;
    assign wei_addr = weight_addr;
    assign rs_addr = rslt_addr;

    

    always_ff @(posedge clk) begin
        if (~rstn) begin
            reg_addr <= '0;
            reg_hwrite <= '0;
        end else begin
            if (ctrl.hsel) begin
                reg_addr <= ctrl.haddr;
                reg_hwrite <= ctrl.hwrite;
            end else begin
                reg_addr <= '0;
                reg_hwrite <= '0;
            end
        end
    end

    assign ctrl.hready = 1;
    assign ctrl.hresp = 0;

    always_ff @(posedge clk) begin
        if (~rstn) begin
            ctrl.hrdata <= '0;
            ctrl_reg <= '0;
            // status_reg <= '0;
            img_addr <= '0;
            weight_addr <= '0;
            rslt_addr <= '0;
        end else begin
            ctrl_reg[0] <= 1'b0;
            ctrl_reg[2] <= 1'b0;// if the cpu doesn't write to these then these must be zero
            if (reg_hwrite) begin
                unique case (reg_addr)
                    CONTROL_REG: ctrl_reg <= ctrl.hwdata;
                    STATUS_REG:;
                    IMAGE_ADDR: img_addr <= ctrl.hwdata;
                    WEIGHT_ADDR: weight_addr <= ctrl.hwdata;
                    RESULT_ADDR: rslt_addr <= ctrl.hwdata;
                    default:;
                endcase
            end
            if (~ctrl.hwrite) begin
                unique case (ctrl.haddr) 
                    CONTROL_REG: ctrl.hrdata <= ctrl_reg;
                    STATUS_REG: ctrl.hrdata <= {30'b0, done_w, busy_w};
                    IMAGE_ADDR: ctrl.hrdata <= img_addr;
                    WEIGHT_ADDR: ctrl.hrdata <= weight_addr;
                    RESULT_ADDR: ctrl.hrdata <= rslt_addr;
                    default: ;
                endcase
            end
        end
    end

endmodule
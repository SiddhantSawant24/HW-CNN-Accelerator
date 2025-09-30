`include "CONV_ACC.v"
`include "Counter.v"
`include "IFM_BUF.v"
`include "PE.v"
`include "PE_FSM.v"
`include "PSUM_ADD.v"
`include "PSUM_BUFF.v"
`include "SYNCH_FIFO.v"
`include "WGT_BUF.v"
`include "WRITE_BACK.v"

`define CI 0
`define CO 0
`define TI 16
`define TI_FACTOR 64/`TI
`define CFG_CI (`CI+1)*8
`define CFG_CO (`CO+1)*8
`define IFM_LEN `CFG_CI*(`TI+3)*`TI_FACTOR*13*8
`define WGT_LEN 4*4*`CFG_CI*`CFG_CO*13*`TI_FACTOR
`define BUF_DEPTH 61
`define OFM_C `CFG_CO
`define OFM_H `BUF_DEPTH
`define OFM_W `BUF_DEPTH
`define OUT_DATA_WIDTH 25

module tb_conv;

    reg clk, rst_n, start_conv;
    reg [1:0] cfg_ci, cfg_co;
    wire [63:0] ifm;
    reg  [63:0] ifm_r;
    wire [31:0] weight;
    reg [31:0] wgt_r;
    wire [24:0] ofm_port0, ofm_port1;
    wire ofm_port0_v, ofm_port1_v, ifm_read, wgt_read, end_conv;

    reg [32:0] ifm_cnt, wgt_cnt;
    reg [7:0] ifm_in [0:`IFM_LEN-1];
    reg [7:0] wgt_in [0:`WGT_LEN-1];

    integer fp_w;

    // Instantiate conv kernel
    CONV_ACC #(
        .out_data_width(`OUT_DATA_WIDTH),
        .buf_addr_width(5),
        .buf_depth(`TI)
    ) conv_acc (
        .clk(clk),
        .rst_n(rst_n),
        .start_conv(start_conv),
        .cfg_ci(cfg_ci),
        .cfg_co(cfg_co),
        .ifm(ifm),
        .weight(weight),
        .ofm_port0(ofm_port0),
        .ofm_port1(ofm_port1),
        .ofm_port0_v(ofm_port0_v),
        .ofm_port1_v(ofm_port1_v),
        .ifm_read(ifm_read),
        .wgt_read(wgt_read),
        .end_conv(end_conv)
    );

    // Load IFM
    initial begin
        $readmemb("C:\\Users\\Siddhant\\Desktop\\Verification\\Arch\\ifm.txt", ifm_in);
    end

    always @(*) begin
        if (!rst_n)
            ifm_r = 0;
        else if (ifm_read) begin
            ifm_r[7:0]   = ifm_in[ifm_cnt+0];
            ifm_r[15:8]  = ifm_in[ifm_cnt+1];
            ifm_r[23:16] = ifm_in[ifm_cnt+2];
            ifm_r[31:24] = ifm_in[ifm_cnt+3];
            ifm_r[39:32] = ifm_in[ifm_cnt+4];
            ifm_r[47:40] = ifm_in[ifm_cnt+5];
            ifm_r[55:48] = ifm_in[ifm_cnt+6];
            ifm_r[63:56] = ifm_in[ifm_cnt+7];
        end else
            ifm_r = 0;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            ifm_cnt <= 0;
        else if (ifm_cnt == `IFM_LEN && !ifm_read)
            ifm_cnt <= 0;
        else if (ifm_read)
            ifm_cnt <= ifm_cnt + 8;
    end
    assign ifm = ifm_r;

    // Load weights
    initial begin
        $readmemb("C:\\Users\\Siddhant\\Desktop\\Verification\\Arch\\weight.txt", wgt_in);
    end

    always @(*) begin
        if (!rst_n)
            wgt_r = 0;
        else if (wgt_read) begin
            wgt_r[7:0]   = wgt_in[wgt_cnt+0];
            wgt_r[15:8]  = wgt_in[wgt_cnt+1];
            wgt_r[23:16] = wgt_in[wgt_cnt+2];
            wgt_r[31:24] = wgt_in[wgt_cnt+3];
        end else
            wgt_r = 0;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            wgt_cnt <= 0;
        else if (wgt_cnt == `WGT_LEN && !wgt_read)
            wgt_cnt <= 0;
        else if (wgt_read)
            wgt_cnt <= wgt_cnt + 4;
    end
    assign weight = wgt_r;

    // Output write logic with ReLU + binary
    task write_output;
        input [24:0] port;
        input        valid;
        reg signed [24:0] relu_out;
        begin
            if (valid) begin
                relu_out = ($signed(port) < 0) ? 25'd0 : port;
                $fwrite(fp_w, "%b\n", relu_out);
                $display("[ReLU OUTPUT] %b", relu_out);
            end
        end
    endtask

    // File write task wrapper
    initial begin
        fp_w = $fopen("conv_acc_out.txt", "w");
        if (fp_w == 0) begin
            $display("❌ ERROR: Cannot open conv_acc_out.txt");
            $finish;
        end else begin
            $display("📁 File conv_acc_out.txt opened for writing.");
        end

        forever begin
            @(posedge clk);
            write_output(ofm_port0, ofm_port0_v);
            write_output(ofm_port1, ofm_port1_v);
        end
    end

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Stimulus
    initial begin
        rst_n = 1;
        start_conv = 0;
        cfg_ci = `CI;
        cfg_co = `CO;
        #10 rst_n = 0;
        #10 rst_n = 1;
        #20 start_conv = 1;
        #10 start_conv = 0;
        $display("\n⏱️  [ConvKernel] Clock 10ns | Started convolution operation...");
    end

    // Simulation duration
    initial begin
        #20000;  // Run longer if needed
        $fclose(fp_w);
        $display("✅ [Simulation] ReLU output written to conv_acc_out.txt");
        $finish;
    end

endmodule



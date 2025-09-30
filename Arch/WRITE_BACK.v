///==------------------------------------------------------------------==///
/// Conv kernel: writeback controller
///==------------------------------------------------------------------==///
module WRITE_BACK #(
    parameter data_width = 25,
    parameter depth = 61
) (
    input  clk,
    input  rst_n,
    input  start_init,
    input  p_filter_end,
    input  [data_width-1:0] row0,
    input  row0_valid,
    input  [data_width-1:0] row1,
    input  row1_valid,
    input  [data_width-1:0] row2,
    input  row2_valid,
    input  [data_width-1:0] row3,
    input  row3_valid,
    input  [data_width-1:0] row4,
    input  row4_valid,
    input  odd_cnt,
    output p_write_zero0,
    output p_write_zero1,
    output p_write_zero2,
    output p_write_zero3,
    output p_write_zero4,
    output p_init,
    output [data_width-1:0] out_port0,
    output [data_width-1:0] out_port1,
    output port0_valid,
    output port1_valid,
    output start_conv
);

    /// State encoding
    localparam IDLE         = 4'b0000,
               INIT_BUFF    = 4'b0001,
               START_CONV   = 4'b0010,
               WAIT_ADD     = 4'b0011,
               ROW_0_1      = 4'b0100,
               CLEAR_0_1    = 4'b0101,
               ROW_2_3      = 4'b0110,
               CLEAR_2_3    = 4'b0111,
               ROW_5        = 4'b1000,
               CLEAR_START_CONV = 4'b1001,
               CLEAR_CNT    = 4'b1010;

    /// Registers
    reg [3:0] st_next, st_cur;
    reg [7:0] cnt;

    /// State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            st_cur <= IDLE;
        else
            st_cur <= st_next;
    end

    /// State transition logic
    always @(*) begin
        st_next = st_cur;
        case (st_cur)
            IDLE:             st_next = start_init ? INIT_BUFF : IDLE;
            INIT_BUFF:        st_next = (cnt == depth-1) ? START_CONV : INIT_BUFF;
            START_CONV:       st_next = (cnt >= depth+2) ? CLEAR_START_CONV : START_CONV;
            CLEAR_START_CONV: st_next = p_filter_end ? WAIT_ADD : CLEAR_START_CONV;
            WAIT_ADD:         st_next = (cnt == depth-1) ? CLEAR_CNT : WAIT_ADD;
            CLEAR_CNT:        st_next = ROW_0_1;
            ROW_0_1:          st_next = (cnt == depth-1) ? CLEAR_0_1 : ROW_0_1;
            CLEAR_0_1:        st_next = ROW_2_3;
            ROW_2_3:          st_next = (cnt == depth-1) ? CLEAR_2_3 : ROW_2_3;
            CLEAR_2_3:        st_next = ROW_5;
            ROW_5:            st_next = (cnt == depth-1) ? START_CONV : ROW_5;
            default:          st_next = IDLE;
        endcase
    end

    /// Zero write control logic
    reg p_write_zero0_r, p_write_zero1_r, p_write_zero2_r, p_write_zero3_r, p_write_zero4_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            p_write_zero0_r <= 0;
            p_write_zero1_r <= 0;
            p_write_zero2_r <= 0;
            p_write_zero3_r <= 0;
            p_write_zero4_r <= 0;
        end else begin
            p_write_zero0_r <= (st_cur == ROW_0_1);
            p_write_zero1_r <= (st_cur == ROW_0_1);
            p_write_zero2_r <= (st_cur == ROW_2_3);
            p_write_zero3_r <= (st_cur == ROW_2_3);
            p_write_zero4_r <= (st_cur == ROW_5);
        end
    end

    assign p_write_zero0 = p_write_zero0_r;
    assign p_write_zero1 = p_write_zero1_r;
    assign p_write_zero2 = p_write_zero2_r;
    assign p_write_zero3 = p_write_zero3_r;
    assign p_write_zero4 = p_write_zero4_r;

    /// Initialization signal for buffer
    reg p_init_r;
    always @(posedge clk or negedge rst_n)
        if (!rst_n) p_init_r <= 0;
        else        p_init_r <= (st_cur == INIT_BUFF);
    assign p_init = p_init_r;

    /// Start convolution flag
    reg start_conv_r;
    always @(posedge clk or negedge rst_n)
        if (!rst_n) start_conv_r <= 0;
        else        start_conv_r <= (st_cur == START_CONV);
    assign start_conv = start_conv_r;

    /// Controlled counter
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            cnt <= 0;
        else if (st_cur == IDLE || st_cur == CLEAR_0_1 || st_cur == CLEAR_START_CONV || 
                 st_cur == CLEAR_2_3 || st_cur == CLEAR_CNT)
            cnt <= 0;
        else
            cnt <= cnt + 1;
    end

    /// Output mux: safely select output data with valid flags
    reg [data_width-1:0] out_port0_r, out_port1_r;
    reg port0_valid_r, port1_valid_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_port0_r <= {data_width{1'b0}};
            out_port1_r <= {data_width{1'b0}};
            port0_valid_r <= 0;
            port1_valid_r <= 0;
        end else begin
            case ({row0_valid, row1_valid, row2_valid, row3_valid, row4_valid})
                5'b11000: begin
                    out_port0_r    <= row0;
                    out_port1_r    <= row1;
                    port0_valid_r  <= 1;
                    port1_valid_r  <= 1;
                end
                5'b00110: begin
                    out_port0_r    <= row2;
                    out_port1_r    <= row3;
                    port0_valid_r  <= 1;
                    port1_valid_r  <= 1;
                end
                5'b00001: begin
                    out_port0_r    <= row4;
                    out_port1_r    <= 0;
                    port0_valid_r  <= 1;
                    port1_valid_r  <= 0;
                end
                default: begin
                    out_port0_r    <= 0;
                    out_port1_r    <= 0;
                    port0_valid_r  <= 0;
                    port1_valid_r  <= 0;
                end
            endcase
        end
    end

    assign out_port0   = out_port0_r;
    assign out_port1   = out_port1_r;
    assign port0_valid = port0_valid_r;
    assign port1_valid = port1_valid_r;

endmodule


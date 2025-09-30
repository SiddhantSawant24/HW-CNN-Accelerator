///==------------------------------------------------------------------==///
/// Conv kernel: synchronous FIFO
///==------------------------------------------------------------------==///
/// Synchronous FIFO
module SYNCH_FIFO #(
    parameter data_width = 25,
    parameter addr_width = 8,
    parameter depth      = 61
) (
    /// Control signal
    input clk,
    input rd_en,
    input wr_en,
    input rst_n,
    /// status signal
    output empty,
    output full,
    /// data signal
    output reg [data_width-1:0] data_out,
    input [data_width-1:0] data_in
);

    reg [addr_width:0] cnt;
    reg [data_width-1:0] fifo_mem [0:depth-1];
    reg [addr_width-1:0] rd_ptr;
    reg [addr_width-1:0] wr_ptr;

    integer i;

    /// Status generation
    assign empty = (cnt == 0);
    assign full  = (cnt == depth);

    /// Initialize everything on reset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr   <= 0;
            wr_ptr   <= 0;
            cnt      <= 0;
            data_out <= {data_width{1'b0}};
            for (i = 0; i < depth; i = i + 1)
                fifo_mem[i] <= {data_width{1'b0}};
        end else begin
            // Write Operation
            if (wr_en && !full) begin
                fifo_mem[wr_ptr] <= data_in;
                wr_ptr <= (wr_ptr == depth - 1) ? 0 : wr_ptr + 1;
            end

            // Read Operation
            if (rd_en && !empty) begin
                data_out <= fifo_mem[rd_ptr];
                rd_ptr <= (rd_ptr == depth - 1) ? 0 : rd_ptr + 1;
            end

            // Counter Logic
            case ({wr_en && !full, rd_en && !empty})
                2'b01: cnt <= cnt - 1;
                2'b10: cnt <= cnt + 1;
                default: cnt <= cnt;
            endcase
        end
    end

    /// Debug log: write and read monitoring
    always @(posedge clk) begin
        if (wr_en && !full)
            $display("[SYNCH_FIFO][WRITE] Time=%0t | Data In: %h | wr_ptr: %d", $time, data_in, wr_ptr);
        if (rd_en && !empty)
            $display("[SYNCH_FIFO][READ ]  Time=%0t | Data Out: %h | rd_ptr: %d", $time, data_out, rd_ptr);
    end

endmodule


module filtfilt68_top #(
    parameter integer W = 32,
    parameter integer FRAC = 24,
    parameter integer N = 68
) (
    input  wire                clk,
    input  wire                rst_n,
    input  wire                start,
    input  wire                in_valid,
    input  wire signed [W-1:0] in_data,
    output reg                 in_ready,
    output reg                 out_valid,
    output reg  signed [W-1:0] out_data,
    output reg                 done
);
    localparam S_IDLE    = 3'd0;
    localparam S_LOAD    = 3'd1;
    localparam S_FWD     = 3'd2;
    localparam S_REV1    = 3'd3;
    localparam S_BWD     = 3'd4;
    localparam S_REV2OUT = 3'd5;

    reg [2:0] state;
    reg [6:0] wr_ptr, rd_ptr, out_ptr;

    reg signed [W-1:0] buf0 [0:N-1];
    reg signed [W-1:0] buf1 [0:N-1];

    reg fir_valid;
    reg signed [W-1:0] fir_in;
    wire fir_out_valid;
    wire signed [W-1:0] fir_out;

    iir4_fixed #(.W(W), .FRAC(FRAC)) u_iir (
        .clk(clk), .rst_n(rst_n), .in_valid(fir_valid), .x_in(fir_in),
        .out_valid(fir_out_valid), .y_out(fir_out)
    );

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            wr_ptr <= 0; rd_ptr <= 0; out_ptr <= 0;
            in_ready <= 1'b0; out_valid <= 1'b0; done <= 1'b0;
            fir_valid <= 1'b0; fir_in <= '0; out_data <= '0;
        end else begin
            out_valid <= 1'b0;
            fir_valid <= 1'b0;
            done <= 1'b0;
            case (state)
                S_IDLE: begin
                    in_ready <= 1'b0;
                    if (start) begin
                        wr_ptr <= 0;
                        in_ready <= 1'b1;
                        state <= S_LOAD;
                    end
                end
                S_LOAD: begin
                    if (in_valid && in_ready) begin
                        buf0[wr_ptr] <= in_data;
                        if (wr_ptr == N-1) begin
                            in_ready <= 1'b0;
                            rd_ptr <= 0;
                            state <= S_FWD;
                        end
                        wr_ptr <= wr_ptr + 1'b1;
                    end
                end
                S_FWD: begin
                    if (rd_ptr < N) begin
                        fir_valid <= 1'b1;
                        fir_in <= buf0[rd_ptr];
                        rd_ptr <= rd_ptr + 1'b1;
                    end
                    if (fir_out_valid) begin
                        buf1[rd_ptr-1] <= fir_out;
                        if (rd_ptr == N && (rd_ptr-1) == N-1) begin
                            state <= S_REV1;
                        end
                    end
                end
                S_REV1: begin
                    for (i = 0; i < N; i = i + 1)
                        buf0[i] <= buf1[N-1-i];
                    rd_ptr <= 0;
                    state <= S_BWD;
                end
                S_BWD: begin
                    if (rd_ptr < N) begin
                        fir_valid <= 1'b1;
                        fir_in <= buf0[rd_ptr];
                        rd_ptr <= rd_ptr + 1'b1;
                    end
                    if (fir_out_valid) begin
                        buf1[rd_ptr-1] <= fir_out;
                        if (rd_ptr == N && (rd_ptr-1) == N-1) begin
                            out_ptr <= 0;
                            state <= S_REV2OUT;
                        end
                    end
                end
                S_REV2OUT: begin
                    out_valid <= 1'b1;
                    out_data <= buf1[N-1-out_ptr];
                    if (out_ptr == N-1) begin
                        done <= 1'b1;
                        state <= S_IDLE;
                    end
                    out_ptr <= out_ptr + 1'b1;
                end
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule

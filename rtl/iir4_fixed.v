module iir4_fixed #(
    parameter integer W = 32,
    parameter integer FRAC = 24
) (
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  in_valid,
    input  wire signed [W-1:0]   x_in,
    output reg                   out_valid,
    output reg  signed [W-1:0]   y_out
);

    // Q8.24 fixed-point coefficients
    localparam signed [W-1:0] B0 = 32'sd80939;    // 0.004824343357716
    localparam signed [W-1:0] B1 = 32'sd323758;   // 0.019297373430865
    localparam signed [W-1:0] B2 = 32'sd485637;   // 0.028946060146297
    localparam signed [W-1:0] B3 = 32'sd323758;
    localparam signed [W-1:0] B4 = 32'sd80939;

    localparam signed [W-1:0] A1 = -32'sd39753777; // -2.369513007182036
    localparam signed [W-1:0] A2 = 32'sd38822361;  // 2.313988414415877
    localparam signed [W-1:0] A3 = -32'sd17694459; // -1.054665405878565
    localparam signed [W-1:0] A4 = 32'sd3143708;   // 0.187379492368184

    localparam signed [W-1:0] Z0_INIT = 32'sd16696277; // 0.9951756566422711
    localparam signed [W-1:0] Z1_INIT = -32'sd23381254;// -1.3936347239705993
    localparam signed [W-1:0] Z2_INIT = 32'sd14955397; // 0.8914076302989508
    localparam signed [W-1:0] Z3_INIT = -32'sd3062768; // -0.1825551490104656

    reg signed [W-1:0] z0, z1, z2, z3;

    function automatic signed [W-1:0] qmul;
        input signed [W-1:0] a;
        input signed [W-1:0] b;
        reg   signed [2*W-1:0] p;
        begin
            p = a * b;
            qmul = p >>> FRAC;
        end
    endfunction

    reg signed [W-1:0] y_next, nz0, nz1, nz2, nz3;

    always @(*) begin
        y_next = qmul(B0, x_in) + z0;
        nz0    = qmul(B1, x_in) + z1 - qmul(A1, y_next);
        nz1    = qmul(B2, x_in) + z2 - qmul(A2, y_next);
        nz2    = qmul(B3, x_in) + z3 - qmul(A3, y_next);
        nz3    = qmul(B4, x_in)          - qmul(A4, y_next);
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            z0 <= Z0_INIT;
            z1 <= Z1_INIT;
            z2 <= Z2_INIT;
            z3 <= Z3_INIT;
            y_out <= '0;
            out_valid <= 1'b0;
        end else begin
            out_valid <= in_valid;
            if (in_valid) begin
                y_out <= y_next;
                z0 <= nz0;
                z1 <= nz1;
                z2 <= nz2;
                z3 <= nz3;
            end
        end
    end
endmodule

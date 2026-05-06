module iir4_dw_fp32 (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         clr_state,
    input  wire         in_valid,
    input  wire [31:0]  x_in,
    output reg          out_valid,
    output reg  [31:0]  y_out
);
    // IEEE754 single-precision constants
    localparam [31:0] B0 = 32'h3b9e4631; // 0.004824343357716
    localparam [31:0] B1 = 32'h3c9e4631; // 0.019297373430865
    localparam [31:0] B2 = 32'h3ced8968; // 0.028946060146297
    localparam [31:0] B3 = 32'h3c9e4631;
    localparam [31:0] B4 = 32'h3b9e4631;

    localparam [31:0] A1 = 32'hc017a639; // -2.369513007182036
    localparam [31:0] A2 = 32'h4014149c; // 2.313988414415877
    localparam [31:0] A3 = 32'hbf870007; // -1.054665405878565
    localparam [31:0] A4 = 32'h3e3fe24a; // 0.187379492368184

    localparam [31:0] Z0_INIT = 32'h3f7ec3b8;
    localparam [31:0] Z1_INIT = 32'hbfb26820;
    localparam [31:0] Z2_INIT = 32'h3f6436b4;
    localparam [31:0] Z3_INIT = 32'hbe3af52c;

    localparam [2:0] RND = 3'b000;

    reg [31:0] z0, z1, z2, z3;

    wire [31:0] b0x, b1x, b2x, b3x, b4x;
    wire [31:0] a1y, a2y, a3y, a4y;
    wire [31:0] y_calc, z0_n, z1_n, z2_n, z3_n;

    // Multipliers
    DW_fp_mult #(23,8,0) u_m_b0 (.a(B0), .b(x_in), .rnd(RND), .z(b0x), .status());
    DW_fp_mult #(23,8,0) u_m_b1 (.a(B1), .b(x_in), .rnd(RND), .z(b1x), .status());
    DW_fp_mult #(23,8,0) u_m_b2 (.a(B2), .b(x_in), .rnd(RND), .z(b2x), .status());
    DW_fp_mult #(23,8,0) u_m_b3 (.a(B3), .b(x_in), .rnd(RND), .z(b3x), .status());
    DW_fp_mult #(23,8,0) u_m_b4 (.a(B4), .b(x_in), .rnd(RND), .z(b4x), .status());

    DW_fp_mult #(23,8,0) u_m_a1 (.a(A1), .b(y_calc), .rnd(RND), .z(a1y), .status());
    DW_fp_mult #(23,8,0) u_m_a2 (.a(A2), .b(y_calc), .rnd(RND), .z(a2y), .status());
    DW_fp_mult #(23,8,0) u_m_a3 (.a(A3), .b(y_calc), .rnd(RND), .z(a3y), .status());
    DW_fp_mult #(23,8,0) u_m_a4 (.a(A4), .b(y_calc), .rnd(RND), .z(a4y), .status());

    // Add/Sub trees
    DW_fp_add #(23,8,0) u_add_y  (.a(b0x), .b(z0), .rnd(RND), .z(y_calc), .status());

    wire [31:0] t0, t1, t2, t3;
    DW_fp_add #(23,8,0) u_add_t0 (.a(b1x), .b(z1), .rnd(RND), .z(t0), .status());
    DW_fp_add #(23,8,0) u_add_t1 (.a(b2x), .b(z2), .rnd(RND), .z(t1), .status());
    DW_fp_add #(23,8,0) u_add_t2 (.a(b3x), .b(z3), .rnd(RND), .z(t2), .status());

    DW_fp_sub #(23,8,0) u_sub_z0 (.a(t0), .b(a1y), .rnd(RND), .z(z0_n), .status());
    DW_fp_sub #(23,8,0) u_sub_z1 (.a(t1), .b(a2y), .rnd(RND), .z(z1_n), .status());
    DW_fp_sub #(23,8,0) u_sub_z2 (.a(t2), .b(a3y), .rnd(RND), .z(z2_n), .status());
    DW_fp_sub #(23,8,0) u_sub_z3 (.a(b4x), .b(a4y), .rnd(RND), .z(z3_n), .status());

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            z0 <= Z0_INIT; z1 <= Z1_INIT; z2 <= Z2_INIT; z3 <= Z3_INIT;
            y_out <= 32'h0;
            out_valid <= 1'b0;
        end else if (clr_state) begin
            z0 <= Z0_INIT; z1 <= Z1_INIT; z2 <= Z2_INIT; z3 <= Z3_INIT;
            y_out <= 32'h0;
            out_valid <= 1'b0;
        end else begin
            out_valid <= in_valid;
            if (in_valid) begin
                y_out <= y_calc;
                z0 <= z0_n;
                z1 <= z1_n;
                z2 <= z2_n;
                z3 <= z3_n;
            end
        end
    end
endmodule

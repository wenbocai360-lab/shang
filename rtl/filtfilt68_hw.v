module filtfilt68_hw #(
    parameter integer W = 32,
    parameter integer FRAC = 24,
    parameter integer NS = 68,
    parameter integer NFACT = 12,
    parameter integer EXT = NS + 2*NFACT
) (
    input  wire                clk,
    input  wire                rst_n,
    input  wire                start,
    input  wire                in_valid,
    input  wire signed [W-1:0] in_data,
    output reg                 in_ready,
    output reg                 out_valid,
    output reg signed [W-1:0]  out_data,
    output reg                 done
);
    localparam ST_IDLE=0, ST_WAIT_FIRSTX=1, ST_EXTEND=2,
               ST_START_FILTER_IIR_FIRST=3, ST_WAIT_FILTER_IIR_FIRST=4,
               ST_REVERSE_1=5, ST_START_FILTER_IIR_SECOND=6,
               ST_WAIT_FILTER_IIR_SECOND=7, ST_REVERSE_2=8,
               ST_SAVE=9;
    reg [3:0] st;

    reg signed [W-1:0] x[0:NS-1];
    reg signed [W-1:0] ext0[0:EXT-1];
    reg signed [W-1:0] ext1[0:EXT-1];

    reg [7:0] idx;
    reg iir_clr, iir_in_valid;
    reg signed [W-1:0] iir_x;
    wire iir_out_valid;
    wire signed [W-1:0] iir_y;

    iir4_df2t_fixed #(.W(W), .FRAC(FRAC)) u_iir (
        .clk(clk), .rst_n(rst_n), .clr_state(iir_clr),
        .in_valid(iir_in_valid), .x_in(iir_x),
        .out_valid(iir_out_valid), .y_out(iir_y)
    );

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            st<=ST_IDLE; idx<=0; in_ready<=0; out_valid<=0; done<=0;
            iir_clr<=0; iir_in_valid<=0; iir_x<='0; out_data<='0;
        end else begin
            out_valid<=0; done<=0; iir_clr<=0; iir_in_valid<=0;
            case(st)
                ST_IDLE: begin
                    in_ready<=0; idx<=0;
                    if(start) begin in_ready<=1; st<=ST_WAIT_FIRSTX; end
                end
                ST_WAIT_FIRSTX: begin
                    if(in_valid && in_ready) begin
                        x[idx] <= in_data;
                        if(idx==NS-1) begin
                            in_ready<=0; idx<=0; st<=ST_EXTEND;
                        end else idx<=idx+1;
                    end
                end
                ST_EXTEND: begin
                    for(i=0;i<NFACT;i=i+1) begin
                        ext0[i] <= x[NFACT-i];
                        ext0[EXT-1-i] <= x[NS-2-i];
                    end
                    for(i=0;i<NS;i=i+1) ext0[NFACT+i] <= x[i];
                    idx<=0; st<=ST_START_FILTER_IIR_FIRST;
                end
                ST_START_FILTER_IIR_FIRST: begin
                    iir_clr<=1; idx<=0; st<=ST_WAIT_FILTER_IIR_FIRST;
                end
                ST_WAIT_FILTER_IIR_FIRST: begin
                    if(idx < EXT) begin
                        iir_in_valid<=1; iir_x<=ext0[idx]; idx<=idx+1;
                    end
                    if(iir_out_valid) ext1[idx-1] <= iir_y;
                    if(idx==EXT && iir_out_valid) begin idx<=0; st<=ST_REVERSE_1; end
                end
                ST_REVERSE_1: begin
                    for(i=0;i<EXT;i=i+1) ext0[i] <= ext1[EXT-1-i];
                    idx<=0; st<=ST_START_FILTER_IIR_SECOND;
                end
                ST_START_FILTER_IIR_SECOND: begin
                    iir_clr<=1; idx<=0; st<=ST_WAIT_FILTER_IIR_SECOND;
                end
                ST_WAIT_FILTER_IIR_SECOND: begin
                    if(idx < EXT) begin
                        iir_in_valid<=1; iir_x<=ext0[idx]; idx<=idx+1;
                    end
                    if(iir_out_valid) ext1[idx-1] <= iir_y;
                    if(idx==EXT && iir_out_valid) begin idx<=0; st<=ST_REVERSE_2; end
                end
                ST_REVERSE_2: begin
                    for(i=0;i<EXT;i=i+1) ext0[i] <= ext1[EXT-1-i];
                    idx<=0; st<=ST_SAVE;
                end
                ST_SAVE: begin
                    out_valid<=1;
                    out_data<=ext0[NFACT+idx];
                    if(idx==NS-1) begin done<=1; st<=ST_IDLE; end
                    else idx<=idx+1;
                end
            endcase
        end
    end
endmodule

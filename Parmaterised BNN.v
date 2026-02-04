module BNN_Layer_1#(
    parameter IN_WIDTH=512,
parameter OUT_WIDTH=64,
parameter XNORS=64,
parameter T= 256,
parameter POP_WIDTH=$clog2(XNORS)+1,
parameter CYCLES_PER_NEURON=IN_WIDTH/XNORS,
parameter WEIGHT_LOCATION="C:/Verilog_projects/64to1_1H_BNN/layer2_weights.mem"
)
(   input clk,reset,
    input[IN_WIDTH-1:0] in_layer,
    output reg[OUT_WIDTH-1:0] layer_out,
    output reg done
);

reg[IN_WIDTH-1:0] weights_matrix[OUT_WIDTH-1:0];
reg[XNORS-1:0] input_buffer;
reg [$clog2(CYCLES_PER_NEURON):0] cycle_count;
reg[$clog2(OUT_WIDTH):0] neuron_idx;
reg[POP_WIDTH:0] popouts;
reg [POP_WIDTH:0] POPCOUNT;


integer i,j;

initial begin
    $readmemb(WEIGHT_LOCATION, l2_weights);
end


always@(*) begin
    popouts=0;
    for (j=0;j<XNORS;j=j+1) begin
        popouts = popouts + ~(input_buffer[j] ^ weight_matrix[neuron_idx][j+ cycle_count*XNORS]);
    end
end


always@(posedge clk or posedge reset) begin
    if(reset) begin
        cycle_count <= 0;
        neuron_idx <= 0;
        POPCOUNT <= 0;
        layer_out<=0;

        done <= 0;

    end
    else if(!done) begin
       
       input_buffer <=in_layer[cycle_count*XNORS+:XNORS];
   
        if(cycle_count<CYCLES_PER_NEURON-1) begin
            cycle_count <= cycle_count + 1;
            POPCOUNT <= POPCOUNT+popouts;
        end
        else if(cycle_count == CYCLES_PER_NEURON - 1) begin
            cycle_count <= 0;
            layer_out[neuron_idx]<=(POPCOUNT+popouts>=T);
            POPCOUNT<=0;

            if(neuron_idx == OUT_WIDTH - 1) begin
            neuron_idx<=0;
            done<=1;
            end

            else begin

            
            neuron_idx <= neuron_idx + 1;

            end
        end

    end
end
endmodule
            
    

        
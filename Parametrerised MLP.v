module hybridlayer_1 #(

    parameter IN_WIDTH         = 256,
    parameter OUT_WIDTH        = 128,
    parameter PARALLEL_MACS    = 32,
    parameter ACC_WIDTH        = 8 + 8 + $clog2(IN_WIDTH),
    parameter CYCLES_PER_NEURON= IN_WIDTH / PARALLEL_MACS

)(
    input  clk,
    input  reset,

    input  [(IN_WIDTH*8)-1:0] in_layer,      // instead of array we took it as a 1D vector
    output reg [OUT_WIDTH-1:0] out,
    output reg done
);

reg is_input_loaded;

reg signed [7:0] input_buffer  [IN_WIDTH-1:0];                 // inputs stored in register
reg signed [7:0] weight_matrix [IN_WIDTH-1:0][OUT_WIDTH-1:0];

wire signed [ACC_WIDTH:0] next_sum;

reg  signed [ACC_WIDTH:0] current_cycle_product;
reg  signed [ACC_WIDTH:0] accumulators [OUT_WIDTH-1:0];

reg [$clog2(IN_WIDTH):0]           neuron_idx;
reg [$clog2(CYCLES_PER_NEURON):0]  cycle_count;

integer i;

wire signed [7:0] act_in [IN_WIDTH-1:0];   // wire connecting input to input_buffer

genvar j;
generate
    for (j = 0; j < IN_WIDTH; j = j + 1) begin
        assign act_in[j] = in_layer[(j*8)+7 : j*8];   // 1D to 2D conversion
    end
endgenerate

assign next_sum = current_cycle_product + accumulators[neuron_idx];

always @(*) begin
    current_cycle_product = 0;
    for (i = 0; i < PARALLEL_MACS; i = i + 1) begin
        current_cycle_product =
            current_cycle_product +
            input_buffer[i + cycle_count * PARALLEL_MACS] *
            weight_matrix[i + cycle_count * PARALLEL_MACS][neuron_idx];
    end
end

always @(posedge clk or posedge reset) begin

    if (reset == 1) begin
        cycle_count     <= 0;
        neuron_idx      <= 0;
        done            <= 1'b0;
        is_input_loaded <= 0;

        for (i = 0; i < OUT_WIDTH; i = i + 1)
            accumulators[i] <= 0;
    end

    else if (!is_input_loaded) begin
        for (i = 0; i < IN_WIDTH; i = i + 1)
            input_buffer[i] <= act_in[i];

        is_input_loaded <= 1;
    end

    else if (~done) begin

        if (cycle_count < (CYCLES_PER_NEURON - 1)) begin
            accumulators[neuron_idx] <= next_sum;
            cycle_count <= cycle_count + 1;
        end

        else if (cycle_count == (CYCLES_PER_NEURON - 1)) begin
            cycle_count <= 0;
            accumulators[neuron_idx] <= 0;

            out[neuron_idx] <= (next_sum >= $signed(0));

            if (neuron_idx == OUT_WIDTH - 1)
                done <= 1;
            else
                neuron_idx <= neuron_idx + 1;
        end

    end

end

endmodule

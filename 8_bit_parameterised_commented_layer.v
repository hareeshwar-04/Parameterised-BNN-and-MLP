module hybridlayer_1 #(

    parameter IN_WIDTH         = 256,
    parameter OUT_WIDTH        = 128,
    parameter PARALLEL_MACS    = 32, 

    /*
    It corresponds to the size which stores the the sum of the 256 products , whihc is for one neuron   
     Accumulator width should be , 8+8 becuase we're multiplying two 8 bit numbers , so max result is 8+8 , and we are 
    adding is 256 times in the extreme case , if we add 256 highest possible 16 bit numbers , then we would require 1
    extra bit per doubling , like for x2 , +1 bit next another x2 , another +1 , so if we double it 8 times , which is 2^8=256 ,
    so we need clog2(256) extra bits
    
    */
    
    parameter ACC_WIDTH        = 8 + 8 + $clog2(IN_WIDTH),

    /* there 128 neurons on total , each nueron has 256 calculations , so we 32 calculations by once. so 256/32 cycles per neuron  */
    parameter CYCLES_PER_NEURON= IN_WIDTH / PARALLEL_MACS

)(
    input  clk,
    input  reset,

    input  [(IN_WIDTH*8)-1:0] in_layer,      // instead of 2D we took it as a 1D vector , this helps in better data routing for the FGPA
    output reg [OUT_WIDTH-1:0] out,          // input to the next layer , completely binarised
    output reg done      // flags when the layer is done
);

reg is_input_loaded;  

reg signed [7:0] input_buffer  [IN_WIDTH-1:0];                 // inputs stored in register , should be all loaded when amcs start
reg signed [7:0] weight_matrix [IN_WIDTH-1:0][OUT_WIDTH-1:0]; //weights are stored in a 2D fashion

initial begin
    $readmemh("C:/Verilog_projects/Parmaterised Hybrid BNN/Parameterised BNN and MLP/weights.mem", weight_matrix);
end

wire signed [ACC_WIDTH:0] next_sum;
/*
stores the sum of 32 parallel mac , took it 24 bits rather than 21 bits because this will get recursively added to the final accumulator sum 
which is of 24 bits , so its easier to add
 
*/
reg  signed [ACC_WIDTH:0] parallel_sops; 
/*
Stores the sum of each neuron , hence its indexed from from 0 to 128 as there are 128 neurons
*/
reg  signed [ACC_WIDTH:0] each_neuron_sum [OUT_WIDTH-1:0];

/*
neuron index flag and the cycle count flag
*/

reg [$clog2(IN_WIDTH):0]           neuron_idx;

reg [$clog2(CYCLES_PER_NEURON):0]  cycle_count;

integer i;

wire signed [7:0] act_in [IN_WIDTH-1:0];   // wire connecting input to input_buffer

genvar j;
generate
     /*  act_in[0]=in_layer[7:0] 
            act_in[1]=in_layer[15:8] 
            act_in[2]=in_layer[23:16]
            ......
            ......
            ......
            act_in[255]=in_layer[2047:2040]
        */
    for (j = 0; j < IN_WIDTH; j = j + 1) begin
       
        assign act_in[j] = in_layer[(j*8)+7 : j*8];   // 1D to 2D conversion
    end

endgenerate 
/*
----------------------------------------------------------------------------
                        
                          INPUTS ARE READY
                    
----------------------------------------------------------------------------
*/               

/*
wire which holds the next value which should be given into the each neuron sum register

next sum updates instantaneously where as the each_neuron_sum register updates only at the clock edge

so it basically adds the 32 parallel sops to the final sum

example
Cycle 1: each_neuron_sum is 0. next_sum becomes (32 products + 0). On the clock edge, this value is saved back into each_neuron_sum.

Cycle 2: each_neuron_sum now holds the first 32 products. next_sum becomes (New 32 products + Old 32 products). On the clock edge, this new total (64 products) is saved back.

Repeat: This continues until you have added all 256 inputs.

this gives us the oppportunity to instantly use the register value before the cclock edghe for other if and else blocks , whcih usually saves one clokc cycle dewlay
*/
assign next_sum = parallel_sops + each_neuron_sum[neuron_idx];

always @(*) begin
    parallel_sops = 0;

    /* this is where the 32 macs are created */

    for (i = 0; i < PARALLEL_MACS; i = i + 1) begin
        parallel_sops =
            parallel_sops +
            input_buffer[i + cycle_count * PARALLEL_MACS] *
            weight_matrix[i + cycle_count * PARALLEL_MACS][neuron_idx];  //Uses muxes for sending the value as per the indexes from the weights and input buffer
    end
end

/* The registers are now working here , the code has been entered into its hardest part , the pipelining */

always @(posedge clk or posedge reset) begin

 //reset everything

    if (reset == 1) begin
        cycle_count     <= 0;
        neuron_idx      <= 0;
        done            <= 1'b0;
        is_input_loaded <= 0;

// as we are adding the sums in feedback , we should initially start wiht zero

        for (i = 0; i < OUT_WIDTH; i = i + 1)
            each_neuron_sum[i] <= 0;
    end

//load the inputs if its not loaded into the buffer

    else if (!is_input_loaded) begin
        for (i = 0; i < IN_WIDTH; i = i + 1)
            input_buffer[i] <= act_in[i];

        is_input_loaded <= 1;
    end

    else if (~done) begin
 
        if (cycle_count < (CYCLES_PER_NEURON - 1)) begin
            each_neuron_sum[neuron_idx] <= next_sum;  //the values of each cycle , each 32 mac output is getting incremented into the individual neuron sum register
            cycle_count <= cycle_count + 1;
        end

        else if (cycle_count == (CYCLES_PER_NEURON - 1)) begin
            cycle_count <= 0; //We gonna start the cycles for a new neuron


            /*we gonna reset the neuron sum  , not mandatory if the input is only one image
            , but if we insert a another iumage without resetting , we shoudl reset ie clear the register for future use , here it wont matter
            just for more industry oriented
            */

            each_neuron_sum[neuron_idx] <= 0; 

            /* 
            we're comapring the next sum with the threshold cuz the last cycles parallel_sops never actually goes in to neuron sum registers , intead it only gets
            updated in the next sum , so in the 256 , the final value the nueron sum reg stores is the 224 products sum. so why to use the regsiter then?? we use 
            the register for only the sumation purpose
            */
            out[neuron_idx] <= (next_sum >= $signed(0));


            /*
            number of neurons have been finished . hence we are gonna flag done in the layer and it will be halted
            */

            if (neuron_idx == OUT_WIDTH - 1)
                done <= 1;
            else
                neuron_idx <= neuron_idx + 1;
        end

    end

end

endmodule

module hybridlayer_1(
    input clk,reset,
    input [2047:0] in_layer1,
    output reg[127:0] out
);
reg loadinput;
reg done;
reg signed[7:0] l1_act[255:0];
reg signed[7:0] l1_wt[255:0][127:0];
wire signed[23:0] next_sum;

reg signed[23:0] partial_sum;
reg signed[23:0] l1_acc[127:0];
reg[8:0]d;
reg[4:0]c;

integer i;

// Change this in your declarations
wire signed [7:0] act_in [255:0]; 

genvar j;
generate
    for (j = 0; j < 256; j = j + 1) begin
        assign act_in[j] = in_layer1[(j*8)+7 : j*8];
    end
endgenerate


assign next_sum=partial_sum+l1_acc[d];
always@(*) begin
    partial_sum=0;
    for(i=0;i<32;i=i+1)begin
    partial_sum=partial_sum+l1_act[i+c*32]*l1_wt[i+c*32][d];   //adds all the 32 partial sums required for one neuron
    end
end

always@(posedge clk or posedge reset)
begin
    if(reset==1)
    begin
        c<=0;
        d<=0;
        done<=1'b0;
        loadinput<=0;
        for(i=0;i<128;i=i+1)
        l1_acc[i]<=23'd0;
        
    end
    else if(!loadinput)
    begin
        for(i=0;i<256;i=i+1)
        l1_act[i]<=act_in[i];
        loadinput<=1;
    end
    else if(~done) begin
    
   if(c<7)begin
    l1_acc[d]<=next_sum; 
    
        c<=c+1;
    end
        
       

    else if(c==7) begin
    
        c<=0;
        l1_acc[d]<=23'd0;
        out[d]<=(next_sum>=$signed(0));
        if(d==127)
            done<=1;
        else 
         d<=d+1;
       
        
        
        
        
        
        
    end
       
        
        
        
        end
        
         
     end   
        
        
        
    

endmodule





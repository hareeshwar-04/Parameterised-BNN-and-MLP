import random

# Dimensions from your Verilog
IN_WIDTH = 256
OUT_WIDTH = 128

def generate_hex_mem(filename="weights.mem"):
    with open(filename, "w") as f:
        # For a 2D array [IN_WIDTH][OUT_WIDTH], 
        # Vivado expects IN_WIDTH * OUT_WIDTH total entries
        for i in range(IN_WIDTH):
            for j in range(OUT_WIDTH):
                # Generate random 8-bit signed integer (-128 to 127)
                val = random.randint(-128, 127)
                
                # Convert to 2-digit Hex (2's complement)
                hex_val = format(val & 0xFF, '02x')
                f.write(hex_val + "\n")

    print(f"Generated {filename} for [{IN_WIDTH}][{OUT_WIDTH}] array.")

if __name__ == "__main__":
    generate_hex_mem()
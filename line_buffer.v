

`timescale 1ns / 1ps

module line_buffer_4x4 #(
    parameter WIDTH = 320 
)(
    input wire         clk,
    input wire         rst_n,
    input wire         en,  
    input wire         i_valid,           // CHỖ SỬA 1: Input valid nhận từ tầng zipfian_pe
    input wire         pixel_status_in, 

    output wire        p_row0,
    output wire        p_row1,
    output wire        p_row2,
    output wire        p_row3,
    output wire         o_valid            // CHỖ SỬA 2: Output valid đồng bộ ra tầng block_accumulator
);

    reg [WIDTH-1:0] buffer_row1;
    reg [WIDTH-1:0] buffer_row2;
    reg [WIDTH-1:0] buffer_row3;

    // Khối điều khiển dịch hàng có điều kiện
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            buffer_row1 <= {WIDTH{1'b0}};
            buffer_row2 <= {WIDTH{1'b0}};
            buffer_row3 <= {WIDTH{1'b0}};
//            o_valid     <= 1'b0;
        end else if (en) begin
//            o_valid <= i_valid; // Tín hiệu Valid ngõ ra đi song song với nhịp dịch dữ liệu
            
            if (i_valid) begin  // CHỖ SỬA 3: Chỉ dịch hàng khi dữ liệu đầu vào thực sự Valid
                buffer_row1 <= {buffer_row1[WIDTH-2:0], pixel_status_in};
                buffer_row2 <= {buffer_row2[WIDTH-2:0], buffer_row1[WIDTH-1]};
                buffer_row3 <= {buffer_row3[WIDTH-2:0], buffer_row2[WIDTH-1]};
            end
        end
    end

    // Gán dữ liệu ra tổ hợp (giữ nguyên logic gốc)
    assign p_row0 = pixel_status_in;      
    assign p_row1 = buffer_row1[WIDTH-1]; 
    assign p_row2 = buffer_row2[WIDTH-1];  
    assign p_row3 = buffer_row3[WIDTH-1]; 
    assign o_valid = i_valid; // CHỖ SỬA 2: Truyền thẳng valid qua không qua thanh ghi
endmodule



`timescale 1ns / 1ps

module block_buffer(
    input wire clk, rst_n,
    input wire en,              // CHỖ SỬA 1: Thêm chân en hệ thống vào đây
    input wire i_data,
    input wire i_data_valid,
    output wire [79:0] o_data
);
    
    reg [79:0] shift_reg;

    always @(posedge clk) begin
        if (!rst_n) begin
            shift_reg <= 80'd0;
        // CHỖ SỬA 2: Chỉ dịch mạch khi hệ thống CHẠY (en) VÀ dữ liệu đầu vào VALID
        end else if (en && i_data_valid) begin 
            shift_reg <= { i_data, shift_reg[79:1] };
        end
    end

    // Dữ liệu luôn được lôi thẳng từ thanh ghi ra ngõ ra, không mất chu kỳ chờ đọc
    assign o_data = shift_reg;
endmodule

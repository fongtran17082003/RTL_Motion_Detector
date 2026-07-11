
`timescale 1ns / 1ps

module filter #(
    parameter MIN_NEIGHBOR = 3 
)(
    input  wire        i_clk,
    input  wire        i_rst_n,
    input  wire        i_en,           // CHỖ SỬA 1: Thêm chân Enable hệ thống
    input  wire [8:0]  i_window_3x3,   // Nhận từ block_control
    input  wire        i_window_valid, // Nhận từ block_control
     
    output reg         o_filter_data,  // Pixel đầu ra đã được lọc sạch nhiễu (1-bit)
    output reg         o_filter_valid  // Báo hiệu pixel đầu ra hợp lệ
);

    // 1. Phân rã cửa sổ 9-bit thành các ô riêng lẻ để dễ làm toán
    wire p0, p1, p2, p3, p4, p5, p6, p7, p8;
    
    assign p0 = i_window_3x3[0]; // top_3x[0] (Phải)
    assign p1 = i_window_3x3[1]; // top_3x[1] (Giữa)
    assign p2 = i_window_3x3[2]; // top_3x[2] (Trái)
    
    assign p3 = i_window_3x3[3]; // mid_3x[0] (Phải)
    assign p4 = i_window_3x3[4]; // mid_3x[1] <-- Ô TÂM
    assign p5 = i_window_3x3[5]; // mid_3x[2] (Trái)
    
    assign p6 = i_window_3x3[6]; // bot_3x[0] (Phải)
    assign p7 = i_window_3x3[7]; // bot_3x[1] (Giữa)
    assign p8 = i_window_3x3[8]; // bot_3x[2] (Trái)

    // 2. Tính tổng số lượng hàng xóm xung quanh ô tâm (Cộng mạch tổ hợp)
    wire [3:0] num_neighbors;
    assign num_neighbors = p0 + p1 + p2 + p3 + p5 + p6 + p7 + p8;

    // 3. Triển khai các biểu thức điều kiện logic
    wire cond_0;
    assign cond_0 = (p4 == 1'b1) && (num_neighbors > 4'd0);

    wire cond_1;
    assign cond_1 = (num_neighbors > MIN_NEIGHBOR);

    // Điểm ảnh hợp lệ sau lọc
    wire filtered_pixel;
    assign filtered_pixel = cond_0 || cond_1;

    // 4. CHỖ SỬA 2: Đồng bộ ngõ ra bằng Thanh ghi có quản lý bằng chân i_en
    always @(posedge i_clk) begin
        if (!i_rst_n) begin
            o_filter_data  <= 1'b0;
            o_filter_valid <= 1'b0;
        end else if (i_en) begin // <-- Chỉ cho phép cập nhật khi hệ thống CHẠY
            o_filter_data  <= i_window_valid ? filtered_pixel : 1'b0;
            o_filter_valid <= i_window_valid;
        end else begin
            // Khi i_en = 0 (Hệ thống dừng), giữ nguyên dữ liệu cũ, nhưng bắt buộc hạ Valid
            o_filter_valid <= 1'b0;
        end
    end

endmodule

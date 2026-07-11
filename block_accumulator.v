
`timescale 1ns / 1ps

module block_accumulator (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        en,
    input  wire        i_valid,           // CHỖ SỬA 1: Nhận valid từ line_buffer_4x4
    input  wire        p_row0,
    input  wire        p_row1,
    input  wire        p_row2,
    input  wire        p_row3,
    input  wire [4:0]  min_num_motion, 
    output reg         block_status,
    output reg         block_valid  
);
    wire [2:0] col_sum;
    assign col_sum = p_row0 + p_row1 + p_row2 + p_row3;
    
    reg [1:0] x_counter;    
    reg [4:0] block_sum;  
    wire [4:0] next_block_sum;
    assign next_block_sum = (x_counter == 2'd0) ? col_sum : (block_sum + col_sum);
    
    reg [8:0] pixel_in_row_cnt; 
    reg [7:0] y_counter;
    wire is_valid_row = (y_counter[1:0] == 2'b11);
    
    wire end_of_frame;
    reg end_of_frame_reg;
    assign end_of_frame = (pixel_in_row_cnt == 9'd319 && y_counter == 8'd179);
    
    // Tạo độ trễ 1 nhịp cho tín hiệu kết thúc khung hình
    always @(posedge clk) begin 
        if (!rst_n) begin 
            end_of_frame_reg <= 1'b0;
        end else if (en && i_valid) begin // CHỖ SỬA 2: Đồng bộ nhịp valid 
            end_of_frame_reg <= end_of_frame;
        end
    end

    // 1. Khối điều khiển bộ đếm tọa độ nội bộ (CHỈ CHẠY KHI VALID)
    always @(posedge clk) begin 
        if (!rst_n) begin 
            pixel_in_row_cnt <= 9'd0;
            y_counter        <= 8'd0;
        end else if (en && i_valid) begin // CHỖ SỬA 3: Chỉ đếm khi data thực sự valid
            if(pixel_in_row_cnt == 9'd319) begin
                pixel_in_row_cnt <= 9'd0;
                if (y_counter == 8'd179) begin 
                    y_counter <= 8'd0;
                end else begin 
                    y_counter <= y_counter + 8'd1;
                end
            end else begin 
                pixel_in_row_cnt <= pixel_in_row_cnt + 9'd1; 
            end 
        end
    end

    // 2. Khối tích lũy khối 4x4 
    always @(posedge clk) begin
        if (!rst_n) begin
            x_counter    <= 2'd0;
            block_sum    <= 5'd0;
            block_status <= 1'b0;
            block_valid  <= 1'b0;
        end else if (en) begin
            if (i_valid) begin // CHỖ SỬA 4: Xử lý tích lũy có điều kiện valid
                if (is_valid_row) begin
                    block_sum <= next_block_sum;
                    
                    if (x_counter == 2'd3) begin
                        x_counter    <= 2'd0;
                        block_valid  <= 1'b1; // Phát valid ra ngoài khi gom đủ khối 4x4
                        block_status <= (next_block_sum >= min_num_motion);
                    end else begin
                        x_counter    <= x_counter + 2'd1;
                        block_valid  <= 1'b0;
                    end
                end else begin
                    x_counter    <= 2'd0;
                    block_sum    <= 5'd0;
                    block_status <= 1'b0;
                    block_valid  <= 1'b0;
                end
            end else begin
                // CHỖ SỬA 5: Khi i_valid = 0, GIỮ NGUYÊN trạng thái tính toán, chỉ hạ block_valid
                block_valid <= 1'b0;
            end
        end
    end
endmodule

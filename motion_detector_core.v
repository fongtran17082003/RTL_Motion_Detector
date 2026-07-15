

`timescale 1ns / 1ps

module motion_detector_core #(
    parameter WIDTH = 320,
    parameter HEIGHT = 180
)(
    input wire clk,
    input wire rst_n,
    input wire en,
    input wire i_pixel_data_valid,   // CHỖ SỬA 1: Thêm valid đầu vào cho pixel
    input wire [7:0] pixel_in,
    input wire [7:0] m_in,
    input wire [7:0] v_in,
    output wire [7:0] m_next,
    output wire [7:0] v_next,
    output wire block_status,
    output wire block_valid,
    output reg [7:0] sigma,
    output reg [7:0] frame_ctr,
    output wire o_filtered_pixel,  
    output wire o_filtered_valid ,
    output reg [31:0]frame_done_cnt
);
    reg [15:0] pixel_ctr;
    reg update_v_en;
    wire [7:0] rank = frame_ctr - 8'd1;
    reg en_d1, en_d2;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            en_d1 <= 1'b0;
            en_d2 <= 1'b0;
        end else begin
            en_d1 <= en;
            en_d2 <= en_d1; 
        end
    end   
    always @(posedge clk or negedge rst_n) begin 
        if (!rst_n) begin 
            pixel_ctr <= 16'd0;
            frame_ctr <= 8'd0;
        end else if (en && i_pixel_data_valid) begin  
            if (pixel_ctr == (WIDTH*HEIGHT-1)) begin 
                pixel_ctr <= 16'd0;
                frame_ctr <= frame_ctr + 8'd1;
            end else begin 
                pixel_ctr <= pixel_ctr + 16'd1;
            end    
        end
    end

    always @(*) begin 
        update_v_en = (frame_ctr != 8'd0);
    end

    always @(*) begin 
        if (frame_ctr == 8'd0) begin 
            sigma = 8'd128;
        end else begin
            if (rank[0] != 1'b0)       sigma = 8'd128;
            else if (rank[1] != 1'b0)  sigma = 8'd64;
            else if (rank[2] != 1'b0)  sigma = 8'd32;
            else if (rank[3] != 1'b0)  sigma = 8'd16;
            else if (rank[4] != 1'b0)  sigma = 8'd8;
            else if (rank[5] != 1'b0)  sigma = 8'd4;
            else if (rank[6] != 1'b0)  sigma = 8'd2;
            else                       sigma = 8'd1;
        end
    end
    
    wire [15:0] data_from_bram; // Tín hiệu lấy từ BRAM ra
    reg  [15:0] addr_r1, addr_r2;

// --- Thêm vào phần logic always ---
    always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                addr_r1 <= 0;
                addr_r2 <= 0;
            end else if (en ) begin
                addr_r1 <= pixel_ctr;      // Trễ 1 nhịp
                addr_r2 <= addr_r1;        // Trễ 2 nhịp (Khớp với PE)
            end
        end

    // Dây nối tín hiệu valid từ PE ra tầng tiếp theo
    wire pe_valid; 
    wire pixel_status_pe;
    wire p_row0, p_row1, p_row2, p_row3;
    wire o_valid_bram;
    
    reg [7:0] pixel_in_d1, m_in_d1, v_in_d1;
    reg valid_d1;
    reg [7:0] frame_ctr_d1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_in_d1 <= 8'd0;
            m_in_d1     <= 8'd0;
            v_in_d1     <= 8'd0;
            valid_d1    <= 1'b0;
            frame_ctr_d1<= 8'd0;
        end else if (en) begin
            pixel_in_d1 <= pixel_in;           // Trễ pixel 1 nhịp
            m_in_d1     <= m_in;               // Trễ m_in ngoài 1 nhịp
            v_in_d1     <= v_in;               // Trễ v_in ngoài 1 nhịp
            valid_d1    <= i_pixel_data_valid; // Trễ valid 1 nhịp
            frame_ctr_d1<= frame_ctr;          // Đồng bộ với pixel_in_d1
        end
    end

    // --- BỘ CHỌN (MUX) DỮ LIỆU ĐƯA VÀO PE ---
    // Do data_in của BRAM được nối là {v_next, m_next} nên:
    // [15:8] là V, [7:0] là M
    wire [7:0] pe_m_in = (frame_ctr_d1 == 8'd0) ? m_in_d1 : data_from_bram[7:0];
    wire [7:0] pe_v_in = (frame_ctr_d1 == 8'd0) ? v_in_d1 : data_from_bram[15:8];
    
    reg [15:0] addr_r1, addr_r2, addr_r3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            addr_r1 <= 0;
            addr_r2 <= 0;
            addr_r3 <= 0;
        end else if (en) begin
            addr_r1 <= pixel_ctr;      // Trễ 1 nhịp (Lúc BRAM đang đọc data)
            addr_r2 <= addr_r1;        // Trễ 2 nhịp (PE đang tính nhịp 1)
            addr_r3 <= addr_r2;        // Trễ 3 nhịp (PE xuất kết quả -> Ghi BRAM)
        end
    end



zipfian_pe u_pe(
        .clk(clk), .rst_n(rst_n), .en(en),
        .i_valid(valid_d1),               // SỬA: Dùng valid đã trễ 1 nhịp
        .frame_idx(frame_ctr_d1),         // SỬA: Dùng frame_ctr đã trễ 1 nhịp
        .sigma(sigma),
        .update_v_en(update_v_en),
        .n_shift(3'b1),
        .v_min(8'd4),
        .y_in(pixel_in_d1),               // SỬA: Pixel đi vào chậm 1 nhịp
        .m_in(pe_m_in),                   // SỬA: Lấy từ BRAM (hoặc ngoài nếu frame 0)
        .v_in(pe_v_in),                   // SỬA: Lấy từ BRAM (hoặc ngoài nếu frame 0)
        .pixel_status_in(1'b1),
        .m_out(m_next),
        .v_out(v_next),
        .pixel_status_out(pixel_status_pe),
        .o_valid(pe_valid), 
        .o_valid_bram(o_valid_bram)
    );

    bram_320x180 u_bram (
        .clk(clk),
        .we(pe_valid),              
        .write_addr(addr_r3),             // SỬA: Ghi vào bằng addr_r3 (trễ 3 nhịp)
        .data_in({v_next, m_next}), 
        .read_en(i_pixel_data_valid && (frame_ctr > 0)), // Đọc bằng tín hiệu gốc chưa trễ
        .read_addr(pixel_ctr),            // Đọc bằng địa chỉ hiện tại chưa trễ
        .data_out(data_from_bram)
    );
    wire lb_valid;
    line_buffer_4x4 line_buffer(
        .clk(clk),
        .rst_n(rst_n),
        .i_valid(pe_valid),
        .en(en_d1),
        .pixel_status_in(pixel_status_pe),
        .p_row0(p_row0), .p_row1(p_row1), .p_row2(p_row2), .p_row3(p_row3),
        .o_valid(lb_valid)
    );

    wire acc_block_status;
    wire acc_block_valid;     
    block_accumulator accumulator_1(
        .clk(clk),
        .rst_n(rst_n),
        .i_valid(lb_valid),
        .en(en_d2),
        .p_row0(p_row0), .p_row1(p_row1), .p_row2(p_row2), .p_row3(p_row3),
        .min_num_motion(5'd5),
        .block_status(acc_block_status),
        .block_valid(acc_block_valid)
    );

    localparam BLOCKS_PER_FRAME = (WIDTH / 4) * (HEIGHT / 4); 
    reg skip_frame0_done;
    reg [11:0] frame0_block_cnt; 
    always @(posedge clk) begin
        if (!rst_n) begin
            frame0_block_cnt <= 12'd0;
            skip_frame0_done <= 1'b0;
        end else if (en_d2 && acc_block_valid && !skip_frame0_done) begin
            if (frame0_block_cnt == BLOCKS_PER_FRAME - 1) begin
                skip_frame0_done <= 1'b1; 
            end else begin
                frame0_block_cnt <= frame0_block_cnt + 12'd1;
            end
        end
    end

    assign block_valid  = acc_block_valid & skip_frame0_done;
    assign block_status = acc_block_status; 
    wire [8:0] w_window_data;
    wire       w_window_valid;    

block_control u_block_control (
        .i_clk          (clk),
        .i_rst_n        (rst_n),
        .i_en           (en_d2),          
        .i_block_status (block_status), 
        .i_block_valid  (block_valid),  
        .o_window_3x3   (w_window_data),   
        .o_window_valid (w_window_valid)  
    );


filter #(
        .MIN_NEIGHBOR(4) 
    ) u_window_filter (
        .i_clk(clk),
        .i_rst_n(rst_n),
        .i_en(en_d2),               // CHỖ SỬA: Cắm en_d2 vào đây để đồng bộ pha
        .i_window_3x3(w_window_data),
        .i_window_valid(w_window_valid),
        .o_filter_data(o_filtered_pixel),  
        .o_filter_valid(o_filtered_valid)  
    );
    reg [15:0] processed_count;
    
    always @(posedge clk) begin 
        if (~rst_n) begin 
            processed_count<=0;
            frame_done_cnt<=0;
        end else if (o_filtered_valid) begin
                if (processed_count==16'd3599) begin 
                    processed_count<=16'b0;
                    frame_done_cnt<=frame_done_cnt+1'b1;
                end  else begin 
                    processed_count<=processed_count+1'b1;
                    end

        end
    end
endmodule

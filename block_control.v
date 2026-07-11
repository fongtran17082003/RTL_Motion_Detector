

module block_control(
    input  wire        i_clk,
    input  wire        i_rst_n,
    input  wire        i_en,              // Đã tích hợp chân Enable hệ thống
    input  wire        i_block_status,    // Trạng thái từ accumulator
    input  wire        i_block_valid,     // Valid từ accumulator
    
    output reg [8:0]   o_window_3x3,      // Cửa sổ 3x3 xuất ra bộ lọc Filter
    output reg         o_window_valid     // Báo hiệu dữ liệu cửa sổ hợp lệ
);

    // --- Kênh Ghi (Write Channel) ---
    reg [7:0]   block_valid_cnt;           // Đếm số khối trong 1 hàng (0 đến 79)
    reg [1:0]   current_wr_line;           // Con trỏ chọn dòng để Ghi vào (0->1->2->3)
    wire [79:0] bb0_all, bb1_all, bb2_all, bb3_all; 
    reg  [3:0]  bb_wr_valid;                                         

    always @(posedge i_clk) begin
        if (!i_rst_n) begin
            block_valid_cnt   <= 8'd0;
            current_wr_line   <= 2'd0;
        end else if (i_en) begin // <-- Chỉ chạy khi có i_en
            if (i_block_valid) begin
                if (block_valid_cnt == 8'd79) begin 
                    block_valid_cnt <= 8'd0;
                    current_wr_line <= current_wr_line + 2'd1; 
                end else begin
                    block_valid_cnt <= block_valid_cnt + 8'd1;
                end
            end
        end
    end

    always @(*) begin
        bb_wr_valid = 4'b0000;
        bb_wr_valid[current_wr_line] = i_block_valid;
    end
    
    // Nối thêm chân .en(i_en) vào các bộ đệm con
    block_buffer bB0 (.clk(i_clk), .rst_n(i_rst_n), .en(i_en), .i_data(i_block_status), .i_data_valid(bb_wr_valid[0]), .o_data(bb0_all));
    block_buffer bB1 (.clk(i_clk), .rst_n(i_rst_n), .en(i_en), .i_data(i_block_status), .i_data_valid(bb_wr_valid[1]), .o_data(bb1_all));
    block_buffer bB2 (.clk(i_clk), .rst_n(i_rst_n), .en(i_en), .i_data(i_block_status), .i_data_valid(bb_wr_valid[2]), .o_data(bb2_all));
    block_buffer bB3 (.clk(i_clk), .rst_n(i_rst_n), .en(i_en), .i_data(i_block_status), .i_data_valid(bb_wr_valid[3]), .o_data(bb3_all));

    // --- Kênh Đọc tích hợp Padding Biên (Read Channel with Padding) ---
    reg        rd_state;
    reg [6:0]  rd_col_cnt;                // Bộ đếm cột dịch ngang (0 đến 79)
    reg [5:0]  rd_row_idx;                // Chỉ số hàng trong khung hình hiện tại (0 đến 44)
    reg [1:0]  rd_line_ptr;               // Con trỏ quản lý bộ đệm xoay vòng (chỉ vào hàng tâm)
    reg [2:0]  ready_rows;                // Quản lý số lượng hàng chưa đọc đang lưu trong bộ đệm (0 đến 4)

    localparam IDLE    = 1'b0,
               RD_LINE = 1'b1;

    wire write_row_done = (i_block_valid && (block_valid_cnt == 8'd79));
    wire read_row_done  = (rd_state == RD_LINE && (rd_col_cnt == 7'd79));
    
    always @(posedge i_clk ) begin
        if (!i_rst_n) begin
            ready_rows <= 3'd0;
        end else if (i_en) begin // <-- Chỉ chạy khi có i_en
            case ({write_row_done, read_row_done})
                2'b10: ready_rows <= ready_rows + 3'd1;
                2'b01: ready_rows <= ready_rows - 3'd1;
                default: ready_rows <= ready_rows; 
            endcase 
        end
    end

    reg [2:0] next_ready_rows;
    reg [5:0] next_rd_row_idx;
    reg       next_row_valid;

    always @(*) begin
        case ({write_row_done, read_row_done})
            2'b10:   next_ready_rows = ready_rows + 3'd1; 
            2'b01:   next_ready_rows = ready_rows - 3'd1; 
            default: next_ready_rows = ready_rows;        
        endcase
    
        if (read_row_done) begin
            if (rd_row_idx == 6'd44) begin
                next_rd_row_idx = 6'd0;              
            end else begin
                next_rd_row_idx = rd_row_idx + 6'd1; 
            end
        end else begin
            next_rd_row_idx = rd_row_idx;            
        end

        if (next_rd_row_idx == 6'd44) begin
            next_row_valid = (next_ready_rows >= 3'd1); 
        end else begin
            next_row_valid = (next_ready_rows >= 3'd2); 
        end
    end

    always @(posedge i_clk ) begin
        if (!i_rst_n) begin
            rd_state     <= IDLE;
            rd_col_cnt   <= 7'd0;
            rd_row_idx   <= 6'd0;
            rd_line_ptr  <= 2'd0;
        end else if (i_en) begin // <-- Chỉ chạy khi có i_en
            case (rd_state)
                IDLE: begin
                    if (next_row_valid) begin
                        rd_state   <= RD_LINE;
                        rd_col_cnt <= 7'd0;
                    end
                end

                RD_LINE: begin
                    if (rd_col_cnt == 7'd79) begin
                        rd_line_ptr <= rd_line_ptr + 2'd1;
                        rd_row_idx  <= next_rd_row_idx;
                        
                        if (next_row_valid) begin
                            rd_col_cnt <= 7'd0; 
                        end else begin
                            rd_state   <= IDLE;   
                        end
                    end else begin
                        rd_col_cnt <= rd_col_cnt + 7'd1;
                    end
                end
            endcase
        end
    end

    reg [79:0] selected_top, selected_mid, selected_bot;
    reg [79:0] row_top, row_mid, row_bot;

    always @(*) begin
        case (rd_line_ptr)
            2'd0: begin
                selected_top = bb3_all; 
                selected_mid = bb0_all; 
                selected_bot = bb1_all; 
            end
            2'd1: begin
                selected_top = bb0_all; 
                selected_mid = bb1_all; 
                selected_bot = bb2_all; 
            end
            2'd2: begin
                selected_top = bb1_all; 
                selected_mid = bb2_all; 
                selected_bot = bb3_all; 
            end
            2'd3: begin
                selected_top = bb2_all; 
                selected_mid = bb3_all; 
                selected_bot = bb0_all; 
            end
        endcase
    end

    always @(*) begin
        row_top = (rd_row_idx == 6'd0)  ? 80'h0 : selected_top; 
        row_mid = selected_mid;
        row_bot = (rd_row_idx == 6'd44) ? 80'h0 : selected_bot; 
    end

    wire [2:0] top_3x, mid_3x, bot_3x; 
    wire [6:0] idx_minus_1 = (rd_col_cnt == 7'd0)  ? 7'd0  : (rd_col_cnt - 7'd1);
    wire [6:0] idx_plus_1  = (rd_col_cnt == 7'd79) ? 7'd79 : (rd_col_cnt + 7'd1);

    assign top_3x[2] = (rd_col_cnt == 7'd0)  ? 1'b0 : row_top[idx_minus_1]; 
    assign top_3x[1] = row_top[rd_col_cnt];                                    
    assign top_3x[0] = (rd_col_cnt == 7'd79) ? 1'b0 : row_top[idx_plus_1]; 
    
    assign mid_3x[2] = (rd_col_cnt == 7'd0)  ? 1'b0 : row_mid[idx_minus_1];
    assign mid_3x[1] = row_mid[rd_col_cnt];
    assign mid_3x[0] = (rd_col_cnt == 7'd79) ? 1'b0 : row_mid[idx_plus_1];
    
    assign bot_3x[2] = (rd_col_cnt == 7'd0)  ? 1'b0 : row_bot[idx_minus_1];
    assign bot_3x[1] = row_bot[rd_col_cnt];
    assign bot_3x[0] = (rd_col_cnt == 7'd79) ? 1'b0 : row_bot[idx_plus_1];

    always @(posedge i_clk) begin
        if (!i_rst_n) begin
            o_window_3x3   <= 9'd0;
            o_window_valid <= 1'b0;
        end else if (i_en) begin // <-- Chỉ cập nhật ngõ ra khi hệ thống chạy
            o_window_3x3   <= {bot_3x, mid_3x, top_3x};
            o_window_valid <= (rd_state == RD_LINE);
        end else begin
            // Khi hệ thống dừng (i_en = 0), bắt buộc phải hạ Valid 
            // để chặn mạch filter phía sau không xử lý nhầm dữ liệu cũ.
            o_window_valid <= 1'b0;
        end
    end
endmodule

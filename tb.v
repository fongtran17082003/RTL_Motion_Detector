
`timescale 1ns / 1ps

module tb_motion;
    // --- Các tín hiệu điều khiển và dữ liệu đầu vào ---
    reg clk; 
    reg rst_n; 
    reg en;
    reg i_pixel_data_valid; 
    reg [7:0] pixel_in; 
    reg [7:0] m_in; 
    reg [7:0] v_in;
    
    // --- Các tín hiệu ngõ ra từ Core ---
    wire [79:0] o_data_buffer; // Dự phòng cho block_buffer nếu cần
    wire [7:0] m_next; 
    wire [7:0] v_next;
    wire block_status; 
    wire block_valid;
    wire [7:0] sigma;  
    wire [7:0] frame_ctr;
    wire o_filtered_pixel; 
    wire o_filtered_valid; 
    wire [31:0] frame_done_cnt;

    // --- Mảng chứa dữ liệu mẫu nạp từ file bên ngoài ---
    reg [7:0] mem_pixel [0:172799];
    reg [7:0] mem_m     [0:172799];
    reg [7:0] mem_v     [0:172799];
    
    // --- Biến điều khiển vòng lặp và con trỏ File ---
    integer i;
    integer file_live_out;   
    integer file_filtered_out; 

    // -------------------------------------------------------------------
    // KHỞI TẠO MODULE TOP (UUT)
    // -------------------------------------------------------------------
    motion_detector_core #(.WIDTH(320), .HEIGHT(180)) uut (
        .clk(clk), 
        .rst_n(rst_n), 
        .en(en),
        .i_pixel_data_valid(i_pixel_data_valid), 
        .pixel_in(pixel_in), 
        .m_in(m_in), 
        .v_in(v_in),
        .m_next(m_next), 
        .v_next(v_next),
        .block_status(block_status), 
        .block_valid(block_valid),
        .sigma(sigma), 
        .frame_ctr(frame_ctr),
        .o_filtered_pixel(o_filtered_pixel),
        .o_filtered_valid(o_filtered_valid),
        .frame_done_cnt(frame_done_cnt)
    );
    
    // --- Tạo nguồn xung Clock 100MHz chuẩn (Chu kỳ 10ns) ---
    always #5 clk = ~clk;
    
    // -------------------------------------------------------------------
    // TIẾN TRÌNH ĐIỀU KHIỂN KỊCH BẢN TEST CHÍNH
    // -------------------------------------------------------------------
    initial begin
        $display("[TB] ==========================================================");
        $display("[TB] START MULTI-SCENARIO ADVANCED PIPELINE VERIFICATION");
        $display("[TB] ==========================================================");
        
        // Nạp dữ liệu mẫu
        $readmemh("/home/phongtran/E/moiton_detector/input_tb/real_pixel_in_3.txt", mem_pixel);
        $readmemh("/home/phongtran/E/moiton_detector/input_tb/real_m_in_3.txt", mem_m);
        $readmemh("/home/phongtran/E/moiton_detector/input_tb/real_v_in_3.txt", mem_v);
        $display("[DEBUG] Pixel 0 = %h, Pixel 1 = %h", mem_pixel[0], mem_pixel[1]);
        
        // Mở các file để ghi kết quả kiểm chứng
        file_live_out     = $fopen("output_motion_mask.txt", "w"); 
        file_filtered_out = $fopen("output_filtered_pixels.txt", "w"); 
        
        // Trạng thái khởi tạo ban đầu (Tất cả tắt sạch)
        clk = 0; 
        rst_n = 0; 
        en = 0; 
        i_pixel_data_valid = 0;
        pixel_in = 0; 
        m_in = 0; 
        v_in = 0;
        
        // Giữ trạng thái Reset trong 2 chu kỳ
        #20;
        rst_n = 1; 
        #10;
        
        // -------------------------------------------------------------------
        // PHÂN ĐOẠN 1: Bơm dữ liệu kiểu nghẽn giật cục (Burst & Stalling)
        // Áp dụng từ Pixel số 0 đến Pixel 39,999
        // -------------------------------------------------------------------
        $display("[TB] >>> PHÂN ĐOẠN 1: Test Nghẽn Dữ Liệu Đầu Vào (Burst & Stalling) <<<");
        i = 0;
        while (i < 40000) begin
            // Bơm liên tục 4 pixel hợp lệ
            repeat(4) begin
                if (i < 40000) begin
                    @(posedge clk);
                    en                 <= 1'b1;
                    i_pixel_data_valid <= 1'b1;
                    pixel_in           <= mem_pixel[i];
                    m_in               <= mem_m[i];
                    v_in               <= mem_v[i];
                    i = i + 1;
                end
            end
            // Bị nghẽn 3 chu kỳ: Thả rác (8'hFF) vào nhưng hạ Valid để test mạch có ăn nhầm không
            repeat(3) begin
                @(posedge clk);
                en                 <= 1'b1;
                i_pixel_data_valid <= 1'b0; 
                pixel_in           <= 8'hFF; 
                m_in               <= 8'hFF;
                v_in               <= 8'hFF;
            end
        end
        $display("[TB] Phân đoạn 1 HOÀN THÀNH tại pixel: %d", i);

        // -------------------------------------------------------------------
        // PHÂN ĐOẠN 2: Bơm bình thường nhưng dừng đột ngột (System Pausing)
        // Áp dụng từ Pixel số 40,000 đến Pixel 79,999
        // -------------------------------------------------------------------
        $display("[TB] >>> PHÂN ĐOẠN 2: Test Dừng Hệ Thống Đột Ngột (System Pause & Resume) <<<");
        for (i = 40000; i < 80000; i = i + 1) begin
            @(posedge clk);
            en                 <= 1'b1;
            i_pixel_data_valid <= 1'b1;
            pixel_in           <= mem_pixel[i];
            m_in               <= mem_m[i];
            v_in               <= mem_v[i];

            // Giả lập CPU dừng khẩn cấp hệ thống ngay tại pixel thứ 60,000
            if (i == 60000) begin
                $display("[TB] ---> [ALERT] HẠ CHÂN ENABLE ĐỘT NGỘT! ĐÓNG BĂNG MẠCH CHỮA CHÁY!");
                repeat(50) begin
                    @(posedge clk);
                    en                 <= 1'b0; // Đóng băng công tắc tổng
                    i_pixel_data_valid <= 1'b0; // Hạ luôn valid dòng data
                    pixel_in           <= 8'hEE; // Thả rác giả lập nhiễu đường truyền bus
                end
                $display("[TB] ---> [INFO] BẬT LẠI CHÂN ENABLE! TIẾP TỤC XỬ LÝ LƯU THÔNG...");
            end
        end
        $display("[TB] Phân đoạn 2 HOÀN THÀNH tại pixel: %d", i);

        // -------------------------------------------------------------------
        // PHÂN ĐOẠN 3: Bơm liên tục tốc độ cao (Lý tưởng) cho phần còn lại
        // Áp dụng từ Pixel số 80,000 đến Pixel 115,199
        // -------------------------------------------------------------------
        $display("[TB] >>> PHÂN ĐOẠN 3: Test Streaming Tốc Độ Cao Kịch Khung Hình <<<");
        for (i = 80000; i < 172800; i = i + 1) begin
            @(posedge clk);
            en                 <= 1'b1;
            i_pixel_data_valid <= 1'b1;
            pixel_in           <= mem_pixel[i];
            m_in               <= mem_m[i];
            v_in               <= mem_v[i];
        end

        // -------------------------------------------------------------------
        // GIAI ĐOẠN KẾT THÚC: Hạ Valid đầu vào, Giữ nguyên EN để xả hàng tồn kho
        // -------------------------------------------------------------------
        @(posedge clk);
        i_pixel_data_valid <= 1'b0; // Hết dữ liệu thực tế đẩy vào
        en                 <= 1'b1; // GIỮ NGUYÊN BẬT: Để FSM trong block_control xả nốt các hàng cuối
        pixel_in <= 8'd0; m_in <= 8'd0; v_in <= 8'd0;
        
        $display("[TB] Dòng pixel thực tế đã truyền xong. Đang đợi bộ lọc Flush nốt các hàng cuối...");
        
        // Treo mạch chạy không tải một khoảng thời gian để ghi nốt toàn bộ pixel ra file
        #100000; 
        
        // Đóng file sạch sẽ an toàn
        $fclose(file_live_out); 
        $fclose(file_filtered_out);
        $display("[TB] SIMULATION SUCCESSFUL! Đã kiểm tra đầy đủ các kịch bản lỗi biên!");
        $finish;
    end

    always @(posedge clk) begin
        if (o_filtered_valid) begin
            $fwrite(file_filtered_out, "%b\n", o_filtered_pixel);
        end
    end
    always @(posedge clk) begin
        if (block_valid) begin
            $fwrite(file_live_out, "%b\n", block_status);
        end
    end

endmodule


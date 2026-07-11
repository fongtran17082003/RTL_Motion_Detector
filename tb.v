
`timescale 1ns / 1ps

module tb;
    reg clk; reg rst_n; reg en;
    reg [7:0] pixel_in; reg [7:0] m_in; reg [7:0] v_in;
    
    wire [7:0] m_next; wire [7:0] v_next;
    wire block_status; wire block_valid;
    wire [7:0] sigma;  wire [7:0] frame_ctr;

    // Mảng chứa tổng số pixel của 2 khung hình (320 x 180 x 2 = 115200)
    reg [7:0] mem_pixel [0:115199];
    reg [7:0] mem_m     [0:115199];
    reg [7:0] mem_v     [0:115199];

    integer i;
    integer file_out;

    // Khởi tạo Module TOP với cấu hình ảnh thật
    motion_detector_core #(.WIDTH(320), .HEIGHT(180)) uut (
        .clk(clk), .rst_n(rst_n), .en(en),
        .pixel_in(pixel_in), .m_in(m_in), .v_in(v_in),
        .m_next(m_next), .v_next(v_next),
        .block_status(block_status), .block_valid(block_valid),
        .sigma(sigma), .frame_ctr(frame_ctr)
    );
    
    always #5 clk = ~clk;
    
    initial begin
     $display("TB START");
        $readmemh("/home/phongtran/E/moiton_detector/input_tb/read_pixel_in.txt", mem_pixel);
        $readmemh("/home/phongtran/E/moiton_detector/input_tb/read_m_in.txt", mem_m);
        $readmemh("/home/phongtran/E/moiton_detector/input_tb/read_v_in.txt", mem_v);
        file_out = $fopen("output_motion_mask.txt", "w"); 
        
        clk = 0; rst_n = 0; en = 0;
        pixel_in = 0; m_in = 0; v_in = 0;
        #20;
        rst_n = 1;
        #10;
        en = 1;
        
        // Cấp toàn bộ 2 khung hình
        for (i = 0; i < 115200; i = i + 1) begin
            pixel_in = mem_pixel[i];
            m_in     = mem_m[i];
            v_in     = mem_v[i];
            #10; // Chờ 1 nhịp clock
        end
        
        // 🌟 SỬA TẠI ĐÂY: Giữ 'en = 1' thêm 4-5 nhịp để toàn bộ dữ liệu cuối cùng trong đường ống (Pipeline) 
        // kịp chảy ra tới block_accumulator. Nếu hạ en xuống ngay, pixel cuối sẽ bị kẹt lại.
        pixel_in = 8'd0;
        m_in     = 8'd0;
        v_in     = 8'd0;
        #50; // Chờ thêm 5 nhịp clock (5 * 10ns) để đẩy sạch dữ liệu ra ngoài
        
        en = 0;
        #20;
        $fclose(file_out);
        #100;
        $display("Mô phỏng ảnh thật hoàn tất!");
        $finish;
    end
        
    // 🌟 SỬA KHỐI GHI FILE:
 integer valid_block_count = 0; // Thêm biến đếm số block

    always @(posedge clk) begin
        if (block_valid) begin
            valid_block_count = valid_block_count + 1;
            
            // Frame 0: từ block 1 đến 3600
            // Frame 1: từ block 3601 đến 7200
            // Chỉ ghi kết quả của Frame 1 (hoặc tùy bạn chỉnh giới hạn)
            if (valid_block_count > 3600 && valid_block_count <= 7200) begin
                $fwrite(file_out, "%b\n", block_status);
            end
        end
    end

endmodule

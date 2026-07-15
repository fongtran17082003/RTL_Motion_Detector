//`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////////
//// Company: 
//// Engineer: 
//// 
//// Create Date: 06/15/2026 11:09:18 AM
//// Design Name: 
//// Module Name: zipfian_pe
//// Project Name: 
//// Target Devices: 
//// Tool Versions: 
//// Description: 
//// 
//// Dependencies: 
//// 
//// Revision:
//// Revision 0.01 - File Created
//// Additional Comments:
//// 
////////////////////////////////////////////////////////////////////////////////////



`timescale 1ns / 1aps

module zipfian_pe(
    input wire clk, rst_n, en,
    input wire i_valid,
    input wire [7:0] frame_idx,      // Thay thế clear_frame bằng số thứ tự Frame
    
    input wire [7:0] sigma,
    input wire update_v_en,
    input wire [2:0] n_shift,
    input wire [7:0] v_min,
    
    input wire [7:0] y_in, 
    input wire [7:0] m_in, 
    input wire [7:0] v_in,
    input wire pixel_status_in,
    
    output reg [7:0] m_out,
    output reg [7:0] v_out,
    output reg pixel_status_out,
    output reg o_valid,
    output wire o_valid_bram
    
);
    
    wire temp;
    wire [7:0] m_next;
    wire [7:0] o_val;
    reg [7:0] y_in_r1, y_in_r2;


always @(posedge clk) begin
    if (~rst_n) begin 
        y_in_r1 <= 0;
        y_in_r2 <= 0;
    end else if (en ) begin // Chỉ dịch khi có dữ liệu valid
        y_in_r1 <= y_in;
        y_in_r2 <= y_in_r1;
    end
end
    
    assign temp = (v_in > sigma);     
    assign m_next = (!temp) ? m_in : (m_in > y_in) ? (m_in - 8'd1) : (m_in < y_in) ? (m_in + 8'd1) : m_in; 
    assign o_val = (m_next > y_in) ? (m_next - y_in) : (y_in - m_next);
    
    reg [7:0] o_val_r1;
    reg [7:0] v_in_r1;
    reg p_in_r1;
    reg update_v_en_r1;
    reg [7:0] m_next_r1;
    reg       vld_r1;                 // Thanh ghi dịch trễ tầng 1 cho tín hiệu valid
    
    // Khối pipeline nhịp 1: Loại bỏ clear_frame
    always @(posedge clk or negedge     rst_n) begin 
        if (!rst_n) begin 
            o_val_r1       <= 0;
            v_in_r1        <= 0;
            p_in_r1        <= 0;
            update_v_en_r1 <= 0;
            m_next_r1      <= 0;
            vld_r1         <= 1'b0;   // Reset valid tầng 1
        end else if (en) begin 
        vld_r1 <= i_valid;
        if (i_valid) begin
            o_val_r1       <= o_val;
            v_in_r1        <= v_in;         
            p_in_r1        <= pixel_status_in;         
            update_v_en_r1 <= update_v_en;  
            m_next_r1      <= m_next;
        end 
        end
    end
    
    wire [15:0] no_full;
    wire [7:0]  no_val;
    wire [7:0]  v_temp;
    wire [7:0]  v_next;
    wire        p_next;

    assign no_full = o_val_r1 << n_shift;
    assign no_val  = (no_full > 16'd255) ? 8'd255 : no_full[7:0];
    assign v_temp  = (v_in_r1 > no_val) ? (v_in_r1 - 8'd1) : (v_in_r1 < no_val) ? (v_in_r1 + 8'd1) : v_in_r1;
    assign v_next  = (!update_v_en_r1) ? v_in_r1 : (v_temp < v_min) ? v_min : v_temp;
    assign p_next  = (!update_v_en_r1) ? p_in_r1 : (o_val_r1 > v_next);
    assign o_valid_bram=vld_r1;
    
    // Khối pipeline nhịp 2: Cập nhật đầu ra thông minh theo frame_idx
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_out            <= 8'd0;
            v_out            <= 8'd0;
            pixel_status_out <= 1'b0;
        end else if (en) begin
        o_valid <= vld_r1;
        if (vld_r1) begin
            if (frame_idx == 8'd0) begin
                // Học nền chủ động tại Frame đầu tiên, không xóa cứng bằng clear_frame
                m_out            <= y_in_r1;
                v_out            <= 8'd4; 
                pixel_status_out <= 1'b0;
            end else begin
                m_out            <= m_next_r1;
                v_out            <= v_next;
                pixel_status_out <= p_next;
            end
        end
        end
    end
endmodule

//`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////////
//// Company: 
//// Engineer: 
//// 
//// Create Date: 06/15/2026 07:30:59 PM
//// Design Name: 
//// Module Name: motion_detector_core
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



`timescale 1ns / 1ps

module motion_detector_core #(
    parameter WIDTH = 320,
    parameter HEIGHT = 180
)(
    input wire clk,
    input wire rst_n,
    input wire en,
    input wire [7:0] pixel_in,
    input wire [7:0] m_in,
    input wire [7:0] v_in,
    
    output wire [7:0] m_next,
    output wire [7:0] v_next,
    output wire block_status,
    output wire block_valid,
    output reg [7:0] sigma,
    output reg [7:0] frame_ctr
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
        end else if (en) begin 
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
    
    wire pixel_status_pe;
    wire p_row0, p_row1, p_row2, p_row3;
    
    zipfian_pe u_pe(
        .clk(clk), .rst_n(rst_n), .en(en),
        .frame_idx(frame_ctr), 
        .sigma(sigma),
        .update_v_en(update_v_en),
        .n_shift(3'b1),
        .v_min(8'd4),
        .y_in(pixel_in), .m_in(m_in), .v_in(v_in),
        .pixel_status_in(1'b1),
        .m_out(m_next),
        .v_out(v_next),
        .pixel_status_out(pixel_status_pe)
    );
    
    line_buffer_4x4 line_buffer(
        .clk(clk),
        .rst_n(rst_n),
        .en(en_d1),
        .pixel_status_in(pixel_status_pe),
        .p_row0(p_row0), .p_row1(p_row1), .p_row2(p_row2), .p_row3(p_row3)
    );

    block_accumulator accumulator_1(
        .clk(clk),
        .rst_n(rst_n),
        .en(en_d2),
        .p_row0(p_row0), .p_row1(p_row1), .p_row2(p_row2), .p_row3(p_row3),
        .min_num_motion(5'd5),
        .block_status(block_status),
        .block_valid(block_valid)
    );
endmodule
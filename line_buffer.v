//`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////////
//// Company: 
//// Engineer: 
//// 
//// Create Date: 06/15/2026 05:19:59 PM
//// Design Name: 
//// Module Name: line_buffer
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

module line_buffer_4x4 #(
    parameter WIDTH = 320 
)(
    input wire         clk,
    input wire         rst_n,
    input wire         en,  
    // input wire      clear_buffer, <-- LOẠI BỎ
    input wire         pixel_status_in, 

    output wire        p_row0,
    output wire        p_row1,
    output wire        p_row2,
    output wire        p_row3
);

    reg [WIDTH-1:0] buffer_row1;
    reg [WIDTH-1:0] buffer_row2;
    reg [WIDTH-1:0] buffer_row3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            buffer_row1 <= {WIDTH{1'b0}};
            buffer_row2 <= {WIDTH{1'b0}};
            buffer_row3 <= {WIDTH{1'b0}};
        end else if (en) begin
            buffer_row1 <= {buffer_row1[WIDTH-2:0], pixel_status_in};
            buffer_row2 <= {buffer_row2[WIDTH-2:0], buffer_row1[WIDTH-1]};
            buffer_row3 <= {buffer_row3[WIDTH-2:0], buffer_row2[WIDTH-1]};
        end
    end

    assign p_row0 = pixel_status_in;      
    assign p_row1 = buffer_row1[WIDTH-1]; 
    assign p_row2 = buffer_row2[WIDTH-1];  
    assign p_row3 = buffer_row3[WIDTH-1]; 

endmodule
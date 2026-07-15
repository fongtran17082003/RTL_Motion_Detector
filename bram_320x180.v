`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/11/2026 08:43:15 PM
// Design Name: 
// Module Name: bram_320x180
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module bram_320x180#(
    parameter DATA_WIDTH = 16,
    parameter DEPTH      = 57600, 
    parameter ADDR_WIDTH = 16    
)(
    input  wire                  clk,

    input  wire                  we,          // Đã được điều khiển trễ 2 nhịp
    input  wire [ADDR_WIDTH-1:0] write_addr,  // Đã được điều khiển trễ 2 nhịp
    input  wire [DATA_WIDTH-1:0] data_in,
    input  wire                  read_en,     // Tín hiệu điều khiển đọc (ví dụ: i_valid)
    input  wire [ADDR_WIDTH-1:0] read_addr,
    output reg  [DATA_WIDTH-1:0] data_out
);
    reg [DATA_WIDTH-1:0] ram [0:DEPTH-1];
    integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i + 1) begin
            ram[i] = 16'h0000; // V=10, M=0
        end
    end
    always @(posedge clk) begin
        if (we) begin
            ram[write_addr] <= data_in;
        end
    end

    // Quá trình ĐỌC (Có điều kiện read_en)
    always @(posedge clk) begin
        if (read_en) begin
            data_out <= ram[read_addr];
        end else begin 
            data_out<=0;
    end
    end

endmodule
 

/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */
`default_nettype none

module tt_um_edge_detect (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

    wire pixel_valid = ui_in[0];
    wire [7:0] pixel_in = uio_in;

    reg [7:0] out;
    assign uo_out = out;

    // 8x8 image counters
    reg [2:0] row;
    reg [2:0] col;

    // True line buffers
    // linebuf1 = previous row
    // linebuf2 = row before previous row
    reg [7:0] linebuf1 [0:7];
    reg [7:0] linebuf2 [0:7];

    // Horizontal shift registers for 3 rows
    reg [7:0] r0_0, r0_1;  // current row: col-2, col-1
    reg [7:0] r1_0, r1_1;  // previous row: col-2, col-1
    reg [7:0] r2_0, r2_1;  // row-2: col-2, col-1

    wire [7:0] row1_col2 = linebuf1[col];
    wire [7:0] row2_col2 = linebuf2[col];

    // 3x3 window
    wire [7:0] p00 = r2_0;
    wire [7:0] p01 = r2_1;
    wire [7:0] p02 = row2_col2;

    wire [7:0] p10 = r1_0;
    wire [7:0] p11 = r1_1;
    wire [7:0] p12 = row1_col2;

    wire [7:0] p20 = r0_0;
    wire [7:0] p21 = r0_1;
    wire [7:0] p22 = pixel_in;

    // Sobel calculation
    wire signed [11:0] gx =
        -$signed({4'b0, p00}) + $signed({4'b0, p02})
        -($signed({4'b0, p10}) <<< 1) + ($signed({4'b0, p12}) <<< 1)
        -$signed({4'b0, p20}) + $signed({4'b0, p22});

    wire signed [11:0] gy =
         $signed({4'b0, p00}) + ($signed({4'b0, p01}) <<< 1) + $signed({4'b0, p02})
        -$signed({4'b0, p20}) - ($signed({4'b0, p21}) <<< 1) - $signed({4'b0, p22});

    wire [11:0] ax = gx[11] ? (~gx + 1'b1) : gx;
    wire [11:0] ay = gy[11] ? (~gy + 1'b1) : gy;
    wire [12:0] mag = ax + ay;

    wire valid_window = (row >= 3'd2) && (col >= 3'd2);

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            row <= 3'd0;
            col <= 3'd0;
            out <= 8'd0;

            r0_0 <= 8'd0;
            r0_1 <= 8'd0;
            r1_0 <= 8'd0;
            r1_1 <= 8'd0;
            r2_0 <= 8'd0;
            r2_1 <= 8'd0;

            for (i = 0; i < 8; i = i + 1) begin
                linebuf1[i] <= 8'd0;
                linebuf2[i] <= 8'd0;
            end
        end else if (pixel_valid) begin

            // Output current Sobel result
            if (valid_window) begin
                if (mag > 13'd255)
                    out <= 8'hFF;
                else
                    out <= mag[7:0];
            end else begin
                out <= 8'd0;
            end

            // Update line buffers
            linebuf2[col] <= row1_col2;
            linebuf1[col] <= pixel_in;

            // Update horizontal window
            if (col == 3'd7) begin
                col <= 3'd0;

                r0_0 <= 8'd0;
                r0_1 <= 8'd0;
                r1_0 <= 8'd0;
                r1_1 <= 8'd0;
                r2_0 <= 8'd0;
                r2_1 <= 8'd0;

                if (row == 3'd7)
                    row <= 3'd0;
                else
                    row <= row + 3'd1;
            end else begin
                col <= col + 3'd1;

                r0_0 <= r0_1;
                r0_1 <= pixel_in;

                r1_0 <= r1_1;
                r1_1 <= row1_col2;

                r2_0 <= r2_1;
                r2_1 <= row2_col2;
            end
        end
    end

endmodule

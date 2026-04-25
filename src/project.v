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

    // ------------------------------------------------
    // Unused / fixed IO
    // ------------------------------------------------

    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

    // avoid unused warnings
    wire _unused = &{ena, ui_in[7:1], 1'b0};

    // ------------------------------------------------
    // Input interface
    // ------------------------------------------------

    // ui_in[0] = pixel_valid
    wire pixel_valid = ui_in[0];

    // uio_in[7:0] = 8-bit grayscale pixel input
    wire [7:0] pixel_in = uio_in;

    // ------------------------------------------------
    // Output interface
    // ------------------------------------------------

    // Only output 1-bit edge flag:
    // uo_out[0] = edge detected
    // uo_out[7:1] = 0
    reg edge_flag;

    assign uo_out = {7'b0, edge_flag};

    // ------------------------------------------------
    // 8x8 image counters
    // ------------------------------------------------

    reg [2:0] row;
    reg [2:0] col;

    // ------------------------------------------------
    // True line buffers
    //
    // linebuf1 = previous row
    // linebuf2 = row before previous row
    // ------------------------------------------------

    reg [7:0] linebuf1 [0:7];
    reg [7:0] linebuf2 [0:7];

    // ------------------------------------------------
    // Horizontal shift registers
    //
    // store previous two columns
    // ------------------------------------------------

    reg [7:0] r0_0, r0_1;  // current row
    reg [7:0] r1_0, r1_1;  // previous row
    reg [7:0] r2_0, r2_1;  // row - 2

    wire [7:0] row1_col2 = linebuf1[col];
    wire [7:0] row2_col2 = linebuf2[col];

    // ------------------------------------------------
    // 3x3 window
    // ------------------------------------------------

    wire [7:0] p00 = r2_0;
    wire [7:0] p01 = r2_1;
    wire [7:0] p02 = row2_col2;

    wire [7:0] p10 = r1_0;
    wire [7:0] p11 = r1_1;
    wire [7:0] p12 = row1_col2;

    wire [7:0] p20 = r0_0;
    wire [7:0] p21 = r0_1;
    wire [7:0] p22 = pixel_in;

    // ------------------------------------------------
    // Sobel operator
    // ------------------------------------------------

    wire signed [11:0] gx =
        -$signed({4'b0, p00}) + $signed({4'b0, p02})
        -($signed({4'b0, p10}) <<< 1) + ($signed({4'b0, p12}) <<< 1)
        -$signed({4'b0, p20}) + $signed({4'b0, p22});

    wire signed [11:0] gy =
         $signed({4'b0, p00}) + ($signed({4'b0, p01}) <<< 1) + $signed({4'b0, p02})
        -$signed({4'b0, p20}) - ($signed({4'b0, p21}) <<< 1) - $signed({4'b0, p22});

    wire [11:0] abs_gx = gx[11] ? (~gx + 1'b1) : gx;
    wire [11:0] abs_gy = gy[11] ? (~gy + 1'b1) : gy;

    wire [12:0] mag = abs_gx + abs_gy;

    // first valid Sobel output appears at row >= 2 and col >= 2
    wire valid_window = (row >= 3'd2) && (col >= 3'd2);

    // threshold for binary edge output
    wire edge_detected = (mag > 13'd100);

    integer i;

    // ------------------------------------------------
    // Sequential logic
    // ------------------------------------------------

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            row <= 3'd0;
            col <= 3'd0;

            edge_flag <= 1'b0;

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

            // ----------------------------------------
            // Output edge flag
            // ----------------------------------------

            if (valid_window)
                edge_flag <= edge_detected;
            else
                edge_flag <= 1'b0;

            // ----------------------------------------
            // Update line buffers
            // ----------------------------------------

            linebuf2[col] <= row1_col2;
            linebuf1[col] <= pixel_in;

            // ----------------------------------------
            // Update horizontal window + counters
            // ----------------------------------------

            if (col == 3'd7) begin
                col <= 3'd0;

                // clear horizontal history for next row
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

                // current row shift
                r0_0 <= r0_1;
                r0_1 <= pixel_in;

                // previous row shift
                r1_0 <= r1_1;
                r1_1 <= row1_col2;

                // row-2 shift
                r2_0 <= r2_1;
                r2_1 <= row2_col2;
            end
        end
    end

endmodule

`default_nettype wire

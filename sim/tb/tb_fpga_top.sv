`timescale 1ns/1ps
module tb_fpga_top;
    // parameters match your fpga_top
    parameter integer NUM_PORTS = `NUM_PORTS;
    parameter integer W_MINI = `DATA_WIDTH;

    reg clk = 0;
    reg reset_n = 1;

    // simple micro IF wires to match fpga_top ports
    reg  [15:0] uif_addr = 0;
    reg         uif_wr_en = 0;
    reg  [31:0] uif_wr_data = 0;
    reg         uif_rd_en = 0;
    wire [31:0] uif_rd_data;

    // instantiate fpga_top
    fpga_top #(
        .NUM_PORTS(NUM_PORTS),
        .W_MINI(W_MINI)
    ) DUT (
        .clk(clk),
        .reset_n(reset_n),
        .uif_addr(uif_addr),
        .uif_wr_en(uif_wr_en),
        .uif_wr_data(uif_wr_data),
        .uif_rd_en(uif_rd_en),
        .uif_rd_data(uif_rd_data),
        .user_led()
    );

    // clock
    always #5 clk = ~clk; // 100 MHz

    initial begin
        // reset pulse
        reset_n = 0;
        #100;
        reset_n = 1;

        // simple AXI-lite-like poke to the QoS wrapper addr 0 to read ID
        #1000;
        uif_addr = 16'h0000;
        uif_rd_en = 1;
        #20;
        uif_rd_en = 0;

        // run a bit then finish
        #5000;
        $display("SIM DONE");
        $finish;
    end
endmodule

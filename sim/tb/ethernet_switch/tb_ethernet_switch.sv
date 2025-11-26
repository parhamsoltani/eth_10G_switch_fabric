`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: Parman
// Engineer: Alireza Abbasian
//
// Create Date:  2025-03-24 17:56:42
// Module Name: tb_top
// Project Name: switch 10*10g
// Target Devices: ku3p
// Tool Versions: Vivado 2022.2
// Description:
// Dependencies:
//
// Additional Comments:

//////////////////////////////////////////////////////////////////////////////////

`include "sim_options.vh"
`include "implement_options.vh"
module tb_ethernet_switch;

    parameter NUM_PORT = `NUM_PORT;
    parameter LINE_RATE           = `LINE_RATE; // 10, 25

    parameter MICRO_DATA_WIDTH = 16;
    parameter MICRO_ADDR_WIDTH = 16;



    parameter   S                       = `S;            // speed up
    parameter   W_MINI                  = `W;            // bus data width (mini cell data width)
    // parameter   W_MINI                  = LINE_RATE == 10? 64 :128;           // bus data width (mini cell data width)
    parameter   MAIN_MEM_DEPTH          = `D;           // main mem depth
    parameter   XPQ_DEPTH               = `X;
    parameter   OUTPUT_QUEUE_DEPTH      = `OUTPUT_QUEUE_DEPTH;
    parameter   MULTICAST_SUPPORT       = `MULTICAST_SUPPORT;
    parameter   MULTICAST_RATE          = `U;        // Address fifos depth = MULTICAST_RATE* MAIN_MEM_DEPTH
    parameter   PACKET_ID_WIDTH         = 8;
    parameter   QOS_TAG_WIDTH           = 1;





    parameter TX_PERIOD = LINE_RATE == 10 ? 3.2 : 1.28;
    parameter SYS_PERIOD =  1.499;  // 1.2195 : 410 MHz clock,  1.499: 345 MHz clock


    // Clock and Reset Signals
    reg sys_clk;
    reg tx_tester_clk [NUM_PORT];
    reg rx_tester_clk [NUM_PORT];
    reg sys_reset;

    // AXI Stream Interfaces
    axis_if #(.DATA_WIDTH(64), .USER_WIDTH(1)) tx_axis_tester [NUM_PORT](); // Generator to DUT (master)
    axis_if #(.DATA_WIDTH(64), .USER_WIDTH(1)) rx_axis_dut [NUM_PORT](); // Generator to DUT (master)
    axis_if #(.DATA_WIDTH(64), .USER_WIDTH(1)) rx_axis_tester [NUM_PORT](); // DUT to Monitor (slave)

    // micro interface
    micro_if #(.MICRO_ADDR_WIDTH(MICRO_ADDR_WIDTH), .MICRO_DATA_WIDTH(MICRO_DATA_WIDTH)) m_if();

    // Mailboxes
    mailbox dut_frame_out_mailbox [NUM_PORT];
    mailbox dut_frame_in_mailbox [NUM_PORT];
    mailbox expected_mailbox [NUM_PORT];

    // End of simulation event
    bit end_of_sim;



    wire [3:0] xg_ctl_tx_ipg_value [NUM_PORT];






    // Generate Clock ========================================
    initial begin
        $timeformat(-9, 2, " ns", 20);
        sys_clk = 0;
        forever #(SYS_PERIOD) sys_clk = ~sys_clk;
    end

    generate
    for (genvar i=0; i<NUM_PORT; ++i) begin : gen_clock
        initial begin
            tx_tester_clk[i] = 0;
            #1;
            forever #(TX_PERIOD) tx_tester_clk[i] = ~tx_tester_clk[i]; // 156.25 MHz clock
        end

        initial begin
            rx_tester_clk[i] = 0;
            #2;
            forever #(TX_PERIOD) rx_tester_clk[i] = ~rx_tester_clk[i]; // 156.25 MHz clock
        end

        assign rx_axis_dut[i].clk = tx_tester_clk[i];
        assign rx_axis_tester[i].clk = rx_tester_clk[i];


        assign tx_axis_tester[i].clk    = rx_axis_dut[i].clk;
        assign tx_axis_tester[i].tready = 1'b1;
        assign rx_axis_dut[i].tdata            = tx_axis_tester[i].tdata ;
        assign rx_axis_dut[i].tkeep            = tx_axis_tester[i].tkeep ;
        assign rx_axis_dut[i].tvalid           = tx_axis_tester[i].tvalid;
        assign rx_axis_dut[i].tlast            = tx_axis_tester[i].tlast ;
        assign rx_axis_dut[i].tuser            = tx_axis_tester[i].tuser ;

    end
    endgenerate

    assign m_if.clk = sys_clk;

    // ===========================================================





    // ================== for tx of dut, make tready 0 based on ifg
    // preample (7) + SFD(1) + CRC (4) + IFG (11) = 23 >= 2clk + 7 byte

    generate
    for (genvar i=0; i<NUM_PORT; ++i) begin : gen_tready

        initial begin
            forever begin
                rx_axis_tester[i].tready <= 1;
                @(posedge rx_axis_tester[i].tlast);
                @(posedge rx_axis_tester[i].clk);
                rx_axis_tester[i].tready <= 0;
                repeat (2) begin
                    @(posedge rx_axis_tester[i].clk);
                end
            end
        end
    end
    endgenerate
    // ===========================================================





    // Reset Initialization
    initial begin
        sys_reset = 0;
        repeat (100) @(posedge sys_clk);
        $display("reset switch!");
        sys_reset = 1;
        repeat (10) @(posedge sys_clk);
        sys_reset = 0;
    end












    // Instantiate Frame Generator
    generator_frame #(
        .NUM_PORT(NUM_PORT),
        .MICRO_DATA_WIDTH(MICRO_DATA_WIDTH),
        .MICRO_ADDR_WIDTH(MICRO_ADDR_WIDTH)
    ) gen_inst (
        .sys_clk   (sys_clk),
        .sys_reset (sys_reset),
        .axis      (tx_axis_tester),  // Connect AXI interface
        .end_of_sim (end_of_sim),
        .m_if(m_if)
    );




    // Instantiate Switch Wrapper (DUT)
    ethernet_switch #(
        .MICRO_ADDR_WIDTH       (MICRO_ADDR_WIDTH),
        .MICRO_DATA_WIDTH       (MICRO_DATA_WIDTH),
        .LINE_RATE              (LINE_RATE),
        .NUM_PORT              (NUM_PORT),
        .S                     (S),
        .W_MINI                (W_MINI),
        .MAIN_MEM_DEPTH        (MAIN_MEM_DEPTH),
        .XPQ_DEPTH             (XPQ_DEPTH),
        .OUTPUT_QUEUE_DEPTH    (OUTPUT_QUEUE_DEPTH),
        .MULTICAST_SUPPORT     (MULTICAST_SUPPORT),
        .MULTICAST_RATE        (MULTICAST_RATE),
        .PACKET_ID_WIDTH       (PACKET_ID_WIDTH),
        .QOS_TAG_WIDTH         (QOS_TAG_WIDTH)
    ) u_ethernet_switch (
        .sys_clk                (sys_clk),
        .reset                  (sys_reset),
        .rx_axis                (rx_axis_dut),
        .tx_axis                (rx_axis_tester),
        .xg_ctl_tx_ipg_value    (xg_ctl_tx_ipg_value),
        .m_if_in(m_if)
    );

    // Instantiate Monitors
    monitor #(
        .NUM_PORT(NUM_PORT)
    ) u_monitor_dut_tx (
        .axis          (rx_axis_tester),  // Monitor DUT TX output
        .frame_mailbox (dut_frame_out_mailbox)
    );



    monitor #(
        .NUM_PORT(NUM_PORT)
    ) u_monitor_dut_rx (
        .axis          (tx_axis_tester),  // Monitor DUT RX input
        .frame_mailbox (dut_frame_in_mailbox)
    );




    // Instantiate Switch Model
    switch_model #(
        .NUM_PORT(NUM_PORT)
    ) switch_model_inst (
        .sys_clk            (sys_clk),
        .sys_reset          (sys_reset),
        .frame_mailbox_in   (dut_frame_in_mailbox),
        .frame_mailbox_out  (expected_mailbox)
    );



    // Instantiate Scoreboard
    score_board #(
        .NUM_PORT(NUM_PORT)
    ) scoreboard_inst (
        .sys_clk         (sys_clk),
        .sys_reset       (sys_reset),
        .actual_mailbox  (dut_frame_out_mailbox),
        .expected_mailbox(expected_mailbox),
        .end_of_sim      (end_of_sim)
    );





    // Simulation End Condition
    initial begin
        @(posedge end_of_sim);
        repeat (100) @(posedge sys_clk);
        $write("========================================\n");
        $write("********* Simulation finished **********\n");
        $write("========================================\n");
        $stop;
    end




endmodule




`default_nettype wire
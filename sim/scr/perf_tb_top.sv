`timescale 1ns / 1ps
`default_nettype none

module perf_tb_top;
    // Params from des_main_4.txt
    parameter NUM_PORT = 10;
    parameter QOS_TAG_WIDTH = 3;

    // Clock/reset
    reg clk = 0;
    reg reset = 1;
    always #1.449 clk = ~clk;  // 345 MHz from timing.xdc

    // Interfaces (from des_ethernet_switch.txt)
    switch_data_if rx_data_if [NUM_PORT]();
    switch_metadata_if rx_meta_if [NUM_PORT]();
    switch_data_if tx_data_if [NUM_PORT]();

    // DUT
    switch_fabric u_dut (
        .clk(clk),
        .reset(reset),
        .rx_data_if(rx_data_if),
        .rx_meta_if(rx_meta_if),
        .tx_data_if(tx_data_if),
        // ... other ports
    );

    // Traffic generator (random from )
    initial begin
        reset = 1; #10; reset = 0;
        for (int p=0; p<NUM_PORT; p++) begin
            fork
                begin
                    // Generate packets with random QoS tags
                    reg [QOS_TAG_WIDTH-1:0] qos = $urandom % 8;
                    // ... drive rx_data_if[p] with packets (use classes from hvl/classes)
                    // Measure throughput/latency
                end
            join_none
        end
    end

    // Monitor and stats (from )
    reg [63:0] pkt_count [NUM_PORT];
    reg [63:0] latency_sum [NUM_PORT];
    always @(posedge clk) begin
        for (int p=0; p<NUM_PORT; p++) begin
            if (tx_data_if[p].valid && tx_data_if[p].ready) pkt_count[p]++;
            // ... timestamp for latency (use SVA from  for assertions)
        end
    end

    // Dump CSV for analyzer.py
    initial begin
        #1000000;  // Run 1M cycles
        $display("Perf stats:");  // Output to transcript
        for (int p=0; p<NUM_PORT; p++) $display("Port %d: Pkts %d, Avg Lat %d", p, pkt_count[p], latency_sum[p]/pkt_count[p]);
        $finish;
    end

endmodule

`default_nettype wire
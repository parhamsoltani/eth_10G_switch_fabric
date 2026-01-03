`timescale 1ns / 1ps

`include "fabric_params.vh"

module tb_fabric_qos;

    parameter NUM_PORT = 10;  // Changed to match module (no 'S')
    parameter DATA_WIDTH = 64;  // Changed to 64 to match W_MINI
    parameter PACKET_ID_WIDTH = 8;  // Changed to match module
    parameter CLK_PERIOD = 4.0;  // 250 MHz

    logic clk;
    logic rst_n;

    // Interfaces (updated parameters to match)
    switch_data_if #(.DATA_WIDTH(DATA_WIDTH), .ID_WIDTH(PACKET_ID_WIDTH))
        rx_data_if [NUM_PORT] ();

    switch_metadata_if #(.PORT_MASK_WIDTH(NUM_PORT), .ID_WIDTH(PACKET_ID_WIDTH))
        rx_meta_if [NUM_PORT] ();

    switch_data_if #(.DATA_WIDTH(DATA_WIDTH), .ID_WIDTH(PACKET_ID_WIDTH))
        tx_data_if [NUM_PORT] ();

    // Verification modules (updated parameters)
    fabric_scoreboard #(
        .NUM_PORTS(NUM_PORT),  // Use NUM_PORT for consistency
        .DATA_WIDTH(DATA_WIDTH),
        .ID_WIDTH(PACKET_ID_WIDTH)
    ) scoreboard ();

    qos_checker #(
        .NUM_PORTS(NUM_PORT),  // Use NUM_PORT for consistency
        .ID_WIDTH(PACKET_ID_WIDTH)
    ) qos_check ();

    // DUT (updated parameter overrides and ports)
    switch_fabric #(
        .NUM_PORT(NUM_PORT),
        .W_MINI(DATA_WIDTH),
        .PACKET_ID_WIDTH(PACKET_ID_WIDTH)
    ) dut (
        .clk(clk),
        .reset(~rst_n),  // Invert to match active-high reset in module
        .rx_data_if(rx_data_if),
        .rx_meta_if(rx_meta_if),
        .tx_data_if(tx_data_if)
        // Removed non-existent ports: .pkt_count_rx(), etc.
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Reset
    initial begin
        rst_n = 0;
        repeat (10) @(posedge clk);
        rst_n = 1;
        $display("[%0t] Reset released", $time);
    end

    //==========================================================================
    // Per-port packet injection using generate
    //==========================================================================
    
    // Packet request signals for each port (updated to NUM_PORT)
    logic [NUM_PORT-1:0]           pkt_req;
    logic [NUM_PORT-1:0]           pkt_done;
    logic [NUM_PORT-1:0]           pkt_dst_mask [NUM_PORT];
    logic [2:0]                     pkt_qos [NUM_PORT];
    int                             pkt_size [NUM_PORT];
    logic [PACKET_ID_WIDTH-1:0]     pkt_id [NUM_PORT];  // Updated width

    // Global packet ID counter
    int next_pkt_id = 1;

    generate
        for (genvar g = 0; g < NUM_PORT; g++) begin : gen_tx_driver
            
            initial begin
                // Initialize interface signals
                rx_data_if[g].valid = 0;
                rx_data_if[g].data = 0;
                rx_data_if[g].keep = 0;
                rx_data_if[g].last = 0;
                rx_data_if[g].id = 0;
                rx_data_if[g].qos_tag = 0;
                rx_data_if[g].is_bad_frame = 0;
                
                rx_meta_if[g].valid = 0;
                rx_meta_if[g].dest_port_mask = 0;
                rx_meta_if[g].qos_tag = 0;
                rx_meta_if[g].id = 0;
                
                pkt_done[g] = 0;
                
                forever begin
                    // Wait for packet request
                    @(posedge clk);
                    if (pkt_req[g]) begin
                        automatic int num_beats;
                        automatic int bytes_remaining;
                        automatic logic [PACKET_ID_WIDTH-1:0] my_id;  // Updated width
                        automatic logic [NUM_PORT-1:0] my_dst_mask;
                        automatic logic [2:0] my_qos;
                        automatic int my_size;
                        
                        // Capture parameters
                        my_id = pkt_id[g];
                        my_dst_mask = pkt_dst_mask[g];
                        my_qos = pkt_qos[g];
                        my_size = pkt_size[g];
                        num_beats = (my_size + (DATA_WIDTH/8) - 1) / (DATA_WIDTH/8);
                        bytes_remaining = my_size;
                        
                        // Send metadata
                        rx_meta_if[g].dest_port_mask <= my_dst_mask;
                        rx_meta_if[g].qos_tag <= my_qos;
                        rx_meta_if[g].id <= my_id;
                        rx_meta_if[g].valid <= 1'b1;
                        
                        do @(posedge clk); while (!rx_meta_if[g].ready);
                        rx_meta_if[g].valid <= 1'b0;
                        
                        // Send data beats
                        for (int beat = 0; beat < num_beats; beat++) begin
                            automatic int keep_val;
                            
                            if (bytes_remaining >= (DATA_WIDTH/8))
                                keep_val = (DATA_WIDTH/8);
                            else
                                keep_val = bytes_remaining;
                            
                            bytes_remaining -= keep_val;
                            
                            rx_data_if[g].data <= $urandom;
                            rx_data_if[g].keep <= keep_val[3:0];
                            rx_data_if[g].valid <= 1'b1;
                            rx_data_if[g].last <= (beat == num_beats-1);
                            rx_data_if[g].is_bad_frame <= 1'b0;
                            rx_data_if[g].id <= my_id;
                            rx_data_if[g].qos_tag <= my_qos;
                            
                            do @(posedge clk); while (!rx_data_if[g].ready);
                        end
                        
                        rx_data_if[g].valid <= 1'b0;
                        rx_data_if[g].last <= 1'b0;
                        
                        // Signal completion
                        pkt_done[g] <= 1'b1;
                        @(posedge clk);
                        pkt_done[g] <= 1'b0;
                    end
                end
            end
        end
    endgenerate

    //==========================================================================
    // RX monitors - one per output port (updated to NUM_PORT)
    //==========================================================================
    generate
        for (genvar g = 0; g < NUM_PORT; g++) begin : gen_rx_monitor
            initial begin
                automatic int beat_count = 0;
                automatic logic [PACKET_ID_WIDTH-1:0] current_id;  // Updated width
                automatic logic [2:0] current_qos;
                automatic int current_size;

                tx_data_if[g].ready = 1'b1;

                forever begin
                    @(posedge clk);
                    if (tx_data_if[g].valid && tx_data_if[g].ready) begin
                        if (beat_count == 0) begin
                            current_id = tx_data_if[g].id;
                            current_qos = tx_data_if[g].qos_tag;
                            current_size = 0;
                            
                            // DEBUG: Print received packet
                            $display("[MONITOR] RX Packet: ID=%0d on port %0d qos=%0d (binary %b)",
                                     current_id, g, current_qos, current_qos);
                        end

                        current_size += tx_data_if[g].keep;
                        beat_count++;

                        // Check QoS ordering
                        qos_check.check_priority_order(current_id, current_qos, $time);
                        qos_check.check_starvation(current_qos, $time);

                        if (tx_data_if[g].last) begin
                            scoreboard.record_rx(
                                current_id,
                                g,
                                current_qos,
                                current_size,
                                tx_data_if[g].is_bad_frame
                            );
                            beat_count = 0;
                        end
                    end
                end
            end
        end
    endgenerate

    //==========================================================================
    // Helper task to send packet (triggers the per-port driver) - updated widths
    //==========================================================================
    task automatic send_packet(
        input int src,
        input int dst,
        input int size,
        input logic [2:0] qos
    );
        automatic int my_pkt_id;
        
        // Get unique packet ID (protected by sequential execution)
        my_pkt_id = next_pkt_id++;
        
        // Set up packet parameters
        pkt_dst_mask[src] = (1 << dst);
        pkt_qos[src] = qos;
        pkt_size[src] = size;
        pkt_id[src] = my_pkt_id[PACKET_ID_WIDTH-1:0];  // Updated width
        
        // DEBUG: Print transmitted packet
        $display("[DRIVER] TX Packet: ID=%0d from port %0d to port %0d qos=%0d",
                 my_pkt_id, src, dst, qos);
        
        // Record in scoreboard before sending
        scoreboard.record_tx(my_pkt_id[PACKET_ID_WIDTH-1:0], src, dst, qos, size, 1'b0);
        
        // Trigger the driver
        @(posedge clk);
        pkt_req[src] = 1'b1;
        @(posedge clk);
        pkt_req[src] = 1'b0;
        
        // Wait for completion
        wait(pkt_done[src]);
        @(posedge clk);
    endtask

    task automatic send_multicast(
        input int src,
        input logic [NUM_PORT-1:0] dst_mask,
        input int size,
        input logic [2:0] qos
    );
        automatic int my_pkt_id;
        
        my_pkt_id = next_pkt_id++;
        
        pkt_dst_mask[src] = dst_mask;
        pkt_qos[src] = qos;
        pkt_size[src] = size;
        pkt_id[src] = my_pkt_id[PACKET_ID_WIDTH-1:0];  // Updated width
        
        // DEBUG
        $display("[DRIVER] TX Multicast: ID=%0d from port %0d mask=%b qos=%0d",
                 my_pkt_id, src, dst_mask, qos);
        
        // Record for each destination
        for (int dst = 0; dst < NUM_PORT; dst++) begin
            if (dst_mask[dst]) begin
                scoreboard.record_tx(my_pkt_id[PACKET_ID_WIDTH-1:0], src, dst, qos, size, 1'b0);
            end
        end
        
        @(posedge clk);
        pkt_req[src] = 1'b1;
        @(posedge clk);
        pkt_req[src] = 1'b0;
        
        wait(pkt_done[src]);
        @(posedge clk);
    endtask

    //==========================================================================
    // Test stimulus (updated to NUM_PORT)
    //==========================================================================
    initial begin
        $timeformat(-9, 2, " ns", 10);
        
        // Initialize request signals
        for (int i = 0; i < NUM_PORT; i++) begin
            pkt_req[i] = 0;
            pkt_dst_mask[i] = 0;
            pkt_qos[i] = 0;
            pkt_size[i] = 0;
            pkt_id[i] = 0;
        end

        wait (rst_n);
        repeat (20) @(posedge clk);

        $display("\n========================================");
        $display("  FABRIC QoS TEST SEQUENCE - FIXED PRIORITIES");
        $display("  Note: Lower QoS number = HIGHER priority");
        $display("========================================\n");

        //----------------------------------------------------------------------
        // Test 1: Basic unicast with different priorities - FIXED
        //----------------------------------------------------------------------
        $display("[%0t] TEST 1: Priority Ordering", $time);
        
        // CORRECTED: 0=highest, 1=medium, 2=lowest
        send_packet(.src(0), .dst(1), .size(64), .qos(3'b000));   // HIGHEST priority (0)
        send_packet(.src(2), .dst(1), .size(64), .qos(3'b001));   // MEDIUM priority (1)
        send_packet(.src(3), .dst(1), .size(64), .qos(3'b010));   // LOWEST priority (2)

        repeat (200) @(posedge clk);

        //----------------------------------------------------------------------
        // Test 2: Multicast high priority
        //----------------------------------------------------------------------
        $display("[%0t] TEST 2: Multicast High Priority", $time);
        send_multicast(.src(0), .dst_mask(10'b0000001111), .size(128), .qos(3'b000));

        repeat (300) @(posedge clk);

        //----------------------------------------------------------------------
        // Test 3: Sustained mixed load (sequential for simplicity)
        //----------------------------------------------------------------------
        $display("[%0t] TEST 3: Sustained Mixed Traffic", $time);
        
        for (int i = 0; i < 10; i++) begin
            send_packet(.src(0), .dst((i % (NUM_PORT-1)) + 1), .size(64), .qos(3'b000));
        end
        
        for (int i = 0; i < 10; i++) begin
            send_packet(.src(1), .dst(i % NUM_PORT), .size(128), .qos(3'b001));
        end
        
        for (int i = 0; i < 10; i++) begin
            send_packet(.src(2), .dst(i % NUM_PORT), .size(256), .qos(3'b010));
        end

        repeat (1000) @(posedge clk);

        //----------------------------------------------------------------------
        // Test 4: Congestion scenario (all ports to port 5)
        //----------------------------------------------------------------------
        $display("[%0t] TEST 4: Congestion (all->port 5)", $time);
        
        for (int rep = 0; rep < 3; rep++) begin
            for (int s = 0; s < NUM_PORT; s++) begin
                if (s != 5) begin
                    send_packet(.src(s), .dst(5), .size(256), .qos(3'b001));
                end
            end
        end

        repeat (2000) @(posedge clk);

        //----------------------------------------------------------------------
        // Print reports and finish
        //----------------------------------------------------------------------
        scoreboard.print_report();
        qos_check.print_report();

        $display("[%0t] All tests complete", $time);
        $finish;
    end

endmodule
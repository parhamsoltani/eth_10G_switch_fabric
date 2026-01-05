`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Switch Model - Reference model for verification
//////////////////////////////////////////////////////////////////////////////////

`include "sim_options.vh"
`include "implement_options.vh"

module switch_model #(
    parameter NUM_PORT = 4
)(
    input wire sys_clk,
    input wire sys_reset,
    
    // Input frames from DUT RX monitor (generic mailbox)
    mailbox frame_mailbox_in [NUM_PORT],
    
    // Output expected frames (generic mailbox)
    mailbox frame_mailbox_out [NUM_PORT]
);

    // Local frame info structure (same as monitor)
    typedef struct {
        byte data[];
        int size;
        int port_id;
        time timestamp;
        bit has_error;
    } frame_info_t;

    //==========================================================================
    // MAC Table for Learning (simplified)
    //==========================================================================
    bit [47:0] mac_table [256];
    bit [7:0]  mac_port  [256];
    bit        mac_valid [256];
    int        mac_count = 0;

    //==========================================================================
    // Initialize
    //==========================================================================
    initial begin
        for (int i = 0; i < 256; i++) begin
            mac_valid[i] = 0;
        end
    end

    //==========================================================================
    // Learn MAC Address
    //==========================================================================
    function automatic void learn_mac(input bit [47:0] mac, input int port);
        int hash;
        hash = mac[7:0]; // Simple hash using lower 8 bits
        mac_table[hash] = mac;
        mac_port[hash] = port;
        mac_valid[hash] = 1;
    endfunction

    //==========================================================================
    // Lookup MAC Address
    //==========================================================================
    function automatic int lookup_mac(input bit [47:0] mac);
        int hash;
        hash = mac[7:0];
        if (mac_valid[hash] && mac_table[hash] == mac) begin
            return mac_port[hash];
        end
        return -1; // Not found
    endfunction

    //==========================================================================
    // Process Frames from Each Input Port
    //==========================================================================
    generate
        for (genvar p = 0; p < NUM_PORT; p++) begin : gen_port_model
            
            initial begin
                frame_info_t in_frame;
                frame_info_t out_frame;
                bit [47:0] dest_mac;
                bit [47:0] src_mac;
                int dest_port;
                bit is_broadcast;
                bit is_multicast;
                int dp;
                int i;
                
                // Wait for reset
                wait (!sys_reset);
                repeat (100) @(posedge sys_clk);
                
                forever begin
                    if (frame_mailbox_in[p] != null) begin
                        if (frame_mailbox_in[p].try_get(in_frame)) begin
                            
                            `ifdef DEBUG_MODEL
                            $display("[%0t] MODEL[%0d]: Received frame, size=%0d", 
                                     $time, p, in_frame.size);
                            `endif
                            
                            // Extract MAC addresses (assuming standard Ethernet frame)
                            if (in_frame.size >= 14) begin
                                dest_mac = {in_frame.data[0], in_frame.data[1], in_frame.data[2],
                                           in_frame.data[3], in_frame.data[4], in_frame.data[5]};
                                src_mac  = {in_frame.data[6], in_frame.data[7], in_frame.data[8],
                                           in_frame.data[9], in_frame.data[10], in_frame.data[11]};
                                
                                // Learn source MAC
                                learn_mac(src_mac, p);
                                
                                // Determine destination
                                is_broadcast = (dest_mac == 48'hFFFFFFFFFFFF);
                                is_multicast = dest_mac[0]; // LSB of first byte indicates multicast
                                
                                if (is_broadcast || is_multicast) begin
                                    // Forward to all ports except source
                                    for (dp = 0; dp < NUM_PORT; dp++) begin
                                        if (dp != p && frame_mailbox_out[dp] != null) begin
                                            out_frame.data = new[in_frame.size];
                                            for (i = 0; i < in_frame.size; i++) begin
                                                out_frame.data[i] = in_frame.data[i];
                                            end
                                            out_frame.size = in_frame.size;
                                            out_frame.port_id = dp;
                                            out_frame.timestamp = $time;
                                            out_frame.has_error = in_frame.has_error;
                                            
                                            frame_mailbox_out[dp].put(out_frame);
                                            
                                            `ifdef DEBUG_MODEL
                                            $display("[%0t] MODEL: Broadcast/Multicast frame from port %0d to port %0d", 
                                                     $time, p, dp);
                                            `endif
                                        end
                                    end
                                end else begin
                                    // Unicast - use destination MAC to determine port
                                    dest_port = dest_mac[47:40] % NUM_PORT;
                                    
                                    if (dest_port != p && frame_mailbox_out[dest_port] != null) begin
                                        out_frame.data = new[in_frame.size];
                                        for (i = 0; i < in_frame.size; i++) begin
                                            out_frame.data[i] = in_frame.data[i];
                                        end
                                        out_frame.size = in_frame.size;
                                        out_frame.port_id = dest_port;
                                        out_frame.timestamp = $time;
                                        out_frame.has_error = in_frame.has_error;
                                        
                                        frame_mailbox_out[dest_port].put(out_frame);
                                        
                                        `ifdef DEBUG_MODEL
                                        $display("[%0t] MODEL: Unicast frame from port %0d to port %0d", 
                                                 $time, p, dest_port);
                                        `endif
                                    end
                                end
                            end else begin
                                $warning("[%0t] MODEL[%0d]: Frame too short (%0d bytes)", 
                                         $time, p, in_frame.size);
                            end
                        end
                    end
                    
                    @(posedge sys_clk);
                end
            end
            
        end
    endgenerate

endmodule
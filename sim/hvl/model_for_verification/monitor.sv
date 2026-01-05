`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Monitor Module - Monitors all ports
//////////////////////////////////////////////////////////////////////////////////

`include "sim_options.vh"
`include "implement_options.vh"

module monitor #(
    parameter NUM_PORT = 4,
    parameter DATA_WIDTH = 64,
    parameter KEEP_WIDTH = DATA_WIDTH/8
)(
    input wire clk,
    input wire rst_n,
    
    // AXI-Stream interfaces to monitor (array)
    axis_if.slave_mp axis [NUM_PORT],
    
    // Mailbox array for captured frames (use generic mailbox)
    mailbox frame_mailbox [NUM_PORT]
);

    // Local frame info structure
    typedef struct {
        byte data[];
        int size;
        int port_id;
        time timestamp;
        bit has_error;
    } frame_info_t;

    //==========================================================================
    // Per-Port Monitor Logic
    //==========================================================================
    generate
        for (genvar p = 0; p < NUM_PORT; p++) begin : gen_port_monitor
            
            // Frame buffer per port
            byte frame_buffer[$];
            bit capturing;
            int frame_count;
            
            // Initialize
            initial begin
                capturing = 0;
                frame_count = 0;
                frame_buffer.delete();
            end
            
            // Monitor process for each port
            always @(posedge axis[p].clk) begin
                if (axis[p].tvalid && axis[p].tready) begin
                    // Capture bytes based on tkeep
                    for (int i = 0; i < KEEP_WIDTH; i++) begin
                        if (axis[p].tkeep[i]) begin
                            frame_buffer.push_back(axis[p].tdata[i*8 +: 8]);
                        end
                    end
                    capturing = 1;
                    
                    if (axis[p].tlast) begin
                        // Frame complete - send to mailbox
                        if (frame_mailbox[p] != null && frame_buffer.size() > 0) begin
                            frame_info_t frame_info;
                            byte frame_copy[];
                            
                            frame_copy = new[frame_buffer.size()];
                            foreach (frame_buffer[i]) begin
                                frame_copy[i] = frame_buffer[i];
                            end
                            
                            // Create frame info structure
                            frame_info.data = frame_copy;
                            frame_info.size = frame_buffer.size();
                            frame_info.port_id = p;
                            frame_info.timestamp = $time;
                            frame_info.has_error = axis[p].tuser[0];
                            
                            frame_mailbox[p].put(frame_info);
                            frame_count++;
                            
                            `ifdef DEBUG_MONITOR
                            $display("[%0t] MONITOR[%0d]: Captured frame #%0d, size=%0d bytes", 
                                     $time, p, frame_count, frame_buffer.size());
                            `endif
                        end
                        
                        frame_buffer.delete();
                        capturing = 0;
                    end
                end
            end
            
        end
    endgenerate

endmodule
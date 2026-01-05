`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// AXI-Stream Driver Module
//////////////////////////////////////////////////////////////////////////////////

`include "fabric_params.vh"

import ethernet_frame_pkg::*;

module axi_driver #(
    parameter DATA_WIDTH = 64,
    parameter KEEP_WIDTH = DATA_WIDTH/8
)(
    input  wire clk,
    input  wire rst_n,
    
    // Frame input
    input  ethernet_frame tx_frame,  // Changed from Ethernet_frame
    input  wire tx_frame_valid,
    output reg  tx_frame_ready,
    
    // AXI-Stream output
    axis_if.master axis
);

    // State machine
    typedef enum logic [1:0] {
        IDLE,
        SEND_DATA,
        WAIT_READY
    } state_e;
    
    state_e state;
    
    // Frame buffer
    bit [7:0] frame_bytes[$];
    int byte_idx;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            tx_frame_ready <= 1'b1;
            axis.tdata <= '0;
            axis.tkeep <= '0;
            axis.tvalid <= 1'b0;
            axis.tlast <= 1'b0;
            axis.tuser <= 1'b0;
            frame_bytes.delete();
            byte_idx <= 0;
        end else begin
            case (state)
                IDLE: begin
                    axis.tvalid <= 1'b0;
                    axis.tlast <= 1'b0;
                    tx_frame_ready <= 1'b1;
                    
                    if (tx_frame_valid && tx_frame != null) begin
                        tx_frame_ready <= 1'b0;
                        tx_frame.get_bytes(frame_bytes);
                        byte_idx <= 0;
                        state <= SEND_DATA;
                    end
                end
                
                SEND_DATA: begin
                    // Pack bytes into data word
                    axis.tdata <= '0;
                    axis.tkeep <= '0;
                    
                    for (int i = 0; i < KEEP_WIDTH && byte_idx + i < frame_bytes.size(); i++) begin
                        axis.tdata[i*8 +: 8] <= frame_bytes[byte_idx + i];
                        axis.tkeep[i] <= 1'b1;
                    end
                    
                    axis.tvalid <= 1'b1;
                    
                    // Check if last word
                    if (byte_idx + KEEP_WIDTH >= frame_bytes.size()) begin
                        axis.tlast <= 1'b1;
                    end
                    
                    state <= WAIT_READY;
                end
                
                WAIT_READY: begin
                    if (axis.tready) begin
                        byte_idx <= byte_idx + KEEP_WIDTH;
                        
                        if (axis.tlast) begin
                            axis.tvalid <= 1'b0;
                            axis.tlast <= 1'b0;
                            frame_bytes.delete();
                            state <= IDLE;
                        end else begin
                            state <= SEND_DATA;
                        end
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
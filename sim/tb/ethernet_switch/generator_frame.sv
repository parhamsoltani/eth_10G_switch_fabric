`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Frame Generator Module
//////////////////////////////////////////////////////////////////////////////////

`include "fabric_params.vh"

import ethernet_frame_pkg::*;

module generator_frame #(
    parameter NUM_PORT = `NUM_PORTS,
    parameter DATA_WIDTH = 64,
    parameter KEEP_WIDTH = DATA_WIDTH/8
)(
    input  wire clk,
    input  wire rst_n,
    
    // Control interface
    input  wire start,
    input  wire [31:0] num_frames,
    input  wire [1:0]  traffic_pattern,  // 0=random, 1=sequential, 2=hotspot
    input  wire [31:0] frame_delay,
    output reg  done,
    
    // Frame output via mailbox
    output ethernet_frame tx_frame,
    output reg tx_frame_valid,
    input  wire tx_frame_ready,
    
    // Statistics
    output reg [31:0] frames_generated
);

    // Traffic patterns
    localparam PATTERN_RANDOM     = 2'd0;
    localparam PATTERN_SEQUENTIAL = 2'd1;
    localparam PATTERN_HOTSPOT    = 2'd2;

    // State machine
    typedef enum logic [2:0] {
        IDLE,
        GENERATE,
        SEND,
        DELAY,
        COMPLETE
    } state_e;
    
    state_e state;
    
    // Internal signals
    reg [31:0] frame_count;
    reg [31:0] delay_count;
    reg [3:0]  next_dest;
    reg [3:0]  current_src;
    
    ethernet_frame current_frame;

    // Random number for various uses
    int rand_val;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            tx_frame_valid <= 1'b0;
            frames_generated <= 32'h0;
            frame_count <= 32'h0;
            delay_count <= 32'h0;
            next_dest <= 4'h0;
            current_src <= 4'h0;
            current_frame = null;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    tx_frame_valid <= 1'b0;
                    if (start) begin
                        frame_count <= 32'h0;
                        frames_generated <= 32'h0;
                        state <= GENERATE;
                    end
                end

                GENERATE: begin
                    // Create new frame
                    current_frame = new();
                    
                    // Randomize base frame
                    if (!current_frame.randomize()) begin
                        $error("Frame randomization failed");
                    end
                    
                    // Set source port (round-robin through ports)
                    current_src = frame_count % NUM_PORT;
                    current_frame.src_port = current_src;
                    
                    // Set destination based on pattern
                    case (traffic_pattern)
                        PATTERN_RANDOM: begin
                            rand_val = $urandom_range(0, NUM_PORT-1);
                            while (rand_val == current_src) begin
                                rand_val = $urandom_range(0, NUM_PORT-1);
                            end
                            current_frame.set_unicast(rand_val);
                        end
                        
                        PATTERN_SEQUENTIAL: begin
                            next_dest = (current_src + 1) % NUM_PORT;
                            current_frame.set_unicast(next_dest);
                        end
                        
                        PATTERN_HOTSPOT: begin
                            // 50% to port 0, rest distributed
                            if ($urandom_range(0, 1) == 0 && current_src != 0) begin
                                current_frame.set_unicast(0);
                            end else begin
                                rand_val = $urandom_range(1, NUM_PORT-1);
                                while (rand_val == current_src) begin
                                    rand_val = $urandom_range(1, NUM_PORT-1);
                                end
                                current_frame.set_unicast(rand_val);
                            end
                        end
                        
                        default: begin
                            current_frame.set_unicast((current_src + 1) % NUM_PORT);
                        end
                    endcase
                    
                    // Set timing
                    current_frame.tx_time = $time;
                    
                    state <= SEND;
                end

                SEND: begin
                    tx_frame = current_frame;
                    tx_frame_valid <= 1'b1;
                    
                    if (tx_frame_ready) begin
                        tx_frame_valid <= 1'b0;
                        frames_generated <= frames_generated + 1;
                        frame_count <= frame_count + 1;
                        
                        if (frame_count + 1 >= num_frames) begin
                            state <= COMPLETE;
                        end else if (frame_delay > 0) begin
                            delay_count <= frame_delay;
                            state <= DELAY;
                        end else begin
                            state <= GENERATE;
                        end
                    end
                end

                DELAY: begin
                    tx_frame_valid <= 1'b0;
                    if (delay_count > 0) begin
                        delay_count <= delay_count - 1;
                    end else begin
                        state <= GENERATE;
                    end
                end

                COMPLETE: begin
                    tx_frame_valid <= 1'b0;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
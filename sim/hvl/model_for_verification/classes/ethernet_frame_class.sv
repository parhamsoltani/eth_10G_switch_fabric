`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Ethernet Frame Class for Verification
//////////////////////////////////////////////////////////////////////////////////

`include "fabric_params.vh"

package ethernet_frame_pkg;

    // Use NUM_PORTS from fabric_params.vh (not NUM_PORT)
    localparam int NUM_PORTS_LOCAL = `NUM_PORTS;

    typedef enum {
        UNICAST,
        MULTICAST,
        BROADCAST
    } frame_type_e;

    class ethernet_frame;
        // Frame fields
        rand bit [47:0] dest_mac;
        rand bit [47:0] src_mac;
        rand bit [15:0] ethertype;
        rand bit [7:0]  payload[];
        bit [31:0]      fcs;
        
        // Metadata
        rand int unsigned src_port;
        rand int unsigned dest_port;
        rand bit [NUM_PORTS_LOCAL-1:0] dest_mask;
        rand frame_type_e frame_type;
        rand bit [2:0] qos_priority;
        
        // Timing
        time tx_time;
        time rx_time;
        
        // Identification
        int frame_id;
        static int frame_count = 0;

        // Constraints
        constraint valid_ports {
            src_port < NUM_PORTS_LOCAL;
            dest_port < NUM_PORTS_LOCAL;
            src_port != dest_port;
        }

        constraint valid_payload_size {
            payload.size() >= 46;
            payload.size() <= 1500;
        }

        constraint valid_ethertype {
            ethertype >= 16'h0600;
        }

        constraint qos_range {
            qos_priority inside {[0:7]};
        }

        // Constructor
        function new();
            frame_id = frame_count++;
        endfunction

        // Set frame as unicast to specific port
        function void set_unicast(int unsigned dst_port);
            frame_type = UNICAST;
            dest_port = dst_port;
            dest_mask = '0;
            dest_mask[dst_port] = 1'b1;
            // Encode destination port in MAC address for switch lookup
            dest_mac[47:40] = dst_port[7:0];
            dest_mac[39:0] = {8'h00, 8'h00, 8'h00, 8'h00, 8'h01};
        endfunction

        // Set frame as broadcast
        function void set_broadcast(int unsigned src);
            frame_type = BROADCAST;
            src_port = src;
            dest_mask = {NUM_PORTS_LOCAL{1'b1}};
            dest_mask[src] = 1'b0;  // Don't send back to source
            dest_mac = 48'hFFFF_FFFF_FFFF;
        endfunction

        // Set frame as multicast
        function void set_multicast(bit [NUM_PORTS_LOCAL-1:0] mask, int unsigned src);
            frame_type = MULTICAST;
            src_port = src;
            dest_mask = mask;
            dest_mask[src] = 1'b0;  // Don't send back to source
            dest_mac[47:40] = 8'h01;  // Multicast bit set
            dest_mac[39:0] = {8'h00, 8'h5E, 8'h00, 8'h00, 8'h01};
        endfunction

        // Calculate FCS (simplified CRC32)
        function void calculate_fcs();
            // Simplified - in real implementation use CRC32
            fcs = 32'hDEADBEEF;
        endfunction

        // Get frame as byte array
        function void get_bytes(output bit [7:0] bytes[$]);
            bytes.delete();
            // Destination MAC
            for (int i = 5; i >= 0; i--) bytes.push_back(dest_mac[i*8 +: 8]);
            // Source MAC
            for (int i = 5; i >= 0; i--) bytes.push_back(src_mac[i*8 +: 8]);
            // Ethertype
            bytes.push_back(ethertype[15:8]);
            bytes.push_back(ethertype[7:0]);
            // Payload
            foreach (payload[i]) bytes.push_back(payload[i]);
            // FCS
            calculate_fcs();
            for (int i = 3; i >= 0; i--) bytes.push_back(fcs[i*8 +: 8]);
        endfunction

        // Copy function
        function ethernet_frame copy();
            ethernet_frame c = new();
            c.dest_mac = this.dest_mac;
            c.src_mac = this.src_mac;
            c.ethertype = this.ethertype;
            c.payload = this.payload;
            c.fcs = this.fcs;
            c.src_port = this.src_port;
            c.dest_port = this.dest_port;
            c.dest_mask = this.dest_mask;
            c.frame_type = this.frame_type;
            c.qos_priority = this.qos_priority;
            c.tx_time = this.tx_time;
            c.rx_time = this.rx_time;
            c.frame_id = this.frame_id;
            return c;
        endfunction

        // Compare frames
        function bit compare(ethernet_frame other);
            if (other == null) return 0;
            if (dest_mac != other.dest_mac) return 0;
            if (src_mac != other.src_mac) return 0;
            if (ethertype != other.ethertype) return 0;
            if (payload.size() != other.payload.size()) return 0;
            foreach (payload[i]) begin
                if (payload[i] != other.payload[i]) return 0;
            end
            return 1;
        endfunction

        // Display frame info
        function void display(string prefix = "");
            $display("%s[Frame %0d] Type=%s Src=%0d Dst=%0d Size=%0d QoS=%0d",
                     prefix, frame_id, frame_type.name(), src_port, dest_port,
                     payload.size() + 18, qos_priority);
            $display("%s  Dest MAC: %h:%h:%h:%h:%h:%h",
                     prefix, dest_mac[47:40], dest_mac[39:32], dest_mac[31:24],
                     dest_mac[23:16], dest_mac[15:8], dest_mac[7:0]);
            $display("%s  Src MAC:  %h:%h:%h:%h:%h:%h",
                     prefix, src_mac[47:40], src_mac[39:32], src_mac[31:24],
                     src_mac[23:16], src_mac[15:8], src_mac[7:0]);
        endfunction

    endclass

endpackage
`timescale 1ns / 1ps
`default_nettype none

`ifndef SWITCH_METADATA_IF_SV
`define SWITCH_METADATA_IF_SV

`include "fabric_params.vh"

interface switch_metadata_if #(
    parameter PORT_MASK_WIDTH = `NUM_PORTS,
    parameter ID_WIDTH        = `PACKET_ID_WIDTH,
    parameter QOS_TAG_WIDTH   = `QOS_TAG_WIDTH
);
    // Routing information
    logic [PORT_MASK_WIDTH-1:0]  dest_port_mask;  // Multicast/unicast
    logic [ID_WIDTH-1:0]         id;              // Packet ID
    logic [QOS_TAG_WIDTH-1:0]    qos_tag;         // Priority level

    // Handshake
    logic                        valid;
    logic                        ready;

    // Optional: VLAN tag
    logic [11:0]                 vlan_id;

    // Master modport
    modport master (
        input  ready,
        output dest_port_mask, id, qos_tag, vlan_id, valid
    );

    // Slave modport
    modport slave (
        input  dest_port_mask, id, qos_tag, vlan_id, valid,
        output ready
    );

    // Monitor modport
    modport monitor (
        input  dest_port_mask, id, qos_tag, vlan_id, valid, ready
    );

endinterface

`endif // SWITCH_METADATA_IF_SV

`default_nettype wire
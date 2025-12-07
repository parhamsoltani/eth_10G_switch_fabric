`timescale 1ns / 1ps

`ifndef SWITCH_METADATA_IF_SV
`define SWITCH_METADATA_IF_SV

`include "fabric_params.vh"

interface switch_metadata_if #(
    parameter PORT_MASK_WIDTH = `NUM_PORTS,
    parameter ID_WIDTH        = `PACKET_ID_WIDTH,
    parameter QOS_TAG_WIDTH   = `QOS_TAG_WIDTH
);
    // Routing information
    logic [PORT_MASK_WIDTH-1:0]  dest_port_mask;
    logic [ID_WIDTH-1:0]         id;
    logic [QOS_TAG_WIDTH-1:0]    qos_tag;

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

    // ADDED: Master modport with _mp suffix (for consistency with switch_data_if)
    modport master_mp (
        input  ready,
        output dest_port_mask, id, qos_tag, vlan_id, valid
    );

    // ADDED: Slave modport with _mp suffix (for consistency with switch_data_if)
    modport slave_mp (
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
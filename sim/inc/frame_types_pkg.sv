`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Package for shared frame types used in verification
//////////////////////////////////////////////////////////////////////////////////

package frame_types_pkg;

    // Frame info structure for mailbox communication
    typedef struct {
        byte data[];
        int size;
        int port_id;
        time timestamp;
        bit has_error;
    } frame_info_t;

endpackage
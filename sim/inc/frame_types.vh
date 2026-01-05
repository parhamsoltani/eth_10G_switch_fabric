//////////////////////////////////////////////////////////////////////////////////
// Frame Types Include File - Include this in each file that needs frame_info_t
//////////////////////////////////////////////////////////////////////////////////

`ifndef FRAME_TYPES_VH
`define FRAME_TYPES_VH

// Note: This typedef must be inside a module/interface/package scope
// Each module will have its own local copy, but they're structurally identical

`define DEFINE_FRAME_INFO_T \
    typedef struct { \
        byte data[]; \
        int size; \
        int port_id; \
        time timestamp; \
        bit has_error; \
    } frame_info_t

`endif
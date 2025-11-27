//////////////////////////////////////////////////////////////////////////////////
// Implementation Options - QoS-Enabled Configuration
// Generated for 10x10G switch with QoS support
//////////////////////////////////////////////////////////////////////////////////

`ifndef IMPLEMENT_OPTIONS_VH
`define IMPLEMENT_OPTIONS_VH

//=============================================================================
// Basic Switch Configuration
//=============================================================================
`define LINE_RATE 10                // Gbps per port
`define N 10                        // Number of ports
`define NUM_PORT 10                 // Same as N (for compatibility)
`define D 16384                     // Main memory depth
`define S 10                        // Number of cells per packet
`define X 64                        // XPQ depth
`define U 1                         // Unicast/multicast mode
`define W 64                        // Cell width (bits)
`define OUTPUT_QUEUE_DEPTH 64       // Output queue depth
`define MULTICAST_SUPPORT 1         // Enable multicast

//=============================================================================
// QoS Configuration (*** ADDED ***)
//=============================================================================
`define ENABLE_QoS 1                // Enable QoS features
`define QOS_TAG_WIDTH 3             // 3 bits = 8 priority levels
`define PRIORITY_LEVELS 8           // Number of QoS levels
`define VOQ_PER_PRIORITY 1          // Separate VOQ per priority
`define DEFICIT_COUNTER_WIDTH 16    // For weighted fair queuing

//=============================================================================
// QoS Priority Definitions
//=============================================================================
`define PRIORITY_NETWORK_CONTROL 3'd7  // Highest (routing protocols)
`define PRIORITY_VOICE          3'd6  // VoIP
`define PRIORITY_VIDEO          3'd5  // Streaming
`define PRIORITY_CRITICAL       3'd4  // Critical apps
`define PRIORITY_EXCELLENT      3'd3  // Premium
`define PRIORITY_STANDARD       3'd2  // Default
`define PRIORITY_BULK           3'd1  // Background
`define PRIORITY_BACKGROUND     3'd0  // Lowest

// Aliases for testbenches
`define PRIORITY_HIGH    `PRIORITY_NETWORK_CONTROL
`define PRIORITY_MEDIUM  `PRIORITY_STANDARD
`define PRIORITY_LOW     `PRIORITY_BACKGROUND

//=============================================================================
// Packet Configuration
//=============================================================================
`define PACKET_ID_WIDTH 8           // Packet identifier width
`define PORT_MASK_WIDTH `NUM_PORT   // For multicast

//=============================================================================
// Memory Configuration
//=============================================================================
`define ADDR_WIDTH $clog2(`D)       // Address width for main memory
`define XPQ_ADDR_WIDTH $clog2(`X)   // XPQ address width

//=============================================================================
// Timing Parameters (ns)
//=============================================================================
`define SYS_CLK_PERIOD 2.899        // 345 MHz for 10G
`define LINE_CLK_PERIOD 6.4         // 156.25 MHz for 10GBASE-R

//=============================================================================
// Simulation Options
//=============================================================================
`ifdef SIMULATION
    `define INITIAL_RESET_CYCLES 100
    `define POST_RESET_DELAY 10
    `define DEFAULT_SIM_TIME 500  // microseconds
`endif

//=============================================================================
// Synthesis Options
//=============================================================================
`ifndef SIMULATION
    `define FPGA_VENDOR "xilinx"
    `define FPGA_FAMILY "kintexu"
    // Use XPM macros for portability
    `define USE_XPM_MEMORY 1
    `define USE_XPM_FIFO 1
`endif

`endif // IMPLEMENT_OPTIONS_VH

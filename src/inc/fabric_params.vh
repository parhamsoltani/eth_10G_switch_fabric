`ifndef FABRIC_PARAMS_VH
`define FABRIC_PARAMS_VH

//═══════════════════════════════════════════════════════════════════════════════
// Fabric Architecture Parameters
//═══════════════════════════════════════════════════════════════════════════════

// Number of switch ports
`ifndef NUM_PORTS
    `define NUM_PORTS 8
`endif

// Data path width (bits)
`ifndef DATA_WIDTH
    `define DATA_WIDTH 64
`endif

// Packet ID width
`ifndef PACKET_ID_WIDTH
    `define PACKET_ID_WIDTH 16
`endif

//═══════════════════════════════════════════════════════════════════════════════
// QoS Configuration (IEEE 802.1p compliant)
//═══════════════════════════════════════════════════════════════════════════════

// Number of QoS priority levels (802.1p: 0-7)
`ifndef QOS_LEVELS
    `define QOS_LEVELS 8
`endif

// QoS tag width (3 bits supports 8 levels: 0-7)
`ifndef QOS_TAG_WIDTH
    `define QOS_TAG_WIDTH 3
`endif

//═══════════════════════════════════════════════════════════════════════════════
// Virtual Output Queue (VOQ) Parameters
//═══════════════════════════════════════════════════════════════════════════════

// Depth per QoS level in each VOQ
`ifndef VOQ_DEPTH_PER_QOS
    `define VOQ_DEPTH_PER_QOS 32
`endif

// Total VOQ depth per destination
`ifndef VOQ_TOTAL_DEPTH
    `define VOQ_TOTAL_DEPTH (`VOQ_DEPTH_PER_QOS * `QOS_LEVELS)
`endif

// Number of VOQs per port (one per destination)
`ifndef NUM_VOQS_PER_PORT
    `define NUM_VOQS_PER_PORT `NUM_PORTS
`endif

//═══════════════════════════════════════════════════════════════════════════════
// Metadata Configuration
//═══════════════════════════════════════════════════════════════════════════════

// Total metadata width
`ifndef META_DATA_WIDTH
    `define META_DATA_WIDTH 19
`endif

// Metadata field offsets
`ifndef META_QOS_OFFSET
    `define META_QOS_OFFSET 0  // Bits [2:0]
`endif

`ifndef META_SRC_PORT_OFFSET
    `define META_SRC_PORT_OFFSET 3  // Bits [5:3]
`endif

`ifndef META_DST_PORT_OFFSET
    `define META_DST_PORT_OFFSET 6  // Bits [8:6]
`endif

`ifndef META_VLAN_ID_OFFSET
    `define META_VLAN_ID_OFFSET 9  // Bits [20:9] if needed
`endif

//═══════════════════════════════════════════════════════════════════════════════
// Port Width Calculations
//═══════════════════════════════════════════════════════════════════════════════

`ifndef PORT_ID_WIDTH
    `define PORT_ID_WIDTH $clog2(`NUM_PORTS)
`endif

//═══════════════════════════════════════════════════════════════════════════════
// Buffer Management
//═══════════════════════════════════════════════════════════════════════════════

// Maximum packet size (bytes)
`ifndef MAX_PACKET_SIZE
    `define MAX_PACKET_SIZE 1500
`endif

// Minimum packet size (bytes)
`ifndef MIN_PACKET_SIZE
    `define MIN_PACKET_SIZE 64
`endif

// Buffer threshold levels for flow control
`ifndef BUFFER_THRESHOLD_HIGH
    `define BUFFER_THRESHOLD_HIGH 224  // 87.5% of 256
`endif

`ifndef BUFFER_THRESHOLD_MEDIUM
    `define BUFFER_THRESHOLD_MEDIUM 192  // 75% of 256
`endif

`ifndef BUFFER_THRESHOLD_LOW
    `define BUFFER_THRESHOLD_LOW 128  // 50% of 256
`endif

//═══════════════════════════════════════════════════════════════════════════════
// Scheduler Parameters
//═══════════════════════════════════════════════════════════════════════════════

// Enable aging mechanism for starvation prevention
`ifndef SCHEDULER_ENABLE_AGING
    `define SCHEDULER_ENABLE_AGING 0
`endif

// Cycles before a request gets priority boost
`ifndef SCHEDULER_AGING_THRESHOLD
    `define SCHEDULER_AGING_THRESHOLD 1000
`endif

//═══════════════════════════════════════════════════════════════════════════════
// Crossbar Configuration
//═══════════════════════════════════════════════════════════════════════════════

// Crossbar type: 0 = Simple, 1 = Pipelined, 2 = Buffered
`ifndef CROSSBAR_TYPE
    `define CROSSBAR_TYPE 1
`endif

// Pipeline stages in crossbar
`ifndef CROSSBAR_PIPELINE_STAGES
    `define CROSSBAR_PIPELINE_STAGES 2
`endif

//═══════════════════════════════════════════════════════════════════════════════
// Performance Monitoring
//═══════════════════════════════════════════════════════════════════════════════

// Enable performance counters
`ifndef ENABLE_PERF_COUNTERS
    `define ENABLE_PERF_COUNTERS 1
`endif

// Counter width
`ifndef PERF_COUNTER_WIDTH
    `define PERF_COUNTER_WIDTH 32
`endif

//═══════════════════════════════════════════════════════════════════════════════
// Timing Parameters
//═══════════════════════════════════════════════════════════════════════════════

// Clock frequency (MHz)
`ifndef CLOCK_FREQ_MHZ
    `define CLOCK_FREQ_MHZ 156.25
`endif

// Reset duration (cycles)
`ifndef RESET_CYCLES
    `define RESET_CYCLES 10
`endif

`endif // FABRIC_PARAMS_VH
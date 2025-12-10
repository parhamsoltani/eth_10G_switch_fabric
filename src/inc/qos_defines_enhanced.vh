// qos_defines_enhanced.vh - Full 8-level QoS defines (aligned with doc_v2.md)
// Based on des_main_3.txt scheduler params and  weighted example

`ifndef QOS_DEFINES_ENHANCED_VH
`define QOS_DEFINES_ENHANCED_VH

`define QOS_TAG_WIDTH 3  // 8 priority levels (0-7, IEEE 802.1p compliant)
`define QOS_WEIGHTS '{64, 32, 16, 8, 4, 2, 1, 1}  // Weighted shares (higher = more bandwidth)
`define QOS_LEVELS (1 << `QOS_TAG_WIDTH)  // 8

// QoS metadata extension for packets/cells
`define QOS_META_WIDTH (`QOS_TAG_WIDTH + 1)  // Tag + urgency bit

`endif
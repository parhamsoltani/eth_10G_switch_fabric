`timescale 1ns / 1ps
// `default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: IUST
// Engineer: Parham Soltani
//
// Create Date:  2025-08-02 16:01:45
// Module Name: packet_to_cell
// Description: Converts packets to cells with packet ID preservation
// 
// MODIFIED: Added PACKET_ID_WIDTH parameter and packet_id propagation
// FURTHER MODIFIED: Added QOS_TAG_WIDTH parameter and qos_tag propagation
//////////////////////////////////////////////////////////////////////////////////

module packet_to_cell #(
    parameter   NUM_PORT                = 10,
    parameter   S                       = 10,            // speed up
    parameter   W_MINI                  = 64,            // bus data width (mini cell data width)
    parameter   FULL_WAIT_DURATION      = 50,
    parameter   PACKET_ID_WIDTH         = 8,             // NEW: Packet ID width
    parameter   QOS_TAG_WIDTH           = 3,             // NEW: QoS tag width
    // DO NOT CHANGE
    parameter   KEEP_WIDTH              = $clog2((W_MINI/8) + 1),
    parameter   S_LOG                   = $clog2(S),
    // MODIFIED: Added PACKET_ID_WIDTH and QOS_TAG_WIDTH to metadata
    parameter   META_DATA_WIDTH         = S + KEEP_WIDTH + 1 + S_LOG + PACKET_ID_WIDTH + QOS_TAG_WIDTH
) (
    input   wire                                clk,

    input   wire [W_MINI-1:0]                   data_rx,
    input   wire [KEEP_WIDTH-1:0]               keep_rx,
    input   wire                                valid_rx,
    input   wire                                is_bad_frame_rx,
    input   wire                                last_rx,
    input   wire [NUM_PORT-1:0]                 dest_mask_rx,
    input   wire                                dest_mask_valid_rx,
    input   wire [PACKET_ID_WIDTH-1:0]          packet_id_rx,    // NEW: Packet ID input
    input   wire [QOS_TAG_WIDTH-1:0]            qos_tag_rx,      // NEW: QoS tag input

    input   wire                                end_time_slot,
    input   wire                                start_time_slot,
    input   wire [S_LOG-1:0]                    rr_counter,

    input   wire                                force_to_send,
    input   wire                                dfifo_ready,

    output  wire [NUM_PORT-1:0]                 dest_mask_o,
    output  wire                                pop_iq_o,
    output  wire                                wr_en_o,      // to pipeline mem and IQ pop
    output  wire [W_MINI-1:0]                   data_o,
    output  wire                                make_cell_o,
    output  wire                                last_cell_o,
    output  wire [META_DATA_WIDTH-1:0]          metadata_o
);
    //==============================================================================
    // local parameters and integers
    //==============================================================================
    localparam START_NUM_CELL_FORCED = 4;

    typedef enum logic [3:0] {
        IDLE_END,
        IDLE_NO_PACKET,
        FULL_CELL,
        REWRITE,
        FORCE_SEND,
        IDLE_REMAIN,
        FULL_FINISH_CELL,
        WAIT_AFTER_FULL,
        POP_TO_NEW_PACKET
    } p2c_state_t;

    //==============================================================================
    // wires, regs and memories
    //==============================================================================

    wire [W_MINI-1:0] data_i_D [0:2];
    wire wr_en_reg_D [0:1];

    reg [S_LOG-1:0]             last_minicell_index_reg = '0;
    reg                         wr_en_reg = '0;
    reg                         is_bad_frame_reg = '0;
    reg                         make_cell_reg = '0;
    reg                         last_cell_reg = '0;
    reg [S-1:0]                 keep_minicell_reg = '0;
    reg [KEEP_WIDTH-1:0]        keep_last_reg = '0;
    reg [NUM_PORT-1:0]          dest_mask_reg = '0;
    reg                         first_mini_cell = 1;
    reg [$clog2(START_NUM_CELL_FORCED):0] num_send_cell_reg = 0;
    reg [PACKET_ID_WIDTH-1:0]   packet_id_reg = '0;          // NEW: Packet ID register
    reg [QOS_TAG_WIDTH-1:0]     qos_tag_reg = '0;            // NEW: QoS tag register

    reg [S_LOG-1:0]             last_minicell_index_next;
    reg                         wr_en_next;
    reg                         is_bad_frame_next;
    reg                         make_cell_next;
    reg                         last_cell_next;
    reg [S-1:0]                 keep_minicell_next;
    reg [KEEP_WIDTH-1:0]        keep_last_next;
    reg [NUM_PORT-1:0]          dest_mask_next;
    reg                         first_mini_cell_next;
    reg [$clog2(START_NUM_CELL_FORCED):0] num_send_cell_next;
    reg [PACKET_ID_WIDTH-1:0]   packet_id_next;              // NEW: Packet ID next
    reg [QOS_TAG_WIDTH-1:0]     qos_tag_next;                // NEW: QoS tag next

    reg [$clog2(FULL_WAIT_DURATION)-1:0] dont_send_duration = 0;

    reg force_to_send_reg;
    reg force_to_send_next;

    p2c_state_t p2c_state = IDLE_NO_PACKET;
    p2c_state_t p2c_state_next;

    assign dest_mask_o  = dest_mask_reg;
    assign pop_iq_o     = wr_en_next;
    assign wr_en_o      = wr_en_reg_D[1];
    assign data_o       = data_i_D[2];
    assign make_cell_o  = make_cell_reg;
    assign last_cell_o  = last_cell_reg;
    // MODIFIED: Include packet_id and qos_tag in metadata output
    assign metadata_o   = {packet_id_reg, qos_tag_reg, keep_minicell_reg, keep_last_reg, is_bad_frame_reg, last_minicell_index_reg};

    //==============================================================================
    // Main Controls
    //==============================================================================

    always @(posedge clk) begin
        if (dfifo_ready) begin
            if (dont_send_duration > 0) begin
                dont_send_duration <= dont_send_duration - 1;
            end else begin
                dont_send_duration <= 0;
            end
        end else begin
            dont_send_duration <= FULL_WAIT_DURATION - 1;
        end
    end

    always @(*) begin
        last_minicell_index_next = last_minicell_index_reg;
        is_bad_frame_next = is_bad_frame_reg;
        keep_minicell_next = keep_minicell_reg;
        keep_last_next = keep_last_reg;
        first_mini_cell_next = first_mini_cell;
        num_send_cell_next = num_send_cell_reg;
        packet_id_next = packet_id_reg;      // NEW: Default hold
        qos_tag_next = qos_tag_reg;          // NEW: Default hold

        p2c_state_next = p2c_state;

        wr_en_next = '0;
        make_cell_next = '0;
        last_cell_next = '0;
        dest_mask_next = dest_mask_rx;

        if (force_to_send) begin
            force_to_send_next = 1;
        end else begin
            force_to_send_next = force_to_send_reg;
        end

        if (first_mini_cell && start_time_slot) begin
            keep_minicell_next = 0;
            first_mini_cell_next = 0;
        end

        case (p2c_state)
            IDLE_NO_PACKET: begin
                is_bad_frame_next = 0;
                keep_last_next = 0;
                packet_id_next = '0;         // NEW: Reset packet_id
                qos_tag_next = '0;           // NEW: Reset qos_tag
                if (!dfifo_ready) begin
                    p2c_state_next = FULL_FINISH_CELL;
                end else if (start_time_slot) begin
                    if (valid_rx) begin
                        write_minicell();
                        packet_id_next = packet_id_rx;  // NEW: Capture packet_id on first beat
                        qos_tag_next = qos_tag_rx;      // NEW: Capture qos_tag on first beat
                        p2c_state_next = FULL_CELL;
                    end
                end
            end
            IDLE_END: begin
                if (!dfifo_ready) begin
                    p2c_state_next = FULL_FINISH_CELL;
                end else if (end_time_slot) begin
                    drive_cell();
                    drive_packet();
                    p2c_state_next = IDLE_NO_PACKET;
                end
            end
            IDLE_REMAIN: begin
                if (!dfifo_ready) begin
                    p2c_state_next = FULL_FINISH_CELL;
                end else if (start_time_slot && valid_rx) begin
                    if (last_rx) begin
                        write_minicell();
                        p2c_state_next = IDLE_END;
                    end else begin
                        write_minicell();
                        p2c_state_next = FULL_CELL;
                    end
                end
            end
            FULL_CELL: begin
                if (!dfifo_ready) begin
                    p2c_state_next = FULL_FINISH_CELL;
                end else if (valid_rx) begin
                    write_minicell();
                    if (end_time_slot) begin
                        drive_cell();
                        if (last_rx) begin
                            drive_packet();
                            p2c_state_next = IDLE_NO_PACKET;
                        end else begin
                            if (num_send_cell_reg < START_NUM_CELL_FORCED || force_to_send_reg) begin
                                p2c_state_next = FORCE_SEND;
                            end else begin
                                p2c_state_next = IDLE_REMAIN;
                            end
                        end
                    end else begin
                        if (last_rx) begin
                            p2c_state_next = IDLE_END;
                        end else begin
                            p2c_state_next = FULL_CELL;
                        end
                    end
                end else begin
                    p2c_state_next = REWRITE;
                end
            end
            FORCE_SEND: begin
                if (!dfifo_ready) begin
                    p2c_state_next = FULL_FINISH_CELL;
                end else if (valid_rx) begin
                    write_minicell();
                    if (end_time_slot) begin
                        drive_cell();
                        if (last_rx) begin
                            drive_packet();
                            p2c_state_next = IDLE_NO_PACKET;
                        end else begin
                            if (force_to_send_reg) begin
                                p2c_state_next = FORCE_SEND;
                            end else begin
                                if (num_send_cell_reg < START_NUM_CELL_FORCED || force_to_send_reg) begin
                                    p2c_state_next = FORCE_SEND;
                                end else begin
                                    p2c_state_next = IDLE_REMAIN;
                                end
                            end
                        end
                    end else begin
                        if (last_rx) begin
                            p2c_state_next = IDLE_END;
                        end else begin
                            p2c_state_next = FORCE_SEND;
                        end
                    end
                end else begin
                    if (end_time_slot) begin
                        drive_cell();
                        if (num_send_cell_reg < START_NUM_CELL_FORCED || force_to_send_reg) begin
                            p2c_state_next = FORCE_SEND;
                        end else begin
                            p2c_state_next = IDLE_REMAIN;
                        end
                    end
                end
            end

            REWRITE: begin
                if (!dfifo_ready) begin
                    p2c_state_next = FULL_FINISH_CELL;
                end if (rr_counter == last_minicell_index_reg) begin
                    p2c_state_next = FULL_CELL;
                end
            end
            FULL_FINISH_CELL: begin
                if (end_time_slot) begin
                    drive_cell();
                    drive_packet();
                    keep_minicell_next = {S{1'b1}};
                    last_minicell_index_next = S - 1;
                    is_bad_frame_next = 1;
                    keep_last_next = {KEEP_WIDTH{1'b1}};
                    packet_id_next = '0;     // NEW: Clear on error
                    qos_tag_next = '0;       // NEW: Clear on error
                    p2c_state_next = WAIT_AFTER_FULL;
                end
            end
            WAIT_AFTER_FULL: begin
                wr_en_next = 1;
                if (dont_send_duration == 0) begin
                    p2c_state_next = POP_TO_NEW_PACKET;
                end
            end
            POP_TO_NEW_PACKET: begin
                wr_en_next = 1;
                if (valid_rx && last_rx) begin
                    p2c_state_next = IDLE_NO_PACKET;
                end
            end
        endcase
    end

    always @(posedge clk) begin
        wr_en_reg               <= wr_en_next;
        is_bad_frame_reg        <= is_bad_frame_next;
        make_cell_reg           <= make_cell_next;
        last_cell_reg           <= last_cell_next;
        keep_minicell_reg       <= keep_minicell_next;
        keep_last_reg           <= keep_last_next;
        last_minicell_index_reg <= last_minicell_index_next;
        p2c_state               <= p2c_state_next;
        dest_mask_reg           <= dest_mask_next;
        first_mini_cell         <= first_mini_cell_next;
        force_to_send_reg       <= force_to_send_next;
        packet_id_reg           <= packet_id_next;   // NEW: Register packet_id
        qos_tag_reg             <= qos_tag_next;     // NEW: Register qos_tag
    end

    //==============================================================================
    // Instantiated Modules
    //==============================================================================
    delayed_regs #(
        .WIDTH      (W_MINI),
        .NUM_DELAY  (2)
    ) data_rx_delay_inst (
        .clk            (clk),
        .signal_in      (data_rx),
        .delayed_signal (data_i_D)
    );

    delayed_regs #(
        .WIDTH      (1),
        .NUM_DELAY  (1)
    ) wr_en_reg_delay_inst (
        .clk            (clk),
        .signal_in      (wr_en_reg),
        .delayed_signal (wr_en_reg_D)
    );

    task drive_packet();
        force_to_send_next = 0;
        last_cell_next = 1;
        num_send_cell_next = 0;
    endtask

    task drive_cell();
        if (num_send_cell_reg < START_NUM_CELL_FORCED) begin
            num_send_cell_next = num_send_cell_reg + 1;
        end
        make_cell_next = 1;
        first_mini_cell_next = 1;
    endtask

    task write_minicell();
        wr_en_next = 1;
        keep_last_next = keep_rx;
        is_bad_frame_next = is_bad_frame_rx;
        keep_minicell_next[rr_counter] = 1;
        last_minicell_index_next = rr_counter;
    endtask

endmodule

`default_nettype wire
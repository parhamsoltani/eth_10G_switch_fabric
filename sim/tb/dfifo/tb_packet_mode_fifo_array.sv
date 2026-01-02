`timescale 1ns/1ps
// `default_nettype none

module tb_packet_mode_fifo_array;

    parameter DATA_WIDTH                    = 16;
    parameter MAIN_MEM_DEPTH                = 512;
    parameter NUM_FIFO                      = 10;
    localparam FIFO_ID_WIDTH                = $clog2(NUM_FIFO);
    localparam NUM_IN                       = 10;
    localparam ADDRESS_COPY_RATE            = 2;
    parameter NUM_IN_LOG                    = (NUM_IN   == 1) ? 1 : $clog2(NUM_IN);
    localparam META_DATA_WIDTH              = NUM_IN_LOG + FIFO_ID_WIDTH;
    localparam READY_THRESHOLD              = 2*NUM_IN + 10;

    localparam  MAIN_MEM_READ_LATENCY         = 2;
    localparam  MODEL_META_READ_LATENCY = 6;  // Was 5
    localparam  MODEL_DATA_READ_LATENCY = MODEL_META_READ_LATENCY - 1 + MAIN_MEM_READ_LATENCY;  // Now 7

    localparam DONT_SEND_DURATION = 50;
    localparam LAST_POP_TRACK = NUM_IN-1;

    localparam NUM_TEST = 20000;
    localparam NUM_ROUNDS = 2*ADDRESS_COPY_RATE*MAIN_MEM_DEPTH;




    wire [NUM_FIFO-1:0] non_empty_ports ;     // 1 if the FIFO has data
    wire [NUM_IN-1:0]               pop_from_last_packet;
    int last_pop_ids [LAST_POP_TRACK];
    reg [FIFO_ID_WIDTH-1:0] current_fifo[NUM_IN];
    reg packet_remain [NUM_FIFO];

    reg model_reset;
    int dont_send_duration;


    // Testbench signals
    reg clk;
    reg push;
    reg [DATA_WIDTH-1:0] push_data;
    reg [NUM_FIFO-1:0] push_fifo_id;
    reg [NUM_IN_LOG-1:0]           push_input_id;
    reg [META_DATA_WIDTH-1:0]      push_meta_data;
    reg                            push_last;

    reg pop;
    reg [FIFO_ID_WIDTH-1:0] pop_id;


    wire full;
    wire [DATA_WIDTH-1:0] pop_data_design;
    wire [DATA_WIDTH-1:0] pop_data_model;
    wire pop_last_design;
    wire pop_last_model;
    wire [META_DATA_WIDTH-1:0] pop_metadata_design;
    wire [META_DATA_WIDTH-1:0] pop_metadata_model;
    wire [NUM_IN_LOG-1:0]       src_out_packet_design ;
    wire [FIFO_ID_WIDTH-1:0]    dest_out_packet_design  = pop_metadata_design[FIFO_ID_WIDTH-1:0];
    wire [NUM_IN_LOG-1:0]       src_out_packet_model   = pop_metadata_model[META_DATA_WIDTH-1:FIFO_ID_WIDTH];
    wire [FIFO_ID_WIDTH-1:0]    dest_out_packet_model  = pop_metadata_model[FIFO_ID_WIDTH-1:0];


    int num_error = 0;

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end



    packet_mode_dfifo_with_mem #(
        .DATA_WIDTH             (DATA_WIDTH),
        .MAIN_MEM_DEPTH         (MAIN_MEM_DEPTH),
        .NUM_FIFO               (NUM_FIFO),
        .NUM_IN                 (NUM_IN),
        .ADDRESS_COPY_RATE      (ADDRESS_COPY_RATE),
        .META_DATA_WIDTH        (META_DATA_WIDTH),
        .MAIN_MEM_READ_LATENCY  (MAIN_MEM_READ_LATENCY),
        .READY_THRESHOLD        (READY_THRESHOLD)  // you may adjust this
    ) uut (
        .clk                (clk),
        .push               (push),
        .push_last          (push_last),
        .push_data          (push_data),
        .push_output_id     (push_fifo_id),
        .push_input_id      (push_input_id),
        .push_metadata      (push_meta_data),
        .pop                (pop),
        .pop_id             (pop_id),
        .pop_data           (pop_data_design),
        .pop_metadata       (pop_metadata_design),
        .pop_last           (pop_last_design),
        .full               (full),
        .none_mepty_fifos   (non_empty_ports),
        .pop_input_id_o      (src_out_packet_design),
        .pop_from_last_packet_o(pop_from_last_packet)
    );



    packet_mode_fifo_array_model #(
        .WIDTH             (DATA_WIDTH),
        .NUM_FIFO          (NUM_FIFO),
        .NUM_IN            (NUM_IN),
        .META_READ_LATENCY (MODEL_META_READ_LATENCY),
        .DATA_READ_LATENCY (MODEL_DATA_READ_LATENCY),
        .META_DATA_WIDTH   (META_DATA_WIDTH)
    ) model (
        .clk            (clk),
        .reset          (model_reset),
        .push           (push),
        .push_data      (push_data),
        .push_fifo_id   (push_fifo_id),
        .push_in_id     (push_input_id),
        .push_metadata  (push_meta_data),
        .push_last      (push_last),
        .pop            (pop),
        .pop_id         (pop_id),
        .pop_data       (pop_data_model),
        .pop_metadata   (pop_metadata_model),
        .pop_last       (pop_last_model)
    );


    // Test sequence
    initial begin
        $timeformat(-9, 2, " ns", 20);
        push = 0;
        pop = 0;
        push_data = 0;
        push_fifo_id = 0;
        pop_id = 0;
        push_input_id = 0;
        push_meta_data = 0;
        push_last = 1;
        model_reset = 0;
        dont_send_duration = 0;


        for (int i = 0; i < LAST_POP_TRACK; i++) begin
            last_pop_ids[i] = -1;
        end

        for (int i = 0; i < NUM_IN; i++) begin
            current_fifo[i] = $urandom_range(0, NUM_FIFO-1);
        end

        for (int i = 0; i < NUM_FIFO; i++) begin
            packet_remain[i] = 0;
        end





        repeat (20) @(posedge clk);


        // for (int i=0; i<NUM_ROUNDS; ++i) begin
            push_burst(MAIN_MEM_DEPTH);
            pop_burst(MAIN_MEM_DEPTH*2);

            push_pop_task(NUM_TEST);
            pop_burst(MAIN_MEM_DEPTH*2);

            // $display("%0d of %0d", i, NUM_ROUNDS);
        // end







        @(posedge clk);
        push = 0;
        pop = 0;

        repeat (10) @(posedge clk);

        if (num_error == 0) begin
            $display("\n\n********** Test completed successfully ********** \n\n");
        end else begin
            $display("\n\n********** Test FAILED with %0d errors ********** \n\n", num_error);
        end

        $stop;
    end

    function int random_pop_id();
        automatic int id;
        automatic int found = 0;
        automatic bit is_recent;

        // Try up to 100 random picks
        repeat (100) begin
            id = $urandom_range(0, NUM_FIFO-1);
            is_recent = 0;
            for (int j = 0; j < LAST_POP_TRACK; j++) begin
                if (id == last_pop_ids[j]) begin
                    is_recent = 1;
                    break;
                end
            end

            if (!is_recent && (non_empty_ports[id] || packet_remain[id])) begin
                found = 1;
                break;
            end
        end

        // Fallback scan
        if (!found) begin
            for (int i = 0; i < NUM_FIFO; ++i) begin
                is_recent = 0;
                for (int j = 0; j < LAST_POP_TRACK; j++) begin
                    if (i == last_pop_ids[j]) begin
                        is_recent = 1;
                        break;
                    end
                end

                if ((non_empty_ports[i] || packet_remain[i]) && !is_recent) begin
                    return i;
                end
            end
            return NUM_FIFO;  // No valid ID
        end

        return id;
    endfunction




    task push_rnd_task();
        @(posedge clk);
        #1;
        if (!full) begin
            if (dont_send_duration > 0) begin
                dont_send_duration -= 1;
            end else begin
                push_data = $urandom();
                push_input_id  = push_input_id >= NUM_IN-1 ? 0 : push_input_id+1;
                push_fifo_id   = 1 << current_fifo[push_input_id];
                push_meta_data = {push_input_id, current_fifo[push_input_id]};
                push_last   = $urandom_range(0, 99) < 20;
                push        = 1;
                #1;
                if (push_last) begin
                    current_fifo[push_input_id] = $urandom_range(0, NUM_FIFO-1);
                end
            end

        end else begin
            if (dont_send_duration == 0) begin
                push_burst_last(NUM_IN);
            end
            push = 0;
            dont_send_duration = DONT_SEND_DURATION;
        end
    endtask


    task push_last_task();
        @(posedge clk);
        #1;

        push_data = $urandom();
        push_input_id  = push_input_id >= NUM_IN-1 ? 0 : push_input_id+1;
        push_fifo_id   = 1 << current_fifo[push_input_id];
        push_meta_data = {push_input_id, current_fifo[push_input_id]};
        push_last   = 1;
        // push_last   = 0;
        push        = 1;
        #1;
        current_fifo[push_input_id] = $urandom_range(0, NUM_FIFO-1);

    endtask



    task pop_task();
        automatic int fid;

        @(posedge clk);
        #1;

        fid = random_pop_id();

        // Update history
        for (int i = LAST_POP_TRACK - 1; i > 0; i--) begin
            last_pop_ids[i] = last_pop_ids[i - 1];
        end
        last_pop_ids[0] = fid;


        if (fid == NUM_FIFO) begin
            pop = 0;
            return;
        end

        pop_id = fid;
        pop    = 1;

        fork
            begin
                for (int i = 0; i < MODEL_DATA_READ_LATENCY; ++i)
                    @(posedge clk);
                #1;

                if (pop_data_design !== pop_data_model) begin
                    $warning("MISMATCH! in data: %t, design = %x, model = %x (FIFO %0d)",
                            $time, pop_data_design, pop_data_model, fid);
                    num_error++;
                end
            end
            begin
                for (int i = 0; i < MODEL_META_READ_LATENCY; ++i)
                    @(posedge clk);
                #1;

                if (pop_last_design !== pop_last_model) begin
                    $warning("MISMATCH! in last %t, design = %x, model = %x (FIFO %0d)",
                            $time, pop_last_design, pop_last_model, fid);
                    num_error++;
                end
                if (pop_metadata_design !== pop_metadata_model) begin
                    $warning("MISMATCH! in metadata %t, design = %x, model = %x (FIFO %0d)",
                            $time, pop_metadata_design, pop_metadata_model, fid);
                    num_error++;
                end
                if (src_out_packet_design !== src_out_packet_model) begin
                    $warning("MISMATCH! in pop_src_out %t, design = %x, model = %x (FIFO %0d)",
                            $time, src_out_packet_design, src_out_packet_model, fid);
                    num_error++;
                end

                // Track packet_remain here
                if (pop_last_design) begin
                    packet_remain[fid] = 0;
                end else begin
                    packet_remain[fid] = 1;
                end
            end
        join_none


    endtask



    task push_burst(input int num=1);
        for (int i=0; i<num; ++i) begin
            push_rnd_task();
        end
        push_burst_last(NUM_IN);
    endtask

    task push_burst_last(input int num=NUM_IN);
        for (int i=0; i<num; ++i) begin
            push_last_task();
        end
        @(posedge clk);
        push = 0;
    endtask

    task pop_burst(input int num=1);
        for (int i=0; i<num; ++i) begin
            pop_task();
        end
        @(posedge clk);
        pop = 0;
    endtask

    task push_pop_task(input int num=1);
        fork
            begin
            push_burst(num);
            end
            begin
            pop_burst(num);
            end
        join
    endtask




endmodule

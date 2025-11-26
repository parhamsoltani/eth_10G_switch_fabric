`timescale 1ns/1ps
`default_nettype none

module tb_fifo_array;

    parameter DATA_WIDTH                    = 9;
    parameter MAIN_MEM_DEPTH                = 64;
    parameter NUM_FIFO                      = 10;
    parameter MAIN_MEM_MEMORY_PRIMITIVE     = "block";
    parameter NP_MEMORY_PRIMITIVE           = "block";
    parameter HP_TP_MEMORY_PRIMITIVE        = "block";
    parameter FREE_FIFO_MEMORY_PRIMITIVE    = "block";
    parameter MAIN_MEM_READ_LATENCY         = 1;
    parameter INLCUDE_PROTECTION            = 0;

    localparam POINTER_WIDTH                = $clog2(MAIN_MEM_DEPTH);
    localparam FIFO_ID_WIDTH                = $clog2(NUM_FIFO);
    localparam FREE_FIFO_DEPTH_LOG          = $clog2(MAIN_MEM_DEPTH - NUM_FIFO);
    localparam FREE_FIFO_DEPTH              = 2**FREE_FIFO_DEPTH_LOG;

    // Test config
    localparam NUM_TEST = 200;
    localparam MODEL_READ_LATENCY = MAIN_MEM_READ_LATENCY + 1;

    wire [NUM_FIFO-1:0] non_empty_ports ;     // 1 if the FIFO has data
    int last_pop_ids [3];               // last 3 popped FIFO ids



    // Testbench signals
    reg clk;
    reg push;
    reg [DATA_WIDTH-1:0] push_data;
    reg [FIFO_ID_WIDTH-1:0] push_id;

    reg pop;
    reg [FIFO_ID_WIDTH-1:0] pop_id;

    wire [DATA_WIDTH-1:0] pop_data_design;
    wire [DATA_WIDTH-1:0] pop_data_model;
    // wire pop_error;
    // wire pop_empty;
    wire full;
    wire [FREE_FIFO_DEPTH_LOG:0] num_free;


    int num_error = 0;

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // DUT instantiation
    linklist_dynamic_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .MAIN_MEM_DEPTH(MAIN_MEM_DEPTH),
        .NUM_FIFO(NUM_FIFO),
        .MAIN_MEM_MEMORY_PRIMITIVE(MAIN_MEM_MEMORY_PRIMITIVE),
        .NP_MEMORY_PRIMITIVE(NP_MEMORY_PRIMITIVE),
        .HP_TP_MEMORY_PRIMITIVE(HP_TP_MEMORY_PRIMITIVE),
        .FREE_FIFO_MEMORY_PRIMITIVE(FREE_FIFO_MEMORY_PRIMITIVE),
        .MAIN_MEM_READ_LATENCY(MAIN_MEM_READ_LATENCY),
        .INLCUDE_PROTECTION(INLCUDE_PROTECTION)
    ) uut (
        .clk        (clk),
        .push       (push),
        .push_data  (push_data),
        .push_id    (push_id),
        .pop        (pop),
        .pop_id     (pop_id),
        .pop_data   (pop_data_design),
        // .pop_error  (pop_error),
        // .pop_empty  (pop_empty),
        .full       (full),
        .num_free   (num_free),
        .none_mepty_fifos(non_empty_ports)
    );

    // Model instance
    fifo_array_model #(
        .WIDTH          (DATA_WIDTH),
        .NUM_FIFO       (NUM_FIFO),
        .READ_LATENCY   (MODEL_READ_LATENCY)
    ) model (
        .clk            (clk),
        .push           (push),
        .push_data      (push_data),
        .push_id        (push_id),
        .pop            (pop),
        .pop_id         (pop_id),
        .pop_data       (pop_data_model)
    );

    // Test sequence
    initial begin
        $timeformat(-9, 2, " ns", 20);
        push = 0;
        pop = 0;
        push_data = 0;
        push_id = 0;
        pop_id = 0;



        last_pop_ids = '{-1, -1, -1};


        repeat (20) @(posedge clk);

        push_burst(MAIN_MEM_DEPTH);
        pop_burst(MAIN_MEM_DEPTH/2);
        push_pop_task(NUM_TEST);
        pop_burst(MAIN_MEM_DEPTH*10);
        push_burst(MAIN_MEM_DEPTH*2);
        pop_burst(MAIN_MEM_DEPTH*10);

        @(posedge clk);
        push = 0;
        pop = 0;

        repeat (10) @(posedge clk);

        if (num_error == 0) begin
            $display("Test completed successfully");
        end else begin
            $display("Test FAILED with %0d errors", num_error);
        end

        $stop;
    end

    function int random_pop_id();
        automatic int id;
        automatic int found = 0;

        // Try up to 100 random picks
        repeat (100) begin
            id = $urandom_range(0, NUM_FIFO-1);
            if (non_empty_ports[id] &&
                id != last_pop_ids[0] &&
                id != last_pop_ids[1] &&
                id != last_pop_ids[2]) begin
                found = 1;
                break;
            end
        end

        // Fallback scan
        if (!found) begin
            for (int i = 0; i < NUM_FIFO; ++i) begin
                if (non_empty_ports[i] &&
                    i != last_pop_ids[0] &&
                    i != last_pop_ids[1] &&
                    i != last_pop_ids[2]) begin
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
            push_data = $urandom();
            push_id   = $urandom_range(0, NUM_FIFO-1);
            push      = 1;
            #1;
        end else begin
            push = 0;
        end
    endtask


    task pop_task();
        automatic int fid;

        @(posedge clk);
        #1;

        fid = random_pop_id();

        // Update history
        last_pop_ids[2] = last_pop_ids[1];
        last_pop_ids[1] = last_pop_ids[0];
        last_pop_ids[0] = fid;

        if (fid == NUM_FIFO) begin
            pop = 0;
            return;
        end

        pop_id = fid;
        pop    = 1;

        fork
            begin
                for (int i = 0; i < MODEL_READ_LATENCY; ++i)
                    @(posedge clk);
                #1;

                if (pop_data_design !== pop_data_model) begin
                    $warning("MISMATCH! %t, design = %x, model = %x (FIFO %0d)",
                            $time, pop_data_design, pop_data_model, fid);
                    num_error++;
                end
            end
        join_none

        
    endtask



    task push_burst(input int num=1);
        for (int i=0; i<num; ++i) begin
            push_rnd_task();
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
        for (int i=0; i<num; ++i) begin
            fork
                push_rnd_task();
                pop_task();
            join
        end
        @(posedge clk);
        pop = 0;
        push = 0;
    endtask




endmodule

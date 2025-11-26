`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Company: Parman
// Engineer: Alireza Abbasian
// 
// Create Date:  2025-03-24 17:59:01
// Module Name: Fabric_frame_tr
// Project Name: switch
// Target Devices: ku3p
// Tool Versions: Vivado 2022.2
// Description: 
// Dependencies: 
// 
// Additional Comments: 

//////////////////////////////////////////////////////////////////////////////////



class Fabric_frame_tr;

    int length;
    bit [7:0] data[];
    bit is_bad_frame;
    time start_time;
    time end_time;
    int ifg_clk; // inter frame gap
    int id;
    
    bit [1000:0] dest;
    
    
    
    function new(input int length,
                input bit [1000:0] dest,
                input int ifg_clk = 0,
                input bit is_bad_frame = 0,
                input int id = 0);
        this.data = new[length];
        this.length = length;
        this.is_bad_frame = is_bad_frame;
        this.ifg_clk = ifg_clk;
        this.dest = dest;
        this.id = id;
    endfunction
    




    static function Fabric_frame_tr create_from_raw(
                            input bit [7:0] raw_data[], 
                            input bit [1000:0] dest,
                            input int ifg_clk = 8,
                            input bit is_bad_frame = 0,
                            input int id = 0);
        
        Fabric_frame_tr new_frame = new(
            .length         (raw_data.size()),
            .dest           (dest),
            .ifg_clk        (ifg_clk),
            .is_bad_frame   (is_bad_frame),
            .id(id)
        );


        
        for (int i = 0; i < new_frame.length; i++) begin
            new_frame.data[i] = raw_data[i];
        end
        
        return new_frame;

    endfunction
    




    function Fabric_frame_tr do_copy();

        Fabric_frame_tr new_frame = new(
            .length         (this.length),
            .dest           (this.dest),
            .ifg_clk        (this.ifg_clk),
            .is_bad_frame   (this.is_bad_frame),
            .id(this.id)
        );
        
        new_frame.data = this.data;
        new_frame.start_time = this.start_time;
        new_frame.end_time = this.end_time;
        
        return new_frame;
    endfunction
    




    function bit do_compare(input Fabric_frame_tr other);

        if (this.is_bad_frame == other.is_bad_frame && this.is_bad_frame == 1) begin
            return 1;
        end else begin
            return (this.length == other.length &&
                    this.data == other.data &&
                    this.is_bad_frame == other.is_bad_frame);
        end
    endfunction
    




    function void frame_to_raw(output bit [7:0] raw_frame[]);

        raw_frame = new[this.length];

    
        for (int i = 0; i < this.length; i++)
            raw_frame[i] = this.data[i];
        
    endfunction
    






   
    
    


endclass




`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Micro Interface Driver Class
//////////////////////////////////////////////////////////////////////////////////

class Micro_driver #(
    parameter MICRO_DATA_WIDTH = 16,
    parameter MICRO_ADDR_WIDTH = 16
);
    
    virtual micro_if #(.MICRO_ADDR_WIDTH(MICRO_ADDR_WIDTH), .MICRO_DATA_WIDTH(MICRO_DATA_WIDTH)) vif;
    
    function new(virtual micro_if #(.MICRO_ADDR_WIDTH(MICRO_ADDR_WIDTH), .MICRO_DATA_WIDTH(MICRO_DATA_WIDTH)) vif);
        this.vif = vif;
        // Initialize interface signals
        vif.addr = 0;
        vif.wr_data = 0;
        vif.wr_en = 0;
        vif.rd_en = 0;
    endfunction
    
    task write_reg(
        input logic [MICRO_ADDR_WIDTH-1:0] addr,
        input logic [MICRO_DATA_WIDTH-1:0] data,
        input string description = ""
    );
        @(posedge vif.clk);
        vif.addr <= addr;
        vif.wr_data <= data;
        vif.wr_en <= 1'b1;
        vif.rd_en <= 1'b0;
        @(posedge vif.clk);
        vif.wr_en <= 1'b0;
        if (description != "") begin
            $display("[MICRO_WR] %s: addr=0x%04h, data=0x%04h", description, addr, data);
        end
    endtask
    
    task read_reg(
        input logic [MICRO_ADDR_WIDTH-1:0] addr,
        output logic [MICRO_DATA_WIDTH-1:0] data,
        input string description = ""
    );
        @(posedge vif.clk);
        vif.addr <= addr;
        vif.wr_en <= 1'b0;
        vif.rd_en <= 1'b1;
        @(posedge vif.clk);
        @(posedge vif.clk); // Wait for read data
        data = vif.rd_data;
        vif.rd_en <= 1'b0;
        if (description != "") begin
            $display("[MICRO_RD] %s: addr=0x%04h, data=0x%04h", description, addr, data);
        end
    endtask
    
endclass
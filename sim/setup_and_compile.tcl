# ===================================================================
# Master Setup and Compilation Script
# ===================================================================

puts "========================================="
puts "Switch Fabric Simulation Setup"
puts "========================================="

# Get script directory
set script_dir [file dirname [file normalize [info script]]]
cd $script_dir

# Step 1: Generate memory initialization files
puts ""
puts "Step 1: Generating memory initialization files..."
puts "-------------------------------------------------"

if {[catch {source mem_gen.tcl} result]} {
    puts "ERROR: Memory generation failed"
    puts $result
    exit 1
}

# Step 2: Compilation
puts ""
puts "Step 2: Starting compilation..."
puts "-------------------------------------------------"

if {[catch {source sim.tcl} result]} {
    puts "ERROR: Compilation failed"
    puts $result
    exit 1
}

puts ""
puts "========================================="
puts "Setup and compilation complete"
puts "========================================="
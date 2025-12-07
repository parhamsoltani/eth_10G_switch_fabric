# ===================================================================
# Memory Initialization File Generator for Switch Fabric
# ===================================================================

# === Set paths ===
set cfg_file "inc/implement_options.vh"
set mem_dir  "inc/mem_init"

puts "========================================="
puts "Memory Initialization File Generator"
puts "========================================="
puts "Config file:   $cfg_file"
puts "Output dir:    $mem_dir"
puts "========================================="

# Create output directory
file delete -force $mem_dir
file mkdir $mem_dir

# === Read config file ===
if {![file exists $cfg_file]} {
    puts "ERROR: Missing $cfg_file"
    puts "Please ensure implement_options.vh exists in sim/inc/"
    exit 1
}

set fh [open $cfg_file r]
set text [read $fh]
close $fh

# === Extract macro defines ===
proc get_define_value {text name} {
    set pattern [format {`define\s+%s\s+(\S+)} $name]
    if {[regexp $pattern $text -> val]} {
        # Remove parentheses if present
        regsub -all {[()]} $val "" val
        return $val
    } else {
        error "Missing `define $name in config file"
    }
}

# === Expression evaluation ===
proc eval_expr {expr_str vars} {
    set original_expr $expr_str

    # Replace variable names with values
    foreach {key val} $vars {
        set expr_str [string map [list $key $val] $expr_str]
    }

    # Replace ^ with ** for power
    regsub -all {\^} $expr_str ** expr_str

    # Evaluate
    set result 0
    set rc [catch { expr $expr_str } result]

    if {$rc != 0} {
        puts "ERROR evaluating: \"$original_expr\" -> \"$expr_str\""
        puts "Reason: $result"
        error $result
    }

    return $result
}

# === Read parameters from config ===
puts "\n--- Reading Configuration Parameters ---"
set N [get_define_value $text "N"]
set D [get_define_value $text "D"]
set S [get_define_value $text "S"]
set X [get_define_value $text "X"]
set U [get_define_value $text "U"]
puts "N = $N"
puts "D = $D"
puts "S = $S"
puts "X = $X"
puts "U = $U"

set vars [list N $N D $D S $S X $X U $U]

# === Define memory range expressions ===
# HP/TP in dfifo of addresses in VOQ: "0" - "N-1"
# fwft free fifo of address fifos: "N+1"-"U*D-1"  (first element at N saved in reg)
# fwft free fifo of VOQ: "N" - "U*D-1"
# fwft free fifo of VOQ: "S+1"-"D-1"
# HP/TP in cross: "0"-"S-1"
# free fifo in cross: "S+1" - "X-1"
# free fifo in cross: "S" - "X-1"

set mem_ranges {
    {" 0 "          " N - 1 "}
    {" N + 1 "      " U * D - 1 "}
    {" N  "         " U * D - 1 "}
    {" S + 1 "      " D - 1 "}
    {" S "          " D - 1 "}
    {" 0 "          " S - 1 "}
    {" S + 1 "      " X - 1 "}
    {" S "          " X - 1 "}
}

# === Define constant-value memories ===
# out read address of packet_mode_fifo_array
set mem_all_same {
    {" N " " 1 "}
    {" D " " 0 "}
}

# === File generation procedures ===
proc generate_range_file {fname start end} {
    if {$end < $start} {
        error "Range end < start ($start-$end)"
    }
    set range_count [expr {$end - $start + 1}]
    set fh [open $fname w]
    for {set addr 0} {$addr < $range_count} {incr addr} {
        set value [expr {$addr + $start}]
        puts $fh [format %X $value]
    }
    close $fh
    puts "   Created: [file tail $fname] ($range_count entries)"
}

proc generate_all_same_file {fname depth value} {
    set fh [open $fname w]
    for {set i 0} {$i < $depth} {incr i} {
        puts $fh [format %X $value]
    }
    close $fh
    puts "   Created: [file tail $fname] ($depth entries, all=$value)"
}

set generated_files {}

# === Generate range-based memory files ===
puts "\n--- Generating Range-Based Memory Files ---"
for {set i 0} {$i < [llength $mem_ranges]} {incr i} {
    set pair [lindex $mem_ranges $i]
    set start_expr [lindex $pair 0]
    set end_expr   [lindex $pair 1]

    set start [eval_expr $start_expr $vars]
    set end   [eval_expr $end_expr $vars]

    puts "\nMemory[$i]: $start_expr to $end_expr"
    puts "  Evaluated: $start to $end"

    if {$end < $start} {
        puts "WARNING: Invalid range ($start > $end), skipping"
        continue
    }

    set fname [format "%s/mem_init_%d_%d.mem" $mem_dir $start $end]
    generate_range_file $fname $start $end
    lappend generated_files $fname
}

# === Generate constant-value memory files ===
puts "\n--- Generating Constant-Value Memory Files ---"
foreach pair $mem_all_same {
    set depth_expr [lindex $pair 0]
    set value_expr [lindex $pair 1]

    set depth [eval_expr $depth_expr $vars]
    set value [eval_expr $value_expr $vars]

    puts "\nConstant Memory: depth=$depth_expr ($depth), value=$value_expr ($value)"

    set fname [format "%s/mem_init_all_%d_depth_%d.mem" $mem_dir $value $depth]
    generate_all_same_file $fname $depth $value
    lappend generated_files $fname
}

# === Final verification ===
puts "\n========================================="
puts "Verification"
puts "========================================="
set success 1
foreach f $generated_files {
    if {![file exists $f]} {
        puts " Missing: $f"
        set success 0
    }
}

if {$success} {
    puts " All [llength $generated_files] memory files created successfully!"
    puts "\nOutput directory:"
    puts "  $mem_dir"
    puts "\nGenerated files:"
    foreach f $generated_files {
        puts "  - [file tail $f]"
    }
    puts "\n========================================="
    puts "SUCCESS: Memory generation complete"
    puts "========================================="
} else {
    puts "\n ERROR: Some files were not created"
    exit 1
}
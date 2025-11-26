set_param general.maxThreads 4
set_param synth.maxThreads 4

# === Config paths ===
set cfg_file "../../src/inc/implement_options.vh"
set mem_dir  "../../src/inc/mem_init"
file delete -force $mem_dir
file mkdir $mem_dir

# === Read config file ===
if {![file exists $cfg_file]} {
    puts "ERROR: Missing $cfg_file"
    exit 1
}
set fh [open $cfg_file r]
set text [read $fh]
close $fh

# === Extract macro defines ===
proc get_define_value {text name} {
    set pattern [format {`define\s+%s\s+(\S+)} $name]
    if {[regexp $pattern $text -> val]} {
        return $val
    } else {
        error "Missing `define $name"
    }
}



# === Expression evaluation ===
# proc eval_expr {expr_str vars} {
#     foreach {key val} $vars {
#         regsub -all "\\b$key\\b" $expr_str $val expr_str
#     }
#     regsub -all {\^} $expr_str ** expr_str
#     return [expr $expr_str]
# }


proc eval_expr {expr_str vars} {
    # puts "-----------------------------------------"
    # puts "Original Expression: $expr_str"
    set original_expr $expr_str

    # Step 1: Replace variable names with values
    foreach {key val} $vars {
        # puts "Substituting $key with $val"
        set expr_str [string map [list $key $val] $expr_str]
    }

    # puts "After substitution: $expr_str"

    # Step 2: Replace ^ with ** for power
    regsub -all {\^} $expr_str ** expr_str
    # puts "After ^ to ** conversion: $expr_str"

    # Step 3: Evaluate safely
    set result 0
    set rc [catch { expr $expr_str } result]

    if {$rc != 0} {
        puts "ERROR evaluating: \"$original_expr\" -> \"$expr_str\""
        puts "Reason: $result"
        error $result
    } else {
        puts "Evaluated Result: $result"
    }

    puts "-----------------------------------------\n"
    return $result
}




set N [get_define_value $text "N"]
set D [get_define_value $text "D"]
set S [get_define_value $text "S"]
set X [get_define_value $text "X"]
set U [get_define_value $text "U"]
puts "INFO: N = $N, D = $D, S = $S, X = $X, U = %U"

set vars [list N $N D $D S $S X $X U $U]

# === Define your expression list here ===
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

# HP/TP in dfifo of addresses in VOQ: "0" - "N-1"
# fwft free fifo of address fifos: "N+1"-"multicastRate*D"  (in fwft the first element (N) save in reg)
# fwft free fifo of VOQ: "S+1"-"D"
# HP/TP in cross: "0"-"S-1"
# free fifo in cross: "S"-" X "

# === New list of {depth value} pairs for same-value memory ===
set mem_all_same {
    {" N " " 1 "}
    {" D " " 0 "}
}

# out read address of packet_mode_fifo_array


















# === File generator ===
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
    add_files $fname
}

# === Procedure to generate memory file with repeated value ===
proc generate_all_same_file {fname depth value} {
    set fh [open $fname w]
    for {set i 0} {$i < $depth} {incr i} {
        puts $fh [format %X $value]
    }
    close $fh
    add_files $fname
}


set generated_files {}

# === Loop and generate memory files ===
for {set i 0} {$i < [llength $mem_ranges]} {incr i} {
    set pair [lindex $mem_ranges $i]
    set start_expr [lindex $pair 0]
    set end_expr   [lindex $pair 1]
    set start [eval_expr $start_expr $vars]
    set end   [eval_expr $end_expr $vars]

    puts "INFO: mem[$i] = \"$start_expr\" - \"$end_expr\"  => ($start - $end)"

    if {$end < $start} {
        puts "ERROR: mem[$i] range is invalid ($start > $end)"
        exit 1
    }

    set fname [format "%s/mem_init_%d_%d.mem" $mem_dir $start $end]
    generate_range_file $fname $start $end
    lappend generated_files $fname
}


# === Generate files from mem_all_same ===
foreach pair $mem_all_same {
    set depth_expr [lindex $pair 0]
    set value_expr [lindex $pair 1]

    # Evaluate depth and value using current vars
    set depth [eval_expr $depth_expr $vars]
    set value [eval_expr $value_expr $vars]

    puts "INFO: all-same mem: depth=$depth value=$value"

    set fname [format "%s/mem_init_all_%d_depth_%d.mem" $mem_dir $value $depth]
    generate_all_same_file $fname $depth $value
    lappend generated_files $fname
}


# === Sanity check ===
foreach f $generated_files {
    if {![file exists $f]} {
        puts "ERROR: Missing output file: $f"
        exit 1
    }
}
puts "INFO: All memory files created successfully."
puts "PRE-SYNTH: DONE."

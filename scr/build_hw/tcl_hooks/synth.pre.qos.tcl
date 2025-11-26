# QoS-aware synthesis pre-hook
# Extends synth.pre.tcl with QoS-specific memory initialization

source [file join [file dirname [info script]] synth.pre.tcl]

# === Read QoS configuration ===
set qos_enable [get_define_value $text "ENABLE_QOS"]
set qos_levels [get_define_value $text "QOS_LEVELS"]

puts "INFO: ENABLE_QOS = $qos_enable, QOS_LEVELS = $qos_levels"

if {$qos_enable == "1"} {
    # === Generate QoS priority mapping tables ===
    set qos_map_dir "$mem_dir/qos_maps"
    file mkdir $qos_map_dir

    # VLAN PCP → QoS mapping (8 entries)
    set vlan_pcp_map {
        0x2  ; # PCP 0 → MEDIUM
        0x3  ; # PCP 1 → LOW
        0x2  ; # PCP 2 → MEDIUM
        0x1  ; # PCP 3 → HIGH
        0x1  ; # PCP 4 → HIGH
        0x1  ; # PCP 5 → HIGH
        0x0  ; # PCP 6 → CRITICAL
        0x0  ; # PCP 7 → CRITICAL
    }

    set vlan_file [format "%s/vlan_pcp_to_qos.mem" $qos_map_dir]
    set fh [open $vlan_file w]
    foreach val $vlan_pcp_map {
        puts $fh [format %X $val]
    }
    close $fh
    add_files $vlan_file
    lappend generated_files $vlan_file

    # IP DSCP → QoS mapping (64 entries, simplified)
    set dscp_file [format "%s/dscp_to_qos.mem" $qos_map_dir]
    set fh [open $dscp_file w]
    for {set i 0} {$i < 64} {incr i} {
        # Simplified mapping based on DSCP ranges
        if {$i >= 48} {
            puts $fh "0"  ; # CS6/CS7 → CRITICAL
        } elseif {$i >= 40 || $i == 46} {
            puts $fh "1"  ; # AF4x/EF → HIGH
        } elseif {$i >= 16} {
            puts $fh "2"  ; # AF1x-AF3x → MEDIUM
        } else {
            puts $fh "3"  ; # CS0-CS1 → LOW
        }
    }
    close $fh
    add_files $dscp_file
    lappend generated_files $dscp_file

    puts "INFO: QoS mapping tables generated"
}

puts "PRE-SYNTH-QOS: DONE."
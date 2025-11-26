puts "Compiling for tb_qos_classifier_unit..."

set INCLUDE_OPTS "+incdir+../../src/inc +incdir+../inc +define+SIMULATION"

# Only compile the classifier module
vlog -sv $INCLUDE_OPTS ../../src/hdl/core/qos_classifier.sv
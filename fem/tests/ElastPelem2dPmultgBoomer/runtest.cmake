include(test_macros)
execute_process(COMMAND ${ELMERGRID_BIN} 1 2 angle -partdual -metiskway ${MPIEXEC_NTASKS} 3 -nooverwrite)
RUN_ELMER_TEST()

INCLUDE(test_macros)
INCLUDE_DIRECTORIES(${CMAKE_BINARY_DIR}/fem/src)

CONFIGURE_FILE(IBC.sif IBC.sif COPYONLY)

file(COPY ELMERSOLVER_STARTINFO wire.grd DESTINATION "${CMAKE_CURRENT_BINARY_DIR}/")

ADD_ELMER_TEST(mgdyn_harmonic_wire_impedanceBC2 LABELS whitney)

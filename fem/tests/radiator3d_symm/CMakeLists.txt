INCLUDE(test_macros)
INCLUDE_DIRECTORIES(${CMAKE_BINARY_DIR}/fem/src)

CONFIGURE_FILE( half.sif half.sif COPYONLY)

file(COPY box_half.grd ELMERSOLVER_STARTINFO  DESTINATION "${CMAKE_CURRENT_BINARY_DIR}/")

ADD_ELMER_TEST(radiator3d_symm LABELS quick radiator)

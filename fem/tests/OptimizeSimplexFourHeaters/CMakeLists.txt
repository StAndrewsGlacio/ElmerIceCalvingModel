INCLUDE(test_macros)
INCLUDE_DIRECTORIES(${CMAKE_BINARY_DIR}/fem/src)

CONFIGURE_FILE( case.sif case.sif COPYONLY)
ADD_ELMERTEST_MODULE(OptimizeSimplexFourHeaters CostFunction CostFunction.f90)

file(COPY ELMERSOLVER_STARTINFO spots.grd CostFunction.f90 DESTINATION "${CMAKE_CURRENT_BINARY_DIR}/")

ADD_ELMER_TEST(OptimizeSimplexFourHeaters LABELS control)

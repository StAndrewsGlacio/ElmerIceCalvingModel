IF(HAVE_MUMPS)
INCLUDE(test_macros)
INCLUDE_DIRECTORIES(${CMAKE_BINARY_DIR}/fem/src)
CONFIGURE_FILE(case.sif case.sif COPYONLY)
file(COPY ELMERSOLVER_STARTINFO winkel.grd DESTINATION "${CMAKE_CURRENT_BINARY_DIR}/")
ADD_ELMER_TEST(WinkelNavierPelem NPROCS 1 3 LABELS mumps p-fem)
ENDIF()

IF(HAVE_ZOLTAN)
IF(HAVE_MUMPS)
INCLUDE(test_macros)
INCLUDE_DIRECTORIES(${CMAKE_BINARY_DIR}/fem/src)
CONFIGURE_FILE(case.sif case.sif COPYONLY)
file(COPY ELMERSOLVER_STARTINFO solid.grd shell.grd DESTINATION "${CMAKE_CURRENT_BINARY_DIR}/")
ADD_ELMER_TEST(Shell_with_Solid_Beam_Par NPROCS 3 LABELS block shell)
ENDIF()
ENDIF()

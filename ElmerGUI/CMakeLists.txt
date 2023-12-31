CMAKE_MINIMUM_REQUIRED(VERSION 2.8.9)
SET(CMAKE_MODULE_PATH "${CMAKE_MODULE_PATH};${CMAKE_CURRENT_SOURCE_DIR}/cmake/Modules")
PROJECT(ElmerGUI CXX C)
SET(APPLICATION_INCLUDE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}/netgen/libsrc/interface")

IF(APPLE)
include(cmake/Modules/FindOpenCasCade.cmake)
# add_subdirectory(cmake/Modules)
ENDIF()

SET(WITH_PYTHONQT FALSE CACHE BOOL "ElmerGUI: Use PythonQt for scripting in post processor?")
SET(WITH_OCC FALSE CACHE BOOL "ElmerGUI: Use OpenCASCADE 6.3 for importing CAD files? Needs VTK.")
SET(WITH_MATC FALSE CACHE BOOL "ElmerGUI: Use MATC for internal operations in postprocessing?")
SET(WITH_PARAVIEW FALSE CACHE BOOL "ElmerGUI: Use ParaView for postprocessing?")
SET(WITH_VTK FALSE CACHE BOOL "ElmerGUI: Use VTK for postprocessing?")
SET(WITH_QWT TRUE CACHE BOOL "ElmerGUI: Use QWT for convergence monitor?")
SET(WITH_ELMERGUILOGGER FALSE CACHE BOOL "ElmerGUI: Include ElmerGUIlogger")

find_package(Qt5 COMPONENTS Widgets)
if (Qt5_FOUND)
set(WITH_QT5 TRUE CACHE BOOL "ElmerGUI: Use Qt5")
endif()

IF(WITH_QT5)
  MESSAGE(STATUS "------------------------------------------------")
  IF(WIN32)
    MESSAGE(STATUS "Qt5 Windows packaging")
    SET(QT5_PKG_LIST Qt5OpenGL Qt5Xml Qt5Script Qt5Gui Qt5Core Qt5Svg Qt5Widgets Qt5PrintSupport)
  ELSE()
    MESSAGE(STATUS "Qt5 non-Windows packaging")
    SET(QT5_PKG_LIST Qt5OpenGL Qt5Xml Qt5Script Qt5Gui Qt5Core Qt5Svg Qt5PrintSupport)
  ENDIF()
  FOREACH(_pkg ${QT5_PKG_LIST})
    FIND_PACKAGE(${_pkg} PATHS ${QT5_PATH})
  ENDFOREACH()
  ADD_DEFINITIONS(-DWITH_QT5)
  MESSAGE(STATUS "  [ElmerGUI] Qt5:               " ${Qt5_FOUND})
  MESSAGE(STATUS "  [ElmerGUI] Qt5 Libraries: ${Qt5OpenGL_LIBRARIES} ${Qt5Xml_LIBRARIES} ${Qt5Script_LIBRARIES} ${Qt5Gui_LIBRARIES} ${Qt5Core_LIBRARIES}")
  MESSAGE(STATUS "------------------------------------------------")
ELSE()
  MESSAGE(STATUS "------------------------------------------------")
  FIND_PACKAGE(Qt4 COMPONENTS QtOpenGL QtXml QtScript QtGui QtCore REQUIRED)
  MESSAGE(STATUS "  [ElmerGUI] Qt4:               " ${Qt4_FOUND})
  MESSAGE(STATUS "  [ElmerGUI] Qt4_LIBRARIES:     " ${Qt4_LIBRARY})
  MESSAGE(STATUS "------------------------------------------------")
ENDIF()

IF(WITH_PYTHONQT)
  IF(WITH_QT5)
    MESSAGE(FATAL_ERROR "QT5 and PythonQt is not supported")
  ENDIF()
  ADD_DEFINITIONS(-DEG_PYTHONQT)
  ADD_SUBDIRECTORY(PythonQt)
  SET(APPLICATION_INCLUDE_DIRS "${APPLICATION_INCLUDE_DIRS};${CMAKE_CURRENT_SOURCE_DIR}/PythonQt/src")
ENDIF()

SET_DIRECTORY_PROPERTIES(Application INCLUDE_DIRECTORIES "${APPLICATION_INCLUDE_DIRS}")

IF(WITH_QWT)
  ADD_DEFINITIONS(-DEG_QWT)
  FIND_PACKAGE(Qwt REQUIRED)
  FIND_PATH(QWT_INCLUDE_DIR qwt.h)
#  SET(QWT_INCLUDE_DIR "c:/b/qwt-6.1.0/include")
#  SET(QWT_LIBRARY "c:/b/qwt-6.1.0/lib/qwt.dll")
  MESSAGE(STATUS "  [ElmerGUI] Qwt:             " ${Qwt_FOUND})
  MESSAGE(STATUS "  [ElmerGUI] QWT_LIBRARY:     " ${QWT_LIBRARY})
  MESSAGE(STATUS "  [ElmerGUI] QWT_INCLUDE_DIR: " ${QWT_INCLUDE_DIR})
  MESSAGE(STATUS "------------------------------------------------")
ENDIf()

IF(WITH_OCC)

  if(APPLE)
    include_directories(/usr/local/Cellar/opencascade/7.4.0_1/include/opencascade/)
  endif()

  IF(NOT WITH_VTK)
    SET(WITHOUT_VTKPOST TRUE)
  ENDIF()
  SET(WITH_VTK TRUE)
  ADD_DEFINITIONS(-DEG_OCC)

  FIND_PACKAGE(OpenCASCADE)
  IF(OpenCASCADE_FOUND)
    MESSAGE(STATUS "  [ElmerGUI] OpenCASCADE:               " ${OpenCASCADE_FOUND})
    MESSAGE(STATUS "  [ElmerGUI] OpenCASCADE_VERSION:       " ${OpenCASCADE_VERSION})
    MESSAGE(STATUS "  [ElmerGUI] OpenCASCADE_INCLUDE_DIR:   " ${OpenCASCADE_INCLUDE_DIR})
    SET(ELMER_OCC_LIBS "TKernel;TKMath;TKG3d;TKG2d;TKBRep;TKSTEP;TKMesh;TKIGES;TKG2d;TKGeomBase;TKBool;TKBO;TKGeomAlgo;TKPrim;TKShHealing;TKSTEP209;TKSTEPAttr;TKSTEPBase;TKTopAlgo;TKXSBase" CACHE INTERNAL "")
    MESSAGE(STATUS "  [ElmerGUI] ELMER_OCC_LIBS:    " "${ELMER_OCC_LIBS}")
    MESSAGE(STATUS "------------------------------------------------")
  ELSE()
    FIND_PACKAGE(OCE REQUIRED)
    MESSAGE(STATUS "  [ElmerGUI] OCE:               " ${OCE_FOUND})
    MESSAGE(STATUS "  [ElmerGUI] OCE_VERSION:       " ${OCE_VERSION})
    MESSAGE(STATUS "  [ElmerGUI] OCE_INCLUDE_DIRS:  " ${OCE_INCLUDE_DIRS})
    SET(ELMER_OCC_LIBS "TKernel;TKMath;TKG3d;TKG2d;TKBRep;TKSTEP;TKMesh;TKIGES;TKG2d;TKGeomBase;TKBool;TKBO;TKGeomAlgo;TKPrim;TKShHealing;TKSTEP209;TKSTEPAttr;TKSTEPBase;TKTopAlgo;TKXSBase" CACHE INTERNAL "")
    MESSAGE(STATUS "  [ElmerGUI] ELMER_OCC_LIBS:    " "${ELMER_OCC_LIBS}")
    MESSAGE(STATUS "------------------------------------------------")
    SET(OpenCASCADE_INCLUDE_DIR ${OCE_INCLUDE_DIRS} CACHE PATH "Include dir for OCCT or OCE")
  ENDIF()
  
ENDIF()

IF(WITH_VTK)
  # ADD_DEFINITIONS(-DEG_VTK)
  FIND_PACKAGE(VTK REQUIRED)
  INCLUDE(${VTK_USE_FILE})
  MESSAGE(STATUS "  [ElmerGUI] VTK version:       " ${VTK_VERSION})
  MESSAGE(STATUS "  [ElmerGUI] VTK_LIBS:          " "${VTK_LIBRARIES}")
  MESSAGE(STATUS "  [ElmerGUI] VTK_INCLUDE_DIRS:  " "${VTK_INCLUDE_DIRS}")
  MESSAGE(STATUS "------------------------------------------------")
ENDIF()

IF(WITH_MATC)
  ADD_DEFINITIONS(-DEG_MATC)
  ADD_SUBDIRECTORY(matc)
  MESSAGE(STATUS "  [ElmerGUI] Compiling in matc")
  MESSAGE(STATUS "------------------------------------------------")
ENDIF()

IF(WITH_PARAVIEW)
  ADD_DEFINITIONS(-DEG_PARAVIEW)
ENDIF()


ADD_SUBDIRECTORY(netgen)
ADD_SUBDIRECTORY(Application)


IF(WIN32)
  INCLUDE(cmake/windows_bundle.cmake)
ENDIF(WIN32)

INSTALL(FILES ${CMAKE_CURRENT_SOURCE_DIR}/LICENSES DESTINATION "share/ElmerGUI/license_texts" COMPONENT "elmergui")
INSTALL(FILES ${CMAKE_CURRENT_SOURCE_DIR}/GPL-2 DESTINATION "share/ElmerGUI/license_texts" COMPONENT "elmergui")
INSTALL(FILES ${CMAKE_CURRENT_SOURCE_DIR}/GPL_EXCEPTION DESTINATION "share/ElmerGUI/license_texts" COMPONENT "elmergui")
INSTALL(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/samples DESTINATION "share/ElmerGUI" COMPONENT "elmergui_samples")


!/*****************************************************************************/
! *
! *  Elmer/Ice, a glaciological add-on to Elmer
! *  http://elmerice.elmerfem.org
! *
! * 
! *  This program is free software; you can redistribute it and/or
! *  modify it under the terms of the GNU General Public License
! *  as published by the Free Software Foundation; either version 2
! *  of the License, or (at your option) any later version.
! * 
! *  This program is distributed in the hope that it will be useful,
! *  but WITHOUT ANY WARRANTY; without even the implied warranty of
! *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
! *  GNU General Public License for more details.
! *
! *  You should have received a copy of the GNU General Public License
! *  along with this program (in file fem/GPL-2); if not, write to the 
! *  Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, 
! *  Boston, MA 02110-1301, USA.
! *
! *****************************************************************************/
! ******************************************************************************
! *
! *  Authors: F. GILLET-CHAULET
! *  Email:   fabien.gillet-cahulet@univ-grenoble-alpes.fr
! *  Web:     http://elmerice.elmerfem.org
! *
! *  Original Date: Nov. 2017
! * 
! *****************************************************************************
!!! Apply the flotation criterion to update Zb and Zs from the ice thickness H
!!!    Execute this solver on the bottom boundary where the thickness equation is solved
!!!    IF the mesh is vertically extruded export Zs on the top surface.
!
!   OUTPUT Variables:
!     Zb
!     Zs
!     DZbDt (optional, if variable found and transient simulation)
!     DZsDt (optional, if variable found and transient simulation)
!   
!   INPUT Variable:
!     H
!     bedrock (optional)
!
! PARAMETERS:
!   Constants: 
!     zsea
!     rhow
!   Material:
!      SSA Mean Density
!     
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
SUBROUTINE  Flotation_init( Model,Solver,dt,TransientSimulation )
  USE DefUtils
  IMPLICIT NONE
  !------------------------------------------------------------------------------
  TYPE(Solver_t), TARGET :: Solver
  TYPE(Model_t) :: Model
  REAL(KIND=dp) :: dt
  LOGICAL :: TransientSimulation
  !--------------------------------------------------------------------------
  CHARACTER(LEN=MAX_NAME_LEN) :: ZbName,ZsName,HName
  CHARACTER(LEN=MAX_NAME_LEN) :: SolverName='Flotation'
  TYPE(ValueList_t), POINTER :: SolverParams
  LOGICAL :: GotIt
  
  SolverParams => Solver % Values 

  ZbName = GetString(SolverParams, 'Bottom Surface Name', GotIt)
  IF (.NOT.GotIt) THEN
    CALL INFO(SolverName, 'Bottom Surface Name not found - using default Zb', level=3)
    CALL ListAddString(SolverParams,'Bottom Surface Name','Zb')
  END IF

  ZsName = GetString(SolverParams, 'Top Surface Name', GotIt)
  IF (.NOT.GotIt) THEN
    CALL INFO(SolverName, 'Top Surface Name not found - using default Zs', level=3)
    CALL ListAddString(SolverParams,'Top Surface Name','Zs')
  END IF

  HName = GetString(SolverParams, 'Thickness Variable Name', GotIt)
  IF (.NOT.GotIt) THEN
    CALL INFO(SolverName, 'Thickness Variable Name not found - using default H', level=3)
    CALL ListAddString(SolverParams,'Thickness Variable Name','H')
  END IF

END SUBROUTINE  Flotation_init
!------------------------------------------------------------------------------
!------------------------------------------------------------------------------
SUBROUTINE Flotation( Model,Solver,dt,Transient )
!------------------------------------------------------------------------------
  USE CoordinateSystems
  USE MeshUtils
  USE DefUtils

  IMPLICIT NONE
!------------------------------------------------------------------------------
  TYPE(Model_t)  :: Model
  TYPE(Solver_t), TARGET :: Solver
  LOGICAL ::  Transient
  REAL(KIND=dp) :: dt
!------------------------------------------------------------------------------
!    Local variables
!------------------------------------------------------------------------------
  TYPE(Mesh_t),POINTER :: Mesh
  TYPE(Solver_t),POINTER :: PSolver
  TYPE(Variable_t),POINTER :: Var
  TYPE(Variable_t),POINTER :: ZbVar=>NULL(),ZsVar=>NULL()
  TYPE(Variable_t),POINTER :: DZbDt=>NULL(),DZsDt=>NULL()
  TYPE(Variable_t),POINTER :: HVar=>NULL(),BedVar=>NULL()
  TYPE(Variable_t),POINTER :: GLMask=>NULL()
  TYPE(Element_t), POINTER :: Element
  TYPE(ValueList_t),POINTER :: BodyForce,Material, Params

  REAL(KIND=dp),DIMENSION(:),ALLOCATABLE,SAVE :: ZbPrev,ZsPrev
  REAL(KIND=dp),DIMENSION(:),ALLOCATABLE,SAVE :: Density
  REAL(KIND=dp),DIMENSION(:),ALLOCATABLE,SAVE :: GL
  REAL(KIND=dp) :: zsea,rhow,rhoi
  REAL(KIND=dp) :: H,zb,zs,bedrock


  INTEGER,DIMENSION(:),POINTER,SAVE :: BotPointer,TopPointer,UpPointer
  INTEGER, POINTER,SAVE :: NodeIndexes(:)
  INTEGER :: GroundedNode
  INTEGER :: ActiveDirection
  INTEGER :: t,i,n
  INTEGER :: topnode
  INTEGER :: Active

  LOGICAL,SAVE :: Initialized = .FALSE.
  LOGICAL,SAVE :: ExtrudedMesh=.False.
  LOGICAL :: Found,GotIt
  LOGICAL :: BoundarySolver

  CHARACTER(LEN=MAX_NAME_LEN) :: SolverName='Flotation'
  CHARACTER(LEN=MAX_NAME_LEN) :: ZbName,ZsName,HName

!------------------------------------------------------------------------------
  Mesh => Model % Mesh

  Params => Solver % Values

  BoundarySolver = ( Solver % ActiveElements(1) > Model % Mesh % NumberOfBulkElements )

!!! get required variables Zb,Zs,H
  ZbName = ListGetString(Params, 'Bottom Surface Name', UnFoundFatal=.TRUE.)
  zbVar => VariableGet( Model % Mesh % Variables, ZbName,UnFoundFatal=.TRUE.)
  
  ZsName = ListGetString(Params, 'Top Surface Name', UnFoundFatal=.TRUE.)
  zsVar => VariableGet( Model % Mesh % Variables, ZsName,UnFoundFatal=.TRUE.)

  HName = ListGetString(Params, 'Thickness Variable Name', UnFoundFatal=.TRUE.)
  HVar => VariableGet( Model % Mesh % Variables, HName, UnFoundFatal=.TRUE.)

!!
!! get optional variables GLMAsk,DZbDt,DZsDt,bedrock
  GLMAsk => VariableGet( Model % Mesh % Variables, 'GroundedMask')
  IF (.NOT.ASSOCIATED(GLMAsk)) THEN
    Message='GroundedMask not found'
    CALL INFO(SolverName,Message,level=5)
  ELSE
    IF ((ParEnv % PEs>1).AND.(.NOT.ASSOCIATED(Solver%Matrix))) &
       CALL FATAL(SolverName,'Solver%Matrix should be associated to update GLMask')
  END IF
  BedVar => VariableGet( Model % Mesh % Variables, 'bedrock')
  IF (.NOT.ASSOCIATED(BedVar)) THEN
     Message='bedrock not found'
     CALL INFO(SolverName,Message,level=5)
  END IF
  IF (Transient) THEN
    DzbDt => VariableGet( Model % Mesh % Variables, 'DZbDt')
    IF (.NOT.ASSOCIATED(DzbDt)) THEN
       Message='Transient simulation but DZbDt  not found'
       CALL INFO(SolverName,Message,level=5)
    END IF
    DzsDt => VariableGet( Model % Mesh % Variables, 'DZsDt')
    IF (.NOT.ASSOCIATED(DzsDt)) THEN
       Message='Transient simulation but DZsDt  not found'
       CALL INFO(SolverName,Message,level=5)
    END IF
  END IF

!!! Do some initialisation/allocation
  IF ((.NOT.Initialized).OR.Mesh%Changed) THEN

    ActiveDirection = ListGetInteger(Params,'Active Coordinate',ExtrudedMesh)
    IF (ExtrudedMesh) THEN
      ! Choose active direction coordinate and set corresponding unit vector
      !---------------------------------------------------------------------

      PSolver => Solver
      CALL DetectExtrudedStructure( Mesh, PSolver, ExtVar = Var, BotNodePointer = BotPointer , &
                                TopNodePointer = TopPointer, UpNodePointer = UpPointer)
    END IF

    IF (Initialized) deallocate(ZbPrev,ZsPrev,Density,GL)
    
    N=Model % MaxElementNodes
    allocate(ZbPrev(size(ZbVar%Values)),ZsPrev(size(ZsVar%Values)),&
             Density(N),GL(N))

    Initialized = .TRUE.
  END IF
!!

 zsea = ListGetCReal( Model % Constants, 'Sea Level', UnFoundFatal=.TRUE. )
 rhow = ListGetCReal( Model % Constants, 'water density', UnFoundFatal=.TRUE. )

 IF (ASSOCIATED(DZbDt)) ZbPrev=ZbVar%Values
 IF (ASSOCIATED(DZsDt)) ZsPrev=ZsVar%Values

 IF (ASSOCIATED(GLMask)) GLMask%Values = -1.0

! Active = GetNOFActive()
! Do t=1,Active
    !Element => GetActiveElement(t)

   IF (BoundarySolver) THEN
     Active = GetNOFBoundaryElements()
   ELSE
     Active = Solver % Mesh % NumberOfBulkElements
   ENDIF

   Do t=1,Active

    IF (BoundarySolver) THEN
      Element => GetBoundaryElement(t,Solver)
    ELSE
      Element => Solver % Mesh % Elements(t)
      CurrentModel % CurrentElement => Element
    ENDIF

    n = GetElementNOFNodes(Element)
    NodeIndexes => Element % NodeIndexes

    Material => GetMaterial(Element)

    Density(1:n) = ListGetReal( Material, 'SSA Mean Density',n, NodeIndexes,UnFoundFatal=.TRUE.)

    GroundedNode=0
    GL=-1
    Do i=1,n 

       H=HVar%Values(HVar%Perm(NodeIndexes(i)))
       rhoi=Density(i)
       zb=zsea-H*rhoi/rhow
      ! if bedrock defined check flotation criterion
       IF(ASSOCIATED(BedVar)) THEN
          bedrock=BedVar%Values(BedVar%Perm(NodeIndexes(i)))
          IF (zb.LE.bedrock) THEN
             zb=bedrock
             GL(i)=1
             GroundedNode=GroundedNode+1
          END IF
       END IF

       zs=zb+H
       ZbVar%Values(ZbVar%Perm(NodeIndexes(i)))=zb
       ZsVar%Values(ZsVar%Perm(NodeIndexes(i)))=zs

       ! compute DzDt if required
       IF (ASSOCIATED(DZbDt).AND.(dt.GT.tiny(dt))) &
          DZbDt%Values(DZbDt%Perm(NodeIndexes(i)))=(zb-ZbPrev(ZbVar%Perm(NodeIndexes(i))))/dt
       IF (ASSOCIATED(DZsDt).AND.(dt.GT.tiny(dt))) &
          DZsDt%Values(DZsDt%Perm(NodeIndexes(i)))=(zs-ZsPrev(ZsVar%Perm(NodeIndexes(i))))/dt

       ! Export Zs on top surface if required
       IF (ExtrudedMesh) THEN
          topnode=TopPointer(NodeIndexes(i))
          ZsVar%Values(ZsVar%Perm(topnode))=zs
       END IF

    End do
    IF (ASSOCIATED(GLMask)) THEN
       IF ((GroundedNode.GT.0).AND.(GroundedNode.LT.n)) THEN
           WHERE(GL.GT.0._dp) GL=0._dp
       END IF
       GLMask%Values(GLMask%Perm(NodeIndexes(1:n)))= GL(1:n) * ABS(GLMask%Values(GLMask%Perm(NodeIndexes(1:n))))
    END IF
 End Do

 IF (ASSOCIATED(GLMask).AND.( ParEnv % PEs>1 )) CALL ParallelSumVector( Solver % Matrix, GLMask%Values ,1 )

!------------------------------------------------------------------------------
END SUBROUTINE Flotation
!------------------------------------------------------------------------------

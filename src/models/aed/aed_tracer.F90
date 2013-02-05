!###############################################################################
!#                                                                             #
!# aed_tracer.F90                                                              #
!#                                                                             #
!# Developed by :                                                              #
!#     AquaticEcoDynamics (AED) Group                                          #
!#     School of Earth & Environment                                           #
!# (C) The University of Western Australia                                     #
!#                                                                             #
!# Copyright by the AED-team @ UWA under the GNU Public License - www.gnu.org  #
!#                                                                             #
!#   -----------------------------------------------------------------------   #
!#                                                                             #
!# Created March 2012                                                          #
!#                                                                             #
!###############################################################################

#ifdef _FABM_F2003_

#include "fabm_driver.h"

!
MODULE aed_tracer
!-------------------------------------------------------------------------------
! aed_tracer --- tracer biogeochemical model
!
! The AED module tracer contains equations that describe exchange of
! soluable reactive tracer across the air/water interface and sediment flux.
!-------------------------------------------------------------------------------
   USE fabm_types
   USE fabm_driver

   IMPLICIT NONE

   PRIVATE
!
   PUBLIC type_aed_tracer, aed_tracer_create
!
   TYPE,extends(type_base_model) :: type_aed_tracer
!     Variable identifiers
      _TYPE_STATE_VARIABLE_ID_,ALLOCATABLE :: id_ss(:)
      _TYPE_DEPENDENCY_ID_                 :: id_temp

!     Model parameters
      REALTYPE,ALLOCATABLE :: decay(:),settling(:), Fsed(:)

      CONTAINS      ! Model Methods
!       procedure :: initialize               => aed_tracer_init
        procedure :: do                       => aed_tracer_do
        procedure :: do_ppdd                  => aed_tracer_do_ppdd
        procedure :: do_benthos               => aed_tracer_do_benthos
        procedure :: get_conserved_quantities => aed_tracer_get_conserved_quantities
   END TYPE


!===============================================================================
CONTAINS


!###############################################################################
FUNCTION aed_tracer_create(namlst,name,parent) RESULT(self)
!-------------------------------------------------------------------------------
! Initialise the AED model
!
!  Here, the aed namelist is read and te variables exported
!  by the model are registered with FABM.
!-------------------------------------------------------------------------------
!ARGUMENTS
   INTEGER,INTENT(in)          :: namlst
   CHARACTER(len=*),INTENT(in) :: name
   _CLASS_ (type_model_info),TARGET,INTENT(inout) :: parent
!
!LOCALS
   _CLASS_ (type_aed_tracer),POINTER :: self

   INTEGER  :: num_tracers
   REALTYPE :: decay(100)
   REALTYPE :: settling(100)
   REALTYPE :: Fsed(100)
   REALTYPE :: trace_initial = _ZERO_
   INTEGER  :: i
   CHARACTER(4) :: trac_name

   REALTYPE,PARAMETER :: secs_pr_day = 86400.
   NAMELIST /aed_tracer/ num_tracers,decay,settling,Fsed
!
!-------------------------------------------------------------------------------
!BEGIN
   ALLOCATE(self)
   CALL self%initialize(name,parent)

   ! Read the namelist
   read(namlst,nml=aed_tracer,err=99)

   ! Store parameter values in our own derived type

   ALLOCATE(self%id_ss(num_tracers))
   ALLOCATE(self%decay(num_tracers))    ; self%decay(1:num_tracers)    = decay(1:num_tracers)
   ALLOCATE(self%settling(num_tracers)) ; self%settling(1:num_tracers) = settling(1:num_tracers)
   ALLOCATE(self%Fsed(num_tracers))     ; self%Fsed(1:num_tracers)     = Fsed(1:num_tracers)

   trac_name = 'ss0'
   ! Register state variables
   DO i=1,num_tracers
      trac_name(3:3) = CHAR(ICHAR('0') + i)
      self%id_ss(i) = self%register_state_variable(TRIM(trac_name),'mmol/m**3','tracer', &
                                   trace_initial,minimum=_ZERO_,no_river_dilution=.false.)
   ENDDO

   ! Register environmental dependencies
   self%id_temp = self%register_dependency(varname_temp)

   RETURN

99 CALL fatal_error('aed_tracer_init','Error reading namelist aed_tracer')

END FUNCTION aed_tracer_create
!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


!###############################################################################
SUBROUTINE aed_tracer_do(self,_FABM_ARGS_DO_RHS_)
!-------------------------------------------------------------------------------
! Right hand sides of aed_tracer model
!-------------------------------------------------------------------------------
!ARGUMENTS
   _CLASS_ (type_aed_tracer),INTENT(in) :: self
   _DECLARE_FABM_ARGS_DO_RHS_
!
!LOCALS

!-------------------------------------------------------------------------------
!BEGIN
   ! Enter spatial loops (if any)
   _FABM_LOOP_BEGIN_

   ! Leave spatial loops (if any)
   _FABM_LOOP_END_
END SUBROUTINE aed_tracer_do
!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++



!###############################################################################
SUBROUTINE aed_tracer_do_ppdd(self,_FABM_ARGS_DO_PPDD_)
!-------------------------------------------------------------------------------
! Right hand sides of tracer biogeochemical model exporting
! production/destruction matrices
!-------------------------------------------------------------------------------
!ARGUMENTS
   _CLASS_ (type_aed_tracer),INTENT(in) :: self
   _DECLARE_FABM_ARGS_DO_PPDD_
!
!LOCALS

!-------------------------------------------------------------------------------
!BEGIN
   ! Enter spatial loops (if any)
   _FABM_LOOP_BEGIN_

   ! Leave spatial loops (if any)
   _FABM_LOOP_END_
END SUBROUTINE aed_tracer_do_ppdd
!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++



!###############################################################################
SUBROUTINE aed_tracer_do_benthos(self,_FABM_ARGS_DO_BENTHOS_RHS_)
!-------------------------------------------------------------------------------
! Calculate pelagic bottom fluxes and benthic sink and source terms of AED tracer.
! Everything in units per surface area (not volume!) per time.
!-------------------------------------------------------------------------------
!ARGUMENTS
   _CLASS_ (type_aed_tracer),INTENT(in) :: self
   _DECLARE_FABM_ARGS_DO_BENTHOS_RHS_
!
!LOCALS
   ! Environment
   REALTYPE :: temp

   ! State
   REALTYPE :: ss

   ! Temporary variables
   REALTYPE :: ss_flux, theta_sed_ss = 1.0
   INTEGER  :: i

!-------------------------------------------------------------------------------
!BEGIN
   ! Enter spatial loops (if any)
   _FABM_HZ_LOOP_BEGIN_

   ! Retrieve current environmental conditions for the bottom pelagic layer.
   _GET_DEPENDENCY_(self%id_temp,temp)  ! local temperature

    DO i=1,ubound(self%id_ss,1)
    ! Retrieve current (local) state variable values.
       _GET_STATE_(self%id_ss(i),ss)

      ! Sediment flux dependent on temperature only.
      ss_flux = self%Fsed(i) * (theta_sed_ss**(temp-20.0))

      ! Transfer sediment flux value to FABM.
      _SET_BOTTOM_EXCHANGE_(self%id_ss(i),ss_flux)

   ENDDO

   ! Leave spatial loops (if any)
   _FABM_HZ_LOOP_END_

END SUBROUTINE aed_tracer_do_benthos
!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


!###############################################################################
SUBROUTINE aed_tracer_get_conserved_quantities(self,_FABM_ARGS_GET_CONSERVED_QUANTITIES_)
!-------------------------------------------------------------------------------
! Get the total of conserved quantities (currently only tracer)
!-------------------------------------------------------------------------------
!ARGUMENTS
   _CLASS_ (type_aed_tracer),INTENT(in) :: self
   _DECLARE_FABM_ARGS_GET_CONSERVED_QUANTITIES_
!
!LOCALS
!  REALTYPE :: ss
!  INTEGER  :: i
!
!-------------------------------------------------------------------------------
!BEGIN
   ! Enter spatial loops (if any)
   _FABM_LOOP_BEGIN_

!  DO i,ubound(self%id_ss,1)
      ! Retrieve current (local) state variable values.
!     _GET_STATE_(self%id_ss(i),ss) ! tracer

      ! Total nutrient is simply the sum of all variables.
!     _SET_CONSERVED_QUANTITY_(self%id_ss(i),ss)
!  ENDDO

   ! Leave spatial loops (if any)
   _FABM_LOOP_END_

END SUBROUTINE aed_tracer_get_conserved_quantities
!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


END MODULE aed_tracer
#endif
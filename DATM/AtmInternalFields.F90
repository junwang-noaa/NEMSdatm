module AtmInternalFields

#include "LocalDefs.F90"

  use ESMF

  implicit none

  private

  !from model_configure
                       integer, public :: iatm,jatm,nfhout
       real(kind=ESMF_KIND_R8), public :: dt_atmos 
  character(len=ESMF_MAXSTR),   public :: filename_base 
  character(len=ESMF_MAXSTR),   public :: cdate0 
  character(len=ESMF_MAXSTR),   public :: dirpath = 'DATM_INPUT/'

  ! the forward and backward timestamps
     real(kind=ESMF_KIND_R8), public :: hfwd, hbak

  ! Set the index type once and for all
  ! Setting the coords and mask values from file assume that the indexing
  ! is global
  type(ESMF_Index_Flag), public :: AtmIndexType = ESMF_INDEX_GLOBAL

  ! Here, the standard_name is used for field connections w/in NUOPC
  ! the field_name is the name of the field internal to the Atm Model
  ! and the file_varname is the name of the variable in the source file
  type, public :: AtmField_Definition
    character(len=64)                                :: standard_name
    character(len=12)                                :: field_name
    character(len=12)                                :: file_varname
    character(len=12)                                :: unit_name
    character(len=10)                                :: staggertype
              logical                                :: isPresent
    real(kind=ESMF_KIND_R8), dimension(:,:), pointer :: farrayPtr     => null()
    real(kind=ESMF_KIND_R4), dimension(:,:), pointer :: farrayPtr_bak => null()
    real(kind=ESMF_KIND_R4), dimension(:,:), pointer :: farrayPtr_fwd => null()
  end type AtmField_Definition

  ! Field Bundles for Atm model used for time-interpolation of forcing
  type(ESMF_FieldBundle), public :: AtmBundleFwd
  type(ESMF_FieldBundle), public :: AtmBundleBak

  integer, parameter, public :: AtmFieldCount =  6  & !height lowest
                                              +  3  & !swd,lwd,lwup
                                              +  4  & !momentum,sens,lat
                                              +  4  & !vis,ir,dir,dif
                                              +  3    !ps,prec

  type(AtmField_Definition), public :: AtmBundleFields(AtmFieldCount)

  integer, public   :: lPet, petCnt
  ! a diagnostic point to print at
  integer, public   :: iprnt, jprnt

  ! called by AtmInit
  public :: AtmBundleSetUp

  !-----------------------------------------------------------------------------
  ! grid associated stagger_center lats,lons,mask
  ! coords are defined 2dim here, which makes writing with ESMF_ArrayWrite easy
  !-----------------------------------------------------------------------------

  real(kind=ESMF_KIND_R8), public, pointer :: atmlonc(:,:)
  real(kind=ESMF_KIND_R8), public, pointer :: atmlatc(:,:)

  ! stagger_corner lats,lons
  real(kind=ESMF_KIND_R8), public, pointer :: atmlonq(:,:)
  real(kind=ESMF_KIND_R8), public, pointer :: atmlatq(:,:)

  contains

  subroutine AtmBundleSetUp

  type(ESMF_Config)       ::  cfdata

  integer :: ii,nfields,rc
  logical :: lvalue

  character(len=ESMF_MAXSTR) :: msgString
  
  ! default values
  AtmBundleFields(:)%staggertype = 'center'
  ! field availability will be set using data_table.IN
  !AtmBundleFields(:)%isPresent   = .true.

    ii = 0
  !-----------------------------------------------------------------------------
  ! the same list of standard_name fields as in ExportState
  !-----------------------------------------------------------------------------

    ii = ii + 1
    AtmBundleFields(ii)%standard_name = 'mean_zonal_moment_flx'
    AtmBundleFields(ii)%field_name    = 'Dusfc'
    AtmBundleFields(ii)%file_varname  = 'dusfc'
    AtmBundleFields(ii)%unit_name     = 'N/m2'
    AtmBundleFields(ii)%farrayPtr_bak => null()
    AtmBundleFields(ii)%farrayPtr_fwd => null()

    ii = ii + 1
    AtmBundleFields(ii)%standard_name = 'mean_merid_moment_flx'
    AtmBundleFields(ii)%field_name    = 'Dvsfc'
    AtmBundleFields(ii)%file_varname  = 'dvsfc'
    AtmBundleFields(ii)%unit_name     = 'N/m2'
    AtmBundleFields(ii)%farrayPtr_bak => null()
    AtmBundleFields(ii)%farrayPtr_fwd => null()

  !-----------------------------------------------------------------------------
  !
  !-----------------------------------------------------------------------------

    ii = ii + 1
    AtmBundleFields(ii)%standard_name = 'inst_height_lowest'
    AtmBundleFields(ii)%field_name    = 'Zlowest'
    AtmBundleFields(ii)%file_varname  = 'hgt_hyblev1'
    AtmBundleFields(ii)%unit_name     = 'K'
    AtmBundleFields(ii)%farrayPtr_bak => null()
    AtmBundleFields(ii)%farrayPtr_fwd => null()

    ii = ii + 1
    AtmBundleFields(ii)%standard_name = 'inst_temp_height_lowest'
    AtmBundleFields(ii)%field_name    = 'Tlowest'
    AtmBundleFields(ii)%file_varname  = 'tmp_hyblev1'
    AtmBundleFields(ii)%unit_name     = 'K'
    AtmBundleFields(ii)%farrayPtr_bak => null()
    AtmBundleFields(ii)%farrayPtr_fwd => null()

    ii = ii + 1
    AtmBundleFields(ii)%standard_name = 'inst_spec_humid_height_lowest'
    AtmBundleFields(ii)%field_name    = 'Qlowest'
    AtmBundleFields(ii)%file_varname  = 'spfh_hyblev1'
    AtmBundleFields(ii)%unit_name     = 'kg/kg'
    AtmBundleFields(ii)%farrayPtr_bak => null()
    AtmBundleFields(ii)%farrayPtr_fwd => null()

    ii = ii + 1
    AtmBundleFields(ii)%standard_name = 'inst_zonal_wind_height_lowest'
    AtmBundleFields(ii)%field_name    = 'Ulowest'
    AtmBundleFields(ii)%file_varname  = 'ugrd_hyblev1'
    AtmBundleFields(ii)%unit_name     = 'm/s'
    AtmBundleFields(ii)%farrayPtr_bak => null()
    AtmBundleFields(ii)%farrayPtr_fwd => null()

    ii = ii + 1
    AtmBundleFields(ii)%standard_name = 'inst_merid_wind_height_lowest'
    AtmBundleFields(ii)%field_name    = 'Vlowest'
    AtmBundleFields(ii)%file_varname  = 'vgrd_hyblev1'
    AtmBundleFields(ii)%unit_name     = 'm/s'
    AtmBundleFields(ii)%farrayPtr_bak => null()
    AtmBundleFields(ii)%farrayPtr_fwd => null()

    ii = ii + 1
    AtmBundleFields(ii)%standard_name = 'inst_pres_height_lowest'
    AtmBundleFields(ii)%field_name    = 'Plowest'
    AtmBundleFields(ii)%file_varname  = 'pres_hyblev1'
    AtmBundleFields(ii)%unit_name     = 'Pa'
    AtmBundleFields(ii)%farrayPtr_bak => null()
    AtmBundleFields(ii)%farrayPtr_fwd => null()

  !-----------------------------------------------------------------------------
  !
  !-----------------------------------------------------------------------------

    ii = ii + 1
    AtmBundleFields(ii)%standard_name = 'mean_down_sw_flx'
    AtmBundleFields(ii)%field_name    = 'Dswrf'
    AtmBundleFields(ii)%file_varname  = 'DSWRF'
    AtmBundleFields(ii)%unit_name     = 'W/m2'
    AtmBundleFields(ii)%farrayPtr_bak => null()
    AtmBundleFields(ii)%farrayPtr_fwd => null()

    ii = ii + 1
    AtmBundleFields(ii)%standard_name = 'mean_down_lw_flx'
    AtmBundleFields(ii)%field_name    = 'Dlwrf'
    AtmBundleFields(ii)%file_varname  = 'DLWRF'
    AtmBundleFields(ii)%unit_name     = 'W/m2'
    AtmBundleFields(ii)%farrayPtr_bak => null()
    AtmBundleFields(ii)%farrayPtr_fwd => null()

    ii = ii + 1
    AtmBundleFields(ii)%standard_name = 'mean_up_lw_flx'
    AtmBundleFields(ii)%field_name    = 'Ulwrf'
    AtmBundleFields(ii)%file_varname  = 'ULWRF'
    AtmBundleFields(ii)%unit_name     = 'W/m2'
    AtmBundleFields(ii)%farrayPtr_bak => null()
    AtmBundleFields(ii)%farrayPtr_fwd => null()

  !-----------------------------------------------------------------------------
  !
  !-----------------------------------------------------------------------------

    ii = ii + 1
    AtmBundleFields(ii)%standard_name = 'mean_sensi_heat_flx'
    AtmBundleFields(ii)%field_name    = 'Shtfl'
    AtmBundleFields(ii)%file_varname  = 'shtfl_ave'
    AtmBundleFields(ii)%unit_name     = 'W/m2'
    AtmBundleFields(ii)%farrayPtr_bak => null()
    AtmBundleFields(ii)%farrayPtr_fwd => null()

    ii = ii + 1
    AtmBundleFields(ii)%standard_name = 'mean_laten_heat_flx'
    AtmBundleFields(ii)%field_name    = 'Lhtfl'
    AtmBundleFields(ii)%file_varname  = 'lhtfl_ave'
    AtmBundleFields(ii)%unit_name     = 'W/m2'
    AtmBundleFields(ii)%farrayPtr_bak => null()
    AtmBundleFields(ii)%farrayPtr_fwd => null()

  !-----------------------------------------------------------------------------
  !
  !-----------------------------------------------------------------------------

    ii = ii + 1
    AtmBundleFields(ii)%standard_name = 'mean_down_sw_vis_dir_flx'
    AtmBundleFields(ii)%field_name    = 'Vbdsf'
    AtmBundleFields(ii)%file_varname  = 'vbdsf_ave'
    AtmBundleFields(ii)%unit_name     = 'W/m2'
    AtmBundleFields(ii)%farrayPtr_bak => null()
    AtmBundleFields(ii)%farrayPtr_fwd => null()

    ii = ii + 1
    AtmBundleFields(ii)%standard_name = 'mean_down_sw_vis_dif_flx'
    AtmBundleFields(ii)%field_name    = 'Vddsf'
    AtmBundleFields(ii)%file_varname  = 'vddsf_ave'
    AtmBundleFields(ii)%unit_name     = 'W/m2'
    AtmBundleFields(ii)%farrayPtr_bak => null()
    AtmBundleFields(ii)%farrayPtr_fwd => null()

    ii = ii + 1
    AtmBundleFields(ii)%standard_name = 'mean_down_sw_ir_dir_flx'
    AtmBundleFields(ii)%field_name    = 'Nbdsf'
    AtmBundleFields(ii)%file_varname  = 'nbdsf_ave'
    AtmBundleFields(ii)%unit_name     = 'W/m2'
    AtmBundleFields(ii)%farrayPtr_bak => null()
    AtmBundleFields(ii)%farrayPtr_fwd => null()
    
    ii = ii + 1
    AtmBundleFields(ii)%standard_name = 'mean_down_sw_ir_dif_flx'
    AtmBundleFields(ii)%field_name    = 'Nddsf'
    AtmBundleFields(ii)%file_varname  = 'nddsf_ave'
    AtmBundleFields(ii)%unit_name     = 'W/m2'
    AtmBundleFields(ii)%farrayPtr_bak => null()
    AtmBundleFields(ii)%farrayPtr_fwd => null()

  !-----------------------------------------------------------------------------
  !
  !-----------------------------------------------------------------------------

    ii = ii + 1
    AtmBundleFields(ii)%standard_name = 'inst_pres_height_surface'
    AtmBundleFields(ii)%field_name    = 'Psurf'
    AtmBundleFields(ii)%file_varname  = 'psurf'
    AtmBundleFields(ii)%unit_name     = 'Pa'
    AtmBundleFields(ii)%farrayPtr_bak => null()
    AtmBundleFields(ii)%farrayPtr_fwd => null()

    ii = ii + 1
    AtmBundleFields(ii)%standard_name = 'mean_prec_rate'
    AtmBundleFields(ii)%field_name    = 'Prate'
    AtmBundleFields(ii)%file_varname  = 'precp'
    AtmBundleFields(ii)%unit_name     = 'kg/m2/s'
    AtmBundleFields(ii)%farrayPtr_bak => null()
    AtmBundleFields(ii)%farrayPtr_fwd => null()

    ii = ii + 1
    AtmBundleFields(ii)%standard_name = 'mean_fprec_rate'
    AtmBundleFields(ii)%field_name    = 'Snwrate'
    AtmBundleFields(ii)%file_varname  = 'fprecp'
    AtmBundleFields(ii)%unit_name     = 'kg/m2/s'
    AtmBundleFields(ii)%farrayPtr_bak => null()
    AtmBundleFields(ii)%farrayPtr_fwd => null()

    if(ii .ne. size(AtmBundleFields)) &
    call ESMF_LogWrite("ERROR: check # AtmBundleFields", ESMF_LOGMSG_INFO)

  !-----------------------------------------------------------------------------
  ! get the input availability from the datm_data_table 
  !-----------------------------------------------------------------------------

    cfdata=ESMF_ConfigCreate(rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out

    call ESMF_ConfigLoadFile(config=cfdata ,filename='datm_data_table' ,rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out

    nfields = size(AtmBundleFields)
    do ii = 1,nfields
     call ESMF_ConfigGetAttribute(config=cfdata, &
                                  value=lvalue, &
                                  label=trim(AtmBundleFields(ii)%standard_name),rc=rc)
     if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
       line=__LINE__, &
       file=__FILE__)) &
       return  ! bail out
     AtmBundleFields(ii)%isPresent=lvalue
    enddo

  !-----------------------------------------------------------------------------
  ! check
  !-----------------------------------------------------------------------------
  
    call ESMF_LogWrite('AtmBundleFields : ', ESMF_LOGMSG_INFO)
    do ii = 1,size(AtmBundleFields)
     write(msgString,'(i6,2(a2,a14),a2,a30,a2,l6)')ii, &
                                              '  ',trim(AtmBundleFields(ii)%file_varname), &
                                              '  ',trim(AtmBundleFields(ii)%field_name), &
                                              '  ',trim(AtmBundleFields(ii)%standard_name), &
                                              '  ',AtmBundleFields(ii)%isPresent
     call ESMF_LogWrite(trim(msgString), ESMF_LOGMSG_INFO)
    enddo

  end subroutine AtmBundleSetUp
end module AtmInternalFields

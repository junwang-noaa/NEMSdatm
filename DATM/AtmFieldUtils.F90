module AtmFieldUtils
  !-----------------------------------------------------------------------------
  ! Field utility module
  !-----------------------------------------------------------------------------

  use ESMF
  use NUOPC

  use AtmInternalFields, only : AtmField_Definition
  use AtmInternalFields, only : AtmIndexType
  use AtmExportFields,   only : AtmFieldsToExport

  implicit none

  private

  ! called by Cap
  public :: AtmFieldsAdvertise, AtmFieldsRealize
  public :: AtmFieldCheck
  public :: AtmFieldDump

  ! called by AtmInit, AtmRun
  public :: AtmForceFwd2Bak, AtmBundleCheck
  public :: AtmBundleIntp

  contains

  !-----------------------------------------------------------------------------

  subroutine AtmFieldsAdvertise(state, field_defs, rc)

    type(ESMF_State),          intent(inout)  :: state
    type(AtmField_Definition), intent(inout)  :: field_defs(:)
    integer,                   intent(  out)  :: rc

  ! Local items
    integer :: ii, nfields

    rc = ESMF_SUCCESS

  ! number of items
    nfields = size(field_defs)
  !print *,'found nfields = ',nfields,' to advertise ',field_defs%field_name

    do ii = 1,nfields
      call NUOPC_Advertise(state, &
        StandardName=trim(field_defs(ii)%standard_name), &
                name=trim(field_defs(ii)%field_name), &
                  rc=rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
        line=__LINE__, &
        file=__FILE__)) &
        return  ! bail out
    enddo

  end subroutine AtmFieldsAdvertise

  !-----------------------------------------------------------------------------

  subroutine AtmFieldsRealize(state, grid, field_defs, tag, rc)

    type(ESMF_State),          intent(inout)  :: state
    type(ESMF_Grid),           intent(in   )  :: grid
    type(AtmField_Definition), intent(inout)  :: field_defs(:)
    character(len=*),          intent(in   )  :: tag
    integer,                   intent(out  )  :: rc

    type(ESMF_ArraySpec)       :: arrayspecR8
    type(ESMF_Field)           :: field
    type(ESMF_StaggerLoc)      :: staggerloc
    character(len=ESMF_MAXSTR) :: msgString

    integer                    :: ii,nfields
    logical                    :: connected

    rc = ESMF_SUCCESS
    call ESMF_LogWrite("User routine AtmFieldsRealize "//trim(tag)//" started", ESMF_LOGMSG_INFO)
                  
    nfields=size(field_defs)
    !print *,'found nfields = ',nfields,' to realize ',field_defs%field_name

    call ESMF_ArraySpecSet(arrayspecR8, rank=2, typekind=ESMF_TYPEKIND_R8, rc=rc)

    do  ii = 1,nfields
     ! they should all be center ;-)
     if(field_defs(ii)%staggertype == 'center')staggerloc = ESMF_STAGGERLOC_CENTER

      field = ESMF_FieldCreate(grid=grid, &
                               arrayspec=arrayspecR8, &
                               indexflag=AtmIndexType, &
                               staggerloc=staggerloc, &
                               name=trim(field_defs(ii)%field_name), rc=rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
        line=__LINE__, &
        file=__FILE__)) &
        return  ! bail out

      connected = NUOPC_IsConnected(state, fieldName=trim(field_defs(ii)%field_name), rc=rc)
      if(     connected)write(msgString,*)'Field '//trim(field_defs(ii)%field_name)//' is connected '
      if(.not.connected)write(msgString,*)'Field '//trim(field_defs(ii)%field_name)//' is NOT connected '
      call ESMF_LogWrite(trim(msgString), ESMF_LOGMSG_INFO, rc=rc)

      call NUOPC_Realize(state, field=field, rc=rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
        line=__LINE__, &
        file=__FILE__)) &
        return  ! bail out

      call ESMF_FieldGet(field, farrayPtr=field_defs(ii)%farrayPtr, rc=rc)
      if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
        line=__LINE__, &
        file=__FILE__)) &
        return  ! bail out

      field_defs(ii)%farrayPtr = 0.0
      !do j = lbound(field_defs(ii)%farrayPtr,2),ubound(field_defs(ii)%farrayPtr,2)
      ! do i = lbound(field_defs(ii)%farrayPtr,1),ubound(field_defs(ii)%farrayPtr,1)
      !  field_defs(ii)%farrayPtr(i,j) = 0.0
      ! enddo
      !enddo
    enddo

    call ESMF_LogWrite("User routine AtmFieldsRealize "//trim(tag)//" finished", ESMF_LOGMSG_INFO)
  end subroutine AtmFieldsRealize

  !-------------------------------------------------------------------------------------

  subroutine AtmFieldCheck(importState, exportState, tag, rc)

  use AtmInternalFields, only : iprnt, jprnt

  type(ESMF_State)              :: importState, exportState
  character(len=*), intent( in) :: tag
           integer, intent(out) :: rc

  ! Local variables
  type(ESMF_Field)           :: field
  character(len=ESMF_MAXSTR) :: msgString

  integer :: ii, nfields, ijloc(2)

  ! Initialize return code
  rc = ESMF_SUCCESS

  !-----------------------------------------------------------------------------
  ! Check Fields
  !-----------------------------------------------------------------------------

  nfields = size(AtmFieldsToExport)
  do ii = 1,nfields
    call ESMF_StateGet(exportState, &
                       itemName=trim(AtmFieldsToExport(ii)%field_name), &
                       field=field, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out

    call ESMF_FieldGet(field, farrayPtr=AtmFieldsToExport(ii)%farrayPtr, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out

    write (msgString,*)trim(tag), ' AtmFieldsToExport ',&
                       trim(AtmFieldsToExport(ii)%field_name),'  ',&
                       real(AtmFieldsToExport(ii)%farrayPtr(iprnt,jprnt),4)
    call ESMF_LogWrite(trim(msgString), ESMF_LOGMSG_INFO, rc=rc)

    !ijloc = maxloc(abs(AtmFieldsToExport(ii)%farrayPtr))
    !write (msgString,*)trim(tag), ' AtmFieldsToExport ',&
    !                   trim(AtmFieldsToExport(ii)%field_name),' maxloc ',&
    !                   ijloc(1),ijloc(2),&
    !                   real(AtmFieldsToExport(ii)%farrayPtr(ijloc(1),ijloc(2)),4)
    !call ESMF_LogWrite(trim(msgString), ESMF_LOGMSG_INFO, rc=rc)

    write (msgString,*)trim(tag), ' AtmFieldsToExport ',&
                       trim(AtmFieldsToExport(ii)%field_name),' min,max,sum ',&
                       minval(real(AtmFieldsToExport(ii)%farrayPtr,4)),&
                       maxval(real(AtmFieldsToExport(ii)%farrayPtr,4)),&
                          sum(real(AtmFieldsToExport(ii)%farrayPtr,4))
    call ESMF_LogWrite(trim(msgString), ESMF_LOGMSG_INFO, rc=rc)
   enddo

  end subroutine AtmFieldCheck

  !-----------------------------------------------------------------------------

  subroutine AtmFieldDump(importState, exportState, tag, iicnt, rc)

  type(ESMF_State)              :: importState
  type(ESMF_State)              :: exportState
  character(len=*), intent( in) :: tag
           integer, intent( in) :: iicnt
           integer, intent(out) :: rc

  ! Local variables
  type(ESMF_Field)                 :: field

  integer :: ii,nfields
  character(len=ESMF_MAXSTR) :: varname
  character(len=ESMF_MAXSTR) :: filename
  character(len=ESMF_MAXSTR) :: msgString

  ! Initialize return code
  rc = ESMF_SUCCESS

  call ESMF_LogWrite("User routine AtmFieldDump started", ESMF_LOGMSG_INFO)

  ! Atm variables in exportState
  nfields = size(AtmFieldsToExport)
  do ii = 1,nfields
   call ESMF_StateGet(exportState, &
                      itemName = trim(AtmFieldsToExport(ii)%field_name), &
                      field=field,rc=rc)
    varname = trim(AtmFieldsToExport(ii)%standard_name)

    if(trim(tag) .eq. 'before AtmRun')filename = 'field_atm_exportb_'//trim(varname)//'.nc'
    if(trim(tag) .eq.  'after AtmRun')filename = 'field_atm_exporta_'//trim(varname)//'.nc'

    !if(trim(varname) .eq. 'inst_pres_height_lowest')then
    write(msgString, '(a,i6)')'Writing exportState field '//trim(varname)//' to ' &
                            //trim(filename)//' iicnt = ',iicnt
    call ESMF_LogWrite(trim(msgString), ESMF_LOGMSG_INFO, rc=rc)

    call ESMF_FieldWrite(field, &
                         fileName=filename, &
                         variableName=varname, &
                         overwrite=.true., &
                         timeslice=iicnt,rc=rc)
    !endif
    !if(iicnt .eq. 1)then
    ! write(msgString, *)'Writing exportState field ',trim(varname),' to ',trim(filename)
    ! call ESMF_LogWrite(trim(msgString), ESMF_LOGMSG_INFO, rc=rc)
    !endif
  enddo
  call ESMF_LogWrite("User routine AtmFieldDump finished", ESMF_LOGMSG_INFO)

  end subroutine AtmFieldDump

  !-----------------------------------------------------------------------------

  subroutine AtmForceFwd2Bak(rc)

  use AtmInternalFields, only : hfwd, hbak
  use AtmInternalFields, only : AtmBundleFields
  use AtmInternalFields, only : AtmBundleFwd, AtmBundleBak
  
  integer, intent(out) :: rc

  ! Local variables
  integer :: ii,nfields

  type(ESMF_Field)           :: fieldfwd, fieldbak
  character(len=ESMF_MAXSTR) :: fnamefwd, fnamebak
  character(len=ESMF_MAXSTR) :: msgString

  ! Initialize return code
  rc = ESMF_SUCCESS

  call ESMF_LogWrite("User routine AtmForceFwd2Bak started", ESMF_LOGMSG_INFO)

  call ESMF_FieldBundleGet(AtmBundleFwd,fieldCount=nfields,rc=rc)
  do ii = 1,nfields
    fnamefwd = trim(AtmBundleFields(ii)%field_name)//'_fwd'
    fnamebak = trim(AtmBundleFields(ii)%field_name)//'_bak'

    call ESMF_FieldBundleGet(AtmBundleFwd, & 
                             fieldName=trim(fnamefwd), &
                             field=fieldfwd,rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out

    call ESMF_FieldBundleGet(AtmBundleBak, &
                             fieldName=trim(fnamebak), &
                             field=fieldbak,rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out

    ! copy the fwd fields to the bak fields
    ! this function is defined (fieldout,fieldin)
    call ESMF_FieldCopy(fieldbak, fieldfwd, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out
  enddo

  call ESMF_LogWrite("User routine AtmForceFwd2Bak finished", ESMF_LOGMSG_INFO)

  end subroutine AtmForceFwd2Bak

  !-----------------------------------------------------------------------------

  subroutine AtmBundleCheck(tag,rc)

  use AtmInternalFields, only : iprnt, jprnt
  use AtmInternalFields, only : AtmBundleFields
  use AtmInternalFields, only : AtmBundleFwd, AtmBundleBak
  
    character(len=*), intent(in ) :: tag
             integer, intent(out) :: rc

  ! Local variables
  integer :: ii,nfields

  type(ESMF_Field)           :: fieldfwd, fieldbak
  character(len=ESMF_MAXSTR) :: fnamefwd, fnamebak
  character(len=ESMF_MAXSTR) :: msgString

  ! Initialize return code
  rc = ESMF_SUCCESS

  call ESMF_LogWrite("User routine AtmBundleCheck "//trim(tag)//" started", ESMF_LOGMSG_INFO)

  call ESMF_FieldBundleGet(AtmBundleFwd,fieldCount=nfields,rc=rc)
  do ii = 1,nfields
    fnamefwd = trim(AtmBundleFields(ii)%field_name)//'_fwd'
    fnamebak = trim(AtmBundleFields(ii)%field_name)//'_bak'

    call ESMF_FieldBundleGet(AtmBundleBak, & 
                             fieldName=trim(fnamebak), &
                             field=fieldbak,rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out
  
    call ESMF_FieldGet(fieldbak,farrayPtr=AtmBundleFields(ii)%farrayPtr_bak,rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out

    call ESMF_FieldBundleGet(AtmBundleFwd, &
                             fieldName=trim(fnamefwd), &
                             field=fieldfwd,rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out

    call ESMF_FieldGet(fieldfwd,farrayPtr=AtmBundleFields(ii)%farrayPtr_fwd,rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out
 
     write(msgString,'(i4,2(a2,a12),2f14.5)')ii,'  ',trim(fnamebak), &
                                                '  ',trim(fnamefwd), &
                                AtmBundleFields(ii)%farrayPtr_bak(iprnt,jprnt), &
                                AtmBundleFields(ii)%farrayPtr_fwd(iprnt,jprnt)
    !                            AtmBundleFields(ii)%farrayPtr_bak(152,60), &
    !                            AtmBundleFields(ii)%farrayPtr_fwd(152,60)
     call ESMF_LogWrite(trim(msgString), ESMF_LOGMSG_INFO, rc=rc)
  enddo

  call ESMF_LogWrite("User routine AtmBundleCheck finished", ESMF_LOGMSG_INFO)

  end subroutine AtmBundleCheck

  !-----------------------------------------------------------------------------

  subroutine AtmBundleIntp(gcomp, importState, exportState, externalClock, hour, rc)

  use AtmExportFields
  
  use AtmInternalFields, only : hfwd,hbak
  use AtmInternalFields, only : iprnt,jprnt
  use AtmInternalFields, only : AtmBundleFields
  use AtmInternalFields, only : AtmBundleFwd, AtmBundleBak

  type(ESMF_GridComp)        :: gcomp
  type(ESMF_State)           :: importState
  type(ESMF_State)           :: exportState
  type(ESMF_Clock)           :: externalClock

  real(ESMF_KIND_R8), intent(in) :: hour
            integer, intent(out) :: rc

  ! Local variables
  integer :: ii,nfields,ijloc(2)

  type(ESMF_Field)            :: fieldbak, field, fieldfwd
  character(len=ESMF_MAXSTR)  :: fnamefwd, fnamebak
  character(len=ESMF_MAXSTR)  :: msgString
  real(kind=ESMF_KIND_R8)     :: wf, wb, wtot

  ! Initialize return code
  rc = ESMF_SUCCESS

  call ESMF_LogWrite("User routine AtmBundleIntp  started", ESMF_LOGMSG_INFO)

  nfields = size(AtmFieldsToExport)
  do ii = 1,nfields
    call ESMF_StateGet(exportState, &
                       itemName=trim(AtmFieldsToExport(ii)%field_name), &
                       field=field, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out

    call ESMF_FieldGet(field, farrayPtr=AtmFieldsToExport(ii)%farrayPtr, rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out

    ! get the corresponding _fwd and _bak fields
    fnamefwd = trim(AtmFieldsToExport(ii)%field_name)//'_fwd'
    fnamebak = trim(AtmFieldsToExport(ii)%field_name)//'_bak'

    call ESMF_FieldBundleGet(AtmBundleFwd, & 
                             fieldName=trim(fnamefwd), &
                             field=fieldfwd,rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out

    call ESMF_FieldGet(fieldfwd,farrayPtr=AtmBundleFields(ii)%farrayPtr_fwd,rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out

    call ESMF_FieldBundleGet(AtmBundleBak, &
                             fieldName=trim(fnamebak), &
                             field=fieldbak,rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out

    call ESMF_FieldGet(fieldbak,farrayPtr=AtmBundleFields(ii)%farrayPtr_bak,rc=rc)
    if (ESMF_LogFoundError(rcToCheck=rc, msg=ESMF_LOGERR_PASSTHRU, &
      line=__LINE__, &
      file=__FILE__)) &
      return  ! bail out

   !special case at initialization
   if(int(hour,4) .eq. 0)then
    AtmFieldsToExport(ii)%farrayPtr = real(AtmBundleFields(ii)%farrayPtr_bak,8)
   else
    ! interpolate in time
      wf = hfwd - hour
      wb = hour - hbak
    wtot = wf+wb
    AtmFieldsToExport(ii)%farrayPtr = real((wf*AtmBundleFields(ii)%farrayPtr_bak &
                                         +  wb*AtmBundleFields(ii)%farrayPtr_fwd)/wtot,8)
   endif !hour=0

    !ijloc = maxloc(abs(AtmFieldsToExport(ii)%farrayPtr))
    !write (msgString,*)' AtmIntp ',&
    !                   trim(AtmFieldsToExport(ii)%field_name),' maxloc ',&
    !                   ijloc(1),ijloc(2),&
    !                   real(AtmFieldsToExport(ii)%farrayPtr(ijloc(1),ijloc(2)),4),&
    !                   real(AtmBundleFields(ii)%farrayPtr_bak(ijloc(1),ijloc(2)),4),&
    !                   real(AtmBundleFields(ii)%farrayPtr_fwd(ijloc(1),ijloc(2)),4)
    !call ESMF_LogWrite(trim(msgString), ESMF_LOGMSG_INFO, rc=rc)

    write (msgString,*)' AtmIntp ',&
                       trim(AtmFieldsToExport(ii)%field_name),&
                       real(AtmFieldsToExport(ii)%farrayPtr(iprnt,jprnt),4),&
                       real(AtmBundleFields(ii)%farrayPtr_bak(iprnt,jprnt),4),&
                       real(AtmBundleFields(ii)%farrayPtr_fwd(iprnt,jprnt),4)
    call ESMF_LogWrite(trim(msgString), ESMF_LOGMSG_INFO, rc=rc)

    !write (msgString,*)' AtmFieldsToExport ',&
    !                   trim(AtmFieldsToExport(ii)%field_name),' min,max,sum ',&
    !                   minval(real(AtmFieldsToExport(ii)%farrayPtr,4)),&
    !                   maxval(real(AtmFieldsToExport(ii)%farrayPtr,4)),&
    !                      sum(real(AtmFieldsToExport(ii)%farrayPtr,4))
    ! call ESMF_LogWrite(trim(msgString), ESMF_LOGMSG_INFO, rc=rc)
   enddo

  call ESMF_LogWrite("User routine AtmBundleIntp finished", ESMF_LOGMSG_INFO)
  end subroutine AtmBundleIntp

end module AtmFieldUtils

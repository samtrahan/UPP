  module CTLBLK_mod
!-----------------------------------------------------------------------
! module: CTLBLK
!
! ABSTRACT: 
! this module is replacing the CTLBLK.comm, all the comm block is 
!    removed.
! Revision Log:
!  2011-02    Jun Wang  - ADD variables for grib2
!  2011-12-14 SARAH LU  - ADD AER FILENAME
!  2011-12-23 SARAH LU  - ADD NBIN FOR DU, SS, OC, BC, SU
!  2021-09-30 JESSE MENG - 2D DECOMPOSITION
!  2022-09-22 Li(Kate) Zhang - Add option for NASA GOCART as "nasa_on", add NBIN for NO3 and NH4
!  2022-11-08 Kai Wang  - Replace aqfcmaq_on with aqf_on
!  2023-01-24 Sam Trahan - IFI flight levels, runtime of IFI, and record of the bucket time
!  2023-03-21 Jesse Meng - Add slrutah_on option to use U Utah SLR
!  2023-04-04 Li(Kate Zhang) Add namelist optoin for CCPP-Chem (UFS-Chem) 
!         and 2D diag. output (d2d_chem) for GEFS-Aerosols and CCPP-Chem model.
!  2023-04-17 Eric James - Adding 160 and 320 m above ground to HTFD for RRFS output.
!-----------------------------------------------------------------------
!
  implicit none
!
  type field_info
!> ifld @memberof CTLBLK_mod
    integer ifld
!> lvl @memberof CTLBLK_mod
    integer lvl
!> lvl1 @memberof CTLBLK_mod
!> lvl2 @memberof CTLBLK_mod
    integer lvl1,lvl2
!> ntrange @memberof CTLBLK_mod
    integer ntrange
!> tinvstat @memberof CTLBLK_mod
    integer tinvstat
  end type
  integer, parameter :: komax=70
  integer, parameter :: LSMDEF=46             ! default number of p levels
  integer,PARAMETER  :: NFD=20,NBND=6
  REAL,  PARAMETER   :: QMIN = 1.E-15
!
  integer :: novegtype ! max number of veg type
!
  character(len=256) :: fileName,fileNameFlux,fileNameD3D,fileNameAER, &
                        fileNameFlat
  character(len=19)  :: DateStr
  character(len=4)   :: MODELNAME, SUBMODELNAME
  character(len=8)   :: FULLMODELNAME
  character(len=20)  :: IOFORM
  character(len=4)   :: VTIMEUNITS
!      
  character(5) :: grib
  type(field_info),allocatable :: fld_info(:)
  integer :: cfld,ntlfld,npset
  real*8 :: gdsdegr
  real,allocatable :: datapd(:,:,:)
!
  logical :: gocart_on, gccpp_on, nasa_on, d3d_on, hyb_sigp, rdaod, d2d_chem, aqf_on, slrutah_on
  logical :: SIGMA,RUN,FIRST,RESTRT
  logical :: global
  logical :: SMFLAG
  integer :: IDAT(5),IHRST, NFCST,NBC,LIST,IOUT,IFHR,NTSTM,            &
             NDDAMP,NPREC,IDTAD,NBOCO,NSHDE,NCP,IMDLTY,NPHS,           &
             NRADS,NRADL,IMIN,ifmin,DataHandle,imp_physics,            &
             icu_physics,iSF_SURFACE_PHYSICS,ISEC,icount_calmict,      &
             ivegsrc
  real :: DT,SDAT(3),AVRAIN,AVCNVC,DTQ2,PT,PDTOP,                      &
          SPL(komax),ALSL(komax),PREC_ACC_DT,PT_TBL,PREC_ACC_DT1,spval
! real :: SPVAL=9.9e10                                     ! Moorthi
!
  integer :: NUM_PROCS,ME,JSTA,JEND,ISTA,IEND,                         &
               JSTA_M,JEND_M, JSTA_M2,JEND_M2,                         &
               ISTA_M,IEND_M,ISTA_M2,IEND_M2,                          &
             IUP,IDN,ICNT(0:1023),IDSP(0:1023),  ICNT2(0:1023),IDSP2(0:1023),                      & 
             JSTA_2L, JEND_2U,JVEND_2U,                                &
             ISTA_2L, IEND_2U,IVEND_2U,                                &
             NUM_SERVERS, MPI_COMM_INTER,    &
             MPI_COMM_COMP, IM,JM,LM,NSOIL,LP1,LM1,IM_JM,              &
             ileft,iright,                                             &
                ileftb,irightb ,                                       & 
             ibsize,ibsum,                                             &
             lsm,lsmp1                                    !comm mpi
        integer, allocatable :: icoords(:,:),ibcoords(:,:)
        real   , allocatable :: rcoords(:,:),rbcoords(:,:)
        real, allocatable :: bufs(:),buff(:)                           
        integer , allocatable :: isxa(:),iexa(:),jsxa(:),jexa(:)       
        integer numx
        integer, allocatable :: ibufs(:)
        real, allocatable :: rbufs(:)
!
  real :: ARDSW, ARDLW, ASRFC, TSRFC,TRDLW,TRDSW,TCLOD,THEAT,          &
          TPREC,TMAXMIN,TD3D                              !comm rad
!
  real PTHRESH ! moved from params because it is defined differently for NAM
!  
  real(kind=8) :: ETAFLD2_tim=0.,ETA2P_tim=0.,SURFCE2_tim=0.,          &
                  CLDRAD_tim=0.,MISCLN_tim=0.,FIXED_tim=0.,            &
                  MDL2SIGMA_tim=0.,READxml_tim=0.,MDL2AGL_tim=0.,      &
                  MDL2STD_tim=0.,MDL2THANDPV_tim=0.,                   &
                  CALRAD_WCLOUD_tim=0.,RUN_IFI_TIM=0.     !comm tim_info
!
  real(kind=8) :: time_output=0., time_e2out=0.           !comm jjt
!
  real :: SPLDEF(LSMDEF) =                                             &
      (/200.,500.,700.,1000.,2000.,3000.                               &
      ,5000.,7000.,7500.,10000.,12500.,15000.,17500.,20000.,22500.     &
      ,25000.,27500.,30000.,32500.,35000.,37500.,40000.,42500.,45000.  &
      ,47500.,50000.,52500.,55000.,57500.,60000.,62500.,65000.         &
      ,67500.,70000.,72500.,75000.,77500.,80000.,82500.,85000.         &
      ,87500.,90000.,92500.,95000.,97500.,100000./)
!
  REAL HTFD(NFD),PETABND(NBND),SIGBND(NBND)

! Add GOCART aerosol specification
  integer, parameter :: nbin_du = 5   		! dust
  integer, parameter :: nbin_ss = 5   		! sea salt
  integer, parameter :: nbin_oc = 2   		! organic carbon
  integer, parameter :: nbin_bc = 2   		! black carbon
  integer, parameter :: nbin_su = 1   		! sulfate
  integer, parameter :: nbin_no3 = 3   		! nitrate
  integer, parameter :: nbin_nh4 = 1   		! NH4
  integer, parameter :: nbin_sm = 1             ! smoke
!
!     SET FD LEVEL HEIGHTS IN GEOPOTENTAL METERS.
      DATA HTFD  / 20.E0,30.E0,40.E0,50.E0,80.E0,100.E0,160.E0,305.E0,320.E0,457.E0,610.E0,   &
           914.E0,1524.E0,1829.E0,2134.E0,2743.E0,3658.E0,4572.E0, &
	   6000.E0,7010.E0/
!
!     SET MIDPOINT "SIGMA" VALUES FOR ETA BOUNDARY LAYERS.
      DATA SIGBND / 0.985,0.955,0.925,0.895,0.865,0.835 /
      DATA PETABND / 15.,45.,75.,105.,135.,165./
!
!     Precipitation bucket time
      real :: ITPREC=-1
!
!     Flight levels in feet, provided by libIFI
      integer :: ifi_nflight = 0
      real, allocatable :: ifi_flight_levels(:) ! units are FEET
!     
!-----------------------------------------------------------------------
  end module CTLBLK_mod

!> @file
!> @brief mdl2std_p() vertical interpolation of model levels to standard atmospheric pressure.
!>
!> Originated from MISCLN.f. This routine interpolate to standard
!> atmospheric pressure, instead of model pressure.
!>
!> ### Program History Log
!> Date | Programmer | Comments
!> -----|------------|---------
!> 2019-09-24 | Y Mao  | Rewritten from MISCLN.f
!> 2020-05-20 | J Meng | CALRH unification with NAM scheme
!> 2020-11-10 | J Meng | Use UPP_PHYSICS Module
!> 2021-03-11 | B Cui  | Change local arrays to dimension (im,jsta:jend)
!> 2021-10-14 | J MENG | 2D DECOMPOSITION
!> 2022-05-25 | Y Mao  | Remove interpolation of VVEL/ABSV/CLWMR
!> 2023-03-14 | Y Mao  | Remove interpolation of RH, remove use CALRH and CALVOR
!>
!> @author Y Mao W/NP22 @date 2019-09-24
!--------------------------------------------------------------------------------------
!> mdl2std_p() vertical interpolation of model levels to standard atmospheric pressure.
!>
      SUBROUTINE MDL2STD_P()

!
      use vrbls3d, only: pint, pmid, zmid
      use vrbls3d, only: t, q, uh, vh, omga, cwm, qqw, qqi, qqr, qqs, qqg
      
      use vrbls3d, only: ICING_GFIP, ICING_GFIS, catedr, mwt, gtg
      use ctlblk_mod, only: grib, cfld, fld_info, datapd, im, jsta, jend, jm, &
                            lm, htfd, spval, nfd, me,&
                            jsta_2l, jend_2u, MODELNAME,&
                            ista, iend, ista_2l, iend_2u
      use rqstfld_mod, only: iget, lvls, iavblfld, lvlsxml
      use grib2_module, only: pset

!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
!
      implicit none

      real, external :: P2H, relabel

      real,dimension(ista_2l:iend_2u,jsta_2l:jend_2u) :: grid1
      real,dimension(ista_2l:iend_2u,jsta_2l:jend_2u) :: EGRID1,EGRID2,EGRID3,EGRID4

!
      integer I,J,ii,jj,L,ITYPE,IFD,ITYPEFDLVL(NFD)

!     Variables introduced to allow FD levels from control file - Y Mao
      integer :: N,NFDCTL
      REAL, allocatable :: HTFDCTL(:)
      integer, allocatable :: ITYPEFDLVLCTL(:)
      real, allocatable :: QIN(:,:,:,:), QFD(:,:,:,:)
      character, allocatable :: QTYPE(:)
      real, allocatable :: VAR3D1(:,:,:), VAR3D2(:,:,:)

      integer, parameter :: NFDMAX=50 ! Max number of fields with the same HTFDCTL
      integer :: IDS(NFDMAX) ! All field IDs with the same HTFDCTL
      integer :: nFDS ! How many fields with the same HTFDCTL in the control file
      integer :: iID ! which field with HTFDCTL
      integer :: N1, N2
!     
!******************************************************************************
!
!     START MDL2STD_P. 
!

!     --------------WAFS block----------------------
!     479 ICSEV
!     481 ICIP
!     476 EDPARM
!     477 CAT
!     478 MWTURB
!     518 HGT
!     519 TMP
!     520 UGRD
!     521 VGRD
      IF(IGET(479)>0 .or. IGET(481)>0 .or. &
         IGET(476)>0 .or. IGET(477)>0 .or. IGET(478)>0 .or. &
         IGET(518)>0 .or. IGET(519)>0 .or. IGET(520)>0 .or. &
         IGET(521)>0) then

!        STEP 1 -- U V (POSSIBLE FOR ABSV) INTERPLOCATION
         IF(IGET(520)>0 .or. IGET(521)>0 ) THEN
!           U/V are always paired, use any for HTFDCTL          
            iID=520
            N = IAVBLFLD(IGET(iID))
            NFDCTL=size(pset%param(N)%level)
            if(allocated(ITYPEFDLVLCTL)) deallocate(ITYPEFDLVLCTL)
            allocate(ITYPEFDLVLCTL(NFDCTL))
            DO IFD = 1,NFDCTL
               ITYPEFDLVLCTL(IFD)=LVLS(IFD,IGET(iID))
            ENDDO
            if(allocated(HTFDCTL)) deallocate(HTFDCTL)
            allocate(HTFDCTL(NFDCTL))
            HTFDCTL=pset%param(N)%level
            DO i = 1, NFDCTL
               HTFDCTL(i)=P2H(HTFDCTL(i)/100.)
            ENDDO
            if(allocated(VAR3D1)) deallocate(VAR3D1)
            if(allocated(VAR3D2)) deallocate(VAR3D2)
            allocate(VAR3D1(ISTA_2L:IEND_2U,JSTA_2L:JEND_2U,NFDCTL))
            allocate(VAR3D2(ISTA_2L:IEND_2U,JSTA_2L:JEND_2U,NFDCTL))
            VAR3D1=SPVAL
            VAR3D2=SPVAL

            call FDLVL_UV(ITYPEFDLVLCTL,NFDCTL,HTFDCTL,VAR3D1,VAR3D2)

            DO IFD = 1,NFDCTL
               ! U
               IF (LVLS(IFD,IGET(520)) > 0) THEN
!$omp parallel do private(i,j)
                  DO J=JSTA,JEND
                  DO I=ISTA,IEND
                     GRID1(I,J)=VAR3D1(I,J,IFD)
                  ENDDO
                  ENDDO
                  if(grib=='grib2') then
                     cfld=cfld+1
                     fld_info(cfld)%ifld=IAVBLFLD(IGET(520))
                     fld_info(cfld)%lvl=LVLSXML(IFD,IGET(520))
!$omp parallel do private(i,j,ii,jj)
                     do j=1,jend-jsta+1
                        jj = jsta+j-1
                        do i=1,iend-ista+1
                        ii = ista+i-1
                           datapd(i,j,cfld) = GRID1(ii,jj)
                        enddo
                     enddo
                  endif
               ENDIF
               ! V
               IF (LVLS(IFD,IGET(521)) > 0) THEN
!$omp parallel do private(i,j)
                  DO J=JSTA,JEND
                  DO I=ISTA,IEND
                     GRID1(I,J)=VAR3D2(I,J,IFD)
                  ENDDO
                  ENDDO
                  if(grib=='grib2') then
                     cfld=cfld+1
                     fld_info(cfld)%ifld=IAVBLFLD(IGET(521))
                     fld_info(cfld)%lvl=LVLSXML(IFD,IGET(521))
!$omp parallel do private(i,j,ii,jj)
                     do j=1,jend-jsta+1
                        jj = jsta+j-1
                        do i=1,iend-ista+1
                        ii = ista+i-1
                           datapd(i,j,cfld) = GRID1(ii,jj)
                        enddo
                     enddo
                  endif
               ENDIF
            ENDDO

            deallocate(VAR3D1)
            deallocate(VAR3D2)

         ENDIF

!        STEP 2 -- MASS FIELDS INTERPOLATION EXCEPT:
!                  HGT(TO BE FIXED VALUES)
!                  RH ABSV (TO BE CACULATED)

         if(allocated(QIN)) deallocate(QIN)
         if(allocated(QTYPE)) deallocate(QTYPE)
         ALLOCATE(QIN(ISTA:IEND,JSTA:JEND,LM,NFDMAX))
         ALLOCATE(QTYPE(NFDMAX))

!        INITIALIZE INPUTS
         nFDS = 0
         IF(IGET(479) > 0) THEN
            nFDS = nFDS + 1
            IDS(nFDS) = 479
            QIN(ISTA:IEND,JSTA:JEND,1:LM,nFDS)=icing_gfip(ISTA:IEND,JSTA:JEND,1:LM)
            QTYPE(nFDS)="O"
         end if
         IF(IGET(481) > 0) THEN
            nFDS = nFDS + 1
            IDS(nFDS) = 481
            QIN(ISTA:IEND,JSTA:JEND,1:LM,nFDS)=icing_gfis(ISTA:IEND,JSTA:JEND,1:LM)
            QTYPE(nFDS)="O"
         end if
         IF(IGET(476) > 0) THEN
            nFDS = nFDS + 1
            IDS(nFDS) = 476
            QIN(ISTA:IEND,JSTA:JEND,1:LM,nFDS)=gtg(ISTA:IEND,JSTA:JEND,1:LM)
            QTYPE(nFDS)="O"
         end if
         IF(IGET(477) > 0) THEN
            nFDS = nFDS + 1
            IDS(nFDS) = 477
            QIN(ISTA:IEND,JSTA:JEND,1:LM,nFDS)=catedr(ISTA:IEND,JSTA:JEND,1:LM)
            QTYPE(nFDS)="O"
         end if
         IF(IGET(478) > 0) THEN
            nFDS = nFDS + 1
            IDS(nFDS) = 478
            QIN(ISTA:IEND,JSTA:JEND,1:LM,nFDS)=mwt(ISTA:IEND,JSTA:JEND,1:LM)
            QTYPE(nFDS)="O"
         end if
         IF(IGET(519) > 0) THEN
            nFDS = nFDS + 1
            IDS(nFDS) = 519
            QIN(ISTA:IEND,JSTA:JEND,1:LM,nFDS)=T(ISTA:IEND,JSTA:JEND,1:LM)
            QTYPE(nFDS)="T"
         end if

!        FOR WAFS, ALL LEVLES OF DIFFERENT VARIABLES ARE THE SAME, USE ANY
         iID=IDS(1)
         N = IAVBLFLD(IGET(iID))
         NFDCTL=size(pset%param(N)%level)
         if(allocated(ITYPEFDLVLCTL)) deallocate(ITYPEFDLVLCTL)
         allocate(ITYPEFDLVLCTL(NFDCTL))
         DO IFD = 1,NFDCTL
            ITYPEFDLVLCTL(IFD)=LVLS(IFD,IGET(iID))
         ENDDO
         if(allocated(HTFDCTL)) deallocate(HTFDCTL)
         allocate(HTFDCTL(NFDCTL))
         HTFDCTL=pset%param(N)%level
         DO i = 1, NFDCTL
            HTFDCTL(i)=P2H(HTFDCTL(i)/100.)
         ENDDO

         if(allocated(QFD)) deallocate(QFD)
         ALLOCATE(QFD(ISTA:IEND,JSTA:JEND,NFDCTL,nFDS))
         QFD=SPVAL

         call FDLVL_MASS(ITYPEFDLVLCTL,NFDCTL,pset%param(N)%level,HTFDCTL,nFDS,QIN,QTYPE,QFD)

!        Adjust values before output
         N1 = -1
         DO N=1,nFDS
            iID=IDS(N)

!           Icing Potential
            if(iID==481) then
               N1=N
               DO IFD = 1,NFDCTL
                  DO J=JSTA,JEND
                  DO I=ISTA,IEND
                     if(QFD(I,J,IFD,N) < SPVAL) then
                        QFD(I,J,IFD,N)=max(0.0,QFD(I,J,IFD,N))
                        QFD(I,J,IFD,N)=min(1.0,QFD(I,J,IFD,N))
                     endif
                  ENDDO
                  ENDDO
               ENDDO
            endif

!           Icing severity categories
!              0 = none (0, 0.08)
!              1 = trace [0.08, 0.21]
!              2 = light (0.21, 0.37]
!              3 = moderate (0.37, 0.67]
!              4 = severe (0.67, 1]
!              http://www.nco.ncep.noaa.gov/pmb/docs/grib2/grib2_table4-207.shtml
            if(iID==479) then
               DO IFD = 1,NFDCTL
                  DO J=JSTA,JEND
                  DO I=ISTA,IEND
                     if(N1 > 0) then
                        ! Icing severity is 0 when icing potential is too small
                        if(QFD(I,J,IFD,N1) < 0.001) QFD(I,J,IFD,N)=0.
                     endif
                     if(QFD(I,J,IFD,N) == SPVAL) cycle
                     if (QFD(I,J,IFD,N) < 0.08) then
                        QFD(I,J,IFD,N) = 0.0
                     elseif (QFD(I,J,IFD,N) <= 0.21) then
                        QFD(I,J,IFD,N) = 1.
                     else if(QFD(I,J,IFD,N) <= 0.37) then
                        QFD(I,J,IFD,N) = 2.0
                     else if(QFD(I,J,IFD,N) <= 0.67) then
                        QFD(I,J,IFD,N) = 3.0
                     else
                        QFD(I,J,IFD,N) = 4.0
                     endif
                  ENDDO
                  ENDDO
               ENDDO
            endif

!           GTG turbulence:  EDRPARM, CAT, MWTURB
            if(iID==476 .or. iID==477 .or. iID==478) then
               DO IFD = 1,NFDCTL
                  DO J=JSTA,JEND
                  DO I=ISTA,IEND
                     if(QFD(I,J,IFD,N) < SPVAL) then
                        QFD(I,J,IFD,N)=max(0.0,QFD(I,J,IFD,N))
                        QFD(I,J,IFD,N)=min(1.0,QFD(I,J,IFD,N))
                     endif
                  ENDDO
                  ENDDO
               ENDDO
            endif

         ENDDO

!        Output
         DO N=1,nFDS
            iID=IDS(N)
            DO IFD = 1,NFDCTL
               IF (LVLS(IFD,IGET(iID)) > 0) THEN
!$omp parallel do private(i,j)
                  DO J=JSTA,JEND
                  DO I=ISTA,IEND
                     GRID1(I,J)=QFD(I,J,IFD,N)
                  ENDDO
                  ENDDO
                  if(grib=='grib2') then
                     cfld=cfld+1
                     fld_info(cfld)%ifld=IAVBLFLD(IGET(iID))
                     fld_info(cfld)%lvl=LVLSXML(IFD,IGET(iID))
!$omp parallel do private(i,j,ii,jj)
                     do j=1,jend-jsta+1
                        jj = jsta+j-1
                        do i=1,iend-ista+1
                        ii = ista+i-1
                           datapd(i,j,cfld) = GRID1(ii,jj)
                        enddo
                     enddo
                  endif
               ENDIF
            ENDDO
         ENDDO

         DEALLOCATE(QIN,QFD)
         DEALLOCATE(QTYPE)

!        STEP 3 -  MASS FIELDS CALCULATION
!                  HGT(TO BE FIXED VALUES)
!                  RH ABSV (TO BE CACULATED)
         ! HGT
         IF(IGET(518) > 0) THEN
            iID=518
            N = IAVBLFLD(IGET(iID))
            NFDCTL=size(pset%param(N)%level)
            if(allocated(HTFDCTL)) deallocate(HTFDCTL)
            allocate(HTFDCTL(NFDCTL))
            HTFDCTL=pset%param(N)%level
            DO i = 1, NFDCTL
               HTFDCTL(i)=P2H(HTFDCTL(i)/100.)
            ENDDO

            DO IFD = 1,NFDCTL
               IF (LVLS(IFD,IGET(iID)) > 0) THEN
!$omp parallel do private(i,j)
                  DO J=JSTA,JEND
                  DO I=ISTA,IEND
                     GRID1(I,J)=HTFDCTL(IFD)
                  ENDDO
                  ENDDO
                  if(grib=='grib2') then
                     cfld=cfld+1
                     fld_info(cfld)%ifld=IAVBLFLD(IGET(iID))
                     fld_info(cfld)%lvl=LVLSXML(IFD,IGET(iID))
!$omp parallel do private(i,j,ii,jj)
                     do j=1,jend-jsta+1
                        jj = jsta+j-1
                        do i=1,iend-ista+1
                        ii = ista+i-1
                           datapd(i,j,cfld) = GRID1(ii,jj)
                        enddo
                     enddo
                  endif
               ENDIF
            ENDDO            
         ENDIF

         ! Relabel the pressure level to reference levels
!         IDS = 0
         IDS = (/ 481,479,476,477,478,518,519,520,521,(0,I=10,50) /)
         do i = 1, NFDMAX
            iID=IDS(i)
            if(iID == 0) exit
            N = IAVBLFLD(IGET(iID))
            NFDCTL=size(pset%param(N)%level)
            do j = 1, NFDCTL
               pset%param(N)%level(j) = relabel(pset%param(N)%level(j))
            end do
         end do

      ENDIF

!
!     END OF ROUTINE.
!
      RETURN
      END

!--------------------------------------------------------------------------------------
!> P2H() converts pressure levels (hPa) to geopotential heights.
!> Uses ICAO standard atmosphere parameters as defined here:
!>        https://www.nen.nl/pdfpreview/preview_29424.pdf
!>
!> @param[in] p real Pressure (hPa)
!> @return P2H Geopotential height. 
!> 

      FUNCTION P2H(p)
      implicit none
      real, intent(in) :: p
      real :: P2H
      real, parameter :: lapse = 0.0065
      real, parameter :: surf_temp = 288.15
      real, parameter :: gravity = 9.80665
      real, parameter :: moles_dry_air = 0.02896442
      real, parameter :: gas_const = 8.31432
      real, parameter :: surf_pres = 1013.25
      real, parameter :: power_const = (gravity * moles_dry_air) &
                                       / (gas_const * lapse)

      P2H = (surf_temp/lapse)*(1-(p/surf_pres)**(1/power_const))
      END

!--------------------------------------------------------------------------------------
!> relabel() relabels the pressure level to reference (or standard atmospheric) 
!> pressure levels rather than model pressure.
!>
!> @param[in] p real Pressure (Pa).
!> @return relabel Relabeled pressure value in reference (standard atmospheric) pressure levels. 
!>

      function relabel(p)
      implicit none
      real, intent(in) :: p
      real :: relabel
      relabel=p
      if(p == 10040.) relabel=10000
      if(p == 12770.) relabel=12500
      if(p == 14750.) relabel=15000
      if(p == 17870.) relabel=17500
      if(p == 19680.) relabel=20000
      if(p == 22730.) relabel=22500
      if(p == 27450.) relabel=27500
      if(p == 30090.) relabel=30000
      if(p == 34430.) relabel=35000
      if(p == 39270.) relabel=40000
      if(p == 44650.) relabel=45000
      if(p == 50600.) relabel=50000
      if(p == 59520.) relabel=60000
      if(p == 69680.) relabel=70000
      if(p == 75260.) relabel=75000
      if(p == 81200.) relabel=80000
      if(p == 84310.) relabel=85000
      END

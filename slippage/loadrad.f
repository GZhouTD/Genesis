      subroutine loadrad(islice)
c     =========================================================
c     fills the array crfield with initial field
c     for start up from noise this should be small
c     ---------------------------------------------------------
c
      include 'genesis.def'
      include 'field.cmn'
      include 'input.cmn'
      include 'work.cmn'
      include 'io.cmn'
      include 'diagnostic.cmn'
      include 'time.cmn'
      include 'sim.cmn'
   
c
      real*8  pradin
      integer ix,irec,islice,ierr,n
c
c     initialize field
c     ---------------------------
      do ix=1,ncar*ncar*nhloop
        crfield(ix)=dcmplx(0.,0.)
      enddo
c
      pradoln(1)=prad0          !first halfstep no gain (see diagno)
      do n=2,nhmax
        pradoln(n)=0.d0  !kg
        if (n.eq.nharm) pradoln(n)=pradh0
      end do
c
c     load initial field
c     ------------------------------------------------------------------
c
c
      if (nfin.le.0) then
        call gauss_hermite(crfield,prad0,zrayl,
     +  zwaist,xks,radphase,1) !load gauss-hermite mode for all harmonics
        if ((nharm.gt.1).and.(pradh0.gt.0)) then
          call gauss_hermite(crfield,pradh0,zrayl*dble(nharm),
     +    zwaist,xks*dble(nharm),radphase,nharm) !load gauss-hermite mode for higher harmonics
        endif
      else
        irec=nslp-1+islice                 !get record number
        if (alignradf.ne.0) irec=offsetradf+islice ! add offset, when selected
        if (itdp.eq.0) irec=1              !scan+ss -> use 1sr record
        if (irec.gt.0) then				   ! physical record?
          ierr=readfield(crfield,irec)       !get fundamental field from file
          if (ierr.lt.0) call last           !stop if error occured
        else
          call gauss_hermite(crfield,prad0,zrayl*dble(nharm),
     +	  zwaist,xks*dble(nharm),radphase,1)
          if ((nharm.gt.1).and.(pradh0.gt.0)) then
            call gauss_hermite(crfield,pradh0,zrayl*dble(nharm),
     +      zwaist,xks*dble(nharm),radphase,nharm) !load gauss-hermite mode for all harmonics
          endif
        endif  
        pradin=0.d0
        do ix=1,ncar*ncar                  !copy to crfield
           pradin=pradin+dble(crfield(ix)*conjg(crfield(ix)))
        enddo 
        prad0=pradin*(dxy*eev*xkper0/xks)**2/vacimp
	pradoln(1)=prad0
      endif
      return
      end       !of loadrad
c
c
      subroutine gauss_hermite(cfld,power,zr,zw,rks,phase,harm)
c     =======================================================
c     fills array cfld with the fundamental gauss-hermite mode
c     using the total power, wavenumber rks, rayleigh length zr
c     and waist position zw.
c
c     Note - only the fundamental is loaded. harmonics are set to zero
c     --------------------------------------------------------
c
      include 'genesis.def'
      include 'sim.cmn'
      include 'field.cmn'
      include 'input.cmn'
      include 'diagnostic.cmn'

      complex*16 cfld(ncar*ncar*nhmax),cgauss
      real*8     zscal,xcr,ycr,rcr2,power,zr,zw,rks,phase
      integer    iy,ix,idx,n,harm,ioff
      real*8     dump
c
c     check for unphysical parameters
c
      idx=0
      if (zr.le.0) idx=printerr(errload,'zrayl in gauss_hermite')
      if (rks.le.0) idx=printerr(errload,'xks in gauss_hermite')
      if (power.lt.0) idx=printerr(errload,'power in gauss_hermite')
      if (idx.lt.0) call last
c
      ioff=ncar*ncar*(harm-1)             !offset for harmonics
      cgauss=0.5d0*rks/dcmplx(zr,-zw)     !see siegman
      zscal = dsqrt(2.d0*vacimp*power/pi *dble(cgauss))  
     +              *rks/xkper0**2/eev    !?
      dump=0.d0
      do iy=1,ncar
         do ix=1,ncar
             idx=(iy-1)*ncar+ix
             xcr=dxy*float(ix-1)/xkw0-dgrid
             ycr=dxy*float(iy-1)/xkw0-dgrid
             rcr2=xcr*xcr+ycr*ycr 
             cfld(idx+ioff)=
     +           zscal*cdexp(-cgauss*rcr2+dcmplx(0,1)*phase)  !gaussian beam
             dump=dump+dble(cfld(idx+ioff)*conjg(cfld(idx+ioff))) !=sum of |aij|^2 
         end do    !ix
      end do       !iy
      return
      end
c
      subroutine loadslpfld(nslp)
c     =========================================================
c     fills the array crtime with a seeding field for the first 
c     slice.
c     ---------------------------------------------------------
c
      include 'genesis.def'
      include 'input.cmn'
      include 'field.cmn'
      include 'work.cmn'
      include 'io.cmn'
      include 'timerec.cmn'
      include 'diagnostic.cmn'
c
      integer ix,islp,nslp,ierr,irec,i
c
      if (itdp.eq.0) return

c
c     check for limitation in timerecord                                          
c     ---------------------------------------------------------------             
c                                                                                 
      if (nslice.lt.nslp*(1-iotail))
     c  ierr=printerr(errlargeout,'no output - ntail too small')

      if (nofile.eq.0) then
         if (nslp*ncar*ncar*nhloop.gt.ntmax*nhmax) then
           ierr=printerr(errtime,' ')
           call last
         endif
      endif
c
c     load initial slippage field from file or internal generation 
c     ----------------------------------------------------------------
c


      do islp=1,nslp-1
c
        do ix=1,ncar*ncar*nhloop
          crwork3(ix)=dcmplx(0.,0.)   !initialize the radiation field
        enddo
c
        if (nfin.gt.0) then
            irec=islp
            if (alignradf.ne.0) then
               irec=irec-nslp+1+offsetradf
            endif
            if (irec.gt.0) then
              ierr=readfield(crwork3,irec)  !get field from file (record 1 - nslp-1)
              if (ierr.lt.0) call last      !record nslp is loaded with loadrad (s.a.)
            else
              pradoln(1)=prad0
              do i=2,nhmax
                pradoln(i)=0.
                if (i.eq.nharm) pradoln(i)=pradh0
              enddo
              call gauss_hermite(crwork3,prad0,zrayl,zwaist,xks,
     c                           radphase,1) 
              if ((nharm.gt.1).and.(pradh0.gt.0)) then
                 call gauss_hermite(crwork3,pradh0,zrayl*dble(nharm),
     +                        zwaist,xks*dble(nharm),radphase,nharm) !load gauss-hermite mode for higher harmonics
              endif
            endif   
         else
           call dotimerad(islp+1-nslp)      ! get time-dependence of slippage field behind bunch
           call gauss_hermite(crwork3,prad0,zrayl,zwaist,xks,radphase,1) !load gauss-hermite mode
           if ((nharm.gt.1).and.(pradh0.gt.0)) then
              call gauss_hermite(crwork3,pradh0,zrayl*dble(nharm),
     +                      zwaist,xks*dble(nharm),radphase,nharm) !load gauss-hermite mode for higher harmonics
           endif
           pradoln(1)=prad0
         endif            
         call pushtimerec(crwork3,ncar,nslp-islp)
      enddo   
      return
      end
c 
c
      subroutine swapfield(islp,islice)
c     ========================================
c     swap current field with then time-record
c     ----------------------------------------
c
      include 'genesis.def'
      include 'mpi.cmn'
      include 'input.cmn'
      include 'field.cmn'
      include 'work.cmn'
      include 'time.cmn'
c
      integer islp,it,mpi_top,mpi_bot
      integer memsize,islice,marker,ioff
      integer status(MPI_STATUS_SIZE)
c
      memsize=ncar*ncar*nhloop

      if (mpi_loop.gt.1) then
c
        do it=1,memsize
          crwork3(it)=crfield(it)
        enddo
c
        mpi_top=mpi_id+1
        if (mpi_top.ge.mpi_loop) mpi_top=0
        mpi_bot=mpi_id-1
        if (mpi_bot.lt.0) mpi_bot=mpi_loop-1      
c
        if (mod(mpi_id,2).eq.0) then
         call MPI_SEND(crwork3,memsize,MPI_DOUBLE_COMPLEX,mpi_top,
     c       mpi_id,MPI_COMM_WORLD,mpi_err)
         call MPI_RECV(crfield,memsize,MPI_DOUBLE_COMPLEX,mpi_bot,
     c       mpi_bot,MPI_COMM_WORLD,status,mpi_err)        
        else
         call MPI_RECV(crfield,memsize,MPI_DOUBLE_COMPLEX,mpi_bot,
     c       mpi_bot,MPI_COMM_WORLD,status,mpi_err)        
         call MPI_SEND(crwork3,memsize,MPI_DOUBLE_COMPLEX,mpi_top,
     c       mpi_id,MPI_COMM_WORLD,mpi_err)    
        endif    
      endif
      
      if (mpi_id.eq.0) then
        do it=1,memsize
          crwork3(it)=crfield(it)
        enddo
        write(*,*) '++++++++++++++++++'
        write(*,*) npos
        write(*,*) nslp
        write(*,*) '++++++++++++++++++'
        call pulltimerec(crfield,ncar,islp)
        call pushtimerec(crwork3,ncar,islp)
      endif
c     GZHou modified here for  phase shifter
      if (islp.eq.npos) then
        write(*,*) 'heheheheheheheheheheheheheheheheheh'
        memsize=ncar*ncar
        call gswapfield(islice)
        marker=islice-gslp
        ioff=(marker-1)*memsize
        do it=1,memsize
          if (marker.lt.1) then
              crfield(it)=dcmplx(0.,0.)
          else
              crfield(it)=gfield(it+ioff)
          endif
        enddo
        call phaserot
        call addphi
      endif

      return
      end ! swapfield

c     This function is added by G.Zhou to gather the field
      subroutine gswapfield(islice)
c     ========================================
c     swap current field with then time-record
c     ----------------------------------------
c
      include 'genesis.def'
      include 'mpi.cmn'
      include 'input.cmn'
      include 'field.cmn'
      include 'work.cmn'
c      include 'mpif.h'
c
      integer it,mpi_top,mpi_bot,islice
      integer memsize,gslice,ioff
      integer status(MPI_STATUS_SIZE)
c
      memsize=ncar*ncar
      if (islice-1+mpi_loop.le.nslice) then
        gslice=mpi_loop
      else
        gslice=nslice-islice+1+mpi_id
      endif
c      write(*,*) '+++++++++++++++++++',mpi_id
      write(*,*) "+++++++root is gathering++++++"
      call  MPI_ALLGather(crfield,memsize,MPI_DOUBLE_COMPLEX,tfield,
     c         memsize,MPI_DOUBLE_COMPLEX, MPI_COMM_WORLD,mpi_err)
      call MPI_Barrier(MPI_COMM_WORLD,mpi_err)
      write(*,*) "processors sync'ed"
c      if (mpi_id.gt.0) return
      ioff=(islice-1-mpi_id)*memsize
c      write(*,*) gslice
      do it=1,memsize*gslice
        gfield(it+ioff)=tfield(it)
      enddo
      return
      end ! swapfield
c   
      subroutine goutput(filename)
c     ==================================================================
c     some diagnostics:
c     the radiation power must be calculated for each integration step
c     otherwise error will be wrong.
c     all calculation are stored in a history arrays which will be
c     written to a file ad the end of the run.
c     ------------------------------------------------------------------
c
      include  'genesis.def'
      include  'mpi.cmn'
      include  'sim.cmn'
      include  'input.cmn'
      include  'field.cmn'
      include  'particle.cmn'
      include  'diagnostic.cmn'
      include  'work.cmn'
      include  'magnet.cmn'    ! unofficial
c
      integer i,ip,ix,iy,i0,i1,nn(2),istepz,nctmp,n
      integer ioff,memsize,nout
      real*8 xavg,yavg,tpsin,tpcos,prad,ptot,gainavg,
     +       xxsum,yysum,cr2,crsum,wwcr,pradn,radp(5000)
      complex*16 ctmp 
      character*6 filename
c      if (mpi_id.ne.3) return
      do n=1, nslice   ! looping over harmonics
        crsum=0.0d0
        ioff=(n-1)*ncar*ncar
        do i=1+ioff,ncar*ncar+ioff
          wwcr=dble(gfield(i)*conjg(gfield(i))) !=sum of |aij|^2 
          crsum=crsum+wwcr
        end do
        pradn=crsum*(dxy*eev*xkper0/xks/1.0)**2/vacimp 
        radp(n)=pradn
c        write(*,*) pradn
      enddo
      open(nout,file=filename, status='unknown')
      write(*,30) (radp(n),n=1,nslice)
      write(nout,30) (radp(n),n=1,nslice)
30    format((50(1pe14.4)))
      return
      end


      subroutine ishifter
c     ========================================
c     swap current field with then time-record
c     ----------------------------------------
c
      include 'genesis.def'
      include 'mpi.cmn'
      include 'input.cmn'
      include 'field.cmn'
      include 'work.cmn'
      include 'time.cmn'
c
      integer islp,it,mpi_top,mpi_bot
      integer memsize,islice,shift
      integer status(MPI_STATUS_SIZE)
      real*8  mintmp,tmp
      real*8  tislp,tnslp,hdt1,hdt2
c
      mintmp=100000
      npos=100000
      do islp=1,nslp
        tislp=islp
        tnslp=nslp
        hdt1=tislp/tnslp
        hdt2=pos/zstop 
        if (mpi_id.eq.0) then
          write(*,*) tislp
          write(*,*) nslp
          write(*,*) pos
          write(*,*) zstop
        endif
        tmp=abs(hdt1-hdt2)
        if (tmp.lt.mintmp) then
          mintmp=tmp
          npos=islp
        endif
      enddo
c      if (pos.eq.0) then
c        npos=0
c      endif
      gslp=Floor(tshift/zsep)
      gphi=(tshift-gslp*zsep)*2*pi

      return
      end


      subroutine addphi
c     ==================================================================
c     add a small phase
c     ------------------------------------------------------------------
c
      include 'genesis.def'
      include 'input.cmn'
      include 'particle.cmn' 
      include 'field.cmn'
c
      integer n
      write(*,*) 'gphihdoashdoisdhasdihjsakldjhlaksdjlkasjdkl'
      write(*,*) gphi 
      do n=1,npart
c          write(*,*) theta(n)
	  theta(n)=theta(n)+gphi
c          write(*,*) theta(n)
      enddo 

      return
      end  

      subroutine phaserot 
c     ================================================================= 
c     Transfer matrix calculation supplied by A. Meseck. 
c     ------------------------------------------------------------------
c
      include 'genesis.def'
      include 'io.cmn'
      include 'input.cmn'
      include 'field.cmn'
      include 'sim.cmn'
      include 'particle.cmn'
c
      real*8 ypart_old,py_old,xpart_old,px_old
      real*8 gamma_old,theta_old,ggamma,gnpart  
      integer i,ierr
c
      
      itram56=2*tshift*xlamds
      ggamma=0.0
      gnpart=0.0

      do i=1,npart 
c  exclude lost particles
         if (gamma(i).ge.0) then
           ggamma=ggamma+gamma(i)
           gnpart=gnpart+1.0
         endif
      enddo
      igamref= ggamma/gnpart 
      write(*,*) itram56,itram11,igamref,gnpart
      do i=1,npart 
c  Denormalize      
         px(i)=px(i)/gamma(i)
         py(i)=py(i)/gamma(i)
cc
         xpart_old=xpart(i)
         ypart_old=ypart(i)
         px_old= px(i)
         py_old= py(i)
         theta_old=theta(i)
         gamma_old= gamma(i)

            xpart(i)=itram11*xpart_old+itram12*px_old+
     +      itram13*ypart_old+itram14*py_old+
     +      itram15*theta(i)*xlamds*convharm/twopi+
     +      itram16*(gamma(i)-igamref)/igamref

           px(i)=itram21*xpart_old+itram22*px_old+
     +      itram23*ypart_old+itram24*py_old+
     +      itram25*theta_old*xlamds*convharm/twopi+
     +      itram26*(gamma(i)-igamref)/igamref

         
           ypart(i)=itram31*xpart_old+itram32*px_old+
     +      itram33*ypart_old+itram34*py_old+
     +      itram35*theta_old*xlamds*convharm/twopi+
     +      itram36*(gamma(i)-igamref)/igamref

           py(i)=itram41*xpart_old+itram42*px_old+
     +      itram43*ypart_old+itram44*py_old+
     +      itram45*theta_old*xlamds*convharm/twopi+
     +      itram46*(gamma(i)-igamref)/igamref

          theta(i)=itram55*theta_old+ (itram56*
     +    ((gamma(i)-igamref)/igamref)*twopi/xlamds/convharm)+
     +    (itram51*xpart_old+itram52*px_old+itram53*ypart_old+
     +     itram54*py_old)*twopi/xlamds/convharm

         gamma(i)=(itram61*xpart_old+itram62*px_old+
     +      itram63*ypart_old+itram64*py_old+
     +      itram65*theta_old*xlamds*convharm/twopi)*
     +      igamref + itram66*(gamma(i)-igamref)+igamref

c normalization
           px(i)=px(i)*gamma(i)
           py(i)=py(i)*gamma(i)
cc
      enddo    
                                                                 
      return
      end !of import transfermatrix

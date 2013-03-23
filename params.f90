!-----------------------------------------------------------------------
! Read parameters from an ini file (version 03/2013)
!
!-----------------------------------------------------------------------



subroutine get_params (paramsfile)
  use mpi_header ! Module incapsulates mpif.
  use share_vars
  implicit none
  integer                              :: mpicode, io_error,i,icpu
  integer, dimension (11)              :: comm_int
  real (kind=pr), dimension (11)       :: comm_real
  character (len=80)                   :: paramsfile ! this is the file we read the PARAMS from
  character (len=80)                   :: tmp
  character PARAMS(nlines)*256	! this array will contain the ascii-params file
 
 

  if (mpirank==0) then
    !-----------------------------------------------------------
    ! read in the params file (root)
    !-----------------------------------------------------------
    write (*,'(A,i3)') "*** info: reading params from "//trim(paramsfile)//" rank=", mpirank
    i = 1
    open ( unit=14, file=paramsfile, action='read', status='old' )    
    do while ((io_error==0).and.(i<=nlines))
      read (14,'(A)',iostat=io_error) PARAMS(i)  
      i = i+1
    enddo      
    close (14)
    i = i-1 ! counted one too far
  endif

  call GetValue_Int (PARAMS,i,"Resolution","nx",nx, 4)
  call MPI_BCAST( nx, 1, mpiinteger, 0, MPI_COMM_WORLD, mpicode )
  call GetValue_Int (PARAMS,i,"Resolution","ny",ny, 4)
  call MPI_BCAST( ny, 1, mpiinteger, 0, MPI_COMM_WORLD, mpicode )
  call GetValue_Int (PARAMS,i,"Resolution","nz",nz, 4)
  call MPI_BCAST( nz, 1, mpiinteger, 0, MPI_COMM_WORLD, mpicode )
  
  call GetValue_Int (PARAMS,i,"Time","nt",nt, 9999999)
  call MPI_BCAST( nt, 1, mpiinteger, 0, MPI_COMM_WORLD, mpicode )
  call GetValue_Int (PARAMS,i,"Time","iTimeMethodFluid",iTimeMethodFluid, 1)
  call MPI_BCAST( iTimeMethodFluid, 1, mpiinteger, 0, MPI_COMM_WORLD, mpicode )  
  call GetValue_Real (PARAMS,i,"Time","Tmax",Tmax, 1.d9)
  call MPI_BCAST( Tmax, 1, mpireal, 0, MPI_COMM_WORLD, mpicode )
  call GetValue_Real (PARAMS,i,"Time","CFL",cfl, 0.1d0)
  call MPI_BCAST( cfl, 1, mpireal, 0, MPI_COMM_WORLD, mpicode )  
  
  call GetValue_Real (PARAMS,i,"ReynoldsNumber","nu",nu, 1.d-2)
  call MPI_BCAST( nu, 1, mpireal, 0, MPI_COMM_WORLD, mpicode )  
  
  call GetValue_Int (PARAMS,i,"InitialCondition","inicond",inicond, 3)
  call MPI_BCAST( inicond, 1, mpiinteger, 0, MPI_COMM_WORLD, mpicode )
  
  call GetValue_Int (PARAMS,i,"Dealiasing","iDealias",iDealias, 3)
  call MPI_BCAST( iDealias, 1, mpiinteger, 0, MPI_COMM_WORLD, mpicode )  
  
  call GetValue_Int (PARAMS,i,"Penalization","iPenalization",iPenalization, 3)
  call MPI_BCAST( iPenalization, 1, mpiinteger, 0, MPI_COMM_WORLD, mpicode )  
  call GetValue_Int (PARAMS,i,"Penalization","iMoving",iMoving, 3)
  call MPI_BCAST( iMoving, 1, mpiinteger, 0, MPI_COMM_WORLD, mpicode )  
  call GetValue_Int (PARAMS,i,"Penalization","iMask",iMask, 3)
  call MPI_BCAST( iMask, 1, mpiinteger, 0, MPI_COMM_WORLD, mpicode )  
  call GetValue_Real (PARAMS,i,"Penalization","eps",eps, 1.d-2)
  call MPI_BCAST( eps, 1, mpireal, 0, MPI_COMM_WORLD, mpicode )  
  
  call GetValue_Real (PARAMS,i,"Geometry","xl",xl, 1.d0)
  call MPI_BCAST( xl, 1, mpireal, 0, MPI_COMM_WORLD, mpicode ) 
  call GetValue_Real (PARAMS,i,"Geometry","yl",yl, 1.d0)
  call MPI_BCAST( yl, 1, mpireal, 0, MPI_COMM_WORLD, mpicode ) 
  call GetValue_Real (PARAMS,i,"Geometry","zl",zl, 1.d0)
  call MPI_BCAST( zl, 1, mpireal, 0, MPI_COMM_WORLD, mpicode ) 
  call GetValue_Real (PARAMS,i,"Geometry","x0",x0, 0.d0)
  call MPI_BCAST( x0, 1, mpireal, 0, MPI_COMM_WORLD, mpicode ) 
  call GetValue_Real (PARAMS,i,"Geometry","y0",y0, 0.d0)
  call MPI_BCAST( y0, 1, mpireal, 0, MPI_COMM_WORLD, mpicode ) 
  call GetValue_Real (PARAMS,i,"Geometry","z0",z0, 0.d0)
  call MPI_BCAST( z0, 1, mpireal, 0, MPI_COMM_WORLD, mpicode ) 
  
  
  call GetValue_Int (PARAMS,i,"MeanFlow","iMeanFlow",iMeanFlow, 3)
  call MPI_BCAST( iMeanFlow, 1, mpiinteger, 0, MPI_COMM_WORLD, mpicode )  
  call GetValue_Real (PARAMS,i,"MeanFlow","ux",ux, 1.d0)
  call MPI_BCAST( ux, 1, mpireal, 0, MPI_COMM_WORLD, mpicode ) 
  call GetValue_Real (PARAMS,i,"MeanFlow","uy",uy, 1.d0)
  call MPI_BCAST( uy, 1, mpireal, 0, MPI_COMM_WORLD, mpicode ) 
  call GetValue_Real (PARAMS,i,"MeanFlow","uz",uz, 1.d0)
  call MPI_BCAST( uz, 1, mpireal, 0, MPI_COMM_WORLD, mpicode ) 
  call GetValue_Real (PARAMS,i,"MeanFlow","ax",ax, 0.d0)
  call MPI_BCAST( ax, 1, mpireal, 0, MPI_COMM_WORLD, mpicode ) 
  call GetValue_Real (PARAMS,i,"MeanFlow","ay",ay, 0.d0)
  call MPI_BCAST( ay, 1, mpireal, 0, MPI_COMM_WORLD, mpicode ) 
  call GetValue_Real (PARAMS,i,"MeanFlow","az",az, 0.d0)
  call MPI_BCAST( az, 1, mpireal, 0, MPI_COMM_WORLD, mpicode ) 
  
  call GetValue_Int (PARAMS,i,"Saving","iDoBackup",iDoBackup, 3)
  call MPI_BCAST( iDoBackup, 1, mpiinteger, 0, MPI_COMM_WORLD, mpicode )  
  call GetValue_Int (PARAMS,i,"Saving","iSaveVelocity",iSaveVelocity, 3)
  call MPI_BCAST( iSaveVelocity, 1, mpiinteger, 0, MPI_COMM_WORLD, mpicode )  
  call GetValue_Int (PARAMS,i,"Saving","iSavePress",iSavePress, 3)
  call MPI_BCAST( iSavePress, 1, mpiinteger, 0, MPI_COMM_WORLD, mpicode )  
  call GetValue_Int (PARAMS,i,"Saving","iSaveVorticity",iSaveVorticity, 3)
  call MPI_BCAST( iSaveVorticity, 1, mpiinteger, 0, MPI_COMM_WORLD, mpicode )  
  call GetValue_Int (PARAMS,i,"Saving","iSaveMask",iSaveMask, 3)
  call MPI_BCAST( iSaveMask, 1, mpiinteger, 0, MPI_COMM_WORLD, mpicode )  
  call GetValue_Int (PARAMS,i,"Saving","iSaveSolidVelocity",iSaveSolidVelocity, 3)
  call MPI_BCAST( iSaveSolidVelocity, 1, mpiinteger, 0, MPI_COMM_WORLD, mpicode )  
  call GetValue_Real (PARAMS,i,"Saving","tsave",tsave, 9.d9)
  call MPI_BCAST( tsave, 1, mpireal, 0, MPI_COMM_WORLD, mpicode ) 
  call GetValue_Real (PARAMS,i,"Saving","tdrag",tdrag, 9.d9)
  call MPI_BCAST( tdrag, 1, mpireal, 0, MPI_COMM_WORLD, mpicode )   
  !-------------------------------------------------------
  ! set other parameters
  !-------------------------------------------------------  
  pi     = 4.d0 * datan (1.d0)
  scalex = 2.d0*pi / xl
  scaley = 2.d0*pi / yl
  scalez = 2.d0*pi / zl  
  dx = xl / dble (nx)
  dy = yl / dble (ny)
  dz = zl / dble (nz) 
  tstart = 0.d0
  
  
  !-- Stop if the sizes are odd or smaller than 4
  if ( nx<4 .or. ny<4 .or. nz<4 .or. modulo(nx,2)==1 .or. modulo(ny,2)==1 .or. modulo(nz,2)==1 ) then
    if ( mpirank == 0 ) then
      print *, 'nx, ny, nz must be even and not smaller than 4'
    endif
    stop
  endif
  
  !-------------------------------------------------------
  ! initialize FFT
  !-------------------------------------------------------
  call fft_initialize 
  
  !--------------------------------------------------------
  ! HEADER
  !--------------------------------------------------------
  if ( mpirank == 0 ) then
     write (*,*) '--------------------------------------------'
     write (*, '(" nx = ",i4, 1x, "ny = ", i4, 1x, "nz = ", i4)') nx, ny, nz
     write (*, '(" xl = ", f6.2, 1x, "yl = ", f6.2, 1x, "zl = ", f6.2)') xl, yl, zl
     write (*, '(" nt = ", i6, 1x)') nt
     write (*, '(" tmax = ", f6.2)') tmax
     write (*, '(" viscosity = ", es11.4)') nu
     write (*,*) '--------------------------------------------'
     write (*, '(" calculate drag every", es11.4, " time steps")') tdrag
     write (*, '(" save fields every   ", es11.4)') tsave
     if (iSavePress == 1) write (*,*) 'save pressure'
     if (iSaveVelocity == 1) write (*,*) 'save velocity'
     if (iSaveVorticity == 1) write (*,*) 'save vorticity'
     if (iSaveMask == 1) write (*,*) 'save mask'
     if (iSaveSolidVelocity == 1) write (*,*) 'save mask velocity'
     write (*,*) '--------------------------------------------'
     if (iPenalization > 0) then 
        write (*,*) 'with obstacle'
        write (*, '(" x0 = ", f6.2, 1x, "y0 = ", f6.2, 1x, "z0 = ", f6.2, 1x, &
            & "size = ", f6.2)') x0, y0, z0, length
        write (*, '(" epsilon_eff   = ", es11.4)') eps * xl / real (nx)
        write (*, '(" epsilon       = ", es11.4)') eps
        write (*, '(" Ux = ", f6.2, " Uy = ", f6.2, " Uz = ", f6.2)') Ux, Uy, Uz
        write (*, '(" Ax = ", f6.2, " Ay = ", f6.2, " Az = ", f6.2)') Ax, Ay, Az
        write (*, '(" Re = ", es11.4)') sqrt(Ux**2+Uy**2+Uz**2) * length / nu
     else
        write (*,*) 'without obstacle'
     end if
     write (*,*) ' '
     write (*,*) '--------------------------------------------'
     write (*,*) ' '
  endif
  
  
end subroutine get_params

!--------------------------------------------------------


subroutine GetValue_Int (PARAMS, actual_lines, section, keyword, params_int, defaultvalue)
  use share_vars
  use mpi_header
  implicit none
  character section*(*)			! what section do you look for? for example [Resolution]
  character keyword*(*)			! what keyword do you look for? for example nx=128
  character (len=80)  value  		! returns the value
  character PARAMS(nlines)*256		! this is the complete PARAMS.ini file
  integer params_int, actual_lines, defaultvalue
  integer mpicode
  
  if (mpirank==0) then
  call GetValue(PARAMS, actual_lines, section, keyword, value)
  if (value .ne. '') then
    read (value, *) params_int         
  else
    write(*,'(A,i7)') &
    "??? WARNING: No value found for "//trim(keyword)//" in section "//trim(section)//" ----> default=",defaultvalue
    params_int = defaultvalue
  endif
  endif

  
end subroutine


!--------------------------------------------------------


subroutine GetValue_real (PARAMS, actual_lines, section, keyword, params_real, defaultvalue)
  use share_vars
  use mpi_header
  implicit none
  character section*(*)			! what section do you look for? for example [Resolution]
  character keyword*(*)			! what keyword do you look for? for example nx=128
  character (len=80)  value  		! returns the value
  character PARAMS(nlines)*256		! this is the complete PARAMS.ini file
  real (kind=pr) :: params_real, defaultvalue 
  integer actual_lines
  integer mpicode
  
  if (mpirank==0) then
  call GetValue(PARAMS, actual_lines, section, keyword, value)
  if (value .ne. '') then
    read (value, *) params_real        
  else
    write(*,'(A,es12.4)') &
    "??? WARNING: No value found for "//trim(keyword)//" in section "//trim(section)//" ----> default=", defaultvalue
    params_real = defaultvalue
  endif
  endif

  
end subroutine


!--------------------------------------------------------

subroutine GetValue (PARAMS, actual_lines, section, keyword, value)
  use share_vars
  use mpi_header
  implicit none
  character section*(*)			! what section do you look for? for example [Resolution]
  character keyword*(*)			! what keyword do you look for? for example nx=128
  character value*(*)			! returns the value
  character PARAMS(nlines)*256		! this is the complete PARAMS.ini file
  integer actual_lines			! how many lines did you actually read?  
  integer :: maxline = 256			! how many characters per line?
  integer i, j,k
  character line*256
  logical foundsection
  
  foundsection = .false.
  value = ''

  !------------------------------------------------------------------
  do i=1, actual_lines					! loop over the lines of PARAMS.ini file
  if ((PARAMS(i)(1:1).ne.'#').and.&
      (PARAMS(i)(1:1).ne.';').and.&
      (PARAMS(i)(1:1).ne.'!')) then			! ignore commented lines compleetly
  
  
      if (PARAMS(i)(1:1) == '[') then			! the first char would have to be '['
	  do j = 2, maxline				! then we look fot the corrresponding ']'
	    if (PARAMS(i)(j:j) == ']') then		! we found it
	      if (section == PARAMS(i)(2:j-1)) then	! is this the section we"re looking for?
		foundsection = .true.			! yes, it is
		exit
	      endif
	    endif
	  enddo	
      else      
	  if (foundsection .eqv. .true.) then		! yes we found the section, now we're looking for the keyword
	    do j=1, maxline				! scan the line
	      if (PARAMS(i)(j:j) == '=') then		! found the '='
	      if (keyword == PARAMS(i)(1:j-1)) then	! is this the keyword you're looking for?
		do k = j+1, maxline			! everything behind the '=' and before ';' is the value
		if (PARAMS(i)(k:k) == ';') then		! found the delimiter
		    value = PARAMS(i)(j+1:k-1)		! value is between '=', and ';'   
		    exit
		endif
		enddo
		if ((value == '').and.(mpirank==0)) then
		  write (*,'(A)') "??? Though found the keyword, I'm unable to find value for variable --> "& 
		               //trim(keyword)//" <-- maybe missing delimiter (;)?"		  
		endif
	      endif
	      endif
	    enddo
	  endif
      endif
      
      
  endif
  enddo
  !------------------------------------------------------------------
  
end subroutine getvalue

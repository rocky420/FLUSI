program FLUSI
  use mpi
  use fsi_vars
  implicit none
  integer :: mpicode
  character (len=strlen) :: infile

  ! Initialize MPI, get size and rank
  call MPI_INIT (mpicode)
  call MPI_COMM_SIZE (MPI_COMM_WORLD,mpisize,mpicode)
  call MPI_COMM_RANK (MPI_COMM_WORLD,mpirank,mpicode) 
  
  ! get filename of PARAMS file from command line
  call get_command_argument(1,infile)
  
  if ( index(infile,'.ini') .ne. 0) then  
      !-------------------------------------------------------------------------
      ! the file is an *.ini file -> we run a normal simulation 
      !-------------------------------------------------------------------------
      call Start_Simulation()    

  elseif ( infile == "--postprocess") then 
      !-------------------------------------------------------------------------
      ! the first argument tells us that we're postprocessing 
      !-------------------------------------------------------------------------
      call postprocessing()
      
  else
      if (mpirank==0) write(*,*) "nothing to do..."      
  endif

  
  call MPI_FINALIZE(mpicode)
  call exit(0)
end program FLUSI




subroutine Start_Simulation()
  use mpi
  use fsi_vars
  use p3dfft_wrapper
  use kine ! kinematics from file (Dmitry, 14 Nov 2013)
  implicit none
  real(kind=pr)          :: t1,t2
  real(kind=pr)          :: time,dt0,dt1,memory, mem_field
  integer                :: n0=0,n1=1,it
  character (len=strlen)     :: infile
  ! Arrays needed for simulation
  real(kind=pr),dimension(:,:,:,:),allocatable :: explin  
  real(kind=pr),dimension(:,:,:,:),allocatable :: u,vort
  real(kind=pr),dimension(:,:,:,:),allocatable :: work
  complex(kind=pr),dimension(:,:,:,:),allocatable :: uk
  ! complex work array, used for sponge and/or passive scalar
  complex(kind=pr),dimension(:,:,:,:),allocatable :: workc
  complex(kind=pr),dimension(:,:,:,:,:),allocatable :: nlk

  
  ! Set method information in vars module.
  method="fsi" ! We are doing fluid-structure interactions
  nf=1 ! We are evolving one field.
  nd=3*nf ! The one field has three components.
  neq=nd
  nrw=1 ! number of real valued work arrays
  ncw=0 ! number of complex values work arrays 

  ! initialize timing variables
  time_fft=0.0; time_ifft=0.0; time_vis=0.0; time_mask=0.0
  time_vor=0.0; time_curl=0.0; time_p=0.0; time_nlk=0.0; time_fluid=0.0
  time_bckp=0.0; time_save=0.0; time_total=MPI_wtime(); time_u=0.0; time_sponge=0.0
  time_insect_head=0.0; time_insect_body=0.0; time_insect_eye=0.0
  time_insect_wings=0.0; time_insect_vel=0.0; time_scalar=0.0

  
  ! Set up global communicators. We have two groups, for solid and fluid CPUs
  ! with dedicated tasks to do. For MHD, all CPU are reserved for the fluid
  call setup_fluid_solid_communicators( 0 )
  
  
  if (mpirank == 0) then
     write(*,'(A)') '--------------------------------------'
     write(*,'(A)') '  FLUSI'
     write(*,'(A)') '--------------------------------------'
     write(*,'("Running on ",i5," CPUs")') ncpu
     write(*,'("  Using ",i5," CPUs for fluid")') ncpu_fluid
     write(*,'("  Using ",i5," CPUs for solid")') ncpu_solid
     write(*,'(A)') '--------------------------------------'
  endif

  !-----------------------------------------------------------------------------
  ! Read input parameters
  !-----------------------------------------------------------------------------
  allocate(lin(nf)) ! Set up the linear term
  if (mpirank == 0) write(*,'(A)') '*** info: Reading input data...'
  ! get filename of PARAMS file from command line
  call get_command_argument(1,infile)
  ! read all parameters from that file
  call get_params(infile)
  
  !-----------------------------------------------------------------------------
  ! Initialize FFT (this also defines local array bounds for real and cmplx arrays)
  !-----------------------------------------------------------------------------  
  call fft_initialize 
  
  !-----------------------------------------------------------------------------
  ! Initialize time series output files, if not resuming a backup
  !-----------------------------------------------------------------------------
  if ((mpirank==0).and.(inicond(1:8).ne."backup::")) then 
    call initialize_time_series_files()
  endif
 
  ! Print domain decomposition
  call print_domain_decomposition()

  !-----------------------------------------------------------------------------
  ! Allocate memory:
  !-----------------------------------------------------------------------------
  ! reserve additional space for scalars?
  if (use_passive_scalar==1) then
    neq = neq + n_scalars
    compute_scalar=.true.
  endif
  
  mem_field = dble(nx)*dble(ny)*dble(nz)*8.0
  memory = 0.0
  
  allocate(explin(ca(1):cb(1),ca(2):cb(2),ca(3):cb(3),1:nf))
  memory = memory + dble(nf)*mem_field
  
  ! velocity in Fourier space
  allocate(uk(ca(1):cb(1),ca(2):cb(2),ca(3):cb(3),1:neq))
  memory = memory + dble(nd)*mem_field
  
  ! right hand side of navier-stokes
  allocate(nlk(ca(1):cb(1),ca(2):cb(2),ca(3):cb(3),1:neq,0:1))
  memory = memory + 2.0*dble(nd)*mem_field
  
  ! velocity in physical space
  allocate(u(ra(1):rb(1),ra(2):rb(2),ra(3):rb(3),1:nd))
  memory = memory + dble(nd)*mem_field
  
  ! vorticity in physical space
  allocate(vort(ra(1):rb(1),ra(2):rb(2),ra(3):rb(3),1:nd))   
  memory = memory + dble(nd)*mem_field
  
  ! real valued work array(s)
  ! allocate one work array
  nrw = 1
  
  allocate(work(ra(1):rb(1),ra(2):rb(2),ra(3):rb(3),1:nrw))
  memory = memory + dble(nrw)*mem_field
  
  ! mask function (defines the geometry)
  allocate(mask(ra(1):rb(1),ra(2):rb(2),ra(3):rb(3)))  
  memory = memory + mem_field
  
  ! mask color function (distinguishes between different parts of the mask)
  allocate(mask_color(ra(1):rb(1),ra(2):rb(2),ra(3):rb(3)))
  memory = memory + mem_field/4.d0
  
  ! solid body velocities
  allocate(us(ra(1):rb(1),ra(2):rb(2),ra(3):rb(3),1:nd)) 
  memory = memory + dble(nd)*mem_field
  
  ! vorticity sponge, work array that is used for sponge and/or passive scalar
  if (iVorticitySponge=="yes") then
    ncw = 3
  else
    if (use_passive_scalar==1) ncw = 1
  endif
  allocate (workc(ca(1):cb(1),ca(2):cb(2),ca(3):cb(3),1:ncw) )
  
  ! Load kinematics from file (Dmitry, 14 Nov 2013)
  if (Insect%KineFromFile/="no") then
     call load_kine_init(mpirank,MPI_DOUBLE_PRECISION,MPI_INTEGER)
  endif
  
  ! If required, initialize rigid solid dynamics solver
  ! and set idynamics flag on or off
  call rigid_solid_init(SolidDyn%idynamics)

  ! show memory consumption for information
  if (mpirank==0) then
    write(*,'(80("-"))')
    write(*,'("FLUSI allocated ",f7.1,"MB (",f5.1,"GB) of memory in total")')&
    memory/(1.0d6),memory/(1.0d9)
    write(*,'("which is ",f7.1,"MB (",f4.1,"GB) per CPU")') &
    memory/(1.0d6)/dble(mpisize),memory/(1.0d9)/dble(mpisize)
    write(*,'(80("-"))')
  endif
  
  !-----------------------------------------------------------------------------
  ! check if at least FFT works okay
  !-----------------------------------------------------------------------------
  call fft_unit_test(work(:,:,:,1),uk(:,:,:,1))
  
  !-----------------------------------------------------------------------------
  ! Initial condition
  !-----------------------------------------------------------------------------
  if (mpirank == 0) write(*,*) "Set up initial conditions...."
  call init_fields(n1,time,it,dt0,dt1,uk,nlk,vort,explin,workc)
  n0=1 - n1 !important to do this now in case we're retaking a backp
  
  !-----------------------------------------------------------------------------
  ! Masks for startup
  !-----------------------------------------------------------------------------  
  if (mpirank == 0) write(*,*) "Create mask variables...."
  ! Create mask function:
  call create_mask(time)
  call update_us(u)

  !*****************************************************************************
  ! Step forward in time
  !*****************************************************************************
  t1 = MPI_wtime()
  call time_step(u,uk,nlk,vort,work,workc,explin,infile,time,dt0,dt1,n0,n1,it)
  t2 = MPI_wtime() - t1
  
  !-----------------------------------------------------------------------------
  ! Deallocate memory
  !-----------------------------------------------------------------------------
  deallocate(lin)
  deallocate(explin)
  deallocate(vort,work,workc)
  deallocate(u,uk,nlk)
  deallocate(us)
  deallocate(mask)
  deallocate(mask_color)
  ! Clean kinematics (Dmitry, 14 Nov 2013)
  if (Insect%KineFromFile/="no") call load_kine_clean
  
  call fft_free 
  !-------------------------
  ! Show the breakdown of timing information
  !-------------------------
  if (mpirank == 0) call show_timings(t2)
end subroutine Start_Simulation




! Output information on where the algorithm spent the most time.
subroutine show_timings(t2)
  use fsi_vars
  implicit none

  real (kind=pr) :: t2,tmp

  write(*,'(A)') '--------------------------------------'
  write(*,'(A)') '*** Timings'
  write(*,'(A)') '--------------------------------------'
  write(*,'("of the total time ",es12.4,", FLUSI spend ",es12.4," (",f5.1,"%) on FFTS")') &
       t2, time_fft+time_ifft,100.0*(time_fft+time_ifft)/t2 
  write(*,'(A)') '--------------------------------------'
  write(*,'("Time Stepping contributions:")')
  write(*,'("Fluid      : ",es12.4," (",f5.1,"%)")') time_fluid, 100.0*time_fluid/t2
  write(*,'("Mask       : ",es12.4," (",f5.1,"%)")') time_mask, 100.0*time_mask/t2
  write(*,'("Save Fields: ",es12.4," (",f5.1,"%)")') time_save, 100.0*time_save/t2
  write(*,'("Backuping  : ",es12.4," (",f5.1,"%)")') time_bckp, 100.0*time_bckp/t2
  tmp = t2 - (time_fluid + time_mask + time_save + time_bckp + time_save)
  write(*,'("Misc       : ",es12.4," (",f5.1,"%)")') tmp, 100.0*tmp/t2
  write(*,'(A)') '--------------------------------------'
  write(*,'(A)') "The time spend for the fluid decomposes into:"
  write(*,'("cal_nlk: ",es12.4," (",f5.1,"%)")') time_nlk, 100.0*time_nlk/time_fluid
  write(*,'("cal_vis: ",es12.4," (",f5.1,"%)")') time_vis, 100.0*time_vis/time_fluid
  tmp = time_fluid - time_nlk - time_vis
  write(*,'("misc:  ",es12.4," (",f5.1,"%)")') tmp, 100.0*tmp/time_fluid
  write(*,'(A)') '--------------------------------------'
  if (use_passive_scalar==1) then
  write(*,'("passive scalar : ",es12.4," (",f5.1,"%)")') time_scalar, 100.0*time_scalar/t2
  write(*,'(A)') '--------------------------------------'
  endif
  write(*,'(A)') "cal_nlk decomposes into:"
  write(*,'("ifft(uk)       : ",es12.4," (",f5.1,"%)")') time_u, 100.0*time_u/time_nlk
  write(*,'("curl(uk)       : ",es12.4," (",f5.1,"%)")') time_vor, 100.0*time_vor/time_nlk
  write(*,'("vor x u - chi*u: ",es12.4," (",f5.1,"%)")') time_curl, 100.0*time_curl/time_nlk
  write(*,'("projection     : ",es12.4," (",f5.1,"%)")') time_p, 100.0*time_p/time_nlk
  write(*,'("sponge         : ",es12.4," (",f5.1,"%)")') time_sponge, 100.0*time_sponge/time_nlk
  tmp = time_nlk - time_u - time_vor - time_curl - time_p  
  write(*,'("Misc           : ",es12.4," (",f5.1,"%)")') tmp, 100.0*tmp/time_nlk
  write (*,'(A)') "cal_nlk: FFTs and local operations:"
  write(*,'("FFTs           : ",es12.4," (",f5.1,"%)")') time_nlk_fft, 100.0*time_nlk_fft/time_nlk
  tmp = time_nlk-time_nlk_fft
  write(*,'("local          : ",es12.4," (",f5.1,"%)")') tmp, 100.0*tmp/time_nlk
  if (iMask=="Insect") then
  write(*,'(A)') '--------------------------------------'
  write(*,'(A)') 'Insect mask generation decomposes into:'
  write(*,'("Body : ",es12.4," (",f5.1,"%)")') time_insect_body, 100.0*time_insect_body/time_mask
  write(*,'("Eyes : ",es12.4," (",f5.1,"%)")') time_insect_eye,  100.0*time_insect_eye/time_mask
  write(*,'("Head : ",es12.4," (",f5.1,"%)")') time_insect_head, 100.0*time_insect_head/time_mask
  write(*,'("Wings: ",es12.4," (",f5.1,"%)")') time_insect_wings,100.0*time_insect_wings/time_mask  
  write(*,'("veloc: ",es12.4," (",f5.1,"%)")') time_insect_vel,  100.0*time_insect_vel/time_mask  
  write(*,'(A)') '--------------------------------------'
  endif
  write(*,'(A)') '--------------------------------------'
  write(*,'(A)') 'Finalizing computation....'
  write(*,'(A)') '--------------------------------------'
end subroutine show_timings



subroutine initialize_time_series_files()
  use fsi_vars
  implicit none
  tab = char(9) ! set horizontal tab character 
  
  ! For insect wing/body forces
  if (iMask=='Insect') then
  open  (14,file='forces.t',status='replace')
    write (14,'(27A)') "% time",tab,"Forcex",tab,"Forcey",tab,"Forcez",tab,&
                      "Forcex_unst",tab,"Forcey_unst",tab,"Forcez_unst",tab,&
                      "Momentx",tab,"Momenty",tab,"Momentz",tab,&
                      "Momentx_unst",tab,"Momenty_unst",tab,"Momentz_unst",tab,&
                      "Aero_Power"
    close (14)
    open  (14,file='forces_part1.t',status='replace')
    write (14,'(27A)') "% time",tab,"Forcex",tab,"Forcey",tab,"Forcez",tab,&
                      "Forcex_unst",tab,"Forcey_unst",tab,"Forcez_unst",tab,&
                      "Momentx",tab,"Momenty",tab,"Momentz",tab,&
                      "Momentx_unst",tab,"Momenty_unst",tab,"Momentz_unst",tab,&
                      "Aero_Power"
    close (14)
    open  (14,file='forces_part2.t',status='replace')
    write (14,'(27A)') "% time",tab,"Forcex",tab,"Forcey",tab,"Forcez",tab,&
                      "Forcex_unst",tab,"Forcey_unst",tab,"Forcez_unst",tab,&
                      "Momentx",tab,"Momenty",tab,"Momentz",tab,&
                      "Momentx_unst",tab,"Momenty_unst",tab,"Momentz_unst",tab,&
                      "Aero_Power"
    close (14)
    open  (14,file='forces_part3.t',status='replace')
    write (14,'(27A)') "% time",tab,"Forcex",tab,"Forcey",tab,"Forcez",tab,&
                      "Forcex_unst",tab,"Forcey_unst",tab,"Forcez_unst",tab,&
                      "Momentx",tab,"Momenty",tab,"Momentz",tab,&
                      "Momentx_unst",tab,"Momenty_unst",tab,"Momentz_unst",tab,&
                      "Aero_Power"
    close (14)
    open  (14,file='kinematics.t',status='replace')
    write (14,'(27A)') "% time",tab,"xc_body",tab,"yc_body",tab,"zc_body",tab,&
                      "psi",tab,"beta",tab,"gamma",tab,"eta_stroke",tab,&
                      "alpha_l",tab,"phi_l",tab,"theta_l",tab,&
                      "alpha_r",tab,"phi_r",tab,"theta_r"
    close (14)
  ! If this is not an insect
  else 
    open  (14,file='forces.t',status='replace')
    write (14,'(25A)') "% time",tab,"Forcex",tab,"Forcey",tab,"Forcez",tab,&
                      "Forcex_unst",tab,"Forcey_unst",tab,"Forcez_unst",tab,&
                      "Momentx",tab,"Momenty",tab,"Momentz",tab,&
                      "Momentx_unst",tab,"Momenty_unst",tab,"Momentz_unst"
    close (14)
  endif    

  open  (14,file='divu.t',status='replace')
  write (14,'(13A)') "% time",tab,"max(divu)",tab
  close (14)
  
  ! this file contains, time, iteration#, time step and performance
  open  (14,file='timestep.t',status='replace')
  close (14)    
  
  open  (14,file='meanflow.t',status='replace')
  close (14)  
  
end subroutine




subroutine print_domain_decomposition()
  use fsi_vars
  use mpi
  implicit none
  integer :: mpicode
  
  
  if (mpirank == 0) then
     write(*,'(A)') '--------------------------------------'
     write(*,'(A)') '*** Domain decomposition:'
     write(*,'(A)') '--------------------------------------'
  endif
  call MPI_barrier (MPI_COMM_world, mpicode)
  write (*,'("mpirank=",i5," x-space=(",i4,":",i4," |",i4,":",i4," |",i4,":",i4,&
       &") k-space=(",i4,":",i4," |",i4,":",i4," |",i4,":",i4,")")') &
       mpirank, ra(1),rb(1), ra(2),rb(2),ra(3),rb(3), ca(1),cb(1), ca(2),cb(2),ca(3),cb(3)
  call MPI_barrier (MPI_COMM_world, mpicode)
end subroutine 
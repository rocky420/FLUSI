!=========================================================
!      Collect the data from files
!      produced with HIVE parallel code
!      and save them in a binary file
!=========================================================

program convert_mpiio
  use mpi
  implicit none

  integer, parameter :: pr_in = 8, pr_out = 4 ! precision for input and output (INPUT PRECISION MUST BE KNOWN!!!)
  integer, parameter :: mpireal = MPI_DOUBLE_PRECISION  ! double precision array for input
  integer, dimension(MPI_STATUS_SIZE) :: mpistatus
  integer :: nx, ny, nz, filedesc, mpicode
  integer :: ix, iy, iz, iSaveAscii
  real (kind=pr_in ), dimension (:,:,:), allocatable :: field_in
  real (kind=pr_out), dimension (:,:,:), allocatable :: field_out
  character (len=128) :: fname, nx_str, ny_str, nz_str, ascii_str
  logical :: file_exists

  !--------------------------------------------------
  ! read in command line arguments
  !--------------------------------------------------  
  call get_command_argument(1, fname)
  if (len_trim(fname)==0) then
    write (*,*) "You forgot to tell me which file to process..."
    call Help
    stop
  endif

  call get_command_argument(2, nx_str)
  if  (len_trim(nx_str).ne.0) then
    read (nx_str, *) nx
  else
    write (*,*) "I'm confused... whats nx?"
    call Help
    stop    
  endif
  
  call get_command_argument(3, ny_str)
  if  (len_trim(ny_str).ne.0) then
    read (ny_str, *) ny
  else
    write (*,*) "I'm confused... whats ny?"
    call Help
    stop    
  endif
  
  call get_command_argument(4, nz_str)
  if  (len_trim(nz_str).ne.0) then
    read (nz_str, *) nz
  else
    write (*,*) "I'm confused... whats nz?"
    call Help
    stop    
  endif
  
  call get_command_argument(5, ascii_str)
  if  (len_trim(ascii_str).ne.0) then
    read (ascii_str, *) iSaveAscii
  else
    write (*,*) "As you didn't tell me whether or not to write a *.ascii file also, I've decided not to do it."
    iSaveAscii = 0
  endif
  
  
  !--------------------------------------------------
  ! check if desired file exists
  !--------------------------------------------------
  inquire(file=trim(fname)//'.mpiio',exist=file_exists)   
  if (file_exists .eqv. .false.) then
    write (*,'("ERROR!! File ",A,".mpiio NOT found")') trim(fname)
    stop
  endif
  
  allocate ( field_in(0:(nx-1),0:(ny-1),0:(nz-1)), field_out(0:(nx-1),0:(ny-1),0:(nz-1)) )
 
  !--------------------------------------------------
  ! read MPI data
  !-------------------------------------------------- 
  call MPI_INIT (mpicode)
  call MPI_FILE_OPEN (MPI_COMM_WORLD,trim(fname)//'.mpiio',MPI_MODE_RDONLY,MPI_INFO_NULL,filedesc,mpicode)
  call MPI_FILE_READ_ORDERED (filedesc,field_in,nx*ny*nz,mpireal,mpistatus,mpicode)
  call MPI_FILE_CLOSE (filedesc,mpicode)

  write(*,'("Converting ",A,".mpiio  -> ",A,".binary Min:Max=",es12.4,":",es12.4,1x,"nx:ny:nz=",i3,":",i3,":",i3)') &
  trim(fname), trim(fname), minval (field_in), maxval (field_in),nx,ny,nz
  
  
  field_out = real(field_in, kind=pr_out)  ! convert field to output precision
  ! ------------------------------------
  ! Write *,binary file (for vapor et al)
  ! ------------------------------------
  open (12, file = trim(fname)//".binary", form='unformatted', status='replace')
  write (12) (((field_out (ix,iy,iz), ix=0, nx-1), iy=0, ny-1), iz=0, nz-1)
  close (12)

  ! ------------------------------------
  ! Write *,ascii file (for matlab)
  ! ------------------------------------
  if (iSaveAscii ==1) then
      write(*,'("Converting ",A,".mpiio  -> ",A,".ascii")') trim(fname), trim(fname)
      open (11, file = trim(fname)//".ascii", form='formatted', status='replace')
      do ix = 0,nx-1
      do iy = 0,ny-1
      do iz = 0,nz-1
      write (11,'(es15.8)') field_out (ix,iy,iz) !es15.8 defines output precision
      enddo
      enddo
      enddo
      close (11)
  endif

  deallocate ( field_in, field_out )

  
  call MPI_FINALIZE (mpicode)

end program convert_mpiio


subroutine help
  write (*,*) "--------------------------------------------------------------"
  write (*,*) "		converter "
  write (*,*) " *.mpiio -> *.binary and/or *.ascii"
  write (*,*) "--------------------------------------------------------------"
  write (*,*) "  usage: ./convert_mpiio filename nx ny nz iAscii"
  write (*,*) ""
  write (*,*) " [filename]: the base file name WITHOUT the .mpiio suffix"
  write (*,*) " [nx, ny, nz] is the resolution"
  write (*,*) " [iAscii] : 0=Don't save *.ascii, 1= do so"
  write (*,*) "  iascii is optional"
  write (*,*) "--------------------------------------------------------------"

end subroutine


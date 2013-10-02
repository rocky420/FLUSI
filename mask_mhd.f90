! MHD wrapper for different mask functions 
subroutine create_mask_mhd()
  use mpi_header
  use mhd_vars
  implicit none

  mask=0.d0
  if(iPenalization == 1) then
     select case (iMask)
     case("TaylorCouette")
        call  tc_mask_mhd()
     case("smc")
        call smc_mask_mhd()
     case("smclinear")
        call smc_mask_mhd()
     case("smcflat")
        call smc_mask_mhd()
     case default
        if(mpirank == 0) then
           write (*,*) &
                "iMask not properly set for mhd in create_mask_mhd; stopping."
           stop
        endif
     end select
  endif
end subroutine create_mask_mhd


! MHD wrapper for setting (possibly velocity-dependent) imposed field.
subroutine update_us_mhd(ub)
  use mpi_header
  use mhd_vars
  implicit none

  real(kind=pr),intent(in)::ub(ra(1):rb(1),ra(2):rb(2),ra(3):rb(3),1:nd)

  if(iPenalization == 1) then
     select case (iMask)
     case("TaylorCouette")
        call tc_us_mhd(ub)
     case("smc")
        call smc_us_mhd(ub)
     case("smclinear")
        call smclinear_us_mhd(ub)
     case("smcflat")
        call smcflat_us_mhd(ub)
     case default
        if(mpirank == 0) then
           write (*,*) &
                "iMask not properly set for mhd in update_us_mhd; stopping."
           stop
        endif
     end select
  endif
end subroutine update_us_mhd


! Set the solid velocity for MHD Taylor-Couette flow.
subroutine tc_us_mhd(ub)
  use mpi_header
  use mhd_vars
  implicit none
  
  real(kind=pr),intent(in)::ub(ra(1):rb(1),ra(2):rb(2),ra(3):rb(3),1:nd)
  real (kind=pr) :: r, x, y
  integer :: ix, iy, iz
  
  us=0.d0

  ! Set the velocity field to be the steady-state solution:
  call taylor_couette_u_us(us(:,:,:,1),us(:,:,:,2),us(:,:,:,3))

  do ix=ra(1),rb(1)  
     x=xl*(dble(ix)/dble(nx) -0.5d0)
     do iy=ra(2),rb(2)
        y=yl*(dble(iy)/dble(ny) -0.5d0)

        r=dsqrt(x*x + y*y)
        
        if(r <= R1) then
           do iz=ra(3),rb(3)
              ! Magnetic field:
              us(ix,iy,iz,4)=0.d0
              us(ix,iy,iz,5)=0.d0
              ! FIXME: non-penetration for b?
!!$              us(ix,iy,iz,4)=-omega1*y
!!$              us(ix,iy,iz,5)=omega1*x
           enddo
        endif
        if(r >= R2) then
           do iz=ra(3),rb(3)
              ! NB: We assume that the outer wall is not moving.
              ! Magnetic field: 
              ! FIXME: non-penetration for b?
              us(ix,iy,iz,4)=0.d0
              us(ix,iy,iz,5)=0.d0
           enddo
        endif
     enddo
  enddo

  ! Always penalize the z-component to the axial field.
  us(:,:,:,6)=B0 
end subroutine tc_us_mhd


! Set the mask function for MHD Taylor-Couette flow.
subroutine tc_mask_mhd()
  use mpi_header
  use mhd_vars
  implicit none
  
  real (kind=pr) :: r,x,y
  integer :: ix,iy,iz

  mask=0.d0

  do ix=ra(1),rb(1)  
     x=xl*(dble(ix)/dble(nx) -0.5d0)
     do iy=ra(2),rb(2)
        y=yl*(dble(iy)/dble(ny) -0.5d0)

        r=dsqrt(x*x + y*y)

        if(r <= R1 .or. r >= R2) then
           do iz=ra(3),rb(3)
              mask(ix,iy,iz)=1.d0
           enddo
        endif

     enddo
  enddo
end subroutine tc_mask_mhd


! Set the mask function for Sean-Montgomery-Chen flow.
subroutine smc_mask_mhd()
  use mpi_header
  use mhd_vars
  implicit none
  
  real (kind=pr) :: r, x, y
  integer :: ix, iy, iz

  mask=0.d0

  do ix=ra(1),rb(1)  
     x=xl*(dble(ix)/dble(nx) -0.5d0)
     do iy=ra(2),rb(2)
        y=yl*(dble(iy)/dble(ny) -0.5d0)

        r=dsqrt(x*x +y*y)

        if(r >= R1) then
           do iz=ra(3),rb(3)
              mask(ix,iy,iz)=1.d0
           enddo
        endif

     enddo
  enddo
end subroutine smc_mask_mhd


! Set the solid velocity for Sean-Montgomery-Chen flow.
subroutine smc_us_mhd(ub)
  use mpi_header
  use mhd_vars
  implicit none
  
  real(kind=pr),intent(in)::ub(ra(1):rb(1),ra(2):rb(2),ra(3):rb(3),1:nd)
  real (kind=pr) :: r,x,y
  integer :: ix,iy,iz
  real (kind=pr) :: a,b,c,d,k1,k2,h
  
  ! Velocity is no-slip:
  us(:,:,:,1)=0.d0
  us(:,:,:,2)=0.d0
  us(:,:,:,3)=0.d0

  us(:,:,:,4)=0.d0
  us(:,:,:,5)=0.d0
  us(:,:,:,6)=B0

  k1=Bc*r2/r1
  k2=Bc/r1
  A=(2.d0*k1 -k2*(r2-r3))/(r3*r3*r3 -3.d0*r2*r3*r3 +3.d0*r2*r2*r3 -r2*r2*r2)
  B=(k2 -3.d0*A*(r2*r2 -r3*r3))/(2.d0*r2 -2.d0*r3)
  C=-3.d0*A*r3*r3 -2.d0*B*r3
  D=2.d0*A*r3*r3*r3 +B*r3*r3

  do ix=ra(1),rb(1)
     x=xl*(dble(ix)/dble(nx) -0.5d0)
     do iy=ra(2),rb(2)
        y=yl*(dble(iy)/dble(ny) -0.5d0)

        r=dsqrt(x*x +y*y)
        
        ! Linear profile:
        if(r >= r1 .and. r < r2) then
           do iz=ra(3),rb(3)
              us(ix,iy,iz,4)=-Bc*y/r1
              us(ix,iy,iz,5)=Bc*x/r1
           enddo
        endif
        
        ! Hermite profile:
        if(r >= r2 .and. r <= r3) then
           h=(A*r*r*r +B*r*r +C*r +D)
           do iz=ra(3),rb(3)
              us(ix,iy,iz,4)=-h*y/r
              us(ix,iy,iz,5)=h*x/r
           enddo
        endif
        
     enddo
  enddo
end subroutine smc_us_mhd


! Set the solid velocity for Sean-Montgomery-Chen flow.
subroutine smclinear_us_mhd(ub)
  use mpi_header
  use mhd_vars
  implicit none
  
  real(kind=pr),intent(in)::ub(ra(1):rb(1),ra(2):rb(2),ra(3):rb(3),1:nd)
  real (kind=pr) :: r,x,y
  integer :: ix,iy,iz
  real (kind=pr) :: a,b,c,d,k1,k2
  
  ! Velocity is no-slip:
  us(:,:,:,1)=0.d0
  us(:,:,:,2)=0.d0
  us(:,:,:,3)=0.d0

  us(:,:,:,4)=0.d0
  us(:,:,:,5)=0.d0
  us(:,:,:,6)=B0

  k1=Bc*r2/r1
  k2=Bc/r1
  A=(2.d0*k1 -k2*(r2-r3))/(r3*r3*r3 -3.d0*r2*r3*r3 +3.d0*r2*r2*r3 -r2*r2*r2)
  B=(k2 -3.d0*A*(r2*r2 -r3*r3))/(2.d0*r2 -2.d0*r3)
  C=-3.d0*A*r3*r3 -2.d0*B*r3
  D=2.d0*A*r3*r3*r3 +B*r3*r3

  do ix=ra(1),rb(1)  
     x=xl*(dble(ix)/dble(nx) -0.5d0)
     do iy=ra(2),rb(2)
        y=yl*(dble(iy)/dble(ny) -0.5d0)

        r=dsqrt(x*x +y*y)
        
        ! Linear profile:
        if(r >= r1 .and. r < r2) then
           do iz=ra(3),rb(3)
              us(ix,iy,iz,4)=-Bc*y/r1
              us(ix,iy,iz,5)=Bc*x/r1
           enddo
        endif
        
     enddo
  enddo
end subroutine smclinear_us_mhd


! Set the solid velocity for Sean-Montgomery-Chen flow.
subroutine smcflat_us_mhd(ub)
  use mpi_header
  use mhd_vars
  implicit none
  
  real(kind=pr),intent(in)::ub(ra(1):rb(1),ra(2):rb(2),ra(3):rb(3),1:nd)
  real (kind=pr) :: r,x,y
  integer :: ix,iy,iz
  real (kind=pr) :: a,b,c,d,k1,k2
  
  ! Velocity is no-slip:
  us(:,:,:,1)=0.d0
  us(:,:,:,2)=0.d0
  us(:,:,:,3)=0.d0

  us(:,:,:,4)=0.d0
  us(:,:,:,5)=0.d0
  us(:,:,:,6)=B0

  k1=Bc*r2/r1
  k2=Bc/r1
  A=(2.d0*k1 -k2*(r2-r3))/(r3*r3*r3 -3.d0*r2*r3*r3 +3.d0*r2*r2*r3 -r2*r2*r2)
  B=(k2 -3.d0*A*(r2*r2 -r3*r3))/(2.d0*r2 -2.d0*r3)
  C=-3.d0*A*r3*r3 -2.d0*B*r3
  D=2.d0*A*r3*r3*r3 +B*r3*r3

  do ix=ra(1),rb(1)  
     x=xl*(dble(ix)/dble(nx) -0.5d0)
     do iy=ra(2),rb(2)
        y=yl*(dble(iy)/dble(ny) -0.5d0)

        r=dsqrt(x*x +y*y)
        
        ! Linear profile:
        if(r >= r1 .and. r < r2) then
           do iz=ra(3),rb(3)
              us(ix,iy,iz,4)=-Bc
              us(ix,iy,iz,5)=Bc
           enddo
        endif
        
     enddo
  enddo
end subroutine smcflat_us_mhd

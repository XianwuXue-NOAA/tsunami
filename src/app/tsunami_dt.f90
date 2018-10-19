program tsunami_dt

  ! Tsunami simulator.
  !
  ! Solves the non-linear 2-d shallow water equation system:
  !
  !     du/dt + u du/dx + v du/dy + g dh/dx = 0
  !     dv/dt + u dv/dx + v dv/dy + g dh/dy = 0
  !     dh/dt + d(hu)/dx + d(hv)/dy = 0
  !
  ! This version is parallelized, and uses derived types.

  use iso_fortran_env, only: output_unit

  use mod_diagnostics, only: mean
  use mod_diff, only: diffx => diffc_2d_x, diffy => diffc_2d_y
  use mod_field, only: Field
  use mod_io, only: write_field
  use mod_kinds, only: ik, rk
  use mod_parallel, only: tile_indices, sync_edges

  implicit none

  integer(ik) :: i, j, n

  integer(ik), parameter :: im = 101 ! grid size in x
  integer(ik), parameter :: jm = 101 ! grid size in y
  integer(ik), parameter :: nm = 1000 ! number of time steps

  real(rk), parameter :: dt = 0.02 ! time step [s]
  real(rk), parameter :: dx = 1 ! grid spacing [m]
  real(rk), parameter :: dy = 1 ! grid spacing [m]

  real(rk), parameter :: g = 9.8 ! gravitational acceleration [m/s]

  real(rk), allocatable :: h(:,:), u(:,:), v(:,:)
  real(rk), allocatable :: gather(:,:)[:]
  real(rk), allocatable :: hm(:,:)

  integer(ik), parameter :: ic = 51, jc = 51
  real(rk), parameter :: decay = 0.02

  integer(ik) :: is, ie, js, je ! global start and end indices
  integer(ik) :: indices(4)

  type(Field) :: hh, uu, vv, hhm

  if (this_image() == 1) print *, 'Tsunami started'

  uu = Field('x-component of velocity', [im, jm])
  vv = Field('y-component of velocity', [im, jm])
  hh = Field('Water height displacement', [im, jm])
  hhm = Field('Mean water height', [im, jm])

  allocate(gather(im, jm)[*])

  ! initialize a gaussian blob centered at i = 25
  call hh % init_gaussian(decay, ic, jc)
  call hh % sync_edges()

  ! set initial velocity and mean water depth
  uu = 0.
  vv = 0.
  hhm = 10.

  stop

  ! gather to image 1 and write water height to file
  gather(is:ie, js:je)[1] = h(is:ie, js:je)
  sync all
  n = 0
  if (this_image() == 1) then
    print *, n, mean(gather)
    call write_field(gather, 'h', n)
  end if

  time_loop: do n = 1, nm

    call sync_edges(h, indices)

    ! compute u at next time step
    u = u - (u * diffx(u) / dx + v * diffy(u) / dy &
      + g * diffx(h) / dx) * dt

    ! compute v at next time step
    v = v - (u * diffx(v) / dx + v * diffy(v) / dy &
      + g * diffy(h) / dy) * dt

    call sync_edges(u, indices)
    call sync_edges(v, indices)

    ! compute h at next time step
    h = h - (diffx(u * (hm + h)) / dx + diffy(v * (hm + h)) / dy) * dt

    ! gather to image 1 and write water height to file
    gather(is:ie, js:je)[1] = h(is:ie, js:je)
    sync all
    if (this_image() == 1) then
      print *, n, mean(gather)
      call write_field(gather, 'h', n)
    end if

  end do time_loop

end program tsunami_dt
"""
Example using 2 processors 

Run from terminal using >> mpiexecjl --project=. -np 2 julia examples/example2.jl
"""

using Mist

# Define parameters 
param = parameters(
    # Constants
    mu_liq=0.1,       # Dynamic viscosity
    mu_gas=0.1,       # Dynamic viscosity
    rho_liq=1.0,           # Density
    rho_gas=1.0,           # Density
    sigma = 0.0,
    gravity = 0.0,
    Lx=3.0,            # Domain size
    Ly=3.0,
    Lz=3.0,
    tFinal=100.0,      # Simulation time
    
    # Discretization inputs
    Nx=20,           # Number of grid cells
    Ny=20,
    Nz=10,
    stepMax=20,   # Maximum number of timesteps
    CFL=0.1,         # Courant-Friedrichs-Lewy (CFL) condition for timestep
    out_period=10,     # Number of steps between when plots are updated
    tol = 1e-3,

    # Processors 
    nprocx = 2,
    nprocy = 1,
    nprocz = 1,

    # Periodicity
    xper = false,
    yper = false,
    zper = false,

    VTK_dir = "VTK_example2",
)

"""
Initial conditions for pressure and velocity
"""
function IC!(P,u,v,w,VF,mesh)
    @unpack imin_,imax_,jmin_,jmax_,kmin_,kmax_,
                xm,ym,zm,Lx,Ly,Lz = mesh
    # Pressure
    fill!(P,0.0)

    # Velocity
    for k = kmin_:kmax_, j = jmin_:jmax_, i = imin_:imax_ 
        u[i,j,k] = 0.0 #-(ym[j] - Ly/2.0)
        v[i,j,k] = 0.0 # (xm[i] - Lx/2.0)
        w[i,j,k] = 0.0
    end

    # Volume Fraction
    fill!(VF,0.0)

    return nothing    
end

"""
Boundary conditions for velocity
"""
function BC!(u,v,w,t,mesh,par_env)
    @unpack irankx, iranky, irankz, nprocx, nprocy, nprocz = par_env
    @unpack imin,imax,jmin,jmax,kmin,kmax = mesh
    
     # Left 
     if irankx == 0 
        i = imin-1
        u[i,:,:] = -u[imin,:,:] # No flux
        v[i,:,:] = -v[imin,:,:] # No slip
        w[i,:,:] = -w[imin,:,:] # No slip
    end
    # Right
    vright=1.0
    if irankx == nprocx-1
        i = imax+1
        u[i,:,:] = -u[imax,:,:] # No flux
        v[i,:,:] = -v[imax,:,:] .+ 2vright # No slip
        w[i,:,:] = -w[imax,:,:] # No slip
    end
    # Bottom 
    if iranky == 0 
        j = jmin-1
        u[:,j,:] = -u[:,jmin,:] # No slip
        v[:,j,:] = -v[:,jmin,:] # No flux
        w[:,j,:] = -w[:,jmin,:] # No slip
    end
    # Top
    utop=0.0
    if iranky == nprocy-1
        j = jmax+1
        u[:,j,:] = -u[:,jmax,:] .+ 2utop # No slip
        v[:,j,:] = -v[:,jmax,:] # No flux
        w[:,j,:] = -w[:,jmax,:] # No slip
    end
    # Back 
    if irankz == 0 
        k = kmin-1
        u[:,:,k] = -u[:,:,kmin] # No slip
        v[:,:,k] = -v[:,:,kmin] # No slip
        w[:,:,k] = -w[:,:,kmin] # No flux
    end
    # Front
    if irankz == nprocz-1
        k = kmax+1
        u[:,:,k] = -u[:,:,kmax] # No slip
        v[:,:,k] = -v[:,:,kmax] # No slip
        w[:,:,k] = -w[:,:,kmax] # No flux
    end

    return nothing
end


"""
Define area of outflow region
"""
function outflow_correction!(correction,uf,vf,wf,mesh,par_env)
    # Do nothing - no inflow/outflow
end

"""
Define area of outflow region
"""
function outflow_area(mesh,par_env)
    # Do nothing - no inflow/outflow
end
outflow =(area=outflow_area,correction=outflow_correction!)

# Simply run solver on 1 processor
run_solver(param, IC!, BC!,outflow)
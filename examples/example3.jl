"""
Example using inflow/outflow
"""

using Mist

# Define parameters 
param = parameters(
    # Constants
    mu_liq=10.0,       # Dynamic viscosity
    mu_gas=10.0,       # Dynamic viscosity
    rho_liq=1.0,           # Density
    rho_gas=1.0,           # Density
    sigma = 0.0,
    gravity = 0.0,
    Lx=3.0,            # Domain size
    Ly=3.0,
    Lz=3.0,
    tFinal=1.0,      # Simulation time
    
    # Discretization inputs
    Nx=10,           # Number of grid cells
    Ny=10,
    Nz=1,
    stepMax=15,   # Maximum number of timesteps
    CFL=0.01,         # Courant-Friedrichs-Lewy (CFL) condition for timestep
    out_period=1,     # Number of steps between when plots are updated
    tol = 1e-3,

    # Processors 
    nprocx = 1,
    nprocy = 1,
    nprocz = 1,

    # Periodicity
    xper = false,
    yper = false,
    zper = true,

    # pressure_scheme = "semi-lagrangian",
    # pressureSolver = "hypreSecant",
    
    pressureSolver = "FC_hypre",
    pressure_scheme = "finite-difference",
    
    iter_type = "standard",
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
    @unpack jmin_,jmax_ = mesh
    @unpack xm,ym = mesh
    
     # Left 
     if irankx == 0 
        i = imin-1
        for j=jmin_:jmax_
            if ym[j] <= 1.5 
                uleft = 1.0
            else
                uleft = 0.0
            end
            u[i,j,:] .= 2uleft .- u[imin,j,:]
        end
        v[i,:,:] = -v[imin,:,:] # No slip
        w[i,:,:] = -w[imin,:,:] # No slip
    end
    # Right
    vright=0.0
    if irankx == nprocx-1
        i = imax+1
        for j=jmin_:jmax_
            if ym[j] <= 1.5
                uright = 1.0
            else
                uright = 0.0
            end
            u[i,j,:] .= 2uright .- u[imax,j,:]
        end
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
Apply outflow correction to region
"""
function outflow_correction!(correction,uf,vf,wf,mesh,par_env)
    @unpack imin_,imax_,jmin_,jmax_,kmin_,kmax_ = mesh
    @unpack iranky,nprocy = par_env
    # Right is the outflow
    if irankx == nprocx-1
        uf[imax_+1,:,:] .+= correction 
    end
end

"""
Define area of outflow region
"""
function outflow_area(mesh,par_env)
    @unpack imin_,imax_,jmin_,jmax_,kmin_,kmax_ = mesh
    @unpack x,y,z = mesh 
    myArea = (y[jmax_+1]-y[jmin_]) * (z[kmax_+1]-z[kmin_])
    return NavierStokes_Parallel.parallel_sum_all(myArea,par_env)
end
outflow =(area=outflow_area,correction=outflow_correction!)

# Simply run solver on 1 processor
@time run_solver(param, IC!, BC!,outflow)
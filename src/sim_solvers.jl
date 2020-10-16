export solve!

function solve!(sim::Simulation)
    sim.ψ[1, :] = sim.ψ₀
    if sim.αₚ > 0 
        ind_p = [i for i in 2:(sim.box.Nₜ÷2+1) if (i-1)%sim.box.n_periods != 0]
        ind_p = sort([ind_p; sim.box.Nₜ.-ind_p.+2])
        #println(ind_p)
    end

    println("==========================================")
    println("Solving cubic NLSE with the following options:")
    print(sim)
    @showprogress 1 "Computing..." for i = 1:sim.box.Nₓ-1
    #for i = 1:sim.box.Nₓ-1
        if sim.algorithm == "2S"
            @views sim.ψ[i+1, :] = T2(sim.ψ[i, :], sim.box.ω, sim.box.dx)
        elseif sim.algorithm == "4S"
            @views sim.ψ[i+1, :] = T4S(sim.ψ[i, :], sim.box.ω, sim.box.dx)
        elseif sim.algorithm == "6S"
            @views sim.ψ[i+1, :] = T6S(sim.ψ[i, :], sim.box.ω, sim.box.dx)
        elseif sim.algorithm == "8S"
            @views sim.ψ[i+1, :] = T8S(sim.ψ[i, :], sim.box.ω, sim.box.dx)
        else
            throw(ArgumentError("Algorithm type unknown, please check the documentation"))
        end
        # Pruning
        # TODO: get rid of this extra ψ and rewrite more elegantly
        if sim.αₚ > 0 
            ψ = sim.ψ[i+1, :]
            fft!(ψ)
            @views ψ[ind_p] .*= exp.(-sim.αₚ*abs.(ψ[ind_p]))
            ifft!(ψ)
            sim.ψ[i+1, :] = ψ
        end
    end #for
    sim.solved = true

    println("Computation Done!")
    println("==========================================")

    return nothing
end #solve

function T2(ψ, ω, dx)
    # Nonlinear
    V = -1*abs.(ψ).^2                      
    ψ .*= exp.(-im * dx/2 * (-1*abs.(ψ).^2)) 

    # Kinetic
    fft!(ψ)                                   
    ψ .*= ifftshift(exp.(-im * dx * ω .^ 2 / 2)) 
    ifft!(ψ)                                  

    # Nonlinear
    ψ .*= exp.(-im * dx/2 * (-1*abs.(ψ).^2)) 

    return ψ
end #T2

function T4S(ψ, ω, dx)
    s = 2^(1 / 3)
    os = 1 / (2 - s)

    ft = os
    bt = -s * os

    ψ = T2(ψ, ω, ft * dx)
    ψ = T2(ψ, ω, bt * dx)
    ψ = T2(ψ, ω, ft * dx)

    return ψ
end # T4S

function T6S(ψ, ω, dx)
    s = 2^(1 / 5)
    os = 1 / (2 - s)

    ft = os
    bt = -s * os

    ψ = T4S(ψ, ω, ft * dx)
    ψ = T4S(ψ, ω, bt * dx)
    ψ = T4S(ψ, ω, ft * dx)

    return ψ
end #T6S

function T8S(ψ, ω, dx)
    s = 2^(1 / 7)
    os = 1 / (2 - s)

    ft = os
    bt = -s * os

    ψ = T6S(ψ, ω, ft * dx)
    ψ = T6S(ψ, ω, bt * dx)
    ψ = T6S(ψ, ω, ft * dx)

    return ψ
end #T8S
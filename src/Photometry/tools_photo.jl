"""
`add_streaks`
using an events dataframe made by the function observe_pokes(analog)
add an array specifying the current side
"""
function add_streaks(analog, events)
    analog[:PokeIn] = false
    analog[events[:In],:PokeIn] = true
    analog[:PokeOut] = false
    analog[events[:Out],:PokeOut] = true
    analog[:PokeIn_n] = 0
    analog[:PokeOut_n] = 0
    counter = 1
    for i =1:size(events,1)
        analog[events[i,:In],:PokeIn_n] = counter
        analog[events[i,:Out],:PokeOut_n] = counter
        counter = counter +1
    end
    counter = 1
    analog[:Pokes] = analog[:R_p]+analog[:L_p]
    analog[:Poke_n] = 0
    for i = 1:size(events,1)
        analog[events[i,:In]:events[i,:Out],:Poke_n] = counter
        counter = counter + 1
    end
    # Streaks the first part assignes the side from the first poke to the one to last
    analog[:StreakStart] = false
    analog[:StreakEnd] = false
    analog[:StreakIn_n] = 0
    analog[:StreakOut_n] = 0
    analog[:Streak_n] = 0
    analog[:Side] = "travel"
    by(events,:Streak_n) do dd
        start = dd[1,:In]
        finish = dd[end,:Out]
        analog[start,:StreakStart] = true
        analog[finish,:StreakEnd] = true
        analog[start,:StreakIn_n] = dd[1,:Streak_n]
        analog[finish,:StreakOut_n] = dd[1,:Streak_n]
        analog[start:finish,:Streak_n] = dd[1,:Streak_n]
        analog[start:finish,:Side] = dd[1,:Side]
    end
    return analog
end



"""
`calc_F0`
"""
function calc_F0(data::AbstractDataFrame,WHAT::Symbol,start = -100, finish = -50)
    Fzeroes=[]
    for trials = 1:size(data,1)
        if data[trials,WHAT].shifts[1] == 0
            F0 = missing
            push!(Fzeroes,F0)
        else
            v = skipmissing(data[trials,WHAT][start:finish])
            F0 = isempty(v) ? missing : mean(v)#if there are only missing value return missing else the mean
            push!(Fzeroes,F0)
        end

    end
    return Fzeroes
end
"""
`Normalise_F0`
"""
function  Normalise_F0(data::AbstractDataFrame,WHAT::Symbol;start = -100, finish = -50)
    F0_norm =  Array{ShiftedArrays.ShiftedArray{Float64,Missings.Missing,1,Array{Float64,1}}}(size(data,1))
    Fzeroes = calc_F0(data,WHAT,start,finish)
    for i = 1:size(data,1)
        subtract = (data[i,WHAT].parent) - Fzeroes[i]
        value = subtract/Fzeroes[i]
        shift = data[i,WHAT].shifts[1]#shifts is a Tuples need to be indexed
        if typeof(value)== DataArrays.DataArray{Float64,1}
            println("i = ",i)
            println("shift = ", shift)
            println(value,typeof(value))
            convert(Array{Float64,1},value)
        end
        F0_norm[i] = ShiftedArray(value,shift)
    end
    return F0_norm
end
"""
`Normalise_GLM`
"""
function  Normalise_GLM(data::AbstractDataFrame,signal::Symbol,regressor::Symbol)
    prov = DataFrame()
    sig_vector = Union{Float64,Missing}[]
    ref_vector = Union{Float64,Missing}[]
    for i = 1:size(data,1)
        append!(sig_vector, data[i,signal].parent)
        append!(ref_vector, data[i,regressor].parent)
    end;
    prov = DataFrame(Sig=sig_vector,Ref = ref_vector)
    filter = .!ismissing.(sig_vector)
    OLS = lm(@formula(Sig ~ 0 + Ref), prov[filter,:])
    coefficient = coef(OLS)
    prov = DataFrame(Sig=sig_vector,Ref = ref_vector)
    filter = .!ismissing.(sig_vector)
    OLS = lm(@formula(Sig ~ 0 + Ref), prov[filter,:])
    coefficient = coef(OLS)
    Reg_norm =  Array{Any}(size(data,1))
    for i in 1:size(data,1)
        value = @.(data[i,signal].parent-data[i,regressor].parent*coefficient)
        shift = data[i,signal].shifts[1]
        Reg_norm[i] = ShiftedArray(value,shift)
    end;
    return Reg_norm
end
"""
`Normalise_Reg`
"""
function  Normalise_Reg(data::AbstractDataFrame,WHAT::Symbol)
    col_sig = WHAT
    col_ref = Symbol(replace(String(WHAT),"sig","ref"))
    sig_shifted = Normalise_F0(data,col_sig)
    ref_shifted = Normalise_F0(data,col_ref)
    sig_vector = sig_shifted[1].parent
    ref_vector = ref_shifted[1].parent
    for i = 2:size(sig_shifted,1)
        sig_vector = vcat(sig_vector,sig_shifted[i].parent)
        ref_vector = vcat(ref_vector,ref_shifted[i].parent)
    end
    intercept, slope = linreg(collect(skipmissing(ref_vector)),collect(skipmissing(sig_vector)))
    Reg_norm =  Array{ShiftedArray}(size(data,1))
    for i in 1:size(data,1)
        value = @.(sig_shifted[i].parent-ref_shifted[i].parent*slope)
        shift = data[i,WHAT].shifts[1]
        Reg_norm[i] = ShiftedArray(value,shift)
    end
    return Reg_norm
end

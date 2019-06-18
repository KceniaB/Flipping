export process_pokes,process_streaks, create_exp_dataframe

"""
`iscolumn`
"""

function iscolumn(df::DataFrames.AbstractDataFrame,what::Symbol)
    if in(what,names(df))
        return true
    else
        return false
    end
end

"""
`session_info`
"""

function session_info(filepath::String)
    sessionREGEX = match(r"[a-zA-Z]{2}\d+_\d{6}[a-z]{1}",filepath); #the result is a regex object with several info
    if isempty(sessionREGEX.match)
        sessionREGEX = match(r"[a-zA-Z]{1}\d+_\d{6}",filepath);
        if isempty(sessionREGEX.match)
            println(filepath)
            return missing, missing, missing
        else
            session = sessionREGEX.match;
        end
    else
        session = sessionREGEX.match;
    end
    mouse, giorno = split(session,"_")[1:2]
    day = "20"*giorno[1:end-1]
    # String and string are not the same thing don't change them
    mouse = String(mouse)
    day = string(day)
    daily_session = string(giorno[end])
    session = String(session)
    return mouse, day, daily_session, session
end

"""
`gen`

look for a list of genotypes from the MouseID
"""
function gen(str; dir = joinpath(dirname(@__DIR__), "genotypes"))
    genotype = "missing"
    for file in readdir(dir)
        if endswith(file, ".csv")
            df = FileIO.load(joinpath(dir, file)) |> DataFrame
            n = names(df)[1]
            if str in df[n]
                genotype = string(n)
            end
        end
    end
    genotype
end

"""
`pharm`
"""
function pharm(str; dir = joinpath(dirname(@__DIR__), "pharmacology"))
    drug = "missing"
    for file in readdir(dir)
        if endswith(file, ".csv")
            df = FileIO.load(joinpath(dir, file)) |> DataFrame
            n = names(df)[1]
            if str in df[n]
                drug = String(n)
            end
        end
    end
    return drug
end

"""
`get_protocollo(df)`

Python preprocessing creates a Boolean vector to distinguish between 2 Protocollo
relative Gamma and Probability are infered by the respective GammaVec and ProbVec
"""
function get_protocollo(df)
    ProtName = String[]
    for i = collect(1:size(df,1))
        #in the original data protocol are labeled either 0 or 1
        #this function collapse the respective gamma and prob in a string
        if df[i,:Protocollo]==0
            curr_prot = string(df[i,:ProbVec0],"/",df[i,:GamVec0])
            push!(ProtName,curr_prot)
        elseif df[i,:Protocollo]==1
            curr_prot = string(df[i,:ProbVec1],"/",df[i,:GamVec1])
            push!(ProtName,curr_prot)
        end
    end
    #ProtName = categorical(ProtName)
    return ProtName
end

"""
`count_sequence`
"""

function count_sequence(series::AbstractArray)
    streak_n = [1]
    count = 1
    for i = 2:size(series,1)
        if series[i] == series[i-1]
            count = count
        else
            count = count+1
        end
        push!(streak_n,count)
    end
    return streak_n
end

"""
`get_hierarchy`
Elaborate a series indicating the number of streak from the last stimulated trial.
First stim trial is 0;
following non stim trial have negative values;
following stim trials have positive values;
"""

function nextcount(count::T, rewarded) where {T <: Number}
    if rewarded
        count > 0 ? count + 1 : one(T)
    else
        count < 0 ? count - 1 : -one(T)
    end
end
signedcount(v::AbstractArray{Bool}) = accumulate(nextcount, v;init=0.0)
get_hierarchy(v) = lag(signedcount(v), default = NaN)


"""
`process_pokes`
"""

function process_pokes(filepath::String)
    curr_data = FileIO.load(filepath) |> DataFrame
    rename!(curr_data, Symbol("") => :Poke) #change poke counter name
    curr_data[:Poke] = curr_data[:Poke].+1
    start_time = curr_data[1,:PokeIn]
    curr_data[:PokeIn] = curr_data[:PokeIn] .- start_time
    curr_data[:PokeOut] = curr_data[:PokeOut] .- start_time
    curr_data[:PokeDur] = curr_data[:PokeOut]-curr_data[:PokeIn]
    if !iscolumn(curr_data,:Wall)
        curr_data[:Wall] = zeros(size(curr_data,1))
    end
    booleans=[:Reward,:Side,:SideHigh,:Stim,:Wall]#columns to convert to Bool
    for x in booleans
        curr_data[x] = Bool.(curr_data[x])
    end
    if iscolumn(curr_data,:ProbVec0)
        integers=[:Protocollo,:ProbVec0,:ProbVec1,:GamVec0,:GamVec1,:delta]; #columns to convert to Int64
        for x in integers
            curr_data[x] = Int64.(curr_data[x])
        end
        curr_data[:Protocol] = Flipping.get_protocollo(curr_data)
        for x in[:ProbVec0,:ProbVec1,:GamVec0,:GamVec1,:Protocollo]
            deletecols!(curr_data, x)
        end
        curr_data[:StimFreq] = curr_data[:Stim] == 0 ? 25 : 0
    elseif iscolumn(curr_data,:Prwd)
        curr_data[:Protocol] = string(curr_data[:Prwd]) .* '/' .* string(curr_data[:Ptrs])
    end
    mouse, day, daily_session, session = session_info(filepath)
    curr_data[:MouseID] = mouse
    curr_data[:Day] = parse(Int64,day)
    curr_data[:Daily_Session] = daily_session
    curr_data[:Session] = session
    curr_data[:Gen] = Flipping.gen.(curr_data[:MouseID])
    curr_data[:Drug] = Flipping.pharm.(curr_data[:Day])
    curr_data[:Stim_Day] = length(findall(curr_data[:Stim])) == 0 ? false : true
    curr_data[:Streak] = count_sequence(curr_data[:Side])
    curr_data[:ReverseStreak] = reverse(curr_data[:Streak])
    curr_data[:Poke_within_Streak] = 0
    curr_data[:InterPoke] = 0.0
    curr_data[:Poke_Hierarchy] = 0.0
    by(curr_data,:Streak) do dd
        dd[:Poke_within_Streak] = count_sequence(dd[:Poke])
        prov = lead(dd[:PokeIn],default = 0.0) .- dd[:PokeOut]
        dd[:InterPoke]  = [x.< 0 ? 0 : x for x in prov]
        dd[:Poke_Hierarchy] = Flipping.get_hierarchy(dd[:Reward])
    end
    curr_data[:Block] = count_sequence(curr_data[:Wall])
    curr_data[:Streak_within_Block] = 0
    by(curr_data,:Block) do dd
        dd[:Streak_within_Block] = count_sequence(dd[:Side])
    end
    curr_data[:Correct] = curr_data[:Side] .== curr_data[:SideHigh]
    return curr_data
end

"""
`process_streaks`
"""

function process_streaks(df::DataFrames.AbstractDataFrame; photometry = false)
    columns_list = [:MouseID, :Gen, :Drug,:Day, :Daily_Session, :Stim_Day,:Condition, :ExpDay, :Area,:Session];
    booleans=[:Reward,:Side,:SideHigh,:Stim,:Wall,:Correct,:Stim_Day]#columns to convert to Bool
    for x in booleans
        df[x] = eltype(df[x]) == Bool ? df[x] : occursin.(df[x],"true")
    end
    streak_table = by(df, :Streak) do dd
        dt = DataFrame(
        Num_pokes = size(dd,1),
        Num_Rewards = length(findall(dd[:Reward].==1)),
        Start_Reward = dd[1,:Reward],
        Last_Reward = findlast(dd[:Reward] .== 1).== nothing ? 0 : findlast(dd[:Reward] .== 1),
        Prev_Reward = findlast(dd[:Reward] .== 1).== nothing ? 0 : findprev(dd[:Reward] .==1, findlast(dd[:Reward] .==1)-1),
        Trial_duration = (dd[end,:PokeOut]-dd[1,:PokeIn]),
        Start = (dd[1,:PokeIn]),
        Stop = (dd[end,:PokeOut]),
        InterPoke = maximum(dd[:InterPoke]),
        PokeSequence = [SVector{size(dd,1),Bool}(dd[:Reward])],
        Stim = dd[1,:Stim],
        StimFreq = dd[1,:StimFreq],
        Wall = dd[1,:Wall],
        Protocol = dd[1,:Protocol],
        Correct = dd[1,:Correct],
        Block = dd[1,:Block],
        Streak_within_Block = dd[1,:Streak_within_Block],
        Side = dd[1,:Side],
        ReverseStreak = dd[1,:ReverseStreak]
        )
        for s in columns_list
            if s in names(df)
                dt[s] = df[1, s]
            end
        end
        return dt
    end
    streak_table[:Prev_Reward] = [x .== nothing ? 0 : x for x in streak_table[:Prev_Reward]]
    streak_table[:AfterLast] = streak_table[:Num_pokes] .- streak_table[:Last_Reward];
    streak_table[:BeforeLast] = streak_table[:Last_Reward] .- streak_table[:Prev_Reward].-1;
    prov = lead(streak_table[:Start],default = 0.0) .- streak_table[:Stop];
    streak_table[:Travel_to]  = [x.< 0 ? 0 : x for x in prov]
    if photometry
        frames = by(df, :Streak) do df
            dd = DataFrame(
            In = df[1,:In],
            Out = df[end,:Out],
            LR_In = findlast(df[:Reward])==0 ? NaN : df[findlast(df[:Reward]),:In],
            LR_Out = findlast(df[:Reward])==0 ? NaN : df[findlast(df[:Reward]),:Out]
            )
        end
        streak_table[:In] = frames[:In]
        streak_table[:Out] = frames[:Out]
        streak_table[:LR_In] = frames[:LR_In]
        streak_table[:LR_Out] = frames[:LR_Out]
    end

    return streak_table
end

"""
`process_sessions`
"""

function process_sessions(DataIndex::DataFrames.AbstractDataFrame)
    c=0
    b=0
    pokes = []
    streaks = []
    for i=1:size(DataIndex,1)
        #print(i," ")
        path = DataIndex[i,:Bhv_Path]
        session = DataIndex[i,:Session]
        filetosave = DataIndex[i,:Preprocessed_Path]
        if ~isfile(filetosave)
            pokes_data = process_pokes(path)
            FileIO.save(filetosave,pokes_data)
            streaks_data = process_streaks(pokes_data)
            b=b+1
        else
            pokes_data = FileIO.load(filetosave)|> DataFrame
            booleans=[:Reward,:Side,:SideHigh,:Stim,:Wall,:Correct,:Stim_Day]#columns to convert to Bool
            for x in booleans
                pokes_data[x] = eltype(pokes_data[x]) == Bool ? pokes_data[x] : occursin.(pokes_data[x],"true")
            end
            streaks_data = process_streaks(pokes_data)
            c=c+1
        end
        if isempty(pokes)
            pokes = pokes_data
            streaks = streaks_data
        else
            try
                append!(pokes, pokes_data)
                append!(streaks, streaks_data)
            catch
                append!(pokes, pokes_data[:, names(pokes)])
                append!(streaks, streaks_data[:, names(streaks)])
            end
        end
    end
    println("Existing file = ",c," Preprocessed = ",b)
    return pokes, streaks
end

"""
"count_series"
useful to count an ordered series of categorical values, wheter they are the same or
they change
"""
function count_trues(count::T, same) where {T <: Number}
    if same
        count+1
    else
        1
    end
end

function check_series(x)
    Vector = [false]
    for i = 2:size(x,1)
        push!(Vector,x[i] == x[i-1] ? true : false)
    end
    return Vector
end

function count_series(vector)
    x = check_series(vector)
    res = accumulate(count_trues,x;init=0)
    return res
end

"""
`create_exp_calendar`
Method1: recount days of experiment
Method2: recount days according to changes in a manipulation
days is a Symbol  for the column that stores the actual days
"""
function create_exp_calendar(df::AbstractDataFrame,days::Symbol)
    lista = sort!(union(df[days]))
    Exp_day = Array{Int64,1}()
    Day = []
    for (n,d) in enumerate(lista)
        push!(Exp_day,Int64(n))
        push!(Day,d)
    end
    x = DataFrame(Exp_Day = Exp_day)
    x[days] = Day
    return x
end

function create_exp_calendar(df::AbstractDataFrame,days::Symbol,manipulation::Symbol)
    x = by(df,days) do dd
        DataFrame(manipulation_state = union(dd[manipulation]))
    end
    what = string(manipulation)
    new_name = Symbol(what*"_Day")
    reordered = sortperm(x,(days))
    x = x[reordered,:]
    x[new_name] = count_series(x[:manipulation_state])
    deletecols!(x,:manipulation_state)
    return x
end

"""
`create_exp_dataframes`
"""

function create_exp_dataframes(Directory_path::String,Exp_type::String,Exp_name::String, Mice_suffix::String)
    DataIndex = Flipping.find_behavior(Directory_path, Exp_type, Exp_name,Mice_suffix)
    pokes, streaks = process_sessions(DataIndex)
    exp_calendar = by(pokes,:MouseID) do dd
        Flipping.create_exp_calendar(dd,:Day)
    end
    protocol_calendar = by(pokes,:MouseID) do dd
        Flipping.create_exp_calendar(dd,:Day,:Protocol)
    end
    pokes = join(pokes, exp_calendar, on = [:MouseID,:Day], kind = :inner,makeunique=true);
    pokes = join(pokes, protocol_calendar, on = [:MouseID,:Day], kind = :inner,makeunique=true);
    mask = occursin.(String.(names(pokes)),"_1")
    for x in[names(pokes)[mask]]
        deletecols!(pokes, x)
    end
    pokes = Flipping.check_fiberlocation(pokes,Directory_path,Exp_name)
    filetosave = Directory_path*"Datasets/"*Exp_type*"/"*Exp_name*"/pokes"*Exp_name*".jld2"
    @save filetosave pokes
    streaks = join(streaks, exp_calendar, on = [:MouseID,:Day], kind = :inner,makeunique=true);
    streaks = join(streaks, protocol_calendar, on = [:MouseID,:Day], kind = :inner,makeunique=true);
    mask = occursin.(String.(names(streaks)),"_1")
    for x in[names(streaks)[mask]]
        deletecols!(streaks, x)
    end
    streaks = Flipping.check_fiberlocation(streaks,Directory_path,Exp_name)
    filetosave = Directory_path*"Datasets/"*Exp_type*"/"*Exp_name*"/streaks"*Exp_name*".jld2"
    @save filetosave streaks
    return pokes, streaks, DataIndex
end

function create_exp_dataframes(Raw_data_dir)
    DataIndex = Flipping.find_behavior(Raw_data_dir)
    pokes, streaks = process_sessions(DataIndex)
    exp_calendar = Flipping.create_exp_calendar(pokes,:Day)
    protocol_calendar = Flipping.create_exp_calendar(pokes,:Day,:Protocol)
    pokes = join(pokes, exp_calendar, on = :Day, kind = :inner,makeunique=true);
    pokes = join(pokes, protocol_calendar, on = :Day, kind = :inner,makeunique=true);
    mask = occursin.(String.(names(pokes)),"_1")
    for x in[names(pokes)[mask]]
        delete!(pokes, x)
    end
    filetosave = Directory_path*"Datasets/"*Exp_type*"/"*Exp_name*"/pokes"*Exp_name*".jld2"
    @save filetosave pokes
    streaks = join(streaks, exp_calendar, on = :Day, kind = :inner,makeunique=true);
    streaks = join(streaks, protocol_calendar, on = :Day, kind = :inner,makeunique=true);
    mask = occursin.(String.(names(streaks)),"_1")
    for x in[names(streaks)[mask]]
        delete!(streaks, x)
    end
    filetosave = Directory_path*"Datasets/"*Exp_type*"/"*Exp_name*"/streaks"*Exp_name*".jld2"
    @save filetosave streaks
    return pokes, streaks, DataIndex
end

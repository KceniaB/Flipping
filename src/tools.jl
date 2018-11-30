"""
`convert2Bool(df,symbols)`

Converts values of columns symbols of dataframe df in Bool
"""
function convert2Bool(df,symbols)
    for symbol in symbols
        df[:,symbol] = Bool.(df[:,symbol])
    end
end

"""
`convert2Int(df,symbols)`

Converts values of columns symbols of dataframe df in Int
"""
function convert2Int(df,symbols)
    for symbol in symbols
        df[:,symbol]=Int64.(df[:,symbol])
    end
end

"""
`get_CAMmousedate(filepath, pattern)`

it extract the session name by pattern match:
It assumes that the date of the creation of the file is the day of the session
"""
function get_CAMmousedate(filepath, pattern)
    fileinfo = get_sessionname(filepath,pattern)
    mouse, note = split(fileinfo, "_")[1:2]# decompose the file name by _ and take the first as animal name
    #and the second as extra experimental note, like target area
    date = Dates.Date(Dates.unix2datetime(ctime(filepath)))#return the date from file properties,
    #convert it from unix to normal time and take only the date
    mouse = String(mouse)
    note = String(mouse)
    return mouse, date, note
end

"""
`get_BHVmousedate(filepath)`

it extract the session name by Regular expression match:
It assumes that session name is composed by
2 characters and a number for the mouse
followed by the date
"""
function get_BHVmousedate(filepath)
    sessionREGEX = match(r"[a-zA-Z]{2}\d+_\d{6}",filepath); #the result is a regex object with several info
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
    day = "20"*giorno
    mouse = String(mouse)
    day = String(day)
    session = String(session)
    return mouse, day, session
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
`get_streak(df)`

Starting from 1 create a counter that increase
when detect change in side between a poke and the previous
"""
function get_streak(df)
    Streak = Int64[1] #create an array to fill with streak counter first value is by definition streak 1
    for i = 2:size(df,1)
        if df[i,:Side] != df[i-1,:Side] #if previous side is different from current side
            push!(Streak, Streak[i-1]+1) #increase the counter
        else
            push!(Streak, Streak[i-1]) #otherwise keep the counter fixed
        end
    end
    return Streak
end
"""
`get_sequence`

Starting from 1 create a counter that increase when detect change in  a categorical variable
a 3rd argument can be use to reset the counter at the change of another categorical variable
Method1 count events in a column get_sequence(df,category::Symbol)
Method2 count events in a column devided by another get_sequence(df,category,by)
Method3 count events in a column devided by another if a condition matches get_sequence(df,category,by,se)
"""
#Method 3 count events in a column devided by another if a condition matches
function get_sequence(df,category,by,se)
    sequence = Int64[1] #create an array to fill with sequence counter first value is by definition sequence 1
    for i = 2:size(df,1)
        if df[i-1,by] == df[i,by]
            if df[i,category] != df[i-1,category] && df[i,se] #if previous side is different from current side
                push!(sequence, sequence[i-1]+1) #increase the counter
            else
                push!(sequence, sequence[i-1]) #otherwise keep the counter fixed
            end
        else
            push!(sequence, 1)
        end
    end
    return sequence
end

#Method2 count events in a column devided by another
function get_sequence(df,category,by)
    sequence = Int64[1] #create an array to fill with sequence counter first value is by definition sequence 1
    for i = 2:size(df,1)
        if df[i-1,by] == df[i,by]
            if df[i,category] != df[i-1,category] #if previous side is different from current side
                push!(sequence, sequence[i-1]+1) #increase the counter
            else
                push!(sequence, sequence[i-1]) #otherwise keep the counter fixed
            end
        else
            push!(sequence, 1)
        end
    end
    return sequence
end
##Method1 count events in a column
function get_sequence(df,category::Symbol)
    sequence = Int64[1] #create an array to fill with sequence counter first value is by definition sequence 1
    for i = 2:size(df,1)
        if df[i,category] != df[i-1,category] #if previous side is different from current side
            push!(sequence, sequence[i-1]+1) #increase the counter
        else
            push!(sequence, sequence[i-1]) #otherwise keep the counter fixed
        end
    end
    return sequence
end

"""
`get_streakstart(df)`

function to create a boolean column that flags the begin of a streak
begin of trials
"""
function get_streakstart(df)
    #create an array to point first poke of a given trial,
    #by definition first poke of the session is the beginning of a trial
    Streakstart = Bool[true]
    for i= 2:size(df,1)
        #if previous streak counter is different from the current
        if df[i,:Streak_n] != df[i-1,:Streak_n]
            push!(Streakstart,true) #begin of a new trial
        else
            push!(Streakstart,false)#otherwise same trial
        end
    end
    return Streakstart
end

"""
`get_correct`

TO BE REDEFINE WORKS ONLY FOR 100% GAMMA NOT SO WELL also
function to define correct and incorrect trials
"""
function get_correct(df) #this function works correctly only for protocols with 100% probability flipping gamma
    Correct = Bool[] #create an array to fill with streak counter
    for i = 1:size(df,1)
        if df[i,:Side] == df[i,:SideHigh] #if current side is equal from side high
            push!(Correct, true) # set correct true
            #elseif (df[i,:SideHigh] == df[i-1,:SideHigh]) && (df[i-1,:Side] == df[i-1,:SideHigh])
            #    push!(Correct, true)
        else
            push!(Correct, false) #otherwise false
        end
    end
    return Correct
end
"""
`get_last`
"""
function get_last(df,what::Symbol)
    last = zeros(size(df,1))
    beginning = findmax(df[what])[2]
    last[beginning:end].=1
    return last
end

"""
`get_shifteddifference`
"""
#Method1
function get_shifteddifference(df,second::Symbol,first::Symbol)
    difference = df[second][2:end] - df[first][1:end-1];
    #unshift!(difference,0)#place a 0 at the first element because there is no precedent value to be subtracted
    unshift!(difference,0.0)
    return difference
end
#Method2 set 2 zero according to the reset of another counter
function get_shifteddifference(df,second::Symbol,first::Symbol,reset::Symbol)
    difference = df[second][2:end] - df[first][1:end-1];
    unshift!(difference,0)#place a 0 at the first element because there is no precedent value to be subtracted
    difference[df[reset]] = 0#place a 0 at the begin of a new streak
    return difference
end

"""
`check_fiberlocation`

look for a dataset where fiberlocation across day is stored
"""
function check_fiberlocation(data,Exp_name)
    filetofind=joinpath("/Users/dariosarra/Google Drive/Flipping/run_task_photo/"*Exp_name*"/FiberLocation.csv");
    if isfile(filetofind)
        fiberlocation = FileIO.load(filetofind) |> DataFrame;
        n_table = join(data, fiberlocation, on = :Session, kind = :inner,makeunique=true);
        println("found fibres location file, HAVE YOU UPDATED IT?")
    else
        println("no fibres location file")
        n_table = data;
    end
    return n_table
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
`concat_data!`

Adjust append in case Dataframes have different columns order
"""
concat_data!(a, b) = append!(a, b[:, names(a)])

"""
`concat_data`

Append a series of dataframe if receives an arrays of paths
"""

function concat_data!(v)
    a = FileIO.load(v[1]) |> DataFrame
    for n in v[2:end]
        try
            concat_data!(a, FileIO.load(n)|> DataFrame)
        catch
            println( "Error session = ", n)
        end
    end
    a
end

"""
`custom_bin`

function to bin an array of numbers in n  bins of the same size
for each row returns to which bin it belongs and the range of that bin
"""
function custom_bin(data::DataFrames.AbstractDataFrame,what::Symbol,n_of_bins::Int)
   prov= by(data,what) do dd
       DataFrame(size = size(dd,1))
   end;
   sort!(prov,order(what))
   prov[:cumulative] = 0
   for i = 1:size(prov,1)
       prov[i,:cumulative] = sum(prov[1:i, :size])
   end
   binsize = sum(prov[:size])/n_of_bins
   prov[:bin] = floor.(prov[:cumulative]./binsize);
   Binned_value = []
   for i in data[what]
       push!(Binned_value,prov[findfirst(prov[what].==i), :bin])
   end
   contr = by(prov,:bin) do dd
       DataFrame(size = sum(dd[:size]),
       range = string(union(dd[what])[1],":",union(dd[what])[end]))
   end;
   dict = Dict(contr[i,:bin] => contr[i,:range] for i = 1:size(contr,1))
   Binned_range = [dict[i] for i in Binned_value]

   return Binned_value, Binned_range
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
signedcount(v::AbstractArray{Bool}) = accumulate(nextcount, 0.0, v)
get_hierarchy(v) = lag(signedcount(v), default = NaN)

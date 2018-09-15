"""
`adjust_matfile`
read a matlab file from the photometry set up and turn it in a DataFrame
adjusting the fiber names
"""
function adjust_matfile(mat_filepath)
    #matvars read structures as a dictionary
    matvars=matread(mat_filepath);
    #since the camera alternates on 2 channels the frame rate is actually half
    framerate = (matvars["framerate"])/2;
    framerate
    #this labels are set at the moment of the acquisition
    labels = vec(matvars["labels"]);
    #DataFrame is the functions that understands the difference between rows and columns
    #as indicated in the dictionary made by matread, deviding correctly different fibers
    session_sig = DataFrame(matvars["sig"]);
    names!(session_sig,[Symbol(i *"_sig") for i in labels],makeunique=true);
    session_sig[:Frame] = collect(1:size(session_sig,1))
    session_ref = DataFrame(matvars["ref"]);
    names!(session_ref,[Symbol(i *"_ref") for i in labels],makeunique=true);
    session_ref[:Frame] = collect(1:size(session_ref,1));
    # join the signals and references in one dataframe
    session=join(session_sig,session_ref;on = :Frame);
    return session
end
##

"""
'adjust_logfile'
read the national board instrument log, cancel noise and return a DataFrame with
the task info
"""
function adjust_logfile(analog_filepath;conversion_rate=50,acquisition_rate=1000,force=false)
    #rec type is true if protocol is signaled on the 3 channel
    analog, rec_type = read_log(analog_filepath)
    analog = compress_analog(analog,conversion_rate,acquisition_rate)
    if force
        #few session hadn't protocol and reward signal but the L and R pokes where separeted
        rec_type = true
    end
    analog[:Frame] = collect(1:size(analog,1))
    events = observe_pokes(analog,conversion_rate,rec_type)
    return analog, events, rec_type
end
##
"""
`cancelnoise`
finding first poke remove possible bursts of current in the beginning
of the sessions in the poke tracing coming from arduino's begin of the task
"""
function cancelnoise(analogs)
    firststep = findfirst(analogs.>4.5)
    analogs[1:firststep] = 0
    return analogs
end

"""
`read_log`
remove noise from the analog traces
"""
function read_log(analog_filepath)
    analog= FileIO.load(analog_filepath,header_exists=false) |> DataFrame;
    analog = analog[:,1:6];
    names!(analog,[:timestamp,:R_p,:L_p,:Rew,:SideHigh,:Protocol]);
    if isempty(find(analog[:Rew].<-2))
        rec_type = false
    else
        rec_type = true
    end
    analog[:Rew] = - analog[:Rew];
    for name in names(analog)
        if name == :timestamp
            analog[name] = collect(1:1:size(analog,1))
        else
             check = cancelnoise(analog[name])
            if !isempty(find(check))
                analog[name] = check
            end
            inds = analog[name].<4.7
            # risky approach to account for old datas
            if size(inds,1) == size(analog,1)##
                inds = analog[name].< 1.5*mean(analog[name])
            end
            analog[inds,name] = 0
            analog[.!inds,name] = 1
            analog[name] = Bool.(analog[:,name])
        end
    end
    return analog, rec_type
end
"""
`compress_squarewave`
collapse from millisecond rate to the a chosen rate
"""
function compress_squarewave(analogs,conversion_rate,acquisition_rate)
    long = Float64.(analogs)
    rate = Int64(round(acquisition_rate/conversion_rate))
    short = []
    for i = 1:rate:size(long,1)-rate
        a = ceil(mean(long[i:i+rate-1]))
        push!(short,a)
    end
    lastrange = size(long,1)-rate:size(long,1)
    a = ceil(mean(long[lastrange]))
    push!(short,a)
    return short
end
"""
`compress_analog`
"""
function compress_analog(analog,conversion_rate,acquisition_rate)
    short_log = DataFrame()
    for name in names(analog)
        short_log[name] = compress_squarewave(analog[name],conversion_rate,acquisition_rate)
    end
    return short_log
end

"""
`find_events`
return the index of a squarewave signal either begins or ends
"""
function find_events(squarewave,which)
    digital_trace = Bool.(squarewave)
    if which == :in
        indexes = find(.!digital_trace[1:end-1] .& digital_trace[2:end])
    elseif which == :out
        indexes = find(digital_trace[1:end-1] .& .!digital_trace[2:end])
    end
    return indexes
end

"""
`check_burst`
in some session a current registred simultaneous pokes left and right
"""
function check_burst(analog)
    checksame = analog[:R_p] + analog[:L_p];
    if any(checksame .== 2)
        burst = checksame .> 1
        burst_in = find_events(burst,:in)
        burst_out = find_events(burst,:out)
        Tocancel = DataFrame(in = burst_in,out = burst_out)
        println("found $(size(Tocancel,1)) overlapping events")
        for i = 1:size(Tocancel,1)
            interval = Tocancel[i,:in]:Tocancel[i,:out]
            analog[interval,:] = 0
        end
    end
    return analog
end

"""
`observe_pokes`
identify all the pokes in and out and return a dataframe with the ordered index
of every poke and their side
"""
function observe_pokes(analog,conversion_rate,rec_type::Bool)
    if rec_type
        analog = check_burst(analog)
    end
    R_in= find_events(analog[:R_p],:in)
    R_out = find_events(analog[:R_p],:out)
    events = DataFrame()
    events[:In] = R_in
    events[:Side] = "R"
    events[:Out] = R_out
    L_in = find_events(analog[:L_p],:in)
    L_out = find_events(analog[:L_p],:out)
    if rec_type
        L_in = find_events(analog[:L_p],:in)
        L_out = find_events(analog[:L_p],:out)
        append!(events,DataFrame(In = L_in, Side = repmat(["L"],size(L_in,1)), Out = L_out))
        sort!(events,:In)
    end
    events[:Poke_n] = collect(1:size(events,1))
    events[:Streak_n] = get_sequence(events,:Side)
    events[:In_t] = events[:In]./conversion_rate
    events[:Out_t] = events[:Out]./conversion_rate
    start_time = events[1,:In_t]
    events[:In_t] = events[:In_t].- start_time
    events[:Out_t] = events[:Out_t].- start_time
    events[:PokeDur] = events[:Out_t]-events[:In_t]
    events[:InterPoke] = 0.0
    by(events,:Streak_n) do dd
        dd[:InterPoke] = get_shifteddifference(dd,:In_t,:Out_t)
    end
    return events
end


##
include("process_behaviour.jl")
plotly()
##
"""
'check_accordance'
"""
function check_accordance!(bhv,events,analog_filepath,rec_type)
    if size(bhv,1)!=size(events,1)
        if size(bhv,1)/size(events,1)>1.5
            analog, events = adjust_logfile(analog_filepath; force = true)
            println("force 2 side poke reading")
            rec_type = true
        end
        if size(bhv,1)>size(events,1)
            difference = size(bhv,1) - size(events,1)
            println("bhv pokes - events pokes = ", difference)
            short_pokes = ghost_buster(bhv,difference)
        end
        if size(bhv,1)==size(events,1)
         println("All good file adjusted")
        else
            println("Ops it didn't work")
            println("no solution found")
            println("pokes in bhv: ",size(bhv,1))
            println("pokes in events: ",size(events,1))
        end
    end
end
"""
`ghost_buster`
"""
function ghost_buster(bhv,difference;dur_threshold = 0.1019999999999)
    short_pokes = find(bhv[:PokeDur].<=dur_threshold)
    if size(short_pokes,1)!=0
        println("find n",size(short_pokes,1)," short pokes in Session ", bhv[1,:Session])
    end
    if size(short_pokes,1) == difference
        targets = short_pokes
    elseif size(short_pokes,1) > difference
        println("too many short pokes")
        if difference == 1
            println("trying to remove shortest poke")
            targets = find(bhv[:PokeDur].== minimum(bhv[:PokeDur]))
        end
    elseif size(short_pokes,1) == 0
        println("no short poke found")
        if difference == 1
            println("trying to remove shortest poke")
            targets = find(bhv[:PokeDur].== minimum(bhv[:PokeDur]))
        end
    else
        println("no solution found")
        println("pokes in bhv: ",size(bhv,1))
        println("pokes in events: ",size(events,1))
        targets = [0]
    end
    for i in targets
        bhv[i,:PokeOut] = bhv[i+1,:PokeOut]
        if bhv[i,:Reward] | bhv[i+1,:Reward]
            bhv[i,:Reward] = true
        else
            bhv[i,:Reward] = false
        end
        bhv[i,:PokeDur] = bhv[i+1,:PokeOut] - bhv[i,:PokeIn]
        if size(bhv,1)==i+1
            bhv[i,:InterPoke] = 0.0
        else
            bhv[i,:InterPoke] = bhv[i+2,:PokeIn] - bhv[i+1,:PokeOut]
        end
    end
    deleterows!(bhv, targets.+1)
    println("Replaced Pokes:", targets)
    return(targets)
end
"""
`process_photo`

"""
function process_photo(DataIndex, idx;fps=50,NiDaq_rate=1000)
    mat_filepath = DataIndex[idx,:Cam_Path]
    analog_filepath = DataIndex[idx,:Log_Path]
    raw_path = DataIndex[idx,:Bhv_Path]
    cam = adjust_matfile(mat_filepath);
    analog, events, rec_type = adjust_logfile(analog_filepath,conversion_rate =fps, acquisition_rate =NiDaq_rate);
    bhv = process_pokes(raw_path);
    check_accordance!(bhv,events,analog_filepath,rec_type)
    if !rec_type
        analog[:L_p] = 0.0
        for i=1:size(events,1)
            events[i,:Streak_n] = bhv[i,:Streak_n]
            if bhv[i,:Side]
                events[i,:Side] = "L"
            else
                events[i,:Side] = "R"
            end
        end
    end
    analog = add_streaks(analog, events)
    trace = join(cam,analog,on=:Frame);
    start =  events[1,:In]-5*fps
    if start<1
        start = 1
    end
    finish = events[1,:Out]+5*fps
    if finish > size(trace,1)
        finish = size(trace,1)
    end
    bhv = join(bhv,events[:,[:Poke_n,:In,:Out]], on = :Poke_n)
    return trace, events, bhv
end

"""
`create_processed_files`
"""
function create_processed_files(DataIndex)
    All_traces =DataFrame()
    All_events =DataFrame()
    All_pokes =DataFrame()
    for idx = 1:size(DataIndex,1)
        println(DataIndex[idx,:Session], " idx = ",idx)
        trace, events, bhv = process_photo(DataIndex,idx)
        trace_file = DataIndex[idx,:Exp_Path]*"Traces/"*"Trace_"*DataIndex[idx,:Session]*".csv"
        events_file = DataIndex[idx,:Exp_Path]*"Traces/"*"Events_"*DataIndex[idx,:Session]*".csv"
        bhv_file = DataIndex[idx,:Exp_Path]*"Bhv/"*DataIndex[idx,:Session]*".csv"
        FileIO.save(trace_file,trace)
        FileIO.save(events_file,events)
        FileIO.save(bhv_file,bhv)
        if isempty(All_traces)
            All_traces = trace
            All_events = events
            All_pokes = bhv
        else
            append!(All_traces,trace)
            append!(All_events,events)
            append!(All_pokes,bhv)
        end
    end
    return All_traces, All_events, All_pokes
end

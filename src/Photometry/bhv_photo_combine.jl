"""
'check_accordance!'
"""
function check_accordance!(bhv,events,analog_filepath,rec_type)
    if size(bhv,1) != size(events,1)
        if size(bhv,1)/size(events,1)>1.5
            analog, events = adjust_logfile(analog_filepath; force = true)
            println("force 2 side poke reading")
            rec_type = true
        end
        if size(bhv,1) > size(events,1) # with ground fluctuation arduino signal fake pokes to python
            difference = size(bhv,1) - size(events,1)
            println("bhv pokes - events pokes = ", difference)
            short_pokes = ghost_buster(bhv,difference)
        end
        if size(bhv,1) < size(events,1)
            difference = size(events,1) - size(bhv,1)
            println("events pokes - bhv pokes = ", difference)
            short_pokes = events_buster(events,bhv)
        end
        if size(bhv,1) == size(events,1)
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
'edit_merged_pokes_file!'
"""
function edit_events!(bhv,events,analog)
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

function events_buster(events,bhv)
    if maximum(bhv[:Streak_n]) == maximum(events[:Streak_n])
        println("number of streaks is correct")
        incorrect = []
        for i = 1:maximum(bhv[:Streak_n])
            ongoing_ev = events[events[:Streak_n].==i,:]
            ongoing_bhv = bhv[bhv[:Streak_n].==i,:]
            if size(ongoing_ev,1) != size(ongoing_bhv,1)
                difference = size(ongoing_ev,1) - size(ongoing_bhv,1)
                println("streak_n $(i) has $(difference) more pokes")
                wrongpokes = find(ongoing_ev[:PokeDur] .== minimum(ongoing_ev[:PokeDur]))
                push!(incorrect,wrongpokes)
                for w in wrongpokes
                    w_P = ongoing_ev[w,:Poke_n]
                    w_P_idx = find(events[:Poke_n].== w_P)
                    for x in [:Out,:Out_t]
                        events[w_P_idx,x] = events[w_P_idx+1,x]
                    end
                    events[w_P_idx,:PokeDur] = events[w_P_idx,:PokeDur] + events[w_P_idx+1,:PokeDur]
                end
                deleterows!(events, wrongpokes.+1)
                events[:Poke_n] = collect(1:size(events,1))
            end
        end
    else
        println("number of streaks is incorrect")
        println( "size event streak = $(maximum(events[:Streak_n])), size bhv streaks = $(maximum(bhv[:Streak_n]))")
        return nothing
    end
    return incorrect
end

"""
`sliding_f0`
"""

function sliding_f0(traces::AbstractDataFrame,ongoing_trace::Symbol,norm_range::Range) # return one ShiftedArray
    ongoing = traces[ongoing_trace]
    sliding_f0(ongoing,norm_range)
end

function sliding_f0(ongoing_trace::Vector,norm_range::Range) #return one normalised vector
    sliding_start = - (norm_range.start + norm_range.stop)
    transformed_trace = repmat([0.0],sliding_start)
    for i = sliding_start+1:size(ongoing_trace,1)
        interval_stop = i + norm_range.stop
        interval_start =  interval_stop + norm_range.start
        interval_range = interval_start:interval_stop
        ongoing_interval = ongoing_trace[interval_range]
        mask = ongoing_interval.<median(ongoing_interval)
        ongoing_f0 = mean(ongoing_interval[mask])
        normalised_value = (ongoing_trace[i] - ongoing_f0)/ongoing_f0
        push!(transformed_trace,normalised_value)
    end
    return transformed_trace
end



"""
`process_photo`
It requires a DataIndex table and the raw to process
keywars:
fps(frame per second) = camera acquisition rate default is 50
Nidaq_rate = it's the rate of acquisition of the behaviour, default is 1000
onlystructure = by default return only the PhotometryStructure
    if false it the following variables
    structure, traces, events, bhv, streaks
"""
function process_photo(DataIndex, idx;fps=50,NiDaq_rate=1000, onlystructure = true)
    mat_filepath = DataIndex[idx,:Cam_Path]
    analog_filepath = DataIndex[idx,:Log_Path]
    raw_path = DataIndex[idx,:Bhv_Path]
    cam = adjust_matfile(mat_filepath);
    #events is a DataFrame with the PokeIn and PokeOut frames
    #rec_type is true if rewards were tracked
    analog, events, rec_type = adjust_logfile(analog_filepath,conversion_rate =fps, acquisition_rate =NiDaq_rate);
    bhv = process_pokes(raw_path);
    # some file recorded separetely Left and Right Pokes
    # but not the other task info, so check check_accordance
    # updates rectype
    check_accordance!(bhv,events,analog_filepath,rec_type)
    # if pokes where recorded only on one trace streaks
    #have to be infered from bhv
    if !rec_type
        edit_events!(bhv,events,analog)
    end
    analog = add_streaks(analog, events)
    #extended trace info
    trace = join(cam,analog,on=:Frame);
    #essential traces only Pokes signals and references
    Cols = names(trace);
    Columns = string.(Cols);
    result = Columns[contains.(Columns,"_sig").|contains.(Columns,"_ref")]
    norm_range = -11*fps:-1*fps
    for x in result
        new_col = "sn_"*x
        trace[Symbol(new_col)] = sliding_f0(trace[Symbol(x)],norm_range)
    end
    result = vcat(result,["sn_"*x for x in result],["Pokes"])
    essential = trace[:,Symbol.(result)]
    bhv = join(bhv,events[:,[:Poke_n,:In,:Out]], on = :Poke_n)
    streaks = process_streaks(bhv; photometry = true)
    structure = PhotometryStructure(bhv,streaks,essential);
    if onlystructure
        return structure
    elseif !onlystructure # if you want take a look to the events dataframe mostly
        return structure, traces, events, bhv, streaks
    end
end

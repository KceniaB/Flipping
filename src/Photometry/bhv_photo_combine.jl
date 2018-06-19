"""
'check_accordance!'
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
    # some file recorded separetely Left and Righe Pokes
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
    Cols = trace.colindex.names;
    Columns = string.(Cols);
    result = Columns[contains.(Columns,"_sig").|contains.(Columns,"_ref")]
    push!(result,"Pokes")
    essential = trace[:,Symbol.(result)]
    bhv = join(bhv,events[:,[:Poke_n,:In,:Out]], on = :Poke_n)
    streaks = process_streaks(bhv; photometry = true)
    structure = PhotometryStructure(bhv,streaks,essential);
    if onlystructure
        return structure
    elseif !onlystructure
        return structure, traces, events, bhv, streaks
    end
end
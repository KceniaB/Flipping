"""
`paths_dataframe`
Create a Dataframe to store paths of files to preprocess
"""
function paths_dataframe(bhv)
    behavior = DataFrame()
    behavior[:Bhv_Path]= bhv
    ##### extract date and mouse ID per session using get_mousedate (it works with a full path)
    MouseID = Array{String}(size(behavior,1))
    Day = Array{String}(size(behavior,1))
    Session = Array{String}(size(behavior,1))
    for i = collect(1:size(behavior,1))
        MouseID[i], Day[i], Session[i] = get_BHVmousedate(behavior[i,:Bhv_Path])
    end
    behavior[:MouseID] = MouseID
    behavior[:Day] = Day#file properties are not reliable for the date of the session
    behavior[:Session] = Session.*".csv";
    return behavior
end


"""
`createfilelist`
use get_data function to obtain all filenames of behaviour
"""
function createfilelist(Directory_path::String, Mice_suffix::String)
    bhv = get_data(Directory_path,:bhv)
    #use get_sessionname to select relevant session (for instance use exp naming code)
    bhv_session = map(t->get_sessionname(t,Mice_suffix),bhv)#to be changed for each dataframe
    # get_sessionname return a start result for sessions that don't match the criteria this can be used to prune irrelevant paths
    bhv = bhv[bhv_session.!="start"]
    bhv_session = bhv_session[bhv_session.!="start"]
    return bhv
end

"""
`get_data`

Functions to find the path to data files according to character pattern considering that each session is a subfolder
Get data revised: this version operate in 2 possible way,
in the first way it will looks for file names containing a specified string
in the second way use a symbol to refer to a dictionary and find the specified string
"""
#Method 1 inputs a directory and a string
function get_data(dirnames,what::String)
    location = String[] #array to load with all the paths corrisponding to researched file type
    if eltype(dirnames)== Char #in case only one folder is loaded the for loop would research in single character
        tool = String[]
        push!(tool,dirnames)
        dirnames = tool
    end
    for dirname in dirnames
        files = readdir(dirname)
        for file in files
            if ismatch(Regex(what), file)
                complete_filename = joinpath(dirname,file)
                push!(location,complete_filename)
            end
        end
    end
    return location
end
#Method 2 a directory and a symbol
function get_data(dirnames, kind::Symbol)
    #the dictionary refers the symbol in the input to a specific string to look for
    ext_dict = Dict(:bhv => "a.csv", :cam => ".mat", :log => "AI.csv")
    if !(kind in keys(ext_dict))
        error("Choose among $(keys(ext_dict))")
    end
    #once the string is identified the function call itself again with the first method
    return get_data(dirnames, ext_dict[kind])
end

"""
`get_sessionname(filepath, what::String)`

Use it to find the name of a session from a path, can accept a string or a symbol connected to a dict to find
file matching the requirements
"""
#this function extract the name of a session from a filepath according to a given character pattern
function get_sessionname(filepath, what::String)
    pathinfo = split(filepath,"/")
    sessionname = "start"
    for piece in pathinfo
        if ismatch(Regex(what), string(piece))
            sessionname = piece
        end
    end
    sessionname = String(sessionname)
    return sessionname
end


# the second method allows to save experiment related character pattern in a dictionary
function get_sessionname(filepath, kind::Symbol)
    #the dictionary refers the symbol in the input to a specific string to look for
    ext_dict = Dict(:GcAMP => "170", :BilNac => "NB")
    if !(kind in keys(ext_dict))
        error("Choose among $(keys(ext_dict))")
    end
    #once the string is identified the function call itself again with the first method
    return get_sessionname(filepath, ext_dict[kind])
end

"""
`get_session`
Generalise version
"""
function get_session(filepath,what::String)
    a = get_sessionname(filepath,what)
    b = match(r"[a-zA-Z]{2}\d+",a)
    c = b.match
    if ismatch(r"\d{8}",a)
        d = match(r"\d{8}",a)
        e = d.match
        e = e[3:8]
    else
        d = match(r"\d{6}",a)
        e = c.match
    end
    sessione = c*"_"*e
    return sessione
end

"""
`gatherfilesphotometry`
"""
function gatherfilesphotometry(Camera_path::String,Behavior_path::String,Mice_suffix::String,bad_days)
    cam = get_data(Camera_path,:cam)
    #use get_sessionname to select relevant session (for instance use exp naming code)
    cam_session = map(t->get_sessionname(t,Mice_suffix),cam)
    # get_sessionname return a start result for sessions that don't match the criteria this can be used to prune irrelevant paths
    cam = cam[cam_session.!="start"]
    cam_session =cam_session[cam_session.!="start"]
    #create a DataFrame suitable to compare behaviour and cam+log session
    camera = DataFrame()
    camera[:Cam_Path]= cam
    camera[:Cam_Session]= cam_session;
    #extract date and mouse ID per session using get_mousedate (it works with a full path)
    # compose logAI file name from mat file
    camera[:Log_Session]=[replace(f, ".mat", "_logAI.csv") for f in camera[:Cam_Session]];
    camera[:Log_Path]=[replace(f, ".mat", "_logAI.csv") for f in camera[:Cam_Path]];
    #Identifies information from file name using get_mousedate function in a for loop
    MouseID = Array{String}(size(camera,1))
    Day2 = Array{Date}(size(camera,1))
    Area = Array{String}(size(camera,1))
    for i = collect(1:size(camera,1))
        MouseID[i], Day2[i], Area[i] = get_CAMmousedate(camera[i,:Cam_Path],Mice_suffix)
    end
    camera[:MouseID] = MouseID
    camera[:Day2] = Day2
    camera[:Area] = Area
    file_components = Array{String}(size(camera,1),2)
    for i = 1:size(camera,1)
        file_components[i,1] = String(split(camera[i,:Cam_Session], "_")[2])
        file_components[i,2] = String(split(camera[i,:Cam_Session], "_")[3])
    end
    correct_date = Array{Date}(size(camera,1))
    dformat = Dates.DateFormat("yyyymmdd")
    for i = 1:size(camera,1)
        try
            correct_date[i]= Date(file_components[i,2],dformat)
        catch
            correct_date[i] = Date(file_components[i,1],dformat)
        end
    end
    camera[:Day] = correct_date;
    exp_days = minimum(camera[:Day]):maximum(camera[:Day])
    good_days = [day for day in exp_days if ! (day in bad_days)];
    camera=camera[[(d in good_days) for d in camera[:Day]],:];
    # use get_data function to obtain all filenames of behaviour
    bhv = get_data(Behavior_path,:bhv)
    #use get_sessionname to select relevant session (for instance use exp naming code)
    bhv_session = map(t->get_sessionname(t,Mice_suffix),bhv)#to be changed for each dataframe
    # get_sessionname return a start result for sessions that don't match the criteria this can be used to prune irrelevant paths
    bhv = bhv[bhv_session.!="start"]
    bhv_session = bhv_session[bhv_session.!="start"]
    #create a DataFrame suitable to compare behaviour and cam+log session
    ###
    behavior = DataFrame()
    behavior[:Bhv_Path]= bhv
    behavior[:Bhv_Session]= bhv_session
    #extract date and mouse ID per session using get_mousedate (it works with a full path)
    MouseID = Array{String}(size(behavior,1))
    Day2 = Array{String}(size(behavior,1))
    Area = Array{String}(size(behavior,1))
    for i = collect(1:size(behavior,1))
        MouseID[i], Day2[i], Area[i] = get_BHVmousedate(behavior[i,:Bhv_Path])
    end
    behavior[:MouseID] = MouseID
    behavior[:Day2] = Day2#file properties are not reliable for the date of the session
    behavior[:Day] = Date(Day2,"yyyymmdd")
    behavior = behavior[[(bho in good_days) for bho in behavior[:Day]],:];
    println("accordance between cam and behavior dates");
    println(sort(union(behavior[:Day])) == sort(union(camera[:Day])));
    if sort(union(behavior[:Day])) != sort(union(camera[:Day]))
        println(symdiff(sort(union(camera[:Day])),sort(union(behavior[:Day]))))
    end
    DataIndex = join(camera, behavior, on = [:MouseID, :Day], kind = :inner, makeunique = true);
    provisory = [] #create general session field
    for x in DataIndex[:Bhv_Session]
        push!(provisory,replace(x,"a.csv",""))
    end
    DataIndex[:Exp_Path]= replace(Camera_path,"Cam/","")
    DataIndex[:Exp_Name]=String(split(DataIndex[1,:Exp_Path],"/")[end-1])
    DataIndex[:Session] = provisory
    for x in[:Day2,:Day2_1]
        delete!(DataIndex, x)
    end
    return DataIndex
end

"""
`check_fiberlocation`

look for a dataset where fiberlocation across day is stored
"""
function check_fiberlocation(data,Directory_path,Exp_name)
    filetofind=joinpath(Directory_path*"run_task_photo/"*Exp_name*"/FiberLocation"*".csv");
    if isfile(filetofind)
        fiberlocation = FileIO.load(filetofind) |>DataFrame;
        merged_data = join(data, fiberlocation, on = :Session, kind = :inner,makeunique=true);
        println("found fibres location file, HAVE YOU UPDATED IT?")
    else
        println("no fibres location file")
        merged_data = data;
    end
    for x in [:MouseID_1,:Day_1,:Area_1]
        delete!(merged_data, x)
    end
    return merged_data
end

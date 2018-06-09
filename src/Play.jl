using Flipping
plotly()
####
Directory_path = joinpath("/Users/dariosarra/Google Drive/Flipping/");
Camera_path = "/Users/dariosarra/Google Drive/Flipping/run_task_photo/Sert-Gcamp DRN/Cam/"
Behavior_path = "/Users/dariosarra/Google Drive/Flipping/run_task_photo/raw_data"
Exp_type = "Photometry";
Exp_name = "Sert-Gcamp DRN"
Mice_suffix = "GD";
Saving_path = "/Users/dariosarra/Google Drive/Flipping/Datasets";

training_days = Dates.Date(2018,5,14):Dates.Date(2017,5,15)
issues_days = Dates.Date(2016,12,31):Dates.Date(2017,1,1)
bad_days = vcat(training_days, issues_days)
DataIndex = gatherfilesphotometry(Camera_path::String,Behavior_path::String,Mice_suffix::String,bad_days)
DataIndex = check_fiberlocation(DataIndex,Exp_name);
##
q=1
function process_photo(DataIndex, idx;fps=50,NiDaq_rate=1000)
    mat_filepath = DataIndex[idx,:Cam_Path]
    analog_filepath = DataIndex[idx,:Log_Path]
    raw_path = DataIndex[idx,:Bhv_Path]
    cam = adjust_matfile(mat_filepath);
    analog, events, rec_type = adjust_logfile(analog_filepath,conversion_rate =fps, acquisition_rate =NiDaq_rate);
    bhv = process_pokes(raw_path);
    if size(bhv,1)!=size(events,1)
        if size(bhv,1)/size(events,1)>1.5
            analog, events = adjust_logfile(analog_filepath; force = true)
        end
        if size(bhv,1)>size(events,1)
            short_pokes = ghost_buster(bhv,analog)
        end
        if size(bhv,1)==size(events,1)
         println("All good file adjusted")
        else
            println("Ops it didn't work")
        end
    end
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
    start =  events[1,:IN]-5*fps
    if start<1
        start = 1
    end
    finish = events[1,:Out]+5*fps
    if finish > size(trace,1)
        finish = size(trace,1)
    end
    trace=trace[start:finish,:]
    return trace, events, bhv
end
##
events
analog
union(analog[:Poke_n])
if rec_type


end
size(events,1)
size(bhv,1)
##
##
session=["GD10_180517","GD9_180518","GD10_180518","GD2_180524","GD5_180530","GD6_180531",
"GD9_180530"];
cam_session=["GD10_DRN_20180517","GD9_DRN_20180518","GD10_DRN_20180518","GD2_DRN_20180524",
"GD5_DRN_20180530","GD6_DRN_20180531","GD9_DRN_20180530"];
q=1
raw_path = "/Users/dariosarra/Google Drive/Flipping/run_task_photo/raw_data/"*session[q]*"a.csv"
exp_path = "/Users/dariosarra/Google Drive/Flipping/run_task_photo/Sert-Gcamp DRN/"
bhv_filepath = exp_path*"Bhv/"*session[q]*".csv"
mat_filepath= exp_path*"Cam/"*cam_session[q]*"_000.mat"
analog_filepath =exp_path*"Cam/"*cam_session[q]*"_000_logAI.csv"
#old_log = preprocess_photometry(mat_filepath,analog_filepath);
cam = adjust_matfile(mat_filepath);
analog,events = adjust_logfile(analog_filepath);
bhv = process_pokes(raw_path);
if size(bhv,1)/size(events,1)>1.5
    analog, events = adjust_logfile(analog_filepath; force = true)
end
if size(bhv,1)>size(events,1)
    short_pokes = ghost_buster(bhv,analog)
end
##
short_pokes
bhv[short_pokes[1]-2:short_pokes[1]+2,[:PokeIn,:PokeOut,:PokeDur,:InterPoke]]
bhv[1:6,[:PokeIn,:PokeOut,:PokeDur,:InterPoke]]

events[1:6,[:In_t,:Out_t,:PokeDur]]




events[short_pokes[1]-2:short_pokes[1]+2,[:In_t,:Out_t,:PokeDur]]
size(events,1)
size(bhv,1)
t=bhv[bhv[:PokeDur].>0.1019999999999,:];
minimum(bhv[:PokeDur])
size(t)
bhv
##

##
plot(Int64.(analog[:R_p]))
plot!(Int64.(analog[:L_p]))
##

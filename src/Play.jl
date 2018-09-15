using Flipping
Directory_path = joinpath("/Users/dariosarra/Google Drive/Flipping/");
Exp_type = "Photometry";
Exp_name = "AAV_Gcamp_DRN"
Camera_path = "/Users/dariosarra/Google Drive/Flipping/run_task_photo/"*Exp_name*"/Cam/"
Behavior_path = "/Users/dariosarra/Google Drive/Flipping/run_task_photo/raw_data"
Mice_suffix = "GV";
Saving_path = "/Users/dariosarra/Google Drive/Flipping/Datasets";
training_days = Dates.Date(2018,5,14):Dates.Date(2017,5,15)
issues_days = Dates.Date(2016,12,31):Dates.Date(2017,1,1)
bad_days = vcat(training_days, issues_days)
DataIndex = gatherfilesphotometry(Camera_path::String,Behavior_path::String,Mice_suffix::String,bad_days)
DataIndex = check_fiberlocation(DataIndex,Exp_name);
##
idx=4;
mat_filepath = DataIndex[idx,:Cam_Path]
analog_filepath = DataIndex[idx,:Log_Path]
raw_path = DataIndex[idx,:Bhv_Path]
cam = adjust_matfile(mat_filepath);
#events is a DataFrame with the PokeIn and PokeOut frames
#rec_type is true if rewards were tracked
analog, events, rec_type = adjust_logfile(analog_filepath);
bhv = process_pokes(raw_path);
##
function ghost_buster(events,bhv)
    if maximum(bhv[:Streak_n])==maximum(events[:Streak_n])
        for i = 1:maximum(bhv[:Streak_n])
            ongoing_ev = events[events[:Streak_n].==i,:]
            ongoing_bhv = bhv[bhv[:Streak_n].==i,:]
            if size(ongoing_ev,1) != size(ongoing_bhv,1)
                difference = size(ongoing_ev,1) - size(ongoing_bhv,1)
                println("streak_n $(i) has $(difference) more pokes")
                wrongpokes = find(ongoing_ev[:Poke_Dur] .== minimum(ongoing_ev[:Poke_Dur])
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
    end
    return events
end
names(events)
find(events[:PokeDur] .== minimum(events[:PokeDur]))

events[90:95,[:Poke_n,:PokeDur,:InterPoke,:In,:Out]]
bhv[90:95,[:Poke_n,:PokeDur,:Streak_n]]
##
plotly()
##
scatter(bhv[90:92,:PokeIn],repmat([1],size(bhv[90:92,:],1)),ylims=(0.99,1.06))
scatter!(bhv[90:92,:PokeOut],repmat([1],size(bhv[90:92,:],1)),ylims=(0.99,1.06),marker = :hex)
scatter!(events[90:92,:In_t],repmat([1.05],size(events[90:92,:],1)),ylims=(0.99,1.06))
scatter!(events[90:92,:Out_t],repmat([1.05],size(events[90:92,:],1)),ylims=(0.99,1.06),marker = :hex)
##
plot(analog[:R_p])
plot(analog())
##
events[1,:]
events[end-2,:PokeDur]
bhv[end-2,:PokeDur]
##
analog= FileIO.load(analog_filepath,header_exists=false) |> DataFrame;
analog = analog[:,1:6];
names!(analog,[:timestamp,:R_p,:L_p,:Rew,:SideHigh,:Protocol]);
##
plot(analog[:R_p]+analog[:L_p])
plot!(analog[2500:5000,:L_p])
##
plot(analog[:Rew])
##

##

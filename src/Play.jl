using Revise
using Flipping
##
Directory_path = "/home/beatriz/mainen.flipping.5ht@gmail.com/Flipping/";
Exp_type = "Photometry";
Exp_name = "GCaMP_close_pokes"
training_days = Date(2017,5,15):Day(1):Date(2017,5,26)
issues_days = Date(2016,12,31):Day(1):Date(2017,1,1)
bad_days = vcat(training_days, issues_days)
Camera_path = "/Users/dariosarra/Google Drive/Flipping/run_task_photo/DatcreGCaMPAutomaticBarr/Cam/"
Behavior_path = "/Users/dariosarra/Google Drive/Flipping/run_task_photo/raw_data"
Mice_suffix = "DG";
DataIndex = ProcessPhotometry.create_photometry_DataIndex(Directory_path, Exp_type,Exp_name, Mice_suffix;bad_days = bad_days)
names(DataIndex)
#
dformat = Dates.DateFormat("yyyymmdd")
mask = DataIndex[:Day].<=Date("20190717",dformat)
# mask = DataIndex[:MouseID].== "DG2"
DataIndex = DataIndex[mask,:]
# names(DataIndex)
##
pokes, cam_dict = save_bhv_photo(DataIndex)

DataIndex[.!ispath.(DataIndex[:Log_Path]),:Log_Path]
size(DataIndex,1)
union(column(pokes,:MouseID))
union(column(pokes,:Session))
union(DataIndex[:Session])
process_pokes(DataIndex[56,:Bhv_Path])[:MouseID]

Flipping.session_info(DataIndex[56,:Bhv_Path])

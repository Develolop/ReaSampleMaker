print=reaper.ShowConsoleMsg
dofile(reaper.GetResourcePath().."/UserPlugins/ultraschall_api.lua")
package.path = reaper.GetResourcePath() .. '/Scripts/rtk/1/?.lua'
local rtk = require('rtk')
local log = rtk.log

-- to do:
-- set midi input on all midi automatically

-- sample globals--
track_id = 0
track = -1
media_items = 1
media_length = 1
octave_start = 0
note_start = 0
note_volume = 127
max_volume = -60
midi_channel = 1
note_on_msg = 0x90 --| (midi_channel - 1)
reps = 0
note = 0
note_step = 1
is_running = false
----------------
--rtk.log.level = rtk.log.DEBUG

----------------------------GUI--------------------------------------
local main_window = rtk.Window{w= 700, h= 600}
local main_wrapper = main_window:add(rtk.VBox{spacing=10})
local selection_wrapper = main_wrapper:add(rtk.HBox{spacing=2, padding = 4, margin = 6})
local slider_wrapper = main_wrapper:add(rtk.VBox{spacing=2, padding = 4, margin = 6})

-- recoding window
local recording_text = main_window:add(rtk.Heading{'RECORDING',textalign='center',fontsize=150}, {halign='center', valign='center'} )
recording_text.visible = false

-- Start button
local start_button = rtk.Button{label='Start', margin=20}
start_button:attr('color', 'grey') 
start_button.onclick = function()
    start_button:animate{'color', dst='red'}
    start_button:attr('label', "Stop conversion")
    if(is_running == false)then init_start()
    else reps = 4000
    end

end
main_window:add(start_button,{valign='bottom', halign='right'})

function close_start_button()
  start_button:animate{'color', dst='grey'}
  start_button:attr('label', "Start")
end

-- rename button
local rename_button = rtk.Button{label='Rename', margin=20}
rename_button.onclick = function()
    rename_items()
end
main_window:add(rename_button, {valign='bottom', halign='left'})

-- get track button
local get_track_button = rtk.Button{label='Selected track', margin=20}
get_track_button.onclick = function()

    local tmp = reaper.GetSelectedTrack(0, 0)
    if(not(tmp == nil))then 
        track = tmp
    else
        print("Nothing selected or something went wrong")
    end
end
main_window:add(get_track_button, {valign='bottom', halign='center'})

-- channel selection
local track_box = selection_wrapper:add(rtk.VBox{spacing=5, margin=10})
track_box:add(rtk.Heading{'Select Track'}, { valign='top'})
local track_select = track_box:add(rtk.OptionMenu{
    menu={
        {'1', id =0},
        {'2', id =1},
        {'3', id =2},
        {'4', id =3},
      },
  },
  {valign='bottom'}
)
track_select.onchange = function(self, item)
    track_id = item.id
    track = reaper.GetTrack(0, track_id)
end
track_select:select(0)

-- start note selection
local start_note_box = selection_wrapper:add(rtk.VBox{ margin=10, spacing=5})
start_note_box:add(rtk.Heading{'Start note'}, { valign='top'})
local start_note_select = start_note_box:add(rtk.OptionMenu{
    menu={
        {'C', id =0},
        {'C#', id =1},
        {'D', id =2},
        {'D#', id =3},
        {'E', id =4},
        {'F', id =5},
        {'F#', id =6},
        {'G', id =7},
        {'G#', id =8},
        {'A', id =9},
        {'A#', id =10},
        {'B', id =11}
      },
  },
  {valign='bottom'}
)
start_note_select.onchange = function(self, item)
  note_start = item.id

end
start_note_select:select(0)

-- start octave selection
local start_octave_box = selection_wrapper:add(rtk.VBox{ margin=10, spacing=5})
start_octave_box:add(rtk.Heading{'Start octave'}, { valign='top'})
local start_octave_select = start_octave_box:add(rtk.OptionMenu{
    menu={
        {'0', id =0},
        {'1', id =1},
        {'2', id =2},
        {'3', id =3},
        {'4', id =4},
        {'5', id =5},
        {'6', id =6},
        {'7', id =7},
        {'8', id =8},
        {'9', id =9},
        {'10', id =10},
      },
  },
  {valign='bottom'}
)
start_octave_select.onchange = function(self, item)
  octave_start = item.id

end
start_octave_select:select(0)

-- step selection 
local step_box = selection_wrapper:add(rtk.VBox{ margin=10, spacing=5})
step_box:add(rtk.Heading{'Step range'}, { valign='top'})
local step_select = step_box:add(rtk.OptionMenu{
    menu={
        {'1', id =1},
        {'2', id =2},
        {'3', id =3},
        {'4', id =4},
        {'5', id =5},
        {'6', id =6},
        {'7', id =7},
        {'8', id =8},
        {'9', id =9},
        {'10', id =10},
        {'11', id =11},
        {'12', id =12},
      },
  },
  {valign='bottom'}
)
step_select.onchange = function(self, item)
note_step = item.id

end
step_select:select(1)

-- media item slider 
slider_wrapper:add(rtk.Heading{'Item count'})
local media_item_slider_wrapper = slider_wrapper:add(rtk.HBox())
local media_item_slider_min = media_item_slider_wrapper:add(rtk.Text{'1', w=25})
local media_item_slider  = media_item_slider_wrapper:add(rtk.Slider{step=1, min=1, max=24, ticks=true, spacing=0.5,padding = 4, fontsize = 0.5})
local media_item_slider_selected = media_item_slider_wrapper:add(rtk.Text{'1', w=25})
media_item_slider.onchange = function (self)
  media_items = self.value
  media_item_slider_selected:attr('text', self.value)
end

-- media_length slider
slider_wrapper:add(rtk.Heading{'Min length'})
local media_length_slider_wrapper = slider_wrapper:add(rtk.HBox())
local media_length_slider_min = media_length_slider_wrapper:add(rtk.Text{'1', w=25})
local media_length_slider  = media_length_slider_wrapper:add(rtk.Slider{step=1, min=1, max=24, ticks=true, spacing=0.5,padding = 4, fontsize = 0.5})
local media_length_slider_selected = media_length_slider_wrapper:add(rtk.Text{'1', w=25})
media_length_slider.onchange = function (self)
  media_length = self.value
  media_length_slider_selected:attr('text', self.value)
end

-- max volume slider 
slider_wrapper:add(rtk.Heading{'Volume threshold'})
local max_volume_slider_wrapper = slider_wrapper:add(rtk.HBox())
local max_volume_slider_min = max_volume_slider_wrapper:add(rtk.Text{'-200', w=25})
local max_volume_slider  = max_volume_slider_wrapper:add(rtk.Slider{step=1, min=-200, max=1, ticks=false, spacing=0.5,padding = 4, fontsize = 0.5})
local max_volume_slider_selected = max_volume_slider_wrapper:add(rtk.Text{'1', w=25})
max_volume_slider.onchange = function (self)
  max_volume = self.value
  max_volume_slider_selected:attr('text', self.value)
end

-- hide slider 
function hide_slider()
  slider_wrapper.visible = false
end

function show_slider()
  slider_wrapper.visible = true
end

function hide_selection()
  selection_wrapper.visible = false
end
function show_selection()
  selection_wrapper.visible = true
end

function show_converting()
  hide_selection()
  hide_slider()
  recording_text.visible = true
  
end

function hide_converting()
  show_selection()
  show_slider()

  recording_text.visible = false
end

main_window:open{align='center'}


------------------------sampling--------------------------------------

-- stop recording
function stop_record()
  reaper.SetMediaTrackInfo_Value( track, "I_RECARM",0) 
  reaper.Main_OnCommand(1013, 1)
  close_start_button()
  is_running = false
  rename_items()
  hide_converting()
end

-- Start recording
track = reaper.GetTrack(0, track_id)
-- peak test
function wait_for_peak()
  reaper.ClearConsole()
  reaper.ClearPeakCache() 
  peak = (reaper.Track_GetPeakInfo(track, 1))
  amp_dB = 8.6562

  peak_in_dB = amp_dB*math.log(peak)


-- wait for peak
  if(peak_in_dB > max_volume) then
    ultraschall.Defer(wait_for_peak," ", 2, 0.5)
-- loop until max media items reached
  elseif reps < media_items then
    reaper.SetMediaTrackInfo_Value( track, "I_RECARM",0) 
    
    ultraschall.Defer(conversion,"bla", 2,2)
-- turn off recording
  else 
    stop_record()
  end
end

function sleep()
  reaper.StuffMIDIMessage(0, note_on_msg, note, 0)
  
  note = note + note_step

  wait_for_peak()
  --wait_for_peak(ultraschall.Defer(wait_for_peak," ", 2,2))
end
function wait_after_midi()
    reaper.StuffMIDIMessage(0, note_on_msg, note, note_volume)
    ultraschall.Defer(sleep,"blala", 2, media_length)
end

-- Start recording
function conversion()

  if(is_running == false)then
    is_running = true
    reaper.Main_OnCommand(1013, 0) -- Transport: Record
  end
  reps = reps +1
  reaper.SetMediaTrackInfo_Value(track, "I_RECARM",1)
  --sleep(0.1)
  
  ultraschall.Defer(wait_after_midi,"blala", 2, 0.2)
  return
end
-- init before recording
function init_start()
    reps = 0
    if((media_items*note_step + octave_start*12 + note_start) > 127) then
      print("Last note out of midi range!")
      close_start_button()
      return
    end
    show_converting()
    if(track == -1)then track = reaper.GetTrack(0, track_id) end
    local bits_set=tonumber('111111'..'00000',2)
    reaper.SetMediaTrackInfo_Value( track, 'I_RECINPUT', 4096+bits_set ) -- set input to all MIDI
    note = note_start + octave_start * 12
    conversion()
end
------------------------rename items--------------------------------------

function rename_items()
    track_item_count = reaper.CountTrackMediaItems(track)
    if(not(track_item_count == media_items)) then
        print("Something went wrong while renaming.\nNames may be wrong!")
        if(track_item_count < 1) then
            return
        end
    end

    for i=0, track_item_count-1, 1 do
        local note = note_start + octave_start * 12 + note_step * i
        local item = reaper.GetTrackMediaItem(track, i)
        local take = reaper.GetMediaItemTake(item, 0)
        reaper.GetSetMediaItemTakeInfo_String(take, 'P_NAME', number_to_note(note), true)
        
    end
    --reaper.DeleteTrackMediaItem(track, item)
    --print(item)
end

function number_to_note(n)

    local midi_note = n
    local octave = math.floor(n / 12 )
    local note
    if not(octave==0) then
      note = n % (octave *12)
    else
      note = n
    end

    if note == 0 then note = 'C'
    elseif note == 1 then   note = 'C#'
    elseif note == 2 then   note = 'D'
    elseif note == 3 then   note = 'D#'
    elseif note == 4 then   note = 'E'
    elseif note == 5 then   note = 'F'
    elseif note == 6 then   note = 'F#'
    elseif note == 7 then   note = 'G'
    elseif note == 8 then   note = 'G#'
    elseif note == 9 then   note = 'A'
    elseif note == 10 then   note = 'A#'
    elseif note == 11 then   note = 'B'
    else note = 'Something went wrong with your note!'
    end
    return tostring(note) .. tostring(octave) .. " " .. tostring(midi_note)
end
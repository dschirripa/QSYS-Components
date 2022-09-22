CurrentCamera = Controls["Currently Selected Camera"];
FrontCameraCoordinates = Controls["Front Camera Coordinates"];
RearCameraCoordinates = Controls["Rear Camera Coordinates"];
SetFrontCameraCoordinates = Controls["Set Front Camera Coordinates"];
SetRearCameraCoordinates = Controls["Set Rear Camera Coordinates"]
PresetSaved = Controls["Preset Saved Feedback"];

FrontCameraPresets = {};
RearCameraPresets = {};

for k,v in ipairs(Controls["Set Preset"]) do
  v.EventHandler = function()
    --Set preset based on current camera selection
    if CurrentCamera.Boolean == true then
      -- Front Camera selected
      FrontCameraPresets[k] = FrontCameraCoordinates.String;
    elseif CurrentCamera.Boolean == false then
      RearCameraPresets[k] = RearCameraCoordinates.String;
    end;
    SaveCameraPresets();
    PresetSaved.Boolean = true;
    Timer.CallAfter(function() PresetSaved.Boolean = false end, 1);
  end;
end;

for k,v in ipairs(Controls["Recall Preset"]) do
  v.EventHandler = function()
    if CurrentCamera.Boolean == true then
      if FrontCameraPresets[k] == nil then
        return;
      end;
      SetFrontCameraCoordinates.String = FrontCameraPresets[k];
    elseif CurrentCamera.Boolean == false then
      if RearCameraPresets[k] == nil then
        return;
      end;
      SetRearCameraCoordinates.String = RearCameraPresets[k];
    end;
  end;
end;

function SaveCameraPresets()
  print("Saving Front Presets...");
  CameraPresetFile = io.open("media/FrontCameraPresets.cfg", "w+");
  for k,v in ipairs (FrontCameraPresets) do
    CameraPresetFile:write(tostring(v).."\r\n");
    print("Saved Preset"..k..": "..v);
  end;
  CameraPresetFile:close();
  print("Saving Rear Presets...");
  CameraPresetFile = io.open("media/RearCameraPresets.cfg", "w+");
  for k,v in ipairs(RearCameraPresets) do
    CameraPresetFile:write(tostring(v).."\r\n");
    print("Saved Preset"..k..": "..v);
  end;
  CameraPresetFile:close();
  print("Presets Saved");
end;

function LoadCameraPresets()
  print("Loading Front Presets")
  n = 0;
  for line in io.lines("media/FrontCameraPresets.cfg") do
    n = n + 1;
    FrontCameraPresets[n] = line;
    print("Loaded Preset"..n..": "..line);
  end;
  print("Loading Rear Presets")
  n = 0;
  for line in io.lines("media/RearCameraPresets.cfg") do
    n = n+1;
    RearCameraPresets[n] = line;
    print("Loaded Preset"..n..": "..line);
  end;
end;

LoadCameraPresets();

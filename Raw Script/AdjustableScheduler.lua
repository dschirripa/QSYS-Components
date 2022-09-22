
-- Check current time every minute
Controls["Current Time"].EventHandler = function()
  -- If Bypassed, don't bother
  Time = Controls["Current Time"].String;
  if Controls["Schedule Bypass"] then
    return;
  end;

  -- If the Current Time is equal to the defined Start Time, then disable the mute
  if Time == Controls["Start Time"].String then
    Controls["Scheduled Toggle"].Boolean = false;
  -- if the Current Time is equal to the defined End Time, then enable the mute
  elseif Time == Controls["End Time"].String then
    Controls["Scheduled Toggle"].Boolean = true;
  end;

end;

Controls["Start Time"].EventHandler = function()
  Starttime = Controls["Start Time"].String;
  Hours = tonumber(string.sub(Starttime, 1,string.find(Starttime, ":") - 1));
  Minutes = tonumber(string.sub(Starttime, string.find(Starttime, ":") + 1, 5));
  if Hours > 24 or Hours < 0 then
    Hours = 07;
  end;
  if Minutes > 60 or Minutes < 0 then
    Minutes = 0;
  end;

  if Hours < 10 then
    Hours = "0"..tostring(Hours);
  end;

  if Minutes < 10 then
    Minutes = "0"..tostring(Minutes);
  end;
  Controls["Start Time"].String = Hours..":"..Minutes;
end;

Controls["End Time"].EventHandler = function()
  Endtime = Controls["End Time"].String;
  Hours = tonumber(string.sub(Endtime, 1,string.find(Endtime, ":") - 1));
  Minutes = tonumber(string.sub(Endtime, string.find(Endtime, ":") + 1, 5));
  if Hours > 24 or Hours < 0 then
    Hours = 07;
  end;
  if Minutes > 60 or Minutes < 0 then
    Minutes = 0;
  end;

  if Hours < 10 then
    Hours = "0"..tostring(Hours);
  end;

  if Minutes < 10 then
    Minutes = "0"..tostring(Minutes);
  end;

  Controls["End Time"].String = Hours..":"..Minutes;
end;

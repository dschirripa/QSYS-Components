--[[
  Author: Daniel Schirripa
  Email:  dschirripa@onediversified.com

  Control script for Atlona OPUS Switcher

  Summary of operations:

    Automatically connect to specified IP address and Port and login
    As per documentation, buffer commands in a Queue and send every half second

    Use the "TieVerificationCallback" method to show proper feedback on the buttons
      When a tie is made, the button will appear the color specified by TiePendingColor until the switcher reports a success, 
      or until the time allotted by TieVerificationCallbackTime expires

      Once a tie is completed, the color will change accordingly, to TieMadeColor, or TieUnmadeColor
]]



Socket = TcpSocket.New();
IP = Controls.IP.String;
Port = tonumber(Controls.Port.String);
StatusFeedback = Controls.Status;
TieCallBackVerificationTime = 6;
TiePendingColor = "#4DFFFF00";
TieMadeColor = "#4D07FF00";
TieUnmadeColor = "#4DFFFFFF";

Controls.IP.EventHandler = Reconnect;
 
Controls.Port.EventHandler = Reconnect;

Controls.Username.EventHandler = Reconnect;
Controls.Password.EventHandler = Reconnect;

--------------- Queue Functions ----------------
Queue = {}
function Queue.new()
  return {first = 0, last = -1}
end;

-- Add a value to the end of the queue
function Queue.add(list, value)
  local last = list.last + 1;
  list.last = last;
  list[last] = value;
end;

-- Return and remove the head of the queue
function Queue.pop(list)
  local first = list.first;
  if first > list.last then return nil end;
  local value = list[first];
  list[first] = nil;
  list.first = first + 1; 
  return value;
end;
---------------------------------------------


CommandBuffer = Queue.new();

TiesPendingApproval = {}

-- Verify that the switch has actually made the ties that have been requested
function TieCallback(tie)
  if TiesPendingApproval[tie] == false then
    Controls["Input Selection"][tie].Boolean = false;
    Controls["Input Selection"][tie].Color = TieUnmadeColor;
    return;
  end; 
  Controls["Input Selection"][tie].Boolean = true;
  Controls["Input Selection"][tie].Color = TieMadeColor;
end;

-- Check if a String starts with a String
function startsWith(String, Start)
  return string.sub(String,1,string.len(Start)) == Start;
end; 

-- Set all Input Selection buttons to fire the correct command
for k,v in ipairs(Controls["Input Selection"]) do
  Controls["Input Selection"][k].EventHandler = function()
    print("Selected "..tostring(k));
    TiesPendingApproval[k] = false;
    v.Color = TiePendingColor;
    Timer.CallAfter(function() TieCallback(k) end, tonumber(TieCallBackVerificationTime));
    Socket:Write("x" .. tostring(k) .. "AVx1\r\n");
  end;
end;

-- Initialize Connection
function InitSocket()
  IP = Controls.IP.String;
  Port = tonumber(Controls.Port.String);
  print("Connecting to " .. IP .. ":" .. Port);
  Socket:Connect(IP, tonumber(Port));
end; 

-- Reconnect the socket
function Reconnect()
  Socket:Disconnect();
  InitSocket();
end;

-- Complete necessary operations once a connection has been made
function SocketConnection()
  Controls.Connection.Boolean = true;
  StatusFeedback.String = "Connected";
  StatusFeedback.Color = "Green";

  -- Begin Buffer loop
  Timer.CallAfter(SendBuffer, 0.5);
  -- Begin KeepAlive loop
  Timer.CallAfter(KeepAlive, 25);

  -- Queue command entries for Login, and default settings
  Queue.add(CommandBuffer, Controls.Username.String);
  Queue.add(CommandBuffer, Controls.Password.String);
  Queue.add(CommandBuffer, "InputBroadcast on");
  Queue.add(CommandBuffer, "Broadcast on");
  Queue.add(CommandBuffer, "Status");
end;

-- Properly deal with a socket disconnection
function SocketDisconnection()
  Controls.Connection.Boolean = false;
  StatusFeedback.String = "Disconnected";
  StatusFeedback.Color = "Red";
end;

-- Evaluate returned information
function ParseReturn(sock, evt, err)
  if evt == TcpSocket.Events.Connected then
    SocketConnection();
    return;
  elseif evt == TcpSocket.Events.Closed then
    SocketDisconnection();
    print("Closed"); 
    return;
  elseif evt == TcpSocket.Events.Error then 
    SocketDisconnection();
    StatusFeedback.String = ("Connection Closed: " .. tostring(err));
    print("Closed:",err)
  elseif evt == TcpSocket.Events.Data then
    ReadLine = Socket:ReadLine(TcpSocket.EOL.Any);
    while ReadLine ~= nil do
      ParseData(ReadLine);
      ReadLine = Socket:ReadLine(TcpSocket.EOL.Any);
    end;
  end;
end;

-- Parse data returned from the switcher
function ParseData(Data)
  print(Data);
  -- Deal with InputStatus responses (Signal prescence)
  if startsWith(Data, "InputStatus") then
    SignalPrescence = string.sub(Data, 13, string.len(Data));
    n = 1; 
    while n < 5 do 
      if string.sub(SignalPrescence, n, n) == "1" then 
        Controls["Signal Prescence"][n].Boolean = true; 
      else 
        Controls["Signal Prescence"][n].Boolean = false;
      end;
      n = n + 1; 
    end; 
    print(SignalPrescence);
    return;
  end;
  -- Deal with AutoSwitching responses
  if startsWith(Data, "AutoSW") then
    DoAutoSwitch = string.sub(Data, 8, string.len(Data));
    if DoAutoSwitch == "on" then 
      Controls["Auto Switching"].Boolean = true;
    elseif DoAutoSwitch == "off" then
      Controls["Auto Switching"].Boolean = false;
    end;
    return;
  end;
  -- Deal with tie verification responses
  if startsWith(Data, "x") then
    InputNumber = tonumber(string.sub(Data, 2, 2));
    for k,v in ipairs (Controls["Input Selection"]) do
      if k == InputNumber then
        Controls["Input Selection"][k].Boolean = true;
        Controls["Input Selection"][k].Color = TieMadeColor;
        TiesPendingApproval[k] = true;
      else
        Controls["Input Selection"][k].Color = TieUnmadeColor;
        Controls["Input Selection"][k].Boolean = false;
        TiesPendingApproval[k] = false;
      end;
    end;
  end;
end;

-- Fire auto switching toggle commands
Controls["Auto Switching"].EventHandler = function()
  if Controls["Auto Switching"].Boolean then 
    Queue.add(CommandBuffer, "AutoSW on");
    return;
  end;
  Queue.add(CommandBuffer, "AutoSW off");
end;

-- Recursively keep the TCP port open by firing a "Status" command every 25 seconds
function KeepAlive()
  if Controls.Connection.Boolean then
    Queue.add(CommandBuffer, "Status");
    Timer.CallAfter(KeepAlive, 25);
  else 
    return;
  end;
end;

-- Recursively send the commands which have been queued in the "CommandBuffer"
function SendBuffer()
  if Controls.Connection.Boolean then 
    Value = Queue.pop(CommandBuffer);
    if Value == nil then
      Timer.CallAfter(SendBuffer, 0.5);
      return;
    end;

    Socket:Write(Value.."\r\n");
    Timer.CallAfter(SendBuffer, 0.5);
  end;
  return;
end;



-- Initialize the connection
Socket.EventHandler = ParseReturn;
InitSocket();
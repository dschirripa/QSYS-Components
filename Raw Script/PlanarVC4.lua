--[[

  Planar VC4 Basic Wall Control Module
  Daniel Schirripa - 2023

]]
Socket = TcpSocket.New();
StatusTimer = Timer.New();
StatusFeedback = Controls.Status;
ConnectionStatus = Controls.Connected;
PowerOnButton = Controls["Power On"];
PowerOffButton = Controls["Power Off"];
BrightnessKnob = Controls.Brightness;

-- Initiate Connection to specified IP and Port
function connect()
  StatusFeedback.String="Connecting";
  StatusFeedback.Color="#FFFF00";
  Socket:Connect(Controls.IP.String, tonumber(Controls.Port.String));
end;

-- Determine return type, and parse as necessary
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

-- Parse String data returned from the VC4
function ParseData(Data)
  print(Data);
  if Data == "SYSTEM.STATE:FAULT" then
    StatusFeedback.String = "FAULT";
    StatusFeedback.Boolean = false;
  elseif Data == "SYSTEM.STATE:ON" then
    Controls["Power State"].Boolean = true;
    PowerOnButton.Boolean = true;
    PowerOffButton.Boolean = false;
  elseif Data == "SYSTEM.STATE:STANDBY" then
    Controls["Power State"].Boolean = false;
    PowerOnButton.Boolean = false;
    PowerOffButton.Boolean = true;
  end;
end;

-- Drive Status Feedback
function SocketConnection()
  ConnectionStatus.Boolean = true;
  print("Socket Connected");
  StatusFeedback.String = "Connected";
  StatusFeedback.Color = "#008000";
  StatusTimer:Start(0.5)
end;

-- Drive Status Feedback
function SocketDisconnection()
  ConnectionStatus.Boolean = false;
  print("Socket Disconnected");
  StatusFeedback.String = "Closed";
  StatusFeedback.Color = "#FF0000";
  StatusTimer:Stop();
  Timer.CallAfter(function() connect() end, 2);
end;

-- Poll for Power Status
function PollStatus()
  Socket:Write("SYSTEM.STATE?\r");
end;

-- Turn wall power on
PowerOnButton.EventHandler = function()
  Socket:Write("SYSTEM.POWER=ON\r");
end;

-- Tune wall power off
PowerOffButton.EventHandler = function()
  Socket:Write("SYSTEM.POWER=OFF\r");
end;

-- Set wall brightness (0 -100)
BrightnessKnob.EventHandler = function()
  print("BRIGHTNESS=" .. BrightnessKnob.String)
  Socket:Write("BRIGHTNESS=" .. BrightnessKnob.String .. "\r");
end;

Socket.EventHandler = ParseReturn;

Controls.IP.EventHandler = connect;
Controls.Port.EventHandler = connect; 
connect();

StatusTimer.EventHandler = PollStatus; 

-- END
-- dschirripa@ondiversified.com 02/07/2023

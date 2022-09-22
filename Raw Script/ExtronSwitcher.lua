IP = Controls.IP.String;
Port = Controls.Port.String;
Pass = Controls.Password.String;
TieTypeList = Controls["Tie Type"];
TieTypeList.Choices  = {"Video", "Audio", "All"};
ConnectionStatus = Controls["Connection Status"];
StatusFeedback = Controls["Status Feedback"];
TieVerificationCallbackTime = Controls["Tie Verification Callback Time"];

Socket = TcpSocket.New();
PollingTimer = Timer.New();
CurrentInputSelection = 1;

StatusFeedback.String = "Initializing";
StatusFeedback.Color = "#0000FF";

MatrixButtons = {};
TiesPendingApproval = {};

MatrixTiedColor = "#FFFFFFFF";
MatrixUntiedColor = "#FF7C7C7C";
MatrixTiePendingColor = "#FFFF00";

function TieVerificationCallback(Tie)
  if TiesPendingApproval[Tie] == false then
    TiesPendingApproval[Tie] = nil;
    MatrixButtons[Tie].Boolean = false;
    MatrixButtons[Tie].Color = MatrixUntiedColor;
  end;
end;

function DebugPrint(string)
  if Controls["Debug Print"].Boolean then
    print("[Debug] "..string);
  end;
end;

-- Assign all Input buttons to change the stored CurrentInputSelection variable
for k,v in ipairs(Controls.Inputs) do
  v.EventHandler = function()
    local LastSelected = CurrentInputSelection;
    CurrentInputSelection = k;
    v.Boolean = true;
    Controls.Inputs[LastSelected].Boolean = false
  end;
end;

-- Assign all Output buttons to fire a matrix tie command
for k,v in ipairs(Controls.Outputs) do
  v.EventHandler = function()
    if v.Boolean == false then
      return;
    end;
    print("Creating a tie: "..CurrentInputSelection.."*"..k.." "..TieTypeList.String);
    Timer.CallAfter(function() v.Boolean = false end, 1);
    TiesPendingApproval[CurrentInputSelection .. "," .. k] = false;
    MatrixButtons[CurrentInputSelection .. "," .. k].Color = MatrixTiePendingColor;
    Timer.CallAfter(TieVerificationCallback(CurrentInputSelection..","..k), tonumber(TieVerificationCallbackTime.String));
    CreateTie(CurrentInputSelection, k, TieTypeList.String);
  end;
end;

Column = 0;
Row = 1;
-- Assign Matrix Button names
for k,v in ipairs(Controls.Matrix) do
  Column = Column + 1;
  if Column > 8 then
    Row = Row + 1;
    Column = 1;
  end;
  local TieInput = Column;
  local TieOutput = Row;
  v.EventHandler = function()
    if v.Boolean == false then
      return;
    end;
    TiesPendingApproval[TieInput..","..TieOutput] = false;
    v.Color = MatrixTiePendingColor;
    Timer.CallAfter(function() TieVerificationCallback(TieInput..","..TieOutput) end, tonumber(TieVerificationCallbackTime.String));
    CreateTie(TieInput, TieOutput, TieTypeList.String)
  end;
  v.Legend = tostring(Column) .. "," .. tostring(Row);
  MatrixButtons[v.Legend] = v;
end;

-- Check if a String starts with a String
function startsWith(String, Start)
  return string.sub(String,1,string.len(Start)) == Start;
end;

-- Initialize Connection
function InitSocket()
  print("Connecting to " .. IP .. ":" .. Port);
  Socket:Connect(IP, tonumber(Port));
end;

-- Kill Socket Connection
function KillSocket()
  Socket:Disconnect();
end;
------------------------------------------------------------------
-- Evaluate returned information
function ParseReturn(sock, evt, err)
  DebugPrint("Function fired")
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

function ParseData(ReturnLine)
    DebugPrint("Data reception")
    DebugPrint(ReturnLine);
    if (startsWith(ReturnLine, "(c)"))then
      print("Copyright");
      print(tostring(Socket:ReadLine(TcpSocket.EOL.Any)));
      Socket:Write("\r\n");
    elseif startsWith(ReturnLine, "Password") then
      print(Pass);
      Socket:Write(tostring(Pass).."\r\n");
      Socket:Write("\x1B3CV\r");
      Socket:Write("0LS");
    elseif startsWith(ReturnLine, "E") then
      if ReturnLine == "E13" then
        return;
      end;
      ParseErr(ReturnLine);
      return;
    elseif startsWith(ReturnLine, "Frq00") then
      ParsePrescence(ReturnLine);
      return;
    elseif startsWith(ReturnLine, "Out") then
      Output = tonumber(string.sub(ReturnLine, 4, 4));
      Input  = tonumber(string.sub(ReturnLine, 8, 8));
      TieType= string.sub(ReturnLine, 10, 12);
      if Input == 0 then
        local i = 0;
        while i < 8 do
          i = i + 1;
          MatrixButtons[i..","..Output].Boolean = false;
          MatrixButtons[i..","..Output].Color = MatrixUntiedColor;
          return;
        end;
      end;
      local i = 0;
      while i < 8 do
        i = i + 1;
        if i ~= Input then
          MatrixButtons[i..","..Output].Boolean = false;
          MatrixButtons[i..","..Output].Color = MatrixUntiedColor;
        end;
      end;
      TiesPendingApproval[Input..","..Output] = true;
      MatrixButtons[Input..","..Output].Boolean = true;
      MatrixButtons[Input..","..Output].Color = MatrixTiedColor;
    end;
end;
---------------------------------------------------------------------

function ParsePrescence(pres)
  PrescenceString = string.sub(pres, 7, string.len(pres));
  DebugPrint(PrescenceString);
  NumInputs = string.len(PrescenceString);
  n = 0;
  while n < NumInputs do
    n = n + 1;
    InputPrescence = string.sub(PrescenceString, n, n);
    if InputPrescence == "1" then
      DebugPrint("Signal Present on input " .. tostring(n));
      Controls["Signal Presence"][n].Boolean = true;
    elseif InputPrescence == "0" then
      Controls["Signal Presence"][n].Boolean = false;
    end;
  end;
end;

function ParseErr(err)
  ErrString = "Received: ";
  if err == "E01" then
    ErrString = ErrString .. "Invalid input number";
  elseif err == "E10" then
    ErrString = ErrString .. "Invalid command";
  elseif err == "E11" then
    ErrString = ErrString .. "Invalid preset number";
  elseif err == "E12" then
    ErrString = ErrString .. "Invalid output number";
  elseif err == "E13" then
    ErrString = ErrString .. "Invalid parameter";
  elseif err == "E14" then
    ErrString = ErrString .. "Not valid for this configuration";
  elseif err == "E17" then
    ErrString = ErrString .. "Invalid command for signal type";
  elseif err == "E18" then
    ErrString = ErrString .. "System or command timeout";
  elseif err == "E21" then
    ErrString = ErrString .. "Invalid room number";
  elseif err == "E22" then
    ErrString = ErrString .. "Busy";
  elseif err == "E24" then
    ErrString = ErrString .. "Privilege Violation";
  elseif err == "E25" then
    ErrString = ErrString .. "Device not present";
  elseif err == "E26" then
    ErrString = ErrString .. "Maximum connections exceeded";
  elseif err == "E27" then
    ErrString = ErrString .. "Invalid event number";
  elseif err == "E28" then
    ErrString = ErrString .. "Bad filename, file not found"
  end;
  print(ErrString);
  StatusFeedback.String = ErrString;
  StatusFeedback.Color = "#FF0000";
end;
-- Create a basic A/V Tie
function CreateTie(Input, Output, Type)
  Command = Input .. "*" .. Output;
  if Type == "Video" then
    Command = Command .. "%";
  elseif Type == "Audio" then
    Command = Command .. "$";
  elseif Type == "All" then
    Command = Command .. "!";
  end;
  print(Command);
  Socket:Write(Command);
end;

function SocketConnection()
  ConnectionStatus.Boolean = true;
  print("Socket Connected");
  StatusFeedback.String = "Connected";
  StatusFeedback.Color = "#008000";
  Timer.CallAfter(function() PollingTimer:Start(1.5)end, 2);
end;

function SocketDisconnection()
  ConnectionStatus.Boolean = false;
  print("Socket Disconnected");
  StatusFeedback.String = "Closed";
  StatusFeedback.Color = "#FF0000";
end;

function Poll()
  Socket:Write("0LS");
end;

TieVerificationCallbackTime.EventHandler = function()
  if tonumber(TieVerificationCallbackTime.String) == nil then
    TieVerificationCallbackTime.String = "5";
  end;
end;

function Reconnect()
  Socket:Disconnect();
  IP = Controls.IP.String;
  Port = Controls.Port.String;
  Pass = Controls.Password.String;
  print("Socket disconnected for reconnection");
  InitSocket();
end;

Controls.IP.EventHandler = Reconnect;
Controls.Port.EventHandler = Reconnect;
Controls.Password.EventHandler = Reconnect;

PollingTimer.EventHandler = Poll;
Socket.EventHandler = ParseReturn;
InitSocket();

# DNetLog
UDP logs for Delphi

![Server screenshot](/Img/server_screenshot.png?raw=true "Server screenshot")

## Build server application
1. Install **VirtualTree for VCL** from GetIt Package Manager or from [https://github.com/Virtual-TreeView/Virtual-TreeView](https://github.com/Virtual-TreeView/Virtual-TreeView)
2. Open DNetLog_Project.groupproj and build **LogServerWin** project (VCL).

![Warning!](/Img/warning_24px.png?raw=true "Warning!") **Filter** is case insensitive for **Message** column and case sensitive for **Data** column.

## Log data from your application
Sample log application is attached to project.

1. Add **DNetLog** folder to system or project search path. 
2. Add files "DNLog.Types" and "DNLog.client" to uses list.
3. Log data, using functions:

```
_Log.LogDebug(LogMessage: string);
_Log.LogDebug(LogTypeNr: ShortInt; LogMessage: string);
_Log.LogDebug(LogTypeNr: ShortInt; LogMessage: string; LogData: TBytes);

_Log.LogInfo(LogMessage: string);
_Log.LogInfo(LogTypeNr: ShortInt; LogMessage: string);
_Log.LogInfo(LogTypeNr: ShortInt; LogMessage: string; LogData: TBytes);

_Log.LogWarning(LogMessage: string);
_Log.LogWarning(LogTypeNr: ShortInt; LogMessage: string);
_Log.LogWarning(LogTypeNr: ShortInt; LogMessage: string; LogData: TBytes);

_Log.LogError(LogMessage: string);
_Log.LogError(LogTypeNr: ShortInt; LogMessage: string);
_Log.LogError(LogTypeNr: ShortInt; LogMessage: string; LogData: TBytes);

// example:

_Log.LogDebug('Some debug text');
_Log.LogDebug(0, 'Some debug text');
_Log.LogDebug(0, 'Some debug text', DataTBytes);

_Log.LogInfo('Some info text');
_Log.LogInfo(0, 'Some info text');
_Log.LogInfo(0, 'Some info text', DataTBytes);

_Log.LogWarning('Some warning text');
_Log.LogWarning(0, 'Some warning text');
_Log.LogWarning(0, 'Some warning text', DataTBytes);

_Log.LogError('Some error text');
_Log.LogError(0, 'Some error text');
_Log.LogError(0, 'Some error text', DataTBytes);
```

Number 0 from above examples, is used for group logs data only and can be any of two bytes integer numbers (ShortInt).

If there is no open UDP port on selected IP address, client will try to connect with log server only once. All next logs will be ignored, so make sure log server is already started before start log client.

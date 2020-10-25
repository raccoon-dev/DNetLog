# DNetLog
TCP/UDP logs for Delphi

![Server screenshot](/Img/server_screenshot.png?raw=true "Server screenshot")

## Compiled log server
Compiled log server:
[https://github.com/raccoon-dev/DNetLog/releases](https://github.com/raccoon-dev/DNetLog/releases)

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
_Log.d(LogMessage: string);
_Log.d(LogTypeNr: ShortInt; LogMessage: string);
_Log.d(LogTypeNr: ShortInt; LogMessage: string; LogData: TBytes);

_Log.i(LogMessage: string);
_Log.i(LogTypeNr: ShortInt; LogMessage: string);
_Log.i(LogTypeNr: ShortInt; LogMessage: string; LogData: TBytes);

_Log.w(LogMessage: string);
_Log.w(LogTypeNr: ShortInt; LogMessage: string);
_Log.w(LogTypeNr: ShortInt; LogMessage: string; LogData: TBytes);

_Log.e(LogMessage: string);
_Log.e(LogTypeNr: ShortInt; LogMessage: string);
_Log.e(LogTypeNr: ShortInt; LogMessage: string; LogData: TBytes);

// example:

_Log.d('Some debug text');
_Log.d(0, 'Some debug text');
_Log.d(0, 'Some debug text', DataTBytes);

_Log.i('Some info text');
_Log.i(0, 'Some info text');
_Log.i(0, 'Some info text', DataTBytes);

_Log.w('Some warning text');
_Log.w(0, 'Some warning text');
_Log.w(0, 'Some warning text', DataTBytes);

_Log.e('Some error text');
_Log.e(0, 'Some error text');
_Log.e(0, 'Some error text', DataTBytes);
```

Number 0 from above examples, is used for group logs data only and can be any of two bytes integer numbers (ShortInt).

Log Client requires defined "LOGS" to send logs. Without that conditional define, client will send nothing and only cost for application will be enter to procedure and leave procedure.

TCP client is set by default. You can change that to UDP by comment define BY_DEFAULT_USE_TCP on top of DNLog.Client unit.

You can disable auto create log client on first use by comment define AUTO_CREATE_CLIENT on top of DNLog.Client unit.

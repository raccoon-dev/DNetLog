# DNetLog
TCP/UDP logs for Delphi to help debug mobile applications.

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

1. Add **DNetLog** folder to the system or project search path or copy DNLog.Client.pas, DNLog.Types.pas and DNLog.Sender.pas files to your project.
2. Add unit "DNLog.Client" to the uses list.
3. Log data, using functions:

```
_Log.d(LogMessage: string);
_Log.d(LogMessage: string; LogData: TBytes);
_Log.d(LogTypeNr: ShortInt; LogMessage: string);
_Log.d(LogTypeNr: ShortInt; LogMessage: string; LogData: TBytes);

_Log.i(LogMessage: string);
_Log.i(LogMessage: string; LogData: TBytes);
_Log.i(LogTypeNr: ShortInt; LogMessage: string);
_Log.i(LogTypeNr: ShortInt; LogMessage: string; LogData: TBytes);

_Log.w(LogMessage: string);
_Log.w(LogMessage: string; LogData: TBytes);
_Log.w(LogTypeNr: ShortInt; LogMessage: string);
_Log.w(LogTypeNr: ShortInt; LogMessage: string; LogData: TBytes);

_Log.e(LogMessage: string);
_Log.e(LogMessage: string; LogData: TBytes);
_Log.e(LogTypeNr: ShortInt; LogMessage: string);
_Log.e(LogTypeNr: ShortInt; LogMessage: string; LogData: TBytes);

_Log.x(LogMessage: string);
_Log.x(LogMessage: string; LogData: TBytes);
_Log.x(LogTypeNr: ShortInt; LogMessage: string);
_Log.x(LogTypeNr: ShortInt; LogMessage: string; LogData: TBytes);

// example:

_Log.d('Some debug text');
_Log.d('Some debug text', DataTBytes);
_Log.d(0, 'Some debug text');
_Log.d(0, 'Some debug text', DataTBytes);

_Log.i('Some info text');
_Log.i('Some info text', DataTBytes);
_Log.i(0, 'Some info text');
_Log.i(0, 'Some info text', DataTBytes);

_Log.w('Some warning text');
_Log.w('Some warning text', DataTBytes);
_Log.w(0, 'Some warning text');
_Log.w(0, 'Some warning text', DataTBytes);

_Log.e('Some error text');
_Log.e('Some error text', DataTBytes);
_Log.e(0, 'Some error text');
_Log.e(0, 'Some error text', DataTBytes);

_Log.x('Some exception text');
_Log.x('Some exception text', DataTBytes);
_Log.x(0, 'Some exception text');
_Log.x(0, 'Some exception text', DataTBytes);
```

Number 0 from above examples, is used for group logs data only and can be any of two bytes integer numbers (ShortInt).

Log Client requires defined "LOGS" to send logs.
By default, it's declared in the client unit, but you can comment or remove this declaration and declare it in your project by yourself.
Without this conditional define, logs are completely invisible for your application, so you don't have to surround log commands with any defines to remove it.
For example, instead of write this code:
```
{$IF defined(DEBUG)}
_Log.i('Some informational text');
{$ENDIF}
```
you can just write:
```
_Log.i('Some informational text');
```
and there will be no cost for your application at all when LOGS isn't defined. This code will be simply removed from your application during compilation.

Using `if _Log.Active the` as it is in the example application is not necessary.

TCP client is set by default. You can change it to UDP by uncomment define USE_UDP on the top of the DNLog.Client unit.

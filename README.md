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
// Debug messages
_Log.d(LogMessage: string);
_Log.d(LogMessage: string; Args: array of const);
_Log.d(LogMessage: string; LogData: TBytes);
_Log.d(LogTypeNr: ShortInt; LogMessage: string);
_Log.d(LogTypeNr: ShortInt; LogMessage: string; LogData: TBytes);

// Informational messages
_Log.i(LogMessage: string);
_Log.i(LogMessage: string; Args: array of const);
_Log.i(LogMessage: string; LogData: TBytes);
_Log.i(LogTypeNr: ShortInt; LogMessage: string);
_Log.i(LogTypeNr: ShortInt; LogMessage: string; LogData: TBytes);

// Warning messages
_Log.w(LogMessage: string);
_Log.w(LogMessage: string; Args: array of const);
_Log.w(LogMessage: string; Args: array of const);
_Log.w(LogMessage: string; LogData: TBytes);
_Log.w(LogTypeNr: ShortInt; LogMessage: string);
_Log.w(LogTypeNr: ShortInt; LogMessage: string; LogData: TBytes);

// Error messages
_Log.e(LogMessage: string);
_Log.e(LogMessage: string; Args: array of const);
_Log.e(LogMessage: string; LogData: TBytes);
_Log.e(LogTypeNr: ShortInt; LogMessage: string);
_Log.e(LogTypeNr: ShortInt; LogMessage: string; LogData: TBytes);

// eXception messages
_Log.x(LogMessage: string);
_Log.x(LogMessage: string; Args: array of const);
_Log.x(LogMessage: string; LogData: TBytes);
_Log.x(LogTypeNr: ShortInt; LogMessage: string);
_Log.x(LogTypeNr: ShortInt; LogMessage: string; LogData: TBytes);

// example:

_Log.d('Some debug text');
_Log.d('Some debug text with %s', ['parameter']);
_Log.d('Some debug text', DataTBytes);
_Log.d(0, 'Some debug text');
_Log.d(0, 'Some debug text', DataTBytes);

_Log.i('Some info text');
_Log.i('Some info text with %s', ['parameter']);
_Log.i('Some info text', DataTBytes);
_Log.i(0, 'Some info text');
_Log.i(0, 'Some info text', DataTBytes);

_Log.w('Some warning text');
_Log.w('Some warning text with %s', ['parameter']);
_Log.w('Some warning text', DataTBytes);
_Log.w(0, 'Some warning text');
_Log.w(0, 'Some warning text', DataTBytes);

_Log.e('Some error text');
_Log.e('Some error text with %s', ['parameter']);
_Log.e('Some error text', DataTBytes);
_Log.e(0, 'Some error text');
_Log.e(0, 'Some error text', DataTBytes);

_Log.x('Some exception text');
_Log.x('Some exception text with %s', ['parameter']);
_Log.x('Some exception text', DataTBytes);
_Log.x(0, 'Some exception text');
_Log.x(0, 'Some exception text', DataTBytes);
```

Number 0 from above examples, is used for group logs data only and can be any of two bytes integer numbers (ShortInt).

Log Client requires defined "USE\_DNLOGS" to send logs.

> **Warning! Previously it was "LOGS" instead of "USE\_DNLOGS".**

Define "USE\_DNLOGS" (previously "LOGS" define) is no longer defined in the client unit so must me manually declared in the project settings.
Without this conditional define, logs are completely invisible for your application, so you don't have to surround log commands with any defines to remove it.
> Warning! this does not apply to the functions:
> ```
> procedure d(const LogMessage: string; const Args: array of const); overload;
> procedure i(const LogMessage: string; const Args: array of const); overload;
> procedure w(const LogMessage: string; const Args: array of const); overload;
> procedure e(const LogMessage: string; const Args: array of const); overload;
> procedure x(const LogMessage: string; const Args: array of const); overload;
> ```
> because these functions can't be marked as inline.

For example, instead of write this code:
```
{$IF defined(DEBUG) AND defined(USE_DNLOGS)}
_Log.i('Some informational text');
{$ENDIF}
```
you can just write:
```
_Log.i('Some informational text');
```
and there will be no cost for your application at all when USE\_DNLOGS isn't defined. This code will be simply removed from your application during compilation.

TCP client is set by default. You can change it to UDP by uncomment define USE\_UDP on the top of the DNLog.Client unit.

---

### All ideas on how to improve this tool are welcome.

---


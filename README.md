# DNetLog
UDP logs for Delphi

![Server screenshot](/Img/server_screenshot.png?raw=true "Server screenshot")

## Build server application
1. Install **VirtualTree for VCL** from GetIt Package Manager or from [https://github.com/Virtual-TreeView/Virtual-TreeView](https://github.com/Virtual-TreeView/Virtual-TreeView)
2. Open DNetLog_Project.groupproj and build **LogServerWin** project.

## Log data from your application
Sample log application is attached to project.

1. Add **DNetLog** folder to system or project search path. 
2. Add files "DNLog.Types" and "DNLog.client" to uses list.
3. Log data, using:

```
_Log.LogDebug('Some text');
_Log.LogDebug(0, 'Some text');
_Log.LogDebug(0, 'Some text', DataTBytes);

_Log.LogInfo('Some text');
_Log.LogInfo(0, 'Some text');
_Log.LogInfo(0, 'Some text', DataTBytes);

_Log.LogWarning('Some text');
_Log.LogWarning(0, 'Some text');
_Log.LogWarning(0, 'Some text', DataTBytes);

_Log.LogError('Some text');
_Log.LogError(0, 'Some text');
_Log.LogError(0, 'Some text', DataTBytes);
```

Number 0 from above example, is used for group logs data and can be any of two bytes integer numbers (ShortInt).

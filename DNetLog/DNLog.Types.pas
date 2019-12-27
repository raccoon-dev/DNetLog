unit DNLog.Types;

interface

uses
  System.SysUtils;

const
  SERVER_ADDRESS = '127.0.0.1';
//  SERVER_BIND_ADDRESS_4 = '127.0.0.1';
  SERVER_BIND_ADDRESS_4 = '0.0.0.0';
//  SERVER_BIND_ADDRESS_6 = '::1';
  SERVER_BIND_ADDRESS_6 = '::';
  SERVER_BIND_PORT = 9999;
  SERVER_BUFFER_SIZE = 20; // [MB]

type TDNLogPriority = (prDebug, prInfo, prWarning, prError);

type TDNLogMessage = record
  LogPriority: TDNLogPriority;
  LogTimestamp: Cardinal;
  LogTypeNr: ShortInt;
  LogMessage: string;
  LogData: TBytes;
end;

implementation

end.

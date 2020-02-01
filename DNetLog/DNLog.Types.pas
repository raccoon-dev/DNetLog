unit DNLog.Types;

interface

uses
  System.SysUtils;

const
  SERVER_ADDRESS = '127.0.0.1'; // Client will connect to this address
//  SERVER_BIND_ADDRESS_4 = '127.0.0.1'; // IPv4 localhost
  SERVER_BIND_ADDRESS_4 = '0.0.0.0'; // IPv4 all
//  SERVER_BIND_ADDRESS_6 = '::1'; // IPv6 localhost
  SERVER_BIND_ADDRESS_6 = '::'; // IPv6 all
  SERVER_BIND_PORT = 9999;
  SERVER_BUFFER_SIZE = 20; // [MB] // We need this, because it's UDP (more = better).

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

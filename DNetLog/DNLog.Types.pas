unit DNLog.Types;

interface

uses
  System.SysUtils;

// Server constants
const
  SERVER_BIND_ADDRESS_4 = '0.0.0.0'; // '0.0.0.0' = IPv4 all; '127.0.0.1' = IPv4 localhost
  SERVER_BIND_ADDRESS_6 = '::';      // '::' = IPv6 all; '::1' = IPv6 localhost
  SERVER_BIND_PORT = 9999;

// Client constants
const
  SERVER_ADDRESS = '127.0.0.1'; // Client will connect to this address
  SERVER_PORT = SERVER_BIND_PORT;

type TDNLogPriority = (prDebug, prInfo, prWarning, prError, prException);

type TDNLogMessage = record
  LogPriority: TDNLogPriority;
  LogTimestamp: Cardinal;
  LogTypeNr: ShortInt;
  LogMessage: string;
  LogData: TBytes;
end;

implementation

end.

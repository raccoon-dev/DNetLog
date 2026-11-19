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

// Packet structure constants
const
  PACKET_SIZE_PRIORITY  = 1;
  PACKET_SIZE_TIMESTAMP = 4;
  PACKET_SIZE_TYPENR    = 1;
  PACKET_SIZE_MSGLEN    = 2;
  PACKET_SIZE_DATALEN   = 2;

  PACKET_OFFSET_PRIORITY  = 0;
  PACKET_OFFSET_TIMESTAMP = PACKET_OFFSET_PRIORITY + PACKET_SIZE_PRIORITY;   // 1
  PACKET_OFFSET_TYPENR    = PACKET_OFFSET_TIMESTAMP + PACKET_SIZE_TIMESTAMP; // 5
  PACKET_OFFSET_MSGLEN    = PACKET_OFFSET_TYPENR + PACKET_SIZE_TYPENR;       // 6
  PACKET_OFFSET_MESSAGE   = PACKET_OFFSET_MSGLEN + PACKET_SIZE_MSGLEN;       // 8

  PACKET_HEADER_SIZE = PACKET_SIZE_PRIORITY +
                       PACKET_SIZE_TIMESTAMP +
                       PACKET_SIZE_TYPENR +
                       PACKET_SIZE_MSGLEN +
                       PACKET_SIZE_DATALEN;  // 10

type TDNLogPriority = (prDebug, prInfo, prWarning, prError, prException);

type TDNLogMessage = record
  // Fields transmitted over the network
  LogPriority: TDNLogPriority;
  LogTimestamp: Cardinal;
  LogTypeNr: ShortInt;
  LogMessage: string;
  LogData: TBytes;
  // Server-side only - assigned by TDNLogServer on receipt, never sent over the network
  LogId: Int64;             // Unique, strictly increasing within one server run (starts at 1)
  LogReceivedAt: TDateTime; // Server local time when the message was received
end;

implementation

end.

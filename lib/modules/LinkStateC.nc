#include <Timer.h>
#include "../../includes/channels.h"
#include "../../includes/packet.h"
#include "../../includes/protocol.h"
#include "../../includes/CommandMsg.h"
#include "../../includes/command.h"

#define LS_MAX_ROUTES 256
#define LS_MAX_COST 17
#define LS_TTL 17
#define AM_LinkState 62
#define AM_NEIGHBOR 0x93

configuration LinkStateC {
  provides interface LinkState;
  uses interface List<pack> as neighborListC;
  uses interface List<lspLink> as lspLinkC;
  uses interface Debug as General;
}

implementation {
  components LinkStateP;
  components new TimerMilliC() as lsrTimer;
  components new TimerMilliC() as dijkstra;
  components new SimpleSendC(AM_NEIGHBOR);
  components new AMReceiverC(AM_NEIGHBOR);
  components new HashmapC(int, 64) as routingTable; // Key is 'int', 64 entries max

  LinkStateP.lsrTimer -> lsrTimer;
  LinkStateP.dijkstraTimer -> dijkstra;
  LinkStateP.neighborList = neighborListC;
  LinkStateP.lspLinkList = lspLinkC;
  LinkStateP.routingTable = routingTable;

  components RandomC as Random;
  LinkStateP.Random -> Random;

  LinkStateP.LSPSender -> FloodingC.LSPSender;

  LinkState = LinkStateP.LinkState;
  LinkStateP.General -> General;  // Wire Debug interface for printing
}

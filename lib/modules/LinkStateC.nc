#include <Timer.h>
#include "../../includes/channels.h"
#include "../../includes/packet.h"
#include "../../includes/protocol.h"
#include "../../includes/CommandMsg.h"
#include "../../includes/command.h"

#define LS_MAX_ROUTES 256
#define LS_MAX_COST 17
#define LS_TTL 17
// Configuration
#define AM_LinkState 62

configuration LinkStateC{
  provides interface LinkState;
  uses interface List<pack> as neighborListC;
  uses interface List<lspLink> as lspLinkC;
  uses interface Hashmap<int> as HashmapC;
}

implementation{
  components LinkStateP;
  //components new TimerMilliC() as neigbordiscoveryTimer;
  components new SimpleSendC(AM_NEIGHBOR);
  components new AMReceiverC(AM_NEIGHBOR);

  components new TimerMilliC() as lsrTimer;
  LinkStateP.lsrTimer -> lsrTimer;

  components new TimerMilliC() as dijkstra;
  LinkStateP.dijkstraTimer -> dijkstra;

  LinkStateP.neighborList = neighborListC;

  components RandomC as Random;
  LinkStateP.Random -> Random;

  // External Wiring
  LinkState = LinkStateP.LinkState;

  /*components new HashmapC(int, 300) as HashmapC;
  LinkStateP.routingTable -> HashmapC;*/

  LinkStateP.lspLinkList = lspLinkC;
  LinkStateP.routingTable = HashmapC;

  components FloodingC;
  LinkStateP.LSPSender -> FloodingC.LSPSender;
}
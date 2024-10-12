#include <Timer.h>
#include "includes/command.h"
#include "includes/packet.h"
#include "includes/CommandMsg.h"
#include "includes/sendInfo.h"
#include "includes/channels.h"
#include <string.h>

configuration NodeC{
}

implementation {
  components MainC;
  components Node;
  components new AMReceiverC(AM_PACK) as GeneralReceive;
  components new ListC(pack, 64) as neighborListC;
  components new ListC(lspLink, 64) as lspLinkC;
  components new HashmapC(int, 300) as HashmapC;

  Node -> MainC.Boot;
  Node.Receive -> GeneralReceive;

  components ActiveMessageC;
  Node.AMControl -> ActiveMessageC;

  components new SimpleSendC(AM_PACK);
  Node.Sender -> SimpleSendC;

  components NeighborDiscoveryC;
  Node.NeighborDiscovery -> NeighborDiscoveryC;
  NeighborDiscoveryC.neighborListC -> neighborListC;
  LinkStateC.lspLinkC -> lspLinkC;

  components CommandHandlerC;
  Node.CommandHandler -> CommandHandlerC;

  components FloodingC;
  Node.FloodSender -> FloodingC.FloodSender;
  Node.RouteSender -> FloodingC.RouteSender;
  //FloodingC.lspLinkC -> lspLinkC;
  FloodingC.HashmapC -> HashmapC;

  components LinkStateC;
  Node.LinkState -> LinkStateC;
  Node.routingTable -> HashmapC;
  LinkStateC.neighborListC -> neighborListC;
  LinkStateC.HashmapC -> HashmapC;
  FloodingC.lspLinkC -> lspLinkC;

  // Invoke the routing table print method
  LinkStateC.LinkState.printRoutingTable();
}

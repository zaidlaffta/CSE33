#include <Timer.h>
#include "../../includes/channels.h"
#include "../../includes/packet.h"
#include "../../includes/protocol.h"
#include "../../includes/CommandMsg.h"
#include "../../includes/command.h"

#define LS_MAX_ROUTES 256
#define LS_MAX_COST 17
#define LS_TTL 17

configuration LinkStateRoutingC {
    provides interface LinkStateRouting;
}

implementation {
    components LinkStateRoutingP;
    LinkStateRouting = LinkStateRoutingP;

    components new SimpleSendC(AM_PACK);
    LinkStateRoutingP.Sender -> SimpleSendC;

    components new HashmapC(LS_MAX_ROUTES) as PacketsReceivedMap;
    LinkStateRoutingP.PacketsReceived -> PacketsReceivedMap;

    components NeighborDiscoveryC;
    LinkStateRoutingP.NeighborDiscovery -> NeighborDiscoveryC;    

    components FloodingC;
    LinkStateRoutingP.Flooding -> FloodingC;

    components new TimerMilliC() as LSRTimer;   
    LinkStateRoutingP.LSRTimer -> LSRTimer;

    components RandomC as Random;               
    LinkStateRoutingP.Random -> Random;
    
}
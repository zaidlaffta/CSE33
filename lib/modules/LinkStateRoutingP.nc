#include <Timer.h>
#include "../../includes/channels.h"
#include "../../includes/packet.h"
#include "../../includes/protocol.h"
#include "../../includes/CommandMsg.h"
#include "../../includes/command.h"

#define LS_MAX_ROUTES 256
#define LS_MAX_COST 17
#define LS_TTL 17

module LinkStateRoutingP {
    provides interface LinkStateRouting;
    
    uses interface SimpleSend as Sender;
    uses interface Hashmap<uint16_t> as PacketsReceived;
    uses interface NeighborDiscovery as NeighborDiscovery;
    uses interface Flooding as Flooding;
    uses interface Timer<TMilli> as LSRTimer;                       
    uses interface Random as Random;                                
}

implementation {

    typedef struct {
        uint8_t nextHop;
        uint8_t cost;
    } Route;

    typedef struct {
        uint32_t neighbor;
        uint8_t cost;
    } LSP;

    uint8_t linkState[LS_MAX_ROUTES][LS_MAX_ROUTES];
    Route routingTable[LS_MAX_ROUTES];
    uint16_t numKnownNodes = 0;
    uint16_t numRoutes = 0;
    uint16_t sequenceNum = 0;
    pack routePack;

    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, void* payload, uint8_t length);
    void initilizeRoutingTable();
    bool updateState(pack* myMsg);
    bool updateRoute(uint8_t dest, uint8_t nextHop, uint8_t cost);
    void addRoute(uint8_t dest, uint8_t nextHop, uint8_t cost);
    void removeRoute(uint8_t dest);
    void sendLSP(uint8_t lostNeighbor);
    void handleForward(pack* myMsg);
    void djikstra();

    command error_t LinkStateRouting.start() {
        dbg(GENERAL_CHANNEL, "Link State Routing Started on node %u!\n", TOS_NODE_ID);
        initilizeRoutingTable();
        call LSRTimer.startPeriodic(30000);
        return SUCCESS;
    }

    event void LSRTimer.fired() {
        dbg(GENERAL_CHANNEL, "Sending flooding packet with neighbor list\n");
        sendLSP(0);
    }

    command void LinkStateRouting.ping(uint16_t destination, uint8_t *payload) {
        makePack(&routePack, TOS_NODE_ID, destination, 0, PROTOCOL_PING, 0, payload, PACKET_MAX_PAYLOAD_SIZE);
        dbg(GENERAL_CHANNEL, "PING FROM %d TO %d\n", TOS_NODE_ID, destination);
        call LinkStateRouting.routePacket(&routePack);
    }    

    command void LinkStateRouting.routePacket(pack* myMsg) {
        uint8_t nextHop;
        if (myMsg->dest == TOS_NODE_ID && myMsg->protocol == PROTOCOL_PING) {
            dbg(GENERAL_CHANNEL, "PING Packet has reached destination %d!!!\n", TOS_NODE_ID);
            makePack(&routePack, myMsg->dest, myMsg->src, 0, PROTOCOL_PINGREPLY, 0, (uint8_t *)myMsg->payload, PACKET_MAX_PAYLOAD_SIZE);
            call LinkStateRouting.routePacket(&routePack);
            return;
        } else if (myMsg->dest == TOS_NODE_ID && myMsg->protocol == PROTOCOL_PINGREPLY) {
            dbg(GENERAL_CHANNEL, "PING_REPLY Packet has reached destination %d!!!\n", TOS_NODE_ID);
            return;
        }
        if (routingTable[myMsg->dest].cost < LS_MAX_COST) {
            nextHop = routingTable[myMsg->dest].nextHop;
            dbg(GENERAL_CHANNEL, "Node %d routing packet through %d\n", TOS_NODE_ID, nextHop);
            if (call Sender.send(*myMsg, nextHop) != SUCCESS) {
                dbg(GENERAL_CHANNEL, "Failed to send packet.\n");
            }
        } else {
            dbg(GENERAL_CHANNEL, "No route to destination. Dropping packet...\n");
        }
    }

    command void LinkStateRouting.handleLS(pack* myMsg) {
        uint16_t seq;
        bool exists = call PacketsReceived.contains(myMsg->src);

        if (exists) {
            seq = call PacketsReceived.get(myMsg->src);
            if (seq == myMsg->seq) {
                // Packet has already been processed
                return;
            }
        }

        call PacketsReceived.insert(myMsg->src, myMsg->seq);

        if (updateState(myMsg)) {
            djikstra();
        }

        call Sender.send(*myMsg, AM_BROADCAST_ADDR);
    }

    command void LinkStateRouting.handleNeighborLost(uint16_t lostNeighbor) {
        dbg(GENERAL_CHANNEL, "Neighbor lost %u\n", lostNeighbor);
        if (linkState[TOS_NODE_ID][lostNeighbor] != LS_MAX_COST) {
            linkState[TOS_NODE_ID][lostNeighbor] = LS_MAX_COST;
            linkState[lostNeighbor][TOS_NODE_ID] = LS_MAX_COST;
            numKnownNodes--;
            removeRoute(lostNeighbor);
        }
        sendLSP(lostNeighbor);
        djikstra();
    }

    command void LinkStateRouting.handleNeighborFound() {
        uint32_t* neighbors = call NeighborDiscovery.fetchNeighbors();
        uint16_t neighborsListSize = call NeighborDiscovery.fetchNeighborCount();
        uint16_t i = 0;
        for (i = 0; i < neighborsListSize; i++) {
            linkState[TOS_NODE_ID][neighbors[i]] = 1;
            linkState[neighbors[i]][TOS_NODE_ID] = 1;
        }
        sendLSP(0);
        djikstra();
    }

    command void LinkStateRouting.printRouteTable() {
        uint16_t i;
        dbg(GENERAL_CHANNEL, "DEST  HOP  COST\n");
        for (i = 1; i < LS_MAX_ROUTES; i++) {
            if (routingTable[i].cost != LS_MAX_COST) {
                dbg(GENERAL_CHANNEL, "%4d%5d%6d\n", i, routingTable[i].nextHop, routingTable[i].cost);
            }
        }
    }

    void initilizeRoutingTable() {
        uint16_t i, j;
        for (i = 0; i < LS_MAX_ROUTES; i++) {
            for (j = 0; j < LS_MAX_ROUTES; j++) {
                linkState[i][j] = (i == j) ? 0 : LS_MAX_COST;
            }
            routingTable[i].nextHop = 0;
            routingTable[i].cost = LS_MAX_COST;
        }
        routingTable[TOS_NODE_ID].nextHop = TOS_NODE_ID;
        routingTable[TOS_NODE_ID].cost = 0;
        numKnownNodes++;
    }

    bool updateState(pack* myMsg) {
        uint16_t i;
        LSP *lsp = (LSP *)myMsg->payload;
        bool isStateUpdated = FALSE;
        for (i = 0; i < 10; i++) {
            if (linkState[myMsg->src][lsp[i].neighbor] != lsp[i].cost) {
                if (linkState[myMsg->src][lsp[i].neighbor] == LS_MAX_COST) {
                    numKnownNodes++;
                } else if (lsp[i].cost == LS_MAX_COST) {
                    numKnownNodes--;
                }
                linkState[myMsg->src][lsp[i].neighbor] = lsp[i].cost;
                linkState[lsp[i].neighbor][myMsg->src] = lsp[i].cost;
                isStateUpdated = TRUE;
            }
        }
        return isStateUpdated;
    }

    void sendLSP(uint8_t lostNeighbor) {
        uint32_t* neighbors = call NeighborDiscovery.fetchNeighbors();
        uint16_t neighborsListSize = call NeighborDiscovery.fetchNeighborCount();
        uint16_t i = 0, counter = 0;

        // Prepare the packet structure and ensure payload allocation
        makePack(&routePack, TOS_NODE_ID, AM_BROADCAST_ADDR, LS_TTL, PROTOCOL_LS, sequenceNum++, NULL, sizeof(LSP) * 10);

        // Ensure the payload pointer is valid
        LSP* lsp = (LSP*)call Packet.getPayload(&routePack, sizeof(LSP) * 10);

        // Iterate through neighbors and fill the LSP array
        for (i = 0; i < neighborsListSize && counter < 10; i++) {
            lsp[counter].neighbor = neighbors[i];
            lsp[counter].cost = (neighbors[i] == lost

#include <Timer.h>
#include "../../includes/channels.h"
#include "../../includes/packet.h"
#include "../../includes/protocol.h"
#include "../../includes/CommandMsg.h"
#include "../../includes/command.h"

#define INFINITY 9999
#define MAXNODES 20

module LinkStateP {
  provides interface LinkState;
  uses interface Timer<TMilli> as lsrTimer;
  uses interface Timer<TMilli> as dijkstraTimer;
  uses interface Debug as General;
  uses interface List<pack> as neighborList;
  uses interface List<lspLink> as lspLinkList;
  uses interface Hashmap<int> as routingTable;
  uses interface Send as LSPSender;
}

implementation {
  int routingTableData[MAXNODES][MAXNODES];
  int nodeID;
  uint16_t sequenceNumber;

  command void LinkState.start() {
    dbg(GENERAL_CHANNEL, "Starting LinkState protocol...\n");

    for (int i = 0; i < MAXNODES; i++) {
      for (int j = 0; j < MAXNODES; j++) {
        routingTableData[i][j] = (i == j) ? 0 : INFINITY;
      }
    }

    nodeID = TOS_NODE_ID;
    dbg(GENERAL_CHANNEL, "Node ID assigned: %d\n", nodeID);
    sequenceNumber = 0;

    call lsrTimer.startPeriodic(1000);   // 1 second LSP broadcast timer
    call dijkstraTimer.startPeriodic(5000);  // 5 seconds Dijkstra timer
  }

  command void LinkState.printRoutingTable() {
    dbg(GENERAL_CHANNEL, "Routing table for node %d:\n", nodeID);
    for (int i = 0; i < MAXNODES; i++) {
      int nextHop;
      if (call routingTable.get(i, &nextHop) == SUCCESS) {
        dbg(GENERAL_CHANNEL, "Destination: %d, Next Hop: %d\n", i, nextHop);
      }
    }
  }

  event void lsrTimer.fired() {
    dbg(GENERAL_CHANNEL, "LSP Timer fired for node %d.\n", nodeID);
    sendLSP();
  }

  event void dijkstraTimer.fired() {
    dbg(GENERAL_CHANNEL, "Dijkstra Timer fired for node %d. Running algorithm...\n", nodeID);
    runDijkstraAlgorithm();
  }

  void sendLSP() {
    static message_t lspMessage;
    packet_t *pkt = (packet_t *) call Packet.getPayload(&lspMessage, sizeof(packet_t));

    if (pkt == NULL) {
      dbg(GENERAL_CHANNEL, "Failed to get packet payload.\n");
      return;
    }

    pkt->protocol = PROTOCOL_LINKSTATE;
    pkt->src = nodeID;
    pkt->dest = AM_BROADCAST_ADDR;
    pkt->ttl = LS_TTL;
    pkt->seq = sequenceNumber++;

    uint8_t numNeighbors = call neighborList.size();
    uint8_t *payload = pkt->payload;

    for (uint8_t i = 0; i < numNeighbors; i++) {
      pack neighbor;
      call neighborList.get(i, &neighbor);
      uint16_t neighborID = neighbor.src;
      memcpy(payload + i * sizeof(uint16_t), &neighborID, sizeof(uint16_t));
    }

    error_t err = call LSPSender.send(AM_BROADCAST_ADDR, &lspMessage, sizeof(packet_t) + numNeighbors * sizeof(uint16_t));
    if (err != SUCCESS) {
      dbg(GENERAL_CHANNEL, "Failed to send LSP from node %d.\n", nodeID);
    } else {
      dbg(GENERAL_CHANNEL, "LSP sent from node %d with sequence number %d.\n", nodeID, sequenceNumber - 1);
    }
  }

  void runDijkstraAlgorithm() {
    // Example: Dijkstra's algorithm to compute shortest paths
    int dist[MAXNODES];
    bool visited[MAXNODES];
    int prev[MAXNODES];

    for (int i = 0; i < MAXNODES; i++) {
      dist[i] = INFINITY;
      visited[i] = FALSE;
      prev[i] = -1;
    }

    dist[nodeID] = 0;

    for (int i = 0; i < MAXNODES; i++) {
      int u = -1;
      int minDist = INFINITY;
      for (int j = 0; j < MAXNODES; j++) {
        if (!visited[j] && dist[j] < minDist) {
          minDist = dist[j];
          u = j;
        }
      }

      if (u == -1) break;

      visited[u] = TRUE;

      for (int v = 0; v < MAXNODES; v++) {
        if (routingTableData[u][v] < INFINITY && !visited[v]) {
          int alt = dist[u] + routingTableData[u][v];
          if (alt < dist[v]) {
            dist[v] = alt;
            prev[v] = u;
          }
        }
      }
    }

    for (int i = 0; i < MAXNODES; i++) {
      if (i != nodeID && dist[i] < INFINITY) {
        int nextHop = i;
        while (prev[nextHop] != nodeID && prev[nextHop] != -1) {
          nextHop = prev[nextHop];
        }
        call routingTable.insert(i, nextHop);
      }
    }

    dbg(GENERAL_CHANNEL, "Dijkstra's algorithm completed for node %d.\n", nodeID);
  }
}

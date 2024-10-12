#include <Timer.h>
#include "../../includes/channels.h"
#include "../../includes/packet.h"
#include "../../includes/protocol.h"
#include "../../includes/CommandMsg.h"
#include "../../includes/command.h"
#include "../../includes/channels.h"
#include "../../includes/packet.h"
#include <stdio.h>

#define INFINITY 9999
#define MAXNODES 20
#define LSP_INTERVAL 1000        // Interval for broadcasting LSPs (in milliseconds)
#define DIJKSTRA_INTERVAL 5000   // Interval for running Dijkstra's algorithm

module LinkStateP {
  // Provides interfaces
  provides interface LinkState;

  // Uses interfaces
  uses interface Timer<TMilli> as lsrTimer;
  uses interface Timer<TMilli> as dijkstraTimer;
  uses interface Debug as General;
  uses interface Random;

  uses interface List<pack> as neighborList;
  uses interface List<lspLink> as lspLinkList;
  uses interface Hashmap<int> as routingTable;

  // Interfaces for sending and receiving messages
  uses interface Send as LSPSender;
  uses interface Receive as LSPReceiver;

  // Internal state variables
  int routingTableData[MAXNODES][MAXNODES];
  int nodeID;
  uint16_t sequenceNumber; // Sequence number for LSPs
}

implementation {
  // Initialization and starting the protocol
  event void Boot.booted() {
    call LinkState.start();
  }

  command void LinkState.start() {
    call General.print("Starting LinkState protocol...\n");
    
    // Initialize the routing table with INFINITY
    for (int i = 0; i < MAXNODES; i++) {
      for (int j = 0; j < MAXNODES; j++) {
        routingTableData[i][j] = (i == j) ? 0 : INFINITY;
      }
    }

    // Assign node ID (assuming TOS_NODE_ID is defined per node)
    nodeID = TOS_NODE_ID;
    call General.print("Node ID assigned: %d\n", nodeID);

    // Initialize sequence number
    sequenceNumber = 0;

    // Start timers
    call lsrTimer.startPeriodic(LSP_INTERVAL);
    call dijkstraTimer.startPeriodic(DIJKSTRA_INTERVAL);
  }

  // Timer fired for broadcasting LSPs
  event void lsrTimer.fired() {
    call General.print("LSP Timer fired for node %d.\n", nodeID);
    sendLSP();
  }

  // Function to send Link-State Packets to neighbors
  void sendLSP() {
    // Create an LSP message
    static message_t lspMessage;
    packet_t *pkt = (packet_t *) call Packet.getPayload(&lspMessage, sizeof(packet_t));

    if (pkt == NULL) {
      call General.print("Failed to get packet payload.\n");
      return;
    }

    // Fill in packet fields
    pkt->protocol = PROTOCOL_LINKSTATE; // Define in protocol.h
    pkt->src = nodeID;
    pkt->dest = AM_BROADCAST_ADDR;      // Broadcast address
    pkt->ttl = MAX_TTL;                 // Define MAX_TTL
    pkt->seq = sequenceNumber++;
    
    // Include neighbor information in the payload
    uint8_t numNeighbors = call neighborList.size();
    uint8_t payloadLength = numNeighbors * sizeof(uint16_t);
    uint8_t *payload = pkt->payload;

    for (uint8_t i = 0; i < numNeighbors; i++) {
      pack neighbor;
      call neighborList.get(i, &neighbor);
      uint16_t neighborID = neighbor.src;
      memcpy(payload + i * sizeof(uint16_t), &neighborID, sizeof(uint16_t));
    }

    // Send the packet
    error_t err = call LSPSender.send(AM_BROADCAST_ADDR, &lspMessage, sizeof(packet_t) + payloadLength);
    if (err != SUCCESS) {
      call General.print("Failed to send LSP from node %d.\n", nodeID);
    } else {
      call General.print("LSP sent from node %d with sequence number %d.\n", nodeID, sequenceNumber - 1);
    }
  }

  // Handle sendDone event for LSPs
  event void LSPSender.sendDone(message_t *msg, error_t error) {
    if (error == SUCCESS) {
      call General.print("LSP send completed successfully from node %d.\n", nodeID);
    } else {
      call General.print("Error in sending LSP from node %d.\n", nodeID);
    }
  }

  // Receive and process incoming LSPs
  event message_t* LSPReceiver.receive(message_t* msg, void* payload, uint8_t len) {
    packet_t *pkt = (packet_t *) payload;

    if (pkt->protocol != PROTOCOL_LINKSTATE) {
      return msg; // Not an LSP
    }

    call General.print("LSP received at node %d from node %d.\n", nodeID, pkt->src);

    // Process LSP and update routing table
    processLSP(pkt, len);

    return msg;
  }

  // Function to process received LSPs
  void processLSP(packet_t *pkt, uint8_t len) {
    uint8_t numNeighbors = (len - sizeof(packet_t)) / sizeof(uint16_t);
    uint8_t *payloadPtr = pkt->payload;

    // Update adjacency matrix
    for (uint8_t i = 0; i < numNeighbors; i++) {
      uint16_t neighborID;
      memcpy(&neighborID, payloadPtr + i * sizeof(uint16_t), sizeof(uint16_t));

      // Update routing table data with cost 1 (assuming symmetric links)
      routingTableData[pkt->src][neighborID] = 1;
      routingTableData[neighborID][pkt->src] = 1;
    }

    // Optionally, store sequence numbers to avoid processing old LSPs
    // Further code for handling sequence numbers...
  }

  // Timer fired for running Dijkstra's algorithm
  event void dijkstraTimer.fired() {
    call General.print("Dijkstra Timer fired for node %d. Running algorithm...\n", nodeID);
    runDijkstraAlgorithm();
  }

  // Dijkstra's algorithm implementation
  void runDijkstraAlgorithm() {
    int dist[MAXNODES];
    bool visited[MAXNODES];
    int prev[MAXNODES];

    // Initialize distances and predecessors
    for (int i = 0; i < MAXNODES; i++) {
      dist[i] = INFINITY;
      visited[i] = FALSE;
      prev[i] = -1;
    }

    dist[nodeID] = 0;

    for (int i = 0; i < MAXNODES; i++) {
      // Find the unvisited node with the smallest distance
      int u = -1;
      int minDist = INFINITY;
      for (int j = 0; j < MAXNODES; j++) {
        if (!visited[j] && dist[j] < minDist) {
          minDist = dist[j];
          u = j;
        }
      }

      if (u == -1) break; // No more reachable nodes

      visited[u] = TRUE;

      // Update distances to neighbors
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


// Function to insert a value into the routing table
  void insertRoutingTable(int destination, int nextHop) {
    routingTableEntry entry;
    entry.nextHop = nextHop;
    call routingTable.insert(destination, entry);
  }

  

    // Update the routing table with next hops
    for (int i = 0; i < MAXNODES; i++) {
      if (i != nodeID && dist[i] < INFINITY) {
        // Determine next hop
        int nextHop = i;
        while (prev[nextHop] != nodeID && prev[nextHop] != -1) {
          nextHop = prev[nextHop];
        }
        call routingTable.insert(i, nextHop);
      }
    }

    call General.print("Dijkstra's algorithm completed for node %d.\n", nodeID);
  }

  command void LinkState.printRoutingTable() {
    call General.print("Routing table for node %d:\n", nodeID);
    for (int i = 0; i < 64; i++) {
      routingTableEntry entry;
      if (call routingTable.get(i, &entry) == SUCCESS) {
        call General.print("Destination: %d, Next Hop: %d\n", i, entry.nextHop);
      }
    }
  }
}

// Project 1
// CSE 160
// Sep/28/2024
// Zaid Laffta

#include <Timer.h>
#include "../../includes/channels.h"
#include "../../includes/packet.h"
#include "../../includes/protocol.h"
#include "../../includes/CommandMsg.h"
#include "../../includes/command.h"

#define NODETIMETOLIVE  22


module NeighborDiscoveryP {
    // Provides the NeighborDiscovery interface to other modules
    provides interface NeighborDiscovery;
    // Uses the Random interface for generating random numbers
    uses interface Random as Random;
    // Uses the Timer interface with millisecond precision for periodic ping packet to be send
    uses interface Timer<TMilli> as Timer;
    // Uses the Hashmap interface to store and manage neighbors (neighbor cache)
    uses interface Hashmap<uint32_t> as NeighborCache;
    // Uses the SimpleSend interface for sending broadcast messages
    uses interface SimpleSend as Broadcast;
}

implementation {
    // Packet structure for sending messages
    pack MessageToSend;
    // Helper function to prepare a packet with the specified parameters
    void makePack(pack *pkt, uint16_t src, uint16_t dest, uint16_t ttl, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t len);
    // Initializes the Neighbor Discovery process
    command error_t NeighborDiscovery.initialize() {
        // Start a periodic timer with a random interval
        call Timer.startPeriodic(500 + (uint16_t)(call Random.rand16() % 500));
        dbg(GENERAL_CHANNEL, "Neighbor Discovery just Starte \n");
        return SUCCESS;
    }

    // Clears all neighbors that have expired (TTL = 0)
    command void NeighborDiscovery.clearExpiredNeighbors() {
        uint32_t* neighbors = call NeighborCache.getKeys();
        uint16_t i;
        // Iterate over the neighbors and remove those with TTL = 0
        for(i = 0; i < call NeighborCache.size(); i++) {
            if (call NeighborCache.get(neighbors[i]) == 0) {
                dbg(NEIGHBOR_CHANNEL, "Removing expired neighbor: %d\n", neighbors[i]);
                call NeighborCache.remove(neighbors[i]);
            }
        }
    }

    // Processes incoming discovery messages (PING/PINGREPLY)
    command void NeighborDiscovery.processDiscovery(pack* message) {
        dbg(GENERAL_CHANNEL, "Processing Neighbor Discovery \n");
        // If the message is a PING and TTL > 0, decrement TTL and send PINGREPLY
        if(message->TTL > 0 && message->protocol == PROTOCOL_PING) {
            dbg(GENERAL_CHANNEL, "PING received, updating message\n");
            message->TTL--;
            message->src = TOS_NODE_ID;
            message->protocol = PROTOCOL_PINGREPLY;
            call Broadcast.send(*message, AM_BROADCAST_ADDR);
        // If a PINGREPLY is received and the destination is the node itself, confirm the neighbor
        } else if (message->protocol == PROTOCOL_PINGREPLY && message->dest == 0) {
            dbg(GENERAL_CHANNEL, "Ping reply got received, confirmed neighbor %d\n", message->src);
            // Add or update the neighbor in the NeighborCache with a fresh TTL
            if (!call NeighborCache.contains(message->src)) {
                call NeighborCache.insert(message->src, NODETIMETOLIVE);
            }
        }
    }
    
    // Timer event to periodically broadcast and manage neighbor cache
    event void Timer.fired() {
        uint32_t* neighbors = call NeighborCache.getKeys();
        uint8_t dummyPayload = 0;
        uint16_t i = 0;
        //dbg(GENERAL_CHANNEL, "Timer fired event\n");
        // Loop through neighbors and decrement their TTL or remove if expired
        for (i = 0; i < call NeighborCache.size(); i++) {
            if (neighbors[i] == 0) continue;
            if (call NeighborCache.get(neighbors[i]) == 0) {
                dbg(GENERAL_CHANNEL, "Neighbor %d expired, removing\n", neighbors[i]);
                call NeighborDiscovery.clearExpiredNeighbors();
            } else {
                call NeighborCache.insert(neighbors[i], call NeighborCache.get(neighbors[i]) - 1);
            }
        }
        // Send a periodic PING broadcast to discover new neighbors
        dbg(GENERAL_CHANNEL, "Sending periodic broadcast to discover new neighbor\n");
        makePack(&MessageToSend, TOS_NODE_ID, 0, 1, PROTOCOL_PING, 0, &dummyPayload, PACKET_MAX_PAYLOAD_SIZE);
        call Broadcast.send(MessageToSend, AM_BROADCAST_ADDR);
    }

    // Retrieve the TTL (Time To Live) for a specific neighbor
    command uint16_t NeighborDiscovery.getNeighborTTL(uint32_t neighbor) {
        // Check if the neighbor exists in the cache
        if (call NeighborCache.contains(neighbor)) {
            uint16_t ttl = call NeighborCache.get(neighbor);
            dbg(GENERAL_CHANNEL, "TTL for neighbor %d is %d\n", neighbor, ttl);
            return ttl;
        } else {
            dbg(NEIGHBOR_CHANNEL, "Neighbor %d not found\n", neighbor);
            return 0;
        }
    }

    // Fetch all the neighbors from the NeighborCache
    command uint32_t* NeighborDiscovery.fetchNeighbors() {
        return call NeighborCache.getKeys();
    }

    // Fetch the number of neighbors in the NeighborCache
    command uint16_t NeighborDiscovery.fetchNeighborCount() {
        return call NeighborCache.size();
    }

    // Helper function to prepare a packet with the specified parameters
    void makePack(pack *pkt, uint16_t src, uint16_t dest, uint16_t ttl, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t len) {
        dbg(NEIGHBOR_CHANNEL, "Preparing packet\n");
        pkt->src = src;
        pkt->dest = dest;
        pkt->TTL = ttl;
        pkt->seq = seq;
        pkt->protocol = protocol;
        memcpy(pkt->payload, payload, len);
    } 
    // Display the list of neighbors stored in the NeighborCache
    command void NeighborDiscovery.displayNeighbors() {
        uint16_t i = 0;
        uint32_t* neighbors = call NeighborCache.getKeys();
        dbg(NEIGHBOR_CHANNEL, "Displaying neighbor list\n");
         dbg(GENERAL_CHANNEL, "Displaying neighbor list\n");
        // Iterate over the neighbors and print each one
        for(i = 0; i < call NeighborCache.size(); i++) {
            if(neighbors[i] != 0) {
                dbg(GENERAL_CHANNEL, "\tNeighbor: %d\n", neighbors[i]);
            }
        }
    }
}

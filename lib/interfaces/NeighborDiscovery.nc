// Project 1
// CSE 160
// Sep/28/2024
// Zaid Laffta

#include "../../includes/packet.h"

interface NeighborDiscovery {
    command error_t initialize();
    command void processDiscovery(pack* message);
    command uint32_t* fetchNeighbors();
    command uint16_t fetchNeighborCount();
    command void displayNeighbors();
    command void clearExpiredNeighbors();  
    command uint16_t getNeighborTTL(uint32_t neighbor); 
}

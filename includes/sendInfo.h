//Author: UCM ANDES Lab
//Date: 2/15/2012
#ifndef PACK_BUFFER_H
#define PACK_BUFFER_H

#include "packet.h"

enum{
	SEND_BUFFER_SIZE=128
};

typedef struct sendInfo{
	pack packet;
	uint16_t src;
	uint16_t dest;
}sendInfo;
// In a header file, 
typedef struct {
  uint16_t src;  // Source node
  uint16_t dest; // Destination node
  uint16_t cost; // Cost of the link
} lspLink;
//Strc for routing table
typedef struct {
    int nextHop; // Stores the next hop for the routing table
} routingTableEntry;
// In protocol.h


#endif /* PACK_BUFFER_H */

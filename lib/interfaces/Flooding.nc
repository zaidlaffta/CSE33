// Project 1
// CSE 160
// Sep/28/2024
// Zaid Laffta

#include "../../includes/channels.h"
#include "../../includes/packet.h"


interface Flooding {
	// Sends a ping message to the specified destination node.
	command void ping(uint16_t destination, uint8_t *payload);

	// Initiates a flooding operation, where 'myMsg' (a pointer to a packet structure) 
	command void Flood(pack* myMsg);
}

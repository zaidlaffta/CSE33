// Project 1
// CSE 160
// Sep/28/2024
// Zaid Laffta

#include "../../includes/CommandMsg.h"
#include "../../includes/command.h"
#include "../../includes/channels.h"

#define AM_PACK 6  // Active Message ID for packet communication
#define UNUSED_CONSTANT 100  // check the number of packet flooded

configuration FloodingC {
	// The FloodingC configuration provides the Flooding interface to other modules.
	provides interface Flooding;
}

implementation {
	// The FloodingC component 
	components FloodingP;
	Flooding = FloodingP;
	// Instantiate a HashMap component to store previously received packets to avoid redundant flooding.
	components new HashmapC(uint32_t, 25);
	//Instantiate a Map component (with key as uint32_t) to track received packets.
	components new SimpleSendC(AM_PACK);
	//Wiring for Flooding
    //used as a packet identifyer - mentioned in the Lab by Jothi
	FloodingP.PreviousPackets -> HashmapC;
	// Wire SimpleSendC component for sending messages using the Active Message (AM) protocol.
	FloodingP.packetTransmitter -> SimpleSendC;
	
}

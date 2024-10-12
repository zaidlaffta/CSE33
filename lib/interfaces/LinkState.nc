#include "../../includes/packet.h"


interface LinkState{
	command void start();
	command void print();
	command void printRoutingTable();
}
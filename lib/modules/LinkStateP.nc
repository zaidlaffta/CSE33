#include <Timer.h>
#include "../../includes/channels.h"
#include "../../includes/packet.h"
#include "../../includes/protocol.h"
#include "../../includes/CommandMsg.h"
#include "../../includes/command.h"
// Module
#include "../../includes/channels.h"
#include "../../includes/packet.h"
#define INFINITY 9999
#define MAXNODES 20

module LinkStateP{

  // provides intefaces
  provides interface LinkState;

  /// uses interface
  uses interface Timer<TMilli> as lsrTimer;
  uses interface Timer<TMilli> as dijkstraTimer;
  uses interface SimpleSend as LSPSender;
  uses interface List<lspLink> as lspLinkList;
  uses interface List<pack> as neighborList;

  uses interface Hashmap<int> as routingTable;
  uses interface Random as Random;

}

implementation{
  pack sendPackage;
  lspLink lspL;
  uint16_t lspAge = 0;
  bool isvalueinarray(uint8_t val, uint8_t *arr, uint8_t size);
  int makeGraph();

  void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);

  command void LinkState.start(){
    // one shot timer and include random element to it.
    //dbg(GENERAL_CHANNEL, "Booted\n");
    call lsrTimer.startPeriodic(80000 + (uint16_t)((call Random.rand16())%10000));
    call dijkstraTimer.startOneShot(90000 + (uint16_t)((call Random.rand16())%10000));
  }

  command void LinkState.printRoutingTable()
  {
    int i = 0;
    for(i=1; i<=call routingTable.size();i++){
      dbg(GENERAL_CHANNEL, "Dest: %d \t firstHop: %d\n", i, call routingTable.get(i));
    }
  }

  command void LinkState.print()
  {

    if(call lspLinkList.size() > 0)
    {
      uint16_t lspLinkListSize = call lspLinkList.size();
      uint16_t i = 0;

      //dbg(NEIGHBOR_CHANNEL, "***the NEIGHBOUR size of node %d is :%d\n",TOS_NODE_ID, neighborListSize);
      for(i = 0; i < lspLinkListSize; i++)
      {
        lspLink lspackets =  call lspLinkList.get(i);
        dbg(ROUTING_CHANNEL,"Source:%d\tNeighbor:%d\tcost:%d\n",lspackets.src,lspackets.neighbor,lspackets.cost);
      }
    }
    else{
      dbg(COMMAND_CHANNEL, "***0 LSP of node  %d!\n",TOS_NODE_ID);
    }

  }

  event void lsrTimer.fired()
  {
    uint16_t neighborListSize = call neighborList.size();
    uint16_t lspListSize = call lspLinkList.size();

    uint8_t neighborArr[neighborListSize];
    uint16_t i,j = 0;
    bool enterdata = TRUE;
    //dbg(ROUTING_CHANNEL,"**NEighbor size %d\n",neighborListSize);

    if(lspAge==MAX_NEIGHBOR_AGE){
      //dbg(NEIGHBOR_CHANNEL,"removing neighbor of %d with Age %d \n",TOS_NODE_ID,neighborAge);
      lspAge = 0;
      for(i = 0; i < lspListSize; i++) {
        call lspLinkList.popfront();
      }
    }

    //dbg(NEIGHBOR_CHANNEL, "***the NEIGHBOUR size of node %d is :%d\n",TOS_NODE_ID, neighborListSize);
    for(i = 0; i < neighborListSize; i++)
    {
      pack neighborNode = call neighborList.get(i);
      for(j = 0; j < lspListSize; j++)
      {
        lspLink lspackets = call lspLinkList.get(j);
        if(lspackets.src == TOS_NODE_ID && lspackets.neighbor==neighborNode.src){
          enterdata = FALSE;
        }
      }
      if (enterdata){
        lspL.neighbor = neighborNode.src;
        lspL.cost = 1;
        lspL.src = TOS_NODE_ID;
        call lspLinkList.pushback(lspL);
	       call dijkstraTimer.startOneShot(90000 + (uint16_t)((call Random.rand16())%10000));
      }
      if(!isvalueinarray(neighborNode.src,neighborArr,neighborListSize)){
        neighborArr[i] = neighborNode.src;
        //dbg(ROUTING_CHANNEL,"**NEighbor %d in node %d\n",neighborNode.src,TOS_NODE_ID);
        }else{
          //dbg(ROUTING_CHANNEL,"**ALREADY EXISTS %d in node %d\n",neighborNode.src,TOS_NODE_ID);
        }
      }
      makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, MAX_TTL, PROTOCOL_LINKSTATE, neighborListSize, (uint8_t *) neighborArr, neighborListSize);
      call LSPSender.send(sendPackage, AM_BROADCAST_ADDR);
      //  dbg(ROUTING_CHANNEL, "Sending LSPs\n");
    }



    /*
    Command Receive(){
    // If the destination is AM_BROADCAST, then respond directly
    send(msg, msg.src);
    // else
    add neighborlist
    //
    }*/

    // each neighbor time since last response. ( let’s set it to 5)

    bool isvalueinarray(uint8_t val, uint8_t *arr, uint8_t size){
      int i;
      for (i=0; i < size; i++) {
        if (arr[i] == val)
        return TRUE;
      }
      return FALSE;
    }

    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
      Package->src = src;
      Package->dest = dest;
      Package->TTL = TTL;
      Package->seq = seq;
      Package->protocol = protocol;
      memcpy(Package->payload, payload, length);
    }

    /*void CalculateUniqueNodes(){
      //get unique nodes for dijkstra
      int size = call lspLinkList.size();
      int nodesize[MAXNODES];
      int i;
      for (i=0;i<size;i++){
        lspLink stuff = call lspLinkList.get(i);
        if (!isvalueinarray(stuff.src, nodesize, MAXNODES)){
          nodesize[i] = stuff.src;
        }
      }
    }*/

    //dijkstra

    // Source Reference - https://www.thecrazyprogrammer.com/2014/03/dijkstra-algorithm-for-finding-shortest-path-of-a-graph.html
    event void dijkstraTimer.fired()
      {
        int nodesize[MAXNODES];
        int size = call lspLinkList.size();
        int maxNode = MAXNODES;
        int i,j,next_hop, cost[maxNode][maxNode], distance[maxNode], pred_list[maxNode];
        int visited[maxNode], node_count, mindistance, nextnode;
        //pred[] stores the predecessor of each node
        //count gives the number of nodes seen so far
        //create the cost matrix

        int start_node = TOS_NODE_ID;
        bool adjMatrix[maxNode][maxNode];
        //dbg(ROUTING_CHANNEL,"\nSOURCE NODE %d\n",TOS_NODE_ID);




        for(i=0;i<maxNode;i++)
        {
          for(j=0;j<maxNode;j++){
            adjMatrix[i][j] = FALSE;
          }
        }

        for(i=0; i<size;i++){
          lspLink stuff = call lspLinkList.get(i);
          adjMatrix[stuff.src][stuff.neighbor] = TRUE;
        }

        for(i=0;i<maxNode;i++)
        {
          for(j=0;j<maxNode;j++)
          {
            if (adjMatrix[i][j] == 0)
            cost[i][j] = INFINITY;
            else
            cost[i][j] = adjMatrix[i][j];
          }
        }

        //initialize pred[],distance[] and visited[]
        for(i = 0; i < maxNode; i++)
        {
          distance[i] = cost[start_node][i];
          pred_list[i] = start_node;
          visited[i] = 0;
        }


        distance[start_node] = 0;
        visited[start_node] = 1;
        node_count = 1;

        while (node_count < maxNode - 1)
        {
          mindistance = INFINITY;
          //nextnode gives the node at minimum distance
          for (i = 0; i < maxNode; i++){
            if (distance[i] <= mindistance && !visited[i])
            {
              mindistance = distance[i];
              nextnode = i;
            }

          }

          visited[nextnode] = 1;
          //check if a better path exists through nextnode
          for (i = 0; i < maxNode; i++)
          {

            if (!visited[i]){
              if (mindistance + cost[nextnode][i] < distance[i])
              {
                distance[i] = mindistance + cost[nextnode][i];
                pred_list[i] = nextnode;
              }
            }
          }
          node_count++;
        }


        //print the path and distance of each node
        /*
        for(i=1;i<maxNode;i++)
        if(i!=start_node)
        {
        printf("\nDistance of node %d=%d",i,distance[i]);
        printf("\nPath=%d",i);

        j=i;
        do
        {
        j=pred_list[j];
        printf("<-%d",j);
        }while(j!=start_node);
      }
      */

      for (i = 0; i < maxNode; i++){
        next_hop = TOS_NODE_ID;
        if (distance[i] != INFINITY){
          if (i != start_node) {
            j = i;
            do {
              if (j!=start_node){
                next_hop = j;
              }
              j = pred_list[j];
              } while (j != start_node);
            }
            else{
              next_hop = start_node;
            }
            if (next_hop != 0 )
            {
              call routingTable.insert(i, next_hop);
            }
          }
        }

    }
  }
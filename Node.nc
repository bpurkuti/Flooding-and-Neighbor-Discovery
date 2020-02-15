/*
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 *
 */
#include <Timer.h>
#include "includes/command.h"
#include "includes/packet.h"
#include "includes/CommandMsg.h"
#include "includes/sendInfo.h"
#include "includes/channels.h"
#include "includes/neighbor.h"

module Node{
   uses interface Boot;
   uses interface SplitControl as AMControl;
   uses interface Receive;
   uses interface SimpleSend as Sender;
   uses interface CommandHandler;
   uses interface List <uint16_t> as NeighborList;
   uses interface List <uint16_t> as packList;
   uses interface Timer<TMilli> as periodicTimer; //Added timer here------
   uses interface Random as Random; //For Timer
}

implementation{
   pack sendPackage;
   uint16_t seqCounter=0;
   // Prototypes
   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);
   void discoverNeighbor();
   void floodingReceive(pack* msg);
   void printPack();

   event void Boot.booted(){      
      call AMControl.start();
      dbg(GENERAL_CHANNEL, "Booted \n");
   }

   event void AMControl.startDone(error_t err){
      if(err == SUCCESS){
         call periodicTimer.startPeriodic(3000);
         dbg(GENERAL_CHANNEL, "Radio is On\n");
      }else{
         //Retry until successful
         call AMControl.start();
      }
   }

   event void AMControl.stopDone(error_t err){}

   event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
      bool isvisited;
      uint16_t i;
      uint16_t size = call packList.size();


      dbg(GENERAL_CHANNEL, "Packet Received\n");
      if(len==sizeof(pack)){
         pack* myMsg=(pack*) payload;

         myMsg->TTL--;
         dbg(GENERAL_CHANNEL, "Package Payload: %s\n", myMsg->payload);
        // call floodingReceive((myMsg);

         dbg(FLOODING_CHANNEL,"Node %d has seen packets from: ", TOS_NODE_ID);
         for(i=0; i<size; i++)
         {
            dbg(FLOODING_CHANNEL,"%d, ", call packList.get(i));
            if(myMsg->seq == call packList.get(i))
            {
               isvisited=TRUE;
            }
         }
         dbg(FLOODING_CHANNEL, "\n");

         //If the packet ttl is higher than 0, then work with it

         //Makeing sure that the current node hasn't seen the packet
         if(myMsg->TTL > 0 && isvisited==FALSE)
         {
            //if someone pinged ot
            if(myMsg->protocol==PROTOCOL_PING)
            {
               dbg(NEIGHBOR_CHANNEL, "Packet received from %d at %d\n",myMsg->src, TOS_NODE_ID);
               
               if(myMsg->dest==TOS_NODE_ID)
               {
                  dbg(NEIGHBOR_CHANNEL, "Packet received at intended location %d ==%d from %d\n",myMsg->dest,TOS_NODE_ID,myMsg->src);
                  makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, myMsg->TTL-1, PROTOCOL_PINGREPLY, myMsg->seq, (uint8_t *) myMsg->payload, sizeof(myMsg->payload));
                  call Sender.send(sendPackage, myMsg->src);
                  if(call packList.size() == 60)
                  {
                     uint16_t temp = call packList.popfront();
                  }
                  call packList.pushback(myMsg->seq);


               } 
               else if(myMsg->dest== AM_BROADCAST_ADDR)
               {
                  //todo
               }
               else
               {
                  dbg(NEIGHBOR_CHANNEL, "Packet not intended for location %d from %d\n",TOS_NODE_ID,myMsg->src);
                  makePack(&sendPackage, TOS_NODE_ID, myMsg->dest, myMsg->TTL-1, myMsg->protocol, myMsg->seq, (uint8_t *) myMsg->payload, sizeof(myMsg->payload));
                  call Sender.send(sendPackage, AM_BROADCAST_ADDR);
                  if(call packList.size() == 60)
                  {
                     uint16_t temp = call packList.popfront();
                  }
                  call packList.pushback(myMsg->seq);
               }

            }
            else if(myMsg->protocol==PROTOCOL_PINGREPLY)
            {
               dbg(NEIGHBOR_CHANNEL, "Ping reply received from %d\n", myMsg->src);
               //check if there is any space in the pack list
               //make space if none
               //otherwise insert seq
               if(call packList.size() == 60)
               {
                  uint16_t temp = call packList.popfront();
               }
               call packList.pushback(myMsg->seq);
               if(myMsg->dest== AM_BROADCAST_ADDR)
               {
                  //todo
               }

            }
         }
         else
         {
            //if the time to live is 0
            //or If we have already have seen the package before --TODO
            dbg(FLOODING_CHANNEL, "TTL for Packet is %d\n", myMsg->TTL);
            if(isvisited==TRUE)
            {
               dbg(FLOODING_CHANNEL, "Node %d has seen the packet\n", TOS_NODE_ID);
            }
         }

         return msg;
      }

      dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
      return msg;
   }


   event void CommandHandler.ping(uint16_t destination, uint8_t *payload){
      dbg(GENERAL_CHANNEL, "PING EVENT \n");
      seqCounter++;
      makePack(&sendPackage, TOS_NODE_ID, destination, MAX_TTL, PROTOCOL_PING, seqCounter, payload, PACKET_MAX_PAYLOAD_SIZE);
      if(call packList.size() == 60)
               {
                  uint16_t temp = call packList.popfront();
               }
      call packList.pushback(seqCounter);
      call Sender.send(sendPackage, AM_BROADCAST_ADDR);
      
   }

   event void periodicTimer.fired()
   {
     // discoverNeighbor();
   }

   void printPack()
   {
      uint32_t i;
      uint32_t size =call packList.size();

      if(!call packList.isEmpty())
      {
         for(i=0;i<size;i++)
         {
               dbg(FLOODING_CHANNEL, "Position %d has packet %d\n", i, call packList.get(i));
         }
      }
      else
      {
         dbg(FLOODING_CHANNEL, "ME LONELy");
      }
   }

   event void CommandHandler.printNeighbors(){}
   event void CommandHandler.printRouteTable(){}
   event void CommandHandler.printLinkState(){}
   event void CommandHandler.printDistanceVector(){}
   event void CommandHandler.setTestServer(){}
   event void CommandHandler.setTestClient(){}
   event void CommandHandler.setAppServer(){}
   event void CommandHandler.setAppClient(){}

   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
      Package->src = src;
      Package->dest = dest;
      Package->TTL = TTL;
      Package->seq = seq;
      Package->protocol = protocol;
      memcpy(Package->payload, payload, length);
   }

   void floodingReceive(pack* msg)
   {
      

   }

   void discoverNeighbor()
   {
      //ttl is 2 coz 
      uint8_t message= "LET ME IN!!!\n";
      seqCounter++;
      makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, 2, PROTOCOL_PING, seqCounter, (uint8_t *) message, sizeof(message));
      call Sender.send(sendPackage, AM_BROADCAST_ADDR);

     // dbg(NEIGHBOR_CHANNEL,"Neighbor Discovery Triggered from %d, to %d\n", TOS_NODE_ID, AM_BROADCAST_ADDR);
   }
}


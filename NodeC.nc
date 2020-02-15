/**
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 *
 */

#include <Timer.h>
#include "includes/CommandMsg.h"
#include "includes/packet.h"

configuration NodeC{
}
implementation {
    components MainC;
    components Node;
    components new AMReceiverC(AM_PACK) as GeneralReceive;

    Node -> MainC.Boot;

    Node.Receive -> GeneralReceive;

    components ActiveMessageC;
    Node.AMControl -> ActiveMessageC;

    components new SimpleSendC(AM_PACK);
    Node.Sender -> SimpleSendC;

    components CommandHandlerC;
    Node.CommandHandler -> CommandHandlerC;

    //Creating timer as myTimerC
    components new TimerMilliC() as myTimerC; 
    Node.periodicTimer -> myTimerC;

    //Connecting Hashmap or List
    components new ListC(uint16_t, 60) as NeighborListC;
    Node.NeighborList -> NeighborListC;

    components new ListC(uint16_t, 60) as packListC;
    Node.packList -> packListC;

    //Connecting randomgen
    components RandomC as Random;
    Node.Random -> Random;
}

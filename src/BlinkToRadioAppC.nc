#include <Timer.h>
#include "printf.h"
#include "BlinkToRadio.h"


configuration BlinkToRadioAppC{
}
implementation{
  components MainC;
  components LedsC;
  components BlinkToRadioC as App;
  components new TimerMilliC() as PWRNTimer, new TimerMilliC() as NoSyncResponseTimeout,new TimerMilliC() as DataACKTimer;
   components new TimerMilliC() as DataTimer;
  components ActiveMessageC; //Component del paquet
  components new AMSenderC(AM_BLINKTORADIO); //Component del enviador
  components new AMReceiverC(AM_BLINKTORADIO); //Component del receptor
  components PrintfC;
  components SerialStartC;
  
  components CC2420ActiveMessageC;


  
  App.Boot -> MainC;
  App.Leds -> LedsC;
  App.PWRNTimer -> PWRNTimer;
  App.NoSyncResponseTimeout->NoSyncResponseTimeout;
  App.DataACKTimer->DataACKTimer;
  App.DataTimer->DataTimer;

  
  App.Packet -> AMSenderC;
  App.AMPacket -> AMSenderC;
  App.AMSend -> AMSenderC;
  App.AMControl -> ActiveMessageC;
  App.Receive -> AMReceiverC;
  App -> CC2420ActiveMessageC.CC2420Packet;
 
}
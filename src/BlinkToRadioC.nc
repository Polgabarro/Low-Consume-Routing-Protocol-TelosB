#include <Timer.h>
#include "printf.h"
#include "BlinkToRadio.h"

module BlinkToRadioC {
	uses interface Boot;
	uses interface Leds;
	uses interface Timer<TMilli> as PWRNTimer;
	uses interface Timer<TMilli> as NoSyncResponseTimeout;
	uses interface Timer<TMilli> as DataACKTimer;
	uses interface Timer<TMilli> as DataTimer;

	uses interface Packet;
	uses interface AMPacket;
	uses interface AMSend;
	uses interface SplitControl as AMControl;
	uses interface Receive;

	uses interface CC2420Packet;

}
implementation {
	bool busy = FALSE;
	bool NoSyncResponseTimeoutBool = FALSE;
	bool dataACKTimer = FALSE;

	message_t pkt;
	PHASES phases;
	nx_uint16_t id;
	nx_uint16_t negotiationN;
	nx_uint16_t linkDevice;
	nx_uint16_t rxxlinkDevice;
	nx_uint16_t power;
	bool connecteds[20] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
			0};

	/**
	 * FUNCTIONS
	 */
	uint16_t getRssi(message_t * msg) {
		return(uint16_t) call CC2420Packet.getRssi(msg);
	}

	uint8_t getPower(message_t * msg) {
		return call CC2420Packet.getPower(msg);
	}

	uint8_t getLink() {
		uint8_t i;
		for(i = 0; i <= 20; i++) {

			if(connecteds[i] == TRUE) {
				connecteds[i] = FALSE;
				return i;
			}
		}
		return 0;
	}

	/**
	 * MAIN FUNCTIONS
	 */ 

	//SYNC MESSAGES  

	void startSyn() {

		MSGPROTOCOL * p_pkt = (MSGPROTOCOL * )(call Packet.getPayload(&pkt,
				sizeof(MSGPROTOCOL)));

		call CC2420Packet.setPower(&pkt, DEFAULT_POWER);

		memcpy(call AMSend.getPayload(&pkt, sizeof(p_pkt)), &p_pkt, sizeof p_pkt);
		id = id + 1;
		p_pkt->origin = TOS_NODE_ID;
		p_pkt->destiny = GATEWAY;
		p_pkt->typeP = SYNC_;
		p_pkt->id = id;

		if( ! busy) {
			if(call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(MSGPROTOCOL)) == SUCCESS) {
				busy = TRUE;

				call NoSyncResponseTimeout.startOneShot(TIMEOUT_SYNC);
				NoSyncResponseTimeoutBool = TRUE;

			}
		}
		else {
			startSyn();
		}
	}

	void startSYN_ACK(u_int8_t origin) {

		MSGPROTOCOL * p_pkt = (MSGPROTOCOL * )(call Packet.getPayload(&pkt,
				sizeof(MSGPROTOCOL)));
		call CC2420Packet.setPower(&pkt, 33);

		memcpy(call AMSend.getPayload(&pkt, sizeof(p_pkt)), &p_pkt, sizeof p_pkt);
		id = id + 1;

		p_pkt->origin = TOS_NODE_ID;
		p_pkt->destiny = origin;
		p_pkt->typeP = SYNC_ACK;
		p_pkt->id = id;

		if( ! busy) {
			if(call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(MSGPROTOCOL)) == SUCCESS) {
				//printf("Node: %d SYNC-ACK sended\n", origin);
				printfflush();
				busy = TRUE;
			}
		}
		else {
			startSYN_ACK(origin);
		}
	}

	void startErrorSyn() {

		MSGPROTOCOL * p_pkt = (MSGPROTOCOL * )(call Packet.getPayload(&pkt,
				sizeof(MSGPROTOCOL)));
		call CC2420Packet.setPower(&pkt, DEFAULT_POWER);

		memcpy(call AMSend.getPayload(&pkt, sizeof(p_pkt)), &p_pkt, sizeof p_pkt);
		id = id + 1;
		p_pkt->origin = TOS_NODE_ID;
		p_pkt->destiny = BROADCAST;
		p_pkt->typeP = SYNC_;
		p_pkt->id = id;

		if( ! busy) {
			if(call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(MSGPROTOCOL)) == SUCCESS) {
				busy = TRUE;
				//printf("Node: %d Rssi: %d [dBm] Power: %u \n", btrpkt->nodeid, getRssi(msg) 
				//		- 45, getPower(msg));
				//printfflush(); 
				//call NoSyncResponseTimeout.startOneShot(TIMEOUT_SYNC); 

			}
		}
		else {
			startErrorSyn();
		}
	}
	
	
	//ENERGY FASE 
	
	
	nx_uint16_t negotiationAlgorithm(u_int16_t rssi, u_int16_t power){
		
		if(MAXDBM -rssi>=10&&power>20){
			return 10;
		}
		if(MAXDBM -rssi>=5&&power>14){
			return 5;
		}
		return 2;
	}
	
	
	
	void startPWRN() {

		MSGPROTOCOL * p_pkt = (MSGPROTOCOL * )(call Packet.getPayload(&pkt,
				sizeof(MSGPROTOCOL)));
		call CC2420Packet.setPower(&pkt, power);

		memcpy(call AMSend.getPayload(&pkt, sizeof(p_pkt)), &p_pkt, sizeof p_pkt);
		id = id + 1;
		p_pkt->origin = TOS_NODE_ID;
		p_pkt->destiny = linkDevice;
		p_pkt->typeP = PWRN;
		p_pkt->id = id;
		p_pkt->opcional1 = power;
		negotiationN++;
		p_pkt->opcional2 = negotiationN;

		if( ! busy) {
			if(call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(MSGPROTOCOL)) == SUCCESS) {
				busy = TRUE;

				//call NoSyncResponseTimeout.startOneShot(TIMEOUT_SYNC);
				//NoSyncResponseTimeoutBool = TRUE;  

			}
		}
		else {
			startPWRN();
		}
	}

	void PWRNACK(u_int16_t destiny, u_int16_t powert) {
		MSGPROTOCOL * p_pkt = (MSGPROTOCOL * )(call Packet.getPayload(&pkt,
				sizeof(MSGPROTOCOL)));
		call CC2420Packet.setPower(&pkt, DEFAULT_POWER);

		memcpy(call AMSend.getPayload(&pkt, sizeof(p_pkt)), &p_pkt, sizeof p_pkt);
		id = id + 1;

		p_pkt->origin = TOS_NODE_ID;
		p_pkt->destiny = destiny;
		p_pkt->typeP = PWRN_ACK;
		p_pkt->id = id;
		p_pkt->opcional1 = powert;

		if( ! busy) {
			if(call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(MSGPROTOCOL)) == SUCCESS) {
				busy = TRUE;

				//call NoSyncResponseTimeout.startOneShot(TIMEOUT_SYNC);
				//NoSyncResponseTimeoutBool = TRUE;  

			}
		}
		else {
			PWRNACK(destiny, powert);
		}

	}
	void sendPWRNOK(u_int16_t destiny) {
		MSGPROTOCOL * p_pkt = (MSGPROTOCOL * )(call Packet.getPayload(&pkt,
				sizeof(MSGPROTOCOL)));
		call CC2420Packet.setPower(&pkt, DEFAULT_POWER);

		memcpy(call AMSend.getPayload(&pkt, sizeof(p_pkt)), &p_pkt, sizeof p_pkt);
		id = id + 1;

		p_pkt->origin = TOS_NODE_ID;
		p_pkt->destiny = destiny;
		p_pkt->typeP = PWRN_OK;
		p_pkt->id = id;

		if( ! busy) {
			if(call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(MSGPROTOCOL)) == SUCCESS) {
				busy = TRUE;

				//call NoSyncResponseTimeout.startOneShot(TIMEOUT_SYNC);
				//NoSyncResponseTimeoutBool = TRUE;  

			}
		}
		else {
			sendPWRNOK(destiny);
		}
	}

	//DATA INFO MESSAGES 
	//CONNECTION OK
	void connectionCheck() {	
		MSGPROTOCOL * p_pkt = (MSGPROTOCOL * )(call Packet.getPayload(&pkt,
				sizeof(MSGPROTOCOL)));
		call CC2420Packet.setPower(&pkt, power);
		
		call DataACKTimer.startOneShot(250);
		dataACKTimer=TRUE;

		memcpy(call AMSend.getPayload(&pkt, sizeof(p_pkt)), &p_pkt, sizeof p_pkt);
		id = id + 1;
		p_pkt->origin = TOS_NODE_ID;
		p_pkt->destiny = linkDevice;
		p_pkt->typeP = DATA;
		p_pkt->id = id;
		p_pkt->opcional1 = 0;
		p_pkt->opcional2 = 1;

		if( ! busy) {
			if(call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(MSGPROTOCOL)) == SUCCESS) {

				busy = TRUE;
			}
		}
		else {
			connectionCheck();
		}
	}
	void sendDataACK(MSGPROTOCOL * p_pktR) {

		MSGPROTOCOL * p_pkt = (MSGPROTOCOL * )(call Packet.getPayload(&pkt,
				sizeof(MSGPROTOCOL)));
		call CC2420Packet.setPower(&pkt, power);

		memcpy(call AMSend.getPayload(&pkt, sizeof(p_pkt)), &p_pkt, sizeof p_pkt);
		id = id + 1;
		p_pkt->origin = TOS_NODE_ID;
		p_pkt->destiny = getLink();
		p_pkt->typeP = DATA_ACK;
		p_pkt->id = id;
		p_pkt->opcional1 = p_pktR->opcional1;
		p_pkt->opcional2 = p_pktR->origin;

		if( ! busy) {
			if(call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(MSGPROTOCOL)) == SUCCESS) {
				busy = TRUE;
			}
		}
		else {
			sendDataACK(p_pktR);
		}
	}

	//DEBUG MESSAGES 

	void DebugMessage() {

		MSGPROTOCOL * p_pkt = (MSGPROTOCOL * )(call Packet.getPayload(&pkt,
				sizeof(MSGPROTOCOL)));
		call CC2420Packet.setPower(&pkt, power);

		memcpy(call AMSend.getPayload(&pkt, sizeof(p_pkt)), &p_pkt, sizeof p_pkt);
		id = id + 1;
		p_pkt->origin = TOS_NODE_ID;
		p_pkt->destiny = linkDevice;
		p_pkt->typeP = DATA;
		p_pkt->id = id;
		p_pkt->opcional1 = 0;
		p_pkt->opcional2 = 0;

		if( ! busy) {
			if(call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(MSGPROTOCOL)) == SUCCESS) {
				busy = TRUE;

			}
		}
		else {
			DebugMessage();
		}
	}

	void resendData(MSGPROTOCOL * p_pktR) {

		MSGPROTOCOL * p_pkt = (MSGPROTOCOL * )(call Packet.getPayload(&pkt,
				sizeof(MSGPROTOCOL)));
		call CC2420Packet.setPower(&pkt, power);

		memcpy(call AMSend.getPayload(&pkt, sizeof(p_pkt)), &p_pkt, sizeof p_pkt);
		id = id + 1;
		p_pkt->origin = p_pktR->origin;
		p_pkt->destiny = linkDevice;
		p_pkt->typeP = DATA;
		p_pkt->id = p_pktR->id;
		p_pkt->opcional2 = p_pktR->opcional2;

		if(p_pktR->opcional1 == 0) {
			p_pkt->opcional1 = TOS_NODE_ID;
		}
		else {
			p_pkt->opcional1 = p_pktR->opcional1 * 10 + TOS_NODE_ID;
		}

		if( ! busy) {
			if(call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(MSGPROTOCOL)) == SUCCESS) {
				busy = TRUE;

			}
		}
		else {
			resendData(p_pktR);
		}
	}
	void resendDataACK(MSGPROTOCOL * p_pktR) {

		MSGPROTOCOL * p_pkt = (MSGPROTOCOL * )(call Packet.getPayload(&pkt,
				sizeof(MSGPROTOCOL)));
		call CC2420Packet.setPower(&pkt, 33);

		memcpy(call AMSend.getPayload(&pkt, sizeof(p_pkt)), &p_pkt, sizeof p_pkt);
		id = id + 1;
		p_pkt->origin = p_pktR->origin;

		if(p_pktR->opcional1 == 0) {
			p_pkt->destiny = p_pktR->destiny;
		}
		else {
			p_pkt->opcional1 = p_pktR->opcional1 * 10 + TOS_NODE_ID;
		}

		p_pkt->destiny = getLink();
		p_pkt->typeP = DATA;
		p_pkt->id = p_pktR->id;
		p_pkt->opcional2 = p_pktR->opcional2;

		if( ! busy) {
			if(call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(MSGPROTOCOL)) == SUCCESS) {
				busy = TRUE;

			}
		}
		else {
			resendData(p_pktR);
		}
	}

	/**
	 * EVENTS
	 */ 

	event void Boot.booted() {
		negotiationN=0;
		id = 0;
		rxxlinkDevice = -100;
		linkDevice = -1;
		power = DEFAULT_POWER;

		if(TOS_NODE_ID == 0) {
			printf("BASE DETECTED\n");
			linkDevice = 0;
			printfflush();
			phases = BASE;
			call Leds.led0Toggle();
			call Leds.led1Toggle();
			call Leds.led2Toggle();
		}
		else {
			phases = PHASE_SYNC;
		}
		call AMControl.start();
	}

	event void AMControl.startDone(error_t err) {
		if(err == SUCCESS) {

			if(phases == PHASE_SYNC) {
				startSyn();
			}
			else {
				printf("PASSIVE MODE\n");
				printfflush();
			}
			//call Timer0.startPeriodic(TIMER_PERIOD_MILLI);
		}
		else {
			call AMControl.start();
		}
	}

	event void AMControl.stopDone(error_t err) {
		negotiationN=0;
		id = 0;
		rxxlinkDevice = -100;
		linkDevice = -1;
		power = DEFAULT_POWER;

		if(TOS_NODE_ID == 0) {
			printf("BASE DETECTED\n");
			linkDevice = 0;
			printfflush();
			phases = BASE;
			call Leds.led0Toggle();
			call Leds.led1Toggle();
			call Leds.led2Toggle();
		}
		else {
			phases = PHASE_SYNC;
			call Leds.led0Off();
			call Leds.led1Off();
			call Leds.led2Off();
		}
		call AMControl.start();
	}

	event void AMSend.sendDone(message_t * msg, error_t error) {
		if(&pkt == msg) {
			busy = FALSE;
		}
	}

	/**
	 * RECEIVE MESSAGES
	 */ 

	event message_t * Receive.receive(message_t * msg, void * payload,
			uint8_t len) {

		if(len == sizeof(MSGPROTOCOL)) {

			MSGPROTOCOL * p_pkt = (MSGPROTOCOL * ) payload;
			//printf("PAQUET RECEIVEED TYPE %d DESTINY %d\n",p_pkt->typeP,p_pkt->destiny);
			//printfflush();  

			if(p_pkt->destiny == TOS_NODE_ID || p_pkt->destiny == BROADCAST) {
				if(p_pkt->typeP == SYNC_) {
					//printf("PAQUET SYNC RECEIVED\n");
					//printfflush();
					if(linkDevice != -1) {
						startSYN_ACK(p_pkt->origin);
					}
				}
				if(p_pkt->typeP == SYNC_ACK && TOS_NODE_ID != GATEWAY) {
					NoSyncResponseTimeoutBool = FALSE;

					if(rxxlinkDevice < getRssi(msg)) {

						rxxlinkDevice = getRssi(msg);
						linkDevice = p_pkt->origin;
					}

					call Leds.led0On();
					DebugMessage();

					call PWRNTimer.startOneShot(500);

				}
				if(p_pkt->typeP == DATA) {

					if(p_pkt->opcional2 == 1) {
						connecteds[p_pkt->origin] = 1;
					}
					if(TOS_NODE_ID == GATEWAY) {

						if(p_pkt->opcional2 == 0) {
							printf("Node: %d Connected!! RSSI: %d [dBm] BTW Nodes: %d \n", p_pkt->origin, getRssi(msg) - 45, p_pkt->opcional1);
							printfflush();
						}
						else 
							if(p_pkt->opcional2 == 1) {
							printf("ID: %d Node: %d Connexion established!! RSSI: %d [dBm] BTW Nodes: %d \n",p_pkt->id ,p_pkt->origin, getRssi(msg) - 45, p_pkt->opcional1);
							printfflush();
							sendDataACK(p_pkt);
						}
					}
					else {

						resendData(p_pkt);
					}

				}
				if(p_pkt->typeP == DATA_ACK) {

					if(p_pkt->opcional2 == TOS_NODE_ID) {
						call Leds.led2On();
						call Leds.led1Off();
						call DataTimer.startOneShot(500);
						dataACKTimer=FALSE;
						//END! 

					}
					else {
						resendDataACK(p_pkt);
					}

				}
				if(p_pkt->typeP == PWRN && p_pkt->destiny == TOS_NODE_ID) {
					u_int16_t rssi = getRssi(msg) - 45;
					u_int16_t powert = p_pkt->opcional1;
					if((rssi > MINDBM && rssi <= MAXDBM) || (powert <= MINENERGY)) {
						if(TOS_NODE_ID == GATEWAY) {
							printf("Negotiation PWR %d Node %d PWR %d RSSI %d [dBm] PUT POWER: OK\n",p_pkt->opcional2,
									p_pkt->origin, p_pkt->opcional1, rssi);
							printfflush();
						}
						sendPWRNOK(p_pkt->origin);
					}
					else 
						if(rssi < MINDBM) {
						powert += 2;

						if(powert > MAXENERGY) {

							if(TOS_NODE_ID == GATEWAY) {
					printf("Negotiation PWR %d Node %d PWR %d RSSI %d [dBm] PUT POWER: OK\n",p_pkt->opcional2,
									p_pkt->origin, p_pkt->opcional1, rssi);
								printfflush();
							}
							sendPWRNOK(p_pkt->origin);

						}
						else {
							if(TOS_NODE_ID == GATEWAY) {
								printf("Negotiation PWR %d Node %d PWR %d RSSI %d [dBm] PUT POWER: %d\n",p_pkt->opcional2,
										p_pkt->origin, p_pkt->opcional1, rssi, powert);
								printfflush();
							}
							PWRNACK(p_pkt->origin, powert);
						}
					}
					else 
						if(rssi > MAXDBM) {
						powert -= negotiationAlgorithm(rssi,powert);
						if(TOS_NODE_ID == GATEWAY) {
							printf("Negotiation PWR %d Node %d PWR %d RSSI %d [dBm] PUT POWER: %d\n",p_pkt->opcional2,
										p_pkt->origin, p_pkt->opcional1, rssi, powert);
							printfflush();
						}
						PWRNACK(p_pkt->origin, powert);
					}
				}
				if(p_pkt->typeP == PWRN_ACK && p_pkt->destiny == TOS_NODE_ID) {
					power = p_pkt->opcional1;
					call PWRNTimer.startOneShot(500);
				}
				if(p_pkt->typeP == PWRN_OK && p_pkt->destiny == TOS_NODE_ID) {
					call Leds.led0Off();
					call Leds.led1On();
					negotiationN=0;
					connectionCheck();

					//TIMER COMPROVOCIÓ			
				}
			}
		}
		return msg;

	}
	/**
	 * TIMERS
	 */ 

	event void PWRNTimer.fired() {
		call Leds.led1Toggle();
		startPWRN();
	}

	event void NoSyncResponseTimeout.fired() {
		if(NoSyncResponseTimeoutBool) {

			startErrorSyn();
		}

		/*if(NoSyncBResponseTimeoutBool){
		 call AMControl.stop();
		 }*/
	}

	event void DataACKTimer.fired() {
		if(dataACKTimer){
			call AMControl.stop();
			
			}
	}

	event void DataTimer.fired(){
		connectionCheck();
		
	}
}

//
#ifndef BLINKTORADIO_H
#define BLINKTORADIO_H

enum {
	AM_BLINKTORADIO = 6,
	TIMER_PERIOD_MILLI = 250,
	TIMEOUT_SYNC = 1000,
	DEFAULT_POWER = 31,
	
	//GENERCI ADRESES
	
	BROADCAST = 777,
	GATEWAY = 0,
	
	//PAQUET TYPES
	SYNC_ = 10,
	SYNC_ACK = 11,
	PWRN = 12,
	PWRN_ACK = 13,
	PWRN_OK = 14,
	DATA = 15,
	DATA_ACK = 16
};

#define MAXDBM -72
#define MINDBM -80
#define MINENERGY 5
#define MAXENERGY 31





//PAQUET DESIGN
typedef nx_struct {

	nx_uint16_t origin;
	nx_uint16_t destiny;
	nx_uint16_t id;
	nx_uint16_t typeP;
	nx_uint16_t opcional1;
	nx_uint16_t opcional2;

} MSGPROTOCOL;

//FASES    

typedef enum {
	PHASE_SYNC,
	PHASE_SYNC_ERROR,
	PHASE_ENERGY,
	PHASE_DELAY,
	BASE
} PHASES;

#endif 

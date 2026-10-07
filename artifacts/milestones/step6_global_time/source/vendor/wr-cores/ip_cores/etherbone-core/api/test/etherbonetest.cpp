/*
 * etherbonetest.cpp
 *
 *  Created on: 13.03.2012
 *      Author: zweig
 */


//-rpath=/usr/local/lib

#define __STDC_FORMAT_MACROS
#define __STDC_CONSTANT_MACROS

#include <math.h>
#include <time.h>
#include <stdlib.h>
#include <vector>
#include "ethDevice.h"

#define MAX_CycleSend  250
#define MAX_SCycleSend 70
#define adress_step 4

Teth_settings* local_settings;

void help(){
	printf("usage          : <proto/host/port> <address> <address range>\n");
	printf("example/default: etherbone_test udp/localhost/8183 0x4000 0x4fff\n\n");
}

// fehler ausgabe/etherbone_test udp/localhost/8183 0x40000 0x4ffff
//  ----------------------------------------------
void print_errors(Terror_data* err_data, int err_cnt){

	int index;

	index = 1;
	while (index <= err_cnt){
		printf("Compare error ! Address : %"EB_ADDR_FMT"  write:%"EB_DATA_FMT" <--> read:%"EB_DATA_FMT"\n",
				err_data[index].adress, err_data[index].wr_data, err_data[index].rd_data);
		index++;
	};
	printf("Errors found: %d\n", err_cnt);

}

// generiert zufallszahlen
//  ----------------------------------------------
void print_settings(Teth_settings& local_settings){

	//parameter ausgeben
	printf("\nParameter :\n");
	printf("-------------\n");

	printf("Address      : %"EB_ADDR_FMT"\n", local_settings.address);
	printf("Address range: %"EB_ADDR_FMT"\n", local_settings.address_range);
	printf("Netaddress   : %s\n", local_settings.netaddress);

	printf("Address width: ");
	switch (local_settings.address_width){
		case EB_ADDR8 :	printf("EB_ADDR8\n");	break;
		case EB_ADDR16:	printf("EB_ADDR16\n");	break;
		case EB_ADDR32:	printf("EB_ADDR32\n");	break;
		case EB_ADDR64:	printf("EB_ADDR64\n");	break;
		case EB_ADDRX :	printf("EB_ADDRX\n");	break;
	};

	printf("Data width   : ");
	switch (local_settings.data_width){
		case EB_DATA8 :	printf("EB_DATA8\n");	break;
		case EB_DATA16:	printf("EB_DATA16\n");	break;
		case EB_DATA32:	printf("EB_DATA32\n");	break;
		case EB_DATA64:	printf("EB_DATA64\n");	break;
		case EB_DATAX :	printf("EB_DATAX\n");	break;
	};

	printf("Endian width : ");
	switch (local_settings.endian_width){
		case EB_ENDIAN_MASK  :	printf("EB_ENDIAN_MASK\n");		break;
		case EB_BIG_ENDIAN	 :	printf("EB_BIG_ENDIAN\n");		break;
		case EB_LITTLE_ENDIAN:	printf("EB_LITTLE_ENDIAN\n");	break;
	};

	printf("Probe	     : %d\n", local_settings.probe);
	printf("Attempts     : %d\n", local_settings.attempts);

	printf("-------------\n\n");
}



// generiert zufallszahlen
//  ----------------------------------------------

void eth_rand_data(Tsend_data* eth_data, int max){

	int index;

	// generator starten
	srand((unsigned)time(NULL));

	// zufalls daten erzeugen
	index = 1;
	while(index <= max){
		// zufallsdatum erzeugen
		eth_data[index].data = (rand()+rand());//*pow(2,32);

		//width_do=(rand()%5)+1)
		eth_data[index].data_width = EB_DATA32;

		index++;
	}
}


eb_status_t eth_open(Teth_settings& local_settings){

	eb_status_t status;

	// socket oeffnet/device oeffnen
	status = local_settings.socket.open(0,local_settings.address_width|local_settings.data_width);
	if(status == EB_OK){
		status = local_settings.device.open(local_settings.socket, local_settings.netaddress,
										    local_settings.address_width|local_settings.data_width,
											local_settings.attempts);
	}
	return(status);
}


void eth_close(Teth_settings local_settings){

	local_settings.device.close();
	local_settings.socket.close();
}


eb_status_t eth_testA(Teth_settings local_settings){


	int MAX_SEND=256;

	eb_address_t my_adress;

	my_adress = local_settings.address;

	// Daten anlegen die gesendet werden sollen
	Tsend_data my_data[MAX_SEND+1];

	// Daten anlegen die gelesen werden sollen
	Tread_data my_rd_data[MAX_SEND+1];

	// Zufallszahlen Generieren
	eth_rand_data(my_data ,MAX_SEND);

	// cycles anlegen
	test_cycle cycle_rw;
	test_cycle cycle_wr;

	cycle_rw.myCycle.open(local_settings.device, &cycle_rw, &wrap_member_callback<test_cycle, &test_cycle::complete>);
	cycle_wr.myCycle.open(local_settings.device, &cycle_wr, &wrap_member_callback<test_cycle, &test_cycle::complete>);

	// lesen/schreiben
	cycle_rw.myCycle.read (my_adress, local_settings.endian_width|local_settings.data_width, &my_rd_data[1].data);
	cycle_rw.myCycle.write(my_adress, local_settings.endian_width|local_settings.data_width, my_data[1].data);
	cycle_rw.myCycle.read (my_adress, local_settings.endian_width|local_settings.data_width, &my_rd_data[2].data);
	cycle_rw.myCycle.write(my_adress, local_settings.endian_width|local_settings.data_width, my_data[2].data);


	// Schreiben/Lesen
	cycle_wr.myCycle.write(my_adress, local_settings.endian_width|local_settings.data_width, my_data[3].data);
	cycle_wr.myCycle.read (my_adress, local_settings.endian_width|local_settings.data_width, &my_rd_data[2].data);
	cycle_wr.myCycle.write(my_adress, local_settings.endian_width|local_settings.data_width, my_data[2].data);
	cycle_wr.myCycle.read (my_adress, local_settings.endian_width|local_settings.data_width, &my_rd_data[4].data);

	// cycles schliessen
	cycle_rw.cycle_res_stat();
	cycle_rw.myCycle.close_silently();

	cycle_wr.cycle_res_stat();
	cycle_wr.myCycle.close_silently();

    // cycles abarbeiten
	while (!cycle_rw.ready() || !cycle_wr.ready()) {
		local_settings.socket.run(-1);
    };

    // fehlermeldungen ausgeben
    if(cycle_rw.cycle_rd_stat() != EB_OK) {
	   	return(cycle_rw.cycle_rd_stat());
	} else if(cycle_wr.cycle_rd_stat() != EB_OK){
		return(cycle_wr.cycle_rd_stat());
	};



	return EB_OK;

}



eb_status_t eth_testaddrange(Teth_settings local_settings, int cyclnbr, Terror_data* error_data,
					  	  	 int MAX_SEND, int& err_cnt){

	struct cycle_data{
		Tsend_data my_data[251];
	};

	eb_address_t my_adress;
	int index;
	int index_cy;
	int index_err;
	err_cnt = 0;

	// cycles objekte anlegen
	std::vector<test_cycle> wrTestCycle(cyclnbr+1);
	std::vector<test_cycle> rdTestCycle(cyclnbr+1);

	// Daten anlegen die gesendet werden sollen
	//Tsend_data* my_data= new Tsend_data[MAX_SEND+1];
	cycle_data wr_cycle_data[cyclnbr+1];
	cycle_data rd_cycle_data[cyclnbr+1];

	// Daten anlegen die gelesen werden sollen
	//Tread_data* my_rd_data= new Tread_data[MAX_SEND+1];

	// cycles erstellen
	index_cy= 1;
	index	= 1;
	while(index_cy <= cyclnbr+1){
		wrTestCycle[index_cy].myCycle.open(local_settings.device, &wrTestCycle[index_cy],
											&wrap_member_callback<test_cycle, &test_cycle::complete>);
		rdTestCycle[index_cy].myCycle.open(local_settings.device, &rdTestCycle[index_cy],
											&wrap_member_callback<test_cycle, &test_cycle::complete>);

		index_cy++;
	};

	// cycles erstellen
	index_cy=1;
	my_adress = local_settings.address;

	// alle cycles durchgehen
	while(index_cy <= cyclnbr){

		// zufalls daten erzeugen
		eth_rand_data(wr_cycle_data[index_cy].my_data, 251);

		index = 1;
		// cycle befüllen
		while(index <= MAX_SEND){
			//schreibe anweisung
			wrTestCycle[index_cy].myCycle.write(my_adress, local_settings.endian_width|local_settings.data_width,
					                            wr_cycle_data[index_cy].my_data[index].data);
			wr_cycle_data[index_cy].my_data[index].adress = my_adress;

			//lese anweisung
			rdTestCycle[index_cy].myCycle.read(my_adress, local_settings.endian_width|local_settings.data_width,
					                           &rd_cycle_data[index_cy].my_data[index].data);

			rd_cycle_data[index_cy].my_data[index].adress = my_adress;

			//adresse erhoehen
			my_adress = my_adress + local_settings.addr_step;
			index++;
		}

		wrTestCycle[index_cy].cycle_res_stat();
		rdTestCycle[index_cy].cycle_res_stat();

		wrTestCycle[index_cy].myCycle.close();
		rdTestCycle[index_cy].myCycle.close();
		index_cy++;
	}

    // alle cycles nach abarbeitstatus abfragen
    index_cy = 1;
    while (index_cy <= cyclnbr) {
    	if((!wrTestCycle[index_cy].ready())||(!rdTestCycle[index_cy].ready())){
    		local_settings.socket.run(-1);
    	};
    	index_cy++;
    };

    // fehlermeldungen ausgeben
    index_cy = 1;
    while (index_cy <= cyclnbr){
    	if((wrTestCycle[index_cy].cycle_rd_stat() != EB_OK)||(rdTestCycle[index_cy].cycle_rd_stat() != EB_OK)){
    		return(wrTestCycle[index_cy].cycle_rd_stat());
    	}
    	index_cy++;
    };

    // daten miteinander vergleichen
    index_cy = 1;
    index_err = 1;
    err_cnt = 0;
    while(index_cy <= cyclnbr){
    	index= 1;
    	while(index <= MAX_SEND){
    		if(wr_cycle_data[index_cy].my_data[index].data != rd_cycle_data[index_cy].my_data[index].data){
        		error_data[index_err].adress  = wr_cycle_data[index_cy].my_data[index].adress;
        		error_data[index_err].wr_data = wr_cycle_data[index_cy].my_data[index].data;
        		error_data[index_err].rd_data = rd_cycle_data[index_cy].my_data[index].data;
        		index_err++;
         		err_cnt++;
    		}
    		index++;
    	}
    	index_cy++;
    }

    return EB_OK;
}



//	multicycle true  -> liest /schreibt in je einen cycle
//  multicycle false -> liest /schreibt in einen cycle
//  adadress true	 -> fortlaufende adresse
//  adadress false	 -> gleiche adresse
//  ----------------------------------------------
eb_status_t eth_rdcyad(Teth_settings local_settings,bool adadress, bool multicycle,
					   Terror_data* error_data, int MAX_SEND, int& err_cnt){

	eb_address_t my_adress;
	int index;
	int index_err;
	err_cnt = 0;

	// Daten anlegen die gesendet werden sollen
	Tsend_data* my_data= new Tsend_data[MAX_SEND+1];

	// Daten anlegen die gelesen werden sollen
	Tread_data* my_rd_data= new Tread_data[MAX_SEND+1];

	eth_rand_data(my_data ,MAX_SEND);

	// cycles anlegen
	test_cycle cycle_one;
	test_cycle cycle_two;

    cycle_one.myCycle.open(local_settings.device, &cycle_one, &wrap_member_callback<test_cycle, &test_cycle::complete>);

    if(multicycle){
        cycle_two.myCycle.open(local_settings.device, &cycle_two, &wrap_member_callback<test_cycle, &test_cycle::complete>);
    }

	// cycles mit leben fuellen
	index = 1;
	my_adress = local_settings.address;
	while(index <= MAX_SEND){
		cycle_one.myCycle.write(my_adress, local_settings.endian_width|local_settings.data_width, my_data[index].data);
		my_data[index].adress = my_adress;
		if(multicycle){
			cycle_two.myCycle.read (my_adress, local_settings.endian_width|local_settings.data_width,
									&my_rd_data[index].data);
		}else{
			cycle_one.myCycle.read (my_adress, local_settings.endian_width|local_settings.data_width,
									&my_rd_data[index].data);
		}

		if(adadress){my_adress = my_adress + local_settings.addr_step;};
		index++;
	};

	cycle_one.cycle_res_stat();
	cycle_one.myCycle.close();

	if(multicycle){
		cycle_two.cycle_res_stat();
		cycle_two.myCycle.close();
	};

    // cycles abarbeiten
    if(multicycle){
    	while (!cycle_one.ready() || !cycle_two.ready()) {
    		local_settings.socket.run(-1);
        };
    }else{
    	while (!cycle_one.ready()){
    		local_settings.socket.run(-1);
    	};
    };

    // fehlermeldungen ausgeben
    if(cycle_one.cycle_rd_stat() != EB_OK) {
    	return(cycle_one.cycle_rd_stat());
    }

    if(multicycle){
    	if(cycle_two.cycle_rd_stat() != EB_OK){
    		return(cycle_two.cycle_rd_stat());
    	}
    }

    // daten miteinander vergleichen
    index= 1;
    index_err = 1;
    err_cnt = 0;
    while(index <= MAX_SEND){
    	if( my_data[index].data != my_rd_data[index].data){
    		error_data[index_err].adress  = my_data[index].adress;
    		error_data[index_err].wr_data = my_data[index].data;
    		error_data[index_err].rd_data = my_rd_data[index].data;
    		index_err++;
     		err_cnt++;
    	};
    	index++;
    }

	delete my_data;
	delete my_rd_data;

	return EB_OK;
}


int main(int argc, char* argv[]){

	eb_status_t status;
	int err_cnt;
	char* value_end;

	bool multicycle;
	bool add_up_adress;

	int cyclenbr;

	Terror_data err_data[1024];

// Settings anlegen fuer den localen snooper
	Teth_settings local_settings;

// default settings fuer locale device festlegen
// ------------------------------------------------------------------------
	local_settings.address 		= 0x4000;
	local_settings.address_range= 0xfff;
	local_settings.netaddress 	= "udp/localhost/8183";
	local_settings.address_width= EB_ADDR32;
	local_settings.data_width 	= EB_DATA32;
	local_settings.endian_width	= EB_BIG_ENDIAN;
	local_settings.probe 		= 1;
	local_settings.attempts 	= 3;
	local_settings.addr_step 	= 0x4;


// user argumente einlesen
// ------------------------------------------------------------------------

	// help ausgeben
	if(argc > 1){
		if(strcmp(argv[1],"-help")== 0){
			help();
			return(-1);
		};
	};

	// user parameter übergeben
	if(argc > 2){
		local_settings.netaddress    = argv[1];
		local_settings.address       = strtoull(argv[optind+1], &value_end, 0);
		local_settings.address_range = strtoull(argv[optind+2], &value_end, 0)-local_settings.address;
	};

	// settings ausgeben
	print_settings(local_settings);

	// socket object anlegen
	Socket mySocket;
	local_settings.socket= mySocket;

	// device objekt anlegen
	Device myDevice;
	local_settings.device= myDevice;

	// eth device oeffnen
	status= eth_open(local_settings);
	if(status != EB_OK){
		printf("\e[31mERROR: connect eth-device failure :%s\e[0m\n",eb_status(status));
		return(-1);
	};


// Test 1 schreiben erst dann lesen in einen cycle an gleiche adresse
//-------------------------------------------------------------------------
	printf("Test 1: ");
	err_cnt = 0;

	multicycle 	  = false;
	add_up_adress = false;

	status = eth_rdcyad(local_settings, add_up_adress, multicycle, err_data, MAX_SCycleSend, err_cnt);
	if(status != EB_OK){
		printf("\e[31mERROR during test: %s\e[0m\n",eb_status(status));
		return(-1);
	}

	// fehler ausgabe
	if(err_cnt == 0){printf("- OK -\n");}else{
		printf("\n");
		print_errors(err_data, err_cnt);
		printf("\e[31m- FAILURE -\e[0m\n");
		printf("-------------\n");
	};


// Test 2 schreiben erst dann lesen in je einen cycle an gleiche adresse
//-------------------------------------------------------------------------
	printf("Test 2: ");
	err_cnt = 0;

	multicycle 	  = true;
	add_up_adress = false;

	status = eth_rdcyad(local_settings, add_up_adress, multicycle, err_data, MAX_CycleSend, err_cnt);
	if(status != EB_OK){
		printf("\e[31mERROR during test: %s\e[0m\n",eb_status(status));
		return(-1);
	}

	// fehler ausgabe
	if(err_cnt == MAX_CycleSend-1){printf("- OK -\n");}else{
		printf("\n");
		print_errors(err_data, err_cnt);
		printf("\e[31m- FAILURE -\e[0m\n");
		printf("-------------\n");
	};


// Test 3 schreiben erst dann lesen in einen cycle an fortlaufende adresse
//-------------------------------------------------------------------------
	printf("Test 3: ");
	err_cnt = 0;

	multicycle 	  = false;
	add_up_adress = true;

	status = eth_rdcyad(local_settings, add_up_adress, multicycle, err_data, MAX_SCycleSend, err_cnt);
	if(status != EB_OK){
		printf("\e[31mERROR during test: %s\e[0m\n",eb_status(status));
		return(-1);
	}

	// fehler ausgabe
	if(err_cnt == 0){printf("- OK -\n");}else{
		printf("\n");
		print_errors(err_data, err_cnt);
		printf("\e[31m- FAILURE -\e[0m\n");
		printf("-------------\n");
	};


// Test 4 schreiben erst dann lesen in je einen cycle an fortlaufende adresse
//-------------------------------------------------------------------------

	printf("Test 4: ");
	err_cnt = 0;

	multicycle 	  = true;
	add_up_adress = true;

	status = eth_rdcyad(local_settings, add_up_adress, multicycle, err_data, MAX_SCycleSend, err_cnt);
	if(status != EB_OK){
		printf("\e[31mERROR during test: %s\e[0m\n",eb_status(status));
		return(-1);
	}

	// fehler ausgabe
	if(err_cnt == 0){printf("- OK -\n");}else{
		printf("\n");
		print_errors(err_data, err_cnt);
		printf("\e[31m- FAILURE -\e[0m\n");
		printf("-------------\n");
	};


// Test 5  schreibt erst dann lesen in je einen cycle ueber den gesammten adressraum
//-------------------------------------------------------------------------------------------

	printf("Test 5 /");
	err_cnt = 0;

	// anzahl der cycles berechnen 250 datensätze pro cycle je 4 byte adresschritte
	cyclenbr = int(local_settings.address_range / 0x3e8);

	printf("Cycles %d :",cyclenbr);

	if(cyclenbr > 0) {
		status = eth_testaddrange(local_settings, cyclenbr, err_data, MAX_SCycleSend, err_cnt);
		if(status != EB_OK){
			printf("\e[31mERROR during test: %s\e[0m\n",eb_status(status));
			return(-1);
		};

		// fehler ausgabe
		if(err_cnt == 0){printf("- OK -\n");}else{
			printf("\n");
			print_errors(err_data, err_cnt);
			printf("\e[31m- FAILURE -\e[0m\n");
			printf("-------------\n");
		};
	};


/*
// Test A
//-------------------------------------------------------------------------

	printf("Test A: ");

	status = eth_testA(local_settings);
	if(status != EB_OK){
		printf("ERROR during test: %s\n",eb_status(status));
		return(-1);
	}else printf("- OK -\n");


*/
	printf("\e[32m Hello World\e[0m");
	printf("\n-------------\n\n");

	// eth device schliessen
	eth_close(local_settings);



	return(0);
}

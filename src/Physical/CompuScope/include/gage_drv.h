#ifndef __GAGE_DRV_H__
#define __GAGE_DRV_H__

#if !defined(CSDRV_KERNEL) && !defined(__linux__)
#include <windows.h>
#endif

#include "CsTypes.h"

#ifndef GAGEAPI
#ifdef _WIN32
#define	GAGEAPI __stdcall
#else
#define GAGEAPI
#endif
#endif

#ifndef far
#define far
#endif


//	CompuScope driver error codes.  These values are returned in
//	the low byte of the error variable (gage_error_code).  The high
//	byte contains the number of the board that caused the error.

#define GAGE_NO_ERROR				0x00
#define GAGE_NO_SUCH_BOARD			0x01
#define GAGE_NO_SUCH_MODE			0x02
#define GAGE_NO_SUCH_INPUT			0x03
#define GAGE_INVALID_SAMPLE_RATE	0x04
#define GAGE_NO_SUCH_COUPLING		0x05
#define GAGE_NO_SUCH_CHANNEL		0x06
#define GAGE_NO_SUCH_GAIN			0x07
#define GAGE_NO_SUCH_TRIG_DEPTH		0x08
#define GAGE_NO_SUCH_TRIG_POINT		0x09
#define GAGE_NO_SUCH_TRIG_SLOPE		0x0a
#define GAGE_NO_SUCH_TRIG_SOURCE	0x0b
#define GAGE_ROOT_CONFIG_FILE_BAD	0x0c
#define GAGE_INVALID_SYSTEM_FILE	0x0d
#define GAGE_SYSTEM_FILE_NOT_FOUND	0x0e
#define GAGE_NO_SUCH_SYSTEM			0x0f
#define GAGE_NO_SUCH_IMPEDANCE		0x10
#define GAGE_NO_SUCH_DIFF_INPUT		0x11

#define GAGE_MISC_ERROR				0xff


//  CompuScope buffer size.

#define	GAGE_MAX_RAM_WINDOW			4096	/*  CompuScope area for RAM exchanges (8 bit cards).  */
#define	GAGE_16BIT_MAX_RAM_WINDOW	8192	/*  CompuScope area for RAM exchanges (16 bit cards).  */
#define	GAGE_DOUBLE_MAX_RAM_WINDOW	8192
#define	GAGE_DUAL_SHIFT_VALUE		12
#define	GAGE_DUAL_AND_VALUE			4095
#define	GAGE_SINGLE_SHIFT_VALUE		13
#define	GAGE_SINGLE_AND_VALUE		8191
#define	GAGE_DUAL_16BIT_SHIFT_VALUE		13
#define	GAGE_DUAL_16BIT_AND_VALUE		8191
#define	GAGE_SINGLE_16BIT_SHIFT_VALUE	14
#define	GAGE_SINGLE_16BIT_AND_VALUE		16383

//  CompuScope channel and mode option values.

#define	GAGE_SINGLE_CHAN		0x01	//	Mutually exclusive with GAGE_DUAL_CHAN.
#define	GAGE_DUAL_CHAN			0x02	//	Mutually exclusive with GAGE_SINGLE_CHAN.
#define	GAGE_QUAD_CHAN			0x03	//	4-byte sample	*/
#define	GAGE_MODE_EXT_CLK_ADJ	0x04	//	Can be ORed with either GAGE_DUAL_CHAN or
										//	GAGE_SINGLE_CHAN to adjust external clock
										//	trigger bits independantly of the sample
										//	rate (tbs).
#define GAGE_MODE_MULREC_ADJUST 0x08	/*	Can be ORed with either GAGE_DUAL_CHAN or
											GAGE_SINGLE_CHAN to adjust the data based
											on requirements for the multiple record
											trigger adjustment modification for the
											CS1012, CS6012, CS8012 and CS8012A.
											This will be a standard feature on
											the CS8012 and 8012A and the family
											based on this product.	*/
#define	GAGE_FAST_RAM_ADJUST	0x10	/*	Can be ORed with either GAGE_DUAL_CHAN or
											GAGE_SINGLE_CHAN to adjust the data based
											on requirements for the fast memories
											used on the V2.0 CSx012 memory board.	*/
#define	GAGE_X012X_VERS_ADJUST	0x20	/*	Can be ORed with either GAGE_DUAL_CHAN or
											GAGE_SINGLE_CHAN to adjust the data based
											on requirements for the GAL improvements
											used on the V2.0 CS8012 (et al) analog
											boards.	*/
#define	GAGE_VERSION_ADJUST		0x20	/*	Can be ORed with either GAGE_DUAL_CHAN or
											GAGE_SINGLE_CHAN to adjust the data based
											on requirements for the V1.3 CS8500 analog
											boards.	*/
#define	GAGE_X1_CLOCK_ADJUST	0x40	/*	Can be ORed with either GAGE_DUAL_CHAN or
											GAGE_SINGLE_CHAN to adjust the data based
											on clock requirements for x1 dual mode data
											acquisition.	*/
#define GAGE_CS3200_CLK_INVERT	0x80	/*  Can be ORed with GAGE_SINGLE_CHAN, GAGE_DUAL_CHAN
											or GAGE_QUAD_CHAN. When ORed the CS3200 sample clock
											used will be inverted.	*/
#define GAGE_CS82G_FORCE_GRAY	0x100	/*  Can be ORed with GAGE_SINGLE_CHAN, GAGE_DUAL_CHAN
											or GAGE_QUAD_CHAN. When ORed the CS82G will use gray code
											conversion	*/


//	CompuScope power management definitions.

#define	GAGE_POWER_OFF				0
#define	GAGE_POWER_ON				1
#define	GAGE_POWER_AUTO				2
#define	GAGE_POWER_LAST				3

#define	GAGE_POWER_ON_MASK			0x0001
#define	GAGE_POWER_AUTO_MASK		0x0002


//  CompuScope trigger source values.

#define	GAGE_CHAN_A				1
#define	GAGE_CHAN_B				2
#define	GAGE_CH_A_CH_B			3
#define	GAGE_EXTERNAL			4
#define	GAGE_SOFTWARE			5


//  CompuScope trigger delay operation values.
#define	GAGE_GET_DELAY_TIME				0
#define	GAGE_SET_DELAY_TIME				1
#define	GAGE_GET_DELAY_SAMPLES			2
#define	GAGE_SET_DELAY_SAMPLES 			3

//	CompuScope channel input source values.

#define GAGE_INPUT_ENABLE		1					/*	Use with the CS1012, CS250 and CS220.  */
#define GAGE_INPUT_DISABLE		2					/*	Use with the CS1012, CS250 and CS220.  */
#define	GAGE_INPUT_DATA			GAGE_INPUT_ENABLE	/*	Use with the CSLITE.  */
#define	GAGE_INPUT_TEST			GAGE_INPUT_DISABLE	/*	Use with the CSLITE.  */

//  CompuScope trigger type values.

#define	GAGE_DC					1
#define	GAGE_AC					2
#define GAGE_COUPLING_MASK      0x3;
#define GAGE_COUPLING_SPC       4


//  CompuScope trigger slope values.

#define	GAGE_POSITIVE			1
#define	GAGE_NEGATIVE			2

//  CompuScope trigger bandwidth values.
#define	GAGE_FULL_BW			0
#define	GAGE_HIGH_REJECT		0x20
#define	GAGE_LOW_REJECT			0x40
#define	GAGE_NOISE_REJECT		0x60
#define	GAGE_TRIG_BW_EXPAND		0xE0	// not supported, future devt
#define	GAGE_BW_MASK			0xE0

//  CompuScope trigger sensitivity values
#define	GAGE_SENSE_MASK				0xFF00
#define	GAGE_SENSE_SHIFT				8

//  CompuScope sample rate multiplier values.

#define	GAGE_HZ					1
#define	GAGE_KHZ				2
#define	GAGE_MHZ				3
#define	GAGE_GHZ				4
#define	GAGE_EXT_CLK			5
#define	GAGE_SW_CLK				6

//  CompuScope sample rate rate values.

#define	GAGE_RATE_1				1
#define	GAGE_RATE_2				2
#define	GAGE_RATE_4				4
#define	GAGE_RATE_5				5
#define	GAGE_RATE_8				8
#define	GAGE_RATE_10			10
#define	GAGE_RATE_20			20
#define	GAGE_RATE_25			25
#define	GAGE_RATE_30			30
#define	GAGE_RATE_40			40
#define	GAGE_RATE_50			50
#define	GAGE_RATE_60			60
#define	GAGE_RATE_65			65
#define	GAGE_RATE_80			80
#define	GAGE_RATE_100			100
#define	GAGE_RATE_105			105
#define	GAGE_RATE_120			120
#define	GAGE_RATE_125			125
#define	GAGE_RATE_130			130
#define	GAGE_RATE_150			150
#define GAGE_RATE_160			160
#define	GAGE_RATE_200			200
#define	GAGE_RATE_250			250
#define	GAGE_RATE_300			300
#define	GAGE_RATE_400			400
#define	GAGE_RATE_500			500
#define	GAGE_RATE_2500			2500
#define	GAGE_RATE_12500			12500


#define	GAGE_PM_10_V			0
#define	GAGE_PM_5_V				1
#define	GAGE_PM_2_V				2
#define	GAGE_PM_1_V				3
#define	GAGE_PM_500_MV			4
#define	GAGE_PM_200_MV			5
#define	GAGE_PM_100_MV			6
#define	GAGE_PM_50_MV			7
#define	GAGE_PM_50_V			8
#define	GAGE_PM_20_V			9
#define	GAGE_PM_20_MV			10
#define	GAGE_PM_10_MV			11
#define	GAGE_PM_5_MV			12


#define	GAGE_RANGE_MASK			0x000f

#define	GAGE_1_MOHM_INPUT		0
#define	GAGE_50_OHM_INPUT		0x10

#define	GAGE_DIRECT_ADC_INPUT	0x40

#define	GAGE_SINGLE_ENDED_INPUT	0
#define	GAGE_DIFFERENTIAL_INPUT	0x80
#define	GAGE_IMPED_MASK			0x0010
#define	GAGE_IMPED_INPUT_MASK	0x0010

//  Default CompuScope calibration filename.

#define	GAGE_DEFAULT_CALIB_FILENAME		"CALTABLE.DAC"

#define GAGE_MAX_RANGES			13
#define	GAGE_DAC_TABLE_SIZE		(8 * GAGE_MAX_RANGES)

//  CompuScope trigger point values.

#define	GAGE_POST_0K			0L
#define	GAGE_POST_128			128L
#define	GAGE_POST_256			256L
#define	GAGE_POST_512			512L
#define	GAGE_POST_1K			1024L
#define	GAGE_POST_2K			2048L
#define	GAGE_POST_4K			4096L
#define	GAGE_POST_8K			8192L
#define	GAGE_POST_16K			16384L
#define	GAGE_POST_32K			32768L
#define	GAGE_POST_64K			65536L
#define	GAGE_POST_128K			131072L
#define	GAGE_POST_256K			262144L
#define	GAGE_POST_512K			524288L
#define	GAGE_POST_1M			1048576L
#define	GAGE_POST_2M			2097152L
#define	GAGE_POST_4M			4194304L
#define	GAGE_POST_8M			8388608L
#define	GAGE_POST_16M			16777216L

#define	GAGE_ASSUME_NOTHING		0x0000


#define	GAGE_ASSUME_CS265		0x0001
#define	GAGE_ASSUME_CS8500		0x0002
#define	GAGE_ASSUME_CS8012_TYPE	0x0004
#define	GAGE_ASSUME_CS8012		0x0008
#define	GAGE_ASSUME_CSPCI		0x0010
#define	GAGE_ASSUME_CS512		0x0020
#define	GAGE_ASSUME_CS225		0x0040
#define	GAGE_ASSUME_CSLITE11	0x0100
#define	GAGE_ASSUME_CS220		0x0200
#define	GAGE_ASSUME_CS250		0x0400
#define	GAGE_ASSUME_CSLITE		0x0800
#define	GAGE_ASSUME_CSLITE15	0x0800
#define	GAGE_ASSUME_CS1012		0x1000
#define	GAGE_ASSUME_CS6012		0x2000
#define	GAGE_ASSUME_CS2125		0x4000
#define	GAGE_ASSUME_CS1016		0x8000

#define GAGE_ASSUME_CS85G		(GAGE_ASSUME_CS8500 | 0x0001)                                       //0x0003 
#define	GAGE_ASSUME_CS82G		(GAGE_ASSUME_CS8500 | 0x0080)                                       //0x0082
#define GAGE_ASSUME_CS14200		(GAGE_ASSUME_CS8500 | 0x0800)                                       //0x0802
#define GAGE_ASSUME_CS14105		(GAGE_ASSUME_CS8500 | 0x0400)                                       //0x0402
#define GAGE_ASSUME_CS12400		(GAGE_ASSUME_CS8500 | 0x0200)                                       //0x0202
#define GAGE_ASSUME_RAZOR		(GAGE_ASSUME_CS8500 | GAGE_ASSUME_CS512)
#define	GAGE_ASSUME_CS3200		(GAGE_ASSUME_CS8500 | 0x0100)                                       //0x0102
#define	GAGE_ASSUME_CS12100		(GAGE_ASSUME_CS8500 | GAGE_ASSUME_CS8012_TYPE | GAGE_ASSUME_CS8012) //0x000E
#define	GAGE_ASSUME_CS14100		(GAGE_ASSUME_CS8500 | GAGE_ASSUME_CS8012_TYPE | GAGE_ASSUME_CS1012) //0x1006
#define	GAGE_ASSUME_CS1610		(GAGE_ASSUME_CS8500 | GAGE_ASSUME_CS8012_TYPE | GAGE_ASSUME_CS1016) //0x8006
#define	GAGE_ASSUME_ALL_BOARDS	(GAGE_ASSUME_CS265		| GAGE_ASSUME_CS8500		| \
								 GAGE_ASSUME_CS8012		| GAGE_ASSUME_CSPCI			| \
								 GAGE_ASSUME_CS512		| GAGE_ASSUME_CS225			| \
								 GAGE_ASSUME_CS82G		| GAGE_ASSUME_CS3200		| \
								 GAGE_ASSUME_CS220		| GAGE_ASSUME_CS250			| \
								 GAGE_ASSUME_CSLITE		| GAGE_ASSUME_CS1012		| \
								 GAGE_ASSUME_CS6012		| GAGE_ASSUME_CS2125		| \
								 GAGE_ASSUME_CS1016		| GAGE_ASSUME_CS8012_TYPE	| \
								 GAGE_ASSUME_CS12100	| GAGE_ASSUME_CS12130		| \
								 GAGE_ASSUME_CS14100	| GAGE_ASSUME_CS1610		)


#define	GAGE_ASSUME_CS25018		GAGE_ASSUME_CS250

#define	GAGE_B_L_MAX_CARDS		16
#define	GAGE_B_L_SIZEOF_ELEMENT	2
#define	GAGE_B_L_ELEMENT_SIZE	2
#define	GAGE_B_L_STATUS_SIZE	2
#define	GAGE_B_L_STATUS_START	(GAGE_B_L_MAX_CARDS * GAGE_B_L_ELEMENT_SIZE)
#define	GAGE_B_L_BUFFER_SIZE	(GAGE_B_L_MAX_CARDS * (GAGE_B_L_ELEMENT_SIZE + GAGE_B_L_STATUS_SIZE))


//  CompuScope definitions for memory test override values.

#define	GAGE_MEMORY_DEFAULT		((uInt16)(-1))
#define	GAGE_MEMORY_SIZE_TEST	0
#define	GAGE_MEMORY_SIZE_016K	16
#define	GAGE_MEMORY_SIZE_032K	32
#define	GAGE_MEMORY_SIZE_064K	64
#define	GAGE_MEMORY_SIZE_128K	128
#define	GAGE_MEMORY_SIZE_256K	256
#define	GAGE_MEMORY_SIZE_512K	512
#define	GAGE_MEMORY_SIZE_001M	1024
#define	GAGE_MEMORY_SIZE_002M	2048
#define	GAGE_MEMORY_SIZE_004M	4096
#define	GAGE_MEMORY_SIZE_008M	8192
#define	GAGE_MEMORY_SIZE_016M	16384


//  Definitions for gage_board_type_size_to_text.

#define	GAGE_GBTSTT_STR_SZ			30

#define	GAGE_GBTSTT_BOARD			0x01
#define	GAGE_GBTSTT_MEMORY			0x02
#define	GAGE_GBTSTT_BOTH			0x03
#define	GAGE_GBTSTT_LONG_NAME		0x04
#define	GAGE_GBTSTT_ALL_UPPER_CASE	0x08

//**********************************************************
//
//	CompuScope specific definitions that need global scope.
//
//**********************************************************

//	CompuScope 32 bit cards.
//	========================

#define	GAGE_UNSIGN_32_BIT_SAMPLE_OFFSET		0x7FFFFFFF
#define	GAGE_32_BIT_SAMPLE_OFFSET				-1
#define	GAGE_32_BIT_SAMPLE_RESOLUTION			2147483648U
#define	GAGE_32_BIT_SAMPLE_BITS					32

//	CompuScope 16 bit cards.
//	========================

#define	GAGE_UNSIGN_16_BIT_SAMPLE_OFFSET		0x7FFF
#define	GAGE_16_BIT_SAMPLE_OFFSET				-1
#define	GAGE_16_BIT_SAMPLE_RESOLUTION			32768U
#define	GAGE_16_BIT_SAMPLE_BITS					16

//	CompuScope 14 bit cards.
//	========================

#define	GAGE_UNSIGN_14_BIT_SAMPLE_OFFSET		0x1FFF
#define	GAGE_14_BIT_SAMPLE_OFFSET				-1
#define	GAGE_14_BIT_SAMPLE_RESOLUTION			8192
#define	GAGE_14_BIT_SAMPLE_BITS					14


//	CompuScope 12 bit cards.
//	========================

#define	GAGE_UNSIGN_12_BIT_SAMPLE_OFFSET		0x7FF
#define	GAGE_12_BIT_SAMPLE_OFFSET				-1
#define	GAGE_12_BIT_SAMPLE_RESOLUTION			2048
#define	GAGE_12_BIT_SAMPLE_BITS					12

//cs1220 has only 7/8 of the codes
#define CS1220_SAMPLE_RESOLUTION 				1792


//	CompuScope 8 bit cards.
//	=======================

#define	GAGE_8_BIT_SAMPLE_OFFSET				127
#define	GAGE_8_BIT_SAMPLE_RESOLUTION			128
#define	GAGE_8_BIT_SAMPLE_BITS					8


//	CompuScope EEPROM options encoding definitions.

#define EEPROM_OPTIONS_MULTIPLE_REC		0x00000001L
#define EEPROM_OPTIONS_MASTER			0x00000002L
#define EEPROM_OPTIONS_SLAVE			0x00000004L
#define EEPROM_OPTIONS_ONE_CH_ONLY		0x00000008L
#define EEPROM_OPTIONS_TWO_CH_ONLY		0x00000010L
#define EEPROM_OPTIONS_NORMAL_OSC		0x00000020L
#define EEPROM_OPTIONS_MINMAX			0x00000040L
#define EEPROM_OPTIONS_INDEPEND_TRIG	0x00000080L
#define EEPROM_OPTIONS_PRE_TRIGGER		0x00000100L
#define EEPROM_OPTIONS_GATED_CAPTURE	0x00000200L
#define EEPROM_OPTIONS_SOFTWARE_CLOCK	0x00000400L
#define EEPROM_OPTIONS_EXTERNAL_CLOCK	0x00000800L
#define EEPROM_OPTIONS_ETS				0x00001000L
#define EEPROM_OPTIONS_CALIBRATED_DUAL	0x00002000L
#define EEPROM_OPTIONS_MULREC_ADJUST	0x00004000L
#define EEPROM_OPTIONS_DIRECT_INPUT		0x00008000L
#define EEPROM_OPTIONS_MULREC_COUNT		0x00010000L
#define EEPROM_OPTIONS_X1_CLOCK			0x00020000L
#define EEPROM_OPTIONS_DIM_SELECT_0		0x00040000L
#define EEPROM_OPTIONS_DIM_SELECT_1		0x00080000L
#define EEPROM_OPTIONS_DISABLE_CHANTRIG	0x00100000L
#define EEPROM_OPTIONS_EIB_CAPABLE		0x00200000L
#define EEPROM_OPTIONS_SPECIAL_MULREC	0x00400000L
#define EEPROM_OPTIONS_ALTERNATE_CONFIG	0x00800000L
#define EEPROM_OPTIONS_SINGLE_CALTABLE	0x01000000L
#define EEPROM_OPTIONS_DUAL_CALTABLE	0x02000000L
#define EEPROM_OPTIONS_ACTIVE_BRIDGE	0x04000000L
#define EEPROM_OPTIONS_PCI_MEMORY_ONLY	0x08000000L
#define EEPROM_OPTIONS_POSITION_CONTROL	0x10000000L
#define EEPROM_OPTIONS_UNDEFINED_B_29	0x20000000L
#define EEPROM_OPTIONS_CPCI_CARD		0x40000000L
#define EEPROM_OPTIONS_EXTENDED			0x80000000L

#define EEPROM_OPTIONS_DIM_NONE			0x00000000L
#define EEPROM_OPTIONS_DIM_8			0x00040000L
#define EEPROM_OPTIONS_DIM_12_24		0x00080000L
#define EEPROM_OPTIONS_DIM_32			0x000c0000L
#define EEPROM_OPTIONS_DIM_MASK			0x000c0000L

#define	EEPROM_VERSION_CS16XX_ESR		0x0001
#define	EEPROM_VERSION_CS16XX_EDC		0x0002
#define	EEPROM_VERSION_CS16XX_EIR		0x0004

#define	EEPROM_VERSION_CS12XX0_ESR		0x0001
#define	EEPROM_VERSION_CS12XX0_EDC		0x0002

/*	redefinition of this value for Razor boards */
#define EEPROM_OPTIONS_200_MHZ			0x08000000L	/*	Only applies Splenda (Razor) boards.	*/

//Definitions of the type of events used in low level driver
#define	GAGE_EVENT_GPIB_REPC_CAPTURE_SAVED	0
#define GAGE_EVENT_GPIB_REPC_ACQ_THREAD_END 1


//////////////////////////////////////////
//										//
//	Global variables and structures.	//
//										//
//////////////////////////////////////////

#ifdef WIN32
#pragma pack (4)
#endif //_WIN32
typedef struct
{
	uInt16		index;
	uInt16		segment;
	uInt16		board_type;
	uInt32		max_memory;
	uInt32		max_available_memory;
	uInt16		bank_offset_value;
	int16		mode;
	int16		enable_a;
	int16		enable_b;
	int16		rate;
	int16		multiplier;
	int16		coupling_a;
	int16		coupling_b;
	int16		coupling_ext;
	int16		gain_a;
	int16		gain_b;
	int16		gain_ext;
	int32		trigger_depth;
	int16		trigger_level;
	int16		trigger_slope;
	int16		trigger_source;
	int16		trigger_res;
	int16		multiple_recording;
	int16		sample_offset;
	uInt16		sample_resolution;
	int16		sample_bits;
	uInt16		external_clock_delay;
	float		external_clock_rate;
	float		sample_rate;
	void far	*memptr;
	int16		trigger_level_2;
	int16		trigger_slope_2;
	int16		trigger_source_2;
	int16		imped_a;
	int16		imped_b;
	uInt16		external_clock_adjust;
	int16		trigger_step;
	uInt16		board_version;
	uInt32		ee_options;
	uInt16		index_offset;
	int32		sample_offset_32;
	int32		sample_resolution_32;
	int16		diff_input_a;
	int16		diff_input_b;
	uInt32		multiple_record_count;
	uInt32		real_time_active;
	int16 		trigger_enable_control;

	// Compuscope Cs82G
	int16		trigger_sensitivity;
	int16		trigger_bandwidth;
	int16		trigger_sensitivity_2;
	int16		trigger_bandwidth_2;
	uInt16		max_trigger_sensitivity;
	uInt16		trigger_address_offset;
	uInt16		user_buffer_padding;
	int16		bus_master_support;
	//Retrofit 
	int16		i16RealSampleBits;
} gage_driver_info_type;


#ifdef WIN32
#pragma pack ()
#endif //_WIN32


// Related to the TMB Data Structures	*/

#define TMB_NUM_OF_REGISTERS       	17

// For the board information

typedef struct TriggerMarkerBoard
{
	uInt16 version;						// board version
	uInt16 baseIO;						// Base I/O Address
	uInt16 irq;							// Interrupt Request
	uInt32 mem_size;					// memory size in 40 bit "time samples"
	uInt16 WrReg[TMB_NUM_OF_REGISTERS]; // store read registers values..if needed
	uInt16 RdReg[TMB_NUM_OF_REGISTERS]; // store write registers values..if needed
}
 TRGMBOARD, *PtrTrgMBoard;

// Related to the Data

typedef struct tmb_event_words
{
	uInt16 lword;	// low word of the event data
	uInt16 mword;   // middle word of the event data
	uInt16 hword;   // high word of the event data
	uInt16 padding;	// extra bits to make overall size 64 bits
} TMB_EVENT_WORDS, *PtrEventWords;


typedef struct tmb_event_dwords
{
 uInt32 ldword;		// low double word of the event data
 uInt32 hdword;     // high double word of the event data
} TMB_EVENT_DWORDS, *PtrEventDwords;


typedef union tmb_data{
 TMB_EVENT_WORDS  words;	   // the event data are stored as words
 TMB_EVENT_DWORDS dwords;      // the event data are stored as double words
} TMB_DATA, *PtrData;



#define GAGE_MODE_MULREC_ADJUST 0x08	//	Can be ORed with either GAGE_DUAL_CHAN or
										//GAGE_SINGLE_CHAN to adjust the data based
										//on requirements for the multiple record
										//trigger adjustment modification for the
										//CS1012, CS6012, CS8012 and CS8012A.
										//This will be a standard feature on
										//the CS8012 and 8012A and the family
										//based on this product.

#define	GAGE_FAST_RAM_ADJUST	0x10	//Can be ORed with either GAGE_DUAL_CHAN or
										//GAGE_SINGLE_CHAN to adjust the data based
										//on requirements for the fast memories
										//used on the V2.0 CSx012 memory board.

#define	GAGE_X012X_VERS_ADJUST	0x20	//Can be ORed with either GAGE_DUAL_CHAN or
										//GAGE_SINGLE_CHAN to adjust the data based
										//on requirements for the GAL improvements
										//used on the V2.0 CS8012 (et al) analog
										//boards.

#define	GAGE_VERSION_ADJUST		0x20	//Can be ORed with either GAGE_DUAL_CHAN or
										//GAGE_SINGLE_CHAN to adjust the data based
										//on requirements for the V1.3 CS8500 analog
										//boards.
#define	GAGE_X1_CLOCK_ADJUST	0x40	//Can be ORed with GAGE_DUAL_CHAN


#define	GAGE_MODE_MULREC		0x01
#define GAGE_MODE_85_MEM_TEST	0x1000
#define GAGE_MODE_85_REAL_TIME	0x2000
#define GAGE_MODE_REAL_TIME		0x2000
#define GAGE_MODE_85_PRETRIG	0x4000
#define GAGE_MODE_85_PTM		(GAGE_MODE_85_PRETRIG | GAGE_SINGLE_CHAN)


#define	GAGE_MODE_OPTIONS		(GAGE_MODE_EXT_CLK_ADJ | GAGE_MODE_MULREC_ADJUST | GAGE_FAST_RAM_ADJUST | GAGE_X012X_VERS_ADJUST | GAGE_X1_CLOCK_ADJUST | GAGE_MODE_REAL_TIME)

#define PRETRIG_DELAY_14100			(64)
#define EXT_CLK_TRIG_OFFSET_14100	(20)


#define	CS12100_TRIGGER_STEP_SIZE		6		//  Size is 64 = 2**6.
#define	CS12100_TRIGGER_RES				64

#define	GAGE_GSTT_STR_SZ			128
#define	GAGE_GBTSTT_STR_SZ			30

#define	GAGE_GBTSTT_BOARD			0x01
#define	GAGE_GBTSTT_MEMORY			0x02
#define	GAGE_GBTSTT_BOTH			0x03
#define	GAGE_GBTSTT_LONG_NAME		0x04
#define	GAGE_GBTSTT_ALL_UPPER_CASE	0x08


#define	GAGE_BAD_LSB_SEGMENT			0x0001
#define	GAGE_BAD_MSB_SEGMENT			0x0002
#define	GAGE_BAD_LSB_INDEX				0x0004
#define	GAGE_BAD_MSB_INDEX				0x0008
#define	GAGE_DETECT_FAILED				0x0010
#define	GAGE_MEMORY_FAILED				0x0020
#define GAGE_BAD_MEMORY_SIZE			0x0040
#define	GAGE_ALLOC_FAILED				0x0080
#define	GAGE_PCI_MEM_EXPECTED			0x0100
#define	GAGE_PCI_MEM_LINK_FAILED		0x0200


#define GAGE_RT_ENABLE					1L
#define GAGE_RT_DISABLE					-1L




/*	Global MACRO routines.
	----------------------	*/

#define	GAGE_PTM_IN_USE(multiple_record)		((uInt16)(multiple_record) > 1)
#define	GAGE_PTM_RECORD_SIZE(multiple_record)	(1L << ((uInt32)(((multiple_record >> 8) + 1) & 0xff)))

/*----------------------------------------------------------*/

#ifndef CSDRV_KERNEL

#ifdef	__cplusplus

extern "C"	{

#endif

//----------------------------------------------------------

//	Routines to initialize the driver and CompuScope and select which
//	CompuScope to control.

int16 GAGEAPI	gage_get_config_filename (LPSTR cfgfn);
int16 GAGEAPI	gage_read_config_file (LPSTR filename, uInt16 far *records);
int16 GAGEAPI	gage_set_records (uInt16 far *records, int16 record, uInt16 segment, uInt16 index, uInt16 type_name, uInt16 status);
int16 GAGEAPI	gage_get_records (uInt16 far *records, int16 record, uInt16 far *segment, uInt16 far *index, uInt16 far *b_typename, uInt16 far *status);
int16 GAGEAPI	gage_driver_initialize (uInt16 far *records, uInt16 memory);
void  GAGEAPI	gage_driver_remove (void);
int16 GAGEAPI	gage_select_board (int16 board);
int16 GAGEAPI	gage_get_error_code(void);
int16 GAGEAPI	gage_get_boards_found(void);
void  GAGEAPI	gage_start_capture (int16 auto_trigger);
void  GAGEAPI	gage_abort_capture (int16 reset_trigger_source);
void  GAGEAPI	gage_force_capture (int16 reset_trigger_source);
int32 GAGEAPI	gage_normalize_address (int32 start, int32 address, int32 ram_size);

void  GAGEAPI	gage_calculate_addresses (int16 chan, int16 op_mode, float tbs, int32 far *trig, int32 far *start, int32 far *end);
int32 GAGEAPI	gage_calculate_mr_addresses (int32 group, int16 board_type, int32 depth, int32 memory, int16 chan, int16 op_mode, float tbs, int32 far *trig, int32 far *start, int32 far *end);
int32 GAGEAPI	gage_calculate_mra_addresses (int16 board_type, uInt16 version, int16 chan, int16 op_mode, float tbs, int32 far *trig, int32 far *start, int32 far *end, int16 data);


//	Remember that ALL of the following routines work with the current
//	selected board, as determined by "gage_select_board".

//	Routines that configure a CompuScope board for the desired mode of
//	operation and with the desired parameters.

int16 GAGEAPI	gage_capture_mode (int16 mode, int16 rate, int16 multiplier);
int16 GAGEAPI	gage_input_control (int16 channel, int16 enable, int16 coupling, int16 gain);
int16 GAGEAPI	gage_trigger_control_2 (int16 source_1, int16 source_2, int16 ext_coupling, int16 ext_gain, int16 slope_1, int16 slope_2, int16 level_1, int16 level_2, int32 depth, int16 trigger_from_bus, int16 trigger_to_bus);
int16 GAGEAPI	gage_trigger_control (int16 source, int16 ext_coupling, int16 ext_gain, int16 slope, int16 level, int32 depth);

//	Routines that allow control over the CompuScope disabling and
//	enabling data capturing, reading internal memory buffers and also
//	getting the trigger addresses in the CompuScope to allow for
//	repetious capture of signals.

void  GAGEAPI	gage_abort (void);
void  GAGEAPI	gage_need_ram (int16 need);
int16 GAGEAPI	gage_mem_read_master (int32 location);

//	Routines that, under software control, activate normally automatic
//	functions within the CompuScope for starting and performing data
//	capture.
void  GAGEAPI	gage_software_trigger (void);

//	Routines to read back various control signals generated by the
//	CompuScope to provide the application writer feedback from
//	the current boards's operational state.

int16 GAGEAPI	gage_busy (void);
int16 GAGEAPI	gage_triggered (void);
int16 GAGEAPI	gage_read_master_status (void);


LPSTR GAGEAPI	gage_board_type_size_to_text (LPSTR string, uInt32 string_size, uInt32 action, uInt32 board, uInt32 far *bt, uInt32 far *eeopt, uInt32 far *ver, uInt32 far *max_mem);
void  GAGEAPI	gage_get_driver_info (gage_driver_info_type far *gdi);



//	Global routines: group two, for application program use.
//	--------------------------------------------------------

//	Routines that control how the memory buffers are accessed and located.

int16 GAGEAPI	gage_mem_read_chan_a (int32 location);
int16 GAGEAPI	gage_mem_read_chan_b (int32 location);
int16 GAGEAPI	gage_mem_read_single (int32 location);
void  GAGEAPI	gage_transfer_buffer (int32 ta, int16 channel, void far *buffer, int32 nsamples);
void far* GAGEAPI gage_transfer_buffer_2 (int32 ta, int16 channel, void far *buffer, int32 nsamples);
uInt32 GAGEAPI  gage_transfer_buffer_3 (int32 ta, int16 channel, void far *buffer, int32 nsamples);

//	Routines that handle miscellaneous functionality.

void  GAGEAPI	gage_multiple_record (uInt16 mode);
int16 GAGEAPI	gage_power_control (int16 mode);
int16 GAGEAPI	gage_detect_multiple_record (void);
uInt32 GAGEAPI	gage_multiple_record_acquisitions_32 (uInt32 number);


void  GAGEAPI	gage_get_driver_info_structure (uInt16 far *major_version, uInt16 far *minor_version, uInt16 far *board_support,
						gage_driver_info_type far * far * gdi, int32 far *gdi_size);


void  GAGEAPI	gage_set_ext_clock_variables (int16 op_mode, uInt16 external_clock_delay, float external_clock_rate);

void  GAGEAPI	gage_offset_adjust (int16 channel, int16 offset_adjust);

//	Global routines: Special routines control Multiple Independant Operation.
//	-------------------------------------------------------------------------

int16 GAGEAPI	gage_get_independant_operation (void);
void  GAGEAPI	gage_set_independant_operation (int16 independant);

void  GAGEAPI	gage_board_start_capture (int16 mi_board, int16 auto_trigger);
void  GAGEAPI	gage_board_abort_capture (int16 mi_board);
void  GAGEAPI	gage_board_force_capture (int16 mi_board);


//	Global routines: Special routines for extra functionality.
//	----------------------------------------------------------
uInt32 GAGEAPI	gage_delay_trigger_32 (int16 action, uInt32* DelayLow,uInt32* DelayHigh);
int16  GAGEAPI	gage_ets_detect (void);
void   GAGEAPI	gage_get_data (void);
int32  GAGEAPI	gage_gpib_command (char* strCommand, int nByteSize, char* rvBuffer, int nBufferSize);
void   GAGEAPI	gage_init_clock (void);
void   GAGEAPI	gage_initialize_start_capture (int16 hardware_to_use);

void   GAGEAPI	gage_multiple_record_acquisitions (uInt16 number);
uInt16 GAGEAPI	gage_set_delay_trigger (int16 action, uInt16 delay_trigger);
int32  GAGEAPI  gage_trigger_address (void);
int16  GAGEAPI  gage_use_cal_table (int16 action);
int16 GAGEAPI	gage_read_cal_table (LPSTR caltable_name);

uInt32 GAGEAPI	gage_direct_entry ( uInt32 Param1, uInt32 Param2, void *ptr);

void   GAGEAPI  tmb_set_default_board( PtrTrgMBoard board );
void   GAGEAPI  tmb_get_board_info (PtrTrgMBoard board );
void   GAGEAPI  tmb_init_board( PtrTrgMBoard board );
void   GAGEAPI  tmb_enable_operation ( PtrTrgMBoard board );
void   GAGEAPI  tmb_disable_operation( PtrTrgMBoard board );
void   GAGEAPI  tmb_write_board_memory( PtrTrgMBoard board, uInt32 address, PtrData data);
void   GAGEAPI  tmb_read_board_memory( PtrTrgMBoard board, uInt32 address, PtrData data);
void   GAGEAPI  tmb_write_tc( PtrTrgMBoard board, PtrData data );
void   GAGEAPI  tmb_write_control_reg( PtrTrgMBoard board, uInt16 control_word );
void   GAGEAPI  tmb_set_index_event_polarity( PtrTrgMBoard board, uInt16 IndexPolarity, uInt16 EventPolarity);
void   GAGEAPI  tmb_read_index_value( PtrTrgMBoard board, PtrData data );
void   GAGEAPI  tmb_read_event_count( PtrTrgMBoard board, uInt32* event_count);
void   GAGEAPI  tmb_read_status_reg( PtrTrgMBoard board, uInt32* status);
int32  GAGEAPI  tmb_transfer(PtrTrgMBoard board, void* buffer, uInt32 bufsize, uInt32 flag );
uInt32 GAGEAPI  tmb_verify_memory_size(PtrTrgMBoard board);

#ifdef _WIN32
// RG routines added just to get CS_TEST.EXE to work
void  GAGEAPI	gage_set_trigger_view_offset (int32 offset);
void  GAGEAPI	gage_trigger_view_transfer (int16 channel, uInt8 far *buffer, int16 nsamples);
void  GAGEAPI gage_trigger_view_transfer_2 (int16 channel, void far *buffer, int32 nsamples);
uInt32 GAGEAPI  gage_trigger_view_transfer_3 (int16 channel, void far *buffer, int32 nsamples);
uInt32 GAGEAPI   gage_rt_mode( uInt32 realtime_mode );
LPSTR GAGEAPI	gage_support_to_text (LPSTR string, uInt32 string_size, uInt16 board_support);
// end of CS_TEST FUNCTIONS	
#endif


#define TMB_INDEX_RISING_EDGE   0x0001
#define TMB_INDEX_FALLING_EDGE  0x0000
#define TMB_EVENT_RISING_EDGE   0x0002
#define TMB_EVENT_FALLING_EDGE  0x0000

#define TMB_FLAG				0x00000001L
#define TMB_STATUS				0x00000002L
#define TMB_EVENT_COUNT			0x00000004L
#define TMB_FIRST_EVENT			0x00000008L
#define TMB_LAST_EVENT			0x00000010L
#define TMB_INDEX_VALUE			0x00000020L
#define TMB_EVENTS				0x00000040L
#define TMB_GET_EVENT			0x00000080L
#define TMB_EVENT_SIZE_32		0x10000000L
#define TMB_EVENT_SIZE_64		0x20000000L
#define TMB_CLEAR        		0x40000000L
#define TMB_INITIALIZE      	0x80000000L
#define TMB_INITIALIZE_CLEAR	(TMB_CLEAR | TMB_INITIALIZE)


#ifdef	__cplusplus

}

#endif

#endif // CSDRV_KERNEL

#endif //__GAGE_DRV_H__

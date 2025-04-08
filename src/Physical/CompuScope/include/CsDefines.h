
#ifndef __CS_DEFINES_H__
#define __CS_DEFINES_H__

//!
//! \defgroup ALL_DEFINES CompuScope Defines
//! \{
//!
//! \}

//!
//! \defgroup ACQUISITION_MODES Acquisition Modes
//! \ingroup ALL_DEFINES
//! \{
//! \sa CSACQUISITIONCONFIG

#define CS_MODE_SINGLE			0x1		//!< \brief Single channel acquisition
//!<
//!< Switch to single channel mode. One channel per board

#define	CS_MODE_DUAL			0x2     //!< \brief Dual channel acquisition
//!<
//!< Switch to dual channel mode. Two channels per board

#define CS_MODE_QUAD			0x4     //!< \brief Four channel acquisition
//!<
//!< Switch to quad channel mode. Four channels per board

#define CS_MODE_OCT     		0x8     //!< \brief Eight channel acquisition
//!<
//!< Switch to octal channel mode. Eight channels per board

#define CS_MASKED_MODE			0x0000000f // < \brief Mask to use when determining operating mode

#define CS_MODE_RESERVED			0x10	// < Reserved
#define CS_MODE_EXPERT_HISTOGRAM	0x20    // < Expert Histogram (Cobra PCI only)
#define CS_MODE_SINGLE_CHANNEL2		0x40    // < Capture in Single Channel mode with channel 2 (Cobra & CobraMax PCI-E only)
//!<
//!< Activate the Histogram features on Cobra PCI

#define CS_MODE_POWER_ON		0x80	//!< \brief Disable power saving mode
//!<
//!< Disable power saving feature to increase capture repeat rate.

#define CS_MODE_REFERENCE_CLK		0x400	//!< \brief Use 10 MHz reference clock
//!<
//!< Use signal connected to the external clock as reference clock to synchronize internal oscillator

#define	CS_MODE_CS3200_CLK_INVERT 0x800 //!< \brief Use falling edge of the clock on CS3200 and CS3200C
//!<
//!< CS3200 and CS3200C only. Use falling edge of the clock to latch data.

//!
//! \}
// ACQUISITION_MODES
// *****************************************************************************

//!
//! \defgroup TIMESTAMPS_MODES Time-stamp Modes
//! \ingroup ALL_DEFINES
//! \{
//! \sa CSACQUISITIONCONFIG

#define	TIMESTAMP_DEFAULT		TIMESTAMP_GCLK|TIMESTAMP_FREERUN

#define	TIMESTAMP_GCLK			0x0		//!< \brief Use sample clock based frequency for time-stamp counter source
//!<
//!< Use sample clock based frequency for time-stamp counter source


#define	TIMESTAMP_MCLK			0x1		//!< \brief Use fixed on-board oscillator for time-stamp counter source
//!<
//!< Use fixed on-board oscillator for time-stamp counter source

#define	TIMESTAMP_SEG_RESET		0x0		//!< \brief Reset time-stamp counter on capture start
//!<
//!< Reset time-stamp counter upon start of the acquisition

#define	TIMESTAMP_FREERUN		0x10    //!< \brief Manual reset of time-stamp counter.
//!<
//!< Time-stamp counter will be reset only by CsDo(ACTION_TIMESTAMP_RESET) call.

//! \}
// TIMESTAMPS_MODES
// *****************************************************************************

//!
//! \defgroup TRANSFER_MODES Data transfer modes
//! \ingroup ALL_DEFINES
//! \{
//! \sa CsTransfer

//
#define	TxMODE_DEFAULT			TxMODE_DATA_ANALOGONLY

//! \brief PCI Slave mode transfer. (PCI bus-mastering transfer is otherwise used)
//!
//! PCI Slave mode transfer used for troubleshooting.
#define	TxMODE_SLAVE			0x80000000

//! \brief Transfer unformatted data (raw data format)
//!
//! Transfer data in raw data format with timestamp	(single channel)
#define	TxMODE_MULTISEGMENTS	0x40000000	

//! \brief Transfer unformatted data (raw data format)
//!
//! Transfer data in raw data format with timestamp (all channels)
#define	TxMODE_RAW_DATA			0x20000000


//! \brief Transfer only Analog data
//!
//! Transfer only Analog data.
//! (Do not transfer digital input bit data, which are optionally available on certain CompuScope models)
#define TxMODE_DATA_ANALOGONLY  0x00

#define	TxMODE_DATA_FLOAT		0x01		// < Transfer data in floating point format

//! \brief Transfer time-stamp information
//!
//! Transfer time-stamp information and time-stamp clock frequency.
//! For CompuScope models that support the time-stamping of data.
#define	TxMODE_TIMESTAMP		0x02

//! \brief Transfer all data
//!
//! Transfer all data bits including digital input bits.
//! (Digital input bits are optionally available on certain CompuScope models)
#define	TxMODE_DATA_16			0x04

//! \brief Transfer only digital input bits
//!
//! Transfer only digital input bits. (Digital input bits are optionally available on certain CompuScope models)
#define	TxMODE_DATA_ONLYDIGITAL	0x08

//! \brief Transfer data as 32-bit samples
//!
//! Transfer data as 32 bit samples
#define	TxMODE_DATA_32			0x10

//! \brief Transfer data in FFT format
//!
//! Transfer data in FFT format. Should be use only with eXpert FFT firmware.
#define	TxMODE_DATA_FFT			0x30

//! \brief Transfer data in interleaved format
//!
//! Transfer data in interleaved format. 
#define	TxMODE_DATA_INTERLEAVED		0x40

//! \brief Transfer segment tail
//!
//! Transfer segment tail in raw data format. The tail contains some information such as trigger \link CSSEGMENTTAIL timestamp \endlink.
#define	TxMODE_SEGMENT_TAIL			0x80

//! \brief Transfer Histogram
//!
//! Transfer histogram data (Cobra PCI only). Should be use only with Expert Histogram
#define	TxMODE_HISTOGRAM			0x100

//! \brief Transfer data as 64-bit samples
//!
//! Transfer data as 64 bit samples
#define	TxMODE_DATA_64			0x200

//! \brief Transfer data as 64-bit samples
//!
//! Transfer data as 64 bit samples
#define	TxMODE_DEBUG_DISP			0x10000000

//! \}
// TRANSFER_MODES
// *****************************************************************************

//!
//! \defgroup TRANSFER_DATA_FORMAT Data transfer formats
//! \ingroup ALL_DEFINES
//! \{
//! Available data formats when using CsTransferEx()
//!

//! \brief Octal interleaved
//!
//! Data format for interleaved data in octal channel mode (8 channel boards)
#define TxFORMAT_OCTAL_INTERLEAVED			0x12345678

//! \brief Quad interleaved
//!
//! Data format for interleaved data in quad channel mode (4 channel boards)
#define	TxFORMAT_QUAD_INTERLEAVED			0x11223344

//! \brief Combine dual interleaved
//!
//! Data format for interleaved data in dual channel mode (Cobra and Razor  boards)
#define	TxFORMAT_COBRA_DUAL_INTERLEAVED		0x11112222

//! \brief Dual interleaved
//!
//! Data format for interleaved data in dual channel mode 
#define	TxFORMAT_DUAL_INTERLEAVED			0x11221122


//! \brief Non-interleaved
//!
//! Data format for non-interleaved data
#define	TxFORMAT_NON_INTERLEAVED			0x11111111

//! \brief Single channel
//!
//! Data format for data in single channel mode 
#define TxFORMAT_SINGLE						0x11111111

//! \brief Stacked mode
//!
//! Data format for stacked channels (all of Ch1, then all Ch2, etc. CsUsb devices)
#define	TxFORMAT_STACKED					0x7fffffff

//! \}
// TRANSFER_DATA_FORMATS
// *****************************************************************************


//!
//! \defgroup CHAN_DEFS Channel Constants
//! \ingroup ALL_DEFINES
//! \{
//! \sa CSCHANNELCONFIG

//! \brief Channel index
//!
//! Channel index. Indexing starts at 1 and spans the whole CompuScope system.
//! Channel index is constant and does not depend on Acquisition mode.
#define CS_CHAN_1	1
#define CS_CHAN_2	2

#define CS_FILTER_OFF  0
#define CS_FILTER_ON   1

//! \brief DC coupling
//!
//! DC coupling
#define	CS_COUPLING_DC				0x1

//! \brief AC coupling
//!
//! AC coupling
#define	CS_COUPLING_AC				0x2

#define	CS_COUPLING_MASK			0x3

//! \brief Differential input 
//!
//! Differential input (default is Single-ended input)
#define CS_DIFFERENTIAL_INPUT		0x4

//! \brief Direct-to-ADC input
//!
//! Direct-to-ADC input
#define CS_DIRECT_ADC_INPUT			0x8

//! \brief 1 MOhm impedance
//!
//! Front end 1 MOhm impedance. 
//! This constant is also used to indicate HiZ External trigger impedance.
#define CS_REAL_IMP_1M_OHM		1000000	
//! \brief 50 Ohm impedance
//!
//! Front end 50 Ohm impedance. 
#define CS_REAL_IMP_50_OHM		50


//! \brief 1 KOhm impedance
//!
//! Front end 1 KOhm impedance. 
#define CS_REAL_IMP_1K_OHM		1000

//! \brief 100 Volt pk-pk input range
//!
//! 100 Volt peak-peak input range
#define	CS_GAIN_100_V		100000


//! \brief 40 Volt pk-pk input range
//!
//! 40 Volt peak-peak input range
#define	CS_GAIN_40_V		40000

//! \brief 20 Volt pk-pk input range
//!
//! 20 Volt peak-peak input range
#define	CS_GAIN_20_V		20000

//! \brief 10 Volt pk-pk input range
//!
//! 10 Volt peak-peak input range
#define	CS_GAIN_10_V		10000

//! \brief 8 Volt pk-pk input range
//!
//! 8 Volt peak-peak input range
#define	CS_GAIN_8_V			8000

#define	CS_GAIN_5_V			5000

//! \brief 4 Volt pk-pk input range
//!
//! 4 Volt peak-peak input range
#define	CS_GAIN_4_V			4000

//! \brief 3 Volt pk-pk input range
//!
//! 3 Volt peak-peak input range
#define	CS_GAIN_3_V			3000

//! \brief 2 Volt pk-pk input range
//!
//! 2 Volt peak-peak input range
#define	CS_GAIN_2_V			2000

//! \brief 1 Volt pk-pk input range
//!
//! 1 Volt peak-peak input range
#define	CS_GAIN_1_V			1000

//! \brief 800 milliVolt pk-pk input range
//!
//! 800 milliVolt peak-peak input range
#define	CS_GAIN_800_MV		800

#define	CS_GAIN_500_MV		500
//! \brief 400 milliVolt pk-pk input range
//!
//! 400 milliVolt peak-peak input range
#define	CS_GAIN_400_MV		400

//! \brief 200 milliVolt pk-pk input range
//!
//! 200 milliVolt peak-peak input range
#define	CS_GAIN_200_MV		200

//! \brief 100 milliVolt pk-pk input range
//!
//! 100 milliVolt peak-peak input range
#define	CS_GAIN_100_MV		100
#define	CS_GAIN_50_MV		50

//! \brief CMOS signal levels on CS3200 and CS3200C
//!
//! CMOS signal levels on CS3200 and CS3200C
#define CS_GAIN_CMOS		2500

//! \brief TTL signal levels on CS3200 and CS3200C
//!
//! TTL signal levels on CS3200 and CS3200C
#define CS_GAIN_TTL			1500

//! \brief PECL signal levels on CS3200 and CS3200C
//!
//! PECL signal levels on CS3200 and CS3200C
#define CS_GAIN_PECL		3000

//! \brief LVDS signal levels on CS3200 and CS3200C
//!
//! LVDS signal levels on CS3200 and CS3200C
#define CS_GAIN_LVDS		0

//! \brief ECL  signal levels on CS3200 and CS3200C
//!
//! ECL  signal levels on CS3200 and CS3200C
#define CS_GAIN_ECL			-2000

//! \}
// RANGE_DEFS
// *****************************************************************************

//!
//! \defgroup TRIGGER_DEFS Trigger Configuration
//! \ingroup ALL_DEFINES
//! \{
//! \sa CSTRIGGERCONFIG

//! \brief Trigger on the falling slope of the trigger signal
//!
//! Trigger on the falling slope of the trigger signal
#define CS_TRIG_COND_NEG_SLOPE		0

//! \brief Trigger on the rising slope of the signal
//!
//! Trigger on the rising slope of the signal
#define CS_TRIG_COND_POS_SLOPE		1

#define CS_TRIG_COND_PULSE_WIDTH	2	//  Reserved
#define CS_MAX_TRIG_COND			3   //  Reserved

//----- Trigger relations
//! \brief Boolean OR trigger engine 1 and trigger engine 2
//!
//! Boolean OR trigger engine 1 and trigger engine 2
#define CS_RELATION_OR	0

//! \brief Boolean AND trigger engine 1 and trigger engine 2
//!
//! Boolean AND trigger engine 1 and trigger engine 2
#define CS_RELATION_AND	1

#define CS_EVENT1		2
#define CS_EVENT2		3

//! \brief Disable the trigger engine
//!
//! The specified trigger engine is disabled
#define CS_TRIG_ENGINES_DIS		0

//! \brief Enable the trigger engine
//!
//! The specified trigger engine is enabled
#define CS_TRIG_ENGINES_EN		1

//----- Trigger Source
//! \brief Disable trigger engines. Trigger manually or by timeout
//!
//! Disable trigger engines. Trigger manually or by timeout
#define	CS_TRIG_SOURCE_DISABLE	0

//! \brief Use channel index to specify the channel as trigger source
//!
//! Use channel index to specify the channel as trigger source
#define CS_TRIG_SOURCE_CHAN_1	1

#define CS_TRIG_SOURCE_CHAN_2	2

//! \brief Use external trigger input as trigger source
//!
//! Use external trigger input as trigger source
#define CS_TRIG_SOURCE_EXT		-1

//! \}
// TRIGGER_DEFS
// *****************************************************************************

//!
//! \defgroup CONF_QUERY CsSet() CsGet() constants
//! \ingroup ALL_DEFINES
//! \{

//! \brief Version information about the CompuScope system
//!
//! Version information about the CompuScope system
#define CS_BOARD_INFO			1			

//! \brief Static information about the CompuScope system
//!
//! Static information about the CompuScope system
#define CS_SYSTEM			3

//! \brief Dynamic configuration of channels
//!
//! Dynamic configuration of channels
#define CS_CHANNEL			4

//! \brief Dynamic configuration of the trigger engines
//!
//! Dynamic configuration of the trigger engines
#define CS_TRIGGER			5

//! \brief Dynamic configuration of the acquisition
//!
//! Dynamic configuration of the acquisition
#define	CS_ACQUISITION		6

#define CS_PARAMS			7			//  All parameters for the card: flash, eeprom, nvram

//! \brief Configuration parameters for FIR filter firmware
//!
//! Configuration parameters for FIR filter firmware. Can be used only with the FIR or Storage Media Expert firmware option.
#define CS_FIR_CONFIG		8

//! \brief Query information about 2nd and 3rd base-board FPGA images
//!
//! Query information about 2nd and 3rd base-board FPGA images
#define CS_EXTENDED_BOARD_OPTIONS	9


//! \brief Query the timestamp tick frequency.
//!
//! Query the timestamp tickcount frequency. It is used for calculation of elapsed time.
#define CS_TIMESTAMP_TICKFREQUENCY	10


//! \brief Dynamic configuration of the array of channels
//!
//! Configure the channels using the ARRAY_CHANNELCONFIG struct properly allocated
#define CS_CHANNEL_ARRAY	11

//! \brief Dynamic configuration of the array of triggers
//!
//! Configure the triggers using the ARRAY_TRIGGERCONFIG struct properly allocated
#define CS_TRIGGER_ARRAY	12

//! \brief Configuration parameters for Storage Media Testing firmware
//!
//! Configuration parameters for Envelope filter. Can be used only with the Storage Media Testing firmware option.
#define CS_SMT_ENVELOPE_CONFIG		13

//! \brief Configuration parameters for Storage Media Testing firmware
//!
//! Configuration parameters for Histogram filter. Can be used only with the Storage Media Testing firmware option.
#define CS_SMT_HISTOGRAM_CONFIG		14

//! \brief Configuration parameters for FFT filter firmware
//!
//! Configuration parameters for FFT eXpert firmware. Can be used only with the FFT firmware option.
#define CS_FFT_CONFIG		15

//! \brief Window coefficients for FFT eXpert firmware
//!
//! Window coefficients for FFT eXpert firmware. Can be used only with the FFT firmware option.
#define CS_FFTWINDOW_CONFIG		16

//! \brief Configuration parameters for eXpert MulRec Averaging firmware
//!
//! Configuration the number of averaging. Can be used only with the eXpert MulRec Averaging firmware option.
#define CS_MULREC_AVG_COUNT		17

//! \brief Configuration of the Trigger Out synchronisation
//!
//! Configuration of the Trigger Out synchronisation. Can be use only with STLP81 CompuScope
#define	CS_TRIG_OUT_CFG			18

//! Query the segment count. Can be use on eXpert Gate Acquisition to retrieve the actual segment count once the acquisition is complted.
#define	CS_GET_SEGMENT_COUNT	19

//! \brief Enabled one sample depth resolution
//!
//! Enabled one sample depth resolution. By default this featture will be disabled. Only works on some CompuScope models. 
#define	CS_ONE_SAMPLE_DEPTH_RESOLUTION	20


//! Query for the channel that has the triggered event.
#define	CS_TRIGGERED_INFO		200

//! Query for the segment tail size. The value returned is in bytes
#define	CS_SEGMENTTAIL_SIZE_BYTES	201

//! Query for the segment data size in expert Streaming . The value returned is samples.
#define	CS_STREAM_SEGMENTDATA_SIZE_SAMPLES	202

//! Query for the total amount of data in expert Streaming . The value returned is in bytes.
#define	CS_STREAM_TOTALDATA_SIZE_BYTES	203

//! \brief Request for the "Identify" LED 
//!
//! Use with the CsSet(). The "Identify" LED will be flashing for about 5 second. Only supported on some of CompuScope models.
#define CS_IDENTIFY_LED			204


//! \brief Modify the capture mode (Memory ro Streaming)
//!
//! Modify the capture mode. Some of eXpert functions will work in either Memory or Streaming mode. 
//! Use with CsSet(), this paramter is used to change the capture mode to Memory or Streaming mode. Only works on some CompuScope models. 
//! The capture mode can be changed after CsDo( ACTION_COMMIT ) or CsDo( ACTION_START ).
//! Use with CsGet(), to get the current capture mode.

#define CS_CAPTURE_MODE			205

//! \brief Modify the data format in streaming mode (Packed or UnPack)
//!
//! Modify the Data Pack capture mode. The data can be Unpack or Pack mode. By default data format is unpack (native 8-bit or 16-bit data)
//! Use with CsSet(), this paramter is used to change the Data Pack mode for Streaming. Only works on some CompuScope models. 
//! The data pack  mode can be changed after CsDo( ACTION_COMMIT ) or CsDo( ACTION_START ).
//! Use with CsGet(), to get the current Data Pack mode.

#define CS_DATAPACKING_MODE		206

//! \brief Get the information about data format
//!
//! Get different information about data format such as: signed or unsigned, packed or unpacked, 8-bit or 16-bit ...

#define	CS_GET_DATAFORMAT_INFO		207

//! \brief Set/Get ADC delay clock for Decade 6G
//! Use with CsSet(), to set Clock internal/External ADC delay using PCS_ADC_DELAY_STRUCT
//! Use with CsGet(), to get the current PCS_ADC_DELAY_STRUCT.

#define	CS_ADC_DELAY		208

//! \brief Retrieve data from the configuration  settings from the driver
//!
//! Retrieve data from the configuration  settings from the driver
#define CS_CURRENT_CONFIGURATION	 1

//! \brief Retrieve hardware configuration settings from the most recent acquisition
//!
//! Retrieve hardware configuration settings from the most recent acquisition
#define CS_ACQUISITION_CONFIGURATION 2

//! \brief Retrieve the configuration settings that relates to the acquisition buffer
//!
//! Retrieve the configuration settings that relates to the acquisition buffer
#define CS_ACQUIRED_CONFIGURATION 3

//! \}
// CONF_QUERY defines
// *****************************************************************************


//!
//! \defgroup CSDO_ACTIONS CsDo Actions
//! \ingroup ALL_DEFINES
//! \{
//! \sa CsDo

//! \brief Transfers configuration setting values from the drivers to the CompuScope hardware
//!
//! Transfers configuration setting values from the drivers to the CompuScope hardware.<BR>
//! Incorrect values will not be transferred and an error code will be returned.
//! \sa ACTION_COMMIT_COERCE
#define ACTION_COMMIT		1

//! \brief Starts acquisition
//!
//! Starts acquisition
#define	ACTION_START		2

//! \brief Emulates a trigger event
//!
//! Emulates a trigger event
#define ACTION_FORCE	3

//! \brief Aborts an acquisition or a transfer
//!
//! Aborts an acquisition or a transfer
#define	ACTION_ABORT	4

//! \brief Invokes CompuScope on-board auto-calibration sequence
//!
//! Invokes CompuScope on-board auto-calibration sequence
#define	ACTION_CALIB	5

//! \brief SOFT reset the CompuScope system (Software reset).
//!
//! Resets the CompuScope system to its default configuration. All pending operations will be terminated
#define ACTION_RESET	6

//! \brief Transfers configuration setting values from the drivers to the CompuScope hardware
//!
//! Transfers configuration setting values from the drivers to the CompuScope hardware.<BR>
//! Incorrect values will be coerced to valid available values, which will be transferred to the CompuScope system.
//! If coercion was required CS_CONFIG_CHANGED is returned
//! \sa ACTION_COMMIT
#define ACTION_COMMIT_COERCE	7

//! \brief Resets the time-stamp counter
//!
//! Resets the time-stamp counter
#define ACTION_TIMESTAMP_RESET	8

//! \brief Resets the Histogram counters
//!
//! Resets the Histogram counters
#define ACTION_HISTOGRAM_RESET	9

//! \brief Resets the encoder counter
//!
//! Resets the encoder counter
#define ACTION_ENCODER1_COUNT_RESET	10
#define ACTION_ENCODER2_COUNT_RESET	11

//! \brief HARD reset the CompuScope system (harware reset).
//!
//! Send a RESET command to the CompuScope system to reset hardware to its default state (the state after initialization). All pending operations will be terminated
//! Use this parameter with caution. If the PC hardware does not support this feature, it could crash the PC.
#define ACTION_HARD_RESET	12


//! \}
// CSDO_ACTIONS
// *****************************************************************************

//!
//! \defgroup SYSTEM_STATUS System Status
//! \ingroup ALL_DEFINES
//! \{
//! \sa CsGetStatus


//! \brief Ready for acquisition or data transfer
//!
//! Ready for acquisition or data transfer
#define	ACQ_STATUS_READY			0

//! \brief Waiting for trigger event
//!
//! Waiting for trigger event
#define	ACQ_STATUS_WAIT_TRIGGER		1

//! \brief CompuScope system has been triggered but is still busy acquiring
//!
//! CompuScope system has been triggered but is still busy acquiring
#define	ACQ_STATUS_TRIGGERED		2

//! \brief Data transfer is in progress
//!
//! Data transfer is in progress
#define	ACQ_STATUS_BUSY_TX			3

//! \brief CompuScope on-board auto-calibration sequence  is in progress
//!
//! CompuScope on-board auto-calibration sequence  is in progress
#define	ACQ_STATUS_BUSY_CALIB		4

//! \}
// SYSTEM_STATUS defines
// *****************************************************************************


//!
//! \defgroup BOARD_TYPES Board Types
//! \ingroup ALL_DEFINES
//! \{
//!

// Demo systems have their own board types

//! 8 bit demo system
#define	CSDEMO8_BOARDTYPE			0x0801
//! 12 bit demo system
#define	CSDEMO12_BOARDTYPE			0x0802
//! 14 bit demo system
#define	CSDEMO14_BOARDTYPE			0x0803
//! 16 bit demo system
#define	CSDEMO16_BOARDTYPE			0x0804
//! 32 bit demo system
#define	CSDEMO32_BOARDTYPE			0x0805

#define	CSDEMO_BT_MASK				0x0800
#define CSDEMO_BT_FIRST_BOARD		CSDEMO8_BOARDTYPE
#define CSDEMO_BT_LAST_BOARD		CSDEMO32_BOARDTYPE


//! CompuScope 8500
#define	CS8500_BOARDTYPE			0x1
//! CompuScope 82G
#define	CS82G_BOARDTYPE				0x2
//! CompuScope 12100
#define	CS12100_BOARDTYPE			0x3
//! CompuScope 1250
#define	CS1250_BOARDTYPE			0x4
//! CompuScope 1220
#define	CS1220_BOARDTYPE			0x5
//! CompuScope 1210
#define	CS1210_BOARDTYPE			0x6
//! CompuScope 14100
#define	CS14100_BOARDTYPE			0x7
//! CompuScope 1450
#define	CS1450_BOARDTYPE			0x8
//! CompuScope 1610
#define	CS1610_BOARDTYPE			0x9
//! CompuScope 1602
#define	CS1602_BOARDTYPE			0xa
//! CompuScope 3200
#define	CS3200_BOARDTYPE			0xb
// CompuScope 85G
#define	CS85G_BOARDTYPE				0xc
//! CompuScope 14200
#define	CS14200_BOARDTYPE			0xd
//! CompuScope 14105
#define	CS14105_BOARDTYPE			0xe
//! CompuScope 12400
#define	CS12400_BOARDTYPE			0xf

#define	CS14200v2_BOARDTYPE			0x10

#define	SNA142_BOARDTYPE			0x11


#define CS_COMBINE_FIRST_BOARD			CS14200_BOARDTYPE
#define CS_COMBINE_LAST_BOARD			SNA142_BOARDTYPE

//! Nucleon base compuscopes
#define	CSPCIEx_BOARDTYPE  			0x2000
#define	CSNUCLEONBASE_BOARDTYPE  	CSPCIEx_BOARDTYPE

//! Razors board types
#define CS16x1_BOARDTYPE			0x20
#define CS16x2_BOARDTYPE			0x21
#define CS14x1_BOARDTYPE			0x22
#define CS14x2_BOARDTYPE			0x23
#define CS12x1_BOARDTYPE			0x24
#define CS12x2_BOARDTYPE			0x25

#define CS16xyy_BT_FIRST_BOARD		CS16x1_BOARDTYPE
#define CS16xyy_LAST_BOARD			CS12x2_BOARDTYPE
#define	CS16xyy_BASEBOARD			CS16x1_BOARDTYPE

//! Oscar board types
#define CSE42x0_BOARDTYPE			(0x30 | CSPCIEx_BOARDTYPE)
#define CSE42x2_BOARDTYPE			(0x31 | CSPCIEx_BOARDTYPE)
#define CSE42x4_BOARDTYPE			(0x32 | CSPCIEx_BOARDTYPE)
#define CSE42x7_BOARDTYPE			(0x33 | CSPCIEx_BOARDTYPE)
#define CSE43x0_BOARDTYPE			(0x34 | CSPCIEx_BOARDTYPE)
#define CSE43x2_BOARDTYPE			(0x35 | CSPCIEx_BOARDTYPE)
#define CSE43x4_BOARDTYPE			(0x36 | CSPCIEx_BOARDTYPE)
#define CSE43x7_BOARDTYPE			(0x37 | CSPCIEx_BOARDTYPE)
#define CSE44x0_BOARDTYPE			(0x38 | CSPCIEx_BOARDTYPE)
#define CSE44x2_BOARDTYPE			(0x39 | CSPCIEx_BOARDTYPE)
#define CSE44x4_BOARDTYPE			(0x3A | CSPCIEx_BOARDTYPE)
#define CSE44x7_BOARDTYPE			(0x3B | CSPCIEx_BOARDTYPE)

#define CSE4abc_FIRST_BOARD			CSE42x0_BOARDTYPE
#define CSE4abc_LAST_BOARD			CSE44x7_BOARDTYPE
#define	CSE4abc_BASEBOARD			CSE42x0_BOARDTYPE


//! Octopus Board types
#define	CS8220_BOARDTYPE			0x40
#define	CS8221_BOARDTYPE			0x41
#define	CS8222_BOARDTYPE			0x42
#define	CS8223_BOARDTYPE			0x43
#define	CS8224_BOARDTYPE			0x44
#define	CS8225_BOARDTYPE			0x45
#define	CS8226_BOARDTYPE			0x46
#define	CS8227_BOARDTYPE			0x47
#define	CS8228_BOARDTYPE			0x48
#define	CS8229_BOARDTYPE			0x49
//! Board types for 12 bit 2 channel Octopus products
#define	CS822x_BOARDTYPE_MASK		0x40

#define	CS8240_BOARDTYPE			0x50
#define	CS8241_BOARDTYPE			0x51
#define	CS8242_BOARDTYPE			0x52
#define	CS8243_BOARDTYPE			0x53
#define	CS8244_BOARDTYPE			0x54
#define	CS8245_BOARDTYPE			0x55
#define	CS8246_BOARDTYPE			0x56
#define	CS8247_BOARDTYPE			0x57
#define	CS8248_BOARDTYPE			0x58
#define	CS8249_BOARDTYPE			0x59
//! Board types for 12 bit 4 channel Octopus products
#define	CS824x_BOARDTYPE_MASK		0x50

#define	CS8280_BOARDTYPE			0x60
#define	CS8281_BOARDTYPE			0x61
#define	CS8282_BOARDTYPE			0x62
#define	CS8283_BOARDTYPE			0x63
#define	CS8284_BOARDTYPE			0x64
#define	CS8285_BOARDTYPE			0x65
#define	CS8286_BOARDTYPE			0x66
#define	CS8287_BOARDTYPE			0x67
#define	CS8288_BOARDTYPE			0x68
#define	CS8289_BOARDTYPE			0x69
//! Board types for 12 bit 8 channel Octopus products
#define	CS828x_BOARDTYPE_MASK		0x60

#define	CS8320_BOARDTYPE			0x80
#define	CS8321_BOARDTYPE			0x81
#define	CS8322_BOARDTYPE			0x82
#define	CS8323_BOARDTYPE			0x83
#define	CS8324_BOARDTYPE			0x84
#define	CS8325_BOARDTYPE			0x85
#define	CS8326_BOARDTYPE			0x86
#define	CS8327_BOARDTYPE			0x87
#define	CS8328_BOARDTYPE			0x88
#define	CS8329_BOARDTYPE			0x89
//! Board types for 14 bit 2 channel Octopus products
#define	CS832x_BOARDTYPE_MASK		0x80

#define	CS8340_BOARDTYPE			0x90
#define	CS8341_BOARDTYPE			0x91
#define	CS8342_BOARDTYPE			0x92
#define	CS8343_BOARDTYPE			0x93
#define	CS8344_BOARDTYPE			0x94
#define	CS8345_BOARDTYPE			0x95
#define	CS8346_BOARDTYPE			0x96
#define	CS8347_BOARDTYPE			0x97
#define	CS8348_BOARDTYPE			0x98
#define	CS8349_BOARDTYPE			0x99
//! Board types for 14 bit 4 channel Octopus products
#define	CS834x_BOARDTYPE_MASK		0x90

#define	CS8380_BOARDTYPE			0xA0
#define	CS8381_BOARDTYPE			0xA1
#define	CS8382_BOARDTYPE			0xA2
#define	CS8383_BOARDTYPE			0xA3
#define	CS8384_BOARDTYPE			0xA4
#define	CS8385_BOARDTYPE			0xA5
#define	CS8386_BOARDTYPE			0xA6
#define	CS8387_BOARDTYPE			0xA7
#define	CS8388_BOARDTYPE			0xA8
#define	CS8389_BOARDTYPE			0xA9


//! Board types for 14 bit 8 channel Octopus products
#define	CS838x_BOARDTYPE_MASK		0xA0

// The following 2 board types (for 1 channel 12 and 14 bit boards)
// were added on Oct. 5, 2007

#define	CS8210_BOARDTYPE			0xB0
#define	CS8211_BOARDTYPE			0xB1
#define	CS8212_BOARDTYPE			0xB2
#define	CS8213_BOARDTYPE			0xB3
#define	CS8214_BOARDTYPE			0xB4
#define	CS8215_BOARDTYPE			0xB5
#define	CS8216_BOARDTYPE			0xB6
#define	CS8217_BOARDTYPE			0xB7
#define	CS8218_BOARDTYPE			0xB8
#define	CS8219_BOARDTYPE			0xB9
//! Board types for 12 bit 1 channel Octopus products
#define	CS821x_BOARDTYPE_MASK		0xB0

#define	CS8310_BOARDTYPE			0xC0
#define	CS8311_BOARDTYPE			0xC1
#define	CS8312_BOARDTYPE			0xC2
#define	CS8313_BOARDTYPE			0xC3
#define	CS8314_BOARDTYPE			0xC4
#define	CS8315_BOARDTYPE			0xC5
#define	CS8316_BOARDTYPE			0xC6
#define	CS8317_BOARDTYPE			0xC7
#define	CS8318_BOARDTYPE			0xC8
#define	CS8319_BOARDTYPE			0xC9
//! Board types for 14 bit 1 channel Octopus products
#define	CS831x_BOARDTYPE_MASK		0xC0


#define	CS8410_BOARDTYPE			0xD0
#define	CS8412_BOARDTYPE			0xD2

#define	CS8420_BOARDTYPE			0xD4
#define	CS8422_BOARDTYPE			0xD6

#define	CS8440_BOARDTYPE			0xD8
#define	CS8442_BOARDTYPE			0xDA

#define	CS8480_BOARDTYPE			0xDC
#define	CS8482_BOARDTYPE			0xDE
//! Board types for 16 bit Octopus products
#define	CS84xx_BOARDTYPE_MASK		0xD0

#define CS8_BT_MASK					0xD0

#define CS8_BT_FIRST_BOARD			CS8220_BOARDTYPE
#define CS8_BT_LAST_BOARD			CS8482_BOARDTYPE
#define	CS8xxx_BASEBOARD			CS8_BT_FIRST_BOARD

#define CS_ZAP_FIRST_BOARD			CS8410_BOARDTYPE
#define CS_ZAP_LAST_BOARD			CS8482_BOARDTYPE
#define	CS_ZAP_BASEBOARD			CS_ZAP_FIRST_BOARD

//! Board types for Cobra products
#define	CSxyG8_BOARDTYPE_MASK		0x100
#define	CS22G8_BOARDTYPE			0x100
#define	CS21G8_BOARDTYPE			0x101
#define	CS11G8_BOARDTYPE			0x102
#define	LAB11G_BOARDTYPE			0x103
#define CSxyG8_FIRST_BOARD			CS22G8_BOARDTYPE
#define CSxyG8_LAST_BOARD			LAB11G_BOARDTYPE

//! Board type for Base8
#define	CS_BASE8_BOARDTYPE			0x400
//! Board type for CobraX
#define	CS_COBRAX_BOARDTYPE_MASK	0x480
#define	CSX11G8_BOARDTYPE			0x481
#define	CSX21G8_BOARDTYPE			0x482
#define	CSX22G8_BOARDTYPE			0x483
#define	CSX13G8_BOARDTYPE			0x484
#define	CSX23G8_BOARDTYPE			0x485
#define	CSX14G8_BOARDTYPE			0x486
#define	CSX_NTS_BOARDTYPE		    0x487
#define CSX24G8_BOARDTYPE			0x488
#define CSEcdG8_FIRST_BOARD			CSX14G8_BOARDTYPE
#define CSEcdG8_LAST_BOARD			CSX24G8_BOARDTYPE

//! Board types for JD
#define	CS12500_BOARDTYPE			0x500
#define	CS121G_BOARDTYPE			0x501
#define	CS122G_BOARDTYPE			0x502
#define	CS14250_BOARDTYPE			0x510
#define	CS14500_BOARDTYPE			0x511
#define	CS141G_BOARDTYPE			0x512
#define CSJD_FIRST_BOARD			CS12500_BOARDTYPE
#define CSJD_LAST_BOARD			    CS141G_BOARDTYPE

//! Usb compuscopes
#define	CSUSB_BOARDTYPE  			0x1001
#define CSUSB_BT_FIRST_BOARD		CSUSB_BOARDTYPE
#define CSUSB_BT_LAST_BOARD			CSUSB_BOARDTYPE

// Decade12
#define CSDECADE123G_BOARDTYPE		0x600
#define CSDECADE126G_BOARDTYPE		0x601
#define CSDECADE_FIRST_BOARD	    CSDECADE123G_BOARDTYPE
#define CSDECADE_LAST_BOARD			CSDECADE126G_BOARDTYPE

// Hexagon
// PCIe board type
#define CSHEXAGON_161G4_BOARDTYPE		0x701			// 1Ghz 4 chans
#define	CSHEXAGON_161G2_BOARDTYPE		0x702			// 1Ghz 2 chans
#define CSHEXAGON_16504_BOARDTYPE		0x703			// 500Mhz 4 chan
#define CSHEXAGON_16502_BOARDTYPE		0x704			// 500Mhz 2 chan
// PXI board type
#define CSHEXAGON_PXI_BOARDTYPE_MASK	0x080
#define CSHEXAGON_LOWRANGE_BOARDTYPE_MASK	0x040
#define CSHEXAGON_X161G4_BOARDTYPE		(CSHEXAGON_PXI_BOARDTYPE_MASK|CSHEXAGON_161G4_BOARDTYPE)
#define	CSHEXAGON_X161G2_BOARDTYPE		(CSHEXAGON_PXI_BOARDTYPE_MASK|CSHEXAGON_161G2_BOARDTYPE)
#define CSHEXAGON_X16504_BOARDTYPE		(CSHEXAGON_PXI_BOARDTYPE_MASK|CSHEXAGON_16504_BOARDTYPE)
#define CSHEXAGON_X16502_BOARDTYPE		(CSHEXAGON_PXI_BOARDTYPE_MASK|CSHEXAGON_16502_BOARDTYPE)
#define CSHEXAGON_FIRST_BOARD			CSHEXAGON_161G4_BOARDTYPE
#define CSHEXAGON_LAST_BOARD			CSHEXAGON_X16502_BOARDTYPE

// Dagger
// PCIe board type
#define CSDAGGER_50216_BOARDTYPE		0x901
#define	CSDAGGER_25216_BOARDTYPE		0x902
#define CSDAGGER_FIRST_BOARD			CSDAGGER_50216_BOARDTYPE
#define CSDAGGER_LAST_BOARD				CSDAGGER_25216_BOARDTYPE

//! \}
//  BOARD_TYPES
// *****************************************************************************


// CompuScope PLX based board
#define	PLX_BASED_BOARDTYPE			0x4000
//! CompuScope CPCI
#define	CPCI_BOARDTYPE				0x8000
// CompuScope 1610C
#define	CS1610C_BOARDTYPE			(CPCI_BOARDTYPE | CS1610_BOARDTYPE)
// CompuScope 14100C
#define	CS14100C_BOARDTYPE			(CPCI_BOARDTYPE | CS14100_BOARDTYPE)
// CompuScope 82GC
#define	CS82GC_BOARDTYPE			(CPCI_BOARDTYPE | CS82G_BOARDTYPE)
// CompuScope 85GC
#define	CS85GC_BOARDTYPE			(CPCI_BOARDTYPE | CS85G_BOARDTYPE)
// CompuScope 3200C
#define CS3200C_BOARDTYPE			(CPCI_BOARDTYPE | CS3200_BOARDTYPE)

// Electron board type - is 'ORed' with the regular board type
#define FCI_BOARDTYPE				0x10000


// Default timeout value
#define CS_TIMEOUT_DISABLE			-1

//!
//! \defgroup EVENT_IDS Notification events
//! \ingroup ALL_DEFINES
//! \{

//! \brief Trigger event
//!
//! Trigger event
#define	ACQ_EVENT_TRIGGERED		0

//! \brief End of acquisition event
//!
//! End of acquisition event
#define	ACQ_EVENT_END_BUSY		1

//! \brief End of transfer event
//!
//! End of transfer event
#define	ACQ_EVENT_END_TXFER		2

//! \brief Alarm event
//!
//! Alarm event
#define	ACQ_EVENT_ALARM			3

// Number of acquisition events
#define	NUMBER_ACQ_EVENTS		4

//! \}
// EVENT_IDS defines
// *****************************************************************************




//   CAPS_ID   used in CsGetSystemCaps() to identify the
//   dynamic configuration requested
//
//
//	CAPS_ID  =   MainCapsId | SubCapsId
//
//  -------------------------------------------------
//  |	MainCapsId		 |		0000				|
//  -------------------------------------------------
//  31                15  14                       0
//
//  ------------------------------------------------
//  |   0000		     |      SubCapsId	       |
//  ------------------------------------------------
//  31                15  14                       0

//  Depending on CapsID, SubCapsId has different meaning
//  When call CsDrvGetSystemCaps(),
//  CapsID and SunCapsID should always be ORed together
//
//  SubCapsId for CAPS_INPUT_RANGES:
//			External trigger  SubCapsId = 0
//			Channel 1		  SubCapsId = 1
//			Channel 2		  SubCapsId = 2

//
// Make sure lower word should be 0
//

//!
//! \defgroup SYSTEM_CAPS System Capabilities
//! \ingroup ALL_DEFINES
//! \{

//! \brief Query for available sample rates
//!
//! Query for available sample rates using \link CsGetSystemCaps()\endlink method.<BR>
//! Data are returned as an array of CSSAMPLERATETABLE  structures.
//! The successful return value indicates size of the array.
#define CAPS_SAMPLE_RATES	0x10000

//! \brief Query for available input ranges
//!
//! Query for available input ranges using \link CsGetSystemCaps()\endlink method.<BR>
//! This define should be ORed with the channel index. <BR> Channel index starts with 1 (use 0 to query external trigger capabilities).
//! <BR> Data are returned as an array of CSRANGETABLE  structures. The successful return value indicates size of the array.
#define CAPS_INPUT_RANGES	0x20000

//! \brief Query for available impedances
//!
//! Query for available impedances using \link CsGetSystemCaps()\endlink method.<BR>
//! This define should be ORed with the channel index. <BR> Channel index starts with 1 (use 0 to query external trigger capabilities).
//! <BR> Data are returned as an array of CSIMPEDANCETABLE structures. The successful return value indicates size of the array.
#define	CAPS_IMPEDANCES		0x30000

//! \brief Query for available couplings
//
//! Query for available couplings using \link CsGetSystemCaps()\endlink method.<BR>
//! This define should be ORed with the channel index. <BR> Channel index starts with 1 (use 0 to query external trigger capabilities).
//! <BR> Data are returned as an array of CSCOUPLINGTABLE structures. The successful return value indicates size of the array.
#define	CAPS_COUPLINGS		0x40000

//! \brief Query for available capture modes
//!
//! Query for available capture modes using \link CsGetSystemCaps()\endlink method.<BR> 
//! Data are returned as an uInt32 which is a bit mask of all available ACQUISITION_MODES.
#define	CAPS_ACQ_MODES		0x50000

//! \brief Query for available channel terminations
//!
//! Query for available channel terminations using \link CsGetSystemCaps()\endlink method.<BR>
//! This define should be ORed with the channel index. <BR> Channel index starts with 1 (use 0 to query external trigger capabilities).
//! <BR> Data are returned as an uInt32 which is a bit mask of all available terminations.
#define	CAPS_TERMINATIONS	0x60000

//! \brief Query for availability of flexible triggering (triggering from any of cards in system)
//!
//! Query for availability of flexible triggering (triggering from any of cards in system) using \link CsGetSystemCaps()\endlink method.<BR> 
//! Data are returned as an uInt32: 0 - no support for flexible trigger; 1 - full support for flexible trigger; 2 - support flexible trigger on input channels but only one external trigger.
#define	CAPS_FLEXIBLE_TRIGGER	0x70000

//! \brief Query for number of trigger engines per board
//!
//! Query for number of trigger engines per board using \link CsGetSystemCaps()\endlink method. <BR> 
//!Data are returned as an uInt32.
#define	CAPS_BOARD_TRIGGER_ENGINES	0x80000

//! \brief Query for trigger sources available
//!
//! Query for trigger sources available using \link CsGetSystemCaps()\endlink method. <BR>
//! Data are returned as an array of int32 each element signifying a valid trigger source.
//! By default Return all trigger sources are returned. This define can be also ORed with the CS_MODE_XXXX to retrieve trigger sources available only for that mode.
#define	CAPS_TRIGGER_SOURCES	0x90000

//! \brief Query for available built-in filters
//
//! Query for available built-in filters using \link CsGetSystemCaps()\endlink method.<BR>
//! This define should be ORed with the channel index. <BR> Channel index starts with 1 (use 0 to query external trigger capabilities).<BR>
//! Built-in filters are available only on some CompuScope models. Failure to query means that no built-in filters are available.
//! <BR> Data are returned as an array of CSFILTERTABLE structures.
#define	CAPS_FILTERS		0xA0000


//! \brief Query for Max Padding for segment or depth
//!
//! Query for Max Padding for segment or depth using \link CsGetSystemCaps()\endlink method.<BR>
//! Data are returned as an uInt32 containing the max padding depending on board type.
#define	CAPS_MAX_SEGMENT_PADDING	0xB0000


//! \brief Query for DC Offset adjustment capability
//!
//! Query for DC Offset adjustment capability using \link CsGetSystemCaps()\endlink method. <BR>
//! No data are passed. The return value determines availability of the feature.
#define	CAPS_DC_OFFSET_ADJUST		0xC0000

//! \brief Query for external synchronisation clock inputs
//!
//! Query for external synchronisation clock inputs using \link CsGetSystemCaps()\endlink method. <BR>
//! No data are passed. The return value determines availability of the feature.
#define	CAPS_CLK_IN		0xD0000

//! \brief Query for FPGA Boot image  capability
//!
//! Query for FPGA Boot image  capability using \link CsGetSystemCaps()\endlink method. <BR>
//! No data are passed. The return value determines availability of the feature.
#define	CAPS_BOOTIMAGE0		0xE0000

//! \brief Query for Aux input/output capability
//!
//! Query for Aux input/output capability using \link CsGetSystemCaps()\endlink method. <BR>
#define	CAPS_AUX_CONFIG		0xF0000


//! \brief Query for Aux input/output capability
//!
//! Query for Aux input/output capability using \link CsGetSystemCaps()\endlink method. <BR>
#define	CAPS_CLOCK_OUT			0x100000
#define	CAPS_TRIG_OUT			0x110000
#define	CAPS_TRIG_ENABLE		0x120000
#define	CAPS_AUX_OUT			0x130000
#define	CAPS_AUX_IN_TIMESTAMP	0x140000

//! \brief Query for the new behavior of the hardware

//! New behavior of harware does not allow to switch expert image on the fly. The system need to
//! be power down completetly
//! Query for the new behavior of the hardware using \link CsGetSystemCaps()\endlink method. <BR>
#define	CAPS_FWCHANGE_REBOOT	0x150000


//! \brief Query for External Trigger UniPolar input
//!
//! Query for External Trigger input UniPolar capability using \link CsGetSystemCaps()\endlink method. <BR>
#define	CAPS_EXT_TRIGGER_UNIPOLAR	0x160000

//! \brief Query for number of trigger engines per channel
//!
//! Query for number of trigger engines per channel using \link CsGetSystemCaps()\endlink method. <BR>
//! Data are returned as an uInt32.
#define	CAPS_TRIG_ENGINES_PER_CHAN		0x200000

//! \brief Query for multiple record capability
//!
//! Query for multiple record capability using \link CsGetSystemCaps()\endlink method. <BR>
//! No data are passed. The return value determines availability of the feature.
#define	CAPS_MULREC						0x400000

//! \brief Query for trigger resolution
//!
//! Query for trigger resolution using \link CsGetSystemCaps()\endlink method. <BR>
//! Data are returned as an uInt32.
#define	CAPS_TRIGGER_RES				0x410000

//! \brief Query for minimum external clock rate
//!
//! Query for minimum external clock rate using \link CsGetSystemCaps()\endlink method. <BR>
//! Data are returned in Hz as an int64.
#define	CAPS_MIN_EXT_RATE				0x420000

//! \brief Query for external clock skip count
//!
//! Query for external clock skip count using \link CsGetSystemCaps()\endlink method. <BR>
//! Data are returned as an uInt32.
#define CAPS_SKIP_COUNT					0x430000

//! \brief Query for maximum external clock rate
//!
//! Query for maximum external clock rate using \link CsGetSystemCaps()\endlink method. <BR>
//! Data are returned in Hz as an int64.
#define	CAPS_MAX_EXT_RATE				0x440000


//! \brief Query for CsTransferEx() support
//!
//! Query for CsTransferEx() support using \link CsGetSystemCaps()\endlink method. <BR>
//! No data are passed. The return value determines availability of the feature.
#define	CAPS_TRANSFER_EX				0x450000

//! \brief Query for the transfer size boundary in Streaming mode
//!
//! Query for the transfer size boundary in Streaming mode using \link CsGetSystemCaps()\endlink method. <BR>
//! Data are returned as an uInt32.
#define	CAPS_STM_TRANSFER_SIZE_BOUNDARY		0x460000

//! \brief Query for the max segment size in Streaming mode
//!
//!Query for the max segment size in Streaming mode using \link CsGetSystemCaps()\endlink method. <BR>
//! Data are returned as an int64-.
#define	CAPS_STM_MAX_SEGMENTSIZE		0x470000


//! \brief Query for the capability of capturing data from the channel 2 in single channel mode using
//!
//! Query for the capability of capturing data from the channel 2 in single channel mode using \link CsGetSystemCaps()\endlink method. <BR>
//! No data are passed. The return value determines availability of the feature.
#define	CAPS_SINGLE_CHANNEL2			0x480000


//! \brief Query for the capability of the Identify LED
//!
//! Query for the capability of the Identify LED. The LED will be flashing when the request "Identify" is sent to the card.\endlink method. <BR>
//! No data are passed. The return value determines availability of the feature.
#define	CAPS_SELF_IDENTIFY				0x490000

//! \brief Query for the capability of the max pretrigger depth
//!
//! brief Query for the capability of the max pretrigger depth using \link CsGetSystemCaps() \endlink method. <BR>
//! No data are passed. The return value determines availability of the feature.
#define	CAPS_MAX_PRE_TRIGGER			0x4A0000

//! \brief Query for the capability of the depth increment
//!
//! brief Query for the capability of the depth increment using \link CsGetSystemCaps() \endlink method. <BR>
//! No data are passed. The return value determines availability of the feature.
#define	CAPS_DEPTH_INCREMENT			0x4B0000

//! \brief Query for the capability of the trigger delay increment
//!
//! brief Query for the capability of the trigger delay increment using \link CsGetSystemCaps() \endlink method. <BR>
//! No data are passed. The return value determines availability of the feature.
#define	CAPS_TRIGGER_DELAY_INCREMENT	0x4C0000


//! \}
// SYSTEM_CAPS defines
// *****************************************************************************


#define CS_NO_FILTER        0xFFFFFFFF
#define CS_NO_EXTTRIG       0xFFFFFFFF

//! \}
//  DDC 
// *****************************************************************************
//! CsSet with DDC command.
#define CS_MODE_NO_DDC		0x0
#define CS_DDC_MODE_ENABLE	0x1
#define CS_DDC_MODE_CH1		0x1
#define CS_DDC_MODE_CH2		0x2
#define CS_DDC_DEBUG_MUX	0x3
#define CS_DDC_DEBUG_NCO	0x4
#define CS_DDC_MODE_LAST	0x4

//! Old and obsolete DDC defined.
#define CS_DDC_MUX_ENABLE	0x2

//! CsSet with DDC Core Config structure.
#define CS_DDC_CORE_CONFIG				300

//! CsSet with DDC FIR Config structure.
#define CS_DDC_FIR_COEF_CONFIG			301

//! CsSet with DDC CFIR Config structure.
#define CS_DDC_CFIR_COEF_CONFIG			302

//! CsSet with DDC PFIR Config structure.
#define CS_DDC_PFIR_COEF_CONFIG			303

//! CsSet with DDC FIFO DATA
#define CS_DDC_WRITE_FIFO_DATA			305

//! CsGet with DDC FIFO DATA
#define CS_DDC_READ_FIFO_DATA			306

#define SIZE_OF_FIR_COEFS				96
#define SIZE_OF_CFIR_COEFS				21
#define SIZE_OF_PFIR_COEFS				63
#define DDC_FILTER_COEFS_MAX_SIZE		SIZE_OF_FIR_COEFS + SIZE_OF_CFIR_COEFS + SIZE_OF_PFIR_COEFS
#define DDC_CORE_CONFIG_OFFSET			DDC_FILTER_COEFS_MAX_SIZE


//! CsSet with new DDC Config structure.
#define CS_DDC_CONFIG					400

//! CsSet  - DDC Control
#define CS_DDC_SEND_CMD					401

//! CsGet  - DDC Scale Overflow status
#define	CS_DDC_SCALE_OVERFLOW_STATUS	402

//  POSITION ENCODER
// *****************************************************************************
//! Encoder Channel with Encoder Config structure.
#define CS_PE_ENABLE	1
#define CS_PE_DISABLE	0

//! CsSet  - Counter Reset

#define CS_ENCODER1_COUNT_RESET			300
#define CS_ENCODER2_COUNT_RESET			301

//! CsSet - Encoder Channel with Encoder Config structure.
#define CS_ENCODER1_CONFIG				302
#define CS_ENCODER2_CONFIG				303

//! CsGet  - Count Value
#define CS_ENCODER1_COUNT				304
#define CS_ENCODER2_COUNT				305

//! Input Type: Step And Direction or Quadrature.
#define CS_PE_INPUT_TYPE_STEPANDDIRECTION		0
#define CS_PE_INPUT_TYPE_QUADRATURE				1

//! Encoder Mode: Stamping or Trigger-On-Positon mode.
#define CS_PE_ENCODER_MODE_STAMP				0
#define CS_PE_ENCODER_MODE_TOP					1


//! \}
//  OCT (Optical  Coherence Tomography)
// *****************************************************************************
//! OCT firmware define.
#define CS_OCT_ENABLE	1
#define CS_OCT_DISABLE	0

//! OCT phy mode connector.
#define CS_OCT_MODE0	0		// Clock on Chan 1, Sample on Chan 2
#define CS_OCT_MODE1	1		// Clock on Chan 2, Sample on Chan 1

//! CsSet/CsGet OCT Config structure.
#define CS_OCT_CORE_CONFIG				330
#define CS_OCT_RECORD_LEN				331
#define CS_OCT_CMD_MODE					332

//! CsSet/CsGet ADC Delay.
#define CS_ADC_DELAY_FLS_SET			0x80000000
#define CS_ADC_DELAY_FLS_CLEAR			0x1

#endif // __CS_DEFINES_H__


#ifndef _CS_STRUCT_H_
#define _CS_STRUCT_H_

#include "CsTypes.h"

#pragma pack (8)
#pragma warning(disable: 4214) // warning C4214: nonstandard extension used: bit field types other than int

//! \struct CSBOARDINFO
//! \brief Structure contains the version information about the CompuScope.
//!
//! This structure contains the version information about the CompuScope hardware 
//! and firmware. 
//! The information in the structure is read only.
//! \sa CsGet, ARRAY_BOARDINFO
typedef struct 
{
	uInt32		u32Size;   					  //!< Total size, in bytes, of the structure.
	uInt32  	u32BoardIndex;				  //!< Board Index in the system
	uInt32		u32BoardType;				  //!< Numeric constant to represent Gage boards.
	cschar		strSerialNumber[32];		  //!< String representing the board serial number.
	uInt32		u32BaseBoardVersion;		  //!< Version number of the base board.
	uInt32		u32BaseBoardFirmwareVersion;  //!< Version number of the firmware on the base board.
	uInt32		u32AddonBoardVersion;		  //!< Version number of the Addon board.
	uInt32		u32AddonBoardFirmwareVersion; //!< Version number of the firmware of the Addon board.
	uInt32		u32AddonFwOptions;			  //!< Options of the current firmware image of Addon board
	uInt32		u32BaseBoardFwOptions;		  //!< Options of the current firmware image of Baseboard
	uInt32		u32AddonHwOptions;			  //!< Options of the Addon board pcb
	uInt32		u32BaseBoardHwOptions;		  //!< Options of the Baseboard pcb
} CSBOARDINFO, *PCSBOARDINFO;


//! \struct ARRAY_BOARDINFO
//! \brief Array of the CSBOARDINFO to pass to CsGet.
//!
//! This structure is used to retrieve the version information for multi-board
//! systems. 
//! \sa CsGet, CSBOARDINFO
typedef struct 
{
	uInt32			u32BoardCount;		//!< Number of boards in the system .
	CSBOARDINFO		aBoardInfo[1];		//!< A \link CSBOARDINFO CSBOARDINFO \endlink structure as described above.
}ARRAY_BOARDINFO, *PARRAY_BOARDINFO;
/*************************************************************/



//! \struct CSSYSTEMINFO
//! \brief Structure contains the static information describing the CompuScope.
//!
//! This structure contains the static information describing the CompuScope hardware.
//! This structure is used to query for characteristics of the CompuScope system.
//! The information in the structure is read only.
//! \sa CsGetSystemInfo
typedef struct
{
	//! Total size, in Bytes, of the structure.
	uInt32	u32Size;   				//!<  Total size, in Bytes, of the structure.
	//! Total memory size of the each CompuScope board in the system in samples
	int64	i64MaxMemory;			//!<  Total memory size of each CompuScope board in the system in samples
	//! Vertical resolution, in bits, of the system
	uInt32	u32SampleBits;			//!<  Vertical resolution, in bits, of the system
	//! Sample resolution for the system. Used for voltage conversion.
	int32	i32SampleResolution;	//!<  Sample resolution for the system. Used for voltage conversion.
	//! Sample size, in Bytes.
	uInt32	u32SampleSize;			//!<  Sample size, in Bytes
	//! Sample offset of the system
	int32	i32SampleOffset;		//!<  This is ADC output that corresponds to the middle Voltage of the input range. Used for voltage conversion.
	//! Numeric constant that indicates CompuScope model
	uInt32	u32BoardType;			//!<  Numeric constant that indicates \link BOARD_TYPES CompuScope model \endlink
	//! Text string containing the CompuScope model name
	cschar	strBoardName[32];		//!<  Text string containing the CompuScope model name
	//! Options encoding features like gate, trigger enable, digital in, pulse out.
	uInt32	u32AddonOptions;		//!<  Options encoding features like gate, trigger enable, digital in, pulse out.
	//! Options encoding features like gate, trigger enable, digital in, pulse out.
	uInt32	u32BaseBoardOptions;	//!<  Options encoding features like gate, trigger enable, digital in, pulse out.
	//! Number of trigger engines available in the CompuScope system
	uInt32	u32TriggerMachineCount;	//!<  Number of trigger engines available in the CompuScope system
	//! Total number of channels in the CompuScope system
	uInt32 	u32ChannelCount;		//!<  Total number of channels in the CompuScope system
	//!Number of boards in the CompuScope system
	uInt32	u32BoardCount;  		//!<  Number of boards in the CompuScope system
	//!
} CSSYSTEMINFO, *PCSSYSTEMINFO;


//! \struct CSACQUISITIONCONFIG
//! \brief This structure is used to set or query configuration settings of the CompuScope system.
//!
//! \sa CsGet, CsSet
typedef struct
{
	//! Total size, in Bytes, of the structure
	uInt32	u32Size;			//!< Total size, in Bytes, of the structure
	//! Sample rate value in Hz
	int64	i64SampleRate; 		//!< Sample rate value in Hz
	//! External clocking status.  A non-zero value means "active" and zero means "inactive"
	uInt32	u32ExtClk;			//!< External clocking status.  A non-zero value means "active" and zero means "inactive"
	//! Sample clock skip factor in external clock mode.
	uInt32	u32ExtClkSampleSkip;//!< Sample clock skip factor in external clock mode.  The sampling rate will be equal to
	                            //!< (external clocking frequency) / (u32ExtClkSampleSkip) * (1000). <BR>
	                            //!< For example, if the sample clock skip factor is 2000 then the sample rate will be one
	                            //!<  half of the external clocking frequency.
	//! Acquisition mode of the system
	uInt32	u32Mode;			//!< Acquisition mode of the system: \link ACQUISITION_MODES ACQUISITION_MODES\endlink.
	                            //!< Multiple selections may be ORed together.
	//! Vertical resolution of the CompuScope system
	uInt32  u32SampleBits;      //!< Actual vertical resolution, in bits, of the CompuScope system.
	//! Sample resolution for the CompuScope system
	int32	i32SampleRes;		//!< Actual sample resolution for the CompuScope system
	//! Sample size in Bytes for the CompuScope system
	uInt32	u32SampleSize;		//!< Actual sample size, in Bytes, for the CompuScope system
	//! Number of segments per acquisition.
	uInt32	u32SegmentCount;	//!< Number of segments per acquisition.
	//! Number of samples to capture after the trigger event
	int64	i64Depth;			//!< Number of samples to capture after the trigger event is logged and trigger delay counter has expired.
	//! Maximum possible number of points that may be stored for one segment acquisition.
	int64	i64SegmentSize;		//!< Maximum possible number of points that may be stored for one segment acquisition.
	                            //!< i64SegmentSize should be greater than or equal to i64Depth
	//! Amount of time to wait  after start of segment acquisition before forcing a trigger event.
	int64	i64TriggerTimeout;	//!< Amount of time to wait (in 100 nanoseconds units) after start of segment acquisition before
	                            //!< forcing a trigger event. CS_TIMEOUT_DISABLE means infinite timeout. Timeout counter is reset
	                            //!< for every segment in a Multiple Record acquisition.
	//! Enables the external signal used to enable or disable the trigger engines
	uInt32	u32TrigEnginesEn;	//!< Enables the external signal used to enable or disable the trigger engines
	//! Number of samples to skip after the trigger event before starting decrementing depth counter.
	int64	i64TriggerDelay;	//!< Number of samples to skip after the trigger event before starting to decrement depth counter.
	//! Number of samples to acquire before enabling the trigger circuitry.
	int64	i64TriggerHoldoff;	//!< Number of samples to acquire before enabling the trigger circuitry. The amount of pre-trigger
	                            //!< data is determined by i64TriggerHoldoff and has a maximum value of (i64RecordSize) - (i64Depth)
	//! Sample offset for the CompuScope system
	int32  i32SampleOffset;		//!< Actual sample offset for the CompuScope system
	//! Time-stamp mode.
	uInt32	u32TimeStampConfig;	//!< Time stamp mode: \link TIMESTAMPS_MODES TIMESTAMPS_MODES\endlink. 
	                            //!< Multiple selections may be ORed together.
	//! Number of segments per acquisition.
	int32	i32SegmentCountHigh;	//!< High patrt of 64-bit segment count. Number of segments per acquisition.
//!
} CSACQUISITIONCONFIG, *PCSACQUISITIONCONFIG;

//! \struct CSCHANNELCONFIG
//! \brief This structure is used to set or query channel-specific configuration settings. Each channel within the system
//! has its own configuration structure.
//!
//! \sa CsGet, CsSet
typedef struct
{
	//!  Total size, in Bytes, of the structure
	uInt32	u32Size;			//!< Total size, in Bytes, of the structure
	//! Channel index.
	uInt32	u32ChannelIndex;	//!< Channel index. 1 corresponds to the first channel.
	//!< <BR>Regardless of the Acquisition mode, numbers are assigned to channels in a CompuScope system
	//!< as if they all are in use.<BR> For example, in an 8-channel system channels are numbered 1, 2, 3, 4, 5, 6, 7, 8.<BR>
    //!< All modes make use of channel 1. The rest of the channel numbers are evenly spaced throughout the CompuScope 
	//!< system by a fixed increment. To calculate this increment, users must divide the number of channels on one 
	//!< CompuScope board by the number of active channels in the current CompuScope mode, which is equal to the lower 
	//!< 12 bits of acquisition mode.
	
	//! Channel coupling and termination
    uInt32	u32Term;		    //!< Channel \link CHAN_DEFS coupling and termination\endlink. Used to set coupling (AC or DC),
	                            //!< the termination (single-ended or differential), and additional signal conditioning inputs such as Direct-to-ADC.
	//! Channel full scale input range, in mV peak-to-peak
    uInt32	u32InputRange;		//!< Channel full scale input range, in mV peak-to-peak.  May use \link CHAN_DEFS channel range\endlink constants
	//! Channel impedance, in Ohms
    uInt32	u32Impedance;		//!< Channel impedance, in Ohms (50 or 1000000)
	//! Channel bandwidth, kHz
	uInt32	u32Filter;			//!< Filter (default = 0 (No filter))
								//!< Index of the filter to be used. The filter parameters may be extracted with the CsGetSystemCaps using the CAPS_FILTERS parameter.
	//! Channel DC offset, in mV
	int32	i32DcOffset;		//!< Channel DC offset, in mV
	//! Channel on-board auto-calibration method
	int32	i32Calib;			//!< Channel on-board auto-calibration method. The default is 0. 
//!	
} CSCHANNELCONFIG, *PCSCHANNELCONFIG;


//! \struct ARRAY_CHANNELCONFIG
//! \brief	An array of channel configuration structures
//!
typedef struct
{
	//!
	uInt32	u32ChannelCount;		   //!< Number of CSCHANNELCONFIG structure elements in this array
	//!
	CSCHANNELCONFIG		aChannel[1];   //!< Array of \link CSCHANNELCONFIG CSCHANNELCONFIG \endlink structures

}ARRAY_CHANNELCONFIG, *PARRAY_CHANNELCONFIG;


//! \struct CSTRIGGERCONFIG
//! \brief	This structure is used to set or query parameters of the trigger engine. 
//! Each trigger engine is described separately
//!
//! \sa CsGet, CsSet
typedef struct
{
	//! Total size, in Bytes, of the structure.
	uInt32	u32Size;			//!< Total size, in Bytes, of the structure.
	//! Trigger engine index
	uInt32	u32TriggerIndex;	//!< Trigger engine index. 1 corresponds to the first trigger engine.
	//! Trigger condition
	uInt32	u32Condition;	   	//!< See \link TRIGGER_DEFS Trigger condition \endlink constants
	//! Trigger level as a percentage of the trigger source input range (±100%)
	int32	i32Level;			//!< Trigger level as a percentage of the trigger source input range (±100%)
	//! Trigger source
	int32	i32Source;			//!< See \link TRIGGER_DEFS Trigger source \endlink constants
	//! External trigger coupling
	uInt32	u32ExtCoupling;		//!< External trigger coupling: AC or DC
	//! External trigger range
	uInt32	u32ExtTriggerRange;	//!< External trigger full scale input range, in mV
	//! External trigger impedance
	uInt32	u32ExtImpedance;	//!< External trigger impedance, in Ohms
	//!
	int32	i32Value1;			//!< Reserved for future use
	//!
	int32	i32Value2;			//!< Reserved for future use
	//!
	uInt32	u32Filter;			//!< Reserved for future use
	//! Logical relation applied to the trigger engine outputs
	uInt32	u32Relation;     	//!< Logical relation applied to the trigger engine outputs (default OR)

} CSTRIGGERCONFIG, *PCSTRIGGERCONFIG;


//! \struct ARRAY_TRIGGERCONFIG
//! \brief  An array of TRIGGERCONFIG structures, one for each trigger engine in the system.
//!
typedef struct
{
	//!
	uInt32	u32TriggerCount;			//!< Number of CSTRIGGERCONFIG structure elements in this array
	//!
	CSTRIGGERCONFIG		aTrigger[1];	//!< Array of CSTRIGGERCONFIG structures

}ARRAY_TRIGGERCONFIG, *PARRAY_TRIGGERCONFIG;


//! \struct CSSYSTEMCONFIG
//! \brief  Structure containing the whole configuration: Acquisition settings, Channels settings and Triggers settings.
//!
typedef struct
{
	//! Total size, in Bytes, of the structure.
	uInt32					u32Size;   		//!< Total size, in Bytes, of the structure.
	//! Acquisition Configuration
	PCSACQUISITIONCONFIG	pAcqCfg;		//!< \link CSACQUISITIONCONFIG Acquisition Configuration \endlink
	//!  Channels' configuration
	PARRAY_CHANNELCONFIG    pAChannels;		//!< Pointer to an \link ARRAY_CHANNELCONFIG array \endlink of channel configurations
	//!  Trigger engines' configuration
	PARRAY_TRIGGERCONFIG	pATriggers;		//!< Pointer to an \link ARRAY_TRIGGERCONFIG array \endlink of trigger engine configurations
	//!
} CSSYSTEMCONFIG, *PCSSYSTEMCONFIG;


//! \struct CSSAMPLERATETABLE
//! \brief  Structure containing the valid sample rates available for a CompuScope system. This table is only used with the CsGetSystemCaps() method
//!
typedef struct
{
	//!
	int64	i64SampleRate;	//!< Sample rate in Hz
	//!
	cschar	strText[32];	//!< Text string for sample rate (ex:"10 MHz")
	//!
} CSSAMPLERATETABLE, *PCSSAMPLERATETABLE;


//! \struct CSRANGETABLE
//! \brief  Structure containing the valid input ranges for a CompuScope system. This table is only used with the CsGetSystemCaps() method.
//!
typedef struct
{
	//!
	uInt32	u32InputRange;	//!< Full scale input range, in mV
	//!
	cschar	strText[32];	//!< Text string for input ranges (Ex: "+/- 100 mV")
	//!
	uInt32	u32Reserved;	//!< Reserved for internal use
	//!
} CSRANGETABLE, *PCSRANGETABLE;
/*************************************************************/

//! \struct CSIMPEDANCETABLE
//! \brief  Structure containing the valid input impedances for a CompuScope system. This table is only used with the CsGetSystemCaps() method
//!
typedef struct
{
	//!
	uInt32	u32Imdepdance;	//!< Impedances:  50 or 1000000
	//!
	cschar	strText[32];	//!< Text string for impedance (ex:"1 MOhm")
	//!
	uInt32	u32Reserved;	//!< Reserved for internal use
	//!
}CSIMPEDANCETABLE, *PCSIMPEDANCETABLE;
/*************************************************************/

//! \struct CSCOUPLINGTABLE
//! \brief  Structure containing the valid input couplings for a CompuScope system.  This table is only used with the CsGetSystemCaps() method
//!
typedef struct
{
	//!
	uInt32	u32Coupling;	//!< Coupling: AC or DC
	//!
	cschar	strText[32];	//!< Text string for the coupling (ex:"AC")
	//!
	uInt32	u32Reserved;	//!< Reserved for internal use
	//!
}CSCOUPLINGTABLE, *PCSCOUPLINGTABLE;


//! \struct CSFILTERTABLE
//! \brief  Structure containing the built-in filter information
//!
//! Built-in filters are available only on some CompuScope models.<BR>
//! if u32LowCutoff == u32HighCutoff means that filter is by passed.
typedef struct
{
	//!
	uInt32	u32LowCutoff;	//!< Low Cut-off frequency in Hz
	//!
	uInt32	u32HighCutoff;	//!< High Cut-off frequency in Hz
	//!
}CSFILTERTABLE, *PCSFILTERTABLE;


//! \struct IN_PARAMS_TRANSFERDATA
//! \brief  Structure used in CsTransfer() to specify data to be transferred.
//! May be used to transfer digitized data or time-stamp data.
//!
//! \sa CsTransfer
typedef struct
{
	//!  Channel index
	uInt16	u16Channel;			//!< Channel index (will be ignored in time-stamp mode)
	//! Transfer Modes
	uInt32	u32Mode;			//!< See \link TRANSFER_MODES Transfer Modes \endlink
	//! The segment of interest
	uInt32	u32Segment;			//!< The segment of interest
	//!  Start address for transfer
	int64	i64StartAddress;	//!< Start address for transfer relative to the trigger address
	//! Size of the requested data transfer
	int64	i64Length;			//!< Size of the requested data transfer (in samples)
	//! Pointer to the target buffer
	void *	pDataBuffer;		//!< Pointer to application-allocated buffer to hold requested data.  For 8-bit CompuScope models,
	                            //!< data values are formatted as uInt8. For analog input CompuScope models with more than 8-bit
	                            //!< resolution (e.g. 12 bit, 14 bit, 16 bit), data values are formatted as Int16.  For digital
	                            //!< input CompuScope models in 32-bit input mode, data values are formatted as uInt32.
	                             //!< For time-stamp data transfer, time-stamp values are formatted as 64-bit integers.
	//! Notification event

#ifdef _WIN32
	HANDLE	*hNotifyEvent;		//!< Optional: Pointer to the Handle of application-created event. The event will be signalled once data transfer is complete
#else
	void	*hNotifyEvent;		//!< Optional: Pointer to the Handle of application-created event. The event will be signalled once data transfer is complete
	int		hNotifyEvent_read;
	int		hNotifyEvent_write;
#endif /* _WIN32 */

//!
} IN_PARAMS_TRANSFERDATA, *PIN_PARAMS_TRANSFERDATA;


//! \struct OUT_PARAMS_TRANSFERDATA
//! \brief  Structure used in CsTransfer() to hold output parameters
//! \sa CsTransfer
typedef struct
{
	//! Address  of the first sample in the buffer
	int64	i64ActualStart;		//!< Address relative to the trigger address of the first sample in the buffer
	//! Length of valid data in the buffer
	int64	i64ActualLength;	//!< Length of valid data in the buffer
	//! TimeStamp clock frequency
	int32	i32LowPart;			//!< In time-stamp data transfer mode, returns the time-stamp clock frequency in Hz
	//!  Reserved for internal use
	int32	i32HighPart;		//!< Reserved for internal use

}OUT_PARAMS_TRANSFERDATA, *POUT_PARAMS_TRANSFERDATA;


//! \sa CsTransferEx
typedef struct
{
	//!  Channel index
	uInt16	u16Channel;				//!< Channel index (will be ignored in time-stamp mode)
	//! Transfer Modes
	uInt32	u32Mode;				//	Slave , BusMaster, DATA_ONLY, TIMESTAMP_ONLY, DATA_WITH_TAIL, INTERLEAVED
	//! The segment of interest
	uInt32	u32StartSegment;		//!< The first segment of interest

	uInt32	u32SegmentCount;		//!< Number of segments

	//!  Start address for transfer
	int64	i64StartAddress;	//!< Start address for transfer relative to the trigger address
	//! Size of the requested data transfer
	int64	i64Length;			//!< Size of the requested data transfer (in samples)

	//! Pointer to the target buffer
	void *	pDataBuffer;		//!< Pointer to application-allocated buffer to hold requested data.  For 8-bit CompuScope models,
	                            //!< data values are formatted as uInt8. For analog input CompuScope models with more than 8-bit
	                            //!< resolution (e.g. 12 bit, 14 bit, 16 bit), data values are formatted as Int16.  For digital
	                            //!< input CompuScope models in 32-bit input mode, data values are formatted as uInt32.
	                             //!< For time-stamp data transfer, time-stamp values are formatted as 64-bit integers.
	int64	i64BufferLength;

	//! Notification event
#ifdef _WIN32
	HANDLE	*hNotifyEvent;		//!< Optional: Pointer to the Handle of application-created event. The event will be signalled once data transfer is complete
#else
	void	*hNotifyEvent;		//!< Optional: Pointer to the Handle of application-created event. The event will be signalled once data transfer is complete
	int		hNotifyEvent_read;
	int		hNotifyEvent_write;
#endif /* _WIN32 */
//!
} IN_PARAMS_TRANSFERDATA_EX, *PIN_PARAMS_TRANSFERDATA_EX;



//! \struct OUT_PARAMS_TRANSFERDATA
//! \brief  Structure used in CsTransfer() to hold output parameters
//! \sa CsTransfer
typedef struct
{
	uInt32	u32DataFormat0;		// 0x12345678		Spider OCTAL interleaved
								// 0x11223344		Spider/Splenda QUAD  interleaved
								// 0x11112222		Spider/Splenda DUAL  interleaved

								// 0x12121212		Combine/Rabbit/FastBall DUAL  interleaved

								// 0x11111111		NON INTERLEAVED or SINGLE

	uInt32	u32DataFormat1;		// Reserved for future use

}OUT_PARAMS_TRANSFERDATA_EX, *POUT_PARAMS_TRANSFERDATA_EX;
	


//! \struct CALLBACK_DATA
//! \brief  Structure used as a parameter in callback
//!
//! Structure used as a parameter in the method CsRegisterCallbackFnc
//! \sa CsRegisterCallbackFnc
typedef struct
{
	//! Total size, in Bytes, of the structure.
	uInt32		u32Size;   		//!< Total size, in Bytes, of the structure.
	//! Handle of the CompuScope system to be addressed
	CSHANDLE	hSystem; //!< Handle of the CompuScope system to be addressed
    //! Channel index.
	uInt32		u32ChannelIndex;	//!< Channel index. 1 corresponds to Channel A
	//! Transfer token;
	int32		i32Token;			//!< Transfer token;
	//!
}CALLBACK_DATA, *PCALLBACK_DATA;

typedef void (*LPCsEventCallback)(PCALLBACK_DATA pData);

//! \struct CSTIMESTAMP
//! \brief  Structure used in to store the timestamp information.
//!
//! Structure used in to store the timestamp information from a SIG file header.
//! \sa CSSIGSTRUCT
typedef struct 
{
	//! Hours field.
	uInt16 u16Hour;   //!< Hours field.
	//! Minutes field.
	uInt16 u16Minute; //!< Minutes field.
	//! Seconds field.
	uInt16 u16Second; //!< Seconds field.
	//! 100ths of a second field.
	uInt16 u16Point1Second;	//!< 100ths of a second field.
	//!
}CSTIMESTAMP, *PCSTIMESTAMP;

//! \struct CSSIGSTRUCT
//! \brief  Structure used in to create SIG file headers, or to convert between SIG file headers.
//!
//! Structure used in to create SIG file headers, or to convert between SIG file headers.
//! \sa CsConvertToSigHeader, CsConvertFromSigHeader
typedef struct 
{
	//! Total size, in Bytes, of the structure
	uInt32 u32Size;			//!< Total size, in Bytes, of the structure
	//! Sample rate value in Hz
	int64 i64SampleRate;	//!< Sample rate value in Hz
	//! Starting address (in samples) of each segment in the file
	int64 i64RecordStart;	//!< Starting address (in samples) of each segment in the file.
	//! Length (in samples) of each segment in the file
	int64 i64RecordLength;	//!< Length (in samples) of each segment in the file.
	//! Number of segments saved in the file
	uInt32 u32RecordCount;	//!< Number of segments saved in the file
	//! Actual vertical resolution, in bits, of the storred signal
	uInt32 u32SampleBits;	//!< Actual vertical resolution, in bits, of the storred signal.
	//! Actual sample size, in Bytes, for the storred signal
	uInt32 u32SampleSize;	//!< Actual sample size, in Bytes, for the storred signal.
	//! Actual sample offset for the storred signal
	int32 i32SampleOffset;	//!< Actual sample offset for the storred signal. Used for conversion of raw ADC codes to voltage values.
	//! Actual sample resolution for the CompuScope system
	int32 i32SampleRes;		//!< Actual sample resolution for the storred signal. Used for conversion of raw ADC codes to voltage values.
	//! Channel number that is in the file. 1 corresponds to the first channel
	uInt32 u32Channel;		//!< Channel number that is in the file. 1 corresponds to the first channel.
	//! Channel full scale input range, in mV peak-to-peak.  May use \link CHAN_DEFS channel range\endlink constants.
	uInt32 u32InputRange;	//!< Channel full scale input range, in mV peak-to-peak.  May use \link CHAN_DEFS channel range\endlink constants.
	//! Channel DC offset, in mV
	int32 i32DcOffset;		//!< Channel DC offset, in mV.
	//! Time stamp structure, elements are hour, minute, second, 100ths of a second
	CSTIMESTAMP TimeStamp;	//!< Time stamp structure, elements are hour, minute, second, 100ths of a second.
	//!
} CSSIGSTRUCT, *PCSSIGSTRUCT;


//! \struct CSDISKFILEHEADER
//! \brief  Structure used dealing with SIG file headers.
//!
//! Opaque data structure used dealing with SIG file headers
//! \sa CsConvertToSigHeader, CsConvertFromSigHeader
typedef struct 
{
	//! Opaque data used as a placeholder for the SIG file header.
	char cData[512];	//!< Opaque data used as a placeholder for the SIG file header.
} CSDISKFILEHEADER, *PCSDISKFILEHEADER;

//! \struct CSSEGMENTTAIL
//! \brief This structure is used to read segment tail information.
//!
//! \sa CsTransferEx
typedef struct
{
	//! Timestamp of the segment
	int64	i64TimeStamp;			//!< Timestamp of the record
	//! Reserved for future use
	int64	i64Reserved0; 		//!< Reserved for future use
	//! Reserved for future use
	int64	i64Reserved1; 		//!< Reserved for future use
	//! Reserved for future use
	int64	i64Reserved2; 		//!< Reserved for future use
//!
} CSSEGMENTTAIL, *PCSSEGMENTTAIL;


typedef struct
{
	uInt32					u32Size;			// size of this structure
	uInt32					u32FileVersion;		// version 1.0
	uInt32					u32BlockSize;		
	uInt32					u32HeaderSize;		// sizeof(this structure) + u8NbOfChannels*sizeof(CSCHANNELCONFIG) +
												// u8NbOfTrigEn*sizeof(CSTRIGGERCONFIG)
	int64					i64DataSize;		// The size of raw data in bytes
	uInt32					u32FooterSize;		// The size of the footer in bytes
	char					szBoardName[32];
	char					szSerialNumber[32];
	char					szUserDescription[256];
	uInt32					u32Dataformat;
	uInt8					u8NbOfChannels;		// Number of Channel structures followed this structure
	uInt8					u8NbOfTrigEn;		// Number of Channel structures followed this structure
	CSACQUISITIONCONFIG		AcqConfig;

} STREAMING_FILEHEADER, *PSTREAMING_FILEHEADER;

typedef struct
{
	uInt32					u32Size;			// Size of this structure
	uInt16					u16CardIndex;		// Index of the card in the sytem
	uInt32					u32NbOfChannels;	// Number of Channel structures at the end of this structure
	uInt32					u32NbOfTriggers;	// Number of Triggers structures at the end of this structure
	uInt32					u32TailSize;		// Size of each segment tail in bytes

#ifdef _WINDOWS_
	unsigned __int64		u64StartSegment;	// Position of the first segment saved (If the file was paste from another, else 0)
	unsigned __int64		u64SegmentOffset;	// Offset in the first segment saved (If the file was paste from another, else 0)
	unsigned __int64		u64StartPoint;		// Start position of all the segments (If the file is the result of an extraction)
	unsigned __int64		u64EndPoint;		// End position of all the segments (If the file is the result of an extraction)
#else
	uint64				u64StartSegment;	// Position of the first segment saved (If the file was paste from another, else 0)
	uint64				u64SegmentOffset;	// Offset in the first segment saved (If the file was paste from another, else 0)
	uint64				u64StartPoint;		// Start position of all the segments (If the file is the result of an extraction)
	uint64				u64EndPoint;		// End position of all the segments (If the file is the result of an extraction)
#endif

	CSSYSTEMINFO			CSystemInfo;
	char					szDescription[256];
	CSACQUISITIONCONFIG		CsAcqConfig;

	//Dynamic section
	//u32NbOfChannels * CSCHANNELCONFIG
	//u32NbOfTriggers * CSTRIGGERCONFIG
} STMHEADER, *PSTMHEADER;


//! \struct CSTRIGGERED_INFO
//! \brief This structure is used to find out what channel that has the triggered event
//!
//! \sa CsGet
typedef struct
{
	//! Total size, in Bytes, of the structure
	uInt32 u32Size;			//!< Total size, in Bytes, of the structure
	//! The starting segment 
	uInt32					u32StartSegment;
	//! Number of segments 
	uInt32					u32NumOfSegments;

	//! Total size, in Bytes, of the buffer allocated by apllication
	uInt32					u32BufferSize;

	//! Pointer to the buffer allocated by application.
	int16					*pBuffer;		//! The buffer size should be as least equal to u32NumOfSegments * sizeof(int16) 
	
	
} TRIGGERED_INFO_STRUCT, *PTRIGGERED_INFO_STRUCT;

//! \struct CSPECONFIG
//! \brief This structure is used get/set Position Encoder Config
//!
//! \sa CsGet/CsSet
typedef struct
{
	//! Total size, in Bytes, of the structure
	uInt32 u32Size;			//!< Total size, in Bytes, of the structure
	//! Enable/Disable
	uInt32					Enable;
	//! "Step and Direction" or "Quarature"
	uInt32					InputType;
	//! Encoder Mode ToP or STAMP
	uInt32					EncodeMode;

	//! Counter for Top Mode.
	uInt32					Step;

	//! Offset for Top mode.
	uInt32					Offset;		 

} CSPECONFIG, *PCSPECONFIG;


typedef struct
{
	//! Total size, in Bytes, of this structure
	uInt32	u32Size;			//!< Total size, in Bytes, of this structure
	//! Actual Data is sign or unsigned, 1= signed, 0 = unsigned;
	uInt32  u32Signed;      //!< Actual Data is sign or unsigned, 1= signed, 0 = unsigned;
	//!< Actual Data is packed or unpacked. 1= packed, 0 = unpacked;
	uInt32  u32Packed;      //!< Actual Data is packed or unpacked, 1= packed, 0 = unpacked;
	//! Actual vertical resolution, in bits, of the CompuScope system.
	uInt32  u32SampleBits;      //!< Actual vertical resolution, in bits, of the CompuScope system.
	//! Acutual Sample size, in bits, for the CompuScope system. Some of bits may be digital IOs or padded data
	uInt32	u32SampleSize_Bits;		//!< Acutual Sample size, in bits, for the CompuScope system. Some of bits may be digital IOs or padded data
	//! Actual sample offset for the CompuScope system
	int32  i32SampleOffset;		//!< Actual sample offset for the CompuScope system
	//! Actual sample resolution for the CompuScope system
	int32	i32SampleRes;		//!< Actual sample resolution for the CompuScope system

} CS_STRUCT_DATAFORMAT_INFO, *PCS_STRUCT_DATAFORMAT_INFO;


#pragma pack ()


#endif


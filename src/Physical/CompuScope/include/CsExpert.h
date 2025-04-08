
#ifndef __CS_EXPERT_H__
#define __CS_EXPERT_H__

// FPGA Images
//!
//! \addtogroup ACQUISITION_MODES
//! \{

//! \brief Use alternative firmware image 1
//!
//!	Use alternative firmware image. Image capabilities could be determined using CompuScope manager.
//! See eXpert documentation for details
#define	CS_MODE_USER1			0x40000000 // Use alternative firmware image 1
//! \brief Use alternative firmware image 2
//!
//!	Use alternative firmware image. Image capabilities could be determined using CompuScope manager.
//! See eXpert documentation for details
#define	CS_MODE_USER2			0x80000000 // Use alternative firmware image 2

// Averaging
//! \brief Use software averaging acquisition mode
//!
//!	Use software averaging acquisition mode. Note this mode not available for all CompuScope models.
#define CS_MODE_SW_AVERAGING	0x1000     // Software Averaging

//! \}

// Base board Expert firmware options
#define	CS_BBOPTIONS_FIR				0x0001				// FIR options
#define	CS_BBOPTIONS_AVERAGING			0x0002				// Averaging options	
#define	CS_BBOPTIONS_MINMAXDETECT		0x0004				// MinMax Detection options
#define	CS_BBOPTIONS_CASCADESTREAM		0x0008				// MulRec Streaming options
#define	CS_BBOPTIONS_MULREC_AVG			0x0010				// Multiple Records Average
#define	CS_BBOPTIONS_SMT        		0x0020			    // Complex option with histogram and FIR

#define	CS_BBOPTIONS_FFT_8K        		0x0040				// FFT 8192
#define	CS_BBOPTIONS_FFT_4K       		0x0200			    // FFT 4096

#define	CS_BBOPTIONS_MULREC_AVG_TD		0x0400				// Multiple Records Average with Trigger delay
#define	CS_BBOPTIONS_DDC				0x0800				// DDC
#define	CS_BBOPTIONS_OCT				0x1000				// OCT
#define	CS_BBOPTIONS_STREAM      		0x2000				// Stream to analysis or disk
#define	CS_AOPTIONS_HISTOGRAM			0x4001				// Histogram


#define	CS_BBOPTIONS_FFTMASK        	( CS_BBOPTIONS_FFT_4K | \
										  CS_BBOPTIONS_FFT_8K ) 

#define	CS_BBOPTIONS_EXPERT_MASK		0xFFFF				// OR all options aboved 


// Option for memory sizes over 2 Gigasamples
#define CSMV_BBOPTIONS_BIG_TRIGGER		0x80000000

// Limitation of hardware averaging
#define MAX_HW_AVERAGING_DEPTH			(0xC000-128)	// Max trigger depth in hardware Averaging mode (in samples)
#define MAX_HW_AVERAGE_SEGMENTCOUNT		1024			// Max segment count in hardware averaging mode

// Limitation of software averaging
#define MAX_SW_AVERAGING_SEGMENTSIZE	512*1024		// Max segment size in Software averaging mode (in samples)
#define MAX_SW_AVERAGE_SEGMENTCOUNT		4096			// Max segment count in software averaging mode

// Limitation of MinMax detection
#define MAX_MINMAXDETECT_SEGMENTSIZE	0x8FFFFFF		// 28 bits Max segment size in Minmax detection mode (in samples)
#define MAX_MINMAXDETECT_SEGMENTCOUNT	0x1FFFFFF		// 25 bits Max segment count in Minmax detection mode

#define MAX_DISKSTREAM_CHANNELS			16


#pragma pack(8)


//! \struct CS_FIR_CONFIG_PARAMS
//! \brief Structure describes the FIR parameters
//!
//! This structure contains the FIR parameters and can be used only with FIR firmware.
//! This structure is used to configure firmware via CsSet API. 
//! Setting FIR parameters does not require a Commit action.
//! \sa CsSet
typedef struct
{
	//! Total size, in Bytes, of the structure.
	uInt32		u32Size;					//!< Total size, in Bytes, of the structure.
	//! Enable FIR.
	BOOL		bEnable;					//!< Enable FIR. If Disabled a unity filter is used
	//! Symmetrical core
	BOOL		bSymmetrical39th;			//!< If true assume that coefficients are part of a symmetrical 39 tap core. 
	                                        //!< If false a 20 tap core of arbitrary shape is used.
	//! Scaling factor used for all coefficients.
	uInt32		u32Factor;					//!< Scaling factor used for all coefficients. Allowed values are 2^(2*n+1) 1 <= n <= 10
	//! Core coefficients
	int16		i16CoefFactor[20];			//!< Core coefficients represented in a fixed point format. This array contains numerators 
	                                        //!< while the denominator is stored in the u32Factor field.
											//!< The coefficient 0 is stored on index 0,
											//!< The coefficient 1 is stored on index 1 and so on...
	//!
} CS_FIR_CONFIG_PARAMS, *PCS_FIR_CONFIG_PARAMS;

//! \struct CS_SMT_ENVELOPE_CONFIG_PARAMS
//! \brief Structure describes the Envelope parameters
//!
//! This structure contains the Envelope parameters and can be used only with Storage Media firmware.
//! This structure is used to configure firmware via CsSet API. 
//! Setting Envelope parameters does not require a Commit action.
//! \sa CsSet
typedef struct
{
	//! Total size, in Bytes, of the structure.
	uInt32		u32Size;					//!< Total size, in Bytes, of the structure.
	//! Enable Envelop.
	BOOL		bEnable;					//!< Enable Envelope.
	//! Output Selector
	uInt8		u8Output;					//!< Output Selector
											//!< 0: Max
											//!< 1:	Min
											//!< 2:	Peak to peak
											//!< 3:	ASYM
	//! Number of samples in envelope
	uInt16		u16N_Envelope;				//!< The number of points to consider in an Envelope Detection calculation
	//! Scaling factor used for all coefficients.
	uInt16		u16ASYM_Factor;				//!< The factor used in calculation of the ASYM parameter.
	//! The offset used in calculation of the ASYM parameter.
	uInt16		u16ASYM_Offset;				//!< The offset used in calculation of the ASYM parameter.
	//! The pre-scaler used in calculation of the ASYM parameter.
	uInt16		u16ASYM_PreScaler;			//!< The pre-scaler used in calculation of the ASYM parameter.
} CS_SMT_ENVELOPE_CONFIG_PARAMS, *PCS_SMT_ENVELOPE_CONFIG_PARAMS;


//! \struct CS_SMT_HISTOGRAM_CONFIG_PARAMS
//! \brief Structure describes the Histogram parameters
//!
//! This structure contains the Histogram parameters and can be used only with Storage Media firmware.
//! This structure is used to configure firmware via CsSet API. 
//! \sa CsSet
typedef struct
{
	//! Total size, in Bytes, of the structure.
	uInt32		u32Size;					//!< Total size, in Bytes, of the structure.
	//! Enable Histogram
	BOOL		bEnable;					//!< Enable Histogram. 
	//! Start Mode selector
	uInt8		u8StartMode;				//!< Start Mode selector
											//!< 0: Histogram starts on Start Acquisition
											//!< 1:	Histogram starts only on 'Trigger'
	//! Stop selector
	uInt8		u8StopMode;					//!< Stop selector
											//!< 0: Acquisition stop only on Histogram full
											//!< 1:	Acquisition stop on Post trigger depth
} CS_SMT_HISTOGRAM_CONFIG_PARAMS, *PCS_SMT_HISTOGRAM_CONFIG_PARAMS;


//! \struct CS_FFT_CONFIG_PARAMS
//! \brief Structure describes the parameters for eXpert FFT
//!
//! This structure contains the eXpert FFT parameters and can be used only with eXpert FFT firmware.
//! This structure is used to configure firmware via CsSet API. The parameters must be set prior to FFT transfer.
//! The operation does not require the commit action.
//! \sa CsSet, CS_FFTWINDOW_CONFIG_PARAMS
typedef struct
{
	//! Total size, in Bytes, of the structure.
	uInt32		u32Size;					//!< Total size, in Bytes, of the structure.
	//! The size of FFT
	uInt16		u16FFTSize;					//!< The size of FFT (read only)
	//! Enable FFT
	BOOL		bEnable;					//!< Enable FFT filter
	//! Enable FFT averaging
	BOOL		bAverage;					//!< Enable FFT averaging
	//! FFT format
	BOOL		bRealOnly;					//!< FALSE : inputs are Real(I) and Imaginary
											//!< TRUE  : inputs are Real only
	//! Enabling FFT window
	BOOL		bWindowing;					//!< Windowing FFT. If TRUE the coefficients of FFT windows
											//!< should be loaded using \link CS_FFTWINDOW_CONFIG_PARAMS CS_FFTWINDOW_CONFIG_PARAMS \endlink
	//! Inverse FFT
	BOOL		bIFFT;						//!< Inverse FFT
	//! Multi-block transfer format
	BOOL		bFftMr;						//!< FALSE : all FFT blocks are processed from the same acquisition segment
											//!< TRUE  : one FFT block per acquisition segment
} CS_FFT_CONFIG_PARAMS, *PCS_FFT_CONFIG_PARAMS;

//! \struct CS_FFTWINDOW_CONFIG_PARAMS
//! \brief Structure specifies FFT window coefficients
//!
//! This structure contains the window coefficients used by eXpert FFT firmware to scale data before performing FFT.
//! The operation does not require the commit action.
//! \sa CsSet
typedef struct
{
	//! Number of coefficients
	uInt16		u16FFTWinSize;				//!< Number of Coefficients.
											//!< should be one half of the \link CS_FFT_CONFIG_PARAMS::u16FFTSize CS_FFT_CONFIG_PARAMS::u16FFTSize\endlink 
	//! Window coeficients
	int16		i16Coefficients[1];			//!< Window coeficients
} CS_FFTWINDOW_CONFIG_PARAMS, *PCS_FFTWINDOW_CONFIG_PARAMS;

//! \struct CS_TRIG_OUT_CONFIG_PARAMS
//! \brief Structure to configure trigger out signal
//!
//! This structure contains configuration information of the synchronisation trigger out signal to the trigger event
typedef struct
{
	//! Total size, in Bytes, of the structure.
	uInt32		u32Size;					//!< Total size, in Bytes, of the structure.
	//! Delay in samples
	uInt16		u16Delay;					//!< Delay in samples, resolution is 1 sample.
	//! synchronisation polarity
	BOOL		bClockPolarity;				//!< FALSE (0) - Positive edge, TRUE (1) - negative edge.
} CS_TRIG_OUT_CONFIG_PARAMS, *PCS_TRIG_OUT_CONFIG_PARAMS;

typedef struct _TRIGGERTIMEINFO
{
	int64	i64TriggerTimeStamp;
	uInt32	u32TriggerNumber;

}TRIGGERTIMEINFO, *PTRIGGERTIMEINFO;


typedef struct _MINMAXCHANNEL_INFO
{
	int16	i16MaxVal;
	int16	i16MinVal;
	int64	i64MaxPosition;
	int64	i64MinPosition;

} MINMAXCHANNEL_INFO, *PMINMAXCHANNEL_INFO;


typedef struct _MINMAXSEGMENT_INFO
{
	uInt32				u32Size;				// size of this structure
	uInt32				u32NumberOfChannels;	// Number of channel
	TRIGGERTIMEINFO		TrigTimeInfo;
	MINMAXCHANNEL_INFO	MinMaxChanInfo[1];

}MINMAXSEGMENT_INFO, *PMINMAXSEGMENT_INFO;


typedef struct _SEGMENTDATAINFO
{
	uInt32				u32SegmentNumber;
	int32				i32ActualStart;
	uInt32				u32ActualLength;
	uInt32				u32TriggerCount;
	int64				i64TriggerTimestamp;
	
} SEGMENTDATAINFO, *PSEGMENTDATAINFO;


#ifndef __linux__

typedef struct _CSCREATEMINMAXQUEUE
{
	struct
	{
		uInt32		u32Size;				// size of this structure
		uInt32		u32ActionId;			// Must be EXFN_CREATEMINMAXQUEUE
		uInt32		u32QueueSize;			// Number of 
		uInt16		u16DetectorResetMode;	// Min max detector rerset mode
											// 0: Reset on Trigger
											// 1: Reset on Start of Segment

		uInt16		u16TsResetMode;			// MinMax Time stamp reset mode
											// 0: Reset on Start Acquisition
											// 1: Reset on Start of Segment
	} in;

	struct
	{
		HANDLE		*hQueueEvent;			// Data abvailable event
		HANDLE		*hErrorEvent;			// Error event
		HANDLE		*hSwFifoFullEvent;		// Sw Fifo full event
	} out;

} CSCREATEMINMAXQUEUE, *PCSCREATEMINMAXQUEUE;
#endif

typedef struct _CSDESTROYMINMAXQUEUE
{
	struct
	{
		uInt32		u32Size;
		uInt32		u32ActionId;		// Must be EXFN_DESTROYMINMAXQUEUE
	} in;

} CSDESTROYMINMAXQUEUE, *PCSDESTROYMINMAXQUEUE;


typedef struct _CSPARAMS_GESEGMENTINFO
{
	struct
	{
		uInt32		u32Size;
		uInt32		u32ActionId;		// Must be EXFN_GETSEGMENTINFO
		uInt32		u32BufferSize;		// Size of the buffer in byte
	} in;

	struct
	{
		MINMAXSEGMENT_INFO	*pBuffer;	// Pointer to buffer
	} out;

} CSPARAMS_GESEGMENTINFO, *PCSPARAMS_GESEGMENTINFO;


typedef struct _CSPARAMS_GENERIC
{
	struct
	{
		uInt32		u32Size;
		uInt32		u32ActionId;		// Must be EXFN_CLEARERRORMINMAXQUEUE 
	} in;

} CSPARAMS_GENERIC, *PCSPARAMS_GENERIC,
  CLEARERRORMINMAXQUEUE, *PCLEARERRORMINMAXQUEUE,
  CSRELEASE_CASCADESTREAM, *PCSRELEASE_CASCADESTREAM,
  CSSTMMULREC_DATAREAD, *PCSSTMMULREC_DATAREAD;

#ifndef __linux__

typedef struct _CSCONFIG_CASCADESTREAM
{
	struct
	{
		uInt32		u32Size;				// size of this structure
		uInt32		u32ActionId;			// Must be EXFN_CASCADESTREAM_CONFIG
	} in;

	struct
	{
		HANDLE		*hDataAvailableEvent;	// Data abvailable event
		HANDLE		*hErrorEvent;			// Error event
		HANDLE		*hSwFifoFullEvent;		// Sw Fifo full event
	} out;

} CSCONFIG_CASCADESTREAM, *PCSCONFIG_CASCADESTREAM;

#endif

typedef struct _CSGET_CHANNELDATA
{
	struct
	{
		uInt32		u32Size;				// size of this structure
		uInt32		u32ActionId;			// Must be EXFN_CASCADESTREAM_GETCHANNELDATA
		uInt8		u8Channel;				// Channel index
	} in;

	struct
	{
		PVOID						*pChannelBuffer;	// pointer to channel Data buffer
		PSEGMENTDATAINFO			pSegmentDataInfo;	// Segment Info
	} out;

} CSGET_CHANNELDATA, *PCSGET_CHANNELDATA;



typedef struct _CSTRANSFER_RAWMULREC
{
	struct
	{
		uInt32		u32Size;				// size of this structure
		uInt32		u32ActionId;			// Must be EXFN_TRANSFER_RAWMULREC
		uInt32		u32StartSegment;		// Start segment number
		uInt32		u32EndSegment;			// End Segment number
		PVOID		pBuffer;				// Buffer for Data
		int64		i64BufferSize;			// Buffer Size in bytes
	} in;

	struct
	{
		int64		i64ActualBufferSize;	// Buffer Size in bytes
	} out;

} CSTRANSFER_RAWMULREC, *PCSTRANSFER_RAWMULREC;


typedef struct _CSRETRIEVE_DATA_FROM_RAWMULREC
{
	struct
	{
		uInt32		u32Size;				// size of this structure
		uInt32		u32ActionId;			// Must be EXFN_RETRIEVE_CHANNEL
		PVOID		pRawDataBuffer;			// Raw Data Buffer
		uInt32		u32RawDataBufferSize;	// Raw Buffer Size in samples
		uInt32		u32Segment;				// The segment number
		uInt16		u16Channel;				// Channel numbber
		int64		i64StartAddress;		// Start
		int64		i64Length;				// Length in samples
		PVOID		pOutBuffer;				// Normalized data buffer
	} in;

	struct
	{
		int64		i64ActualStart;			// Actual start 
		int64		i64ActualLength;		// Actual Length in samples
		int64		i64TriggerTimeStamp;	// Trigger time stamp of the segment
	} out;

} CSRETRIEVE_DATA_FROM_RAWMULREC, *PCSRETRIEVE_DATA_FROM_RAWMULREC;

#ifndef __KERNEL__
typedef struct _CSCONFIG_DISKSTREAM
{
	uInt32		u32Size;							// size of this structure
	uInt32		u32ActionId;						// Must be one of the EXFN_DISK_STREAM_XXXX commands	
	uInt32		dwTimeout;							// Time (in milliseconds) to wait before forcing a trigger
	int64		i64XferStart;						// Address at which to start transferring the data
	int64		i64XferLen;							// Length of data (in samples) to transfer
	uInt32		u32RecStart;						// Which segment to start transfer from (single record transfers should be set to 1)
	uInt32		u32RecCount;						// How many segments to transfer (single record transfers should be set to 1)
	uInt32		u32AcqNum;							// How many acquisitions to perform
	uInt32      u32FilesPerChannel;                 // Returns how many files will be created for each channel
	BOOL		bTimeStamp;							// Flag to determine if the trigger time stamp should be set in the header comment field
	uInt32		dwStatusTimeout;					// Time (in milliseconds) in which to check whether or not all acquisitions and writes are finished
	uInt32		u32ChannelCount;					// Number of channels to transfer
	uInt16		ChanList[MAX_DISKSTREAM_CHANNELS];	// List of which channels to transfer, the first u32ChannelCount values in the array are used
	TCHAR		szBaseFolder[256];					// Name of base folder to store files. Relative paths are stored below the current directory
} CSCONFIG_DISKSTREAM, *PCSCONFIG_DISKSTREAM;
#endif

typedef struct _STREAMING_STATUS
{
	struct
	{
		uInt32		u32Size;				// size of this structure
		uInt32		u32ActionId;			// Must be EXFN_STREAM_INIT
	} in;

	struct
	{
		int64		i64DataSaved;			// Total data saved so far ...
		int64		i64DataLost;			// Total data lost so far ...
		uInt8		u8CirBufferStatus	;	// Status of circular buffer ...
	} out;

} CSSTREAMING_STATUS, *PCSSTREAMING_STATUS;


typedef struct _STREAMING_CONFIG
{
	struct
	{
		uInt32		u32Size;				// size of this structure
		uInt32		u32ActionId;			// Must be EXFN_STREAM_INIT
		char		szFileName[128];		// Data File name
		uInt32		u32SaveBlockSize;		// Save to Hard Drive Block Size
		uInt32		u32RecordCountHigh;		// 
		uInt32		u32Reserved0;			// Reserved. Should be 0
		uInt32		u32Reserved1;			// Reserved. Should be 0
	} in;

} CSSTREAMING_CONFIG, *PCSSTREAMING_CONFIG;


typedef struct _EXPERT_PARAMS_VOID
{
	struct
	{
		uInt32		u32Size;				// size of this structure
		uInt32		u32ActionId;			// Must be EXFN_STREAM_INIT
	} in;

	struct
	{
		int32		i32Status;				// size of this structure
	} out;

} EXPERT_PARAMS_VOID, *PEXPERT_PARAMS_VOID;


//! \struct CONFIG
//! \brief This structure is used to set or query DDC settings of the CompuScope system.
//!
typedef struct
{
	//!
	uInt32	u32NCOFreq;			//!< NCO Freq in Khz
	//!
	uInt16	NbStages;			//!< Nb of FIR stages used (min =1, max=8)
	//!
	uInt8	u8GainL1;			//!< Gain L1 (0..7)
	//!
	uInt8	u8GainL2;			//!< Gain L2 (0..7)
	//!
	uInt8	u8GainL3;			//!< Gain L3 (0..7)
	//!
	uInt8	u8GainL4;			//!< Gain L4 (0..7)
} DDC_CONFIG_PARAMS, *PDDC_CONFIG_PARAMS;


//! \struct SCALE OVERFLOW STATUS
//! \brief This structure is used to query DDC scale overflow Staus of the CompuScope system.
//!

typedef struct
{
	BOOL		bGainL1_OverFlow;			// Flag to notify GainL1_Overflow
	BOOL		bGainL2_OverFlow;			// Flag to notify GainL2_Overflow
	BOOL		bGainL3_OverFlow;			// Flag to notify GainL3_Overflow
	BOOL		bGainL4_OverFlow;			// Flag to notify GainL4_Overflow
} DDC_SCALE_OVERFLOW_STATUS, *PDDC_SCALE_OVERFLOW_STATUS;


//! \struct DDC_CORE_CONFIG
//! \brief This structure is used to set or query DDC Core settings of the CompuScope system.
//!
typedef struct
{
	//!
	uInt32	u32NCOFreq;			//!< NCO Freq in Khz
	//!
	uInt16	u16CICDecimation;	//!< CIC Decimation Value
	//!
	uInt8	u8MagGain;			//!< Magniture gain
	//!
	uInt8	u8CICNormFactor;	//!< ext PORT CIC Norm Factor

} DDC_CORE_CONFIG, *PDDC_CORE_CONFIG;


//! \struct DDC_FIR_COEF_CONFIG
//! \brief This structure is used to set or query DDC FIR Coefficient Table of the CompuScope system.
//!
typedef struct
{
	//!
	uInt32		u32Size;			//!<  Total size, in Bytes, of the structure.
	//!
	double		r64Coef[96];	//!< Array of Coefficient element

} DDC_FIR_COEF_CONFIG, *PDDC_FIR_COEF_CONFIG;

//! \struct DDC_CFIR_COEF_CONFIG
//! \brief This structure is used to set or query DDC CFIR Coefficient Table of the CompuScope system.
//!
typedef struct
{
	//!
	uInt32		u32Size;		//!<  Total size, in Bytes, of the structure.
	//!
	double		r64Coef[21];	//!< Array of Coefficient element

} DDC_CFIR_COEF_CONFIG, *PDDC_CFIR_COEF_CONFIG;

//! \struct DDC_PFIR_COEF_CONFIG
//! \brief This structure is used to set or query DDC PFIR Coefficient Table of the CompuScope system.
//!
typedef struct
{
	//!
	uInt32		u32Size;		//!<  Total size, in Bytes, of the structure.
	//!
	double		r64Coef[63];	//!< Array of Coefficient element

} DDC_PFIR_COEF_CONFIG, *PDDC_PFIR_COEF_CONFIG;


typedef struct _CSOCT_CONFIG_PARAMS
{
	uInt8	u8Slope;				// Trigger slope : 0=Neg, 1=Pos
	int8	i8Level;				// Trigger voltage level in % (-100,100)
	uInt8	u8Hysteresis;			// Trigger Hysteresis
	uInt8	u8PhyMode;			    // OCT Mode: 0=Clock on Chan 1,Sample on Chan 0, 1=inverse
} CSOCT_CONFIG_PARAMS, *PCSOCT_CONFIG_PARAMS;

#pragma pack()

// Action Id for use in CsExpertCall()
// 
#define		EXFN_CREATEMINMAXQUEUE		1	// MinMaxDetect: Create segment info Minmax queue
#define		EXFN_DESTROYMINMAXQUEUE		2	// MinMaxDetect: Destroy segment info Minmax queue
#define		EXFN_GETSEGMENTINFO			3	// MinMaxDetect: Get Segment Info
#define		EXFN_CLEARERRORMINMAXQUEUE  4	// MinMaxDetect: Clear Error on MinMax Internal Queue

#define		EXFN_CASCADESTREAM_CONFIG				5		// CascadeStream: Configuration
#define		EXFN_CASCADESTREAM_RELEASE				6		// CascadeStream: Release resources 
#define		EXFN_CASCADESTREAM_GETCHANNELDATA		7		// CascadeStream: Get Channels Data
#define		EXFN_CASCADESTREAM_CHANNELSDATAREAD		8		// CascadeStream: Notify driver for channels Data Read
#define		EXFN_RAWMULREC_TRANSFER					9		// Raw Nulrec: Save Multiple record data in raw data mode

#define		EXFX_DISK_STREAM_MASK			0x60000000
#define		EXFN_DISK_STREAM_INITIALIZE		10 | EXFX_DISK_STREAM_MASK	// DiskStream: Initialize the subsystem
#define		EXFN_DISK_STREAM_START			11 | EXFX_DISK_STREAM_MASK	// DiskStream: Start capturing and transferring data
#define		EXFN_DISK_STREAM_STATUS			12 | EXFX_DISK_STREAM_MASK	// DiskStream: Retrieve whether or not we're finished
#define		EXFN_DISK_STREAM_STOP			13 | EXFX_DISK_STREAM_MASK	// DiskStream: Abort any pending captures, transfers or writes
#define		EXFN_DISK_STREAM_CLOSE			14 | EXFX_DISK_STREAM_MASK	// DiskStream: Close the subsystem and clean up an allocated resources
#define		EXFN_DISK_STREAM_ACQ_COUNT		15 | EXFX_DISK_STREAM_MASK	// DiskStream: Return the number of acquisitions performed so far
#define		EXFN_DISK_STREAM_WRITE_COUNT	16 | EXFX_DISK_STREAM_MASK	// DiskStream: Return the number of completed file writes so far
#define		EXFN_DISK_STREAM_ERRORS			17 | EXFX_DISK_STREAM_MASK	// DiskStream: Return the last error
#define		EXFN_DISK_STREAM_TIMING_FLAG	18 | EXFX_DISK_STREAM_MASK	// DiskStream: Flag to enable timing statistics
#define		EXFN_DISK_STREAM_TIMING_STATS	19 | EXFX_DISK_STREAM_MASK	// DiskStream: Return the timing statistics, if available


#define		EXFN_STREAM_INIT			20	// Streaming config and initialize
#define		EXFN_STREAM_CLEANUP			21	// Streaming cleanup resources
#define		EXFN_STREAM_START			22	// Start acquisiton in stream mode
#define		EXFN_STREAM_GETSTATUS		23	// Streaming Get status
#define		EXFN_STREAM_ABORT			24	// Streaming Stop or Abort
#define		EXFN_STREAM_TEST1			25	// Streaming Stop or Abort
#define		EXFN_STREAM_TEST2			26	// Streaming Stop or Abort



// Live streaming Status
// Error flags cound be returned by the function CsStmGetTransferStatus()
#define	STM_TRANSFER_ERROR_FIFOFULL					1
#define	STM_TRANSFER_ERROR_CHANNEL_PROTECTION		2



#endif

/////////////////////////////////////////////////////////////
//! \file CsPrototypes.h
//!    \brief Gage Application Programming Interface (API)
//!
/////////////////////////////////////////////////////////////

#ifndef _GAGE_CS_PROTOTYPES_H_
#define _GAGE_CS_PROTOTYPES_H_

#pragma once
////

// the include files need to be included before we use __cplusplus or the compiler (at  least gcc)
// complains aoubt C linkage of template items
#include "CsTypes.h"
#include "CsStruct.h"
#include "CsDefines.h"
#include "CsErrors.h"

#ifdef __cplusplus
extern "C"{
#endif

#ifdef __linux__
#define SSM_API
#define FS_API
#include <wchar.h>
#else
#define SSM_API __stdcall			// Function exported by CsSsm.dll
#define FS_API	__stdcall			// Function exported by CsFs.dll
#endif


// Initialization function
int32 SSM_API CsInitialize(void);
int32 SSM_API CsGetSystem(CSHANDLE* phSystem, uInt32 u32BoardType, uInt32 u32Channels, uInt32 u32SampleBits, int16 i16Index );
int32 SSM_API CsFreeSystem(CSHANDLE);

// Configuration
int32 SSM_API CsGet(CSHANDLE hSystem, int32 nIndex, int32 nConfig, void* pData);
int32 SSM_API CsSet(CSHANDLE hSystem, int32 nIndex, const void* const pData);
int32 SSM_API CsGetStatusEx(CSHANDLE hSystem, int32 nIndex, void* pData);
int32 SSM_API CsGetSystemInfo(CSHANDLE hSystem, PCSSYSTEMINFO pSystemInfo);
int32 SSM_API CsGetSystemCaps(CSHANDLE hSystem, uInt32 CapsId, void* pBuffer, uInt32* BufferSize);


// Actions
int32 SSM_API CsDo(CSHANDLE hSystem, int16 i16Operation);

// Transfer
int32 SSM_API CsTransfer(CSHANDLE hSystem, PIN_PARAMS_TRANSFERDATA pInData, POUT_PARAMS_TRANSFERDATA outData);
int32 SSM_API CsTransferEx(CSHANDLE hSystem, PIN_PARAMS_TRANSFERDATA_EX pInData, POUT_PARAMS_TRANSFERDATA_EX outData);

// Status
#ifdef _WIN32
	int32 SSM_API CsGetEventHandle(CSHANDLE hSystem, uInt32 u32EventType, EVENT_HANDLE* phEvent);
#else
	int32 SSM_API CsGetEventHandle(CSHANDLE hSystem, uInt32 u32EventType, int* phEvent);
#endif /* _WIN32 */

int32 SSM_API CsGetStatus(CSHANDLE hSystem);

// Support
int32 SSM_API CsGetErrorStringA(int32 i32ErrorCode, LPSTR lpBuffer, int nBufferMax);
int32 SSM_API CsGetErrorStringW(int32 i32ErrorCode, wchar_t* lpBuffer, int nBufferMax);

#ifndef SSM_EXPORTS
	#if defined (_UNICODE) || defined (UNICODE)
		#define CsGetErrorString CsGetErrorStringW
	#else
		#define CsGetErrorString CsGetErrorStringA
	#endif
#endif


///////////////////////////
// Expert functionnality
///////////////////////////

// Asynchronous transfer
int32 SSM_API CsTransferAS(CSHANDLE hSystem, PIN_PARAMS_TRANSFERDATA pInData, POUT_PARAMS_TRANSFERDATA	pOutParams, int32* pToken);
int32 SSM_API CsGetTransferASResult(CSHANDLE hSystem, int32 nChannelIndex, int64* pi64Results);


// Streaming operation
int32 SSM_API CsStmAllocateBuffer( CSHANDLE CsHandle, uInt16 nCardIndex, uInt32 u32BufferSize, PVOID *pVa );
int32 SSM_API CsStmFreeBuffer( CSHANDLE CsHandle, uInt16 nCardIndex, PVOID pVa );
int32 SSM_API CsStmTransferToBuffer( CSHANDLE CsHandle, uInt16 nCardIndex, PVOID pBuffer, uInt32 u32TransferSize );
int32 SSM_API CsStmGetTransferStatus( CSHANDLE CsHandle, uInt16 nCardIndex, uInt32 u32WaitTimeoutMs, uInt32 *u32ErrorFlag, uInt32 *u32ActualSize, PVOID Reserved );

int32 SSM_API CsRegisterCallbackFnc(CSHANDLE hSystem, uInt32 u32Event, LPCsEventCallback pCallBack);
int32 SSM_API CsExpertCall(CSHANDLE hSystem, PVOID pFunctionParams);

///////////////////////////
// GageScope SIG file functionality
///////////////////////////

#ifdef __linux__
	int32 SSM_API CsConvertToSigHeader(PCSDISKFILEHEADER pHeader, PCSSIGSTRUCT pSigStruct, char* szComment, char* szName);
	int32 SSM_API CsConvertFromSigHeader(PCSDISKFILEHEADER pHeader, PCSSIGSTRUCT pSigStruct, char* szComment, char* szName);
#else
	int32 SSM_API CsConvertToSigHeader(PCSDISKFILEHEADER pHeader, PCSSIGSTRUCT pSigStruct, TCHAR* szComment, TCHAR* szName);
	int32 SSM_API CsConvertFromSigHeader(PCSDISKFILEHEADER pHeader, PCSSIGSTRUCT pSigStruct, TCHAR* szComment, TCHAR* szName);
#endif

// Retrieve Channel data from raw data buffer
int32 FS_API  CsRetrieveChannelFromRawBuffer(   PVOID	pMulrecRawDataBuffer,
												int64	i64RawDataBufferSize,
												uInt32	u32SegmentId,
												uInt16	ChannelIndex,
												int64	i64Start,
												int64	i64Length,
												PVOID	pNormalizedDataBuffer,
												int64	*i64TrigTimeStamp,
												int64	*i64ActualStart,
												int64	*i64ActualLength );


#ifdef __cplusplus
}
#endif

#endif // _GAGE_CS_PROTOTYPES_H_

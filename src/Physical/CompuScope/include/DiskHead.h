/////////////////////////////////////////////////////////////
//! \file Diskhead.h
//!    \brief sig file header
//!
/////////////////////////////////////////////////////////////

#pragma once

#include "CsTypes.h"

#ifdef __LINUX_KNL__
	#include <linux/limits.h>
#else
	#include	<limits.h>
#endif

/***********************************************************************\
*																		*
*	DISK FILE HEADER FOR ROUTINES TO TRANSFER TRACES TO / FROM DISK.	*
*																		*
\***********************************************************************/

#ifndef FILE_VERSION
#define	FILE_VERSION		"GS V.3.00"
#endif

#define	DISK_FILE_HEADER_SIZE	512
#define	DISK_FILE_FILEVERSIZE	14
#define	DISK_FILE_CHANNAMESIZE	9	/*	8 + NULL.  */
#define	DISK_FILE_COMMENT_SIZE	256
#define	DISK_FILE_MISC_SIZE		8
#define	DISK_FILE_SYSTEM_SIZE	42	/*  Note: data split into six areas.  */
#define	DISK_FILE_CHANNEL_SIZE	36	/*  Note: data split into three areas.  */
#define	DISK_FILE_DISPLAY_SIZE	43	/*  Note: data split into five areas.  */
#define	DISK_FILE_HEADER_PAD	(DISK_FILE_HEADER_SIZE - (DISK_FILE_FILEVERSIZE +	\
								DISK_FILE_CHANNAMESIZE + DISK_FILE_COMMENT_SIZE + 	\
								DISK_FILE_MISC_SIZE + DISK_FILE_SYSTEM_SIZE + 		\
								DISK_FILE_CHANNEL_SIZE + DISK_FILE_DISPLAY_SIZE))
#ifndef __linux__
#pragma pack (1)
#endif

typedef struct  {

	char	file_version[DISK_FILE_FILEVERSIZE];
	int16	crlf1;								/*	DISK_FILE_MISC_SIZE	*/
	char	name[DISK_FILE_CHANNAMESIZE];
	int16	crlf2;								/*	DISK_FILE_MISC_SIZE	*/
	char	comment[DISK_FILE_COMMENT_SIZE];
	int16	crlf3;								/*	DISK_FILE_MISC_SIZE	*/
	int16	control_z;							/*	DISK_FILE_MISC_SIZE	*/

	int16	sample_rate_index;					/*	DISK_FILE_SYSTEM_SIZE	*/
	int16	operation_mode;						/*	DISK_FILE_SYSTEM_SIZE	*/
	int32	trigger_depth;						/*	DISK_FILE_SYSTEM_SIZE	*/
	int16	trigger_slope;						/*	DISK_FILE_SYSTEM_SIZE	*/
	int16	trigger_source;						/*	DISK_FILE_SYSTEM_SIZE	*/
	int16	trigger_level;						/*	DISK_FILE_SYSTEM_SIZE	*/
	int32	sample_depth;						/*	DISK_FILE_SYSTEM_SIZE	*/

	int16	captured_gain;						/*	DISK_FILE_CHANNEL_SIZE	*/
	int16	captured_coupling;					/*	DISK_FILE_CHANNEL_SIZE	*/
	int32	current_mem_ptr;					/*	DISK_FILE_CHANNEL_SIZE	*/
	int32	starting_address;					/*	DISK_FILE_CHANNEL_SIZE	*/
	int32	trigger_address;					/*	DISK_FILE_CHANNEL_SIZE	*/
	int32	ending_address;						/*	DISK_FILE_CHANNEL_SIZE	*/
	uInt16	trigger_time;						/*	DISK_FILE_CHANNEL_SIZE	*/
	uInt16	trigger_date;						/*	DISK_FILE_CHANNEL_SIZE	*/

	int16	trigger_coupling;					/*	DISK_FILE_SYSTEM_SIZE	*/
	int16	trigger_gain;						/*	DISK_FILE_SYSTEM_SIZE	*/

	int16	probe;								/*	DISK_FILE_CHANNEL_SIZE	*/

	int16	inverted_data;						/*  DISK_FILE_DISPLAY_SIZE  */
	uInt16	board_type;							/*  DISK_FILE_DISPLAY_SIZE  */
	int16	resolution_12_bits;					/*  DISK_FILE_DISPLAY_SIZE  */
												/*	Used when saving 12-bit data.	*/

	int16	multiple_record;					/*	DISK_FILE_SYSTEM_SIZE	*/
	int16	trigger_probe;						/*	DISK_FILE_SYSTEM_SIZE	*/

	int16	sample_offset;						/*  DISK_FILE_DISPLAY_SIZE  */
	int16	sample_resolution;					/*  DISK_FILE_DISPLAY_SIZE  */
	int16	sample_bits;						/*  DISK_FILE_DISPLAY_SIZE  */

	uInt32	extended_trigger_time;				/*	DISK_FILE_CHANNEL_SIZE	*/
	int16	imped_a;							/*	DISK_FILE_CHANNEL_SIZE	*/
	int16	imped_b;							/*	DISK_FILE_CHANNEL_SIZE	*/

	float	external_tbs;						/*	DISK_FILE_SYSTEM_SIZE	*/
	float	external_clock_rate;				/*	DISK_FILE_SYSTEM_SIZE	*/

	uInt32	file_options;						/*	DISK_FILE_DISPLAY_SIZE	*/
	uInt16	version;							/*  DISK_FILE_DISPLAY_SIZE  */
	uInt32	eeprom_options;						/*  DISK_FILE_DISPLAY_SIZE  */

	uInt32	trigger_hardware;					/*	DISK_FILE_SYSTEM_SIZE	*/

	uInt32	record_depth;						/*  DISK_FILE_DISPLAY_SIZE  */
	int32	sample_offset_32;	 				/*  DISK_FILE_DISPLAY_SIZE  */
	int32	sample_resolution_32;				/*  DISK_FILE_DISPLAY_SIZE  */
	uInt32	multiple_record_count;				/*	DISK_FILE_SYSTEM_SIZE	*/
	int16   dc_offset;							/*	DISK_FILE_CHANNEL_SIZE	*/
	float   UnitFactor;							/*  DISK_FILE_DISPLAY_SIZE  */
	char    UnitString[5];						/*  DISK_FILE_DISPLAY_SIZE  */

	uInt8	padding[DISK_FILE_HEADER_PAD];

#ifdef __linux__
}__attribute__ ((packed)) disk_file_header;
#else
} disk_file_header;
#pragma pack ()
#endif

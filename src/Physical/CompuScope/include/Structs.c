/********************************************************\
*   STRUCTS.C	    VERSION 3.80.00						*
*                                                       *                                                       *
*   COPYRIGHT (C) GAGE APPLIED TECHNOLOGIES INC         *
*                                                       *
*	LAST UPDATE:		10/28/04                        *
\********************************************************/

/*----------------------------------------------------------*/

#define	STRUCTS_SOURCE

/*----------------------------------------------------------*/


/*----------------------------------------------------------*/

#ifdef	WINDOWS_CODE

#ifndef _CVI_
#include 	<windows.h>
#else
#include	<ansi_c.h>
#endif

#endif

#ifndef __linux__
	#include	<math.h>
	#include	<stdio.h>
	#include	<string.h>
	#ifndef _CVI_
	#ifdef		__DOS_16__
	#include	<alloc.h>
	#else
	#include	<malloc.h>
	#endif
	#endif	//_CVI_
#else 	/* __linux__ */
	#ifdef __LINUX_KNL__
		#include <linux/kernel.h>
		#define  __NO_VERSION__
		#include <linux/module.h>
		#include <linux/string.h>
		#include <linux/fcntl.h>

	#else   /* __LINUX_KNL__ */
		#include	<string.h>
		#include	<math.h>
		#include	<stdio.h>
		#include	<stdlib.h>
	#endif  /* __LINUX_KNL__ */
	#ifndef lstrcpy
		#define lstrcpy strcpy
	#endif
#endif 	/*__linux__*/


double value_ECL = -2.0;
double value_PECL = 3.0;
double value_LVDS = 0.0;
double value_TTL = 1.35;
double value_CMOS = 2.5;

/*----------------------------------------------------------*/

#include	"gage_drv.h"
#include	"Structs.h"


/*----------------------------------------------------------*/

/*	Useful program structures and variables.	*/

/*----------------------------------------------------------*/

#ifdef	__BOARD_DEF__

boarddef	board = {
	5000000L,
	GAGE_DUAL_CHAN, DEFAULT_SAMPLE_RATE_INDEX,
	GAGE_PM_1_V, GAGE_DC, GAGE_PM_1_V, GAGE_DC,
	GAGE_1_MOHM_INPUT, GAGE_1_MOHM_INPUT,
	0, 0,
	GAGE_CHAN_A, GAGE_POSITIVE, 128, GAGE_PM_1_V, GAGE_DC,
	GAGE_SOFTWARE, GAGE_POSITIVE, 128,	/*	Disable second trigger source.	*/
	GAGE_POST_8K
};

int			board_number = 1;

boarddef	boards[GAGE_B_L_MAX_CARDS] = {
	{
	5000000L,
	GAGE_DUAL_CHAN, DEFAULT_SAMPLE_RATE_INDEX,
	GAGE_PM_1_V, GAGE_DC, GAGE_PM_1_V, GAGE_DC,
	GAGE_1_MOHM_INPUT, GAGE_1_MOHM_INPUT,
	0, 0,
	GAGE_CHAN_A, GAGE_POSITIVE, 128, GAGE_PM_1_V, GAGE_DC,
	GAGE_SOFTWARE, GAGE_POSITIVE, 128,	/*	Disable second trigger source.	*/
	GAGE_POST_8K
	},
	{
	5000000L,
	GAGE_DUAL_CHAN, DEFAULT_SAMPLE_RATE_INDEX,
	GAGE_PM_1_V, GAGE_DC, GAGE_PM_1_V, GAGE_DC,
	GAGE_1_MOHM_INPUT, GAGE_1_MOHM_INPUT,
	0, 0,
	GAGE_CHAN_A, GAGE_POSITIVE, 128, GAGE_PM_1_V, GAGE_DC,
	GAGE_SOFTWARE, GAGE_POSITIVE, 128,	/*	Disable second trigger source.	*/
	GAGE_POST_8K
	},
	{
	5000000L,
	GAGE_DUAL_CHAN, DEFAULT_SAMPLE_RATE_INDEX,
	GAGE_PM_1_V, GAGE_DC, GAGE_PM_1_V, GAGE_DC,
	GAGE_1_MOHM_INPUT, GAGE_1_MOHM_INPUT,
	0, 0,
	GAGE_CHAN_A, GAGE_POSITIVE, 128, GAGE_PM_1_V, GAGE_DC,
	GAGE_SOFTWARE, GAGE_POSITIVE, 128,	/*	Disable second trigger source.	*/
	GAGE_POST_8K
	},
	{
	5000000L,
	GAGE_DUAL_CHAN, DEFAULT_SAMPLE_RATE_INDEX,
	GAGE_PM_1_V, GAGE_DC, GAGE_PM_1_V, GAGE_DC,
	GAGE_1_MOHM_INPUT, GAGE_1_MOHM_INPUT,
	0, 0,
	GAGE_CHAN_A, GAGE_POSITIVE, 128, GAGE_PM_1_V, GAGE_DC,
	GAGE_SOFTWARE, GAGE_POSITIVE, 128,	/*	Disable second trigger source.	*/
	GAGE_POST_8K
	},
	{
	5000000L,
	GAGE_DUAL_CHAN, DEFAULT_SAMPLE_RATE_INDEX,
	GAGE_PM_1_V, GAGE_DC, GAGE_PM_1_V, GAGE_DC,
	GAGE_1_MOHM_INPUT, GAGE_1_MOHM_INPUT,
	0, 0,
	GAGE_CHAN_A, GAGE_POSITIVE, 128, GAGE_PM_1_V, GAGE_DC,
	GAGE_SOFTWARE, GAGE_POSITIVE, 128,	/*	Disable second trigger source.	*/
	GAGE_POST_8K
	},
	{
	5000000L,
	GAGE_DUAL_CHAN, DEFAULT_SAMPLE_RATE_INDEX,
	GAGE_PM_1_V, GAGE_DC, GAGE_PM_1_V, GAGE_DC,
	GAGE_1_MOHM_INPUT, GAGE_1_MOHM_INPUT,
	0, 0,
	GAGE_CHAN_A, GAGE_POSITIVE, 128, GAGE_PM_1_V, GAGE_DC,
	GAGE_SOFTWARE, GAGE_POSITIVE, 128,	/*	Disable second trigger source.	*/
	GAGE_POST_8K
	},
	{
	5000000L,
	GAGE_DUAL_CHAN, DEFAULT_SAMPLE_RATE_INDEX,
	GAGE_PM_1_V, GAGE_DC, GAGE_PM_1_V, GAGE_DC,
	GAGE_1_MOHM_INPUT, GAGE_1_MOHM_INPUT,
	0, 0,
	GAGE_CHAN_A, GAGE_POSITIVE, 128, GAGE_PM_1_V, GAGE_DC,
	GAGE_SOFTWARE, GAGE_POSITIVE, 128,	/*	Disable second trigger source.	*/
	GAGE_POST_8K
	},
	{
	5000000L,
	GAGE_DUAL_CHAN, DEFAULT_SAMPLE_RATE_INDEX,
	GAGE_PM_1_V, GAGE_DC, GAGE_PM_1_V, GAGE_DC,
	GAGE_1_MOHM_INPUT, GAGE_1_MOHM_INPUT,
	0, 0,
	GAGE_CHAN_A, GAGE_POSITIVE, 128, GAGE_PM_1_V, GAGE_DC,
	GAGE_SOFTWARE, GAGE_POSITIVE, 128,	/*	Disable second trigger source.	*/
	GAGE_POST_8K
	},
	{
	5000000L,
	GAGE_DUAL_CHAN, DEFAULT_SAMPLE_RATE_INDEX,
	GAGE_PM_1_V, GAGE_DC, GAGE_PM_1_V, GAGE_DC,
	GAGE_1_MOHM_INPUT, GAGE_1_MOHM_INPUT,
	0, 0,
	GAGE_CHAN_A, GAGE_POSITIVE, 128, GAGE_PM_1_V, GAGE_DC,
	GAGE_SOFTWARE, GAGE_POSITIVE, 128,	/*	Disable second trigger source.	*/
	GAGE_POST_8K
	},
	{
	5000000L,
	GAGE_DUAL_CHAN, DEFAULT_SAMPLE_RATE_INDEX,
	GAGE_PM_1_V, GAGE_DC, GAGE_PM_1_V, GAGE_DC,
	GAGE_1_MOHM_INPUT, GAGE_1_MOHM_INPUT,
	0, 0,
	GAGE_CHAN_A, GAGE_POSITIVE, 128, GAGE_PM_1_V, GAGE_DC,
	GAGE_SOFTWARE, GAGE_POSITIVE, 128,	/*	Disable second trigger source.	*/
	GAGE_POST_8K
	},
	{
	5000000L,
	GAGE_DUAL_CHAN, DEFAULT_SAMPLE_RATE_INDEX,
	GAGE_PM_1_V, GAGE_DC, GAGE_PM_1_V, GAGE_DC,
	GAGE_1_MOHM_INPUT, GAGE_1_MOHM_INPUT,
	0, 0,
	GAGE_CHAN_A, GAGE_POSITIVE, 128, GAGE_PM_1_V, GAGE_DC,
	GAGE_SOFTWARE, GAGE_POSITIVE, 128,	/*	Disable second trigger source.	*/
	GAGE_POST_8K
	},
	{
	5000000L,
	GAGE_DUAL_CHAN, DEFAULT_SAMPLE_RATE_INDEX,
	GAGE_PM_1_V, GAGE_DC, GAGE_PM_1_V, GAGE_DC,
	GAGE_1_MOHM_INPUT, GAGE_1_MOHM_INPUT,
	0, 0,
	GAGE_CHAN_A, GAGE_POSITIVE, 128, GAGE_PM_1_V, GAGE_DC,
	GAGE_SOFTWARE, GAGE_POSITIVE, 128,	/*	Disable second trigger source.	*/
	GAGE_POST_8K
	},
	{
	5000000L,
	GAGE_DUAL_CHAN, DEFAULT_SAMPLE_RATE_INDEX,
	GAGE_PM_1_V, GAGE_DC, GAGE_PM_1_V, GAGE_DC,
	GAGE_1_MOHM_INPUT, GAGE_1_MOHM_INPUT,
	0, 0,
	GAGE_CHAN_A, GAGE_POSITIVE, 128, GAGE_PM_1_V, GAGE_DC,
	GAGE_SOFTWARE, GAGE_POSITIVE, 128,	/*	Disable second trigger source.	*/
	GAGE_POST_8K
	},
	{
	5000000L,
	GAGE_DUAL_CHAN, DEFAULT_SAMPLE_RATE_INDEX,
	GAGE_PM_1_V, GAGE_DC, GAGE_PM_1_V, GAGE_DC,
	GAGE_1_MOHM_INPUT, GAGE_1_MOHM_INPUT,
	0, 0,
	GAGE_CHAN_A, GAGE_POSITIVE, 128, GAGE_PM_1_V, GAGE_DC,
	GAGE_SOFTWARE, GAGE_POSITIVE, 128,	/*	Disable second trigger source.	*/
	GAGE_POST_8K
	},
	{
	5000000L,
	GAGE_DUAL_CHAN, DEFAULT_SAMPLE_RATE_INDEX,
	GAGE_PM_1_V, GAGE_DC, GAGE_PM_1_V, GAGE_DC,
	GAGE_1_MOHM_INPUT, GAGE_1_MOHM_INPUT,
	0, 0,
	GAGE_CHAN_A, GAGE_POSITIVE, 128, GAGE_PM_1_V, GAGE_DC,
	GAGE_SOFTWARE, GAGE_POSITIVE, 128,	/*	Disable second trigger source.	*/
	GAGE_POST_8K
	},
	{
	5000000L,
	GAGE_DUAL_CHAN, DEFAULT_SAMPLE_RATE_INDEX,
	GAGE_PM_1_V, GAGE_DC, GAGE_PM_1_V, GAGE_DC,
	GAGE_1_MOHM_INPUT, GAGE_1_MOHM_INPUT,
	0, 0,
	GAGE_CHAN_A, GAGE_POSITIVE, 128, GAGE_PM_1_V, GAGE_DC,
	GAGE_SOFTWARE, GAGE_POSITIVE, 128,	/*	Disable second trigger source.	*/
	GAGE_POST_8K
	},
};

#endif

/*----------------------------------------------------------*/

srtype far	sample_rate_table[] = {
/*
index		rate				mult			sr_flag			rt_sr_flag	rts_sr_flag			sr_calc				sr_text.
																							Time between samples
																							(in nanoseconds)				*/
{/*	0	*/	GAGE_RATE_1,		GAGE_HZ,		( B_T_CSLITE
												| B_T_CS250
												| B_T_CS225
												| B_T_CS220
												|(B_T_CS512
												& B_T_DUAL)
												| B_T_CS1012
												| B_T_CS6012
												| B_T_CS8012),		0L,			0L,			1000000000.0F,		  "1 Hz",	},

{/*	1	*/	GAGE_RATE_2,		GAGE_HZ,		( B_T_CSLITE
												| B_T_CS250
												| B_T_CS225
												| B_T_CS220
												|(B_T_CS512
												& B_T_DUAL)
												| B_T_CS1012
												| B_T_CS6012
												| B_T_CS8012),		0L,			0L,			 500000000.0F,		  "2 Hz",	},

{/*	2	*/	GAGE_RATE_5,		GAGE_HZ,		( B_T_CSLITE
												| B_T_CS250
												| B_T_CS225
												| B_T_CS220
												|(B_T_CS512
												& B_T_DUAL)
												| B_T_CS1012
												| B_T_CS6012
												| B_T_CS8012
												| (B_T_CS2125
												& B_T_DUAL)),		0L,			0L,			 200000000.0F,		  "5 Hz",	},

{/*	3	*/	GAGE_RATE_10,		GAGE_HZ,		( B_T_CSLITE
												| B_T_CS250
												| B_T_CS225
												| B_T_CS220
												|(B_T_CS512
												& B_T_DUAL)
												| B_T_CS1012
												| B_T_CS6012
												| B_T_CS8012
												| B_T_CS2125),		0L,			0L,			 100000000.0F,		 "10 Hz",	},

{/*	4	*/	GAGE_RATE_20,		GAGE_HZ,		( B_T_CSLITE
												| B_T_CS250
												| B_T_CS225
												| B_T_CS220
												|(B_T_CS512
												& B_T_DUAL)
												| B_T_CS1012
												| B_T_CS6012
												| B_T_CS8012
												| B_T_CS2125),		0L,			0L,			  50000000.0F,		 "20 Hz",	},

{/*	5	*/	GAGE_RATE_50,		GAGE_HZ,		( B_T_CSLITE
												| B_T_CS250
												| B_T_CS225
												| B_T_CS220
												|(B_T_CS512
												& B_T_DUAL)
												| B_T_CS1012
												| B_T_CS6012
												| B_T_CS8012
												| B_T_CS2125
												|(B_T_CS265
												& B_T_DUAL)),		0L,			0L,			  20000000.0F,		 "50 Hz",	},

{/*	6	*/	GAGE_RATE_100,		GAGE_HZ,		( B_T_CSLITE
												| B_T_CS250
												| B_T_CS225
												| B_T_CS220
												|(B_T_CS512
												& B_T_DUAL)
												| B_T_CS1012
												| B_T_CS6012
												| B_T_CS8012
												| B_T_CS2125
												| B_T_CS265),		0L,			0L,			  10000000.0F,		"100 Hz",	},

{/*	7	*/	GAGE_RATE_200,		GAGE_HZ,		( B_T_CSLITE
												| B_T_CS250
												| B_T_CS225
												| B_T_CS220
												|(B_T_CS512
												& B_T_DUAL)
												| B_T_CS1012
												| B_T_CS6012
												| B_T_CS8012
												| B_T_CS2125
												| B_T_CS265),		0L,			0L,			   5000000.0F,		"200 Hz",	},

{/*	8	*/	GAGE_RATE_500,		GAGE_HZ,		( B_T_CSLITE
												| B_T_CS250
												| B_T_CS225
												| B_T_CS220
												|(B_T_CS512
												& B_T_DUAL)
												| B_T_CS1012
												| B_T_CS6012
												| B_T_CS8012
												| B_T_CS2125
												| B_T_CS265),		0L,			0L,			   2000000.0F,		"500 Hz",	},

{/*	9	*/	GAGE_RATE_1,		GAGE_KHZ,		( B_T_CSLITE
												| B_T_CS250
												| B_T_CS225
												| B_T_CS220
												|(B_T_CS512
												& B_T_DUAL)
												| B_T_CS1012
												| B_T_CS6012
												| B_T_CS8012
												| B_T_CS2125
												| B_T_CS265
												|(B_T_CS1016
												& B_T_SINGLE)),		0L,			0L,			   1000000.0F,		  "1 KHz",	},

{/*	10	*/	GAGE_RATE_2,		GAGE_KHZ,		( B_T_CSLITE
												| B_T_CS250
												| B_T_CS225
												| B_T_CS220
												|(B_T_CS512
												& B_T_DUAL)
												| B_T_CS1012
												| B_T_CS6012
												| B_T_CS8012
												| B_T_CS2125
												| B_T_CS265
												|(B_T_CS1016
												& B_T_SINGLE)),		0L,			0L,				500000.0F,		  "2 KHz",	},

{/*	11	*/	GAGE_RATE_5,		GAGE_KHZ,		( B_T_CSLITE
												| B_T_CS250
												| B_T_CS225
												| B_T_CS220
												|(B_T_CS512
												& B_T_DUAL)
												| B_T_CS1012
												| B_T_CS6012
												| B_T_CS8012
												| B_T_CS2125
												| B_T_CS265
												|(B_T_CS1016
												& B_T_SINGLE)),		0L,			0L,				200000.0F,		  "5 KHz",	},

{/*	12	*/	GAGE_RATE_10,		GAGE_KHZ,		( B_T_CSLITE
												| B_T_CS250
												| B_T_CS225
												| B_T_CS220
												|(B_T_CS512
												& B_T_DUAL)
												| B_T_CS1012
												| B_T_CS6012
												| B_T_CS8012
												| B_T_CS2125
												| B_T_CS265
												|(B_T_CS1016
												& B_T_SINGLE)),		0L,			0L,				100000.0F,		 "10 KHz",	},

{/*	13	*/	GAGE_RATE_20,		GAGE_KHZ,		( B_T_CSLITE
												| B_T_CS250
												| B_T_CS225
												| B_T_CS220
												|(B_T_CS512
												& B_T_DUAL)
												| B_T_CS1012
												| B_T_CS6012
												| B_T_CS8012
												| B_T_CS2125
												| B_T_CS265
												|(B_T_CS1016
												& B_T_SINGLE)),		0L,			0L,				 50000.0F,		 "20 KHz",	},

{/*	14	*/	GAGE_RATE_50,		GAGE_KHZ,		( B_T_CSLITE
												| B_T_CS250
												| B_T_CS225
												| B_T_CS220
												|(B_T_CS512
												& B_T_DUAL)
												| B_T_CS1012
												| B_T_CS6012
												| B_T_CS8012
												| B_T_CS2125
												| B_T_CS265
												|(B_T_CS1016
												& B_T_SINGLE)),		0L,			0L,				 20000.0F,		 "50 KHz",	},

{/*	15	*/	GAGE_RATE_100,		GAGE_KHZ,		( B_T_CSLITE
												| B_T_CS250
												| B_T_CS225
												| B_T_CS220
												|(B_T_CS512
												& B_T_DUAL)
												| B_T_CS1012
												| B_T_CS6012
												| B_T_CS8012
												| B_T_CS2125
												| B_T_CS265
												|(B_T_CS1016
												& B_T_SINGLE)),		0L,			0L,				 10000.0F,		"100 KHz",	},

{/*	16	*/	GAGE_RATE_200,		GAGE_KHZ,		( B_T_CSLITE
												| B_T_CS250
												| B_T_CS225
												| B_T_CS220
												|(B_T_CS512
												& B_T_DUAL)
												| B_T_CS1012
												| B_T_CS6012
												| B_T_CS8012
												| B_T_CS2125
												| B_T_CS265
												|(B_T_CS1016
												& B_T_SINGLE)),		0L,			0L,				  5000.0F,		"200 KHz",	},

{/*	17	*/	GAGE_RATE_500,		GAGE_KHZ,		( B_T_CSLITE
												| B_T_CS250
												| B_T_CS225
												| B_T_CS220
												|(B_T_CS512
												& B_T_DUAL)
												| B_T_CS1012
												| B_T_CS6012
												| B_T_CS8012
												| B_T_CS2125
												| B_T_CS265
												| B_T_CS3200
												|(B_T_CS1016
												& B_T_SINGLE)),		0L,			0L,				  2000.0F,		"500 KHz",	},

{/*	18	*/	GAGE_RATE_1,		GAGE_MHZ,		( B_T_CSLITE
												| B_T_CS250
												| B_T_CS225
												| B_T_CS220
												|(B_T_CS512
												& B_T_DUAL)
												| B_T_CS1012
												| B_T_CS6012
												| B_T_CS8012
												| B_T_CS2125
												| B_T_CS265
												| B_T_CS3200
												|(B_T_CS1016
												& B_T_SINGLE)),		0L,			0L,				  1000.0F,		  "1 MHz",	},

{/*	19	*/	GAGE_RATE_2,		GAGE_MHZ,		( B_T_CSLITE
												| B_T_CS250
												|(B_T_CS225
												& B_T_SINGLE)
												| B_T_CS220
												| B_T_CS1012
												| B_T_CS6012
												| B_T_CS8012
												| B_T_CS2125
												| B_T_CS265
												| B_T_CS3200
												|(B_T_CS1016
												& B_T_SINGLE)),		0L,			0L,				   500.0F,		  "2 MHz",	},


{/*	20	*/	GAGE_RATE_2500,		GAGE_KHZ,		((B_T_CS1610)
												& B_T_DUAL),		0L,			0L,				   400.0F,		  "2.5 MHz",	},





{/*	21	*/	GAGE_RATE_5,		GAGE_MHZ,		( B_T_CSLITE
												| B_T_CS250
												| B_T_CS225
												| B_T_CS220
												|(B_T_CS512
												& B_T_DUAL)
												| B_T_CS1012
												| B_T_CS6012
												| B_T_CS8012
												| B_T_CS2125
												| B_T_CS265
												| B_T_CS3200
												|(B_T_CS1016
												& B_T_SINGLE)),		0L,			0L,				   200.0F,		  "5 MHz",	},

{/*	22	*/	GAGE_RATE_10,		GAGE_MHZ,		( B_T_CSLITE
												| B_T_CS250
												|(B_T_CS225
												& B_T_SINGLE)
												| B_T_CS220
												| B_T_CS1012
												| B_T_CS6012
												| B_T_CS8012
												| B_T_CS2125
												| B_T_CS265
												| B_T_CS3200
												|(B_T_CS1016
												& B_T_SINGLE)),		0L,			0L,				   100.0F,		 "10 MHz",	},

{/*	23	*/	GAGE_RATE_12500,	GAGE_KHZ,		((B_T_CS225
												& B_T_DUAL)),		0L,			0L,					80.0F,		 "12.5 MHz",},

{/*	24	*/	GAGE_RATE_20,		GAGE_MHZ,		( B_T_CSLITE
												| B_T_CS220
												| B_T_CS2125
												| B_T_CS8012
												| B_T_CS3200
											   |((B_T_CS1012
												| B_T_CS6012)
												& B_T_SINGLE)
												|(B_T_CS265
												& B_T_SINGLE)),		0L,			0L,					50.0F,		 "20 MHz",	},

{/*	25	*/	GAGE_RATE_25,		GAGE_MHZ,		( B_T_CS250
												| B_T_CS225
												| B_T_CS3200
												|(B_T_CS8500
												& B_T_SINGLE)
												|(B_T_CS265
												& B_T_DUAL)),		0L,			0L,					40.0F,		 "25 MHz",	},

{/*	26	*/	GAGE_RATE_30,		GAGE_MHZ,		( B_T_CS6012
												| B_T_CS2125),		0L,			0L,			100.0F / 3.0F,		 "30 MHz",	},

{/*	27	*/	GAGE_RATE_40,		GAGE_MHZ,		( B_T_CS8012
											   |((B_T_CSLITE
												| B_T_CS220)
												& B_T_SINGLE)),		0L,			0L,					25.0F,		 "40 MHz",	},

{/*	28	*/	GAGE_RATE_50,		GAGE_MHZ,		( B_T_CS250
												| B_T_CS2125
												| B_T_CS3200
												|(B_T_CS8500
												& B_T_SINGLE)
												|(B_T_CS225
												& B_T_SINGLE)
												| B_T_CS265),		0L,			0L,					20.0F,		 "50 MHz",	},

{/*	29	*/	GAGE_RATE_60,		GAGE_MHZ,		( B_T_CS2125
												|(B_T_CS6012
												& B_T_SINGLE)),		0L,			0L,			100.0F / 6.0F,		 "60 MHz",	},

{/*	30	*/	GAGE_RATE_65,		GAGE_MHZ,		((B_T_CS265
												& B_T_DUAL)),		0L,			0L,			100.0F / 6.5F,		 "65 MHz",	},

{/*	31	*/	GAGE_RATE_80,		GAGE_MHZ,		( B_T_CS8012
												& B_T_SINGLE),		0L,			0L,			100.0F / 8.0F,		 "80 MHz",	},

{/*	32	*/	GAGE_RATE_100,		GAGE_MHZ,		((B_T_CS250
												| B_T_CS2125
												| B_T_CS265
												| B_T_CS8500)
												& B_T_SINGLE)
												| B_T_CS3200,		0L,			0L,					10.0F,		"100 MHz",	},

{/*	33	*/	GAGE_RATE_120,		GAGE_MHZ,		( B_T_CS2125
												& B_T_SINGLE),		0L,			0L,		   100.0F / 12.0F,		"120 MHz",	},

{/*	34	*/	GAGE_RATE_125,		GAGE_MHZ,		((B_T_CS2125
												& B_T_DUAL)
												|(B_T_CS8500
												& B_T_SINGLE)),		0L,			0L,					 8.0F,		"125 MHz",	},

{/*	35	*/	GAGE_RATE_130,		GAGE_MHZ,		((B_T_CS265
												& B_T_SINGLE)),		0L,			0L,		   100.0F / 13.0F,		"130 MHz",	},

{/*	36	*/	GAGE_RATE_150,		GAGE_MHZ,		( B_T_NONE),		0L,			0L,			 20.0F / 3.0F,		"150 MHz",	},	/*	FOR FUTURE SUPPORT ONLY.	*/

{/*	37	*/	GAGE_RATE_200,		GAGE_MHZ,		( B_T_CS8500
												& B_T_SINGLE),		0L,			0L,					 5.0F,		"200 MHz",	},	/*	FOR FUTURE SUPPORT ONLY.	*/

{/*	38	*/	GAGE_RATE_250,		GAGE_MHZ,		((B_T_CS2125
												| B_T_CS8500)
												& B_T_SINGLE),		0L,			0L,					 4.0F,		"250 MHz",	},	/*	DUAL IS EQUIVALENT TIME SAMPLING ONLY.	*/

{/*	39	*/	GAGE_RATE_300,		GAGE_MHZ,		( B_T_NONE),		0L,			0L,			 10.0F / 3.0F,		"300 MHz",	},	/*	FOR FUTURE SUPPORT ONLY.	*/

{/*	40	*/	GAGE_RATE_500,		GAGE_MHZ,		( B_T_CS8500
												& B_T_SINGLE),		0L,			0L,					 2.0F,		"500 MHz",	},	/*	DUAL IS EQUIVALENT TIME SAMPLING ONLY.	*/

{/*	41	*/	GAGE_RATE_1,		GAGE_GHZ,		( B_T_NONE),		0L,			0L,					 1.0F,		  "1 GHz",	},	/*	DUAL IS EQUIVALENT TIME SAMPLING ONLY.	*/

{/*	42	*/	GAGE_RATE_2,		GAGE_GHZ,		( B_T_NONE),		0L,			0L,					 0.5F,		  "2 GHz",	},	/*	DUAL IS EQUIVALENT TIME SAMPLING ONLY.	*/
{/*	43	*/	GAGE_RATE_2500,		GAGE_MHZ,		( B_T_NONE),		0L,			0L,					0.4F,		  "2.5 GHz",	},	/*	DUAL IS EQUIVALENT TIME SAMPLING ONLY.	*/
{/*	44	*/	GAGE_RATE_5,		GAGE_GHZ,		( B_T_NONE),		0L,			0L,					 0.2F,		  "5 GHz",	},	/*	DUAL IS EQUIVALENT TIME SAMPLING ONLY.	*/

{/*	45	*/	GAGE_RATE_8,		GAGE_GHZ,		( B_T_NONE),		0L,			0L,				   0.125F,		  "8 GHz",	},	/*	DUAL IS EQUIVALENT TIME SAMPLING ONLY.	*/

{/*	46	*/	GAGE_RATE_10,		GAGE_GHZ,		( B_T_NONE),		0L,			0L,					 0.1F,		 "10 GHz",	},	/*	DUAL IS EQUIVALENT TIME SAMPLING ONLY.	*/

{/*	47	*/	0,					GAGE_EXT_CLK,	( B_T_CSLITE
												| B_T_CS250
												| B_T_CS225
												| B_T_CS220
												|(B_T_CS512
												& B_T_DUAL)
												| B_T_CS1012
												| B_T_CS6012
												| B_T_CS8012
												| B_T_CS2125
												| B_T_CS265
												| B_T_CS3200
												|(B_T_CS8500
												& B_T_SINGLE)
												|(B_T_CS1016
												& B_T_SINGLE)),		0L,			0L,					 1.0F,			 "External",	}
};

/*----------------------------------------------------------*/

int16	sample_rate_table_max = (sizeof (sample_rate_table) / sizeof (srtype));

/*----------------------------------------------------------*/




/*----------------------------------------------------------*/

irtype far	ranges[GAGE_MAX_RANGES] = {
/*	index					constant			ir_flag			ir_calc		ir_text.	Supported by Board:		3200	12100	1610	2125	8012	6012	1012	512		250		225		220		LITE.	*/

{/*	GAGE_PM_10_V   (0)	*/	GAGE_PM_10_V,		( B_T_NONE
												| B_T_CS3200
												| B_T_CS82G
												| B_T_CS1610 ),	   10.0,	"+/-10v",	},	/*					Yes		No		Yes		No		No		No		No		No		No		No		No		No		*/

{/*	GAGE_PM_5_V    (1)	*/	GAGE_PM_5_V,		( B_T_CS250
												| B_T_CS225
												| B_T_CS220
												| B_T_CS512
												| B_T_CS1012
												| B_T_CS6012
												| B_T_CS8012
												| B_T_CS2125
												| B_T_CS265
												| B_T_CS8500
												| B_T_CS82G
												| B_T_CS1610),		5.0,	"+/-5v",	},	/*					No		Yes		Yes		Yes		Yes		Yes		Yes		Yes		Yes		Yes		Yes		No		*/

{/*	GAGE_PM_2_V    (2)	*/	GAGE_PM_2_V,		( B_T_CS220
												| B_T_CS512
												| B_T_CS1012
												| B_T_CS6012
												| B_T_CS8012
												| B_T_CS2125
												| B_T_CS265
												| B_T_CS8500
												| B_T_CS1016
												| B_T_CS82G
												| B_T_CS1610),		2.0,	"+/-2v",	},	/*					No		Yes		Yes		Yes		Yes		Yes		Yes		Yes		No		No		Yes		No		*/

{/*	GAGE_PM_1_V    (3)	*/	GAGE_PM_1_V,		( B_T_CSLITE
												| B_T_CS250
												| B_T_CS225
												| B_T_CS220
												| B_T_CS512
												| B_T_CS1012
												| B_T_CS6012
												| B_T_CS8012
												| B_T_CS2125
												| B_T_CS265
												| B_T_CS8500
												| B_T_CS82G
												| B_T_CS1610),		1.0,	"+/-1v",	},	/*					No		Yes		Yes		Yes		Yes		Yes		Yes		Yes		Yes		Yes		Yes		Yes		*/

{/*	GAGE_PM_500_MV (4)	*/	GAGE_PM_500_MV,		( B_T_CS250
												| B_T_CS225
												| B_T_CS220
												| B_T_CS512
												| B_T_CS1012
												| B_T_CS6012
												| B_T_CS8012
												| B_T_CS2125
												| B_T_CS265
												| B_T_CS8500
												| B_T_CS82G
												| B_T_CS1610),		0.5,	"+/-500mv",	},	/*					No		Yes		Yes		Yes		Yes		Yes		Yes		Yes		Yes		Yes		Yes		No		*/

{/*	GAGE_PM_200_MV (5)	*/	GAGE_PM_200_MV,		( B_T_CSLITE
												| B_T_CS250
												| B_T_CS225
												| B_T_CS220
												| B_T_CS512
												| B_T_CS1012
												| B_T_CS6012
												| B_T_CS8012
												| B_T_CS265
												| B_T_CS8500
												| B_T_CS82G
												| B_T_CS1610),		0.2,	"+/-200mv",	},	/*					No		Yes		Yes		1.30+	Yes		Yes		Yes		Yes		Yes		Yes		Yes		Yes		*/

{/*	GAGE_PM_100_MV (6)	*/	GAGE_PM_100_MV,		( B_T_CS250
												| B_T_CS225
												| B_T_CS220
												| B_T_CS512
												| B_T_CS1012
												| B_T_CS6012
												| B_T_CS8012
												| B_T_CS8500
												| B_T_CS82G
												| B_T_CS1610),		0.1,	"+/-100mv",	},	/*					No		Yes		Yes		1.30+	Yes		Yes		Yes		Yes		Yes		Yes		Yes		Yes		*/

{/*	GAGE_PM_50_MV (7)	*/	GAGE_PM_50_MV,		( B_T_CS1610),		0.05,	"+/-50mv",	},	/*					No		No		Yes		No		Yes		Yes		Yes		Yes		Yes		Yes		Yes		No		*/

{/*	GAGE_PM_50_V (8)	*/	GAGE_PM_50_V,		B_T_CS85G,			50.0,	"+/-50v",	},
{/*	GAGE_PM_25_V (9)	*/	GAGE_PM_20_V,		B_T_CS85G,			20.0,	"+/-20v",	},
{/*	GAGE_PM_25_MV (10)	*/	GAGE_PM_20_MV,		B_T_CS85G,			0.02,	"+/-20mv",	},
{/*	GAGE_PM_10_MV (11)	*/	GAGE_PM_10_MV,		B_T_CS85G,			0.01,	"+/-10mv",	},
{/*	GAGE_PM_5_MV (12)	*/	GAGE_PM_5_MV,		B_T_CS85G,			0.005,	"+/-5mv",	},


};


/*----------------------------------------------------------*/

int16	range_table_max = (sizeof (ranges) / sizeof (irtype));

/*----------------------------------------------------------*/

int16	best_sample_rate (uInt16 board_type, int16 op_mode, int16 external_clock_in_use)

{
	if (external_clock_in_use)  {	/*	External clock overrides any other sample rate.	*/

		return (SRTI_EXTERNAL);
	}else{
		int16	single_srindex;
		int16	dual_srindex;

		if (board_type & GAGE_ASSUME_CS2125)  {
			if ((B_T_DOUBLE_UP_BITS (board_type) & sample_rate_table[SRTI_250_MHZ].sr_flag) == 0)  {
				single_srindex	= SRTI_200_MHZ;
				dual_srindex	= SRTI_100_MHZ;
			}else{
				single_srindex	= SRTI_250_MHZ;
				dual_srindex	= SRTI_125_MHZ;
			}
		}else if (board_type == GAGE_ASSUME_CS85G)  {
			single_srindex	= SRTI_5_GHZ;
			dual_srindex	= SRTI_5_GHZ;
		}else if (board_type == GAGE_ASSUME_CS14200)  {
			single_srindex	= SRTI_200_MHZ;
			dual_srindex	= SRTI_200_MHZ;
//		}else if (board_type == GAGE_ASSUME_CS14105)  {
//			single_srindex	= SRTI_120_MHZ; // actually 105 Mhz
//			dual_srindex	= SRTI_120_MHZ; // actually 105 Mhz
		}else if (board_type == GAGE_ASSUME_CS12400)  {
			single_srindex	= SRTI_200_MHZ;
			dual_srindex	= SRTI_100_MHZ;
		}else if (board_type == GAGE_ASSUME_RAZOR) {
			if ((B_T_DOUBLE_UP_BITS (board_type) & sample_rate_table[SRTI_200_MHZ].sr_flag) == 0)  {
				single_srindex = SRTI_100_MHZ;
				dual_srindex = SRTI_100_MHZ;
			}else {
				single_srindex = SRTI_200_MHZ;
				dual_srindex = SRTI_200_MHZ;
			}
		}else if (board_type == GAGE_ASSUME_CS3200)  {
			single_srindex	= SRTI_100_MHZ;
			dual_srindex	= SRTI_100_MHZ;
		}
		else if (board_type == GAGE_ASSUME_CS12100)  {
			if ((B_T_DOUBLE_UP_BITS (board_type) & sample_rate_table[SRTI_100_MHZ].sr_flag) == 0)  {
				if ((B_T_DOUBLE_UP_BITS (board_type) & sample_rate_table[SRTI_50_MHZ].sr_flag) == 0)  {
					single_srindex	= SRTI_10_MHZ;	/*	CS1210.	*/
					dual_srindex	= SRTI_5_MHZ;
				}else{
					single_srindex	= SRTI_50_MHZ;	/*	CS1250.	*/
					dual_srindex	= SRTI_25_MHZ;
				}
			}else{
				single_srindex	= SRTI_100_MHZ;	/*	CS12100.	*/
				dual_srindex	= SRTI_50_MHZ;
			}
		}else if (board_type == GAGE_ASSUME_CS14100)  {
			if ((B_T_DOUBLE_UP_BITS (board_type) & sample_rate_table[SRTI_100_MHZ].sr_flag) == 0)
			{
				single_srindex	= SRTI_50_MHZ;
				dual_srindex	= SRTI_25_MHZ;
			}
			else
			{
				single_srindex	= SRTI_100_MHZ;
				dual_srindex	= SRTI_50_MHZ;
			}
		}else if (board_type == GAGE_ASSUME_CS82G)  {
			single_srindex	= SRTI_2_GHZ;
			dual_srindex	= SRTI_1_GHZ;
		}
		else if (board_type == GAGE_ASSUME_CS1610)  {
			if ((B_T_DOUBLE_UP_BITS (board_type) & sample_rate_table[SRTI_20_MHZ].sr_flag)  != 0 )
			{
				single_srindex	= SRTI_20_MHZ;
				dual_srindex	= SRTI_20_MHZ;
			}
			else if ((B_T_DOUBLE_UP_BITS (board_type) & sample_rate_table[SRTI_10_MHZ].sr_flag) == 0)  {
				single_srindex	= SRTI_2_5_MHZ;
				dual_srindex	= SRTI_2_5_MHZ;
			}else{
				single_srindex	= SRTI_10_MHZ;	/*	CS1602-10.	*/
				dual_srindex	= SRTI_10_MHZ;
			}
		}else if (board_type & GAGE_ASSUME_CS8500)  {
			dual_srindex	= single_srindex	= SRTI_500_MHZ;
		}else if (board_type & GAGE_ASSUME_CS1016)  {
			dual_srindex	= single_srindex	= SRTI_10_MHZ;
		}else if (board_type & GAGE_ASSUME_CS225)  {
			single_srindex	= SRTI_50_MHZ;
			dual_srindex	= SRTI_25_MHZ;
		}else if (board_type & (GAGE_ASSUME_CS220 | GAGE_ASSUME_CSLITE))  {
			single_srindex	= SRTI_40_MHZ;
			dual_srindex	= SRTI_20_MHZ;
		}else if (board_type & GAGE_ASSUME_CS8012)  {
			if ((B_T_DOUBLE_UP_BITS (board_type) & sample_rate_table[SRTI_80_MHZ].sr_flag) == 0)  {
				single_srindex	= SRTI_100_MHZ;
				dual_srindex	= SRTI_50_MHZ;
			}else{
				single_srindex	= SRTI_80_MHZ;
				dual_srindex	= SRTI_40_MHZ;
			}
		}else if (board_type & GAGE_ASSUME_CS6012)  {
			single_srindex	= SRTI_60_MHZ;
			dual_srindex	= SRTI_30_MHZ;
		}else if (board_type & GAGE_ASSUME_CS1012)  {
			single_srindex	= SRTI_20_MHZ;
			dual_srindex	= SRTI_10_MHZ;
		}else if (board_type & GAGE_ASSUME_CS512)  {
			single_srindex	= SRTI_5_MHZ;
			dual_srindex	= SRTI_5_MHZ;
		}else{
			single_srindex	= SRTI_5_MHZ;
			dual_srindex	= SRTI_5_MHZ;
		}
		if (external_clock_in_use)  {	/*	External clock overrides any other sample rate.	*/
			single_srindex = dual_srindex = SRTI_EXTERNAL;
		}
		if (op_mode == GAGE_SINGLE_CHAN)
			return (single_srindex);
		else if (op_mode == GAGE_DUAL_CHAN)
			return (dual_srindex);
		else
			return (SRTI_5_MHZ);
	}

}	/*	End of best_sample_rate ().	*/

/*----------------------------------------------------------*/

int16	best_rt_sample_rate (uInt16 board_type, int16 boards_in_system, boarddef *bd, int16 external_clock_in_use)
{
	if (external_clock_in_use)  {	/*	External clock overrides any other sample rate.	*/

		return (SRTI_EXTERNAL);
	}

	if (board_type == GAGE_ASSUME_CS12100 ||
		board_type == GAGE_ASSUME_CS14100 )  {
		if (boards_in_system == 1)  {
			if (bd->opmode == GAGE_SINGLE_CHAN)
				bd->srindex = SRTI_50_MHZ;
			else
				bd->srindex = SRTI_25_MHZ;
		}else if (boards_in_system == 2)  {
			if (bd->opmode == GAGE_SINGLE_CHAN)
				bd->srindex = SRTI_20_MHZ;
			else
				bd->srindex = SRTI_10_MHZ;
		}else{
			if (bd->opmode == GAGE_SINGLE_CHAN)
				bd->srindex = SRTI_10_MHZ;
			else
				bd->srindex = SRTI_5_MHZ;
		}
	}
	else if (board_type == GAGE_ASSUME_CS1610 )
	{
		bd->srindex	= SRTI_2_5_MHZ;
	}
	else if (board_type & GAGE_ASSUME_CSPCI)
	{
		if ( board_type & GAGE_ASSUME_CS8012 )
		{
			if ((B_T_DOUBLE_UP_BITS (board_type) & sample_rate_table[SRTI_80_MHZ].sr_flag) == 0)
			{
				if (bd->opmode == GAGE_SINGLE_CHAN)
					bd->srindex 	= SRTI_50_MHZ;
				else
					bd->srindex 	= SRTI_25_MHZ;
			}
			else
			{
				if (bd->opmode == GAGE_SINGLE_CHAN)
					bd->srindex 	= SRTI_40_MHZ;
				else
					bd->srindex 	= SRTI_20_MHZ;
			}
		}
		else if ( board_type & GAGE_ASSUME_CS512 )
		{
			bd->srindex 	= SRTI_5_MHZ;
		}
		else
		{
			if (bd->opmode == GAGE_SINGLE_CHAN)
				bd->srindex 	= SRTI_20_MHZ;
			else
				bd->srindex 	= SRTI_10_MHZ;
		}
	}
	else /* if (board_type == GAGE_ASSUME_CS8500)*/  {
		bd->opmode = GAGE_SINGLE_CHAN;
		if (boards_in_system == 1)  {
			bd->srindex = SRTI_100_MHZ;
		}else if (boards_in_system == 2)  {
			bd->srindex = SRTI_50_MHZ;
		}else{
			bd->srindex = SRTI_25_MHZ;
		}
	}
	return (bd->srindex);

}	/*	End of best_rt_sample_rate ().	*/


/*----------------------------------------------------------*/

void	update_sr_table_for_osc (uInt16 version, uInt16 board_type, uInt32 ee_options)

{
	uInt32	bt_flag;

	if (board_type & GAGE_ASSUME_CS2125)  {
		bt_flag = B_T_DOUBLE_UP_BITS (GAGE_ASSUME_CS2125);
		if ((ee_options & EEPROM_OPTIONS_EIB_CAPABLE) != 0)  {
			sample_rate_table[SRTI_200_MHZ].sr_flag	|= (bt_flag & B_T_SINGLE);
			sample_rate_table[SRTI_250_MHZ].sr_flag	&= ~(bt_flag & B_T_SINGLE);
			sample_rate_table[SRTI_100_MHZ].sr_flag	|= (bt_flag & B_T_DUAL);
			sample_rate_table[SRTI_125_MHZ].sr_flag	&= ~(bt_flag & B_T_DUAL);
		}
		else if ((ee_options & EEPROM_OPTIONS_NORMAL_OSC) == 0)  {
			sample_rate_table[SRTI_500_MHZ].sr_flag	|= (bt_flag & B_T_SINGLE);
			sample_rate_table[SRTI_250_MHZ].sr_flag	&= ~(bt_flag & B_T_SINGLE);
			sample_rate_table[SRTI_250_MHZ].sr_flag	|= (bt_flag & B_T_DUAL);
			sample_rate_table[SRTI_125_MHZ].sr_flag	&= ~(bt_flag & B_T_DUAL);
		}
		if ((version >= 0x0130) || ((version & 0x0001) == 0x0001))  {
			sample_rate_table[SRTI_10_HZ].sr_flag	&= ~bt_flag;
			sample_rate_table[SRTI_20_HZ].sr_flag	&= ~bt_flag;
			sample_rate_table[SRTI_30_MHZ].sr_flag	&= ~bt_flag;
			sample_rate_table[SRTI_60_MHZ].sr_flag	&= ~bt_flag;

			sample_rate_table[SRTI_50_HZ].sr_flag	&= ~(bt_flag & B_T_SINGLE);
			sample_rate_table[SRTI_120_MHZ].sr_flag	&= ~(bt_flag & B_T_SINGLE);

			sample_rate_table[SRTI_5_HZ].sr_flag	&= ~(bt_flag & B_T_DUAL);
			sample_rate_table[SRTI_20_MHZ].sr_flag	&= ~(bt_flag & B_T_DUAL);

			sample_rate_table[SRTI_25_MHZ].sr_flag	|= (bt_flag & B_T_DUAL);
		}else{
			sample_rate_table[SRTI_10_HZ].sr_flag	|= bt_flag;
			sample_rate_table[SRTI_20_HZ].sr_flag	|= bt_flag;
			sample_rate_table[SRTI_30_MHZ].sr_flag	|= bt_flag;
			sample_rate_table[SRTI_60_MHZ].sr_flag	|= bt_flag;

			sample_rate_table[SRTI_50_HZ].sr_flag	|= (bt_flag & B_T_SINGLE);
			sample_rate_table[SRTI_120_MHZ].sr_flag	|= (bt_flag & B_T_SINGLE);

			sample_rate_table[SRTI_5_HZ].sr_flag	|= (bt_flag & B_T_DUAL);
			sample_rate_table[SRTI_20_MHZ].sr_flag	|= (bt_flag & B_T_DUAL);

			sample_rate_table[SRTI_25_MHZ].sr_flag	&= ~(bt_flag & B_T_DUAL);
		}
	}else if (board_type == GAGE_ASSUME_CS12100)  {
		int		i;

		bt_flag = B_T_DOUBLE_UP_BITS (GAGE_ASSUME_CS12100);
		if ((ee_options & EEPROM_OPTIONS_NORMAL_OSC) == 0)  {	/*	1210.	*/
			for (i = SRTI_1_HZ ; i <= SRTI_EXTERNAL ; i++)  {					/*	Turn these off.	*/
				sample_rate_table[i].sr_flag &= ~bt_flag;
			}
			sample_rate_table[SRTI_500_KHZ].sr_flag	|= (bt_flag & B_T_DUAL);	/*	Turn these on.	*/
			sample_rate_table[SRTI_1_MHZ].sr_flag	|= bt_flag;
			sample_rate_table[SRTI_2_MHZ].sr_flag	|= (bt_flag & B_T_SINGLE);
			sample_rate_table[SRTI_2_5_MHZ].sr_flag	|= (bt_flag & B_T_DUAL);
			sample_rate_table[SRTI_5_MHZ].sr_flag	|= bt_flag;
			sample_rate_table[SRTI_10_MHZ].sr_flag	|= (bt_flag & B_T_SINGLE);
			sample_rate_table[SRTI_EXTERNAL].sr_flag|= bt_flag;
		}else if ((ee_options & EEPROM_OPTIONS_ALTERNATE_CONFIG) != 0)  {	/*	1250.	*/
			for (i = SRTI_1_HZ ; i <= SRTI_EXTERNAL ; i++)  {					/*	Turn these off.	*/
				sample_rate_table[i].sr_flag &= ~bt_flag;
			}
			if (version & 1)  {
				sample_rate_table[SRTI_1_MHZ].sr_flag	|= (bt_flag& B_T_DUAL);
				sample_rate_table[SRTI_2_MHZ].sr_flag	|= (bt_flag & B_T_SINGLE);
				sample_rate_table[SRTI_2_5_MHZ].sr_flag	|= (bt_flag & B_T_DUAL);
				sample_rate_table[SRTI_5_MHZ].sr_flag	|= bt_flag;
			}
			sample_rate_table[SRTI_5_MHZ].sr_flag	|= (bt_flag & B_T_DUAL);	/*	Turn these on.	*/
			sample_rate_table[SRTI_10_MHZ].sr_flag	|= bt_flag;
			sample_rate_table[SRTI_20_MHZ].sr_flag	|= (bt_flag & B_T_SINGLE);
			sample_rate_table[SRTI_25_MHZ].sr_flag	|= (bt_flag & B_T_DUAL);
			sample_rate_table[SRTI_50_MHZ].sr_flag	|= (bt_flag & B_T_SINGLE);
			sample_rate_table[SRTI_EXTERNAL].sr_flag|= bt_flag;
		}else{													/*	12100.	*/
			for (i = SRTI_1_HZ ; i <= SRTI_EXTERNAL ; i++)  {					/*	Turn these off.	*/
				sample_rate_table[i].sr_flag &= ~bt_flag;
			}
			if (version & 1)  {
				sample_rate_table[SRTI_1_MHZ].sr_flag	|= (bt_flag & B_T_DUAL);
				sample_rate_table[SRTI_2_MHZ].sr_flag	|= (bt_flag & B_T_SINGLE);
				sample_rate_table[SRTI_2_5_MHZ].sr_flag	|= (bt_flag & B_T_DUAL);
				sample_rate_table[SRTI_5_MHZ].sr_flag	|= bt_flag;
			}
			sample_rate_table[SRTI_5_MHZ].sr_flag	|= (bt_flag & B_T_DUAL);	/*	Turn these on.	*/
			sample_rate_table[SRTI_10_MHZ].sr_flag	|= bt_flag;
			sample_rate_table[SRTI_20_MHZ].sr_flag	|= (bt_flag & B_T_SINGLE);
			sample_rate_table[SRTI_25_MHZ].sr_flag	|= (bt_flag & B_T_DUAL);
			sample_rate_table[SRTI_50_MHZ].sr_flag	|= bt_flag;
			sample_rate_table[SRTI_100_MHZ].sr_flag	|= (bt_flag & B_T_SINGLE);
			sample_rate_table[SRTI_EXTERNAL].sr_flag|= bt_flag;
		}
		sample_rate_table[SRTI_EXTERNAL].sr_flag|= bt_flag;
	}else if (board_type == GAGE_ASSUME_CS1610)  {
		int		i;

		bt_flag = B_T_DOUBLE_UP_BITS (GAGE_ASSUME_CS1610);
		for (i = SRTI_1_HZ ; i <= SRTI_EXTERNAL ; i++)  {					/*	Turn these off.	*/
			sample_rate_table[i].sr_flag &= ~bt_flag;
		}
		bt_flag = B_T_DOUBLE_UP_BITS (GAGE_ASSUME_CS1610) & B_T_DUAL;
		for (i = SRTI_1_KHZ ; i <= SRTI_1_MHZ ; i++)  {						/*	Turn these on.	*/
			sample_rate_table[i].sr_flag |= bt_flag;
		}
		if ( ((ee_options & EEPROM_OPTIONS_ALTERNATE_CONFIG) != 0) &&
		     (version & 1) == 1 )   //CS1220
		{
			sample_rate_table[SRTI_20_MHZ].sr_flag	|= bt_flag;
			sample_rate_table[SRTI_10_MHZ].sr_flag	|= bt_flag;
			sample_rate_table[SRTI_5_MHZ].sr_flag	|= bt_flag;
			sample_rate_table[SRTI_2_MHZ].sr_flag	|= bt_flag;
		}
		else
		{
			sample_rate_table[SRTI_2_5_MHZ].sr_flag	|= bt_flag;
			if ( (ee_options & EEPROM_OPTIONS_ALTERNATE_CONFIG) == 0 )	// CS1602
			{
				if ( version & 1) {		// CS1602 WITH 10Mhz option
					sample_rate_table[SRTI_5_MHZ].sr_flag	|= bt_flag;
					sample_rate_table[SRTI_10_MHZ].sr_flag	|= bt_flag;
				}
			}
			else						// CS1610
			{
				sample_rate_table[SRTI_5_MHZ].sr_flag	|= bt_flag;
				sample_rate_table[SRTI_10_MHZ].sr_flag	|= bt_flag;
			}
		}
	   	sample_rate_table[SRTI_EXTERNAL].sr_flag|= bt_flag;

	}else if (board_type == GAGE_ASSUME_CS14100)  {
		int		i;

		bt_flag = B_T_DOUBLE_UP_BITS (GAGE_ASSUME_CS14100);
		for (i = SRTI_1_HZ ; i <= SRTI_EXTERNAL ; i++)  {					/*	Turn these off.	*/
			sample_rate_table[i].sr_flag &= ~bt_flag;
		}
		for (i = SRTI_1_KHZ ; i <= SRTI_5_MHZ ; i++)  {						/*	Turn these on.	*/
			sample_rate_table[i].sr_flag |= bt_flag;
		}
		sample_rate_table[SRTI_2_5_MHZ].sr_flag &= ~bt_flag;				/*	Turn this off.	*/

		sample_rate_table[SRTI_10_MHZ].sr_flag	|= bt_flag;
		sample_rate_table[SRTI_25_MHZ].sr_flag	|= bt_flag;

		if ((ee_options & EEPROM_OPTIONS_ALTERNATE_CONFIG) != 0)
		{	/*	1450.	*/
			sample_rate_table[SRTI_50_MHZ].sr_flag	|= (bt_flag & B_T_SINGLE);
		}
		else
		{
			sample_rate_table[SRTI_50_MHZ].sr_flag	|= bt_flag;
			sample_rate_table[SRTI_100_MHZ].sr_flag	|= (bt_flag & B_T_SINGLE);
		}
		sample_rate_table[SRTI_EXTERNAL].sr_flag|= bt_flag;

	}else if (board_type == GAGE_ASSUME_CS82G)  {
		int		i;

		bt_flag = B_T_DOUBLE_UP_BITS (GAGE_ASSUME_CS82G);
		for (i = SRTI_1_HZ ; i <= SRTI_EXTERNAL ; i++)  {					/*	Turn these off.	*/
			sample_rate_table[i].sr_flag &= ~bt_flag;
		}
		for (i = SRTI_100_KHZ ; i <= SRTI_2_MHZ ; i++)  {						/*	Turn these on.	*/
			sample_rate_table[i].sr_flag |= (bt_flag & B_T_DUAL);
		}

		sample_rate_table[SRTI_5_MHZ].sr_flag	 |= (bt_flag & B_T_DUAL);
		sample_rate_table[SRTI_10_MHZ].sr_flag	 |= (bt_flag & B_T_DUAL);
		sample_rate_table[SRTI_20_MHZ].sr_flag	 |= bt_flag;
		sample_rate_table[SRTI_40_MHZ].sr_flag	 |= (bt_flag & B_T_SINGLE);
		sample_rate_table[SRTI_50_MHZ].sr_flag  |= (bt_flag & B_T_DUAL);
		sample_rate_table[SRTI_100_MHZ].sr_flag |= bt_flag;
		sample_rate_table[SRTI_125_MHZ].sr_flag |= (bt_flag & B_T_DUAL);
		sample_rate_table[SRTI_200_MHZ].sr_flag |= (bt_flag & B_T_SINGLE);
		sample_rate_table[SRTI_250_MHZ].sr_flag |= bt_flag;
		sample_rate_table[SRTI_500_MHZ].sr_flag |= bt_flag;
		sample_rate_table[SRTI_1_GHZ].sr_flag |= bt_flag;
		sample_rate_table[SRTI_2_GHZ].sr_flag |= (bt_flag & B_T_SINGLE);

		sample_rate_table[SRTI_EXTERNAL].sr_flag|= bt_flag;
	}else if (board_type == GAGE_ASSUME_CS8500)  {
		int		i;

		bt_flag = B_T_DOUBLE_UP_BITS (GAGE_ASSUME_CS8500) & B_T_SINGLE;

		/*	Clean sample rates of 3200	*/
		for (i = SRTI_1_HZ ; i < SRTI_25_MHZ; i++)  {					/*	Turn these off.	*/
			sample_rate_table[i].sr_flag &= ~bt_flag;
		}

		if (ee_options & EEPROM_OPTIONS_SPECIAL_MULREC) {
			sample_rate_table[SRTI_25_MHZ].sr_flag	&= ~bt_flag;
			sample_rate_table[SRTI_50_MHZ].sr_flag	&= ~bt_flag;
			sample_rate_table[SRTI_100_MHZ].sr_flag	&= ~bt_flag;
			sample_rate_table[SRTI_125_MHZ].sr_flag	&= ~bt_flag;
			sample_rate_table[SRTI_250_MHZ].sr_flag	&= ~bt_flag;
		}

		if (version < 0x12)  {
			if (ee_options & EEPROM_OPTIONS_EXTERNAL_CLOCK) {
				sample_rate_table[SRTI_25_MHZ].sr_flag	&= ~bt_flag;
				sample_rate_table[SRTI_50_MHZ].sr_flag	&= ~bt_flag;
				sample_rate_table[SRTI_100_MHZ].sr_flag	&= ~bt_flag;
				sample_rate_table[SRTI_200_MHZ].sr_flag	&= ~bt_flag;
			}
		}

	}else if (board_type & GAGE_ASSUME_CS8012)  {
		bt_flag = B_T_DOUBLE_UP_BITS (GAGE_ASSUME_CS8012);
		if ((ee_options & EEPROM_OPTIONS_NORMAL_OSC) == 0)  {
			sample_rate_table[SRTI_20_MHZ].sr_flag	&= ~bt_flag;	/*	Turn these off.	*/
			sample_rate_table[SRTI_40_MHZ].sr_flag	&= ~bt_flag;
			sample_rate_table[SRTI_80_MHZ].sr_flag	&= ~bt_flag;

			sample_rate_table[SRTI_20_MHZ].sr_flag	|= (bt_flag & B_T_SINGLE);		/*	Turn these on.	*/
			sample_rate_table[SRTI_25_MHZ].sr_flag	|= (bt_flag & B_T_DUAL);
			sample_rate_table[SRTI_50_MHZ].sr_flag	|= bt_flag;
			sample_rate_table[SRTI_100_MHZ].sr_flag	|= (bt_flag & B_T_SINGLE);
		}else{
			sample_rate_table[SRTI_20_MHZ].sr_flag	&= ~bt_flag;	/*	Turn these off.	*/
			sample_rate_table[SRTI_25_MHZ].sr_flag	&= ~bt_flag;
			sample_rate_table[SRTI_50_MHZ].sr_flag	&= ~bt_flag;
			sample_rate_table[SRTI_100_MHZ].sr_flag	&= ~bt_flag;

			sample_rate_table[SRTI_20_MHZ].sr_flag	|= bt_flag;		/*	Turn these on.	*/
			sample_rate_table[SRTI_40_MHZ].sr_flag	|= bt_flag;
			sample_rate_table[SRTI_80_MHZ].sr_flag	|= (bt_flag & B_T_SINGLE);
		}
	}else if (board_type & GAGE_ASSUME_CS1016)  {
		if ((version & 0x0ff0) == 0x0100)  {		/*	10 MHz only.	*/
			int		i;

			bt_flag = B_T_DOUBLE_UP_BITS (GAGE_ASSUME_CS1016);
			for (i = SRTI_5_MHZ ; i >= SRTI_1_KHZ ; i--)
				sample_rate_table[i].sr_flag &= ~bt_flag;
		}
	}else if (board_type == GAGE_ASSUME_CS85G)  {	// For Raptor Project only
		int i;
		bt_flag = B_T_DOUBLE_UP_BITS (GAGE_ASSUME_CS85G);
		for (i = SRTI_1_HZ ; i < sample_rate_table_max ; i++)		// start from 1KHz
				sample_rate_table[i].sr_flag &= ~bt_flag;

		sample_rate_table[SRTI_1_KHZ].sr_flag	= bt_flag;	/*	1	KHz	*/

		sample_rate_table[SRTI_5_KHZ].sr_flag	= bt_flag;	/*	5	KHz	*/
		sample_rate_table[SRTI_10_KHZ].sr_flag	= bt_flag;	/*	10	KHz	*/

		sample_rate_table[SRTI_50_KHZ].sr_flag	= bt_flag;	/*	50	KHz	*/
		sample_rate_table[SRTI_100_KHZ].sr_flag	= bt_flag;	/*	100	KHz	*/

		sample_rate_table[SRTI_500_KHZ].sr_flag	= bt_flag;	/*	500	KHz	*/
		sample_rate_table[SRTI_1_MHZ].sr_flag	= bt_flag;	/*	1	MHz	*/

		sample_rate_table[SRTI_2_5_MHZ].sr_flag	= bt_flag;	/*	2.5	MHz	*/


		sample_rate_table[SRTI_5_MHZ].sr_flag	= bt_flag;	/*	5	MHz	*/
		sample_rate_table[SRTI_10_MHZ].sr_flag	= bt_flag;	/*	10	MHz	*/
		sample_rate_table[SRTI_25_MHZ].sr_flag	= bt_flag;	/*	25	MHz	*/
		sample_rate_table[SRTI_50_MHZ].sr_flag	= bt_flag;	/*	50	MHz	*/
		sample_rate_table[SRTI_100_MHZ].sr_flag	= bt_flag;	/*	100	MHz	*/
		sample_rate_table[SRTI_250_MHZ].sr_flag	= bt_flag;	/*	250	MHz	*/
		sample_rate_table[SRTI_500_MHZ].sr_flag	= bt_flag;	/*	500	MHz	*/
		sample_rate_table[SRTI_1_GHZ].sr_flag	= bt_flag;	/*	1	GHz	*/
		sample_rate_table[SRTI_2_5_GHZ].sr_flag	= bt_flag;	/*	2.5	GHz	*/

		sample_rate_table[SRTI_5_GHZ].sr_flag	= bt_flag;	/*	5	GHz	*/
	}else if (board_type == GAGE_ASSUME_CS14200) {
		int i;
		bt_flag = B_T_DOUBLE_UP_BITS (GAGE_ASSUME_CS14200);
		for (i = SRTI_1_HZ; i < SRTI_50_KHZ; i++)	{
			sample_rate_table[i].sr_flag &= ~bt_flag; /* turn these off */
		}
		for (i = SRTI_50_KHZ; i <= SRTI_2_MHZ; i++)	{
			sample_rate_table[i].sr_flag |= bt_flag;	/* turn these on */
		}
		
		for (i = SRTI_2_5_MHZ; i < SRTI_EXTERNAL; i++) {
			sample_rate_table[i].sr_flag &= ~bt_flag; /* turn these off */
		}
		/* now turn on the specific ones that we need */
		sample_rate_table[SRTI_5_MHZ].sr_flag |= bt_flag;
		sample_rate_table[SRTI_10_MHZ].sr_flag |= bt_flag;
		sample_rate_table[SRTI_20_MHZ].sr_flag |= bt_flag;
		sample_rate_table[SRTI_25_MHZ].sr_flag |= bt_flag;
		sample_rate_table[SRTI_40_MHZ].sr_flag |= bt_flag;
		sample_rate_table[SRTI_50_MHZ].sr_flag |= bt_flag;
		sample_rate_table[SRTI_80_MHZ].sr_flag |= bt_flag;
		sample_rate_table[SRTI_100_MHZ].sr_flag |= bt_flag;
		sample_rate_table[SRTI_200_MHZ].sr_flag |= bt_flag;

		sample_rate_table[SRTI_EXTERNAL].sr_flag |= bt_flag;

	}else if (board_type == GAGE_ASSUME_CS12400) {
		int i;
		bt_flag = B_T_DOUBLE_UP_BITS (GAGE_ASSUME_CS12400);
		for (i = SRTI_1_HZ; i < SRTI_50_KHZ; i++)	{
			sample_rate_table[i].sr_flag &= ~bt_flag; /* turn these off */
		}
		for (i = SRTI_50_KHZ; i <= SRTI_2_MHZ; i++)	{
			sample_rate_table[i].sr_flag |= bt_flag;	/* turn these on */
		}
		
		for (i = SRTI_2_5_MHZ; i < SRTI_EXTERNAL; i++) {
			sample_rate_table[i].sr_flag &= ~bt_flag; /* turn these off */
		}
		/* now turn on the specific ones that we need */
		sample_rate_table[SRTI_5_MHZ].sr_flag |= bt_flag;
		sample_rate_table[SRTI_10_MHZ].sr_flag |= bt_flag;
		sample_rate_table[SRTI_20_MHZ].sr_flag |= bt_flag;
		sample_rate_table[SRTI_25_MHZ].sr_flag |= bt_flag;
		sample_rate_table[SRTI_50_MHZ].sr_flag |= bt_flag;
		sample_rate_table[SRTI_100_MHZ].sr_flag |= bt_flag;
		sample_rate_table[SRTI_200_MHZ].sr_flag |= bt_flag;

		sample_rate_table[SRTI_EXTERNAL].sr_flag |= bt_flag;
	}else if (board_type == GAGE_ASSUME_RAZOR)	{
		int i;
		bt_flag = B_T_DOUBLE_UP_BITS (GAGE_ASSUME_RAZOR);
		for (i = SRTI_1_HZ; i < SRTI_1_KHZ; i++)	{
			sample_rate_table[i].sr_flag &= ~bt_flag; /* turn these off */
		}
		for (i = SRTI_1_KHZ; i <= SRTI_2_MHZ; i++)	{
			sample_rate_table[i].sr_flag |= bt_flag;	/* turn these on */
		}
		for (i = SRTI_2_5_MHZ; i < SRTI_EXTERNAL; i++) {
			sample_rate_table[i].sr_flag &= ~bt_flag; /* turn these off */
		}
		/* now turn on the specific ones that we need */
		sample_rate_table[SRTI_5_MHZ].sr_flag |= bt_flag;
		sample_rate_table[SRTI_10_MHZ].sr_flag |= bt_flag;
		sample_rate_table[SRTI_25_MHZ].sr_flag |= bt_flag;
		sample_rate_table[SRTI_50_MHZ].sr_flag |= bt_flag;
		sample_rate_table[SRTI_100_MHZ].sr_flag |= bt_flag;
		if (ee_options & EEPROM_OPTIONS_200_MHZ) {
			sample_rate_table[SRTI_200_MHZ].sr_flag |= bt_flag;
		}
		sample_rate_table[SRTI_EXTERNAL].sr_flag |= bt_flag;
	}


	if (board_type & GAGE_ASSUME_CS8012_TYPE)  {
		if (version >= 0x0200)  {
			int		sri;

			bt_flag = B_T_DOUBLE_UP_BITS (board_type);
			for (sri = SRTI_1_HZ ; sri < SRTI_200_HZ ; sri++)  {
				sample_rate_table[sri].sr_flag	&= ~bt_flag;	/*	Turn these off.	*/
			}
		}
	}

}	/*	End of update_sr_table_for_osc ().	*/

/*----------------------------------------------------------*/

void	update_sr_table_for_ext_clk_only (void)

{
	int		i;

	for (i = SRTI_1_HZ ; i < SRTI_EXTERNAL ; i++)  {
		sample_rate_table[i].sr_flag = 0L;
	}

}	/*	End of update_sr_table_for_ext_clk_only ().	*/

/*----------------------------------------------------------*/

void	update_sr_table_for_x1_clk_only (uInt16 board_type)

/*	Dual channel only.	*/

{
	int		i;
	uInt32	bt_flag;

	bt_flag = (B_T_DOUBLE_UP_BITS (board_type & ~(GAGE_ASSUME_CS8012_TYPE | GAGE_ASSUME_CSPCI)) & B_T_SINGLE);

	for (i = SRTI_1_HZ ; i <= SRTI_EXTERNAL ; i++)  {
		sample_rate_table[i].sr_flag &= ~bt_flag;
	}

}	/*	End of update_sr_table_for_x1_clk_only ().	*/

/*----------------------------------------------------------*/

void	update_sr_table_for_real_time (int16 boards_on_bus, uInt16 version, uInt16 board_type, uInt32 ee_options)

{
	uInt32	bt_flag;
	int		i;

	if (board_type == GAGE_ASSUME_CS12100)  {
		bt_flag = B_T_DOUBLE_UP_BITS (GAGE_ASSUME_CS12100);
		if ((ee_options & EEPROM_OPTIONS_NORMAL_OSC) == 0)  {				/*	1210.	*/
			for (i = SRTI_1_HZ ; i <= SRTI_EXTERNAL ; i++)  {						/*	Turn these off.	*/
				sample_rate_table[i].rt_sr_flag &= ~bt_flag;
			}
			sample_rate_table[SRTI_500_KHZ].rt_sr_flag	|= (bt_flag & B_T_DUAL);	/*	Turn these on.	*/
			sample_rate_table[SRTI_1_MHZ].rt_sr_flag	|= bt_flag;
			sample_rate_table[SRTI_2_MHZ].rt_sr_flag	|= (bt_flag & B_T_SINGLE);
			sample_rate_table[SRTI_2_5_MHZ].rt_sr_flag	|= (bt_flag & B_T_DUAL);
			sample_rate_table[SRTI_5_MHZ].rt_sr_flag	|= bt_flag;
			sample_rate_table[SRTI_10_MHZ].rt_sr_flag	|= (bt_flag & B_T_SINGLE);
			sample_rate_table[SRTI_EXTERNAL].rt_sr_flag	|= bt_flag;
		}else if ((ee_options & EEPROM_OPTIONS_ALTERNATE_CONFIG) != 0)  {	/*	1250.	*/
			for (i = SRTI_1_HZ ; i <= SRTI_EXTERNAL ; i++)  {						/*	Turn these off.	*/
				sample_rate_table[i].rt_sr_flag &= ~bt_flag;
			}
			if (version & 1)  {
				sample_rate_table[SRTI_500_KHZ].rt_sr_flag	|= (bt_flag & B_T_DUAL);	/*	Turn these on.	*/
				sample_rate_table[SRTI_1_MHZ].rt_sr_flag	|= bt_flag;
				sample_rate_table[SRTI_2_MHZ].rt_sr_flag	|= (bt_flag & B_T_SINGLE);
				sample_rate_table[SRTI_2_5_MHZ].rt_sr_flag	|= (bt_flag & B_T_DUAL);
				sample_rate_table[SRTI_5_MHZ].rt_sr_flag	|= bt_flag;
			}
			sample_rate_table[SRTI_5_MHZ].rt_sr_flag	|= (bt_flag & B_T_DUAL);	/*	Turn these on.	*/
			sample_rate_table[SRTI_10_MHZ].rt_sr_flag	|= bt_flag;
			sample_rate_table[SRTI_20_MHZ].rt_sr_flag	|= (bt_flag & B_T_SINGLE);
			sample_rate_table[SRTI_25_MHZ].rt_sr_flag	|= (bt_flag & B_T_DUAL);
			sample_rate_table[SRTI_50_MHZ].rt_sr_flag	|= (bt_flag & B_T_SINGLE);
			sample_rate_table[SRTI_EXTERNAL].rt_sr_flag	|= bt_flag;
		}else{																/*	12100.	*/
			for (i = SRTI_1_HZ ; i <= SRTI_EXTERNAL ; i++)  {						/*	Turn these off.	*/
				sample_rate_table[i].rt_sr_flag &= ~bt_flag;
			}
			if (version & 1)  {
				sample_rate_table[SRTI_500_KHZ].rt_sr_flag	|= (bt_flag & B_T_DUAL);	/*	Turn these on.	*/
				sample_rate_table[SRTI_1_MHZ].rt_sr_flag	|= bt_flag;
				sample_rate_table[SRTI_2_MHZ].rt_sr_flag	|= (bt_flag & B_T_SINGLE);
				sample_rate_table[SRTI_2_5_MHZ].rt_sr_flag	|= (bt_flag & B_T_DUAL);
				sample_rate_table[SRTI_5_MHZ].rt_sr_flag	|= bt_flag;
			}
			sample_rate_table[SRTI_5_MHZ].rt_sr_flag	|= (bt_flag & B_T_DUAL);	/*	Turn these on.	*/
			sample_rate_table[SRTI_10_MHZ].rt_sr_flag	|= bt_flag;
			sample_rate_table[SRTI_20_MHZ].rt_sr_flag	|= (bt_flag & B_T_SINGLE);
			sample_rate_table[SRTI_25_MHZ].rt_sr_flag	|= (bt_flag & B_T_DUAL);
			sample_rate_table[SRTI_50_MHZ].rt_sr_flag	|= bt_flag;
			sample_rate_table[SRTI_100_MHZ].rt_sr_flag	|= (bt_flag & B_T_SINGLE);
			sample_rate_table[SRTI_EXTERNAL].rt_sr_flag	|= bt_flag;
		}
		for (i = SRTI_1_HZ ; i <= SRTI_EXTERNAL ; i++)  {						/*	Copy the table column.	*/
			sample_rate_table[i].rts_sr_flag = sample_rate_table[i].rt_sr_flag;
		}
		if (boards_on_bus == 1)  {
			i = SRTI_50_MHZ + 1;
			sample_rate_table[SRTI_50_MHZ].rts_sr_flag	&= ~(bt_flag & B_T_DUAL);
		}else if (boards_on_bus == 2)  {
			i = SRTI_25_MHZ + 1;
			sample_rate_table[SRTI_25_MHZ].rts_sr_flag	&= ~(bt_flag & B_T_DUAL);
		}else{
			i = SRTI_10_MHZ + 1;
			sample_rate_table[SRTI_10_MHZ].rts_sr_flag	&= ~(bt_flag & B_T_DUAL);
		}
		for ( ; i < SRTI_EXTERNAL ; i++)  {						/*	Turn these off.	*/
			sample_rate_table[i].rts_sr_flag &= ~bt_flag;
		}
	}else if (board_type == GAGE_ASSUME_CS1610)  {

		bt_flag = B_T_DOUBLE_UP_BITS (GAGE_ASSUME_CS1610);
		for (i = SRTI_1_HZ ; i <= SRTI_EXTERNAL ; i++)  {					/*	Turn these off.	*/
			sample_rate_table[i].rt_sr_flag &= ~bt_flag;
		}
		bt_flag = B_T_DOUBLE_UP_BITS (GAGE_ASSUME_CS1610) & B_T_DUAL;
		for (i = SRTI_1_KHZ ; i <= SRTI_1_MHZ ; i++)  {						/*	Turn these on.	*/
			sample_rate_table[i].rt_sr_flag |= bt_flag;
		}
		sample_rate_table[SRTI_2_5_MHZ].rt_sr_flag	|= bt_flag;
		if (version & 1)  {
			sample_rate_table[SRTI_5_MHZ].rt_sr_flag	|= bt_flag;
			sample_rate_table[SRTI_10_MHZ].rt_sr_flag	|= bt_flag;
		}
		for (i = SRTI_1_HZ ; i <= SRTI_EXTERNAL ; i++)  {						/*	Copy the table column.	*/
			sample_rate_table[i].rts_sr_flag = sample_rate_table[i].rt_sr_flag;
		}
		if (boards_on_bus == 1)  {
			;
		}else if (boards_on_bus == 2)  {
			;
		}else{
			sample_rate_table[SRTI_10_MHZ].rts_sr_flag	&= ~bt_flag;
		}
	}else if (board_type == GAGE_ASSUME_CS3200)  {

		bt_flag = B_T_DOUBLE_UP_BITS (GAGE_ASSUME_CS3200);
		for (i = SRTI_1_HZ ; i <= SRTI_EXTERNAL ; i++)  {						/*	Turn these off.	*/
			sample_rate_table[i].rt_sr_flag &= ~bt_flag;
		}
		sample_rate_table[SRTI_500_KHZ].rt_sr_flag	|= bt_flag;					/*	Turn these on.	*/
		sample_rate_table[SRTI_1_MHZ].rt_sr_flag	|= bt_flag;
		sample_rate_table[SRTI_2_MHZ].rt_sr_flag	|= bt_flag;
		sample_rate_table[SRTI_5_MHZ].rt_sr_flag	|= bt_flag;
		sample_rate_table[SRTI_10_MHZ].rt_sr_flag	|= bt_flag;
		sample_rate_table[SRTI_20_MHZ].rt_sr_flag	|= bt_flag;
		sample_rate_table[SRTI_25_MHZ].rt_sr_flag	|= bt_flag;
		sample_rate_table[SRTI_50_MHZ].rt_sr_flag	|= bt_flag;
		sample_rate_table[SRTI_100_MHZ].rt_sr_flag	|= bt_flag;
		sample_rate_table[SRTI_EXTERNAL].rt_sr_flag	|= bt_flag;

		for (i = SRTI_1_HZ ; i <= SRTI_EXTERNAL ; i++)  {						/*	Copy the table column.	*/
			sample_rate_table[i].rts_sr_flag = sample_rate_table[i].rt_sr_flag;
		}
		if (boards_on_bus == 1)  {
			i = SRTI_100_MHZ + 1;
			sample_rate_table[SRTI_100_MHZ].rts_sr_flag	&= ~(bt_flag & B_T_DUAL);
		}else if (boards_on_bus == 2)  {
			i = SRTI_50_MHZ + 1;
			sample_rate_table[SRTI_50_MHZ].rts_sr_flag	&= ~(bt_flag & B_T_DUAL);
		}else{
			i = SRTI_25_MHZ + 1;
			sample_rate_table[SRTI_25_MHZ].rts_sr_flag	&= ~(bt_flag & B_T_DUAL);
		}
		for ( ; i < SRTI_EXTERNAL ; i++)  {						/*	Turn these off.	*/
			sample_rate_table[i].rts_sr_flag &= ~bt_flag;
		}
	}else if (board_type == GAGE_ASSUME_CS14100)  {
		bt_flag = B_T_DOUBLE_UP_BITS (GAGE_ASSUME_CS14100);
		for (i = SRTI_1_HZ ; i <= SRTI_EXTERNAL ; i++)  {						/*	Turn these off.	*/
			sample_rate_table[i].rt_sr_flag &= ~bt_flag;
		}
		for (i = SRTI_1_KHZ ; i <= SRTI_5_MHZ ; i++)  {							/*	Turn these on.	*/
			sample_rate_table[i].rt_sr_flag |= bt_flag;
		}
		sample_rate_table[SRTI_10_MHZ].rt_sr_flag	|= bt_flag;
		sample_rate_table[SRTI_25_MHZ].rt_sr_flag	|= bt_flag;
		sample_rate_table[SRTI_50_MHZ].rt_sr_flag	|= bt_flag;
		sample_rate_table[SRTI_100_MHZ].rt_sr_flag	|= (bt_flag & B_T_SINGLE);
		sample_rate_table[SRTI_EXTERNAL].rt_sr_flag	|= bt_flag;

		for (i = SRTI_1_HZ ; i <= SRTI_EXTERNAL ; i++)  {						/*	Copy the table column.	*/
			sample_rate_table[i].rts_sr_flag = sample_rate_table[i].rt_sr_flag;
		}
		if (boards_on_bus == 1)  {
			i = SRTI_50_MHZ + 1;
			sample_rate_table[SRTI_50_MHZ].rts_sr_flag	&= ~(bt_flag & B_T_DUAL);
		}else if (boards_on_bus == 2)  {
			i = SRTI_25_MHZ + 1;
			sample_rate_table[SRTI_25_MHZ].rts_sr_flag	&= ~(bt_flag & B_T_DUAL);
		}else{
			i = SRTI_10_MHZ + 1;
			sample_rate_table[SRTI_10_MHZ].rts_sr_flag	&= ~(bt_flag & B_T_DUAL);
		}
		for ( ; i < SRTI_EXTERNAL ; i++)  {						/*	Turn these off.	*/
			sample_rate_table[i].rts_sr_flag &= ~bt_flag;
		}
	}
	else if (board_type == GAGE_ASSUME_CS8500)
	{
		bt_flag = B_T_DOUBLE_UP_BITS (GAGE_ASSUME_CS8500) & B_T_SINGLE;
		for (i = SRTI_1_HZ ; i <= SRTI_EXTERNAL ; i++)  {						/*	Copy the table columns.	*/
			sample_rate_table[i].rts_sr_flag = sample_rate_table[i].rt_sr_flag = (sample_rate_table[i].sr_flag & bt_flag);
		}

		for (i = 0 ; i < SRTI_EXTERNAL ; i++)  {						/*	Turn these off.	*/
			sample_rate_table[i].rts_sr_flag &= ~bt_flag;
			sample_rate_table[i].rt_sr_flag &= ~bt_flag;
		}
		sample_rate_table[SRTI_100_MHZ].rts_sr_flag	|= bt_flag;
		sample_rate_table[SRTI_100_MHZ].rt_sr_flag	|= bt_flag;
		sample_rate_table[SRTI_250_MHZ].rt_sr_flag	|= bt_flag;

	}

}	/*	End of update_sr_table_for_real_time ().	*/

/*----------------------------------------------------------*/

void	update_range_table_for_version (uInt16 version, uInt16 board_type, uInt32 ee_options)

{
	uInt32	bt_flag = B_T_DOUBLE_UP_BITS (board_type);

	if (board_type != GAGE_ASSUME_CS85G)
	{
		int i;

		bt_flag = B_T_DOUBLE_UP_BITS (GAGE_ASSUME_CS85G);
		for (i = GAGE_PM_50_V ; i < GAGE_MAX_RANGES ; i++)
			ranges[i].ir_flag &= ~bt_flag;
	}


	if (board_type & GAGE_ASSUME_CS2125)  {
		if ((ee_options & EEPROM_OPTIONS_EIB_CAPABLE) == 0)  {
			bt_flag = B_T_DOUBLE_UP_BITS (GAGE_ASSUME_CS2125);
			if (version >= 0x0130)  {	/*	5V, 2V, 1V, 500mV and 200mV.	*/
				ranges[GAGE_PM_200_MV].ir_flag |= bt_flag;
			}else if (version & 0x0002)  {	/*	2V, 1V, 500mV and 200mV.	*/
				ranges[GAGE_PM_5_V].ir_flag &= ~bt_flag;
				ranges[GAGE_PM_200_MV].ir_flag |= bt_flag;
			}
		}
	}else if ((board_type == GAGE_ASSUME_CS12100) ||
		      (board_type == GAGE_ASSUME_CS14100) ||
		      (board_type == GAGE_ASSUME_CS8500))  {

		bt_flag = B_T_DOUBLE_UP_BITS (board_type);
		ranges[GAGE_PM_10_V].ir_flag &= ~bt_flag;

		ranges[GAGE_PM_50_MV].ir_flag &= ~bt_flag;

	}else if (board_type == GAGE_ASSUME_CS3200)  {
		int		i;

		int		maxi = GAGE_PM_50_MV;

		bt_flag = B_T_DOUBLE_UP_BITS (board_type);
		for (i = 0 ; i <= maxi ; i++)
			ranges[i].ir_flag &= ~bt_flag;
		ranges[GAGE_PM_10_V].ir_flag |= bt_flag;
		ranges[GAGE_PM_2_V].ir_flag |= bt_flag;
		ranges[GAGE_PM_500_MV].ir_flag |= bt_flag;
		ranges[GAGE_PM_200_MV].ir_flag |= bt_flag;
		ranges[GAGE_PM_100_MV].ir_flag |= bt_flag;

		ranges[GAGE_PM_5_V].ir_flag |= bt_flag;
		ranges[GAGE_PM_1_V].ir_flag |= bt_flag;
		ranges[GAGE_PM_5_V].ir_calc = 1.0;
		ranges[GAGE_PM_1_V].ir_calc = 1.0;
		if ((ee_options & EEPROM_OPTIONS_DIRECT_INPUT) != 0)  {
			lstrcpy(ranges[GAGE_PM_10_V].ir_text, "ECL");
			ranges[GAGE_PM_10_V].ir_calc = value_ECL;

			lstrcpy(ranges[GAGE_PM_5_V].ir_text, "PECL");
			ranges[GAGE_PM_5_V].ir_calc = value_PECL;

			lstrcpy(ranges[GAGE_PM_2_V].ir_text, "LVDS");
			ranges[GAGE_PM_2_V].ir_calc = value_LVDS;

			lstrcpy(ranges[GAGE_PM_1_V].ir_text, "ECL");
			ranges[GAGE_PM_1_V].ir_calc = value_ECL;

			lstrcpy(ranges[GAGE_PM_500_MV].ir_text, "ECL");
			ranges[GAGE_PM_500_MV].ir_calc = value_ECL;

			lstrcpy(ranges[GAGE_PM_200_MV].ir_text, "ECL");
			ranges[GAGE_PM_200_MV].ir_calc = value_ECL;

			lstrcpy(ranges[GAGE_PM_100_MV].ir_text, "ECL");
			ranges[GAGE_PM_100_MV].ir_calc = value_ECL;

		}else{
			lstrcpy(ranges[GAGE_PM_10_V].ir_text, "TTL");
			ranges[GAGE_PM_10_V].ir_calc = value_TTL;

			lstrcpy(ranges[GAGE_PM_5_V].ir_text, "CMOS");
			ranges[GAGE_PM_5_V].ir_calc = value_CMOS;

			lstrcpy(ranges[GAGE_PM_2_V].ir_text, "TTL");
			ranges[GAGE_PM_2_V].ir_calc = value_TTL;

			lstrcpy(ranges[GAGE_PM_1_V].ir_text, "TTL");
			ranges[GAGE_PM_1_V].ir_calc = value_TTL;

			lstrcpy(ranges[GAGE_PM_500_MV].ir_text, "TTL");
			ranges[GAGE_PM_500_MV].ir_calc = value_TTL;

			lstrcpy(ranges[GAGE_PM_200_MV].ir_text, "TTL");
			ranges[GAGE_PM_200_MV].ir_calc = value_TTL;

			lstrcpy(ranges[GAGE_PM_100_MV].ir_text, "TTL");
			ranges[GAGE_PM_100_MV].ir_calc = value_TTL;
		}
	}else if (board_type == GAGE_ASSUME_CS1610)  {
		bt_flag = B_T_DOUBLE_UP_BITS (board_type);
		if ((version & EEPROM_VERSION_CS16XX_EIR) == 0)  {	/*	200mV, 100mV and 50mV not supported.	*/
			ranges[GAGE_PM_200_MV].ir_flag &= ~bt_flag;
			ranges[GAGE_PM_100_MV].ir_flag &= ~bt_flag;
			ranges[GAGE_PM_50_MV].ir_flag  &= ~bt_flag;

		}else{	/*	200mV, 100mV and 50mV are supported.	*/
			ranges[GAGE_PM_200_MV].ir_flag |= bt_flag;
			ranges[GAGE_PM_100_MV].ir_flag |= bt_flag;
			ranges[GAGE_PM_50_MV].ir_flag  |= bt_flag;
		}
	}else if (board_type == GAGE_ASSUME_CS82G)  {
		bt_flag = B_T_DOUBLE_UP_BITS (board_type);
		ranges[GAGE_PM_10_V].ir_flag |= bt_flag;
		ranges[GAGE_PM_50_MV].ir_flag &= ~bt_flag;

	}else if (board_type & GAGE_ASSUME_CS1016)  {
		bt_flag = B_T_DOUBLE_UP_BITS (GAGE_ASSUME_CS1016);
		if ((version & 0x0ff0) == 0x0100)  {		/*	1V only.	*/
			ranges[GAGE_PM_2_V].ir_flag &= ~bt_flag;
			ranges[GAGE_PM_1_V].ir_flag |= bt_flag;
		}else{										/*	2V only.	*/
			ranges[GAGE_PM_2_V].ir_flag |= bt_flag;
			ranges[GAGE_PM_1_V].ir_flag &= ~bt_flag;
		}
	}else if (board_type == GAGE_ASSUME_CS14200) {
		bt_flag = B_T_DOUBLE_UP_BITS (GAGE_ASSUME_CS14200);
		ranges[GAGE_PM_5_V].ir_flag |= bt_flag;
		ranges[GAGE_PM_2_V].ir_flag |= bt_flag;
		ranges[GAGE_PM_1_V].ir_flag |= bt_flag;
		ranges[GAGE_PM_500_MV].ir_flag |= bt_flag;
		ranges[GAGE_PM_200_MV].ir_flag |= bt_flag;
		ranges[GAGE_PM_100_MV].ir_flag |= bt_flag;

	}else if (board_type == GAGE_ASSUME_CS12400) {
		bt_flag = B_T_DOUBLE_UP_BITS (GAGE_ASSUME_CS12400);
		ranges[GAGE_PM_5_V].ir_flag |= bt_flag;
		ranges[GAGE_PM_2_V].ir_flag |= bt_flag;
		ranges[GAGE_PM_1_V].ir_flag |= bt_flag;
		ranges[GAGE_PM_500_MV].ir_flag |= bt_flag;
		ranges[GAGE_PM_200_MV].ir_flag |= bt_flag;
		ranges[GAGE_PM_100_MV].ir_flag |= bt_flag;

	}else if (board_type == GAGE_ASSUME_CS14105) {
		int i;
		bt_flag = B_T_DOUBLE_UP_BITS (GAGE_ASSUME_CS14105);
		
		for (i = 0 ; i < GAGE_MAX_RANGES ; i++)
			ranges[i].ir_flag = 0;
		ranges[GAGE_PM_500_MV].ir_flag |= bt_flag;
		ranges[GAGE_PM_500_MV].ir_calc = 0.738;

	}else if (board_type == GAGE_ASSUME_CS85G)  {
		int i;
		bt_flag = B_T_DOUBLE_UP_BITS (GAGE_ASSUME_CS85G);
		for (i = 0 ; i < GAGE_MAX_RANGES ; i++)
			ranges[i].ir_flag &= ~bt_flag;

		i = -1;
		if (ee_options & EEPROM_OPTIONS_DIRECT_INPUT)		//Full range
		{
			ranges[++i].constant= GAGE_PM_50_V;		/* +/- 50V, 10v/Div */
			ranges[i].ir_flag	= bt_flag;
			ranges[i].ir_calc	= 50.0;
			lstrcpy(ranges[i].ir_text, "+/-50v");
		}
		ranges[++i].constant= GAGE_PM_20_V;		/* +/- 20V, 4v/Div */
		ranges[i].ir_flag	= bt_flag;
		ranges[i].ir_calc	= 20.0;
		lstrcpy(ranges[i].ir_text, "+/-20v");

		ranges[++i].constant= GAGE_PM_10_V;		/* +/- 8V, 2v/Div */
		ranges[i].ir_flag	= bt_flag;
		ranges[i].ir_calc	= 10.0;
		lstrcpy(ranges[i].ir_text, "+/-10v");

		ranges[++i].constant= GAGE_PM_5_V;		/* +/- 5V, 1v/Div */
		ranges[i].ir_flag	= bt_flag;
		ranges[i].ir_calc	= 5.0;
		lstrcpy(ranges[i].ir_text, "+/-5v");

		ranges[++i].constant= GAGE_PM_2_V;		/* +/- 2V, 500mv/Div */
		ranges[i].ir_flag	= bt_flag;
		ranges[i].ir_calc	= 2.0;
		lstrcpy(ranges[i].ir_text, "+/-2v");

		ranges[++i].constant= GAGE_PM_1_V;		/* +/- 1V, 200mv/Div */
		ranges[i].ir_flag	= bt_flag;
		ranges[i].ir_calc	= 1.0;
		lstrcpy(ranges[i].ir_text, "+/-1v");

		ranges[++i].constant= GAGE_PM_500_MV;		/* +/- 500mv, 100mv/Div */
		ranges[i].ir_flag	= bt_flag;
		ranges[i].ir_calc	= 0.5;
		lstrcpy(ranges[i].ir_text, "+/-500mv");

		ranges[++i].constant= GAGE_PM_200_MV;		/* +/- 250mv, 50mv/Div */
		ranges[i].ir_flag	= bt_flag;
		ranges[i].ir_calc	= 0.2;
		lstrcpy(ranges[i].ir_text, "+/-200mv");

		ranges[++i].constant= GAGE_PM_100_MV;		/* +/- 100mv, 20mv/Div */
		ranges[i].ir_flag	= bt_flag;
		ranges[i].ir_calc	= 0.1;
		lstrcpy(ranges[i].ir_text, "+/-100mv");

		ranges[++i].constant= GAGE_PM_50_MV;		/* +/- 50mV, 10mv/Div */
		ranges[i].ir_flag	= bt_flag;
		ranges[i].ir_calc	= 0.05;
		lstrcpy(ranges[i].ir_text, "+/-50mv");

		ranges[++i].constant= GAGE_PM_20_MV;		/* +/- 25mV, 5mv/Div */
		ranges[i].ir_flag	= bt_flag;
		ranges[i].ir_calc	= 0.02;
		lstrcpy(ranges[i].ir_text, "+/-20mv");

		if (ee_options & EEPROM_OPTIONS_DIRECT_INPUT)		//Full range
		{
			ranges[++i].constant= GAGE_PM_10_MV;		/* +/- 10mV, 2mv/Div */
			ranges[i].ir_flag	= bt_flag;
			ranges[i].ir_calc	= 0.01;
			lstrcpy(ranges[i].ir_text, "+/-10mv");

			ranges[++i].constant= GAGE_PM_5_MV;			/* +/- 5mV, 1mv/Div */
			ranges[i].ir_flag	= bt_flag;
			ranges[i].ir_calc	= 0.005;
			lstrcpy(ranges[i].ir_text, "+/-5mv");
		}

	}

}	/*	End of update_range_table_for_version ().	*/

/*----------------------------------------------------------*/
#ifndef __LINUX_KNL__
char	*value_and_units_to_text (double value, char *units)

{
	static char	buf[20];

	value *= 1000000000L;
	if (fabs (value) == 0)  {
#if _MSC_VER >= 1400
		sprintf_s (buf, sizeof(buf), "%+4.3f %s", value, units);
#else
		sprintf (buf, "%+4.3f %s", value, units);
#endif
		return (buf);
	}
	if (fabs (value) < 1000)  {
#if _MSC_VER >= 1400
		sprintf_s (buf, sizeof(buf), "%+4.3f n%s", value, units);
#else
		sprintf (buf, "%+4.3f n%s", value, units);
#endif
		return (buf);
	}
	value /= 1000;
	if (fabs (value) < 1000)  {
#if _MSC_VER >= 1400
		sprintf_s (buf, sizeof(buf), "%+4.3f u%s", value, units);
#else
		sprintf (buf, "%+4.3f u%s", value, units);
#endif
		return (buf);
	}
	value /= 1000;
	if (fabs (value) < 1000)  {
#if _MSC_VER >= 1400
		sprintf_s (buf, sizeof(buf), "%+4.3f m%s", value, units);
#else
		sprintf (buf, "%+4.3f m%s", value, units);
#endif
		return (buf);
	}
	value /= 1000;
	if (fabs (value) < 1000)  {
#if _MSC_VER >= 1400
		sprintf_s (buf, sizeof(buf), "%+4.3f %s", value, units);
#else
		sprintf (buf, "%+4.3f %s", value, units);
#endif
		return (buf);
	}
	value /= 1000;
	if (fabs (value) < 1000)  {
#if _MSC_VER >= 1400
		sprintf_s (buf, sizeof(buf), "%+4.3f K%s", value, units);
#else
		sprintf (buf, "%+4.3f K%s", value, units);
#endif
		return (buf);
	}
	value /= 1000;
	if (fabs (value) < 1000)  {
#if _MSC_VER >= 1400
		sprintf_s (buf, sizeof(buf), "%+4.3f M%s", value, units);
#else
		sprintf (buf, "%+4.3f M%s", value, units);
#endif
		return (buf);
	}
	value /= 1000;
#if _MSC_VER >= 1400
	sprintf_s (buf, sizeof(buf), "%+4.3f G%s", value, units);
#else
	sprintf (buf, "%+4.3f G%s", value, units);
#endif
	return (buf);

}	/*  End of value_and_units_to_text ().  */
#endif
/*----------------------------------------------------------*/

/*	End of STRUCTS.C.	*/

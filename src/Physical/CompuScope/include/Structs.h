/********************************************************\
*   STRUCTS.H	    VERSION 3.80.00						*
*                                                       *                                                       *
*   COPYRIGHT (C) GAGE APPLIED INC                      *
*                                                       *
*   COPYRIGHT (C) GAGE APPLIED TECNOLOGIES INC          **                                                       *
*                                                       *
*	LAST UPDATE:		10/28/04                        *
\********************************************************/
/*----------------------------------------------------------*/

#ifndef	__STRUCTS_H__
#define	__STRUCTS_H__


/*----------------------------------------------------------*/

#define	__BOARD_DEF__

#ifdef	__GAGESCOPE__
#undef	__BOARD_DEF__
#endif

#ifdef	__CDRIVERS__
#ifndef	__BOARD_DEF__
#define	__BOARD_DEF__
#endif
#endif

/*----------------------------------------------------------*/

#ifdef	__cplusplus

extern "C"	{

#endif

/*----------------------------------------------------------*/

#define	B_T_DOUBLE_UP_BITS(w)	(((unsigned long)(w) << 16)|(w))
#define	B_T_NONE				B_T_DOUBLE_UP_BITS(GAGE_ASSUME_NOTHING)	/*	Board type flags for a missing CompuScope.  */
#define	B_T_CSLITE				B_T_DOUBLE_UP_BITS(GAGE_ASSUME_CSLITE)	/*	Board type flags for the CompuScope LITE.  */
#define	B_T_CS250				B_T_DOUBLE_UP_BITS(GAGE_ASSUME_CS250)	/*	Board type flags for the CompuScope 250.  */
#define	B_T_CS225				B_T_DOUBLE_UP_BITS(GAGE_ASSUME_CS225)	/*	Board type flags for the CompuScope 225.  */
#define	B_T_CS220				B_T_DOUBLE_UP_BITS(GAGE_ASSUME_CS220)	/*	Board type flags for the CompuScope 220.  */
#define	B_T_CS512				B_T_DOUBLE_UP_BITS(GAGE_ASSUME_CS512)	/*	Board type flags for the CompuScope 512.  */
#define	B_T_CS1012				B_T_DOUBLE_UP_BITS(GAGE_ASSUME_CS1012)	/*	Board type flags for the CompuScope 1012.  */
#define	B_T_CS6012				B_T_DOUBLE_UP_BITS(GAGE_ASSUME_CS6012)	/*	Board type flags for the CompuScope 6012.  */
#define	B_T_CS8012				B_T_DOUBLE_UP_BITS(GAGE_ASSUME_CS8012)	/*	Board type flags for the CompuScope 8012.  */
#define	B_T_CS8012_TYPE			B_T_DOUBLE_UP_BITS(GAGE_ASSUME_CS8012_TYPE)	/*	Board type flags for the CompuScope 8012 based boards (includes an EEPROM, 50 OHM inputs, etc.).  */
#define	B_T_CS2125				B_T_DOUBLE_UP_BITS(GAGE_ASSUME_CS2125)	/*	Board type flags for the CompuScope 2125.  */
#define	B_T_CS265				B_T_DOUBLE_UP_BITS(GAGE_ASSUME_CS265)	/*	Board type flags for the CompuScope 265.  */
#define	B_T_CS8500				B_T_DOUBLE_UP_BITS(GAGE_ASSUME_CS8500)	/*	Board type flags for the CompuScope 8500.  */
#define	B_T_CS82G				B_T_DOUBLE_UP_BITS(GAGE_ASSUME_CS82G)	/*	Board type flags for the CompuScope 82G.  */ //nat 240700
#define	B_T_CS3200				B_T_DOUBLE_UP_BITS(GAGE_ASSUME_CS3200)	/*	Board type flags for the CompuScope 3200.  */
#define	B_T_CS12100				B_T_DOUBLE_UP_BITS(GAGE_ASSUME_CS12100)	/*	Board type flags for the CompuScope 12100.  */
#define	B_T_CS12130				B_T_DOUBLE_UP_BITS(GAGE_ASSUME_CS12130)	/*	Board type flags for the CompuScope 12130.  */
#define	B_T_CS12400				B_T_DOUBLE_UP_BITS(GAGE_ASSUME_CS12400)	/*	Board type flags for the CompuScope 12400.  */
#define	B_T_CS14100				B_T_DOUBLE_UP_BITS(GAGE_ASSUME_CS14100)	/*	Board type flags for the CompuScope 14100.  */
#define	B_T_CS1610				B_T_DOUBLE_UP_BITS(GAGE_ASSUME_CS1610)	/*	Board type flags for the CompuScope 1610.  */
#define	B_T_CS1016				B_T_DOUBLE_UP_BITS(GAGE_ASSUME_CS1016)	/*	Board type flags for the CompuScope 1016.  */
#define	B_T_CS85G				B_T_DOUBLE_UP_BITS(GAGE_ASSUME_CS85G)	/*	Board type flags for the Raptor CS85G.  */
#define	B_T_CS14200				B_T_DOUBLE_UP_BITS(GAGE_ASSUME_CS14200)	/*	Board type flags for the CompuScope 14200.  */
//#define	B_T_CS14105				B_T_DOUBLE_UP_BITS(GAGE_ASSUME_CS14105)	/*	Board type flags for the CompuScope 14105.  */
#define B_T_RAZOR				B_T_DOUBLE_UP_BITS(GAGE_ASSUME_RAZOR)	/*	Board type flags for the Razor boards.  */

#define	B_T_SINGLE				0xffff0000UL	/*	Board type flags mask for single channel mode.  */
#define	B_T_DUAL				0x0000ffffUL	/*	Board type flags mask for dual channel mode.  */
#define	B_T_ALL_GAGE_CARDS		(B_T_CSLITE | B_T_CS250 | B_T_CS225 | B_T_CS220 | B_T_CS512 | B_T_CS1012 | B_T_CS6012 | B_T_CS8012 | B_T_CS2125 | B_T_CS265 | B_T_CS8500 | B_T_CS12100 | B_T_CS12130 | B_T_CS14100 | B_T_CS1016 | B_T_CS14106 | B_T_CS14105 | B_T_RAZOR)
#define	B_T_ALL_NON_GAGE_CARDS	(B_T_NONE)
#define	B_T_ALL_CARDS			(B_T_ALL_GAGE_CARDS | B_T_ALL_NON_GAGE_CARDS)

#define	B_T_GENERIC				B_T_ALL_GAGE_CARDS	/*	Board type flags for a generic CompuScope (when no boards are found during initialization).  */

/*----------------------------------------------------------*/

#define		SRTI_INDEX_20_DEFINED_FOR_CS1610

/*----------------------------------------------------------*/

#define	SRTI_1_HZ		0
#define	SRTI_2_HZ		1
#define	SRTI_5_HZ		2
#define	SRTI_10_HZ		3
#define	SRTI_20_HZ		4
#define	SRTI_50_HZ		5
#define	SRTI_100_HZ		6
#define	SRTI_200_HZ		7
#define	SRTI_500_HZ		8
#define	SRTI_1_KHZ		9
#define	SRTI_2_KHZ		10
#define	SRTI_5_KHZ		11
#define	SRTI_10_KHZ		12
#define	SRTI_20_KHZ		13
#define	SRTI_50_KHZ		14
#define	SRTI_100_KHZ	15
#define	SRTI_200_KHZ	16
#define	SRTI_500_KHZ	17
#define	SRTI_1_MHZ		18
#define	SRTI_2_MHZ		19
#define	SRTI_2_5_MHZ	20
#define	SRTI_5_MHZ		21
#define	SRTI_10_MHZ		22
#define	SRTI_12_5_MHZ	23
#define	SRTI_20_MHZ		24
#define	SRTI_25_MHZ		25
#define	SRTI_30_MHZ		26
#define	SRTI_40_MHZ		27
#define	SRTI_50_MHZ		28
#define	SRTI_60_MHZ		29
#define	SRTI_65_MHZ		30
#define	SRTI_80_MHZ		31
#define	SRTI_100_MHZ	32
#define	SRTI_120_MHZ	33
#define	SRTI_125_MHZ	34
#define	SRTI_130_MHZ	35
#define	SRTI_150_MHZ	36
#define	SRTI_200_MHZ	37
#define	SRTI_250_MHZ	38
#define	SRTI_300_MHZ	39
#define	SRTI_500_MHZ	40
#define	SRTI_1_GHZ		41
#define	SRTI_2_GHZ		42
#define	SRTI_2_5_GHZ	43

#define	SRTI_5_GHZ		44
#define	SRTI_8_GHZ		45
#define	SRTI_10_GHZ		46
#define	SRTI_EXTERNAL	47

#define	DEFAULT_SAMPLE_RATE_INDEX		SRTI_5_MHZ		/*	5 MHz, maximum sample rate common to all CompuScope cards.	*/
#define	ETS_CS250_SAMPLE_RATE_INDEX		SRTI_1_GHZ		/*	1 GHz.	*/
#define	ETS_CS2125_SAMPLE_RATE_INDEX	SRTI_250_MHZ	/*	250 MHz.	*/
#define	EXTERNAL_SAMPLE_RATE_INDEX		SRTI_EXTERNAL	/*	EXTERNAL Clock source, actual sample rate for display and calculations taken from the command line for "EXTCLKMIN=".	*/

#define	captured_gain_index(cg,bt)	(((bt==B_T_CS250)&&(cg==1))?0:cg)	/*	CS250 - Prior to Version 1.8.	*/

/*----------------------------------------------------------*/

typedef struct  {
	int32	sample_rate;								/*	For gage_capture_mode, indirectly.	*/
	int16	opmode, srindex;							/*	For gage_capture_mode.	*/
	int16	range_a, couple_a, range_b, couple_b;		/*	For gage_input_control.	*/
	int16	imped_a, imped_b, diff_in_a, diff_in_b;		/*	For gage_input_control.	*/
	int16	source, slope, level, range_e, couple_e;	/*	For gage_trigger_control.	*/
	int16	source_2, slope_2, level_2;					/*	For gage_trigger_control_2.	*/
	int32	depth;										/*	For gage_trigger_control.	*/
} boarddef;

/*----------------------------------------------------------*/

typedef struct {
	int16	rate;			/*	Rate used for setting the CompuScope sample rate.	*/
	int16	mult;			/*	Multiplier used for setting the CompuScope sample rate.	*/
	uInt32	sr_flag;		/*	Flag to indicate which board supports which sample rate.	*/
	uInt32	rt_sr_flag;		/*	Flag to indicate which board supports which sample rate in real time mode.	*/
	uInt32	rts_sr_flag;	/*	Flag to indicate which board supports which sample rate in real time mode and is safe to use.	*/
	float	sr_calc;		/*	Time between samples (in ns).  Used in calculating the number of points.	*/
	char	sr_text[12];		/*	Text associated with the current settings of the CompuScope sample rate.	*/
} srtype;

/*----------------------------------------------------------*/

typedef struct {
	int16	constant;	/*	Value of the driver constant for the input range.	*/
	uInt32	ir_flag;	/*	Flag indicates which board supports which gain.	*/
	double	ir_calc;	/*	Multiplier used for display voltage amplitude.	*/
	char	ir_text[12];	/*	Text associated with the input range.	*/
} irtype;

/*----------------------------------------------------------*/

#ifndef	STRUCTS_SOURCE

#ifdef	__BOARD_DEF__

extern boarddef	board;
extern int		board_number;
extern boarddef	boards[];

#endif

extern srtype far	sample_rate_table[];
extern int16		sample_rate_table_max;
extern irtype far	ranges[];
extern int16		range_table_max;

#define	RANGE_MAX	range_table_max

#endif

/*----------------------------------------------------------*/

int16	best_sample_rate (uInt16 board_type, int16 op_mode, int16 external_clock_in_use);
int16	best_rt_sample_rate (uInt16 board_type, int16 boards_in_system, boarddef *board, int16 external_clock_in_use);
void	update_sr_table_for_osc (uInt16 version, uInt16 board_type, uInt32 ee_options);
void	update_sr_table_for_ext_clk_only (void);
void	update_sr_table_for_x1_clk_only (uInt16 board_type);
void	update_sr_table_for_real_time (int16 boards_on_bus, uInt16 version, uInt16 board_type, uInt32 ee_options);
void	update_range_table_for_version (uInt16 version, uInt16 board_type, uInt32 ee_options);
char	*value_and_units_to_text (double value, char *units);

/*----------------------------------------------------------*/

#ifdef	__cplusplus

}

#endif

/*----------------------------------------------------------*/

#endif	/*	__STRUCTS_H__	*/

/*----------------------------------------------------------*/

/*	End of STRUCTS.H.	*/

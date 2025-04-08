#ifndef __CS_CVI_H__
#define __CS_CVI_H__

	#if defined(_CVI_)
		#include <formatio.h>
		#include <ansi_c.h>
		#include <utility.h>
	
		#ifndef INVALID_FILE_ATTRIBUTES
			#define INVALID_FILE_ATTRIBUTES 0
		#endif

		#ifndef GetFileAttributes
			DWORD GetFileAttributes(LPCTSTR szIniFile)
			{
				long lFileSize;
				return (DWORD)GetFileInfo(szIniFile, &lFileSize);
			}			  
		#endif

		#define CsBeep(x,y) Beep
		#define _getch GetKey
		
		#define USE_LOCAL_TCHAR
			
	#else

		#define CsBeep(x,y) Beep((x),(y))
			
	#endif // __CVI__
			

#endif // __CS_CVI_H__

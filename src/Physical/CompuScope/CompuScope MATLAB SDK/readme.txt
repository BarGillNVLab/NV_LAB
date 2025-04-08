RELEASE NOTES

*****************************************************
COMPUSCOPE SDK FOR MATLAB Version 5.06.20
FOR WINDOWS

*****************************************************

The CompuScope SDK for MATLAB for Windows includes 
complete manuals in PDF form and several sample programs
that illustrate control and operation of Compuscope 
hardware in several operating modes. The SDK is all
that is required to completely operate CompuSCope hardware 
from the MATLAB environment.

Please refer to the CompuScope SDK for MATLAB manual 
for the requirements for using this SDK and 
descriptions of the sample programs.


-----------------------------------------------------
ENHANCEMENTS
-----------------------------------------------------

* License Keys are no longer required when installing
  CompuScope SDK.

-----------------------------------------------------
ABOUT THE COMPUSCOPE SDK FOR MATLAB FOR WINDOWS
-----------------------------------------------------

NOTE: When writing an M-file for the CompuScope SDK 
      for MATLAB, do not use the MATLAB "clear all" 
      function.  This will clear out all function 
      pointers and the dlls will have to be 
      reinitialized.  Use the "clear" function 
      instead.

Gage's CompuScope SDK for MATLAB for Windows allows 
you to control one or more CompuScope cards from the 
MATLAB environment.

This CompuScope SDK for Win7/Win8/Win10 supports
the following Gage PCI Express CompuScopes
models: Cobra, CobraMax, Oscar, Razor, RazorMax,
Octopus, Octave and EON Express. In addition,
the SDK also supports the FCiX CompuScope. 

Please note that support for USB CompuScope and PCI
CompuScope models: Eon, Cobra, CobraMax, BASE-8, Razor,
Octopus and USB has been discontinued in the version
5.00.50 CompuScope driver. Please visit the Gage website
(www.gage-applied.com/Support) to download 
the 4.80.22 CompuScope driver that was the last 
version which supported these CompuScopes.


-----------------------------------------------------
WHAT TO LOOK OUT FOR WHEN INSTALLING THE COMPUSCOPE 
SDK FOR MATLAB FOR WINDOWS
-----------------------------------------------------

1) You MUST install the CompuScope Drivers before 
   attempting to use the CompuScope SDK for MATLAB.  
   Without the proper drivers, the CompuScope SDK for 
   MATLAB will not function properly.  See the Driver 
   Installation section of the Startup Guide for 
   instructions on installing the CompuScope Windows
   Drivers and the CompuScope SDK for MATLAB for 
   Windows.

2) The installation will fail if the installer is not 
   an Administrator.

3) Please note that you will be asked to enter a 
   software key during the SDK installation process.  
   This software key is provided upon purchase of the 
   SDK.

4) We recommend that you use the default installation 
   directory; however, you will be prompted to change 
   it if you wish.

5) If during the installation of the SDK you receive 
   a message stating that the MATLAB path could not 
   be modified to include the CompuScope MATLAB SDK 
   path, then you will have to do one of the 
   following:

   a) Copy the contents of addpath.m from the SDK's 
      Main directory to your MATLAB 
      directory\toolbox\local\startup.m, if this file 
      currently exists or else create the file with 
      the contents of addpath.m.

   b) Run addpath.m from the SDK's Main directory 
      every time you load up MATLAB.

   c) Add the path of the three SDK directories (Adv, 
      CsMl, and Main) through the "Set Path" function 
      under "File".

See your CompuScope SDK for MATLAB User's Guide for 
more details on using the CompuScope SDK for MATLAB.



=====================================================
Comments and suggestions can be addressed to:

Gage Project Manager - CompuScope SDK for MATLAB for Windows

In North America:
Tel:    800-567-GAGE
Fax:    800-780-8411

Outside North America:
Tel:    +1-514-633-7447
Fax:    +1-514-633-0770

E-mail:   prodinfo@gage-applied.com
Web site: www.gage-applied.com

[status, cmdout] = system('ping 132.64.56.72');
disp(cmdout)
disp(status)

%% setup5 SRS IP:132.64.56.72
instr = visadev("TCPIP0::132.64.56.72::inst0::INSTR"); 
writeline(instr, "*IDN?");
idn = readline(instr);
disp(idn);


writeline(instr, "FREQ?");
freq = readline(instr)
%writeline(instr, "FREQ 100E6");

writeline(instr, "AMPR?");
amp = readline(instr)
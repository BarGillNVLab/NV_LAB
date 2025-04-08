function psseq = convert_PPH_to_PSSequence(P_PH_array)
%CONVERT_PPH_TO_PSSEQUENCE creates PSSequence from array of P or PH objects
%
%   This is a compatibility function. It is needed to convert the sequence
%   data created using old API P and PH classes into a new PSSequence class

tick = double([P_PH_array.ticks]);
digi = double([P_PH_array.digital]);
ao0 = double([P_PH_array.analog0]);
ao1 = double([P_PH_array.analog1]);


psseq = PSSequence([tick(:), digi(:), ao0(:), ao1(:)]);

end


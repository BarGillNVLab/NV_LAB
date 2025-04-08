function [freq, signal_1, sterr_1, signal_2, sterr_2] = extractESRdata(exp)

freq = exp.frequency;
if isempty(exp.mirrorSweepAround)
    [~, signal_1, sterr_1, ~] = extract1Ddata(exp);
    signal_2 = [];
    sterr_2 = [];
else
    [~, ~, signal_1, signal_2, ~, sterr_1, sterr_2, ~] = extract2Ddata(exp);
end

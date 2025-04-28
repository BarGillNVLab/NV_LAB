% disp(size(squeeze([num2str(4) ' x ' num2str(7)])))
% disp(["Default ROI:" "" "";convertCharsToStrings(num2str(4)) " x " convertCharsToStrings(num2str(7))])
r = strcat(num2str(4), ' x ', num2str(7));
disp(string(join(['Default ROI:',newline, r])))
disp(class(string(join(['Default ROI:',newline, r]))))
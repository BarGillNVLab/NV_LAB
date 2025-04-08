function err2warning(err)
%ERR2WARNING receives error and sends warning of the same content

warning(getReport(err, 'extended', 'hyperlinks', 'on'))    % send error as warning

end


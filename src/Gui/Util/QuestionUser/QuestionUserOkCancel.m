function isOk = QuestionUserOkCancel( title, questionMsg )
%QUESTIONUSEROKCANCEL creates a msgbox with a simple ok\cancel question.
%   isOk - boolean. Did the user pressed "ok"
isOk = QuestionUser(title, questionMsg, {'OK', 'Cancel'}) == 1;
end


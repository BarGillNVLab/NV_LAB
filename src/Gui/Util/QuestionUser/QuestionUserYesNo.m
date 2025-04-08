function isYes = QuestionUserYesNo( title, questionMsg )
%QUESTIONUSERYESNO creates a msgbox with a simple yes\no question.
%   isYes - boolean. Did the user press "yes"
isYes = QuestionUser(title, questionMsg, {'Yes', 'No'}) == 1;
end
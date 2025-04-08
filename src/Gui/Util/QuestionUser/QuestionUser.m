function answerIndex = QuestionUser(title, questionMsg, buttonsStringsCell)
%QUESTIONUSER creates a msgbox with a simple multiple-answers question.
%   answerIndex - integer. Index of the user answer (or -1 if the user canceled)
selection = questdlg( ...
    questionMsg,...
    title,...
    buttonsStringsCell{:}, ...
    buttonsStringsCell{1} ... <--- default button
    );
answerIndex = find(strcmp(buttonsStringsCell, selection));
if length(answerIndex) > 1
    answerIndex = answerIndex(1);
elseif isempty(answerIndex)
    answerIndex = -1;
end
end


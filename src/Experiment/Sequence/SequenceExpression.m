classdef SequenceExpression
    %SEQUENCEEXPRESSION Safe arithmetic over named sequence variables
    %   Evaluates the little expressions a user types into a pulse duration
    %   field - 'tau', '2*tau', 'piTime/2', '(tau + 0.1)*2' - against a set
    %   of declared variables.
    %
    %   This exists instead of eval. A duration field is a place a user
    %   types into, and eval there would run whatever they typed with the
    %   full power of MATLAB, in the middle of an experiment. Everything
    %   here is parsed by hand and the grammar is deliberately tiny:
    %
    %       expr    := term (('+' | '-') term)*
    %       term    := factor (('*' | '/') factor)*
    %       factor  := unary ('^' factor)?          % right associative
    %       unary   := ('-' | '+')? primary
    %       primary := number | name | '(' expr ')'
    %
    %   There are no function calls, no indexing, no assignment and no
    %   workspace access - a name that is not a declared variable is an
    %   error, not a lookup.
    %
    %   Examples:
    %       v.tau = 1.5;
    %       SequenceExpression.evaluate('2*tau + 0.1', v)   % -> 3.1
    %
    %   See also EXPUSERSEQUENCE, USERSEQUENCESPEC

    methods (Static)
        function [value, isOk, message] = evaluate(expression, variables)
            % VALUE = EVALUATE(EXPRESSION, VARIABLES) computes a duration.
            %   VARIABLES is a struct mapping variable name to a scalar.
            %   On failure, ISOK is false and MESSAGE says why.
            value = [];
            isOk = true;
            message = '';

            if ~exist('variables', 'var'); variables = struct(); end
            if ~ischar(expression); expression = char(expression); end

            [tokens, isOk, message] = SequenceExpression.tokenize(expression);
            if ~isOk; return; end
            if isempty(tokens)
                isOk = false;
                message = 'the expression is empty.';
                return
            end

            state.tokens = tokens;
            state.pos = 1;
            state.variables = variables;

            try
                [value, state] = SequenceExpression.parseExpression(state);
            catch err
                value = [];
                isOk = false;
                message = err.message;
                return
            end

            if state.pos <= numel(state.tokens)
                value = [];
                isOk = false;
                message = sprintf('unexpected "%s" after a complete expression.', ...
                    state.tokens(state.pos).text);
                return
            end

            if ~isscalar(value) || ~isfinite(value)
                value = [];
                isOk = false;
                message = 'the expression did not produce a single finite number.';
            end
        end

    end

    %% Tokenizer
    methods (Static, Access = private)
        function [tokens, isOk, message] = tokenize(expression)
            tokens = struct('kind', {}, 'text', {}, 'value', {});
            isOk = true;
            message = '';

            i = 1;
            n = length(expression);
            while i <= n
                c = expression(i);

                if isspace(c)
                    i = i + 1;
                    continue
                end

                if any(c == '+-*/^()')
                    tokens(end+1) = struct('kind', 'op', 'text', c, 'value', NaN); %#ok<AGROW>
                    i = i + 1;
                    continue
                end

                % A number, possibly with a decimal point or an exponent
                if isstrprop(c, 'digit') || (c == '.' && i < n && isstrprop(expression(i+1), 'digit'))
                    j = i;
                    while j <= n && (isstrprop(expression(j), 'digit') || expression(j) == '.')
                        j = j + 1;
                    end
                    if j <= n && any(expression(j) == 'eE')
                        k = j + 1;
                        if k <= n && any(expression(k) == '+-'); k = k + 1; end
                        if k <= n && isstrprop(expression(k), 'digit')
                            j = k;
                            while j <= n && isstrprop(expression(j), 'digit'); j = j + 1; end
                        end
                    end
                    text = expression(i:j-1);
                    value = str2double(text);
                    if isnan(value)
                        isOk = false;
                        message = sprintf('"%s" is not a valid number.', text);
                        return
                    end
                    tokens(end+1) = struct('kind', 'number', 'text', text, 'value', value); %#ok<AGROW>
                    i = j;
                    continue
                end

                % A name
                if isletter(c) || c == '_'
                    j = i;
                    while j <= n && (isletter(expression(j)) || isstrprop(expression(j), 'digit') || expression(j) == '_')
                        j = j + 1;
                    end
                    tokens(end+1) = struct('kind', 'name', 'text', expression(i:j-1), 'value', NaN); %#ok<AGROW>
                    i = j;
                    continue
                end

                isOk = false;
                message = sprintf('"%s" is not allowed here. Use numbers, variable names and + - * / ^ ( ).', c);
                return
            end
        end
    end

    %% Recursive descent parser
    methods (Static, Access = private)
        function [value, state] = parseExpression(state)
            [value, state] = SequenceExpression.parseTerm(state);
            while SequenceExpression.peekIs(state, {'+', '-'})
                op = state.tokens(state.pos).text;
                state.pos = state.pos + 1;
                [rhs, state] = SequenceExpression.parseTerm(state);
                if op == '+'
                    value = value + rhs;
                else
                    value = value - rhs;
                end
            end
        end

        function [value, state] = parseTerm(state)
            [value, state] = SequenceExpression.parseFactor(state);
            while SequenceExpression.peekIs(state, {'*', '/'})
                op = state.tokens(state.pos).text;
                state.pos = state.pos + 1;
                [rhs, state] = SequenceExpression.parseFactor(state);
                if op == '*'
                    value = value * rhs;
                else
                    if rhs == 0
                        error('division by zero.');
                    end
                    value = value / rhs;
                end
            end
        end

        function [value, state] = parseFactor(state)
            [value, state] = SequenceExpression.parseUnary(state);
            if SequenceExpression.peekIs(state, {'^'})
                state.pos = state.pos + 1;
                [exponent, state] = SequenceExpression.parseFactor(state);  % right associative
                value = value ^ exponent;
            end
        end

        function [value, state] = parseUnary(state)
            if SequenceExpression.peekIs(state, {'-'})
                state.pos = state.pos + 1;
                [value, state] = SequenceExpression.parseUnary(state);
                value = -value;
                return
            end
            if SequenceExpression.peekIs(state, {'+'})
                state.pos = state.pos + 1;
                [value, state] = SequenceExpression.parseUnary(state);
                return
            end
            [value, state] = SequenceExpression.parsePrimary(state);
        end

        function [value, state] = parsePrimary(state)
            if state.pos > numel(state.tokens)
                error('the expression ends too early.');
            end

            token = state.tokens(state.pos);

            switch token.kind
                case 'number'
                    value = token.value;
                    state.pos = state.pos + 1;

                case 'name'
                    if ~isfield(state.variables, token.text)
                        error('"%s" is not a declared variable.', token.text);
                    end
                    value = state.variables.(token.text);
                    if ~isnumeric(value) || ~isscalar(value)
                        error('variable "%s" is not a single number.', token.text);
                    end
                    value = double(value);
                    state.pos = state.pos + 1;

                case 'op'
                    if token.text == '('
                        state.pos = state.pos + 1;
                        [value, state] = SequenceExpression.parseExpression(state);
                        if ~SequenceExpression.peekIs(state, {')'})
                            error('a "(" was never closed.');
                        end
                        state.pos = state.pos + 1;
                    else
                        error('"%s" cannot start a value.', token.text);
                    end

                otherwise
                    error('"%s" cannot start a value.', token.text);
            end
        end

        function tf = peekIs(state, texts)
            tf = false;
            if state.pos > numel(state.tokens); return; end
            token = state.tokens(state.pos);
            if ~strcmp(token.kind, 'op'); return; end
            tf = any(strcmp(token.text, texts));
        end
    end
end

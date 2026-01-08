
function [yprime,params,resnorm,residual,conf,delta]=lorentzian_fit(x,y,dhyp,Nhyp,Npeak,varargin)
%varargin is p0 or phyp, first parameter (p1) is the location of the middle
%peak, second (p2) is (width of hyperfine/2)^2.
%third parameter (p3) is the contrast*p2.
%p4,p5,p6,p7- same as p2,p3 but for the 3 different hyperfines. 
%the last parameter of varargin is an additional contrast parameter for all
%peaks.

% y = smooth(y,0.004,'loess')';

optargs = {[],[],'3c',optimset('TolFun',max(mean(y(:))*1e-6,1e-15),'TolX',max(mean(x(:))*1e-6,1e-15))};
numvarargs = length(varargin);
for ii = 1:numvarargs
    if isempty(varargin{ii})
        varargin{ii} = optargs{ii};
    end
end
optargs(1:numvarargs) = varargin;
[p0,print,nparams,options] = optargs{:};
% % function: p1./((p2-x).^2+p3), function max: p1/p3, function width 2sqrt(p3) 
% lp3 = 0.1e-6; % function width
% up3 = 1e-4; % function width
% lp2 = min(x); % function position
% up2 = max(x); % function position
% lp1 = -min(y)*up3; % function hight
% up1 = -min(y)*lp3; % function hight

% lb = [repmat([lp1,lp2,lp3],1,N),max(y)-0.5*max(y)];
% ub = [repmat([up1,up2,up3],1,N),max(y)+0.5*max(y)];
% lb = -1*inf(1,3*N+1);
% ub = inf(1,3*N+1);

% if isempty(p0);
%    p0 = [p1 p2 p3  p4 p5 p6 c];
% elseif numel(p0)~=7
%    error 'P0 must be empty or have four elements for NPARAMS = ''3c''';
%end
% if isempty(bounds)
% elseif ~all(size(bounds)==[2 10])
%    error 'BOUNDS must be empty or it must be a 2x4 matrix for NPARAMS = ''3c''';
% else
%   lb = bounds(1,:); ub = bounds(2,:);
% end

%if any(lb>=ub)
%   error 'Lower bounds must be less than upper bounds';
%end

funcString = ' @(p,x) ';
for i=1:3:3*Npeak
    if Nhyp == 2
        funcString = [funcString sprintf(' - 1./((-0.5*%d+p(%d)-x).^2+(0.5*p(%d))^2).*(((0.5*p(%d))^2)*p(%d)) - 1./((0.5*%d+p(%d)-x).^2+(0.5*p(%d))^2).*(((0.5*p(%d))^2)*p(%d))',...
            dhyp, i, i+1, i+1, i+2, dhyp, i, i+1, i+1, i+2)]; %#ok<AGROW>
    elseif Nhyp == 3
        funcString = [funcString sprintf(' - 1./((-%d+p(%d)-x).^2+(0.5*p(%d))^2).*(((0.5*p(%d))^2)*p(%d)) - 1./((p(%d)-x).^2+(0.5*p(%d))^2).*(((0.5*p(%d))^2)*p(%d)) - 1./((%d+p(%d)-x).^2+(0.5*p(%d))^2).*(((0.5*p(%d))^2)*p(%d))',...
            dhyp,i, i+1, i+1, i+2, i, i+1, i+1,i+2, dhyp, i, i+1, i+1, i+2)]; %#ok<AGROW>
    end
end
func = eval([funcString sprintf('- p(%d)', 3*Npeak+1)]);

% funcString = ' @(p,x)';
% for i=1:3:3*N
%     funcString = [funcString sprintf('p(%d)*exp(-((x-p(%d)).^2)/(2*p(%d)^2)) + ', i, i+1, i+2)]; %#ok<AGROW>
% end
% func = eval([funcString sprintf('p(%d)', 3*N+1)]);

% options = optimoptions('fmincon');
% options.TolCon=1e-7;
% options.TolFun=1e-7;
% options.TolProjCG=1e-3;
% options.TolProjCGAbs=1e-11;
% options.TolX=1e-11;
% options.MaxIter=10000;

% tic
%  [params,resnorm,residual,exitflag,output,lambda,jacobian] = lsqcurvefit(func,p0,x,y,lb,ub);
% toc
% conf = nlparci(params,residual,'jacobian',jacobian);

% %tic
options=statset('TolFun',1e-11,'TolX',1e-4,'MaxIter',200);
opts = statset('nlinfit');
opts.DerivStep =1e-15;
opts.RobustWgtFun = '';
opts.MaxIter=100000;
opts.TolFun=1e-17;
opts.TolX=1e-17;
opts.Display = 'final';

 [params,residual,jacobian,covariance,MSE,ErrorModelInfo]=nlinfit(x,y,func,p0,options);
% %toc
%  conf = nlparci(params,residual,'covar',covariance);
 conf = nlparci(params,residual,'jacobian',jacobian);
 resnorm=0;
%%%%% 

 yprime = func(params,x);
 
% % if strcmp(print,'print')
% figure;
% plot(x,yprime,'r')
% hold on
% plot(x,y)
% hold off
% % end

%save someName params

% computing minima of analytical function obtained above
funcString = ' @(params,x) ';
for i=1:3:3*Npeak
    if Nhyp == 2
        funcString = [funcString sprintf(' - 1./((-0.5*%d+params(%d)-x).^2+(0.5*params(%d))^2).*(((0.5*params(%d))^2)*params(%d)) - 1./((0.5*%d+params(%d)-x).^2+(0.5*params(%d))^2).*(((0.5*params(%d))^2)*params(%d))',...
            dhyp, i, i+1, i+1, i+2, dhyp, i, i+1, i+1, i+2)]; %#ok<AGROW>
    elseif Nhyp == 3
        funcString = [funcString sprintf(' - 1./((-%d+params(%d)-x).^2+(0.5*params(%d))^2).*(((0.5*params(%d))^2)*params(%d)) - 1./((params(%d)-x).^2+(0.5*params(%d))^2).*(((0.5*params(%d))^2)*params(%d)) - 1./((%d+params(%d)-x).^2+(0.5*params(%d))^2).*(((0.5*params(%d))^2)*params(%d))',...
            dhyp,i, i+1, i+1, i+2, i, i+1, i+1,i+2, dhyp, i, i+1, i+1, i+2)]; %#ok<AGROW>
    end
end
p1=params(1);p2=params(2);p3=params(3);p4=params(4);p5=params(5);p6=params(6);p7=params(7);
% func1 = eval([funcString sprintf('- params(%d)', 3*Npeak+1)]);
func2 = @(x)-1./((-0.5*2+p1-x).^2+(0.5*p2)^2).*(((0.5*p2)^2)*p3)-1./((0.5*2+p1-x).^2+(0.5*p2)^2).*(((0.5*p2)^2)*p3)-1./((-0.5*2+p4-x).^2+(0.5*p5)^2).*(((0.5*p5)^2)*p6)-1./((0.5*2+p4-x).^2+(0.5*p5)^2).*(((0.5*p5)^2)*p6)-p7;
[minval_L,minsite_L] = fminbnd(func2,params(1)-10, params(1)+10); 
[minval_R,minsite_R] = fminbnd(func2,params(4)-10, params(4)+10); 
delta=minval_R-minval_L;
end


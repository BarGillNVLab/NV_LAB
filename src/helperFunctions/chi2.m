function chi=chi2(x,y,err,ft)
y=reshape(y,[length(y) 1]);
x=reshape(x,[length(x) 1]);
err=reshape(err,[length(err) 1]);
x2=linspace(x(1),x(end),1000);
chi=sum(((y-ft(x))./err).^2);
end
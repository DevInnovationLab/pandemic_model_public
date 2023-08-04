function y = f0(i,alpha,mu,sigma,xi)
    % Density function of intensity conditional on arrival

    y = (1-alpha) .* sigma.^(1/xi) .* (sigma + xi.*(i - mu)).^(-1-(1./xi));
end
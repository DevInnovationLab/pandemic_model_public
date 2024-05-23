function y = f_cum0(i,alpha,mu,sigma,xi)
    % Cumulative distribution function of intensity conditional on arrival

    y = 1 - (1-alpha) .* (1 + (xi./sigma)*(i - mu)).^(-1./xi);
end
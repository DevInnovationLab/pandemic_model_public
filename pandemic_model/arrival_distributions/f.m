function y = f(i,alpha,mu,sigma,xi,w,ones,twos,threes,fours,fives)
    % Density function of intensity unconditional on arrival
    
    y = ones;
    y = y + twos * 2 .* f_cum0(i,alpha,mu,sigma,xi);
    y = y + threes * 3 .* f_cum0(i,alpha,mu,sigma,xi).^2;
    y = y + fours * 4 .* f_cum0(i,alpha,mu,sigma,xi).^3;
    y = y + fives * 5 .* f_cum0(i,alpha,mu,sigma,xi).^4;
    y = f0(i,alpha,mu,sigma,xi) .* y / w;
end

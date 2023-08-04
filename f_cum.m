function y = f_cum(i,alpha,mu,sigma,xi,w,ones,twos,threes,fours,fives)
    % Cumulative distribution function of intensity unconditional on arrival

    zeros = w - ones - twos - threes - fours - fives; 
    y = zeros;
    y = y + ones .* f_cum0(i,alpha,mu,sigma,xi);
    y = y + twos .* f_cum0(i,alpha,mu,sigma,xi).^2;
    y = y + threes .* f_cum0(i,alpha,mu,sigma,xi).^3;
    y = y + fours .* f_cum0(i,alpha,mu,sigma,xi).^4;
    y = y + fives .* f_cum0(i,alpha,mu,sigma,xi).^5;
    y = y / w;
end
function x = dediscretize(d, parameters, zero_bins, wrap)

if isempty(parameters)
    x = d;
    return
end

if nargin < 4
    wrap = false;
    if nargin < 3
        zero_bins = [];    
    end
end

x = zeros(size(d));
n = numel(d);

for i = 1:n
    % generate uniform in interval [a, b]
    if any(zero_bins == d(i))
        x(i) = 0;
    else
        dd = d(i);
        if wrap && dd == 1
            if rand < (parameters(end) - parameters(end - 1))/(parameters(end) - parameters(end - 1) + parameters(2) - parameters(1))                        
                dd = length(parameters) - 1;
            end
        end
        a = parameters(dd);
        b = parameters(dd + 1);
        x(i) = a + (b - a) * rand;        
    end
end    

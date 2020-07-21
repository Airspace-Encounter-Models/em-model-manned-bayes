% Copyright 2008 - 2020, MIT Lincoln Laboratory
% SPDX-License-Identifier: BSD-2-Clause
function x = dediscretize(d, parameters, zero_bins, wrap)
% DEDISCRETIZE  Uniformly samples a value within the parameters bin
% specified in d. Variables that fall within a zero_bin are set to 0.

if isempty(parameters)
    x = d;
    return
end

if nargin < 4
    wrap = 0;
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
        try
            b = parameters(dd + 1);
        catch
            pause;
        end
        x(i) = a + (b - a) * rand;        
    end
end    

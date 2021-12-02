function x = dediscretize(d, parameters, zero_bins, wrap)
    % Copyright 2008 - 2021, MIT Lincoln Laboratory
    % SPDX-License-Identifier: BSD-2-Clause
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

    for ii = 1:n
        % generate uniform in interval [a, b]
        if any(zero_bins == d(ii))
            x(ii) = 0;
        else
            dd = d(ii);
            if wrap && dd == 1
                if rand < (parameters(end) - parameters(end - 1)) / (parameters(end) - parameters(end - 1) + parameters(2) - parameters(1))
                    dd = length(parameters) - 1;
                end
            end
            a = parameters(dd);
            try
                b = parameters(dd + 1);
            catch
                pause;
            end
            x(ii) = a + (b - a) * rand;
        end
    end

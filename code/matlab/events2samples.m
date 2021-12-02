function d = events2samples(initial, events)
    % Copyright 2008 - 2021, MIT Lincoln Laboratory
    % SPDX-License-Identifier: BSD-2-Clause
    % D - an n x t_max matrix
    %
    % SEE ALSO events2controls

    % Preallocate
    n = numel(initial);
    d = zeros(n, sum(events(:, 1)));
    x = initial(:);

    % Iterate over events
    t = 0;
    for event = events'
        delta_t = event(1);
        if event(2) == 0
            t = t + 1;
            d(:, t:t + delta_t - 1) = x(:, ones(1, delta_t));
        else
            if delta_t > 0
                d(:, t + 1:t + delta_t) = x(:, ones(1, delta_t));
                t = t + delta_t;
            end
            x(event(2)) = event(3);
        end
    end

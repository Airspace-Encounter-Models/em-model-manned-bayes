function controls = events2controls(initial,events,mdl)
% Copyright 2008 - 2021, MIT Lincoln Laboratory
% SPDX-License-Identifier: BSD-2-Clause
%
% SEE ALSO events2samples

% Indices of dynamic variables
% As of July 2021, for the uncorrelated models this should be [5,6,7]
vars = mdl.temporal_map(:,1);

% Preallocate
controls = zeros(size(events,1), 1+numel(vars));
x = initial;

% Iterate over events
t = 0;
counter = 0;
for event = events'
    delta_t = event(1);
    if delta_t > 0
        counter = counter + 1;
        controls(counter,:) =  [t, x(vars)]; 
        t = t + delta_t;
    end
    if event(2) > 0
        x(event(2)) = event(3);
    end
end

% Remove unused rows
controls = controls(1:counter,:);

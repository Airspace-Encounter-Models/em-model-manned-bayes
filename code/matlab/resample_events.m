function events = resample_events(initial, events, rates)
% Copyright 2008 - 2021, MIT Lincoln Laboratory
% SPDX-License-Identifier: BSD-2-Clause
% RESAMPLE_EVENTS generates additional events within a sampled bin
% according to the desired resample rates. This mitigates the excessive
% variability in the vertical rates, turn rates, and acceleration that
% would occur if the values were sampled within each bin at each time step.
% Variables that do not change during the course of the trajectory have a
% resample rate of 0.

n = size(events,1);

newevents = [];

x = initial(:);

for i=1:n
    holdtime = events(i,1);
    if holdtime == 0
        newevents = [newevents; events(i,:)];
    else
        delta_t = 0;
        for j=1:holdtime
            changes = find(rand(size(rates)) < rates);
            delta_t = delta_t + 1;                
            if ~isempty(changes)
                newevents = [newevents; [[delta_t; zeros(numel(changes)-1,1)] changes(:) x(changes)]];
                delta_t = 0;
            end
        end
        newevents = [newevents; delta_t events(i,2) events(i,3)];
    end
    if events(i,2) > 0
        x(events(i,2)) = events(i,3);
    end
end
events = newevents;

function events = resample_events(initial, events, rates)

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

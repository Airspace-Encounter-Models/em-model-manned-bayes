function [initial, events] = dbn_hierarchical_sample(parms, dirichlet_initial, dirichlet_transition, sample_time, dediscretize_parameters, zero_bins, resample_rates, initial)
% Copyright 2008 - 2021, MIT Lincoln Laboratory
% SPDX-License-Identifier: BSD-2-Clause
% DBN_HIERARCHICAL_SAMPLE Calls dbn_sample() to generate samples from a
% dynamic Bayesian network. Variables are sampled discretely in bins and
% then dediscretized.
% See also dbn_sample, resample_events, dediscretize

if nargin < 8
    [initial, events] = dbn_sample(parms, dirichlet_initial, dirichlet_transition, sample_time);
else
    [initial, events] = dbn_sample(parms, dirichlet_initial, dirichlet_transition, sample_time, initial);
end    

if isempty(events)
    events = [sample_time 0 0];
else
    events = [events; sample_time - sum(events(:,1)) 0 0];
end

%disp('Within-bin resampling');
events = resample_events(initial, events, resample_rates);

%disp('Dediscretize')
for i = 1:numel(initial)
    if length(dediscretize_parameters{i}) == (size(parms.N_initial{i},1) - 2)
        
    else
        initial(i) = dediscretize(initial(i), dediscretize_parameters{i}, zero_bins{i});
    end
end

if ~isempty(events)
    for i = 1:(size(events,1)-1)
        events(i,3) = dediscretize(events(i,3), dediscretize_parameters{events(i,2)}, zero_bins{events(i,2)});
    end
end

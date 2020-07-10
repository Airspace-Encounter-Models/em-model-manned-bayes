function [initial, events] = dbn_sample(G_initial, G_transition, temporal_map, r, N_initial, N_transition, dirichlet_initial, dirichlet_transition, t_max, initial)
% INPUT:
% G_initial - initial distribution graph structure
% G_transition - continuous transition model graph structure
% reverse_map -
% r - a column vector specifying the number of bins for each variable
% N_initial - sufficient statistics for initial distribution
% N_transition - sufficient statistics for transition model
% dirichlet_initial - Dirichlet prior
% dirichlet_transition - Dirichlet prior
% t_max - the maximum amount of time to run the simulation
%
% OUTPUT:
% initial
% events - matrix of (t, variable_index, new_value) (NOTE: t is the time
% since the last event)

%% Create initial sample if it is not provided as input
if nargin < 10
    initial = bn_sample(G_initial, r, N_initial, dirichlet_initial, 1);
else
    initial = bn_sample(G_initial, r, N_initial, dirichlet_initial, 1, initial);
end

%%
events = [];
n_initial = length(G_initial);
dynamic_variables = temporal_map(:,2);
order = bn_sort(G_transition);

x = [initial zeros(1, numel(dynamic_variables))];

delta_t = 0;

%% Iterate
for t = 2:t_max
    delta_t = delta_t + 1;
    x_old = x;
    for i = order
        if any(i == dynamic_variables)
            % only dynamic variables change
            parents = G_transition(:,i);
            j = 1;
            if any(parents)
                j = asub2ind(r(parents), x(parents));
            end
            x(i) = select_random(N_transition{i}(:, j) + dirichlet_transition{i}(:, j));
        end
    end
    
    % map back
    x(temporal_map(:,1)) = x(temporal_map(:,2));
    
    if any(x(1:n_initial) ~= x_old(1:n_initial))
        % change (i.e. new event)
        for i = 1:n_initial
            if x(i) ~= x_old(i)
                events = [events; delta_t i x(i)];
                delta_t = 0;
            end
        end
    end
end

function [initial, events] = dbn_sample(parms, dirichlet_initial, dirichlet_transition, t_max, start)
    % Copyright 2008 - 2021, MIT Lincoln Laboratory
    % SPDX-License-Identifier: BSD-2-Clause
    % INPUT:
    % parms - struct created by em_read with the following fields:
    %   G_initial - initial distribution graph structure
    %   G_transition - continuous transition model graph structure
    %   temporal_map -
    %   r - a column vector specifying the number of bins for each variable
    %   N_initial - sufficient statistics for initial distribution
    %   N_transition - sufficient statistics for transition model
    % dirichlet_initial - Dirichlet prior
    % dirichlet_transition - Dirichlet prior
    % t_max - the maximum amount of time to run the simulation
    % start - cell array defining specific bins to sample from
    %
    % OUTPUT:
    % initial - output of bn_sample
    % events - matrix of (t, variable_index, new_value) (NOTE: t is the time
    % since the last event)
    %
    % SEE ALSO bn_sample em_read

    %% Parse parms struct
    G_initial = parms.G_initial;
    G_transition = parms.G_transition;
    temporal_map = parms.temporal_map;
    r_transition = parms.r_transition;
    n_initial = parms.n_initial;
    N_initial = parms.N_initial;
    N_transition = parms.N_transition;
    order_initial = parms.order_initial;
    order_transition = parms.order_transition;

    %% Create initial sample
    initial = bn_sample(G_initial, r_transition, N_initial, dirichlet_initial, 1, start, order_initial);

    %% Preallocate
    dynamic_variables = temporal_map(:, 2);
    x = [initial zeros(1, numel(dynamic_variables))];

    % events
    events = nan(n_initial * t_max, numel(dynamic_variables));
    counter = 0;

    % Time between different events
    delta_t = 0;

    % When setOrder = stable,
    % The values (or rows) in C return in the same order as they appear in A.
    [~, ia, ~] = intersect(order_transition, dynamic_variables, 'stable');
    if iscolumn(ia)
        ia = ia';
    end

    %% Calculate index for variables
    % We calculate index, j, upfront because asub2ind() can
    % introduce unwanted overhead
    j = nan(size(order_transition));
    % N_trans_dyn = cell(size(order_transition));
    % dirichlet_trans_dyn = cell(size(order_transition));

    s = cell(size(order_transition));
    sthres = zeros(t_max, numel(order_transition));

    for ii = order_transition
        if any(ii == dynamic_variables)
            % only dynamic variables change
            parents = G_transition(:, ii);
            if any(parents)
                rj = r_transition(parents);
                xj = x(parents);
                j(ii) = asub2ind(rj, xj);
            else
                j(ii) = 1;
            end

            % Parse N_transition and dirichlet_transition for each dyn variable
            N_trans_dyn = N_transition{ii}(:, j(ii));
            dirichlet_trans_dyn = dirichlet_transition{ii}(:, j(ii));

            % Combine transition and dirichlet for weights
            weights = N_trans_dyn + dirichlet_trans_dyn;

            % Calculate cumsum of weights
            s{ii} = cumsum(weights);

            % Calculate random threshold
            sthres(:, ii) = s{ii}(end) * rand(t_max, 1);
        end
    end

    %% Iterate
    for t = 2:t_max
        delta_t = delta_t + 1;
        x_old = x;

        % Iterate over dynamic variables to select random index
        for ii = ia
            x(ii) = find(s{ii} >= sthres(t, ii), 1, 'first');
            % x(i) = select_random(weights);
        end

        % map back
        x(temporal_map(:, 1)) = x(temporal_map(:, 2));

        if any(x(1:n_initial) ~= x_old(1:n_initial))
            % change (i.e. new event)
            for ii = 1:n_initial
                if x(ii) ~= x_old(ii)
                    counter = counter + 1;
                    events(counter, :) = [delta_t, ii, x(ii)];
                    % events = [events; delta_t, i, x(i)]; % Deprecated
                    delta_t = 0;
                end
            end
        end
    end

    % Remove unused prelloacate rows
    events = events(1:counter, :);

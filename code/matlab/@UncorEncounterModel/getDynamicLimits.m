function dynamiclimits = getDynamicLimits(self, initial, results, idx_G, idx_A, idx_L, idx_V, idx_DH, is_discretized)
    % Copyright 2008 - 2021, MIT Lincoln Laboratory
    % SPDX-License-Identifier: BSD-2-Clause
    %
    % Calculates speed and vertical rate limits based on encounter model distributions
    %
    % SEE ALSO UncorEnocunterModel/track CorTerminalModel/getDynamicLimits

    %%
    prct_low = 1;
    prct_high = 99;

    %% Do something if variables are in expected order
    if idx_G == 1 && idx_A == 2 && idx_L == 3 && idx_V == 4 && idx_DH == 6

        % Geographic domain
        if is_discretized(idx_G)
            dG = initial(idx_G);
        else
            dG = discretize_bayes(initial(idx_G), self.cutpoints_initial{idx_G});
        end

        % Airspace class
        if is_discretized(idx_A)
            dA = initial(idx_A);
        else
            dA = discretize_bayes(initial(idx_A), self.cutpoints_initial{idx_A});
        end

        % Altitude layer
        if is_discretized(idx_L)
            dL = initial(idx_L);
        else
            dL = discretize_bayes([min(results.up_ft) max(results.up_ft)], self.cutpoints_initial{idx_L});
            dL = min(dL):1:max(dL);
        end
        if ~isrow(dL)
            dL = dL';
        end

        % Velocity
        if is_discretized(idx_V)
            dV = initial(idx_V);
        else
            results_speed_kts = results.speed_ftps * 0.592484;
            dV = discretize_bayes([min(results_speed_kts) max(results_speed_kts)], self.cutpoints_initial{idx_V});
            dV = min(dV):1:max(dV);
        end
        if ~isrow(dV)
            dV = dV';
        end

        % Distribution given the first variable (G)
        v_Initial_G = self.N_initial{idx_V}(:, dG:self.r_initial(idx_G):end);
        dh_initial_G =  self.N_initial{idx_DH}(:, dG:self.r_initial(idx_G):end);

        % Distribution given the first (G) & second (A) variables
        v_Initial_G_A = v_Initial_G(:, dA:self.r_initial(idx_A):end);
        dh_initial_G_A = dh_initial_G(:, dA:self.r_initial(idx_A):end);

        % Velocity distribution first three variables: G, A, L
        % We can easily sum here because velocity is the 4th variable
        v_Initial_G_A_L = v_Initial_G_A(:, unique(dL));

        % Vertical rate distribution given G, A, L
        dh_initial_G_A_L = zeros(self.r_initial(idx_DH), 1);
        for di = unique(dL)
            dh_initial_G_A_L = dh_initial_G_A_L + dh_initial_G_A(:, di:self.r_initial(idx_L):end);
        end

        % Vertical rate distribution given G, A, L
        dh_initial_G_A_L_V = zeros(self.r_initial(idx_DH), 1);
        for di = unique(dV)
            dh_initial_G_A_L_V = dh_initial_G_A_L_V + dh_initial_G_A_L(:, di:self.r_initial(idx_V):end);
        end
        assert(size(dh_initial_G_A_L_V, 2) == self.r_initial(5));

        % Aggregate
        v_initial = sum(v_Initial_G_A_L, 2);
        dh_initial = sum(dh_initial_G_A_L_V, 2);
    else
        v_initial = sum(self.N_initial{idx_V}, 2);
        dh_initial = sum(self.N_initial{idx_DH}, 2);
    end

    %% Speed
    % Probability distribution for speed bins
    % Cumulative sum
    % Find bin indicies that satisfy 0.5th and 99.5th
    prob_V = 100 * sum(v_initial, 2) / sum(v_initial, 'all');
    cs_V = cumsum(prob_V);
    k_min_V = find(cs_V >= prct_low, 1, 'first');
    k_max_V = find(cs_V >= prct_high, 1, 'first');

    % Add one because there is one more defined edge than bins aka a bin has two edges
    min_speed_ft_s = self.boundaries{idx_V}(k_min_V + 1) * 1.68780972222222; % v: KTAS -> ft/s
    max_speed_ft_s = self.boundaries{idx_V}(k_max_V + 1) * 1.68780972222222; % v: KTAS -> ft/s

    % Ensure that rotorcrafts shouldn't fly faster than 180 knots (304 fps) and
    % that fixed-wing don't fly slower than 30 knots
    if self.isRotorcraft & max_speed_ft_s > 304
        max_speed_ft_s = 304;
    end
    if ~self.isRotorcraft & min_speed_ft_s < 30
        min_speed_ft_s = 30;
    end

    %% Vertical Rate
    % Probability distribution for speed bins
    % Cumulative sum
    % Find bin indicies that satisfy 0.5th and 99.5th
    prob_DH = 100 * sum(dh_initial, 2) / sum(dh_initial, 'all');
    cs_DH = cumsum(prob_DH);
    k_min_DH = find(cs_DH >= prct_low, 1, 'first');
    k_max_DH = find(cs_DH >= prct_high, 1, 'first');

    max_vertrate_ft_s = max(abs(self.boundaries{idx_DH}([k_min_DH k_max_DH] + 1) / 60));
    if isnan(max_vertrate_ft_s)
        max_vertrate_ft_s = 0;
    end

    %% Aggregate for output
    dynamiclimits = struct;
    dynamiclimits.minVel_ft_s = min_speed_ft_s;
    dynamiclimits.maxVel_ft_s = max_speed_ft_s;
    dynamiclimits.maxVertRate_ft_s = max_vertrate_ft_s;
end

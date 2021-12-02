function [out_results, gen_time_s] = track(self, nSamples, varargin)
    % Copyright 2008 - 2021, MIT Lincoln Laboratory
    % SPDX-License-Identifier: BSD-2-Clause
    %
    % Sample the terminal encounter geometry model
    % SEE ALSO: CorTerminalModel/sample CorTerminalModel/createEncounter

    %% Input handling
    p = inputParser;
    addRequired(p, 'nSamples', @isnumeric);
    addParameter(p, 'initialSeed', nan, @isnumeric);
    addParameter(p, 'firstID', 1, @isnumeric);
    addParameter(p, 'isPlot', false, @islogical);
    addParameter(p, 'minEncTime_s', 30, @isnumeric); % Minimum amount of time that ownship and intruder must overlap
    addParameter(p, 'thresDist_ft', 2.5 * 6076, @isnumeric); % Criteria if track is "close" to runway, aligns with thresDist_ft from classifyTakeoffLand()
    addParameter(p, 'thresAltLow_ft', 750, @isnumeric); % Criteria if track is low relative runway, aligns with thresAltLow_ft from classifyTakeoffLand()
    addParameter(p, 'thresVertRate_ft_s', 300 / 60, @isnumeric); % Criteria for vertical rate (in determining a climb/descend vs. level)
    addOptional(p, 'verboseLvl', 0, @isnumeric); % The greater the value, the less displayed to screen

    % Parse
    parse(p, nSamples, varargin{:});
    seed = p.Results.initialSeed;
    firstID = p.Results.firstID;
    minEncTime_s = p.Results.minEncTime_s;
    thresDist_ft = p.Results.thresDist_ft;
    thresAltLow_ft = p.Results.thresAltLow_ft;
    thresVertRate_ft_s = p.Results.thresVertRate_ft_s;
    verboseLvl = p.Results.verboseLvl;

    %% Inputs Hardcode
    % Maximum time for forward or backwards propagation relative to CPA
    % Total potential track duration is tmax_s * 2
    tmax_s = 120;

    %% Set random seed
    if ~isnan(seed) && ~isempty(seed)
        seed_old = rng;
        rng(seed, 'twister');
    end

    %% Preallocate output
    out_results = struct('sample', [], 'traj', []);
    gen_time_s = zeros(nSamples, 1);

    %% Iterate over desired number of encounters
    for ii = 1:nSamples
        % Start timer
        tic;

        % Preallocate
        is_good = false;
        counter = 0;
        id = ii + (firstID - 1);

        while ~is_good

            % Sample encounter geometry model
            [~, out_samples] = self.sample(1, 'seed', nan);
            sample_geo = out_samples{1};

            % Sample trajectory models and create an encounter
            [traj] = self.createEncounter(sample_geo, tmax_s);

            if isempty(traj(1).t_s) | isempty(traj(2).t_s)
                counter = counter + 1;
            end

            % Compute Acceleration
            a1_ft_s_s = computeAcceleration(traj(1).v_ft_s, 1:1:numel(traj(1).t_s));
            a2_ft_s_s = computeAcceleration(traj(2).v_ft_s, 1:1:numel(traj(2).t_s));

            % Compute greatest magnitude
            maxA1_ft_s_s = max(abs(a1_ft_s_s));
            maxA2_ft_s_s = max(abs(a2_ft_s_s));

            if any(maxA1_ft_s_s > self.dynLimits1.maxAccel_ft_s_s) | any(maxA2_ft_s_s > self.dynLimits2.maxAccel_ft_s_s)
                counter = counter + 1;
            end

            % Calculate hmd, vmd, and time when cpa occurs
            [hmd_ft, vmd_ft, tcpa_s, ~, ~] = self.getGeneratedMissDistance(traj);

            % Check that CPA occurs within pm 5 seconds of ownship initialization
            % The model assumes tca is at 0,
            % If the encounter is initialized too far away, it could skew the assumptions
            is_cpa_good = abs(tcpa_s) <= 10;

            % CPA is a common exclusionary filter - if not good immediately regenerate
            if is_cpa_good
                % Check if this is sufficient time overlap between ownship and intruder
                enc_time_s = length(intersect(traj(1).t_s, traj(2).t_s));
                is_longenough = enc_time_s >= minEncTime_s;

                % Calculate if tracks are close and low to runway
                [is_close1, is_low1] = self.CheckRunwayProximity(traj(1), thresDist_ft, thresAltLow_ft);
                [is_close2, is_low2] = self.CheckRunwayProximity(traj(2), thresDist_ft, thresAltLow_ft);

                % Ownship, must be close and low OR not close
                is_runway_prox1 = ((is_close1 & is_low1) | ~is_close1);

                % Intruder, must be close and low OR not close when landing / takeoff
                % Cannot be close and low while transit
                switch  sample_geo.int_intent
                    case 3 % transit
                        is_runway_prox2 = ~(is_close2 & is_low2);
                    otherwise % land, takeoff
                        is_runway_prox2 = ((is_close2 & is_low2) | ~is_close2);
                end

                % Aggregate runway logicals
                is_runway_good = is_runway_prox1 & is_runway_prox2;

                % Determine vertical rate intent for both tracks
                % Determine if an track is climbing, descending, or remaining level
                [is_climb, is_descend] = self.CheckIntentVertical(traj, thresVertRate_ft_s);

                % Check that encounter conditions satisfy intruder intent
                switch  sample_geo.int_intent
                    case 1 % land
                        is_int_intent_good = is_descend(2);
                    case 2 % takeoff
                        is_int_intent_good = isClimb(2);
                    otherwise % transit
                        is_int_intent_good = true;
                end

                % Check ownship is conducting straight-in landing or straight-out takeoff
                switch  sample_geo.own_intent
                    case 1 % land
                        percentHeadingGood = nnz(traj(1).heading_deg >= 90 - 30 & traj(1).heading_deg <= 90 + 30) / numel(traj(1).heading_deg);
                        is_own_intent_good = is_descend(1) && (percentHeadingGood >= .95);
                    case 2 % takeoff
                        percentHeadingGood = nnz(traj(1).heading_deg >= 270 - 30 & traj(1).heading_deg <= 270 + 30) / numel(traj(1).heading_deg);
                        is_own_intent_good = isClimb(1) && (percentHeadingGood >= .95);
                end

                % Check dynamics, if other criteria are good
                [is_dyn_good1] = self.CheckDynamicLimits(traj(1), self.dynLimits1);
                [is_dyn_good2] = self.CheckDynamicLimits(traj(2), self.dynLimits2);

                % Check all criteria
                is_good = is_cpa_good & is_longenough & is_runway_good & is_own_intent_good & is_int_intent_good & is_dyn_good1 & is_dyn_good2;
            end

            if ~is_good
                counter = counter + 1;
            end

        end % End while

        % Plot if desired
        if p.Results.isPlot
            f = self.plotGeneratedEncounter(traj, id);
            set(f, 'name', sprintf('A=%i, own_intent=%i, int_intent=%i', self.start{1}, self.start{2}, self.start{3}));
        end

        % Assign output
        % Format trajectory files
        [trajFrmt, tcpa_adjusted] = self.reformatTrajFiles(traj, tcpa_s);

        % Assign encounter struct
        out_results(ii).sample = sample_geo;
        out_results(ii).traj = trajFrmt;

        % Resolve indexing issues caused by tcpa at 0
        if tcpa_adjusted == 0
            tcpa_adjusted = 1;
        end

        % Add some additional metadata
        out_results(ii).sample.id = id;
        out_results(ii).sample.tcpa = tcpa_adjusted;
        out_results(ii).sample.hmd_ft = hmd_ft;
        out_results(ii).sample.vmd_ft = vmd_ft;
        out_results(ii).sample.nmac = abs(hmd_ft) < 500 & abs(vmd_ft) < 100;
        verticalRate_ftpm = abs(diff(trajFrmt(1).h)) * 60;
        out_results(ii).sample.own_vertRate_ftpm = verticalRate_ftpm(tcpa_adjusted);
        out_results(ii).sample.own_initVertRate_ftpm = verticalRate_ftpm(1);
        verticalRate_ftpm = abs(diff(trajFrmt(2).h)) * 60;
        out_results(ii).sample.int_vertRate_ftpm = verticalRate_ftpm(tcpa_adjusted);
        out_results(ii).sample.int_initVertRate_ftpm = verticalRate_ftpm(1);
        out_results(ii).sample.own_initSpeed_ftps = trajFrmt(1).v(1);
        out_results(ii).sample.int_initSpeed_ftps = trajFrmt(2).v(1);
        out_results(ii).sample.own_initAlt_ft = trajFrmt(1).h(1);
        out_results(ii).sample.int_initAlt_ft = trajFrmt(2).h(1);

        % Stop and assign timer
        gen_time_s(ii) = toc;
    end

    %% Change back to original seed
    if ~isnan(seed) && ~isempty(seed)
        rng(seed_old);
    end

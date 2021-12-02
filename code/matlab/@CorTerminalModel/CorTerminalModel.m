classdef CorTerminalModel < EncounterModel
    % Copyright 2008 - 2021, MIT Lincoln Laboratory
    % SPDX-License-Identifier: BSD-2-Clause

    properties (SetAccess = immutable, GetAccess = public)
        srcData(1, :) char
        parameters_directory(1, :) char
    end

    properties (SetAccess = protected, GetAccess = public)
        % ownship trajectory models (AC1)
        % Intent = Landing (1)
        mdlFwd1_1(1, 1) EncounterModel {mustBeNonempty}
        mdlBck1_1(1, 1) EncounterModel {mustBeNonempty}
        % Intent = Takeoff (2)
        mdlFwd1_2(1, 1) EncounterModel {mustBeNonempty}
        mdlBck1_2(1, 1) EncounterModel {mustBeNonempty}

        % intruder trajectory models (AC2)
        % Intent = Landing (1)
        mdlFwd2_1(1, 1) EncounterModel {mustBeNonempty}
        mdlBck2_1(1, 1) EncounterModel {mustBeNonempty}
        % Intent = Takeoff (2)
        mdlFwd2_2(1, 1) EncounterModel {mustBeNonempty}
        mdlBck2_2(1, 1) EncounterModel {mustBeNonempty}
        % Intent = Transit (3)
        mdlFwd2_3(1, 1) EncounterModel {mustBeNonempty}
        mdlBck2_3(1, 1) EncounterModel {mustBeNonempty}

        % Dynamic limits
        dynLimits1(1, 1) struct
        dynLimits2(1, 1) struct
    end

    properties (SetAccess = public, GetAccess = public)
        bounds_sample(:, 2) double {mustBeNumeric mustBeReal}
        acType1(1, :) char
        acType2(1, :) char
    end

    properties (Dependent = true)
        variables2controls
    end

    %% Constructor Function
    methods

        function self = CorTerminalModel(varargin)

            % Input parser
            p = inputParser;
            addParameter(p, 'srcData', 'terminalradar');

            % Parse
            parse(p, varargin{:});
            src_data = p.Results.srcData;

            % Set directory
            parameters_directory = [getenv('AEM_DIR_BAYES') filesep 'model' filesep 'correlated_terminal' filesep src_data];

            % Initialize modelNames
            % identifies the full file path for each of the model files that
            % comprise the termianl encounter model
            mdl_names = struct;
            names = {'encounter_model'; 'ownship_landing_model'; 'ownship_takeoff_model'; 'ownship_takeoff_model_reverse'; 'ownship_landing_model_reverse'; 'intruder_landing_model_reverse'; 'intruder_landing_model'; 'intruder_takeoff_model'; 'intruder_takeoff_model_reverse'; 'intruder_transit_model'; 'intruder_transit_model_reverse'};
            for ii = 1:1:numel(names)
                % Find
                listing = dir([parameters_directory filesep '*_' names{ii} '.txt']);

                % Parse
                fname = [listing.folder filesep listing.name];

                % Assign
                mdl_names.(names{ii}) = fname;
            end

            % Call superconstructor for encounter geometry model
            self@EncounterModel('parameters_filename', mdl_names.encounter_model);
            self.srcData = src_data;
            self.parameters_directory = parameters_directory;
            self.bounds_sample = [-inf(length(self.N_initial), 1), inf(length(self.N_initial), 1)]; % Default, no limits

            % Load all ownship trajectory models (AC1)
            % Intent = Landing (1)
            self.mdlFwd1_1 = EncounterModel('parameters_filename', mdl_names.ownship_landing_model);
            self.mdlBck1_1 = EncounterModel('parameters_filename', mdl_names.ownship_landing_model_reverse);
            % Intent = Takeoff (2)
            self.mdlFwd1_2 = EncounterModel('parameters_filename', mdl_names.ownship_takeoff_model);
            self.mdlBck1_2 = EncounterModel('parameters_filename', mdl_names.ownship_takeoff_model_reverse);

            % Load all intruder trajectory models (AC2)
            % Intent = Landing (1)
            self.mdlFwd2_1 = EncounterModel('parameters_filename', mdl_names.intruder_landing_model);
            self.mdlBck2_1 = EncounterModel('parameters_filename', mdl_names.intruder_landing_model_reverse);
            % Intent = Takeoff (2)
            self.mdlFwd2_2 = EncounterModel('parameters_filename', mdl_names.intruder_takeoff_model);
            self.mdlBck2_2 = EncounterModel('parameters_filename', mdl_names.intruder_landing_model_reverse);
            % Intent = Transit (3)
            self.mdlFwd2_3 = EncounterModel('parameters_filename', mdl_names.intruder_transit_model);
            self.mdlBck2_3 = EncounterModel('parameters_filename', mdl_names.intruder_landing_model_reverse);

            % Set auto update to true
            self.isAutoUpdate = true;

            % Assumed aircraft type and dynamic limits
            % When auto updating, setting these variables will also set
            % dynLimits1 and dynLimits2
            self.acType1 = 'GENERIC';
            self.acType2 = 'GENERIC';
        end

    end

    %% Static methods
    methods (Static)

        function [hmd_ft, vmd_ft, tcpa_s, tcpa_index_own, tcpa_index_int] = getGeneratedMissDistance(traj)
            % GETGENERATEDMISSDISTANCE  Finds horizontal and vertical miss distances (in
            % feet) and time of CPA for a pair of generated trajectories.

            [~, ia, ib] = intersect(traj(1).t_s, traj(2).t_s);
            dx_nm = traj(1).x_nm(ia) - traj(2).x_nm(ib);
            dy_nm = traj(1).y_nm(ia) - traj(2).y_nm(ib);
            dxy_ft = sqrt(dx_nm.^2 + dy_nm.^2) .* 6076.1154855643; % Convert from nautical miles to feet
            dz_ft = traj(2).z_ft(ib) - traj(1).z_ft(ia);

            [hmd_ft, idx] = min(dxy_ft);
            vmd_ft = dz_ft(idx);
            tcpa_s = traj(1).t_s(ia(idx));
            tcpa_index_own = ia(idx);
            tcpa_index_int = ib(idx);

        end

        function is_reject = CheckCumTurn(heading, cum_turnlimit)
            % The purpose of this function is to reject any trajectories where the
            % cumulative turn is > cumTurnLimit (nominally 180 deg). E.g., we don't
            % want trajectories where the ownship is turning around in circles.

            % Preallocate / initialize
            is_reject = false;

            heading = wrapTo180(heading);
            heading_diffs = round(diff(heading), 1);
            turn_start = find(heading_diffs(1:end - 1) == 0 & heading_diffs(2:end) ~= 0) + 1;
            turn_end = find(heading_diffs(1:end - 1) ~= 0 & heading_diffs(2:end) == 0);

            % The whole trajectory is a turn
            if isempty(turn_start)
                turn_start = 1;
            end

            if isempty(turn_end)
                turn_end = numel(heading_diffs);
            end

            if numel(turn_start) > numel(turn_end)
                turn_end(end + 1) = numel(heading_diffs);
            end

            % Loop through the turns and see if there are any that go more than the cumTurnLimit
            for i = 1:numel(turn_start)
                headings = wrapTo180(heading_diffs(turn_start(i):turn_end(i)));

                % Find the start of different signed headings
                startIdx = find([0; diff(sign(headings))] ~= 0);

                if isempty(startIdx)
                    is_reject = any(abs(cumsum(headings(1:end))) > cum_turnlimit);
                    if is_reject
                        return
                    end

                else
                    startIdx = unique([1; startIdx; numel(headings) + 1]);
                    for j = 1:numel(startIdx) - 1
                        is_reject = any(abs(cumsum(headings(startIdx(j):startIdx(j + 1) - 1))) > cum_turnlimit);
                        if is_reject
                            return
                        end
                    end
                end

            end
        end

        function [is_close, is_low] = CheckRunwayProximity(traj, thres_dist_ft, thres_altlow_ft)
            % Checks if trajectory struct is within thresDist_ft distance
            % and thresAltLow_ft relevative altitude of the origin (0,0)

            % Preallocate
            is_close = false;
            is_low = false;

            % Calculate distance from runway
            d_nm = hypot(traj.x_nm, traj.y_nm)';
            d_ft = d_nm * 1.68781;

            % Determine if track gets close to runway
            is_close = d_ft <= thres_dist_ft;

            % Determine if any close points satsify altitude criteria
            if any(is_close)
                is_low = traj.z_ft(is_close) <= thres_altlow_ft;
            end

            % Output booleans
            is_close = any(is_close);
            is_low = any(is_low);
        end

        function [is_climb, is_descend] = CheckIntentVertical(traj, thres_vertrate_ft_s)
            % Checks if trajectories have enough updates that have a
            % magnitude of thresVertRate_ft_s when climbing or descending

            % Determine number of trajectories
            n_traj = numel(traj);

            % Preallocate
            is_climb = false(n_traj, 1);
            is_descend = false(n_traj, 1);

            % Iterate over trajectories
            for ii = 1:1:n_traj
                % Parse
                time_s = (1:1:numel(traj(ii).t_s))';
                alt_ft = traj(ii).z_ft';
                trkDur_s = time_s(end);

                % Calculate vertical rate and threshold
                dh_ft_s = computeVerticalRate(alt_ft, time_s);
                vertThresTime_s = (max(alt_ft) - min(alt_ft)) / thres_vertrate_ft_s;
                perecentThres = min([0.2, vertThresTime_s / trkDur_s], [], 2);

                % Percentage of time track is climbing or descend
                percentClimb = nnz(dh_ft_s >= thres_vertrate_ft_s) / numel(dh_ft_s);
                percentDescend = nnz(dh_ft_s <= -1 * thres_vertrate_ft_s) / numel(dh_ft_s);

                % Determine if track is climbing, descending, or remaining level
                is_climb(ii) = percentClimb >= perecentThres;
                is_descend(ii) = percentDescend >= perecentThres;
            end
        end

        function [is_pass] = CheckDynamicLimits(traj, dynlims)
            % Checks if a trajectory satisfies the dynamic limits, defined
            % by dynLims, for altitude, speed, vertical rate, turn rate,
            % pitch, and cumulative turn
            %
            % SEE ALSO CorTerminalModel/getDynamicLimits

            % Preallocate
            is_pass = true;

            % Calculate time starting at zero, instead w.r.t to CPA
            time_s = (1:1:numel(traj.t_s))';

            % Reject if there are one or less points
            % When calculating dynamics, such as computeHeadingRate, we
            % need at least two points
            if numel(time_s) <= 1
                is_pass = false;
            else
                % Altitude
                isAltitude = traj.z_ft' > 0 & traj.z_ft' <= dynlims.maxAltitude_ft;

                % Speed
                isSpeed = traj.v_ft_s' >= dynlims.minVel_ft_s & traj.v_ft_s' <= dynlims.maxVel_ft_s;

                % Vertical rate (magnitude)
                dh_ft_s = computeVerticalRate(traj.z_ft', time_s);
                is_vertrate = abs(dh_ft_s) <= dynlims.maxVertRate_ft_s;

                % Turn Rate
                heading_rad = deg2rad(traj.heading_deg)';
                [dpsi_rad_s, deltaHeading, ~] = computeHeadingRate(heading_rad, time_s);
                is_turnrate = abs(dpsi_rad_s) <= dynlims.maxTurnRate_deg_s;

                % Pitch check - pitch = asin(vertical rate/speed)
                % Vertical rate and speed are both in feet per second
                is_pitch = abs(asind(abs(diff(traj.z_ft)) ./ traj.v_ft_s(2:end)))' <= dynlims.pitch_deg;
                is_pitch = [true; is_pitch];

                % Cumulative Turn
                % Note CheckCumTurn returns if rejected or not, it also returns a single
                % boolean...this needs to be changed in a future revision
                is_cumturn = ~CorTerminalModel.CheckCumTurn(traj.heading_deg', dynlims.maxCumTurn_deg);

                % Aggregate and output
                is_all = isAltitude & isSpeed & is_vertrate & is_turnrate & is_pitch;
                is_pass = all(is_all) & is_cumturn;
            end
        end

        function [out_traj, tcpa_adjusted] = reformatTrajFiles(in_traj, tcpa)
            % Save off the encounter data needed for save_waypoints

            tSubset = intersect(in_traj(1).t_s, in_traj(2).t_s);
            in_traj = CorTerminalModel.GetTrajectorySegment(in_traj, tSubset);
            out_traj = struct('t', [], 'y', [], 'x', [], 'h', []);

            tcpa_index = in_traj(1).t_s == tcpa;

            for ii = 1:2

                t_s = in_traj(ii).t_s - in_traj(ii).t_s(1);
                e_ft = in_traj(ii).x_nm .* 6076.1154855643;
                n_ft = in_traj(ii).y_nm .* 6076.1154855643;
                h_ft = in_traj(ii).z_ft;
                v_ft_s = in_traj(ii).v_ft_s;

                out_traj(ii).t = t_s;
                out_traj(ii).y = n_ft;
                out_traj(ii).x = e_ft;
                out_traj(ii).h = h_ft;
                out_traj(ii).v = v_ft_s;

            end

            tcpa_adjusted = out_traj(1).t(tcpa_index);
        end

        function traj = GetTrajectorySegment(traj, tSubset)
            % Segement trajectory based on a time subset, tSubset

            fields = fieldnames(traj);
            for jj = 1:length(traj)
                [~, idxs] = intersect(traj(jj).t_s, tSubset);
                for ii = 1:length(fields)
                    traj(jj).(fields{ii}) = traj(jj).(fields{ii})(idxs);
                end
            end
        end

        function T = aggregateTerminalMetadata(in_dir)
            % Aggregates metadata files within a directory

            % Input handling
            if nargin < 1
                in_dir = [getenv('AEM_DIR_BAYES') filesep 'output' filesep 'terminal'];
            end

            % Identify files in directory
            listing = dir([in_dir filesep '**' filesep '*.mat']);

            % Do something if there are files
            if isempty(listing)
                T = table;
                warning('Returning empty table, no .mat files found in %s', in_dir);
            else
                % Iterate over files
                for ii = 1:1:numel(listing)
                    % Load data
                    iiFile = [listing(ii).folder filesep listing(ii).name];
                    data = load(iiFile);

                    % Tranpose to column order
                    if isrow(data.id)
                        data = structfun(@transpose, data, 'UniformOutput', false);
                    end

                    % Parse
                    iiN = numel(data.id);
                    iiT = struct2table(data);
                    iiT.file = repmat(string(iiFile), iiN, 1);

                    % Concat
                    if ii == 1
                        T = iiT;
                    else
                        T = [T; iiT];
                    end
                end

                % Sort by id
                T = sortrows(T, 'id', 'ascend');
            end
        end

        function [f] = plotSamplesGeo(in_samples)
            % Plot positions of aircraft at sampled CPA
            %
            % SEE ALSO CorTerminalModel/sample

            % Inputs hardcode
            colors = [[0, 0.45, 0.74]; [0.85, 0.33, 0.1]];
            ownColor = colors(1, :);
            intColor = colors(2, :);

            % Parse
            x1_nm = cellfun(@(sampleGeo)([sampleGeo.own_distance * cosd(sampleGeo.own_bearing)]), in_samples, 'uni', true);
            x2_nm = cellfun(@(sampleGeo)([sampleGeo.int_distance * cosd(sampleGeo.int_bearing)]), in_samples, 'uni', true);

            y1_nm = cellfun(@(sampleGeo)([sampleGeo.own_distance * sind(sampleGeo.own_bearing)]), in_samples, 'uni', true);
            y2_nm = cellfun(@(sampleGeo)([sampleGeo.int_distance * sind(sampleGeo.int_bearing)]), in_samples, 'uni', true);

            % Crete figure
            f = figure('Name', 'Sampled CPA Positions', 'Units', 'inches', 'Position', [1, 1, 5, 5], 'Color', 'w');

            % Plot
            scatter(0, 0, 20, 'k', '+', 'DisplayName', 'Runway mean position', 'HandleVisibility', 'off');
            hold on;
            scatter(x1_nm, y1_nm, 10, ownColor, 'o', 'filled', 'DisplayName', 'CPA - Ownship');
            scatter(x2_nm, y2_nm, 10, intColor, 's', 'filled', 'DisplayName', 'CPA - Intruder');
            axis([-8 8 -8 8]);
            axis('square');
            grid on;
            hold off;
            xlabel('X (nautical miles)');
            ylabel('Y (nautical miles)');
            legend('Location', 'northeast', 'NumColumns', 1, 'FontSize', 10);
        end

        function [f] = plotGeneratedEncounter(traj, fig_num)
            % Plot generated terminal encounter
            %
            % SEE ALSO CorTerminalModel/track

            % Number of aircraft
            n = numel(traj);

            % Inputs hardcode
            colors = [[0, 0.45, 0.74]; [0.85, 0.33, 0.1]];
            ownColor = colors(1, :);
            intColor = colors(2, :);

            % Input handling
            if nargin < 2
                f = figure;
            else
                f = figure(fig_num);
            end
            set(f, 'Units', 'inches', 'Position', [2 2 5.4 7.5]);
            tiledlayout('flow', 'Padding', 'none', 'TileSpacing', 'normal');
            set(gcf, 'name', 'plotGeneratedEncounter');

            % Planview
            nexttile([2 2]);
            hold on;
            grid on;

            % Plot runway mean position
            rwy = scatter(0, 0, 'Marker', '+', 'LineWidth', 1.5, 'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'k', 'SizeData', 72, 'DisplayName', 'Runway mean position');

            % Initial and CPA positions
            for ii = 1:1:n
                switch ii
                    case 1
                        acname = 'Ownship';
                        marker_cpa = '*';
                        marker_start = 's';
                    case 2
                        acname = 'Intruder';
                        marker_cpa = 'h';
                        marker_start = 'd';
                    otherwise
                        marker_cpa = '*';
                        marker_start = 's';
                        acname = sprintf('Aircraft #%i', ii);
                end

                idx = find(traj(ii).t_s == 0);
                cpa = scatter(traj(ii).x_nm(idx), traj(ii).y_nm(idx), 'Marker', marker_cpa, 'LineWidth', 1, 'MarkerEdgeColor', colors(ii, :), 'MarkerFaceColor', colors(ii, :), 'SizeData', 36, 'DisplayName', ['CPA - ' acname]);
                start = scatter(traj(ii).x_nm(1), traj(ii).y_nm(1), 'Marker', marker_start, 'LineWidth', 1, 'MarkerEdgeColor', colors(ii, :), 'MarkerFaceColor', colors(ii, :), 'SizeData', 36, 'DisplayName', ['Initial - ' acname]);
            end

            % Peri and Intra Encounter Tracks
            [~, ia, ib] = intersect(traj(1).t_s, traj(2).t_s);

            plot(traj(1).x_nm, traj(1).y_nm, 'LineWidth', 1, 'LineStyle', ':', 'Color', ownColor, 'HandleVisibility', 'on', 'DisplayName', 'Peri-Track - Ownship');
            plot(traj(2).x_nm, traj(2).y_nm, 'LineWidth', 1, 'LineStyle', ':', 'Color', intColor, 'HandleVisibility', 'on', 'DisplayName', 'Peri-Track - Intruder');

            own = plot(traj(1).x_nm(ia), traj(1).y_nm(ia), 'LineWidth', 2, 'LineStyle', '-', 'Color', ownColor, 'DisplayName', 'Intra-Track - Ownship');
            int = plot(traj(2).x_nm(ib), traj(2).y_nm(ib), 'LineWidth', 2, 'LineStyle', '-', 'Color', intColor, 'DisplayName', 'Intra-Track - Intruder');

            xlabel('X (nautical miles)');
            ylabel('Y (nautical miles)');
            lg = legend('NumColumns', 2, 'FontSize', 10);

            dx = traj(1).x_nm(ia) - traj(2).x_nm(ib);
            dy = traj(1).y_nm(ia) - traj(2).y_nm(ib);
            dxy = sqrt(dx.^2 + dy.^2) .* 6076.1154855643;
            text(0.05, 0.1, sprintf('HMD = %d ft', round(min(dxy))), 'Units', 'normalized');
            axis([-8 8 -8 8]);
            axis('square');
            hold off;

            % Altitude
            nexttile;
            hold on;
            grid on;
            for ii = 1:1:n
                switch ii
                    case 1
                        acname = 'Ownship';
                        marker_cpa = '*';
                        marker_start = 's';
                        idxIntersect = ia;
                    case 2
                        acname = 'Intruder';
                        marker_cpa = 'h';
                        marker_start = 'd';
                        idxIntersect = ib;
                    otherwise
                        marker_cpa = '*';
                        marker_start = 's';
                        acname = sprintf('Aircraft #%i', ii);
                end

                % Tracks
                plot(traj(ii).t_s, traj(ii).z_ft, 'LineWidth', 1, 'LineStyle', ':', 'Color', colors(ii, :), 'DisplayName', ['Peri-Encounter Track - ' acname]);
                plot(traj(ii).t_s(idxIntersect), traj(ii).z_ft(idxIntersect), 'LineWidth', 2, 'LineStyle', '-', 'Color', colors(ii, :), 'DisplayName', ['Intra-Encounter Track - ' acname]);

                % CPA / Initial
                idx = find(traj(ii).t_s == 0);
                scatter(traj(ii).t_s(idx), traj(ii).z_ft(idx), 'Marker', marker_cpa, 'LineWidth', 1, 'MarkerEdgeColor', colors(ii, :), 'MarkerFaceColor', colors(ii, :), 'SizeData', 36, 'DisplayName', ['Initial - ' acname], 'HandleVisibility', 'off');
                scatter(traj(ii).t_s(1), traj(ii).z_ft(1), 'Marker', marker_start, 'LineWidth', 1, 'MarkerEdgeColor', colors(ii, :), 'MarkerFaceColor', colors(ii, :), 'SizeData', 36, 'DisplayName', ['Initial - ' acname], 'HandleVisibility', 'off');

            end
            hold off;
            xlabel('Time relative to CPA (s)');
            ylabel('Altitude (feet)');
            set(gca, 'YLim', [200 3000]);

            % Speed
            nexttile;
            hold on;
            grid on;
            for ii = 1:1:n
                switch ii
                    case 1
                        acname = 'Ownship';
                        marker_cpa = '*';
                        marker_start = 's';
                        idxIntersect = ia;
                    case 2
                        acname = 'Intruder';
                        marker_cpa = 'h';
                        marker_start = 'd';
                        idxIntersect = ib;
                    otherwise
                        marker_cpa = '*';
                        marker_start = 's';
                        acname = sprintf('Aircraft #%i', ii);
                end

                % Tracks
                plot(traj(ii).t_s, traj(ii).v_ft_s ./ 1.6878098571012, 'LineWidth', 1, 'LineStyle', ':', 'Color', colors(ii, :), 'DisplayName', ['Peri-Encounter Track - ' acname]);
                plot(traj(ii).t_s(idxIntersect), traj(ii).v_ft_s(idxIntersect) ./ 1.6878098571012, 'LineWidth', 2, 'LineStyle', '-', 'Color', colors(ii, :), 'DisplayName', ['Intra-Encounter Track - ' acname]);

                % CPA / Initial
                idx = find(traj(ii).t_s == 0);
                scatter(traj(ii).t_s(idx), traj(ii).v_ft_s(idx) ./ 1.6878098571012, 'Marker', marker_cpa, 'LineWidth', 1, 'MarkerEdgeColor', colors(ii, :), 'MarkerFaceColor', colors(ii, :), 'SizeData', 36, 'DisplayName', ['Initial - ' acname], 'HandleVisibility', 'off');
                scatter(traj(ii).t_s(1), traj(ii).v_ft_s(1) ./ 1.6878098571012, 'Marker', marker_start, 'LineWidth', 1, 'MarkerEdgeColor', colors(ii, :), 'MarkerFaceColor', colors(ii, :), 'SizeData', 36, 'DisplayName', ['Initial - ' acname], 'HandleVisibility', 'off');
            end
            hold off;
            xlabel('Time relative to CPA (s)');
            ylabel('Speed (knots)');
            set(gca, 'YLim', [75 500] / 1.6878098571012);

            lg.Layout.Tile = 'south'; % <-- place legend south of tiles
        end

    end

    %% Setters, Updaters, and Preallocate
    methods

        function self = set.acType1(self, newval)
            self.acType1 = newval;
            if self.isAutoUpdate
                self.dynLimits1 = self.getDynamicLimits(1);
            end
        end

        function self = set.acType2(self, newval)
            self.acType2 = newval;
            if self.isAutoUpdate
                self.dynLimits2 = self.getDynamicLimits(2);
            end
        end

    end

end % End class def

function [is_good, T_initial] = sample2track(parameters_filename, initial_filename, transition_filename, varargin)
    % Copyright 2008 - 2021, MIT Lincoln Laboratory
    % SPDX-License-Identifier: BSD-2-Clause
    % See also RUN_2_sample2track, em_read

    %% Input Parser
    p = inputParser;

    % Required
    addRequired(p, 'parameters_filename');
    addRequired(p, 'initial_filename');
    addRequired(p, 'transition_filename');

    % Optional
    addParameter(p, 'num_max_tracks', 10000, @isnumeric);

    % Optional - Output Directory
    addParameter(p, 'out_dir_parent', [getenv('AEM_DIR_BAYES') filesep 'output' filesep 'tracks']);

    % Optional - Initial
    % These need to align with parameters.labels_initial
    % Note that not all models may have these variables / labels
    % These labels can be calculated via:
    % matlab.lang.makeValidName(erase(parameters.labels_initial,{'"','\'}));
    addParameter(p, 'label_initial_geographic', 'G');
    addParameter(p, 'label_initial_airspace', 'A');
    addParameter(p, 'label_initial_altitude', 'L');
    addParameter(p, 'label_initial_speed', 'v');
    addParameter(p, 'label_initial_acceleration', 'dotV');
    addParameter(p, 'label_initial_vertrate', 'dotH');
    addParameter(p, 'label_initial_turnrate', 'dotPsi');

    % Optional - Transition
    % These need to align with parameters.labels_transition
    % Note that not all models may have these variables / labels
    % These labels can be calculated via:
    % matlab.lang.makeValidName(erase(parameters.labels_transition(parameters.temporal_map(:,2)),{'"','\'}))
    addParameter(p, 'label_transition_speed', 'dotV_t_1_'); % \dot v(t+1)
    addParameter(p, 'label_transition_altitude', 'dotH_t_1_'); % \dot h(t+1)
    addParameter(p, 'label_transition_heading', 'dotPsi_t_1_'); % \dot \psi(t+1)

    % Optional - Boundaries
    addParameter(p, 'isOverwriteZeroBoundaries', false, @islogical); % If true
    addParameter(p, 'idxZeroBoundaries', [1 2 3], @isnumeric); % Index of parameters.boundaries to force to be zero / empty

    % Optional - Rejection Sampling
    addParameter(p, 'min_altitude_ft', 0, @isnumeric);

    % Optional
    addParameter(p, 'rng_seed', 42, @isnumeric); % Random seed
    addParameter(p, 'isPlot', false, @islogical);

    % Parse
    parse(p, parameters_filename, initial_filename, transition_filename, varargin{:});

    %% Set random seed
    rng(p.Results.rng_seed, 'twister');

    %% Load files
    % Parameters
    parameters = em_read(parameters_filename, 'isOverwriteZeroBoundaries', p.Results.isOverwriteZeroBoundaries, 'idxZeroBoundaries', p.Results.idxZeroBoundaries);

    labels_init = matlab.lang.makeValidName(erase(parameters.labels_initial, {'"', '\'}))';
    labels_trans = matlab.lang.makeValidName(erase(parameters.labels_transition(parameters.temporal_map(:, 2)), {'"', '\'}))';

    % Initial
    T_initial = readtable(initial_filename, 'Delimiter', ' ', 'HeaderLines', 1, 'EndOfLine', '\n');
    T_initial.Properties.VariableNames = [{'id'}; labels_init];

    % Transition
    T_transition = readtable(transition_filename, 'Delimiter', ' ', 'HeaderLines', 1, 'EndOfLine', '\n');
    T_transition.Properties.VariableNames = [{'id'}; {'t'}; labels_trans];

    %% Filter to desired number tracks
    if size(T_initial, 1) > p.Results.num_max_tracks
        T_initial = T_initial(randperm(size(T_initial, 1), p.Results.num_max_tracks), :);
    end
    num_tracks = size(T_initial, 1);

    %% Find column indicies
    % Initial
    idx_initial_geographic = find(strcmp(T_initial.Properties.VariableNames, p.Results.label_initial_geographic));
    idx_initial_airspace = find(strcmp(T_initial.Properties.VariableNames, p.Results.label_initial_airspace));
    idx_initial_altitude = find(strcmp(T_initial.Properties.VariableNames, p.Results.label_initial_altitude));
    idx_initial_speed = find(strcmp(T_initial.Properties.VariableNames, p.Results.label_initial_speed));
    idx_initial_acceleration = find(strcmp(T_initial.Properties.VariableNames, p.Results.label_initial_acceleration));
    idx_initial_vertrate = find(strcmp(T_initial.Properties.VariableNames, p.Results.label_initial_vertrate));

    % Updates / transition
    idx_update_acc = find(strcmp(T_transition.Properties.VariableNames, p.Results.label_transition_speed));
    idx_update_vertrate = find(strcmp(T_transition.Properties.VariableNames, p.Results.label_transition_altitude));
    idx_update_turnrate = find(strcmp(T_transition.Properties.VariableNames, p.Results.label_transition_heading));

    % Bounds
    idx_bound_alt = find(strcmp(labels_init, p.Results.label_initial_altitude));
    idx_bound_speed = find(strcmp(labels_init, p.Results.label_initial_speed));

    %% For rejection sampling and load balancing
    % Altitude bound
    min_alt = parameters.boundaries{idx_bound_alt}(1);
    max_alt = parameters.boundaries{idx_bound_alt}(end);

    % Airspeed bound
    min_speed = parameters.boundaries{idx_bound_speed}(1);
    max_speed = parameters.boundaries{idx_bound_speed}(end);

    %% Parse parameters_filename
    pfn = strsplit(parameters_filename, filesep);

    % Check if model is one of the many unconventional models
    is_unconv = any(strcmp(strrep(pfn{end}, '.txt', ''), {'balloon_v1p2', 'blimp_v1', 'fai1_v1', 'fai5_v1', 'glider_v1p2', 'paraglider_v1p2', 'paramotor_v1', 'skydiving_v1', 'weatherballoon_v1'}));

    %% The position output is in feet, so we need to determine the appropriate unit conversions
    if ~isempty(strfind(pfn{end}, 'uncor_')) || is_unconv
        % Uncorrelated and unconventional models
        % % https://www.ll.mit.edu/sites/default/files/publication/doc/2018-12/Edwards_2009_ATC-348_WW-18098.pdf
        ur_speed = unitsratio('ft', 'nm') / 3600; % Knots to feet per second
        ur_vertrate = unitsratio('ft', 'ft') / 60; % Feet per minute to feet per second
        ur_heading = 1; % Degrees per second to degrees per second
    else
        warning('sample2track:model', '%s has not been tested with these function, assigning default units\n', pfn{end});
        ur_speed = unitsratio('ft', 'nm') / 3600; % Knots to feet per second
        ur_vertrate = unitsratio('ft', 'ft') / 60; % Feet per minute to feet per second
        ur_heading = 1; % Degrees per second to degrees per second
    end

    %% Apply unit conversions
    % Initial
    T_initial.(idx_initial_speed) = T_initial.(idx_initial_speed) * ur_speed;
    T_initial.(idx_initial_acceleration) = T_initial.(idx_initial_acceleration) * ur_speed;
    T_initial.(idx_initial_vertrate) = T_initial.(idx_initial_vertrate) * ur_vertrate;

    % Transition
    T_transition.(idx_update_vertrate) = T_transition.(idx_update_vertrate) * ur_vertrate;
    T_transition.(idx_update_acc) = T_transition.(idx_update_acc) * ur_speed;
    T_transition.(idx_update_turnrate) = T_transition.(idx_update_turnrate) * ur_heading;

    % Bounds
    min_speed = min_speed * ur_speed;
    max_speed = max_speed * ur_speed;

    %% Determine if variable exists
    is_geographic = ~isempty(idx_initial_geographic);
    is_airspace = ~isempty(idx_initial_airspace);

    %% Create parent output directories
    % Parent
    if exist(p.Results.out_dir_parent, 'dir') ~= 7
        mkdir(p.Results.out_dir_parent);
    end

    % Determine altitude range with a step size of 100
    if mod(min_alt, 1e2) ~= 0
        L = (floor(min_alt - 50):1e2:max_alt + 2e2)';
    else
        L = (min_alt:1e2:max_alt + 2e2)';
    end
    if L(1) < 0
        L(1) = 0;
    end

    % Subdirectories
    if ~isempty(strfind(pfn{end}, 'uncor_'))
        G = unique(T_initial.(idx_initial_geographic));
        A = unique(T_initial.(idx_initial_airspace));
        GAL = allcomb(G, A, L);
        for ii = 1:1:size(GAL, 1)
            ii_dir = [p.Results.out_dir_parent filesep sprintf('G%i', GAL(ii, 1)) filesep sprintf('A%i', GAL(ii, 2)) filesep sprintf('%ift', GAL(ii, 3))];
            if exist(ii_dir, 'dir') ~= 7
                mkdir(ii_dir);
            end
        end
        fprintf('Generated %i directories\n', size(GAL, 1));
    else
        for ii = 1:1:size(L, 1)
            mkdir([p.Results.out_dir_parent filesep sprintf('%ift', L(ii, 1))]);
        end
        fprintf('Generated %i directories\n', size(L, 1));
    end

    %% Iterate
    is_good = false(num_tracks, 1);
    for ii = 1:1:num_tracks
        % Set initial position
        time_s = 0;
        x_ft = 0;
        y_ft = 0;
        z_ft = T_initial{ii, idx_initial_altitude};
        speed_fps = T_initial{ii, idx_initial_speed};
        heading_deg = 0;

        % Filter transition for the ith id
        i_updates = T_transition(T_transition.id == T_initial.id(ii), :);
        max_time_s = size(i_updates, 1);

        % Iterate over time
        pInd = length(time_s);
        cInd = 1;
        while time_s(end) < max_time_s
            cInd = pInd + 1;
            time_s(cInd) = time_s(pInd) + 1;

            % Get updates
            update_vertrate = i_updates{pInd, idx_update_vertrate};
            update_acc = i_updates{pInd, idx_update_acc};
            update_turnrate = i_updates{pInd, idx_update_turnrate};

            % Apply Updates
            z_ft(cInd) = z_ft(pInd) + update_vertrate;
            speed_fps(cInd) = speed_fps(pInd) + update_acc;
            heading_deg(cInd) = heading_deg(pInd) + update_turnrate;

            x_ft(cInd) = x_ft(pInd) + speed_fps(pInd) * cosd(heading_deg(pInd));
            y_ft(cInd) = y_ft(pInd) + speed_fps(pInd) * sind(heading_deg(pInd));

            % Update counter
            pInd = cInd;
        end

        % Plot
        if p.Results.isPlot
            figure(ii);
            plot3(x_ft, y_ft, z_ft, '-*', 'Color', 'b', 'MarkerSize', 2);
            hold on;
            plot3(x_ft(1), y_ft(1), z_ft(1), 's', 'Color', 'r', 'MarkerSize', 10);
            hold off;
            legend('Track', 'Start');
            xlabel('ft');
            ylabel('ft');
            zlabel('ft');
            grid on;
        end

        % Determine if track hits the ground
        is_cfit = false;
        if any(z_ft < 0)
            is_cfit = true;
        end

        % Rejection Sampling - Speed
        is_reject_speed = any(speed_fps <= min_speed | speed_fps >= max_speed);

        % Determine if track is good
        is_good(ii) = ~is_cfit & ~is_reject_speed;

        % Only write to file if no CFIT
        % For load balancing, create subdirectories on model variables
        if is_good(ii)
            % Create filename
            out_name = sprintf('BAYES_t%i_id%i_alt%i_speed%i.csv', max_time_s, ii, round(z_ft(1)), round(speed_fps(1)));

            % Subdirectory for geographic variable, if it exists
            out_dir_child = [];
            if is_geographic
                out_dir_child = sprintf('G%i', T_initial.(idx_initial_geographic)(ii));
            end

            % Subdirectory for airspace class variable, if it exists
            if is_airspace
                out_dir_child = [out_dir_child filesep sprintf('A%i', T_initial.(idx_initial_airspace)(ii))];
            end

            % Subdirectory for initial altitude, always use
            out_dir_alt = L(discretize(z_ft(1), L));
            if isempty(out_dir_child)
                out_dir_child = sprintf('%ift', out_dir_alt);
            else
                out_dir_child = [out_dir_child filesep sprintf('%ift', out_dir_alt)];
            end

            % Create output directory
            out_dir = [p.Results.out_dir_parent filesep out_dir_child];

            % Write to file
            fileId = fopen([out_dir filesep out_name], 'w+', 'native', 'UTF-8');
            if fileId ~= -1
                fprintf(fileId, 'time_s,x_ft,y_ft,z_ft\n');
                fprintf(fileId, '%i,%0.0f,%0.0f,%0.0f\n', [time_s; x_ft; y_ft; z_ft]);
                fclose(fileId);
            else
                warning('sample2tracK:fileid', 'Cant open %s\n', [out_dir filesep out_name]);
            end
        else
            fprintf('Reject i=%i, CFIT = %i, v = [%0.3f, %0.3f]\n', ii, is_cfit, min(speed_fps), max(speed_fps));
        end
    end

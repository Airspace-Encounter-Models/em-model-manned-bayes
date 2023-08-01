function parms = em_read(parameters_filename, varargin)
    % Copyright 2008 - 2023, MIT Lincoln Laboratory
    % SPDX-License-Identifier: BSD-2-Clause
    % EM_READ  Reads an encounter model parameters file.
    % Reads an encounter model parameters file and returns a struct
    % containing the parsed data.
    %
    %   EM_READ(FILENAME) reads the parameters contained in the specified file
    %   and returns the parameters in a structure. Included in this structure
    %   are usually, but not guaranteed, the following fields:
    %        labels_initial
    %             n_initial
    %             G_initial
    %             r_initial
    %             N_initial
    %     labels_transition
    %          n_transition
    %          G_transition
    %          r_transition
    %          N_transition
    %            boundaries
    %        resample_rates
    %          temporal_map
    %             zero_bins

    %% Inputs
    % Create inputParser
    p = inputParser;

    % Required
    addRequired(p, 'parameters_filename'); % text specifying the name of the parameters file

    % Optional - Boundaries
    % `RUN_1_emsample.m` and `RUN_2_sample2track` assume that when the altitude layer is sampled,
    % an actual numeric value is returned (e.g. 650) instead of the sampled index (e.g. 2).
    % This is different than `em-pairing-uncor-importancesampling` which expects
    % the altitude sample to return an index instead of an altitude value.
    % This behavior is controlled by the boundaries parameter.
    % If in the parameter file, it is listed as `*`, it will return just the index (e.g. 2).
    % If there are values, such as `50 500 1200 3000 5000,` it will return a value (e.g. 650).
    addParameter(p, 'isOverwriteZeroBoundaries', false, @islogical); % If true, use idxZeroBoundaries to force the return of a bin index for variables = idxZeroBoundaries
    addParameter(p, 'idxZeroBoundaries', [1 2 3], @isnumeric); % Index of parameters.boundaries that will return a bin index (e.g. 1) when sampled instead of a numeric value (e.g. 50) (The default of [1 2 3] is for most uncor, 1=G,2=A,3=L)

    % Parse
    parse(p, parameters_filename, varargin{:});

    %% Read file
    fid = fopen(parameters_filename, 'r');
    textMaster = textscan(fid, '%s', 'EndOfLine', '\r\n', 'Whitespace', '\r\n', 'TextType', 'string');
    fclose(fid); % Close file
    textMaster = textMaster{1};

    % Parse field headers denoted by # symbol at start of row
    isField = cellfun(@any, strfind(textMaster, '#'));
    idxField = find(isField == true);
    fields = textMaster(isField);
    numFields = nnz(isField);
    numRows = size(textMaster, 1);

    % Check if labels_initial is the first field
    if ~strcmp(fields(1), "# labels_initial")
        warning('The first field is %s, was expecting # labels_initial. This function may fail', fields(1));
    end

    %% Iterate over fields
    for ii = 1:1:numFields
        row = idxField(ii) + 1;

        switch fields(ii)
            case '# labels_initial'
                parms.labels_initial = strtrim(strsplit(textMaster{row}, ','));
                parms.labels_initial = strrep(parms.labels_initial,'"','');
                parms.n_initial = numel(parms.labels_initial);
            case '# G_initial'
                parms.G_initial = logical(scanmatrix(textMaster, row, parms.n_initial));
                parms.order_initial = bn_sort(parms.G_initial);
            case '# r_initial'
                x = textscan(textMaster{row}, '%f', 'Delimiter', ' ');
                parms.r_initial = x{1};
            case '# N_initial'
                dims_initial = getdims(parms.G_initial, parms.r_initial, 1:parms.n_initial);
                x = textscan(textMaster{row}, '%f', 'Delimiter', ' ');
                parms.N_initial = array2cells(x{1}, dims_initial);
            case  '# labels_transition'
                parms.labels_transition = strtrim(strsplit(textMaster{row}, ','));
                parms.labels_transition = strrep(parms.labels_transition,'"','');
                parms.n_transition = numel(parms.labels_transition);
            case '# G_transition'
                parms.G_transition = logical(scanmatrix(textMaster, row, parms.n_transition));
                parms.order_transition = bn_sort(parms.G_transition);
            case '# r_transition'
                x = textscan(textMaster{row}, '%f', 'Delimiter', ' ');
                parms.r_transition = x{1};
            case '# N_transition'
                dims_transition = getdims(parms.G_transition, parms.r_transition, (parms.n_initial + 1):parms.n_transition);
                x = textscan(textMaster{row}, '%f', 'Delimiter', ' ');
                parms.N_transition = array2cells(x{1}, dims_transition);
            case '# boundaries'
                parms.boundaries = cell(1, parms.n_initial);
                for jj = 1:parms.n_initial
                    x = textscan(textMaster{row + jj - 1}, '%f', 'Delimiter', ' ');
                    parms.boundaries{jj} = x{1};
                end
            case '# resample_rates'
                if row <= numRows
                x = textscan(textMaster{row}, '%f', 'Delimiter', ' ');
                parms.resample_rates = x{1};
                else
                    warning('em_read:row:greaterthan:numRows',...
                        'No data on row %i, setting resample_rates to zeros', row);
                    parms.resample_rates = zeros(size(parms.labels_initial)); 
                end
            otherwise
                error('Unknown field: %s', fields(ii));
        end
    end

    %% Extract temporal map and zero bins
    if any(strcmp(fields, '# labels_transition'))
        parms.temporal_map = extract_temporal_map(parms.labels_transition);
    end

    %% Extract zero bins & calculate  bounds_initial and cutpoints_initial
    if any(strcmp(fields, '# boundaries'))
        parms.zero_bins = extract_zero_bins(parms.boundaries);

        % Overwrite boundaries if desired
        if p.Results.isOverwriteZeroBoundaries
            parms.boundaries(p.Results.idxZeroBoundaries) = repmat({double.empty(0, 1)}, size(p.Results.idxZeroBoundaries));
        end

        % Preallocate bounds_initial and cutpoints_initial
        bounds_initial = zeros(parms.n_initial, 2);
        cutpoints_initial = cell(1, parms.n_initial);

        % Iterate over initial network variables
        for ii = 1:1:parms.n_initial
            if isempty(parms.boundaries{ii})
                n = size(parms.N_initial{ii}, 1);
                cutpoints_initial{ii} = 2:1:n;
            else
                bounds_initial(ii, 1:2) = [min(parms.boundaries{ii}) max(parms.boundaries{ii})];
                cutpoints_initial{ii} = parms.boundaries{ii}(2:end - 1)';
            end
        end

        % Assign
        parms.bounds_initial = bounds_initial;
        parms.cutpoints_initial = cutpoints_initial;
    end

function zero_bins = extract_zero_bins(boundaries)
    zero_bins = cell(1, numel(boundaries));
    for ii = 1:numel(boundaries)
        b = boundaries{ii};
        z = [];
        if numel(b) > 2
            for j = 2:numel(b)
                if b(j - 1) < 0 && b(j) > 0
                    z = j - 1;
                end
            end
        end
        zero_bins{ii} = z;
    end

function temporal_map = extract_temporal_map(labels_transition)
    % Does not assume that order of variables at t match that at
    % t+1 or t-1 (order assumption not true for ECEM, but true for previous models)
    temporal_map = [];
    for ii = 1:numel(labels_transition)
        t = strfind(labels_transition{ii}, '(t)');
        if ~isempty(t)
            % Identify (t+1) or (t-1)
            idxFuture = find(contains(labels_transition, [labels_transition{ii}(1:t), 't+1)']));
            idxPast = find(contains(labels_transition, [labels_transition{ii}(1:t), 't-1)']));

            % Update
            if ~isempty(idxFuture)
                temporal_map = [temporal_map; ii, idxFuture];
            end
            if ~isempty(idxPast)
                temporal_map = [temporal_map; ii, idxPast];
            end
        end
    end

function x = scanmatrix(text_input, row_start, num_rows)
    % Parse matrix
    rowEnd = row_start + num_rows - 1;
    str = text_input(row_start:rowEnd);

    % Iterate over rows
    x = zeros(num_rows);
    for ii = 1:1:num_rows
        iiRow = textscan(str{ii}, '%f', 'Delimiter', ' ');
        x(ii, :) = iiRow{1};
    end

function c = array2cells(x, dims)
    c = cell(size(dims, 1), 1);
    index = 1;
    for ii = 1:numel(c)
        c{ii} = zeros(dims(ii, 1), dims(ii, 2));
        c{ii}(:) = x(index:(index - 1 + numel(c{ii})));
        index = index + numel(c{ii});
    end

function dims = getdims(G, r, vars)
    n = size(G, 1);
    dims = zeros(n, 2);
    for ii = vars
        q = prod(r(G(:, ii))); % q_i
        dims(ii, :) = [r(ii) q];
    end

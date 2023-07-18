classdef EncounterModel_CA < handle
    % Copyright 2008 - 2021, MIT Lincoln Laboratory
    % Copyright 2023 Carleton Univerity and National Research Council of
    % Canada
    % SPDX-License-Identifier: BSD-2-Clause
    %%
    properties (SetAccess = immutable, GetAccess = public)
        % Variable labels
        labels_initial(1, :) cell
        labels_transition(1, :) cell

        % maps variable at time t to same variable at time t+1 or t-1
        temporal_map(:, 2) double {mustBeInteger, mustBeNonnegative, mustBeFinite}

        % Graphical network
        G_initial(:, :) logical {mustBeNumericOrLogical, mustBeNonnegative, mustBeFinite}
        G_transition(:, :) logical {mustBeNumericOrLogical, mustBeNonnegative, mustBeFinite}
    end

    properties (SetAccess = public, GetAccess = public)
        % Model cutpoints for each bound, bounds, and zero bins
        bounds_initial(:, 2) double {mustBeReal, mustBeFinite}
        cutpoints_initial(1, :) cell
        boundaries(1, :) cell

        % Bin that discretized variable where we always sample zero
        % e.g. minor heading changes that are treated as no heading change
        % Count inbetween cutpoints_initial, so for dv if a fall falls
        % between -0.25 (cutpoints_initial index #2) and 0.25
        % (cutpoints_initial index #3), so assume the dv observation
        % will be placed in the third bin of [-0.25, 0.25]
        zero_bins(1, :) cell

        % The number of columns in the N matrix is the product of the
        % number of bins in each parents
        N_initial(:, 1) cell
        N_transition(:, 1) cell

        % Resample rates
        % This is just preallocate, we learn this when training the model
        % hierarchical_discretize() learns this
        % WE DO NOT MANUALLY SET THIS
        resample_rates(:, 1) double {mustBeReal, mustBeFinite}
        all_repeat(:, :) double {mustBeReal}
        all_change(:, :) double {mustBeReal}

        prior(1, :) {mustBeNonempty} = 0
        dirichlet_initial(:, 1) cell
        dirichlet_transition(:, 1) cell

        start(:, 1) cell

        isAutoUpdate(1, 1) logical {mustBeNumericOrLogical}
    end

    properties (Dependent = true, GetAccess = public)
        % These should match the number of elements in labels_initial and labels_transition
        n_initial(1, 1) double {mustBeInteger, mustBeNonnegative}
        n_transition(1, 1) double {mustBeInteger, mustBeNonnegative}

        order_initial(:, 1) double {mustBeReal}
        order_transition(:, 1) double {mustBeReal}

        r_initial(:, 1) double {mustBeReal}
        r_transition(:, 1) double {mustBeReal}

        bounds_transition(:, 2) double {mustBeReal, mustBeFinite}
        cutpoints_transition(1, :) cell

        cutpoints_fine(1, :) cell
        dediscretize_parameters(1, :) cell
    end

    %% Constructor Function and Helpers
    methods

        function self = EncounterModel_CA(varargin)
            % EncounterModel_CA Instantiates an object by reading in an encounter model parameters from mat file
            %
            % SEE ALSO em_read_CAN

            self.isAutoUpdate = false;

            % Input handling
            p = inputParser;
            addParameter(p, 'parameters_filename', '');
            addParameter(p, 'idxZeroBoundaries', []);
            addParameter(p, 'isOverwriteZeroBoundaries', false);
            addParameter(p, 'labels_initial', {});
            addParameter(p, 'labels_transition', {});
            addParameter(p, 'temporal_map', nan(0, 2));
            addParameter(p, 'G_initial', false(0, 0));
            addParameter(p, 'G_transition', false(0, 0));
            addParameter(p, 'cutpoints_initial', {});
            addParameter(p, 'bounds_initial', nan(0, 2));
            addParameter(p, 'zero_bins', {});
            parse(p, varargin{:});

            % Either load parameters from file or inputParser
            parameters_filename = p.Results.parameters_filename;
            if ~isempty(p.Results.parameters_filename)
                idxZeroBoundaries = p.Results.idxZeroBoundaries;
                isOverwriteZeroBoundaries = p.Results.isOverwriteZeroBoundaries;

                % Load parameters from Canadian data
                parms = em_read_CAN(parameters_filename);
           
            else
                % Set parms based on inputParser
                parms = p.Results;

                % Remove default fields
                for ii = p.UsingDefaults
                    parms = rmfield(parms, ii);
                end
            end

            % Get fieldnames for parms
            fieldsIn = fieldnames(parms);

            % Get meta.class and property list of object
            % https://www.mathworks.com/help/matlab/matlab_oop/getting-information-about-properties.html
            mc = ?EncounterModel_CA;
            propertyList = mc.PropertyList';

            % Iterate over fields and assign if there is a match
            if ~isempty(fieldsIn)
                for ii = propertyList
                    % Check if dependent (can't set these manuall)
                    if ~ii.Dependent
                        isMatch = strcmpi(fieldsIn, ii.Name);
                        if any(isMatch)
                            self.(ii.Name) = parms.(ii.Name);
                        end
                    end
                end
            end

            % Preallocate N_initial if empty
   
            if isempty(self.N_initial)
                self.preallocNInitial;
            end

            % Preallocate start cell array for sampling
            self.preallocStart;

            % create priors
            self.updateDirichletInitial;
            self.updateDirichletTransition;

            self.isAutoUpdate = true;

        end % End constructor

    end % End methods

    %% Abstract methods
    %     methods (Abstract = true, Access = public, Hidden = false)
    %         sample(self)
    %         %         track(self)
    %     end

    %% Setters, Updaters, and Preallocate
    methods

        function self = set.all_change(self, newValue)
            self.all_change = newValue;
            if self.isAutoUpdate
                self.updateResampleRates;
            end
        end

        function self = set.all_repeat(self, newValue)
            self.all_repeat = newValue;
            if self.isAutoUpdate
                self.updateResampleRates;
            end
        end

        function self = set.bounds_initial(self, newValue)
            self.bounds_initial = newValue;
            if self.isAutoUpdate
                self.updateBoundaries;
            end
        end

        function self = set.cutpoints_initial(self, newValue)
            self.cutpoints_initial = newValue;
            if self.isAutoUpdate
                self.updateBoundaries;
            end
        end

        function self = set.prior(self, newValue)
            oldValue = self.prior;
            self.prior = newValue;

            % Update dirichlet priors if value changed
            if ~strcmpi(oldValue, newValue) & self.isAutoUpdate
                self.updateDirichletInitial;
                self.updateDirichletTransition;
            end
        end

        function setParameters(self, N_initial, N_transition, all_repeat, all_change)
            self.N_initial = N_initial;
            self.N_transition = N_transition;
            self.all_repeat = all_repeat;
            self.all_change = all_change;
        end

    end

    %% Sealed Methods
    methods (Sealed = true)

        function outStruct = struct(self)
            % struct Casts EncounterModel_CA object to a struct

            % Preallocate
            outStruct = struct;

            % Get meta.class and property list of object
            % https://www.mathworks.com/help/matlab/matlab_oop/getting-information-about-properties.html
            mc = ?EncounterModel_CA;
            propertyList = mc.PropertyList';

            % Iterate over propertyList
            for ii = propertyList
                outStruct.(ii.Name) = self.(ii.Name);
            end

        end

        function updateBoundaries(self)
            boundaries = self.dediscretize_parameters;
        end

        function updateResampleRates(self)
            if isempty(self.all_change) | isempty(self.all_repeat)
                warning('Cannot update resample_rate because either all_change or all_repeat are empty');
            else
                newValue = self.all_change ./ (self.all_repeat + self.all_change);
                newValue(1:2) = 0;
                self.resample_rates = newValue;
            end
        end

        function updateDirichletInitial(self)
            newValue = bn_dirichlet_prior(self.N_initial, self.prior);
            self.dirichlet_initial = newValue;
        end

        function updateDirichletTransition(self)
            newValue = bn_dirichlet_prior(self.N_transition, self.prior);
            self.dirichlet_transition = newValue;
        end

        function preallocStart(self)
            self.start = cell(1, length(self.N_initial));
        end

        function preallocNInitial(self)
            % Preallocate Canadian Encounter Model Parameters
            % The number of columns in the N matrix is the product of the
            % number of bins in each parents

            % Parse
            n_initial = self.n_initial;
            G_initial = self.G_initial;
            r_initial = self.r_initial;

            % Preallocate
            N_initial = cell(n_initial, 1);

            % Iterate
            for i = 1:n_initial
                q = prod(r_initial(G_initial(:, i))); % q_i
                N_initial{i} = zeros(r_initial(i), q);
            end

            self.N_initial = N_initial;
        end

    end

    %% Getters
    methods

        function value = get.n_initial(self)
            value = numel(self.labels_initial);
        end

        function value = get.n_transition(self)
            value = numel(self.labels_transition);
        end

        function value = get.order_initial(self)
            value = bn_sort(self.G_initial);
        end

        function value = get.order_transition(self)
            value = bn_sort(self.G_transition);
        end

        function value = get.r_initial(self)
            value = zeros(self.n_initial, 1);
            for i = 1:self.n_initial
                value(i) = length(self.cutpoints_initial{i}) + 1;
            end
        end

        function value = get.r_transition(self)
            value = zeros(length(self.cutpoints_transition), 1);
            for i = 1:self.n_transition
                value(i) = length(self.cutpoints_transition{i}) + 1;
            end
        end

        function value = get.cutpoints_transition(self)
            is_dot = contains(self.labels_initial,"\dot");
            value = [self.cutpoints_initial, self.cutpoints_initial(is_dot)];
        end

        function value = get.bounds_transition(self)
            is_dot = contains(self.labels_initial,"\dot");
            value = [self.bounds_initial; self.bounds_initial(is_dot, :)]; % repeat bounds for last 3 vars in initial
        end

        function value = get.dediscretize_parameters(self)
            value = cell(1, self.n_initial);
            for i = 1:self.n_initial
                if self.bounds_initial(i, 1) == self.bounds_initial(i, 2)
                    value{i} = [];
                else
                    value{i} = [self.bounds_initial(i, 1) self.cutpoints_initial{i} self.bounds_initial(i, 2)];
                end
            end
        end

        function value = get.cutpoints_fine(self)
            value = cell(1, self.n_initial);
            for i = 1:self.n_initial
                if self.bounds_initial(i, 1) == self.bounds_initial(i, 2)
                    value{i} = [];
                else
                    value{i} = hierarchical_cutpoints(self.cutpoints_initial{i}, self.bounds_initial(i, :), 3);
                end
            end
        end

    end
end % End class def

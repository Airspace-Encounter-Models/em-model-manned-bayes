classdef EncounterModel < handle
    % Copyright 2008 - 2021, MIT Lincoln Laboratory
    % SPDX-License-Identifier: BSD-2-Clause
    %%
    properties (SetAccess=immutable, GetAccess=public)
        % Variable labels
        labels_initial(1,:) cell {};
        labels_transition(1,:) cell {};
        
        % maps variable at time t to same variable at time t+1 or t-1
        temporal_map(:,2) double {mustBeInteger, mustBeNonnegative, mustBeFinite};
        
        % Graphical network
        G_initial(:,:) logical {mustBeNumericOrLogical, mustBeNonnegative, mustBeFinite};
        G_transition(:,:) logical {mustBeNumericOrLogical, mustBeNonnegative, mustBeFinite};
    end
    
    properties (SetAccess=public, GetAccess=public)
        % Model cutpoints for each bound, bounds, and zero bins
        bounds_initial(:,2) double {mustBeReal, mustBeFinite};
        cutpoints_initial(1,:) cell {};
        boundaries(1,:) cell {};
        
        % Bin that discretized variable where we always sample zero
        % e.g. minor heading changes that are treated as no heading change
        % Count inbetween cutpoints_initial, so for dv if a fall falls
        % between -0.25 (cutpoints_initial index #2) and 0.25
        % (cutpoints_initial index #3), so assume the dv observation
        % will be placed in the third bin of [-0.25, 0.25]
        zero_bins(1,:) cell {};
        
        % The number of columns in the N matrix is the product of the
        % number of bins in each parents
        N_initial(:,1) cell {};
        N_transition(:,1) cell {};
        
        % Resample rates
        % This is just preallocate, we learn this when training the model
        % hierarchical_discretize() learns this
        % WE DO NOT MANUALLY SET THIS
        resample_rates(:,1) double {mustBeReal, mustBeFinite};
        all_repeat(:,:) double {mustBeReal};
        all_change(:,:) double {mustBeReal};
        
        prior(1,:) {mustBeNonempty} = 0;
        dirichlet_initial(:,1) cell {};
        dirichlet_transition(:,1) cell {};
        
        start(:,1) cell {};
        
        isAutoUpdate(1,1) logical {mustBeNumericOrLogical}
    end
    
    properties (Dependent=true, GetAccess=public)
        % These should match the number of elements in labels_initial and labels_transition
        n_initial(1,1) double {mustBeInteger, mustBeNonnegative};
        n_transition(1,1) double {mustBeInteger, mustBeNonnegative};
        
        order_initial(:,1) double {mustBeReal};
        order_transition(:,1) double {mustBeReal};
        
        r_initial(:,1) double {mustBeReal};
        r_transition(:,1) double {mustBeReal};
        
        bounds_transition(:,2) double {mustBeReal, mustBeFinite};
        cutpoints_transition(1,:) cell {};;
        
        cutpoints_fine(1,:) cell {};
        dediscretize_parameters(1,:) cell {};
    end
    
    %% Constructor Function and Helpers
    methods
        function obj = EncounterModel(varargin)
            % Instantiates an object by reading in an encounter model
            % parameters from an ASCII file
            %
            % SEE ALSO em_read
            
            obj.isAutoUpdate = false;
            
            % Input handling
            p = inputParser;
            addParameter(p,'parameters_filename','');
            addParameter(p,'idxZeroBoundaries',[]);
            addParameter(p,'isOverwriteZeroBoundaries',false);
            addParameter(p,'labels_initial',{});
            addParameter(p,'labels_transition',{});
            addParameter(p,'temporal_map',nan(0,2));
            addParameter(p,'G_initial',false(0,0));
            addParameter(p,'G_transition',false(0,0));
            addParameter(p,'cutpoints_initial',{});
            addParameter(p,'bounds_initial',nan(0,2));
            addParameter(p,'zero_bins',{});
            parse(p,varargin{:});
            
            % Either load parameters from file or inputParser
            parameters_filename = p.Results.parameters_filename;
            if ~isempty(p.Results.parameters_filename)
                idxZeroBoundaries = p.Results.idxZeroBoundaries;
                isOverwriteZeroBoundaries = p.Results.isOverwriteZeroBoundaries;
                
                % Load parameters from ASCII file
                parms = em_read(parameters_filename,'idxZeroBoundaries',idxZeroBoundaries,'isOverwriteZeroBoundaries',isOverwriteZeroBoundaries);
                
            else
                % Set parms based on inputParser
                parms = p.Results;
                
                % Remove default fields
                for ii=p.UsingDefaults
                    parms = rmfield(parms,ii);
                end
            end
            
            % Get fieldnames for parms
            fieldsIn = fieldnames(parms);
            
            % Get meta.class and property list of object
            % https://www.mathworks.com/help/matlab/matlab_oop/getting-information-about-properties.html
            mc =?EncounterModel;
            propertyList = mc.PropertyList';
            
            % Iterate over fields and assign if there is a match
            if ~isempty(fieldsIn)
                for ii=propertyList
                    % Check if dependent (can't set these manuall)
                    if ~ii.Dependent
                        isMatch = strcmpi(fieldsIn,ii.Name);
                        if any(isMatch)
                            obj.(ii.Name) = parms.(ii.Name);
                        end
                    end
                end
            end
            
            % Preallocate N_initial if empty
            % If reading in from ASCII file, this should not be empty but
            % if training or updating a model, this may need to be preallocated
            if isempty(obj.N_initial)
                obj.preallocNInitial;
            end
            
            % Preallocate start cell array for sampling
            obj.preallocStart;
            
            % create priors
            obj.updateDirichletInitial;
            obj.updateDirichletTransition;
            
            obj.isAutoUpdate = true;
            
        end % End constructor
    end % End methods
    
    %% Abstract methods
    %     methods (Abstract = true, Access = public, Hidden = false)
    %         sample(obj)
    %         %         track(obj)
    %     end
    
    %% Setters, Updaters, and Preallocate
    methods
        function obj = set.all_change(obj,newValue)
            obj.all_change = newValue;
            if obj.isAutoUpdate
                obj.updateResampleRates;
            end
        end
        
        function obj = set.all_repeat(obj,newValue)
            obj.all_repeat = newValue;
            if obj.isAutoUpdate
                obj.updateResampleRates;
            end
        end
        
        function obj = set.bounds_initial(obj,newValue)
            obj.bounds_initial = newValue;
            if obj.isAutoUpdate
                obj.updateBoundaries;
            end
        end
        
        function obj = set.cutpoints_initial(obj,newValue)
            obj.cutpoints_initial = newValue;
            if obj.isAutoUpdate
                obj.updateBoundaries;
            end
        end
        
        function obj = set.prior(obj, newValue)
            oldValue = obj.prior;
            obj.prior = newValue;
            
            % Update dirichlet priors if value changed
            if ~strcmpi(oldValue,newValue) & obj.isAutoUpdate
                obj.updateDirichletInitial;
                obj.updateDirichletTransition;
            end
        end
        
        function setParameters(obj, N_initial, N_transition, all_repeat, all_change )
            obj.N_initial = N_initial;
            obj.N_transition = N_transition;
            obj.all_repeat = all_repeat;
            obj.all_change = all_change;
        end
    end
    
    %% Sealed Methods
    methods(Sealed = true)
        
        function outStruct = struct(obj)
            % Preallocate
            outStruct = struct;
            
            % Get meta.class and property list of object
            % https://www.mathworks.com/help/matlab/matlab_oop/getting-information-about-properties.html
            mc =?EncounterModel;
            propertyList = mc.PropertyList';
            
            % Iterate over propertyList
            for ii=propertyList
                outStruct.(ii.Name) = obj.(ii.Name);
            end
            
        end
        
        function updateBoundaries(obj)
            boundaries = obj.dediscretize_parameters;
        end
        
        function updateResampleRates(obj)
            if isempty(obj.all_change) | isempty(obj.all_repeat)
                warning('Cannot update resample_rate because either all_change or all_repeat are empty');
            else
                newValue = obj.all_change ./ (obj.all_repeat + obj.all_change);
                newValue(1:2) = 0;
                obj.resample_rates = newValue;
            end
        end
        
        function updateDirichletInitial(obj)
            newValue = bn_dirichlet_prior(obj.N_initial,obj.prior);
            obj.dirichlet_initial = newValue;
        end
        
        function updateDirichletTransition(obj)
            newValue = bn_dirichlet_prior(obj.N_transition,obj.prior);
            obj.dirichlet_transition = newValue;
        end
        
        function preallocStart(obj)
            obj.start = cell(1,length(obj.N_initial));
        end
        
        function preallocNInitial(obj)
            % Preallocate Encounter Model Parameters
            % The number of columns in the N matrix is the product of the
            % number of bins in each parents
            
            % Parse
            n_initial = obj.n_initial;
            G_initial = obj.G_initial;
            r_initial = obj.r_initial;
            
            % Preallocate
            N_initial = cell(n_initial, 1);
            
            % Iterate
            for i = 1:n_initial
                q = prod(r_initial(G_initial(:,i))); % q_i
                N_initial{i} = zeros(r_initial(i), q);
            end
            
            obj.N_initial = N_initial;
        end
    end
    
    %% Getters
    methods
        function value = get.n_initial(obj)
            value = numel(obj.labels_initial);
        end
        
        function value = get.n_transition(obj)
            value = numel(obj.labels_transition);
        end
        
        function value = get.order_initial(obj)
            value = bn_sort(obj.G_initial);
        end
        
        function value = get.order_transition(obj)
            value = bn_sort(obj.G_transition);
        end
        
        function value = get.r_initial(obj)
            value = zeros(obj.n_initial, 1);
            for i = 1:obj.n_initial
                value(i) = length(obj.cutpoints_initial{i}) + 1;
            end
        end
        
        function value = get.r_transition(obj)
            value = zeros(length(obj.cutpoints_transition), 1);
            for i = 1:obj.n_transition
                value(i) = length(obj.cutpoints_transition{i}) + 1;
            end
        end
        
        function value = get.cutpoints_transition(obj)
            value = [obj.cutpoints_initial, obj.cutpoints_initial(end-2:end)];
        end
        
        function value = get.bounds_transition(obj)
            value = [obj.bounds_initial; obj.bounds_initial(end-2:end,:)]; %repeat bounds for last 3 vars in initial
        end
        
        function value = get.dediscretize_parameters(obj)
            value = cell(1,obj.n_initial);
            for i = 1:obj.n_initial
                if obj.bounds_initial(i,1) == obj.bounds_initial(i,2)
                    value{i} = [];
                else
                    value{i} = [obj.bounds_initial(i,1) obj.cutpoints_initial{i} obj.bounds_initial(i,2)];
                end
            end
        end
        
        function value = get.cutpoints_fine(obj)
            value = cell(1,obj.n_initial);
            for i = 1:obj.n_initial
                if obj.bounds_initial(i,1) == obj.bounds_initial(i,2)
                    value{i} = [];
                else
                    value{i} = hierarchical_cutpoints(obj.cutpoints_initial{i}, obj.bounds_initial(i,:), 3);
                end
            end
        end
    end
end % End class def

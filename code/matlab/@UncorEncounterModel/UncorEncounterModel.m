classdef UncorEncounterModel < EncounterModel
    % Copyright 2008 - 2021, MIT Lincoln Laboratory
    % SPDX-License-Identifier: BSD-2-Clause
    
    properties (SetAccess=public, GetAccess=public)
        isRotorcraft(:,:) logical {mustBeNumericOrLogical, mustBeNonnegative, mustBeFinite};
    end
    
    properties (Dependent=true)
        variables2controls;
    end
    
    
    %% Constructor Function
    methods
        function obj = UncorEncounterModel(varargin)
            
            % Input parser
            p = inputParser;
            addParameter(p,'input_type','file');
            addParameter(p,'parameters_filename',[getenv('AEM_DIR_BAYES') filesep 'model' filesep 'uncor_1200only_fwse_v1p2.txt']);
            addParameter(p,'idxZeroBoundaries',[1 2 3]);
            addParameter(p,'isOverwriteZeroBoundaries',false);
            
            % Parse
            parse(p,varargin{:});
            
            % If input_type is '', then this constructor will do nothing
            % We have to do this because in MATLAB, calls to superclass
            % constructors must be unconditional
            % https://www.mathworks.com/help/matlab/matlab_oop/class-constructor-methods.html
            if ~strcmpi(p.Results.input_type,'file')
                parameters_filename = '';
            else
                parameters_filename = p.Results.parameters_filename;
            end
            
            %
            switch p.Results.input_type
                case 'traditional-opensky'
                    labels_initial = {'G' 'A' 'L' 'v' '\dot v' '\dot h' '\dot \psi'};
                    labels_transition = {'G' 'A' 'L' 'v' '\dot v(t)' '\dot h(t)' '\dot \psi(t)' ...
                        '\dot v(t+1)' '\dot h(t+1)' '\dot \psi(t+1)'};
                    
                    temporal_map = [5 8; 6 9; 7 10];
                    
                    % Full connected matrix, so we don't manually encode
                    % connections, so we can use triangle
                    G_initial = logical(triu(ones(n_initial)) - eye(n_initial));
                    
                    % Parent = column, child = row
                    G_transition = false(n_transition);
                    % No transitions with G as parent
                    G_transition(2,9) = 1; % A -> \dot h(t+1)
                    G_transition(3,8:10) = 1; %L -> \dot v(t+1), L -> \dot h(t+1), L -> \dot psi(t+1)
                    G_transition(4,[8 10]) = 1; %v -> \dot v(t+1), v -> \dot psi(t+1)
                    G_transition(5,8:10) = 1; %\dot v(t) -> \dot v(t+1), \dot v(t) -> \dot h(t+1), \dot v(t) -> \dot psi(t+1)
                    G_transition(6,8:9) = 1; %\dot h(t) -> \dot v(t+1), \dot h(t) -> \dot h(t+1)
                    G_transition(7,8:10) = 1; %\dot psi(t) -> \dot v(t+1), \dot psi(t) -> \dot h(t+1), \dot psi(t) -> \dot psi(t+1)
                    G_transition = G_transition;
                    % No transitions with \dot v(t+1), \dot h(t+1), \dot psi(t+1) as parent
                    
                    bounds_initial = [0 0; 0 0;50 5000; 0 300; -2 2; -2000 2000; -8 8];
                    cutpoints_initial = {
                        [2 3 4 5], ... % G
                        [2 3 4], ... % A
                        [500 1200 3000], ... % L
                        [30 60 90 120 140 165 250], ... % v
                        [-1 -0.25 0.25 1], ... % dv
                        [-1250 -750 -250 250 750 1250], ... % dh
                        [-6 -4.5 -1.5 1.5 4.5 6] ... % dpsi
                        };
                    
                    zero_bins = { [], [], [], [], 3, 4, 4 };
                    isOverwriteZeroBoundaries = false;
                    idxZeroBoundaries = [1 2 3];
                    
                case 'traditional-rades'
                    labels_initial = {'G' 'A' 'L' 'v' '\dot v' '\dot h' '\dot \psi'};
                    labels_transition = {'G' 'A' 'L' 'v' '\dot v(t)' '\dot h(t)' '\dot \psi(t)' ...
                        '\dot v(t+1)' '\dot h(t+1)' '\dot \psi(t+1)'};
                    
                    temporal_map = [5 8; 6 9; 7 10];
                    
                    % Full connected matrix, so we don't manually encode
                    % connections, so we can use triangle
                    G_initial = logical(triu(ones(n_initial)) - eye(n_initial));
                    
                    % Parent = column, child = row
                    G_transition = false(n_transition);
                    % No transitions with G as parent
                    G_transition(2,9) = 1; % A -> \dot h(t+1)
                    G_transition(3,8:10) = 1; %L -> \dot v(t+1), L -> \dot h(t+1), L -> \dot psi(t+1)
                    G_transition(4,[8 10]) = 1; %v -> \dot v(t+1), v -> \dot psi(t+1)
                    G_transition(5,8:10) = 1; %\dot v(t) -> \dot v(t+1), \dot v(t) -> \dot h(t+1), \dot v(t) -> \dot psi(t+1)
                    G_transition(6,8:9) = 1; %\dot h(t) -> \dot v(t+1), \dot h(t) -> \dot h(t+1)
                    G_transition(7,8:10) = 1; %\dot psi(t) -> \dot v(t+1), \dot psi(t) -> \dot h(t+1), \dot psi(t) -> \dot psi(t+1)
                    G_transition = G_transition;
                    % No transitions with \dot v(t+1), \dot h(t+1), \dot psi(t+1) as parent
                    
                    bounds_initial = [0 0; 0 0; 500 18000; 0 300; -2 2; -2000 2000; -8 8];
                    cutpoints_initial = {
                        [2 3 4], ... % G
                        [2 3 4], ... % A
                        [1200 3000 5000], ... % L
                        [30 60 90 120 140 165 250], ... % v
                        [-1 -0.25 0.25 1], ... % dv
                        [-1250 -750 -250 250 750 1250], ... % dh
                        [-6 -4.5 -1.5 1.5 4.5 6] ... % dpsi
                        };
                    
                    zero_bins = { [], [], [], [], 3, 4, 4 };
                    isOverwriteZeroBoundaries = false;
                    idxZeroBoundaries = [1 2 3];
                    
                case 'glider'
                    % Labels
                    labels_initial = {'L' 'v' '\dot v' '\dot h' '\dot \psi'};
                    labels_transition = {'L' 'v' '\dot v(t)' '\dot h(t)' '\dot \psi(t)' ...
                        '\dot v(t+1)' '\dot h(t+1)' '\dot \psi(t+1)'};
                    temporal_map = [3,6;4,7;5,8];
                    
                    % Networks
                    G_initial = logical([0,1,1,1,1;0,0,1,1,1;0,0,0,1,1;0,0,0,0,1;0,0,0,0,0]);
                    G_transition = logical([0,0,0,0,0,1,1,1;0,0,0,0,0,1,1,1;0,0,0,0,0,1,0,0;0,0,0,0,0,0,1,0;0,0,0,0,0,0,0,1;0,0,0,0,0,0,0,0;0,0,0,0,0,1,0,1;0,0,0,0,0,1,0,0]);
                    
                    % Bounds / Cutpoints
                    bounds_initial = [0 0; 0 130; -1.25 1.25; -1250 1250; -17.5 17.5];
                    cutpoints_initial = {
                        [1200 3000 5000], ... % L
                        [15 30 45 60 75 90 105], ... % v
                        [-0.5 -0.15 0.15 0.5], ... % dv
                        [-750 -450 -150 150 450 750], ... % dh
                        [-12.5 -7.5 -2.5 2.5 7.5 12.5] ... % dpsi
                        };
                    zero_bins = { [], [], 3, 4, 4 };
                    isOverwriteZeroBoundaries = false;
                    idxZeroBoundaries = [1];
                    
                otherwise
                    labels_initial={};
                    labels_transition={};
                    temporal_map=nan(0,2);
                    G_initial=false(0,0);
                    G_transition=false(0,0);
                    cutpoints_initial={};
                    bounds_initial=nan(0,2);
                    zero_bins={};
            end
            
            % Call superconstructor
            idxZeroBoundaries = p.Results.idxZeroBoundaries;
            isOverwriteZeroBoundaries = p.Results.isOverwriteZeroBoundaries;
            obj@EncounterModel('parameters_filename',parameters_filename,...
                'idxZeroBoundaries',idxZeroBoundaries,...
                'isOverwriteZeroBoundaries',isOverwriteZeroBoundaries,...
                'labels_initial',labels_initial,...
                'labels_transition',labels_transition,...
                'temporal_map',temporal_map,...
                'G_initial',G_initial,...
                'G_transition',G_transition,...
                'cutpoints_initial',cutpoints_initial,...
                'bounds_initial',bounds_initial,...
                'zero_bins',zero_bins);
            
            % Specify if rotorcraft or not based on parameters_filename
            % This is used when setting the minimum allowable speed when
            % rejection sampling in UncorEncounterModel/track
            if contains(parameters_filename,'rotorcraft')
                obj.isRotorcraft = true;
            else
                obj.isRotorcraft = false;
            end
            
        end
    end
    
    %% Implemented Abstract Class
    methods
        function [outInits, outEvents, outSamples, outEME] = sample(obj,nSamples,sample_time, varargin)
            % SEE ALSO: dbn_hierarchical_sample EncounterModelEvents UncorEncounterModel/track
            
            % Declaration of function for altitude quantization
            round500 = @(num) 500*(floor(num/500) + (mod(num,500) > 250));
            
            % Input handling
            p = inputParser;
            addRequired(p,'nSamples',@isnumeric);
            addRequired(p,'sample_time',@isnumeric);
            addParameter(p,'seed',nan,@isnumeric);
            addParameter(p,'isQuantize500',false,@islogical);
            addParameter(p,'layers',[],@isnumeric);
            
            % Parse
            parse(p,nSamples,sample_time,varargin{:});
            seed = p.Results.seed;
            layers = p.Results.layers;
            isQuantize500 = p.Results.isQuantize500;
            
            % Set random seed
            if ~isnan(seed) && ~isempty(seed)
                oldSeed = rng;
                rng(seed,'twister');
            end
            
            % Preallocate
            outInits = zeros(nSamples,obj.n_initial);
            outEvents = cell(nSamples,1);
            outSamples = cell(nSamples,1);
            outEME(nSamples,1) = EncounterModelEvents;
            
            % Model variable indicies
            idxL = find(strcmp(obj.labels_initial,'"L"'));
            idxV = find(strcmp(obj.labels_initial,'"v"'));
            idxDV = find(strcmp(obj.labels_initial,'"\dot v"'));
            idxDH = find(strcmp(obj.labels_initial,'"\dot h"'));
            idxDPsi = find(strcmp(obj.labels_initial,'"\dot \psi"'));
            
            % Convert object to struct
            % There is a class method to do this, as casting via struct(obj)
            % should be avoided (ref MATLAB documentation)
            % This will calculate all dependent properties, so we don't
            % have to do it every iterate
            s = obj.struct;
            
            % Iterate over the number of samples
            for ii=1:1:nSamples
                
                % Sample model until valid sample produced
                isGood = false;
                while ~isGood
                    
                    % DBN_HIERARCHICAL_SAMPLE Calls dbn_sample() to generate samples from a
                    % dynamic Bayesian network. Variables are sampled discretely in bins and
                    % then dediscretized.
                    [initial, events] = dbn_hierarchical_sample(s, s.dirichlet_initial, s.dirichlet_transition, ...
                        sample_time, s.boundaries, s.zero_bins, s.resample_rates, s.start);
                    
                    % uniform draw for initial altitude within user-defined layer
                    % For nominal use cases, layers should not be defined.
                    % It is primarily used by em-pairing-uncor-importancesampling
                    if ~isempty(layers)
                        h_ft = layers(initial(idxL),1) + rand*(diff(layers(initial(idxL),:)));
                    else
                        h_ft = initial(idxL);
                    end
                    
                    % round to nearest 500-ft increment if level (vertical rate, dh = 0)
                    if initial(idxDH) == 0 && isQuantize500
                        h_ft = round500(h_ft);
                    end
                    
                    if ~isempty(layers) | isQuantize500
                        initial(idxL) = h_ft;
                    end
                    
                    % make sure vertical rate not greater than airspeed
                    if initial(idxV)*1.68781 > abs(initial(idxDH))/60
                        isGood = true;
                    else
                        isGood = false;
                    end
                end
                
                % Convert to samples
                samples = events2samples(initial, events);
                
                % Generate controls array
                controls = events2controls(initial,events,s);
                
                % Reorder to [t dh dpsi dv] to order that EncounterModelEvents (EME) expects
                % As of July 2021, for the uncorrelated models, idxEME = [3 4 2]
                idxEME = [idxDH, idxDPsi, idxDV] - size(controls,2)+1;
                controls = controls(:,[1 idxEME]);
                
                % Convert to units used by EncounterModelEvents
                controls(:,2) = controls(:,2) / 60; % dh: fpm to fps
                controls(:,3) = deg2rad(controls(:,3)); % dpsi: deg/s to rad/s
                controls(:,4) = controls(:,4) * 1.68780972222222; % dv: kts/s to ft/s2;
                
                % Instantiate EncounterModelEvents
                eme = EncounterModelEvents( 'event', controls );
                
                % Assign to output
                outInits(ii,:) = initial;
                outEvents{ii} = events;
                outSamples{ii} = samples;
                outEME(ii) = eme;
            end
            
            % Change back to original seed
            if ~isnan(seed) && ~isempty(seed)
                rng(oldSeed);
            end
        end
    end
    
    %% Track
    methods
        function outResults = track(obj,nSamples,sample_time,varargin)
            % SEE ALSO: UncorEncounterModel/sample run_dynamics_fast placeTrack
            
            % Input handling
            p = inputParser;
            addRequired(p,'nSamples',@isnumeric);
            addRequired(p,'sample_time',@isnumeric);
            addParameter(p,'initialSeed',nan,@isnumeric);
            addParameter(p,'isQuantize500',false,@islogical);
            addParameter(p,'coordSys','NEU',@ischar);
            addParameter(p,'isPlot',false,@islogical);
            
            % Geodetic coordinate system
            % Default is lat/lon origin is Exit 35C on I95, Massachusetts
            % There are some towers nearby and minor elevation change, so
            % its a good location to demonstrate obstacle avoidance and
            % estimated AGL altitude
            addParameter(p,'lat0_deg',42.29959,@isnumeric);
            addParameter(p,'lon0_deg',-71.22220,@isnumeric);
            addParameter(p,'z_agl_tol_ft',200,@isnumeric);
            
            % Optional - DEM
            addParameter(p,'dem','globe',@ischar);
            addParameter(p,'Z_m',[],@isnumeric);
            addParameter(p,'refvec',[],@isnumeric);
            addParameter(p,'R',map.rasterref.GeographicCellsReference.empty(0,1), @(x)(isa(x,'map.rasterref.GeographicCellsReference') | isa(x,'map.rasterref.GeographicPostingsReference')));
            
            % Obstacle
            addParameter(p,'Tdof',table,@istable);
            addParameter(p,'dofMaxRange_ft',2000,@isnumeric);
            addParameter(p,'dofMaxVert_ft',1000,@isnumeric);
            addParameter(p,'dofMinHeight_ft',50,@isnumeric);
            addParameter(p,'dofTypes', {'ag equip','antenna','lgthouse','met','monument','silo','spire','stack','t-l twr','tank','tower','utility pole','windmill'},@iscell);
            
            % Parse
            parse(p,nSamples,sample_time,varargin{:});
            seed = p.Results.initialSeed;
            isQuantize500 = p.Results.isQuantize500;
            coordSys = p.Results.coordSys;
            lat0_deg = p.Results.lat0_deg;
            lon0_deg = p.Results.lon0_deg;
            z_agl_tol_ft = p.Results.z_agl_tol_ft;
            Tdof = p.Results.Tdof;
            dofMaxRange_ft = p.Results.dofMaxRange_ft;
            dofMaxVert_ft = p.Results.dofMaxVert_ft;
            dofMinHeight_ft = p.Results.dofMinHeight_ft;
            dofTypes = p.Results.dofTypes;
            Z_m = p.Results.Z_m;
            refvec = p.Results.refvec;
            R = p.Results.R;
            isPlot = p.Results.isPlot;
            
            % Preallocate output
            outResults = cell(nSamples,1);
            
            % Initial 2D position
            % Vertical axis set in for loop based on model sample
            n_ft = 0;
            e_ft = 0;
            
            % Model variable indicies
            idxG = find(strcmp(obj.labels_initial,'"G"'));
            idxA = find(strcmp(obj.labels_initial,'"A"'));
            idxL = find(strcmp(obj.labels_initial,'"L"'));
            idxV = find(strcmp(obj.labels_initial,'"v"'));
            idxDV = find(strcmp(obj.labels_initial,'"\dot v"'));
            idxDH = find(strcmp(obj.labels_initial,'"\dot h"'));
            idxDPsi = find(strcmp(obj.labels_initial,'"\dot \psi"'));
            
            % If true, variable already discretized in initial sample
            isDiscretized = cellfun(@isempty,obj.dediscretize_parameters);
            
            % Some rejection sampling thresholds
            minAlt_ft = min(obj.boundaries{idxL}); % ft
            maxAlt_ft = max(obj.boundaries{idxL}); % ft
                
            % Other dynamic thresholds
            minDH_ft_s = min(obj.boundaries{idxDH}) / 60; % hdot: ft/min -> ft/s
            maxDH_ft_s = max(obj.boundaries{idxDH}) / 60; % hdot: ft/min -> ft/s
            
            % Dynamic constraints for run_dynamics_fast
            % v_low,v_high,dh_ftps_min,dh_ftps_max,qmax,rmax
            % ftps, ftps, ftps, ftps, rad, rad
            % We don't use minSpeed_ft_s and maxSpeed_ft_s because we don't
            % want to have the dynamics model in run_dynamics_fast override
            % samples from the model.
            dyn = [1.7 max(obj.boundaries{idxV})* 1.68780972222222 minDH_ft_s maxDH_ft_s deg2rad(3), 1000000];
            
            % Iterate over samples
            for ii=1:1:nSamples
                
                isGood = false;
                while ~isGood
                    % Generate samples from dynamic bayesian network
                    [initial, ~, ~, EME] = obj.sample(1,sample_time,'seed',seed,'isQuantize500',isQuantize500);
                    
                    % Seed has been used, so advance it
                    % If seed = NaN, nan + 1 = nan.
                    seed = seed + 1;
                    
                    % Parse
                    controls = EME.event;
                    
                    % Parse initial and convert units as needed
                    h_ft = initial(idxL); % Altitude: no units conversion needed
                    v_ft_s = initial(idxV) * 1.68780972222222;   % v: KTAS -> ft/s (use mean altitude for layer)
                    dv_ft_ss = initial(idxDV) * 1.68780972222222;   % vdot: kt/s -> ft/s^2
                    dh_ft_s = initial(idxDH) / 60;  % hdot: ft/min -> ft/s
                    dpsi_rad_s = deg2rad(initial(idxDPsi));  % psidot: deg/s -> rad/s
                    
                    % Calculate heading, pitch and bank angles
                    heading_rad = 0;
                    pitch_rad = asin(dh_ft_s/v_ft_s);
                    bank_rad = atan(v_ft_s*dpsi_rad_s/32.2); % 32.2 = acceleration g
                    
                    % Initial conditions array for run_dynamics_fast
                    ic = [0,v_ft_s,n_ft,e_ft,h_ft,heading_rad,pitch_rad,bank_rad,dv_ft_ss];
                    
                    % Simulate track using run_dynamics_fast
                    results = run_dynamics_fast(ic,controls,dyn,ic,controls,dyn,sample_time);
                    results = results(1);
                    isSec = rem(results.time,1) == 0;
                    
                    % Calculate vertical rate (magnitude)
                    results_dh_ft_s = computeVerticalRate(results.up_ft(isSec),results.time(isSec));
                    results_dh_ft_s = abs(results_dh_ft_s);
                    
                    % Calculates speed and vertical rate limits based on
                    % encounter model distributions
                    dynLims = obj. getDynamicLimits(initial,results,idxG,idxA,idxL,idxV,idxDH,isDiscretized);
                    
                    % Rejection sampling criteria
                    isViolateL = any(results.up_ft < minAlt_ft | results.up_ft > maxAlt_ft);
                    isViolateV = any(results.speed_ftps < dynLims.minVel_ft_s | results.speed_ftps > dynLims.maxVel_ft_s);
                    isViolateDH = any(results_dh_ft_s > dynLims.maxVertRate_ft_s);
   
                    if isViolateL | isViolateV | isViolateDH
                        isGood = false;
                    else
                        isGood = true;
                    end
                end
                
                % Convert to timetable
                rowTimes = seconds(results.time);
                TT = timetable(results.north_ft,results.east_ft,results.up_ft,results.speed_ftps,results.phi_rad,results.theta_rad,results.psi_rad,...
                    'VariableNames',{'north_ft','east_ft','up_ft','speed_ft_s','phi_rad','theta_rad','psi_rad'},...
                    'RowTimes',rowTimes);
                
                switch lower(coordSys)
                    case 'neu'
                        outResults{ii} = TT;
                    case 'geodetic'
                        
                        % Filter DOF based on bounding box of anchor points
                        if any(strcmpi(p.UsingDefaults,'Tdof'))
                            [latc, lonc] = scircle1(lat0_deg,lon0_deg,182283,[],wgs84Ellipsoid('ft'));
                            bbox = [min(lonc), min(latc); max(lonc), max(latc)];
                            [~, Tdof] = gridDOF('inFile',[getenv('AEM_DIR_CORE') filesep 'output' filesep 'dof.mat'],...
                                'BoundingBox_wgs84',bbox,...
                                'minHeight_ft',dofMinHeight_ft,...
                                'isVerified',true,...
                                'obsTypes',dofTypes);
                        else
                            Tdof = p.Results.Tdof;
                        end
                        
                        % Create obstacles polygons
                        spheroid_ft = wgs84Ellipsoid('ft');
                        [latObstacle,lonObstacle] = scircle1(Tdof.lat_deg,Tdof.lon_deg,repmat(dofMaxRange_ft,size(Tdof,1),1),[],spheroid_ft,'degrees',20);
                        altObstacle_ft_agl = Tdof.alt_ft_agl + dofMaxVert_ft;
                        
                        % Translate to geodetic using placeTrack
                        args = {'labelTime','Time','labelX','east_ft','labelY','north_ft','labelZ','up_ft',...
                            'z_agl_tol_ft',z_agl_tol_ft,'z_units','agl',...
                            'latObstacle',latObstacle,'lonObstacle',lonObstacle,'altObstacle_ft_agl',altObstacle_ft_agl,...
                            'Z_m',Z_m,'refvec',refvec,'R',R,...
                            'isPlot',isPlot,'seed',seed};
                        outTrack = placeTrack(TT,lat0_deg,lon0_deg,args{:});
                        
                        % Assign
                        outResults{ii} = outTrack;
                end
            end
        end
        

        
        
    end   
end % End class def

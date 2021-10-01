classdef CorTerminalModel < EncounterModel
    % Copyright 2008 - 2021, MIT Lincoln Laboratory
    % SPDX-License-Identifier: BSD-2-Clause
    
    properties (SetAccess=immutable, GetAccess=public)
        srcData(1,:) char {};
        parameters_directory(1,:) char {};
    end
    
    properties (SetAccess=protected, GetAccess=public)
        % ownship trajectory models (AC1)
        % Intent = Landing (1)
        mdlFwd1_1(1,1) EncounterModel {mustBeNonempty};
        mdlBck1_1(1,1) EncounterModel {mustBeNonempty};
        % Intent = Takeoff (2)
        mdlFwd1_2(1,1) EncounterModel {mustBeNonempty};
        mdlBck1_2(1,1) EncounterModel {mustBeNonempty};
        
        % intruder trajectory models (AC2)
        % Intent = Landing (1)
        mdlFwd2_1(1,1) EncounterModel {mustBeNonempty};
        mdlBck2_1(1,1) EncounterModel {mustBeNonempty};
        % Intent = Takeoff (2)
        mdlFwd2_2(1,1) EncounterModel {mustBeNonempty};
        mdlBck2_2(1,1) EncounterModel {mustBeNonempty};
        % Intent = Transit (3)
        mdlFwd2_3(1,1) EncounterModel {mustBeNonempty};
        mdlBck2_3(1,1) EncounterModel {mustBeNonempty};
        
        % Dynamic limits
        dynLimits1(1,1) struct {};
        dynLimits2(1,1) struct {};
    end
    
    properties (SetAccess=public, GetAccess=public)
        bounds_sample(:,2) double {mustBeNumeric mustBeReal};
        acType1(1,:) char {};
        acType2(1,:) char {};
    end
    
    properties (Dependent=true)
        variables2controls;
    end
    
    %% Constructor Function
    methods
        function obj = CorTerminalModel(varargin)
            
            % Input parser
            p = inputParser;
            addParameter(p,'srcData','terminalradar');
            
            % Parse
            parse(p,varargin{:});
            srcData = p.Results.srcData;
            
            % Set directory
            parameters_directory = [getenv('AEM_DIR_BAYES') filesep 'model' filesep 'correlated_terminal' filesep srcData];
            
            % Initialize modelNames
            % identifies the full file path for each of the model files that
            % comprise the termianl encounter model
            modelNames = struct;
            names = {'encounter_model';'ownship_landing_model';'ownship_takeoff_model';'ownship_takeoff_model_reverse';'ownship_landing_model_reverse';'intruder_landing_model_reverse';'intruder_landing_model';'intruder_takeoff_model';'intruder_takeoff_model_reverse';'intruder_transit_model';'intruder_transit_model_reverse'};
            for ii=1:1:numel(names)
                % Find
                listing = dir([parameters_directory filesep '*_' names{ii} '.txt']);
                
                % Parse
                fname = [listing.folder filesep listing.name];
                
                % Assign
                modelNames.(names{ii}) = fname;
            end
            
            % Call superconstructor for encounter geometry model
            obj@EncounterModel('parameters_filename',modelNames.encounter_model);
            obj.srcData = srcData;
            obj.parameters_directory = parameters_directory;
            obj.bounds_sample = [-inf(length(obj.N_initial),1), inf(length(obj.N_initial),1)]; % Default, no limits
            
            % Load all ownship trajectory models (AC1)
            % Intent = Landing (1)
            obj.mdlFwd1_1 = EncounterModel('parameters_filename',modelNames.ownship_landing_model);
            obj.mdlBck1_1 = EncounterModel('parameters_filename',modelNames.ownship_landing_model_reverse);
            % Intent = Takeoff (2)
            obj.mdlFwd1_2 = EncounterModel('parameters_filename',modelNames.ownship_takeoff_model);
            obj.mdlBck1_2 = EncounterModel('parameters_filename',modelNames.ownship_takeoff_model_reverse);
            
            % Load all intruder trajectory models (AC2)
            % Intent = Landing (1)
            obj.mdlFwd2_1 = EncounterModel('parameters_filename',modelNames.intruder_landing_model);
            obj.mdlBck2_1 = EncounterModel('parameters_filename',modelNames.intruder_landing_model_reverse);
            % Intent = Takeoff (2)
            obj.mdlFwd2_2 = EncounterModel('parameters_filename',modelNames.intruder_takeoff_model);
            obj.mdlBck2_2 = EncounterModel('parameters_filename',modelNames.intruder_landing_model_reverse);
            % Intent = Transit (3)
            obj.mdlFwd2_3 = EncounterModel('parameters_filename',modelNames.intruder_transit_model);
            obj.mdlBck2_3 = EncounterModel('parameters_filename',modelNames.intruder_landing_model_reverse);
            
            % Set auto update to true
            obj.isAutoUpdate = true;
            
            % Assumed aircraft type and dynamic limits
            % When auto updating, setting these variables will also set
            % dynLimits1 and dynLimits2
            obj.acType1 = 'GENERIC';
            obj.acType2 = 'GENERIC';
        end
    end
    
    %% Static methods
    methods(Static)
        
        function [hmd_ft, vmd_ft, tcpa_s, tcpa_index_own, tcpa_index_int] = getGeneratedMissDistance( traj )
            % GETGENERATEDMISSDISTANCE  Finds horizontal and vertical miss distances (in
            % feet) and time of CPA for a pair of generated trajectories.
            
            [~,ia,ib] = intersect(traj(1).t_s, traj(2).t_s);
            dx_nm = traj(1).x_nm(ia) - traj(2).x_nm(ib);
            dy_nm = traj(1).y_nm(ia) - traj(2).y_nm(ib);
            dxy_ft = sqrt(dx_nm.^2 + dy_nm.^2).*6076.1154855643; % Convert from nautical miles to feet
            dz_ft = traj(2).z_ft(ib) - traj(1).z_ft(ia);
            
            [hmd_ft, idx] = min(dxy_ft);
            vmd_ft = dz_ft(idx);
            tcpa_s = traj(1).t_s(ia(idx));
            tcpa_index_own = ia(idx);
            tcpa_index_int = ib(idx);
            
        end
        
        function isReject = CheckCumTurn(heading, cumTurnLimit)
            % The purpose of this function is to reject any trajectories where the
            % cumulative turn is > cumTurnLimit (nominally 180 deg). E.g., we don't
            % want trajectories where the ownship is turning around in circles.
            
            % Preallocate / initialize
            isReject = false;
            
            heading = wrapTo180(heading);
            headingDiffs = round(diff(heading),1);
            turnStart = find(headingDiffs(1:end-1)==0 & headingDiffs(2:end)~=0) + 1;
            turnEnd = find(headingDiffs(1:end-1)~=0 & headingDiffs(2:end)==0);
            
            % The whole trajectory is a turn
            if isempty(turnStart)
                turnStart = 1;
            end
            
            if isempty(turnEnd)
                turnEnd = numel(headingDiffs);
            end
            
            if numel(turnStart)>numel(turnEnd)
                turnEnd(end+1) = numel(headingDiffs);
            end
            
            % Loop through the turns and see if there are any that go more than the cumTurnLimit
            for i = 1:numel(turnStart)
                headings = wrapTo180(headingDiffs(turnStart(i):turnEnd(i)));
                
                % Find the start of different signed headings
                startIdx = find([0; diff(sign(headings))]~=0);
                
                if isempty(startIdx)
                    isReject = any(abs(cumsum(headings(1:end))) > cumTurnLimit);
                    if isReject
                        return;
                    end
                    
                else
                    startIdx = unique([1; startIdx; numel(headings)+1]);
                    for j = 1:numel(startIdx)-1
                        isReject = any(abs(cumsum(headings(startIdx(j):startIdx(j+1)-1))) > cumTurnLimit);
                        if isReject
                            return;
                        end
                    end
                end
                
            end
        end
        
        
        function [isClose, isLow] = CheckRunwayProximity(traj,thresDist_ft,thresAltLow_ft)
            % Checks if trajectory struct is within thresDist_ft distance 
            % and thresAltLow_ft relevative altitude of the origin (0,0) 
            
            % Preallocate
            isClose = false;
            isLow = false;
            
            % Calculate distance from runway
            d_nm = hypot(traj.x_nm,traj.y_nm)';
            d_ft = d_nm * 1.68781;
            
            % Determine if track gets close to runway
            isClose = d_ft <= thresDist_ft;
            
            % Determine if any close points satsify altitude criteria
            if any(isClose)
                isLow = traj.z_ft(isClose) <= thresAltLow_ft;
            end
            
            % Output booleans
            isClose = any(isClose);
            isLow = any(isLow);
        end
        
        function [isClimb, isDescend] = CheckIntentVertical(traj,thresVertRate_ft_s)
            % Checks if trajectories have enough updates that have a
            % magnitude of thresVertRate_ft_s when climbing or descending
            
            % Determine number of trajectories
            nTraj = numel(traj);
            
            % Preallocate
            isClimb = false(nTraj,1);
            isDescend = false(nTraj,1);
            
            % Iterate over trajectories
            for ii=1:1:nTraj
                % Parse
                time_s = (1:1:numel(traj(ii).t_s))';
                alt_ft = traj(ii).z_ft';
                trkDur_s = time_s(end);
                
                % Calculate vertical rate and threshold
                dh_ft_s = computeVerticalRate(alt_ft,time_s);
                vertThresTime_s = (max(alt_ft) - min(alt_ft)) / thresVertRate_ft_s;
                perecentThres = min([0.2 , vertThresTime_s / trkDur_s ],[],2);
                
                % Percentage of time track is climbing or descend
                percentClimb = nnz(dh_ft_s >= thresVertRate_ft_s) / numel(dh_ft_s);
                percentDescend = nnz(dh_ft_s <= -1*thresVertRate_ft_s) / numel(dh_ft_s);
                
                % Determine if track is climbing, descending, or remaining level
                isClimb(ii) = percentClimb >= perecentThres;
                isDescend(ii) = percentDescend >= perecentThres;
            end
        end
        
        function [isPass] = CheckDynamicLimits(traj,dynLims)
            % Checks if a trajectory satisfies the dynamic limits, defined
            % by dynLims, for altitude, speed, vertical rate, turn rate,
            % pitch, and cumulative turn
            %
            % SEE ALSO CorTerminalModel/getDynamicLimits
            
            % Preallocate
            isPass = true;
            
            % Calculate time starting at zero, instead w.r.t to CPA
            time_s = (1:1:numel(traj.t_s))';
            
            % Reject if there are one or less points
            % When calculating dynamics, such as computeHeadingRate, we
            % need at least two points
            if numel(time_s) <= 1
                isPass = false;
            else
                % Altitude
                isAltitude = traj.z_ft' > 0 & traj.z_ft' <= dynLims.maxAltitude_ft;
                
                % Speed
                isSpeed = traj.v_ft_s' >= dynLims.minVel_ft_s & traj.v_ft_s' <= dynLims.maxVel_ft_s;
                
                % Vertical rate (magnitude)
                dh_ft_s = computeVerticalRate(traj.z_ft',time_s);
                isVertRate = abs(dh_ft_s) <= dynLims.maxVertRate_ft_s;
                
                % Turn Rate
                heading_rad = deg2rad(traj.heading_deg)';
                [dpsi_rad_s,deltaHeading,~] = computeHeadingRate(heading_rad,time_s);
                isTurnRate = abs(dpsi_rad_s) <= dynLims.maxTurnRate_deg_s;
                
                % Pitch check - pitch = asin(vertical rate/speed)
                % Vertical rate and speed are both in feet per second
                isPitch = abs(asind(abs(diff(traj.z_ft))./traj.v_ft_s(2:end)))' <= dynLims.pitch_deg;
                isPitch = [true; isPitch];
                
                % Cumulative Turn
                % Note CheckCumTurn returns if rejected or not, it also returns a single
                % boolean...this needs to be changed in a future revision
                isCumTurn = ~CorTerminalModel.CheckCumTurn(traj.heading_deg', dynLims.maxCumTurn_deg);
                
                % Aggregate and output
                isAll = isAltitude & isSpeed & isVertRate & isTurnRate & isPitch;
                isPass = all(isAll) & isCumTurn;
            end
        end
        
        function [trajOut, tcpa_adjusted] = reformatTrajFiles(trajIn, tcpa)
            % Save off the encounter data needed for save_waypoints
            
            tSubset = intersect(trajIn(1).t_s, trajIn(2).t_s);
            trajIn = CorTerminalModel.GetTrajectorySegment(trajIn, tSubset);
            trajOut = struct('t',[],'y',[],'x',[],'h',[]);
            
            tcpa_index = trajIn(1).t_s == tcpa;
            
            for ii = 1:2
                
                t_s = trajIn(ii).t_s - trajIn(ii).t_s(1);
                e_ft = trajIn(ii).x_nm.*6076.1154855643;
                n_ft = trajIn(ii).y_nm.*6076.1154855643;
                h_ft = trajIn(ii).z_ft;
                v_ft_s = trajIn(ii).v_ft_s;
                
                trajOut(ii).t = t_s;
                trajOut(ii).y = n_ft;
                trajOut(ii).x = e_ft;
                trajOut(ii).h = h_ft;
                trajOut(ii).v = v_ft_s;
                
            end
            
            tcpa_adjusted = trajOut(1).t(tcpa_index);
        end
        
        function traj = GetTrajectorySegment(traj, tSubset)
            % Segement trajectory based on a time subset, tSubset
            
            fields = fieldnames(traj);
            for jj = 1:length(traj)
                [~,idxs] = intersect(traj(jj).t_s, tSubset);
                for ii=1:length(fields)
                    traj(jj).(fields{ii}) = traj(jj).(fields{ii})(idxs);
                end
            end
        end
        
        function T = aggregateTerminalMetadata(inDir)
            % Aggregates metadata files within a directory
            
            % Input handling
            if nargin < 1
                inDir = [getenv('AEM_DIR_BAYES') filesep 'output' filesep 'terminal'];
            end
            
            % Identify files in directory
            listing = dir([inDir filesep '**' filesep '*.mat']);
            
            % Do something if there are files
            if isempty(listing)
                T = table;
                warning('Returning empty table, no .mat files found in %s',inDir);
            else
                % Iterate over files
                for ii=1:1:numel(listing)
                    % Load data
                    iiFile = [listing(ii).folder filesep listing(ii).name];
                    data = load(iiFile);
                    
                    % Tranpose to column order
                    if isrow(data.id);
                        data = structfun(@transpose,data,'UniformOutput',false);
                    end
                    
                    % Parse
                    iiN = numel(data.id);
                    iiT = struct2table(data);
                    iiT.file = repmat(string(iiFile),iiN,1);
                    
                    % Concat
                    if ii == 1
                        T = iiT;
                    else
                        T = [T;iiT];
                    end
                end
                
                % Sort by id
                T = sortrows(T,'id','ascend');
            end
        end
        
        function [f] = plotSamplesGeo(inSamples)
            % Plot positions of aircraft at sampled CPA
            %
            % SEE ALSO CorTerminalModel/sample
                    
            % Inputs hardcode
            colors = [ [0,0.45,0.74] ; [0.85,0.33,0.1] ];
            ownColor = colors(1,:);
            intColor = colors(2,:);
                        
            % Parse
            x1_nm = cellfun(@(sampleGeo)([sampleGeo.own_distance*cosd(sampleGeo.own_bearing)]),inSamples,'uni',true);
            x2_nm = cellfun(@(sampleGeo)([sampleGeo.int_distance*cosd(sampleGeo.int_bearing)]),inSamples,'uni',true);
            
            y1_nm = cellfun(@(sampleGeo)([sampleGeo.own_distance*sind(sampleGeo.own_bearing)]),inSamples,'uni',true);
            y2_nm = cellfun(@(sampleGeo)([sampleGeo.int_distance*sind(sampleGeo.int_bearing)]),inSamples,'uni',true);
            
            % Crete figure
            f = figure('Name','Sampled CPA Positions','Units','inches','Position',[1,1,5,5],'Color','w');
            
            % Plot
            scatter(0,0,20,'k','+','DisplayName','Runway mean position');hold on;
            scatter(x1_nm,y1_nm,10,ownColor,'o','filled','DisplayName','CPA - Ownship'); 
            scatter(x2_nm,y2_nm,10,intColor,'s','filled','DisplayName','CPA - Intruder');
            axis([-8 8 -8 8]); axis('square'); grid on; hold off;
            xlabel('X (nautical miles)'); ylabel('Y (nautical miles)');
            legend('Location','northeast','NumColumns',1,'FontSize',10);
        end
        
        
        function [f] = plotGeneratedEncounter( traj, figNum )
            % Plot generated terminal encounter
            %
            % SEE ALSO CorTerminalModel/track
            
            % Number of aircraft
            n =  numel(traj);
            
            % Inputs hardcode
            colors = [ [0,0.45,0.74] ; [0.85,0.33,0.1] ];
            ownColor = colors(1,:);
            intColor = colors(2,:);
            
            % Input handling
            if nargin < 2
                f = figure;
            else
                f = figure(figNum);
            end
            set(f,'Units','inches','Position',[2 2 5.4 7.5]);
            tiledlayout('flow','Padding','none','TileSpacing','normal');
            set(gcf,'name','plotGeneratedEncounter');
            
            % Planview
            nexttile([2 2]);
            hold on; grid on;
            
            % Plot runway mean position
            rwy = scatter(0, 0, 'Marker', '+', 'LineWidth', 1.5, 'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'k', 'SizeData', 72,'DisplayName','Runway mean position');
            
            % Initial and CPA positions
            for ii = 1:1:n
                switch ii
                    case 1
                        acName = 'Ownship';
                        markerCpa = '*';
                        markerStart = 's';
                    case 2
                        acName = 'Intruder';
                        markerCpa = 'h';
                        markerStart = 'd';
                    otherwise
                        markerCpa = '*';
                        markerStart = 's';
                        acName = sprintf('Aircraft #%i',ii)
                end
                
                idx = find(traj(ii).t_s == 0);
                cpa = scatter(traj(ii).x_nm(idx), traj(ii).y_nm(idx), 'Marker', markerCpa, 'LineWidth', 1, 'MarkerEdgeColor', colors(ii,:), 'MarkerFaceColor', colors(ii,:), 'SizeData', 36,'DisplayName',['CPA - ' acName]);
                start = scatter(traj(ii).x_nm(1), traj(ii).y_nm(1), 'Marker', markerStart, 'LineWidth', 1, 'MarkerEdgeColor', colors(ii,:), 'MarkerFaceColor', colors(ii,:), 'SizeData', 36,'DisplayName',['Initial - ' acName]);
            end
            
            % Peri and Intra Encounter Tracks
            [~,ia,ib] = intersect(traj(1).t_s, traj(2).t_s);
            
            plot(traj(1).x_nm, traj(1).y_nm, 'LineWidth', 1, 'LineStyle', ':', 'Color', ownColor,'HandleVisibility','on','DisplayName','Peri-Track - Ownship');
            plot(traj(2).x_nm, traj(2).y_nm, 'LineWidth', 1, 'LineStyle', ':', 'Color', intColor,'HandleVisibility','on','DisplayName','Peri-Track - Intruder');
            
            own = plot(traj(1).x_nm(ia), traj(1).y_nm(ia), 'LineWidth', 2, 'LineStyle', '-', 'Color', ownColor,'DisplayName','Intra-Track - Ownship');
            int = plot(traj(2).x_nm(ib), traj(2).y_nm(ib), 'LineWidth', 2, 'LineStyle', '-', 'Color', intColor,'DisplayName','Intra-Track - Intruder');
            
            xlabel('X (nautical miles)'); ylabel('Y (nautical miles)')
            lg = legend('NumColumns',2,'FontSize',10);
            
            dx = traj(1).x_nm(ia) - traj(2).x_nm(ib);
            dy = traj(1).y_nm(ia) - traj(2).y_nm(ib);
            dxy = sqrt(dx.^2 + dy.^2).*6076.1154855643;
            text(0.05, 0.1, sprintf('HMD = %d ft', round(min(dxy))), 'Units', 'normalized');
            axis([-8 8 -8 8]); axis('square'); hold off;
            
            % Altitude
            nexttile;
            hold on; grid on;
            for ii = 1:1:n
                switch ii
                    case 1
                        acName = 'Ownship';
                        markerCpa = '*';
                        markerStart = 's';
                        idxIntersect = ia;
                    case 2
                        acName = 'Intruder';
                        markerCpa = 'h';
                        markerStart = 'd';
                        idxIntersect = ib;
                    otherwise
                        markerCpa = '*';
                        markerStart = 's';
                        acName = sprintf('Aircraft #%i',ii)
                end
                
                % Tracks
                plot(traj(ii).t_s, traj(ii).z_ft, 'LineWidth', 1, 'LineStyle', ':', 'Color', colors(ii,:),'DisplayName',['Peri-Encounter Track - ' acName]);
                plot(traj(ii).t_s(idxIntersect), traj(ii).z_ft(idxIntersect), 'LineWidth', 2, 'LineStyle', '-', 'Color', colors(ii,:),'DisplayName',['Intra-Encounter Track - ' acName]);
                
                % CPA / Initial
                idx = find(traj(ii).t_s == 0);
                scatter(traj(ii).t_s(idx), traj(ii).z_ft(idx), 'Marker', markerCpa, 'LineWidth', 1, 'MarkerEdgeColor', colors(ii,:), 'MarkerFaceColor', colors(ii,:),'SizeData', 36,'DisplayName',['Initial - ' acName],'HandleVisibility','off');
                scatter(traj(ii).t_s(1), traj(ii).z_ft(1), 'Marker', markerStart, 'LineWidth', 1, 'MarkerEdgeColor', colors(ii,:), 'MarkerFaceColor', colors(ii,:),'SizeData', 36,'DisplayName',['Initial - ' acName],'HandleVisibility','off');
                
            end
            hold off;
            xlabel('Time relative to CPA (s)'); ylabel('Altitude (feet)');
            set(gca,'YLim', [200 3000]);
            
            % Speed
            nexttile
            hold on; grid on;
            for ii = 1:1:n
                switch ii
                    case 1
                        acName = 'Ownship';
                        markerCpa = '*';
                        markerStart = 's';
                        idxIntersect = ia;
                    case 2
                        acName = 'Intruder';
                        markerCpa = 'h';
                        markerStart = 'd';
                        idxIntersect = ib;
                    otherwise
                        markerCpa = '*';
                        markerStart = 's';
                        acName = sprintf('Aircraft #%i',ii)
                end
                
                % Tracks
                plot(traj(ii).t_s,traj(ii).v_ft_s./1.6878098571012, 'LineWidth', 1, 'LineStyle', ':', 'Color', colors(ii,:),'DisplayName',['Peri-Encounter Track - ' acName]);
                plot(traj(ii).t_s(idxIntersect), traj(ii).v_ft_s(idxIntersect)./1.6878098571012, 'LineWidth', 2, 'LineStyle', '-', 'Color', colors(ii,:),'DisplayName',['Intra-Encounter Track - ' acName]);
                
                % CPA / Initial
                idx = find(traj(ii).t_s == 0);
                scatter(traj(ii).t_s(idx), traj(ii).v_ft_s(idx)./1.6878098571012, 'Marker', markerCpa, 'LineWidth', 1, 'MarkerEdgeColor', colors(ii,:), 'MarkerFaceColor', colors(ii,:),'SizeData', 36,'DisplayName',['Initial - ' acName],'HandleVisibility','off');
                scatter(traj(ii).t_s(1), traj(ii).v_ft_s(1)./1.6878098571012, 'Marker', markerStart, 'LineWidth', 1, 'MarkerEdgeColor', colors(ii,:), 'MarkerFaceColor', colors(ii,:),'SizeData', 36,'DisplayName',['Initial - ' acName],'HandleVisibility','off');
            end
            hold off;
            xlabel('Time relative to CPA (s)'); ylabel('Speed (knots)');
            set(gca,'YLim',[75 500]/1.6878098571012);
            
            lg.Layout.Tile = 'south'; % <-- place legend south of tiles
        end
        
    end
    
    %% Setters, Updaters, and Preallocate
    methods
        function obj = set.acType1(obj,newValue);
            obj.acType1 = newValue;
            if obj.isAutoUpdate
                obj.dynLimits1 = obj.getDynamicLimits(1);
            end
        end
        
        function obj = set.acType2(obj,newValue);
            obj.acType2 = newValue;
            if obj.isAutoUpdate
                obj.dynLimits2 = obj.getDynamicLimits(2);
            end
        end
    end
    
end % End class def

function [outResults, genTime_s] = track(obj,nSamples,varargin)
% Copyright 2008 - 2021, MIT Lincoln Laboratory
% SPDX-License-Identifier: BSD-2-Clause
%
% Sample the terminal encounter geometry model
% SEE ALSO: CorTerminalModel/sample CorTerminalModel/createEncounter

%% Input handling
p = inputParser;
addRequired(p,'nSamples',@isnumeric);
addParameter(p,'initialSeed',nan,@isnumeric);
addParameter(p,'firstID',1,@isnumeric);
addParameter(p,'isPlot',false,@islogical);
addParameter(p,'minEncTime_s',30,@isnumeric); % Minimum amount of time that ownship and intruder must overlap
addParameter(p,'thresDist_ft',2.5*6076,@isnumeric); % Criteria if track is "close" to runway, aligns with thresDist_ft from classifyTakeoffLand()
addParameter(p,'thresAltLow_ft',750,@isnumeric); % Criteria if track is low relative runway, aligns with thresAltLow_ft from classifyTakeoffLand()
addParameter(p,'thresVertRate_ft_s',300/60,@isnumeric); % Criteria for vertical rate (in determining a climb/descend vs. level)
addOptional(p,'verboseLvl',0,@isnumeric); % The greater the value, the less displayed to screen

% Parse
parse(p,nSamples,varargin{:});
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
    oldSeed = rng;
    rng(seed,'twister');
end

%% Preallocate output
outResults = struct('sample',[],'traj',[]);
genTime_s = zeros(nSamples,1);

%% Iterate over desired number of encounters
for ii=1:nSamples
    % Start timer
    tic
    
    % Preallocate
    isGood = false;
    counter = 0;
    id = ii + (firstID-1);
    
    while ~isGood
        
        % Sample encounter geometry model
        [outInits, outSamples] = obj.sample(1,'seed',nan);
        sampleGeo = outSamples{1};
        
        % Sample trajectory models and create an encounter
        [traj] = obj.createEncounter(sampleGeo,tmax_s);
        
        if isempty(traj(1).t_s) | isempty(traj(2).t_s)
            counter = counter + 1;
        end
        
        % Compute Acceleration
        a1_ft_s_s = computeAcceleration(traj(1).v_ft_s,1:1:numel(traj(1).t_s));
        a2_ft_s_s = computeAcceleration(traj(2).v_ft_s,1:1:numel(traj(2).t_s));
        
        % Compute greatest magnitude
        maxA1_ft_s_s = max(abs(a1_ft_s_s));
        maxA2_ft_s_s = max(abs(a2_ft_s_s));
        
        if any(maxA1_ft_s_s > obj.dynLimits1.maxAccel_ft_s_s) | any(maxA2_ft_s_s > obj.dynLimits2.maxAccel_ft_s_s)
            counter = counter + 1;
        end
        
        % Calculate hmd, vmd, and time when cpa occurs
        [hmd_ft, vmd_ft, tcpa_s, ~, ~] = obj.getGeneratedMissDistance(traj);
        
        % Check that CPA occurs within pm 5 seconds of ownship initialization
        % The model assumes tca is at 0,
        % If the encounter is initialized too far away, it could skew the assumptions
        isCpaGood = abs(tcpa_s) <= 10;
        
        % CPA is a common exclusionary filter - if not good immediately regenerate
        if isCpaGood
            % Check if this is sufficient time overlap between ownship and intruder
            encTime_s = length(intersect(traj(1).t_s, traj(2).t_s));
            isLongEnough = encTime_s >= minEncTime_s;
            
            % Calculate if tracks are close and low to runway
            [isClose1, isLow1] = obj.CheckRunwayProximity(traj(1),thresDist_ft,thresAltLow_ft);
            [isClose2, isLow2] = obj.CheckRunwayProximity(traj(2),thresDist_ft,thresAltLow_ft);
            
            % Ownship, must be close and low OR not close
            isRunwayProx1 = ((isClose1 & isLow1) | ~isClose1);
            
            % Intruder, must be close and low OR not close when landing / takeoff
            % Cannot be close and low while transit
            switch  sampleGeo.int_intent
                case 3 % transit
                    isRunwayProx2 = ~(isClose2 & isLow2);
                otherwise % land, takeoff
                    isRunwayProx2 = ((isClose2 & isLow2) | ~isClose2);
            end
            
            % Aggregate runway logicals
            isRunwayGood = isRunwayProx1 & isRunwayProx2;
            
            % Determine vertical rate intent for both tracks
            % Determine if an track is climbing, descending, or remaining level
            [isClimb, isDescend] = obj.CheckIntentVertical(traj,thresVertRate_ft_s);
            
            % Check that encounter conditions satisfy intruder intent
            switch  sampleGeo.int_intent
                case 1 % land
                    isIntIntentGood = isDescend(2);
                case 2 % takeoff
                    isIntIntentGood = isClimb(2);
                otherwise % transit
                    isIntIntentGood = true;
            end
            
            % Check ownship is conducting straight-in landing or straight-out takeoff
            switch  sampleGeo.own_intent
                case 1 % land
                    percentHeadingGood = nnz(traj(1).heading_deg >= 90-30 & traj(1).heading_deg <= 90+30) / numel(traj(1).heading_deg);
                    isOwnIntentGood = isDescend(1) && (percentHeadingGood >= .95);
                case 2 % takeoff
                    percentHeadingGood = nnz(traj(1).heading_deg >= 270-30 & traj(1).heading_deg <= 270+30) / numel(traj(1).heading_deg);
                    isOwnIntentGood = isClimb(1) && (percentHeadingGood >= .95);
            end
            
            % Check dynamics, if other criteria are good
            [isDynGood1] = obj.CheckDynamicLimits(traj(1),obj.dynLimits1);
            [isDynGood2] = obj.CheckDynamicLimits(traj(2),obj.dynLimits2);
            
            % Check all criteria
            isGood = isCpaGood & isLongEnough & isRunwayGood & isOwnIntentGood & isIntIntentGood & isDynGood1 & isDynGood2;  
        end
        
        if ~isGood
            counter = counter + 1;
        end
        
    end % End while
    
    % Plot if desired
    if p.Results.isPlot
        f = obj.plotGeneratedEncounter( traj, id );
        set(f,'name',sprintf('A=%i, own_intent=%i, int_intent=%i',obj.start{1},obj.start{2},obj.start{3}));
    end
    
    % Assign output
    % Format trajectory files
    [trajFrmt, tcpa_adjusted] = obj.reformatTrajFiles(traj, tcpa_s);
    
    % Assign encounter struct
    outResults(ii).sample = sampleGeo;
    outResults(ii).traj = trajFrmt;
    
    % Resolve indexing issues caused by tcpa at 0
    if tcpa_adjusted == 0
        tcpa_adjusted = 1;
    end
    
    % Add some additional metadata
    outResults(ii).sample.id = id;
    outResults(ii).sample.tcpa = tcpa_adjusted;
    outResults(ii).sample.hmd_ft = hmd_ft;
    outResults(ii).sample.vmd_ft = vmd_ft;
    outResults(ii).sample.nmac = abs(hmd_ft)<500 & abs(vmd_ft)<100;
    verticalRate_ftpm = abs(diff(trajFrmt(1).h))*60;
    outResults(ii).sample.own_vertRate_ftpm = verticalRate_ftpm(tcpa_adjusted);
    outResults(ii).sample.own_initVertRate_ftpm = verticalRate_ftpm(1);
    verticalRate_ftpm = abs(diff(trajFrmt(2).h))*60;
    outResults(ii).sample.int_vertRate_ftpm = verticalRate_ftpm(tcpa_adjusted);
    outResults(ii).sample.int_initVertRate_ftpm = verticalRate_ftpm(1);
    outResults(ii).sample.own_initSpeed_ftps = trajFrmt(1).v(1);
    outResults(ii).sample.int_initSpeed_ftps = trajFrmt(2).v(1);
    outResults(ii).sample.own_initAlt_ft = trajFrmt(1).h(1);
    outResults(ii).sample.int_initAlt_ft = trajFrmt(2).h(1);
    
    % Stop and assign timer
    genTime_s(ii) = toc;
end

%% Change back to original seed
if ~isnan(seed) && ~isempty(seed)
    rng(oldSeed);
end


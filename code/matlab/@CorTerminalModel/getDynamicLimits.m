function dynamicLimits = getDynamicLimits(obj,acId)
% Copyright 2008 - 2021, MIT Lincoln Laboratory
% SPDX-License-Identifier: BSD-2-Clause

switch acId
    case 1 
        acType = obj.acType1;
    case 2
        acType = obj.acType2;
    otherwise
        error('acId must be either 1 or 2');
end

switch upper(acType)
    case 'GENERIC'
        dynamicLimits.minVel_ft_s = 50; % 30 knots 
        dynamicLimits.maxVel_ft_s = 506; % 300 knots
        dynamicLimits.maxTurnRate_deg_s = 12;
        dynamicLimits.maxAltitude_ft = 5000;
        dynamicLimits.maxVertRate_ft_s = 6000/60;
        dynamicLimits.maxCumTurn_deg = Inf;
        dynamicLimits.pitch_deg = Inf;
        
    case 'RTCA228_A1'
        dynamicLimits.minVel_ft_s = 169; % 100 knots
        dynamicLimits.maxVel_ft_s = 491; % 291 knots
        dynamicLimits.maxTurnRate_deg_s = 1.5;
        dynamicLimits.maxAltitude_ft = 5000;
        dynamicLimits.maxVertRate_ft_s = 2500/60;
        dynamicLimits.maxCumTurn_deg = 180;
        dynamicLimits.pitch_deg = 15;
        
    case 'RTCA228_A2'
        dynamicLimits.minVel_ft_s = 68; % 40 knots
        dynamicLimits.maxVel_ft_s = 338; % 200 knots
        dynamicLimits.maxTurnRate_deg_s = 3;
        dynamicLimits.maxAltitude_ft = 5000;
        dynamicLimits.maxVertRate_ft_s = 1500/60;
        dynamicLimits.maxCumTurn_deg = 180;
        dynamicLimits.pitch_deg = 15;
        
    case 'RTCA228_A3'
        dynamicLimits.minVel_ft_s = 68; % 40 knots
        dynamicLimits.maxVel_ft_s = 186; % 110 knots
        dynamicLimits.maxTurnRate_deg_s = 7;
        dynamicLimits.maxAltitude_ft = 5000;
        dynamicLimits.maxVertRate_ft_s = 500/60;
        dynamicLimits.maxCumTurn_deg = 180;
        dynamicLimits.pitch_deg = 15;
        
    otherwise
        error('Unknown aircraft type of %s',acType);
end

%% Acceleration Dynamic Limit
% The default value in sampleMultipleEncounters() should be , the same as
% this calculation. We include it in the run script here to show how we
% calculated the default value
% Accelerations can be large due to how we sample trajectories in
% flyTrajectoryForwards and flyTrajectoryBackwards. These functions
% incrementally sample the models in 2 second intervals. When sampling the
% next increment, the velocity bin not the sampled velocity, is used. So it
% is possible from the lower end of bin #1 and then sample the upper end of
% bin #2. As of July 2021, the velocity bins were 100 feet per second wide.
% So its technically possible to sample velocity such it transitions from
% 100 (bin 1) to 199 (bin 2) in one timestep. To minimize this, we set the
% maximum acceleration the width of the largest bin (50 feet per second)
idxSpeed = find(strcmp(obj.mdlFwd1_1.labels_initial,'"speed"'));
dynamicLimits.maxAccel_ft_s_s = max(diff(obj.cutpoints_initial{idxSpeed})); % 50 or ~30 knots per second


function [traj] = createEncounter(obj,sampleGeo,tmax_s)
% Copyright 2008 - 2021, MIT Lincoln Laboratory
% SPDX-License-Identifier: BSD-2-Clause
%
% Generate trajectory pair given an encounter sample
%
% SEE ALSO CorTerminalModel CorTerminalModel/track

%% Preallocate
traj = repmat(struct(), 1,2);

%% Assign models
% Assign ownship trajectory model (AC1)
switch sampleGeo.own_intent
    case 1
        mdlFwd1 = obj.mdlFwd1_1;
        mdlBck1 = obj.mdlBck1_1;
    case 2
        mdlFwd1 = obj.mdlFwd1_2;
        mdlBck1 = obj.mdlFwd1_2;
    otherwise
        error('Unknown int_intent = %i',sampleGeo.own_intent);
end

% Assign intruder trajectory model (AC2)
switch sampleGeo.int_intent
    case 1
        mdlFwd2 = obj.mdlFwd2_1;
        mdlBck2 = obj.mdlBck2_1;
    case 2
        mdlFwd2 = obj.mdlFwd2_2;
        mdlBck2 = obj.mdlFwd2_2;
    case 3
        mdlFwd2 = obj.mdlFwd2_3;
        mdlBck2 = obj.mdlFwd2_3;
    otherwise
        error('Unknown int_intent = %i',sampleGeo.int_intent);
end

%% Initialization
% coordinate system is along-runway, right-of-runway
% Column 1 = ownship, column 2 = intruder
% x0 = north / south (yNorth), y0 = east / west (xEast), z0 = altitude agl

x0_nm = [sampleGeo.own_distance*cosd(sampleGeo.own_bearing), sampleGeo.int_distance*cosd(sampleGeo.int_bearing)];
y0_nm = [sampleGeo.own_distance*sind(sampleGeo.own_bearing), sampleGeo.int_distance*sind(sampleGeo.int_bearing)];
z0_ft = [sampleGeo.own_alt, sampleGeo.int_alt];
heading0_deg = [sampleGeo.own_heading, sampleGeo.int_heading];
speed0_ft_s = [sampleGeo.own_speed, sampleGeo.int_speed];

%% Iterate over each aircraft
for ii = 1:1:2
    
    % Select model and intent
    switch ii
        case 1
            dynLims = obj.dynLimits1;
            mdlForwards = mdlFwd1;
            mdlBackwards = mdlBck1;
            intent = sampleGeo.own_intent;
            isOwnship = true;
        case 2
            dynLims = obj.dynLimits2;
            mdlForwards = mdlFwd2;
            mdlBackwards = mdlBck2;
            intent = sampleGeo.int_intent;
            isOwnship = false;
    end
    
    % propagate forward and bckwards
    fwd = PropagateTrajectory(isOwnship,mdlForwards, 1, x0_nm(ii), y0_nm(ii), z0_ft(ii), speed0_ft_s(ii), heading0_deg(ii), intent, tmax_s, dynLims);
    bck = PropagateTrajectory(isOwnship,mdlBackwards, -1, x0_nm(ii), y0_nm(ii), z0_ft(ii), speed0_ft_s(ii), heading0_deg(ii), intent, tmax_s, dynLims);
    
    % combine forwards and backwards
    fields = fieldnames(fwd);
    for jj = 1:length(fields)
        traj(ii).(fields{jj}) = [fwd.(fields{jj}), bck.(fields{jj})(1,2:end)];
    end
    
    % order in time
    [~,idxs] = sort(traj(ii).t_s);
    for jj = 1:length(fields)
        traj(ii).(fields{jj}) = traj(ii).(fields{jj})(idxs);
    end
    
    % smooth speed and altitude
    % See (not publicly released) CalcKinematicFeatures() for similar smoothing during model training
    traj(ii).v_ft_s = local_smooth(traj(ii).t_s(:), traj(ii).v_ft_s(:), 5)';
    traj(ii).z_ft = local_smooth(traj(ii).t_s(:), traj(ii).z_ft(:), 15)';
end
end

function [traj] = PropagateTrajectory(isOwnship, mdl, dt_s, x0_nm, y0_nm, z0_ft, v0_ft_s, heading0_deg, intent, tmax_s, dynLims)
% Copyright XXXX - XXXX, MIT Lincoln Laboratory
% SPDX-License-Identifier: XXXX
%
% PropagateTrajectory using the identified dynamic Bayesian network,
% propagates until reaching a specified end state or or maximum time.
%
% SEE ALSO dbn_sample bn_dirichlet_prior setTransitionPriors

%% Loosely preallocate
traj = struct('t_s',0,'x_nm',x0_nm,'y_nm',y0_nm,'z_ft',z0_ft,'heading_deg',heading0_deg,'v_ft_s',v0_ft_s);

%% Define rotation matrix
rotationmatrix = @(theta) [cosd(theta), -sind(theta); sind(theta), cosd(theta)];

%% Location of variables in initial network
% Check that last three variables are heading, altitude, speed
assert(strcmp(mdl.labels_initial{4},'"heading"'));
assert(strcmp(mdl.labels_initial{5},'"altitude"'));
assert(strcmp(mdl.labels_initial{6},'"speed"'));

idx.int = find(strcmp(mdl.labels_initial,'"intent"'));
idx.dist = find(strcmp(mdl.labels_initial,'"distance"'));
idx.bear = find(strcmp(mdl.labels_initial,'"bearing"'));
idx.head = find(strcmp(mdl.labels_initial,'"heading"'));
idx.alt = find(strcmp(mdl.labels_initial,'"altitude"'));
idx.spd = find(strcmp(mdl.labels_initial,'"speed"'));

%% Define valid discrete values for altitude and speed
% Altitude (maximum only, no minimum alt defined in dynamic limits)
discreteValidAlt = 1:1:find((mdl.dediscretize_parameters{idx.alt}<=dynLims.maxAltitude_ft) == true,1,'last');

% Speed
s = find((mdl.dediscretize_parameters{idx.spd}>=dynLims.minVel_ft_s) == false,1,'last'); % First bin
e = find((mdl.dediscretize_parameters{idx.spd}<=dynLims.maxVel_ft_s) == true,1,'last'); % Last bin
discreteValidV = s:1:e;

%% priors
prior_initial = bn_dirichlet_prior(mdl.N_initial, 0);
prior_transition = setTransitionPriors(mdl.G_transition, mdl.r_transition, mdl.temporal_map, 1);

heading_discrete = hierarchical_discretize(heading0_deg, mdl.cutpoints_initial{idx.head}, mdl.cutpoints_fine{idx.head}, mdl.zero_bins{idx.head});

% Cast object into a struct
% This is really important for performance when using dbn_sample, as will
% use dot notion to get order_initial and order_transition from the first
% input which has the model parameters. The EncounterModel SuperClass will
% call bn_sort as part of the gettter for order_initial and
% order_transition because they are Dependent properties. By casting to a
% struct, bn_sort is only called once instead of every iteration through
% the while isResample loop
% dbn_sample
mdlStruct = struct(mdl);

%%
% Initialize counters
t_s = 0; % time
ii = 1; % track update

xy_nm = [x0_nm; y0_nm];
v_ft_s = rotationmatrix(heading0_deg)*[v0_ft_s;0];

% State at t = 0;
%x_nm = xy_nm(1);
%y_nm = xy_nm(2);
z_ft = z0_ft;
heading_deg = heading0_deg;
v_ft_s = v_ft_s;

isResample = true;
while isResample
    
    % Update output struct
    traj.t_s(ii) = t_s;
    traj.x_nm(ii) = xy_nm(1);
    traj.y_nm(ii) = xy_nm(2);
    traj.z_ft(ii) = z_ft;
    traj.heading_deg(ii) = heading_deg;
    traj.v_ft_s(ii) = norm(v_ft_s);
    
    % Calculate new XY position based on speed and old XY position
    dx_ft = v_ft_s.*dt_s;
    dx_nm = dx_ft./6076.1154855643; % Convert from feet to nautical miles
    xy_nm = xy_nm + dx_nm;
    
    % Calculate current heading (SOH CAH TOA)
    currHdg_deg = wrapTo360(atan2d(v_ft_s(2), v_ft_s(1)));
    traj.heading_deg(ii) = currHdg_deg;
    
    % Compute current altitude taking max vertical rates into account
    if ii > 1
        altDifference_ft = z_ft - traj.z_ft(ii-1);
        currZ_ft = traj.z_ft(ii-1) + sign(altDifference_ft)*min( dynLims.maxVertRate_ft_s, abs(altDifference_ft) );
        traj.z_ft(ii) = currZ_ft;
    end
    
    % Create start distribution to be used by dbn_sample
    [start, heading_discrete, alt_discrete, spd_discrete] = CreateStartDistribution(mdl, idx, intent, xy_nm(1), xy_nm(2), z_ft, heading_deg, v_ft_s);
    
    % Sample dynamic Bayesian network
    % events - matrix of (t, variable_index, new_value)
    isResample = true;
    while isResample
        [~, events] = dbn_sample(mdlStruct, prior_initial, prior_transition, 2, start);
        isResample = false;
        
        % Iterate over events
        nEvents = size(events,1);
        for jj=1:1:nEvents
            switch events(jj,2)
                case 4 % Heading
                    % only update desired heading if in a different bin
                    if events(jj,3) ~= heading_discrete
                        heading_deg = dediscretize(events(jj,3), mdl.dediscretize_parameters{idx.head});
                    end
                    isResample = false;
                case 5 % Altitude
                    if any(discreteValidAlt  == events(jj,3))
                        z_ft = dediscretize(events(jj,3), mdl.dediscretize_parameters{idx.alt});
                        isResample = false;
                    else
                        isResample = true;
                    end
                case 6 % Speed
                    % Check min and max speed limits
                    if any(discreteValidV  == events(jj,3))
                        v_ft_s(1) = dediscretize(events(jj,3), mdl.dediscretize_parameters{idx.spd});
                        
                        % Account if the variable bin is okay but
                        % dediscretize() samples a value less than the
                        % minimum or greater than the maximum
                        if v_ft_s(1) < dynLims.minVel_ft_s; v_ft_s(1) = dynLims.minVel_ft_s; end
                        if v_ft_s(1) > dynLims.maxVel_ft_s; v_ft_s(1) = dynLims.maxVel_ft_s; end
                        
                        v_ft_s(2) = 0;
                        v_ft_s = rotationmatrix(heading_deg)*v_ft_s;
                        isResample = false;
                    else
                        isResample = true;
                    end
                otherwise
                    warning('Cannot update variable index %i', events(jj,2));
            end
            
            % Break for loop if need to resample
            if isResample; break; end
        end
    end
    
    % Turn to desired heading at maximum rate
    turn1 = heading_deg - currHdg_deg;
    %turn2 = wrapTo360(heading_deg) - wrapTo360(currHdg_deg);
    
    turn1 = round(turn1,2);
    deltaHdg_deg = min(abs(turn1),dynLims.maxTurnRate_deg_s)*sign(turn1);
    %     if abs(turn1) <= abs(turn2)
    %         deltaHdg_deg = min(abs(turn1),dynLims.maxTurnRate_deg_s)*sign(turn1); %turn1
    %     else
    %         deltaHdg_deg = min(abs(turn2),dynLims.maxTurnRate_deg_s)*sign(turn2); %turn2;
    %     end
    v_ft_s = rotationmatrix(deltaHdg_deg)*v_ft_s;
    
    % Advance counters
    t_s = t_s + dt_s;
    ii = ii + 1;
    
    % Determine if we need to continue sampling
    isResample = CheckTrajectoryConditions(isOwnship, mdl.bounds_initial(idx.dist,:), intent, xy_nm, t_s, tmax_s);
end
end

%% Helper Functions
function [start, heading_discrete, alt_discrete, spd_discrete] = CreateStartDistribution(mdl, idx, intent, jx_nm, jy_nm, jz_ft, jhead_deg, jv_ft_s)
% Creates start distribution to be used by dbn_sample
% SEE ALSO discretize_bayes

% Intent doesn't change
intent_discrete = intent;

% Distance
dist_nm = norm([jx_nm;jy_nm]);
dist_discrete = discretize_bayes(dist_nm, mdl.cutpoints_initial{idx.dist});

% Bearing
bearing = wrapTo360(atan2d(jy_nm, jx_nm));
bearing_discrete = discretize_bayes(bearing, mdl.cutpoints_initial{idx.bear});

% Heading
heading_discrete = discretize_bayes(jhead_deg, mdl.cutpoints_initial{idx.head});

% Altitude
alt_discrete = discretize_bayes(jz_ft, mdl.cutpoints_initial{idx.alt});

% Speed
spd_discrete = discretize_bayes(norm(jv_ft_s), mdl.cutpoints_initial{idx.spd});

% Aggregate and output
start = {intent_discrete, dist_discrete, bearing_discrete, heading_discrete, alt_discrete, spd_discrete};
end

function isResample = CheckTrajectoryConditions(isOwnship, boundsDist_nm, intent, xy_nm, t_s, tmax_s)
%

% Preallocate
isResample = true;

% Distance track is away from runway
d_nm = norm(xy_nm);

% Check if track is too long in duration
violateTime = abs(t_s) > tmax_s;

% Check if too far away from runway
violateFar = d_nm > boundsDist_nm(2);

switch intent
    case 1 % landing
        violateIntent = d_nm <= 0.25;
    case 2 % takeoff
        violateIntent = d_nm <= 0.25;
    otherwise %
        violateIntent = false;
end

% Coordinate system is [0 360] with (Inf, 0) = 0, (Inf, Inf) = 90, ...
% Due to how we generate the runway centric coordinate system,
% ownship headings should have a vector torwards 90 degrees and
% landings have a vector torwards 270 degrees (opposite of 90)
violateOwnship = isOwnship & xy_nm(2) > 0.25;

% Set to true if no violations
isResample = ~any([violateTime;violateFar;violateIntent;violateOwnship]);
end


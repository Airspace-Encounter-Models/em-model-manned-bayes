function dynamicLimits = getDynamicLimits(obj,initial,results,idxG,idxA,idxL,idxV,idxDH,isDiscretized)
% Copyright 2008 - 2021, MIT Lincoln Laboratory
% SPDX-License-Identifier: BSD-2-Clause
%
% Calculates speed and vertical rate limits based on encounter model distributions
%
% SEE ALSO UncorEnocunterModel/track CorTerminalModel/getDynamicLimits

%%
prctLow = 1;
prctHigh = 99;

%% Do something if variables are in expected order
if idxG == 1 && idxA == 2 && idxL == 3 && idxV == 4 && idxDH == 6
    
    % Geographic domain
    if isDiscretized(idxG)
        dG = initial(idxG);
    else
        dG = discretize_bayes(initial(idxG),obj.cutpoints_initial{idxG});
    end
    
    % Airspace class
    if isDiscretized(idxA)
        dA = initial(idxA);
    else
        dA = discretize_bayes(initial(idxA),obj.cutpoints_initial{idxA});
    end
    
    % Altitude layer
    if isDiscretized(idxL)
        dL = initial(idxL);
    else
        dL = discretize_bayes([min(results.up_ft) max(results.up_ft)],obj.cutpoints_initial{idxL});
        dL = min(dL):1:max(dL);
    end
    if ~isrow(dL); dL = dL'; end
    
    % Velocity
    if isDiscretized(idxV)
        dV = initial(idxV);
    else
        results_speed_kts = results.speed_ftps*0.592484;
        dV = discretize_bayes([min(results_speed_kts) max(results_speed_kts)],obj.cutpoints_initial{idxV});
        dV = min(dV):1:max(dV);
    end
    if ~isrow(dV); dV = dV'; end
    
    % Distribution given the first variable (G)
    v_Initial_G = obj.N_initial{idxV}(:,dG:obj.r_initial(idxG):end);
    dh_initial_G =  obj.N_initial{idxDH}(:,dG:obj.r_initial(idxG):end);
    
    % Distribution given the first (G) & second (A) variables
    v_Initial_G_A = v_Initial_G(:,dA:obj.r_initial(idxA):end);
    dh_initial_G_A = dh_initial_G(:,dA:obj.r_initial(idxA):end);
    
    % Velocity distribution first three variables: G, A, L
    % We can easily sum here because velocity is the 4th variable
    v_Initial_G_A_L = v_Initial_G_A(:,unique(dL));
    
    % Vertical rate distribution given G, A, L
    dh_initial_G_A_L = zeros(obj.r_initial(idxDH),1);
    for di=unique(dL)
        dh_initial_G_A_L = dh_initial_G_A_L + dh_initial_G_A(:,di:obj.r_initial(idxL):end);
    end
    
    % Vertical rate distribution given G, A, L
    dh_initial_G_A_L_V = zeros(obj.r_initial(idxDH),1);
    for di=unique(dV)
        dh_initial_G_A_L_V = dh_initial_G_A_L_V + dh_initial_G_A_L(:,di:obj.r_initial(idxV):end);
    end
    assert(size(dh_initial_G_A_L_V,2) == obj.r_initial(5));

    % Aggregate
    v_initial = sum(v_Initial_G_A_L,2);
    dh_initial = sum(dh_initial_G_A_L_V,2);
else
    v_initial = sum(obj.N_initial{idxV},2);
    dh_initial = sum(obj.N_initial{idxDH},2);
end

%% Speed
% Probability distribution for speed bins
% Cumulative sum
% Find bin indicies that satisfy 0.5th and 99.5th
probV = 100*sum(v_initial,2) / sum(v_initial,'all');
csV = cumsum(probV);
kMinV = find(csV >= prctLow,1,'first');
kMaxV = find(csV >= prctHigh,1,'first');

% Add one because there is one more defined edge than bins aka a bin has two edges
minSpeed_ft_s = obj.boundaries{idxV}(kMinV+1) * 1.68780972222222; % v: KTAS -> ft/s
maxSpeed_ft_s = obj.boundaries{idxV}(kMaxV+1) * 1.68780972222222; % v: KTAS -> ft/s

% Ensure that rotorcrafts shouldn't fly faster than 180 knots (304 fps) and
% that fixed-wing don't fly slower than 30 knots
if obj.isRotorcraft & maxSpeed_ft_s > 304; maxSpeed_ft_s = 304; end
if ~obj.isRotorcraft & minSpeed_ft_s < 30; minSpeed_ft_s = 30; end

%% Vertical Rate
% Probability distribution for speed bins
% Cumulative sum
% Find bin indicies that satisfy 0.5th and 99.5th
probDH = 100*sum(dh_initial,2) / sum(dh_initial,'all');
csDH = cumsum(probDH);
kMinDH = find(csDH >= prctLow,1,'first');
kMaxDH = find(csDH >= prctHigh,1,'first');

maxVertRate_ft_s = max(abs(obj.boundaries{idxDH}([kMinDH kMaxDH]+1)/60));
if isnan(maxVertRate_ft_s); maxVertRate_ft_s = 0; end

%% Aggregate for output
dynamicLimits = struct;
dynamicLimits.minVel_ft_s = minSpeed_ft_s;
dynamicLimits.maxVel_ft_s = maxSpeed_ft_s;
dynamicLimits.maxVertRate_ft_s = maxVertRate_ft_s;
end
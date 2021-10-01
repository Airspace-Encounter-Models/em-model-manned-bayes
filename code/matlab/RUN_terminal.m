% Copyright 2008 - 2021, MIT Lincoln Laboratory
% SPDX-License-Identifier: BSD-2-Clause

%% Inputs
% Data source
srcData = 'terminalradar';

% Number of total tracks
nSamples = 18;

% Random seed
initialSeed = 1;

% Aircraft type 1 used to set dynamic limits when rejection sampling
acType1 = 'RTCA228_A1';

%% Instantiate object
mdl = CorTerminalModel('srcData',srcData);

%% Demonstrate how to update aircraft type
% This is used to set dynamic limits of aircraft when rejection sampling to
% create encounters
fprintf('The default minimum velocity for %s aircraft 1 is %0.2f feet per second\n',mdl.acType1,mdl.dynLimits1.minVel_ft_s);
mdl.acType1 = acType1;
fprintf('The minimum velocity for %s aircraft 1 is %0.2f feet per second\n',mdl.acType1,mdl.dynLimits1.minVel_ft_s);

%% Create set of start distributions
startCells = mdl.InitStartTerminal('nSamples',nSamples);

%% Iterate over start distributions
for ii=1:1:size(startCells,1)
    % Set start distribution
    mdl.start = startCells(ii,:);
    
    % Demonstrate how to generate samples
    [outInits, outSamples] = mdl.sample(100,'seed',initialSeed);
    mdl.plotSamplesGeo(outSamples);
    
    % Demonstrate how to create an encounter with tracks
    [outResults, genTime_s] = mdl.track(1,'firstID',ii,'initialSeed',initialSeed,'isPlot',true);
end

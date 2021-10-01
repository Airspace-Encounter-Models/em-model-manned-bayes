function start = InitStartTerminal(obj,varargin)
% Copyright 2008 - 2021, MIT Lincoln Laboratory
% SPDX-License-Identifier: BSD-2-Clause
%
% Function creates a cell array that can be parsed to be used as the
% optional arguement 'start' to bn_sample(). 'start' is a cell array
% with same number of elements as n_initial, allows parameters to be preset.
% A parameter can only be preset if all of its parents, if any, are also preset
%
% Currently only supports airspace_class, own_intent, int_intent model variables and
% assumes an equal number of encounters for each combination of class & intent
%
% SEE ALSO CorTerminalModel bn_sample

%% Inputs
p = inputParser;

addOptional(p,'nSamples',1000000,@isnumeric); % Number of encounters to generate
addOptional(p,'airspace_class',[false true true true],@islogical); % Airspace classes to keep, default is to exclude Class B
addOptional(p,'own_intent',[true true],@islogical); % Ownship intent, default is all
addOptional(p,'int_intent',[true true true],@islogical); % Intruder intent, default is all
addOptional(p,'isVerbose',false,@islogical); % If true, display to screen

% Parse
parse(p,varargin{:});
nSamples = p.Results.nSamples;
isVerbose = p.Results.isVerbose;

%% Input checking

% Check that first three variables are airspace_class, own_intent, int_intent
assert(strcmp(obj.labels_initial{1},'"airspace_class"'));
assert(strcmp(obj.labels_initial{2},'"own_intent"'));
assert(strcmp(obj.labels_initial{3},'"int_intent"'));

% Check that variables have the expected number of bins
assert(numel(p.Results.airspace_class) == obj.r_initial(1));
assert(numel(p.Results.own_intent) == obj.r_initial(2));
assert(numel(p.Results.int_intent) == obj.r_initial(3));

%% Preallocate
% Bin values to use
idxClass = find(p.Results.airspace_class == true);
idxOwnInt = find(p.Results.own_intent == true);
idxIntInt = find(p.Results.int_intent == true);

% Number of airspace class and ownship intent combinations
nCombs = numel(idxClass) * numel(idxOwnInt) * numel(idxIntInt);

% In rare case when user didn't request enough samples, display status
if nCombs > nSamples;
    fprintf('%i combinations but requested %i total samples, generating %i samples instead\n',nCombs,nSamples,nCombs);
    nSamples = nCombs;
end

% Number of encounters for each combination
nEncPerComb = ceil(nSamples / nCombs);

% Preallocate start_distribution
start = cell(nSamples,obj.n_initial);

%% Iterate over airspace class and ownship intent
% Initialize start and end indices
s = 1;
e = inf;

% Iterate over airspace class
for ii=idxClass
    
    % Iterate over ownship intent
    for jj=idxOwnInt
        
        % Iterate over intruder intent
        for kk=idxIntInt
            % Update end index
            e = s + nEncPerComb - 1;
            
            % Assign
            start(s:e,1) = repmat({ii},nEncPerComb,1);
            start(s:e,2) = repmat({jj},nEncPerComb,1);
            start(s:e,3) = repmat({kk},nEncPerComb,1);
            
            % Display status
            if isVerbose
                fprintf('encounters %i-%i, airspace_class = %i, own_intent = %i, int_intent = %i\n',s,e,ii,jj, kk);
            end
            
            % Update start index
            s = e + 1;
        end
    end
end

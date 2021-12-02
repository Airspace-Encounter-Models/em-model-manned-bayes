% Copyright 2008 - 2021, MIT Lincoln Laboratory
% SPDX-License-Identifier: BSD-2-Clause
%
%% self
addpath(genpath([getenv('AEM_DIR_BAYES') filesep 'code' filesep 'matlab']));

%% Other repos

% AEM_DIR_CORE
if isempty(getenv('AEM_DIR_CORE'))
    error('startup:aem_dir_core', 'System environment variable, AEM_DIR_CORE, not found\n');
else
    addpath(genpath([getenv('AEM_DIR_CORE') filesep 'matlab']));
end

%% Check for matlab version
if verLessThan('matlab', '9.8')
    warning('Matlab version is less than R2020a (9.8), some code will not work. For example readgeoraster(), used when creating geodetic tracks with UncorEncounterModel/track, was introduced R2020a.');
end

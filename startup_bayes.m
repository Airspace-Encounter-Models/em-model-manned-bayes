% Copyright 2008 - 2021, MIT Lincoln Laboratory
% SPDX-License-Identifier: BSD-2-Clause
%
%% self
addpath(genpath([getenv('AEM_DIR_BAYES') filesep 'code' filesep 'matlab']));

%% Other repos

% AEM_DIR_CORE
if isempty(getenv('AEM_DIR_CORE'))
    error('startup:aem_dir_core','System environment variable, AEM_DIR_CORE, not found\n')
else
    addpath(genpath([getenv('AEM_DIR_CORE') filesep 'matlab']))    
end

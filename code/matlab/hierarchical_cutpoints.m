function cutpoints_fine = hierarchical_cutpoints(cutpoints_coarse, boundaries, n)
    % Copyright 2008 - 2021, MIT Lincoln Laboratory
    % SPDX-License-Identifier: BSD-2-Clause
    % n is the number of fine bins within coarse bins

    % Preallocate output
    cutpoints_fine = cell(numel(cutpoints_coarse) + 1, 1);

    thresholds = [boundaries(1); cutpoints_coarse(:); boundaries(2)];

    for ii = 2:numel(thresholds)
        a = thresholds(ii - 1);
        b = thresholds(ii);
        cutpoints_fine{ii - 1} = a + (1:(n - 1)) * ((b - a) / n);
    end

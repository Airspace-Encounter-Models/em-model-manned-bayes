function [g, lat_CA_deg, lon_CA_deg, lat_US_deg, lon_US_deg, lat_islands_deg, lon_islands_deg, bound_caribbean_lat_deg, bound_caribbean_lon_deg, bound_HI_lat_deg, bound_HI_lon_deg] = IdentifyGeographicVariable(lat_deg, lon_deg, varargin)
    % Copyright 2008 - 2021, MIT Lincoln Laboratory
    % SPDX-License-Identifier: BSD-2-Clause
    % Identifies the geographic domain for latitude, longitude coordinates

    %% Input parser
    % Create input parser
    p = inputParser;

    % Required
    addRequired(p, 'lat_deg', @isnumeric);
    addRequired(p, 'lon_deg', @isnumeric);

    % Optional - Location of natural earth data adminstrative data
    addParameter(p, 'inFile', [getenv('AEM_DIR_CORE') filesep 'data' filesep 'NE-Adminstrative' filesep 'ne_10m_admin_1_states_provinces.shp']);

    % Optional - Bounds
    addParameter(p, 'boundsLat_deg', [0 75]); % If true, filter to have only points in the northern hemisphere
    addParameter(p, 'boundsLon_deg', [-168 -30]); % If true, filter to have only points in the western hemisphere...%-178 covers Adak, the westernmost muni in the USA, but avoids issues when transitioning to eastern hemi

    % Optional - Level 0 administrative boundaries to consider
    % https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2#Officially_assigned_code_elements
    addParameter(p, 'iso_a2', {'US', 'CA', 'PR', 'VI'});

    % Optional -  Boundaries considered as islands
    addParameter(p, 'islands_iso_3166_2', {'US-HI', 'US-PR', 'VI-X01~', 'VI-X02~', 'VI-X03~'});

    % Optional -  Boundaries to remove
    addParameter(p, 'remove_iso_3166_2', {});

    % Buffer and Union
    addParameter(p, 'bufwidth_deg', nm2deg(6), @isnumeric); % bufdwith parameter for bufferm()
    addParameter(p, 'shrink', 0.85, @isnumeric); % shrink parameter for boundary()
    addParameter(p, 'areaMin_nm', 25, @isnumeric); % Minimum landmass area (note uncor 1200-code v2.0 used 87.6: https://arc.aiaa.org/doi/pdf/10.2514/6.2013-5049)

    % Optional Variables you not want to calculate everytime
    addParameter(p, 'latCA_deg', {}, @iscell);
    addParameter(p, 'lonCA_deg', {}, @iscell);
    addParameter(p, 'latUS_deg', {}, @iscell);
    addParameter(p, 'lonUS_deg', {}, @iscell);
    addParameter(p, 'latIslands_deg', {}, @iscell);
    addParameter(p, 'lonIslands_deg', {}, @iscell);
    addParameter(p, 'boundCaribbean_lat_deg', []);
    addParameter(p, 'boundCaribbean_lon_deg', []);
    addParameter(p, 'boundHI_lat_deg', []);
    addParameter(p, 'boundHI_lon_deg', []);

    % Optional - Plot
    addParameter(p, 'isPlot', false, @islogical); % If true, plot boundary
    addParameter(p, 'isVerbose', false, @islogical); % If true, plot boundary

    % Parse
    parse(p, lat_deg, lon_deg, varargin{:});

    %% Preallocate Output
    g = zeros(size(lat_deg));

    %% Load Natural Earth Adminstrative Boundaries
    ne_admin = shaperead(p.Results.inFile, 'UseGeoCoords', true);

    %% Filter based on ISO 3166-1 alpha-2 codes
    ll = contains({ne_admin.iso_a2}, p.Results.iso_a2);
    ne_admin = ne_admin(ll);

    ll = contains({ne_admin.iso_3166_2}, p.Results.remove_iso_3166_2);
    ne_admin(ll) = [];

    %% Identify islands, canada, and usa (conus + ak)
    lCA = strcmpi({ne_admin.iso_a2}, 'CA')';
    lUS = strcmpi({ne_admin.iso_a2}, 'US')';
    lIslands = any(cell2mat(cellfun(@(x)(strcmpi({ne_admin.iso_3166_2}, x)'), p.Results.islands_iso_3166_2, 'uni', false)), 2);

    %% Process Adminstrative Boundaries
    % Canada
    if any(strcmpi(p.UsingDefaults, 'latCA_deg') | strcmpi(p.UsingDefaults, 'lonCA_deg'))
        [lat_CA_deg, lon_CA_deg, ~] = JoinMergeSplit({ne_admin(lCA & ~lIslands).Lat}, {ne_admin(lCA & ~lIslands).Lon}, p);
        [lat_CA_deg, lon_CA_deg, ~] = BufferBoundUnion(lat_CA_deg, lon_CA_deg, p);
    else
        lat_CA_deg = p.Results.latCA_deg;
        lon_CA_deg = p.Results.lonCA_deg;
    end

    % CONUS + AK
    if any(strcmpi(p.UsingDefaults, 'latUS_deg') | strcmpi(p.UsingDefaults, 'lonUS_deg'))
        [lat_US_deg, lon_US_deg, ~] = JoinMergeSplit({ne_admin(lUS & ~lIslands).Lat}, {ne_admin(lUS & ~lIslands).Lon}, p);
        [lat_US_deg, lon_US_deg, ~] = BufferBoundUnion(lat_US_deg, lon_US_deg, p);
    else
        lat_US_deg = p.Results.latUS_deg;
        lon_US_deg = p.Results.lonUS_deg;
    end

    % Islands
    if any(strcmpi(p.UsingDefaults, 'latIslands_deg') | strcmpi(p.UsingDefaults, 'lonIslands_deg'))
        [lat_islands_deg, lon_islands_deg, ~] = JoinMergeSplit({ne_admin(lIslands).Lat}, {ne_admin(lIslands).Lon}, p);
        [lat_islands_deg, lon_islands_deg, ~] = BufferBoundUnion(lat_islands_deg, lon_islands_deg, p);
    else
        lat_islands_deg = p.Results.latIslands_deg;
        lon_islands_deg = p.Results.lonIslands_deg;
    end

    %% Create polygons for island offshore regions
    if any(strcmpi(p.UsingDefaults, 'boundCaribbean_lat_deg') | strcmpi(p.UsingDefaults, 'boundCaribbean_lon_deg'))
        [bound_caribbean_lat_deg, bound_caribbean_lon_deg] = genBoundaryIso3166A2('iso_a2', {'AW', 'AG', 'BB', 'BS', 'CU', 'CW', 'DR', 'JM', 'KY', 'PR', 'TC', 'TT', 'VG'}, 'mode', 'boundary', 'shrink', 0.5, ...
                                                                                  'isBuffer', true, 'bufwidth_deg', nm2deg(12), ...
                                                                                  'isPlot', p.Results.isPlot);
    else
        bound_caribbean_lat_deg = p.Results.boundCaribbean_lat_deg;
        bound_caribbean_lon_deg = p.Results.boundCaribbean_lon_deg;
    end

    if any(strcmpi(p.UsingDefaults, 'boundHI_lat_deg') | strcmpi(p.UsingDefaults, 'boundHI_lon_deg'))
        [bound_HI_lat_deg, bound_HI_lon_deg] = genBoundaryIso3166A2('iso_a2', {'US'}, 'mode', 'convhull', ...
                                                                    'isBuffer', true, 'bufwidth_deg', nm2deg(70), ...
                                                                    'boundsLat_deg', [15 30], 'boundsLon_deg', [-161.5, -150], ...
                                                                    'isPlot', p.Results.isPlot);
    else
        bound_HI_lat_deg = p.Results.boundHI_lat_deg;
        bound_HI_lon_deg = p.Results.boundHI_lon_deg;
    end

    %% Plot polygons
    if p.Results.isPlot
        figure;
        set(gcf, 'name', 'CA');
        [lat, lon] = polyjoin(lat_CA_deg, lon_CA_deg);
        geoplot(lat, lon);
        figure;
        set(gcf, 'name', 'CONUS + AK');
        [lat, lon] = polyjoin(lat_US_deg, lon_US_deg);
        geoplot(lat, lon);
        figure;
        set(gcf, 'name', 'Islands');
        [lat, lon] = polyjoin(lat_islands_deg, lon_islands_deg);
        geoplot(lat, lon);
    end

    %% Find track indicies over land
    % First check for points over USA (G=1)
    is_us_mainland = cellfun(@(x, y)(sparse(InPolygon(lon_deg, lat_deg, x, y))), lon_US_deg, lat_US_deg, 'uni', false);
    is_us_mainland = full(any(cell2mat(is_us_mainland'), 2));

    % Check if all points over US (this is likely for many tracks)
    if all(is_us_mainland)
        is_islands = false(size(is_us_mainland));
        is_us_offshore = false(size(is_us_mainland));
        is_islands_offshore = false(size(is_us_mainland));
        is_canada = false(size(is_us_mainland));
    else
        % Next check for points over Canada
        is_canada = cellfun(@(x, y)(sparse(InPolygon(lon_deg, lat_deg, x, y))), lon_CA_deg, lat_CA_deg, 'uni', false);
        is_canada = full(any(cell2mat(is_canada'), 2));

        % Check for points over the islands
        is_islands = cellfun(@(x, y)(sparse(InPolygon(lon_deg, lat_deg, x, y))), lon_islands_deg, lat_islands_deg, 'uni', false);
        is_islands = full(any(cell2mat(is_islands'), 2));

        % Determine if near Hawaii or in the Caribbean
        is_caribbean = InPolygon(lon_deg, lat_deg, bound_caribbean_lon_deg, bound_caribbean_lat_deg);
        is_hi = InPolygon(lon_deg, lat_deg, bound_HI_lon_deg, bound_HI_lat_deg);
        is_islands_offshore = is_caribbean | is_hi;

        % Default is offshore of the USA
        % This can be set as ~(isMainUS | isCanada | isIslands | isOffshoreIslands)
        is_us_offshore = true(size(g));
    end

    %% Assign output
    % The order of assignment is important here!
    % Elements could be overwritten and changed based on priority
    % The highest priority should be assigned last
    g(is_us_offshore) = 3;
    g(is_islands_offshore) = 4;
    g(is_islands) = 2;
    g(is_canada) = 5;
    g(is_us_mainland) = 1;
end

% Helper functions
function [out_lat_deg, out_lon_deg, area_nm] = JoinMergeSplit(in_lat_deg, in_lon_deg, p)

    % Join, merge, split
    [join_lat_deg, join_lon_deg] = polyjoin(in_lat_deg, in_lon_deg);
    [merged_lat_deg, merged_lon_deg] = polymerge(join_lat_deg, join_lon_deg);
    [out_lat_deg, out_lon_deg] = polysplit(merged_lat_deg, merged_lon_deg);

    % Calculate area
    area_nm = cellfun(@(lat, lon)(areaint(lat, lon, wgs84Ellipsoid('nm'))), out_lat_deg, out_lon_deg);
    isSmall = area_nm < p.Results.areaMin_nm;

    % Filter out small polygons
    out_lat_deg(isSmall) = [];
    out_lon_deg(isSmall) = [];
    area_nm(isSmall) = [];
end

function [buff_lat_deg, buff_lon_deg, pgons] = BufferBoundUnion(in_lat_deg, in_lon_deg, p)
    % Preallocate
    pgons(size(in_lat_deg, 1), 1) = polyshape();

    % Iterate
    for ii = 1:1:numel(in_lat_deg)
        % Reduce number of points
        % [latReduce_deg,lonReduce_deg] = reducem(latIn_deg{i},lonIn_deg{i});
        k = boundary(in_lat_deg{ii}, in_lon_deg{ii}, p.Results.shrink);

        % Calculate buffer
        [latb_deg, lonb_deg] = bufferm(in_lat_deg{ii}(k), in_lon_deg{ii}(k), p.Results.bufwidth_deg, 'outPlusInterior');

        isBLat = latb_deg >= p.Results.boundsLat_deg(1) & latb_deg <= p.Results.boundsLat_deg(2);
        isBLon = lonb_deg >= p.Results.boundsLon_deg(1) & lonb_deg <= p.Results.boundsLon_deg(2);
        isInBound = isBLat & isBLon;

        % Create polyshape
        pgons(ii) = polyshape(lonb_deg(isInBound), latb_deg(isInBound));

        % Display status
        if p.Results.isVerbose
            fprintf('ReduceBuff: %i / %i\n', ii, numel(in_lat_deg));
        end
    end

    % Union and remove holes to minimize number of polygons
    pgons = simplify(rmholes(union(pgons)));

    % Split polygon to create output
    [buff_lat_deg, buff_lon_deg] = polysplit(pgons.Vertices(:, 2), pgons.Vertices(:, 1));

    % Close polygon
    buff_lat_deg = cellfun(@(x)([x; x(1); nan]), buff_lat_deg, 'uni', false);
    buff_lon_deg = cellfun(@(x)([x; x(1); nan]), buff_lon_deg, 'uni', false);
end

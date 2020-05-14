function [isGood,T_initial] = sample2track(parameters_filename,initial_filename,transition_filename,varargin)

p = inputParser;

% Required
addRequired(p,'parameters_filename');
addRequired(p,'initial_filename');
addRequired(p,'transition_filename');

% Optional
addOptional(p,'num_max_tracks',10000,@isnumeric);

% Optional - Output Directory
addOptional(p,'out_dir_parent',[getenv('AEM_DIR_BAYES') filesep 'output' filesep 'tracks']);

% Optional - Initial
% These need to exactly match parameters.labels_initial
% Note that not all models may have these variables / labels
addOptional(p,'label_initial_geographic','"G"');
addOptional(p,'label_initial_airspace','"A"');
addOptional(p,'label_initial_altitude','"L"');
addOptional(p,'label_initial_speed','"v"');
addOptional(p,'label_initial_acceleration','"\dot v"');
addOptional(p,'label_initial_vertrate','"\dot h"');
addOptional(p,'label_initial_turnrate','"\dot \psi" ');

% Optional - Transition
% These need to exactly match parameters.labels_transition
% Note that not all models may have these variables / labels
addOptional(p,'label_transition_speed',"\dot v(t+1)");
addOptional(p,'label_transition_altitude',"\dot h(t+1)");
addOptional(p,'label_transition_heading',"\dot \psi(t+1)" );

% Optional - Rejection Sampling
addOptional(p,'min_altitude_ft',0, @isnumeric);

% Optional
addOptional(p,'rng_seed',42,@isnumeric); % Random seed
addOptional(p,'isPlot',false,@islogical);

% Parse
parse(p,parameters_filename,initial_filename,transition_filename,varargin{:});

%% Set random seed
rng(p.Results.rng_seed);

%% Load files
% Parameters
parameters = em_read(parameters_filename);

% Initial
T_initial = readtable(initial_filename,'Delimiter',' ','HeaderLines',1,'EndOfLine','\n');
T_initial.Properties.VariableNames = [{'id'}; parameters.labels_initial];

% Transition
T_transition = readtable(transition_filename,'Delimiter',' ','HeaderLines',1,'EndOfLine','\n');
T_transition.Properties.VariableNames = [{'id'}; {'t'}; parameters.labels_transition(parameters.temporal_map(:,2))];

%% Filter to desired number tracks
if size(T_initial,1) > p.Results.num_max_tracks
    T_initial = T_initial(randperm(size(T_initial,1),p.Results.num_max_tracks),:);
end
num_tracks = size(T_initial,1);

%% Find column indicies
% Initial
idx_initial_geographic = find(contains(T_initial.Properties.VariableNames,p.Results.label_initial_geographic));
idx_initial_airspace = find(contains(T_initial.Properties.VariableNames,p.Results.label_initial_airspace));
idx_initial_altitude = find(contains(T_initial.Properties.VariableNames,p.Results.label_initial_altitude));
idx_initial_speed = find(contains(T_initial.Properties.VariableNames,p.Results.label_initial_speed));
idx_initial_acceleration = find(contains(T_initial.Properties.VariableNames,p.Results.label_initial_acceleration));
idx_initial_vertrate = find(contains(T_initial.Properties.VariableNames,p.Results.label_initial_vertrate));

% Updates / transition
idx_update_acc = find(contains(T_transition.Properties.VariableNames,p.Results.label_transition_speed));
idx_update_vertrate = find(contains(T_transition.Properties.VariableNames,p.Results.label_transition_altitude));
idx_update_turnrate = find(contains(T_transition.Properties.VariableNames,p.Results.label_transition_heading));

% Bounds
idx_bound_alt = find(contains(parameters.labels_initial,p.Results.label_initial_altitude));
idx_bound_speed = find(contains(parameters.labels_initial,p.Results.label_initial_speed));

%% For rejection sampling and load balancing
% Altitude bound
min_alt = parameters.boundaries{idx_bound_alt}(1);
max_alt = parameters.boundaries{idx_bound_alt}(end);

% Airspeed bound
min_speed = parameters.boundaries{idx_bound_speed}(1);
max_speed = parameters.boundaries{idx_bound_speed}(end);

%% Parse parameters_filename
pfn = strsplit(parameters_filename,filesep);

% Check if model is one of the many unconventional models
is_unconv = any(strcmp(strrep(pfn{end},'.txt',''),{'balloon_v1p2','blimp_v1','fai1_v1','fai5_v1','glider_v1p2','paraglider_v1p2','paramotor_v1','skydiving_v1','weatherballoon_v1'}));

%% The position output is in feet, so we need to determine the appropriate unit conversions
if is_unconv
    % https://www.ll.mit.edu/sites/default/files/publication/doc/2018-12/Edwards_2009_ATC-348_WW-18098.pdf
    ur_speed = unitsratio('ft','nm') / 3600; % Knots to feet per second
    ur_vertrate = unitsratio('ft','ft') / 60; % Feet per minute to feet per second
    ur_heading = 1; % Degrees per second to degrees per second
    dt_s = 1; % Sampled timestep of model
else
    switch strrep(pfn{end},'.txt','')
        case 'uncor_v2p2'
            ur_speed = unitsratio('ft','nm') / 3600; % Knots to feet per second
            ur_vertrate = unitsratio('ft','ft') / 60; % Feet per minute to feet per second
            ur_heading = 1; % Degrees per second to degrees per second
            dt_s = 1; % Sampled timestep of model
    end
end

%% Apply unit conversions
% Initial
T_initial.(idx_initial_speed) = T_initial.(idx_initial_speed) * ur_speed;
T_initial.(idx_initial_acceleration) = T_initial.(idx_initial_acceleration) * ur_speed;
T_initial.(idx_initial_vertrate) = T_initial.(idx_initial_vertrate) * ur_vertrate;

% Transition
T_transition.(idx_update_vertrate) = T_transition.(idx_update_vertrate) * ur_vertrate;
T_transition.(idx_update_acc) = T_transition.(idx_update_acc) * ur_speed;
T_transition.(idx_update_turnrate) = T_transition.(idx_update_turnrate) * ur_heading;

% Bounds
min_speed = min_speed * ur_speed;
max_speed = max_speed * ur_speed;

%% Determine if variable exists
is_geographic = ~isempty(idx_initial_geographic);
is_airspace = ~isempty(idx_initial_airspace);

%% Create parent output directories
% Parent
mkdir(p.Results.out_dir_parent);

% Subdirectories
if is_unconv
    L = (min_alt:1e2:max_alt+1e2)';
    for i=1:1:size(L,1)
        mkdir([p.Results.out_dir_parent filesep sprintf('%ift',L(i,1))]);
    end
    fprintf('Generated %i directories\n',size(L,1));
else
    switch strrep(pfn{end},'.txt','')
        case 'uncor_v2p2'
            G = unique(T_initial.(idx_initial_geographic));
            A = unique(T_initial.(idx_initial_airspace));
            L = (min_alt:1e2:max_alt+1e2)';
            GAL = combvec(G',A',L')';
            for i=1:1:size(GAL,1)
                mkdir([p.Results.out_dir_parent filesep sprintf('G%i',GAL(i,1)) filesep sprintf('A%i',GAL(i,2)) filesep sprintf('%ift',GAL(i,3))]);
            end
            fprintf('Generated %i directories\n',size(GAL,1));
    end
end

%% Iterate
isGood = false(num_tracks,1);
for i=1:1:num_tracks
    % Set initial position
    time_s = 0;
    x_ft = 0;
    y_ft = 0;
    z_ft = T_initial{i,idx_initial_altitude};
    speed_fps = T_initial{i,idx_initial_speed};
    heading_deg = 0;
    
    % Filter transition for the ith id
    i_updates = T_transition(T_transition.id == T_initial.id(i),:);
    max_time_s = size(i_updates,1);
    
    % Iterate over time
    pInd=length(time_s);
    cInd = 1;
    while time_s(end) < max_time_s
        cInd=pInd+1;
        time_s(cInd) = time_s(pInd)+1;
        
        % Get updates
        update_vertrate = i_updates{pInd,idx_update_vertrate};
        update_acc = i_updates{pInd,idx_update_acc};
        update_turnrate = i_updates{pInd,idx_update_turnrate};
        
        % Apply Updates
        z_ft(cInd) = z_ft(pInd) + update_vertrate;
        speed_fps(cInd) = speed_fps(pInd) + update_acc;
        heading_deg(cInd) = heading_deg(pInd) + update_turnrate;
        
        x_ft(cInd) = x_ft(pInd) + speed_fps(pInd) * cosd(heading_deg(pInd));
        y_ft(cInd) = y_ft(pInd) + speed_fps(pInd) * sind(heading_deg(pInd));
        
        % Update counter
        pInd=cInd;
    end
    
    % Plot
    if p.Results.isPlot
        figure(i);
        plot3(x_ft,y_ft,z_ft,'-*','Color','b','MarkerSize',2); hold on
        plot3(x_ft(1),y_ft(1),z_ft(1),'s','Color','r','MarkerSize',10); hold off
        legend('Track','Start'); xlabel('ft'); ylabel('ft'); zlabel('ft');
        grid on;
    end
    
    % Determine if track hits the ground
    is_cfit = false;
    if any(z_ft < 0); is_cfit = true; end;
    
    % Rejection Sampling - Speed
    is_reject_speed = any(speed_fps <= min_speed | speed_fps >= max_speed);
    
    % Determine if track is good
    isGood(i) = ~is_cfit & ~is_reject_speed;
    
    % Only write to file if no CFIT
    % For load balancing, create subdirectories on model variables
    if isGood(i)
        % Create filename
        out_name = sprintf('BAYES_t%i_id%i_alt%i_speed%i.csv',max_time_s,i,round(z_ft(1)),round(speed_fps(1)));
        
        % Subdirectory for geographic variable, if it exists
        out_dir_child = [];
        if is_geographic
            out_dir_child = sprintf('G%i',T_initial.(idx_initial_geographic)(i));
        end
        
        % Subdirectory for airspace class variable, if it exists
        if is_airspace
            out_dir_child = [out_dir_child filesep sprintf('A%i',T_initial.(idx_initial_airspace)(i))];
        end
        
        % Subdirectory for initial altitude, always use
        if z_ft(1) >= 10000
            out_dir_alt =  round(z_ft(1),3,'significant');
        else
            if z_ft(1) >= 1000
                out_dir_alt =  round(z_ft(1),2,'significant');
            else
                out_dir_alt =  round(z_ft(1),1,'significant');
            end
            if z_ft(1) < 100
                if z_ft(1) >= 50
                    out_dir_alt = 100;
                else
                    out_dir_alt = 0;
                end
            end
        end
        if isempty(out_dir_child)
            out_dir_child = sprintf('%ift',out_dir_alt);
        else
            out_dir_child = [out_dir_child filesep sprintf('%ift',out_dir_alt)];
        end
        
        % Create output directory
        out_dir = [p.Results.out_dir_parent filesep out_dir_child];
        
        % Write to file
        fileId = fopen([out_dir filesep out_name],'w+','native','UTF-8');
        if fileId ~= -1
            fprintf(fileId,'time_s,x_ft,y_ft,z_ft\n');
            fprintf(fileId,'%i,%0.0f,%0.0f,%0.0f\n',[time_s;x_ft;y_ft;z_ft]);
            fclose(fileId);
        else
            warning('sample2tracK:fileid','Cant open %s\n',[out_dir filesep out_name]);
        end
    else
        fprintf('Reject i=%i, CFIT = %i, v = [%0.3f, %0.3f]\n',i,is_cfit,min(speed_fps),max(speed_fps));
    end
end
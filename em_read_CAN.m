% Copyright (c) 2023 Carleton University and National Research Council Canada

function [p] = em_read_CAN(file_name)
load(file_name)

% Set up data for initial distribution
p.labels_initial {1,1} = '"A"';
p.labels_initial {2,1} = '"L"';
p.labels_initial {3,1} = '"v"';
p.labels_initial {4,1} = '"\dot v"';
p.labels_initial {5,1} = '"\dot h"';
p.labels_initial {6,1} = '"\dot \psi"';
p.n_initial = size(DAG_Initial,1);
p.G_initial = logical(DAG_Initial);
for i = 1:size(N_initial,1)
    p.r_initial(i,1) = size(N_initial{i,1},1);
end
p.N_initial=N_initial;
% Set up data for transition distribution
p.labels_transition {1,1} = '"A"';
p.labels_transition {2,1} = '"L"';
p.labels_transition {3,1} = '"v"';
p.labels_transition {4,1} = '"\dot v(t)"';
p.labels_transition {5,1} = '"\dot h(t)"';
p.labels_transition {6,1} = '"\dot \psi(t)"';
p.labels_transition {7,1} = '"\dot v(t+1)"';
p.labels_transition {8,1} = '"\dot h(t+1)"';
p.labels_transition {9,1} = '"\dot \psi(t+1)"';
p.n_transition = size(DAG_Transition,1);
p.G_transition = logical(DAG_Transition);
p.r_transition(1:size(N_initial,1),1) = p.r_initial;
for i = size(N_initial,1)+1:size(N_transition,1)
    p.r_transition(i,1) = size(N_transition{i,1},1);
end
p.N_transition = N_transition;
p.boundaries{1,1} = [];
p.boundaries{1,2} = Cut_Points{5,2}';
p.boundaries{1,3} = Cut_Points{4,2}';
p.boundaries{1,4} = (Cut_Points{1,2}/100)';
p.boundaries{1,5} = (Cut_Points{2,2})';
p.boundaries{1,6} = (Cut_Points{3,2}/100)';
p.resample_rates = resample_rate;
p.temporal_map = [4,7;5,8;6,9];
p.zero_bins{1,1}=[];
p.zero_bins{1,2}=[];
p.zero_bins{1,3}=[];
p.zero_bins{1,4}=find(Cut_Points{1,2}(1:end-1) <= 0 & Cut_Points{1,2}(2:end) >= 0, 1);
p.zero_bins{1,5}=find(Cut_Points{2,2}(1:end-1) <= 0 & Cut_Points{2,2}(2:end) >= 0, 1);
p.zero_bins{1,6}=find(Cut_Points{3,2}(1:end-1) <= 0 & Cut_Points{3,2}(2:end) >= 0, 1);

%% Complete cutpoints and bounds
bounds_initial = zeros(p.n_initial,2);
cutpoints_initial = cell(1, p.n_initial);

for i = 1:p.n_initial
    if isempty(p.boundaries{i})
        n = size(p.N_initial{i},1);
        cutpoints_initial{i} = 2:n;
        bounds_initial(i,:) = [1,n+1];
    else
        bounds_initial(i,:) = [min(p.boundaries{i}), max(p.boundaries{i})];
        cutpoints_initial{i} = p.boundaries{i}(2:end-1)';
    end
end

p.bounds_initial = bounds_initial;
p.cutpoints_initial = cutpoints_initial;

end

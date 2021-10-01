function [fig1, fig2, fig3] = plotTerminalMetadata(obj,T,binSrc)
% Copyright 2008 - 2021, MIT Lincoln Laboratory
% SPDX-License-Identifier: BSD-2-Clause
% Plots metadata of generated terminal encounters

% Input handling
if nargin < 3
    binSrc = 'geometry';
end

% Inputs hardcode
colors = [ [0,0.45,0.74] ; [0.85,0.33,0.1] ];
ownColor = colors(1,:);
intColor = colors(2,:);

ownStyle = {'FaceColor','none','EdgeColor',ownColor,'LineStyle','-','LineWidth',1.5,'DisplayName','Ownship'};
intStyle = {'FaceColor','none','EdgeColor',intColor,'LineStyle',':','LineWidth',1.5,'DisplayName','Intruder'};

% Source bins for either geometry or trajectory model
switch binSrc
    case 'geometry'
        % Distance
        bOwnDist = obj.boundaries{strcmp(strrep(obj.labels_initial,'"',''),'own_distance')};
        bIntDist = obj.boundaries{strcmp(strrep(obj.labels_initial,'"',''),'int_distance')};
        
        % Altitude
        bOwnAlt = obj.boundaries{strcmp(strrep(obj.labels_initial,'"',''),'own_alt')};
        bIntAlt = obj.boundaries{strcmp(strrep(obj.labels_initial,'"',''),'int_alt')};
        
        % Speed
        bOwnSpd = obj.boundaries{strcmp(strrep(obj.labels_initial,'"',''),'own_speed')};
        bIntSpd = obj.boundaries{strcmp(strrep(obj.labels_initial,'"',''),'int_speed')};
        
    case 'trajectory'
        % Distance
        bOwnDist = obj.mdlFwd1_1.boundaries{strcmp(strrep(obj.mdlFwd1_1.labels_initial,'"',''),'distance')};
        bIntDist = obj.mdlFwd2_1.boundaries{strcmp(strrep(obj.mdlFwd2_1.labels_initial,'"',''),'distance')};
        
        % Altitude
        bOwnAlt = obj.mdlFwd1_1.boundaries{strcmp(strrep(obj.mdlFwd1_1.labels_initial,'"',''),'altitude')};
        bIntAlt = obj.mdlFwd2_1.boundaries{strcmp(strrep(obj.mdlFwd2_1.labels_initial,'"',''),'altitude')};
        
        % Speed
        bOwnSpd = obj.mdlFwd1_1.boundaries{strcmp(strrep(obj.mdlFwd1_1.labels_initial,'"',''),'speed')};
        bIntSpd = obj.mdlFwd2_1.boundaries{strcmp(strrep(obj.mdlFwd2_1.labels_initial,'"',''),'speed')};
    otherwise
        error('Unknown binSrc of %s, binSrc can be ''geometry'' or ''trajectory''');
end

% Set bins for calculated variables
maxHmd_ft = round(max(bOwnDist) * 6076.1154855643);
maxVmd_ft = 2525;
bVertRate = 0:300:1800;
bVertRate = bVertRate / 60;

% Airspace class and Intent
fig1 = figure('Name','Airspace Class and Intent');
tiledlayout('flow','Padding','none','TileSpacing','compact');
nexttile;
histogram(categorical(T.airspace_class),'Normalization','probability')
xlabel('Airspace Class'); ylabel('Frequency'); grid on;

nexttile;
heatmap(T,'own_intent','int_intent',...
    'XDisplayData',{-1,1,0},'YDisplayData',{-1,1,0},...
    'XDisplayLabels',{'Landing - straight','Takeoff - straight','Transit'},'YDisplayLabels',{'Landing - any','Takeoff - any','Transit'},...
    'XLabel','Ownship Intent','YLabel','Intruder Intent','Title','',...
    'ColorbarVisible','off');

% Ownship and Intruder
% Create figure
fig2 = figure('Name','Histogram: Terminal Encounters');
tl = tiledlayout('flow','Padding','none','TileSpacing','compact');

% Distance from runway
ax1=nexttile;
histogram(T.own_distance_nm,bOwnDist,'Normalization','probability',ownStyle{:}); hold on;
histogram(T.int_distance_nm,bIntDist,'Normalization','probability',intStyle{:}); hold off;

set(gca,'XTick',bOwnDist,'XTickLabelRotation',45);
xlabel('Nautical miles'); grid on;
title('Distance from runway');
legend('Location','northeast');
if ~all(bOwnDist == bOwnDist)
    warning('Altitude boundaries are different between ownship and intruder, plotting altitude with ownship boundaries');
end

% Altitude
ax2=nexttile;
histogram(T.own_alt_ft,bOwnAlt,'Normalization','probability',ownStyle{:}); hold on;
histogram(T.int_alt_ft,bIntAlt,'Normalization','probability',intStyle{:}); hold off;

set(gca,'XTick',bOwnAlt,'XTickLabelRotation',45);
xlabel('Feet'); grid on;
title('Altitude');
legend('Location','northeast');
if ~all(bOwnAlt == bIntAlt)
    warning('Altitude boundaries are different between ownship and intruder, plotting altitude with ownship boundaries');
end

% Speed
ax3=nexttile;
histogram(T.own_speed_ftps,bOwnSpd,'Normalization','probability',ownStyle{:}); hold on;
histogram(T.int_speed_ftps,bIntSpd,'Normalization','probability',intStyle{:}); hold off;

set(gca,'XTick',bOwnSpd,'XTickLabelRotation',45);
xlabel('Feet per second'); grid on;
title('Speed');
legend('Location','northeast');
if ~all(bOwnSpd == bIntSpd)
    warning('Speed boundaries are different between ownship and intruder, plotting speed with ownship boundaries');
end

% Vertical Rate
ax4=nexttile;
histogram(T.own_vertRate_ftpm/60,bVertRate,'Normalization','probability',ownStyle{:}); hold on;
histogram(T.int_vertRate_ftpm/60,bVertRate,'Normalization','probability',intStyle{:}); hold off;

set(gca,'XTick',bVertRate,'XTickLabelRotation',45);
xlabel('Feet per second');grid on;
title('Vertical rate (magnitude)');
legend('Location','northeast');

linkaxes([ax1,ax2,ax3,ax4],'y')
ylabel(tl,'Frequency','FontWeight','bold','FontSize',14)

% HMD and VMD
% Create figure
fig3 = figure('Name','Contour: HMD and VMD');

% Calculate bin centers
% Assumes bin center is in the middle of edges
edgesX_ft = 0:25:maxHmd_ft;
edgesY_ft = -maxVmd_ft:25:maxVmd_ft;
centersX_ft = edgesX_ft(1:end-1) + diff(edgesX_ft) / 2;
centersY_ft = edgesY_ft(1:end-1) + diff(edgesY_ft) / 2;

% 2D Histogram
[bc,Xedges,Yedges] = histcounts2(T.hmd_ft,T.vmd_ft,centersX_ft,centersY_ft,'Normalization','count');
h = histogram2('XBinEdges',Xedges,'YBinEdges',Yedges,'BinCounts',bc,'Normalization','cdf','DisplayStyle','tile');
z = h.Values';

% Calculate bin centers using output of histcounts2
% Assumes bin center is in the middle of edges
Xcenters = Xedges(1:end-1) + diff(Xedges) / 2;
Ycenters = Yedges(1:end-1) + diff(Yedges) / 2;

% Plot CDF contour
[M,c] = contourf(Xcenters,Ycenters,z,[0 .01 .05 .1 .25 .5 .75 .95],'w-','ShowText','on');
colormap parula; caxis([0 1]); %colorbar; colorbar('Ticks',0:.1:1,'Limits',[0 1]);
clabel(M,c,'Color','w','FontWeight','bold','FontName','Times New Roman');
xlabel('HMD (ft)'); ylabel('VMD (ft)'); grid on;

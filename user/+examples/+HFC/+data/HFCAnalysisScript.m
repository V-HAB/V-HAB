doLoadData  = 1;
doMarinate  = 0;
doPlotData  = 1;

%% Housekeeping
% Uncomment and Run this Section first (only once)

% addr    = pwd;
% addr = [addr,'\..\..\03 Analysis\Matlab Code\'];
% addpath(addr)

% format long
% set(0,'DefaultFigureColor',[1 1 1]);
% set(0,'DefaultLineLineWidth', 2.5);
% set(0,'DefaultAxesFontSize',18);

%% Load Data
if(doLoadData)
fprintf('Loading Data: ')
tic
%% Import COZIR data
sFileID = strrep('+examples/+HFC/+data/April-04-2017-upstrm2.csv','/',filesep);
[UpTime_2,UpCO2_2]  = examples.HFC.data.importCO2file(sFileID,3,1220);
% UpTime_2(1:106) = [];
sFileID = strrep('+examples/+HFC/+data/April-05-2017 - upstrm.csv','/',filesep);
[UpTime_1,UpCO2_1]  = examples.HFC.data.importCO2file(sFileID,3,2060);
sFileID = strrep('+examples/+HFC/+data/April-04-2017-dwnstrm2.csv','/',filesep);
[DnTime_2,DnCO2_2]  = examples.HFC.data.importCO2file(sFileID,3,1217);
% DnTime_2(1:102) = [];
sFileID = strrep('+examples/+HFC/+data/April-05-2017 - dwnstrm.csv','/',filesep);
[DnTime_1,DnCO2_1]  = examples.HFC.data.importCO2file(sFileID,3,2098);
UpTime              = [UpTime_2;UpTime_1];
UpCO2               = [UpCO2_2;UpCO2_1];
DnTime              = [DnTime_2;DnTime_1];
DnCO2               = [DnCO2_2;DnCO2_1];

%% Calculate Errors
UpErr               = 50*ones(size(UpCO2));
UpErr(UpCO2>=1667)  = 0.03.*(UpCO2(UpCO2>=1667));
DnErr               = 50*ones(size(DnCO2));
DnErr(DnCO2>=1667)  = 0.03.*(DnCO2(DnCO2>=1667));

%% Bin Data to Common Time
% Initialize Common Time Array
Time_C  = linspace(min([DnTime;UpTime]),max([DnTime;UpTime]),1200)';
Time_C(end) = [];
dt      = Time_C(2)-Time_C(1);      % Bin Width
fprintf('Bin Width: %5.2f [s]\n',seconds(dt))

% Initialize Data Arrays to size of Common Time
UpCO2_C = nan(length(Time_C)-1,1);  % Concentration     [PPM]
UpCO2_n = nan(length(Time_C)-1,1);  % Number of Data    []
UpCO2_E = nan(length(Time_C)-1,1);  % Measurement Error [PPM]

DnCO2_C = nan(length(Time_C)-1,1);  % Concentration     [PPM]
DnCO2_n = nan(length(Time_C)-1,1);  % Number of Data    []
DnCO2_E = nan(length(Time_C)-1,1);  % Measurement Error [PPM]

for i = 1:length(Time_C)-1
    % Find all indices for Upstream measurements with times in the bin
    iFindUp    = find(and(Time_C(i)<=UpTime,UpTime<=Time_C(i+1)));
    % Average those measurements and assign to data array
    UpCO2_C(i) = mean(UpCO2(iFindUp));
    UpCO2_n(i) = length(iFindUp);
    UpCO2_E(i) = sum(UpErr(iFindUp))/UpCO2_n(i);
   
    % Find all indices for Downstream measurements with times in the bin
    iFindDn    = find(and(Time_C(i)<=DnTime,DnTime<=Time_C(i+1)));
    % Average those measurements and assign to data array
    DnCO2_C(i) = mean(DnCO2(iFindDn));
    DnCO2_n(i) = length(iFindDn);
    DnCO2_E(i) = sum(DnErr(iFindDn))/DnCO2_n(i);
end
Time_C(end) = [];

%% Get rid of Data Gaps
iDelete     = or(UpCO2_n==0,DnCO2_n==0);
Time_C(iDelete)  = [];
UpCO2_C(iDelete) = [];
UpCO2_E(iDelete) = [];
DnCO2_C(iDelete) = [];
DnCO2_E(iDelete) = [];
DnCO2_n(iDelete) = [];
UpCO2_n(iDelete) = [];

if(any([isnan(UpCO2_E);isnan(DnCO2_E)]))
    disp('UH OH!')
end

%% Calculate Delta PPM and Errors
PPM2T   = 3200;
dPPM2T  = 0;
Delta_C = 3200.*(UpCO2_C - DnCO2_C)./UpCO2_C; % Delta PPM Normalized 2 Torr
Delta_E = sqrt(((PPM2T.*DnCO2_C./(UpCO2_C.^2)).^2).*(UpCO2_E.^2)+...
               ((-PPM2T./UpCO2_C).^2).*(DnCO2_E.^2)+...
               ((1-DnCO2_C./UpCO2_C).^2).*(dPPM2T.^2));
% Delta_E = UpCO2_E + DnCO2_E; Old Equation  

%% Load Model Data
sFileID = strrep('+examples/+HFC/+data/AllCharData.mat','/',filesep);
load(sFileID);
% load('..\..\03 Analysis\Matlab Code\AllCharData.mat','HFC_Gas_M');
toc
end

%% Process Data
if(doMarinate)
fprintf('Marinating Data: ')
tic
%% Define Trial Times
% Test Card Times:
[~,iEvent1] = min(abs(Time_C-datetime(2017,4,4,13,34,0)));  % 0.2 SLPM
[~,iEvent2] = min(abs(Time_C-datetime(2017,4,4,14,00,0)));  % 0.3 SLPM
[~,iEvent3] = min(abs(Time_C-datetime(2017,4,4,14,16,0)));  % 0.4 SLPM
[~,iEvent4] = min(abs(Time_C-datetime(2017,4,4,14,29,0)));  % Regen Attmpt

[~,iEvent5] = min(abs(Time_C-datetime(2017,4,5,10,27,0)));  % 0.5 SLPM
[~,iEvent6] = min(abs(Time_C-datetime(2017,4,5,10,45,0)));  % 0.6 SLPM
[~,iEvent7] = min(abs(Time_C-datetime(2017,4,5,11,45,0)));  % Pump 2
[~,iEvent8] = min(abs(Time_C-datetime(2017,4,5,12,00,0)));  % Pump 3
[~,iEvent9] = min(abs(Time_C-datetime(2017,4,5,12,15,0)));  % Pump 4
[~,iEvent10]= min(abs(Time_C-datetime(2017,4,5,12,45,0)));  % Pump 2

%% Gas Flow Rate Trials:
GasFlow     = nan(5,3);
GasErr      = nan(5,3);
% 0.2 SLPM
StartTime   = datetime(2017,4,4,13,37,37);
EndTime     = datetime(2017,4,4,13,51,27);
iStart      = find(abs(Time_C-StartTime)<=seconds(1));
iEnd        = find(abs(Time_C-EndTime)<=seconds(1));
GasFlow(1,:)= [0.2,examples.HFC.data.wmean(Delta_C(iStart:iEnd),UpCO2_n(iStart:iEnd)+...
                   DnCO2_n(iStart:iEnd)),examples.HFC.data.wmean(UpCO2_C(iStart:iEnd),...
                   UpCO2_n(iStart:iEnd))];
GasErr(1,:) = [0.02,sum(Delta_E(iStart:iEnd))/(iEnd-iStart),...
                   sum(UpCO2_E(iStart:iEnd))/(iEnd-iStart)];               

% 0.3 SLPM
StartTime   = datetime(2017,4,4,14,01,30);
EndTime     = datetime(2017,4,4,14,12,49);
iStart      = find(abs(Time_C-StartTime)<=seconds(1));
iEnd        = find(abs(Time_C-EndTime)<=seconds(1));
GasFlow(2,:)= [0.3,examples.HFC.data.wmean(Delta_C(iStart:iEnd),UpCO2_n(iStart:iEnd)+...
                   DnCO2_n(iStart:iEnd)),examples.HFC.data.wmean(UpCO2_C(iStart:iEnd),...
                   UpCO2_n(iStart:iEnd))];
GasErr(2,:) = [0.02,sum(Delta_E(iStart:iEnd))/(iEnd-iStart),...
                   sum(UpCO2_E(iStart:iEnd))/(iEnd-iStart)];     

% 0.4 SLPM
StartTime   = datetime(2017,4,4,14,16,35);
EndTime     = datetime(2017,4,4,14,29,09);
iStart      = find(abs(Time_C-StartTime)<=seconds(1));
iEnd        = find(abs(Time_C-EndTime)<=seconds(1));
GasFlow(3,:)= [0.4,examples.HFC.data.wmean(Delta_C(iStart:iEnd),UpCO2_n(iStart:iEnd)+...
                   DnCO2_n(iStart:iEnd)),examples.HFC.data.wmean(UpCO2_C(iStart:iEnd),...
                   UpCO2_n(iStart:iEnd))];
GasErr(3,:) = [0.02,sum(Delta_E(iStart:iEnd))/(iEnd-iStart),...
                   sum(UpCO2_E(iStart:iEnd))/(iEnd-iStart)];                   

% 0.5 SLPM
StartTime   = datetime(2017,4,5,10,26,53);
EndTime     = datetime(2017,4,5,10,41,58);
iStart      = find(abs(Time_C-StartTime)<=seconds(1));
iEnd        = find(abs(Time_C-EndTime)<=seconds(1));
GasFlow(4,:)= [0.5,examples.HFC.data.wmean(Delta_C(iStart:iEnd),UpCO2_n(iStart:iEnd)+...
                   DnCO2_n(iStart:iEnd)),examples.HFC.data.wmean(UpCO2_C(iStart:iEnd),...
                   UpCO2_n(iStart:iEnd))];
GasErr(4,:) = [0.02,sum(Delta_E(iStart:iEnd))/(iEnd-iStart),...
                   sum(UpCO2_E(iStart:iEnd))/(iEnd-iStart)];                   

% 0.6 SLPM
StartTime   = datetime(2017,4,5,10,44,28);
EndTime     = datetime(2017,4,5,11,02,04);
iStart      = find(abs(Time_C-StartTime)<=seconds(1));
iEnd        = find(abs(Time_C-EndTime)<=seconds(1));
GasFlow(5,:)= [0.6,examples.HFC.data.wmean(Delta_C(iStart:iEnd),UpCO2_n(iStart:iEnd)+...
                   DnCO2_n(iStart:iEnd)),examples.HFC.data.wmean(UpCO2_C(iStart:iEnd),...
                   UpCO2_n(iStart:iEnd))];
GasErr(5,:) = [0.02,sum(Delta_E(iStart:iEnd))/(iEnd-iStart),...
                   sum(UpCO2_E(iStart:iEnd))/(iEnd-iStart)];                   

% Convert DeltaPPM to kg/day
M_CO2       = 44.01;                % Molar Mass CO2    [g/mol]
R           = 8.31446;              % Gas Constant      [J/molK]
P           = 83.6;                 % Pressure in Cont. [kPa]
T           = 23.1;                 % Temp in Cont.     [C]
% V           = 0.5;                  % Volume Flow Rate  [SLPM]
dN          = (P.*1E3)./(R.*(T+273.16)).*GasFlow(:,1).*(GasFlow(:,2)./1E6);
                                    % Mole Change       [Mol/min]
dMmn        = (dN.*M_CO2)./1000;    % Mass Change       [kg/min]
dMhr        = dMmn.*60;             % Mass Change       [kg/hr]
dMdy        = dMhr.*24;             % Mass Change       [kg/day]
GasFlow(:,4)= dMdy;

dNErr       = (P.*1E3)./(R.*(T+273.16)).*GasFlow(:,1).*(GasErr(:,2)./1E6);                                   % Mole Change       [Mol/min]
dMmn        = (dNErr.*M_CO2)./1000; % Mass Change       [kg/min]
dMhr        = dMmn.*60;             % Mass Change       [kg/hr]
dMdy        = dMhr.*24;             % Mass Change       [kg/day]
GasErr(:,4) = dMdy;

%% IL Flow Rate Trials:
ILFlow     = nan(4,3);
ILErr      = nan(4,3);
% Pump Setting: 1
StartTime   = datetime(2017,4,4,13,37,37);
EndTime     = datetime(2017,4,4,13,51,27);
iStart      = find(abs(Time_C-StartTime)<=seconds(1));
iEnd        = find(abs(Time_C-EndTime)<=seconds(1));
PR          = PumpConvert(1,15);    % Pump Rate [mL/min]
ILFlow(1,:) = [PR,wmean(Delta_C(iStart:iEnd),UpCO2_n(iStart:iEnd)+...
                   DnCO2_n(iStart:iEnd)),wmean(UpCO2_C(iStart:iEnd),...
                   UpCO2_n(iStart:iEnd))];
ILErr(1,:)  = [10,sum(Delta_E(iStart:iEnd))/(iEnd-iStart),...
                   sum(UpCO2_E(iStart:iEnd))/(iEnd-iStart)];

% Pump Setting: 2
% StartTime   = datetime(2017,4,5,11,47,19);
% EndTime     = datetime(2017,4,5,11,58,37);
StartTime   = datetime(2017,4,5,12,45,07);
EndTime     = datetime(2017,4,5,12,58,57);
iStart      = find(abs(Time_C-StartTime)<=seconds(1));
iEnd        = find(abs(Time_C-EndTime)<=seconds(1));
PR          = PumpConvert(2,15);    % Pump Rate [mL/min]
ILFlow(2,:) = [PR,wmean(Delta_C(iStart:iEnd),UpCO2_n(iStart:iEnd)+...
                   DnCO2_n(iStart:iEnd)),wmean(UpCO2_C(iStart:iEnd),...
                   UpCO2_n(iStart:iEnd))];
ILErr(2,:)  = [10,sum(Delta_E(iStart:iEnd))/(iEnd-iStart),...
                   sum(UpCO2_E(iStart:iEnd))/(iEnd-iStart)];

% Pump Setting: 3
StartTime   = datetime(2017,4,5,11,59,53);
EndTime     = datetime(2017,4,5,12,14,58);
iStart      = find(abs(Time_C-StartTime)<=seconds(1));
iEnd        = find(abs(Time_C-EndTime)<=seconds(1));
PR          = PumpConvert(3,15);    % Pump Rate [mL/min]
ILFlow(3,:) = [PR,wmean(Delta_C(iStart:iEnd),UpCO2_n(iStart:iEnd)+...
                   DnCO2_n(iStart:iEnd)),wmean(UpCO2_C(iStart:iEnd),...
                   UpCO2_n(iStart:iEnd))];
ILErr(3,:)  = [10,sum(Delta_E(iStart:iEnd))/(iEnd-iStart),...
                   sum(UpCO2_E(iStart:iEnd))/(iEnd-iStart)];
               

% Pump Setting: 4
StartTime   = datetime(2017,4,5,12,16,13);
EndTime     = datetime(2017,4,5,12,33,49);
iStart      = find(abs(Time_C-StartTime)<=seconds(1));
iEnd        = find(abs(Time_C-EndTime)<=seconds(1));
PR          = PumpConvert(4,15);    % Pump Rate [mL/min]
ILFlow(4,:) = [PR,wmean(Delta_C(iStart:iEnd),UpCO2_n(iStart:iEnd)+...
                   DnCO2_n(iStart:iEnd)),wmean(UpCO2_C(iStart:iEnd),...
                   UpCO2_n(iStart:iEnd))];
ILErr(4,:)  = [10,sum(Delta_E(iStart:iEnd))/(iEnd-iStart),...
                   sum(UpCO2_E(iStart:iEnd))/(iEnd-iStart)];
toc

% Convert DeltaPPM to kg/day
V           = 0.2;                  % Volume Flow Rate  [SLPM]
dN          = (P.*1E3)./(R.*(T+273.16)).*V.*(ILFlow(:,2)./1E6);
                                    % Mole Change       [Mol/min]
dMmn        = (dN.*M_CO2)./1000;    % Mass Change       [kg/min]
dMhr        = dMmn.*60;             % Mass Change       [kg/hr]
dMdy        = dMhr.*24;             % Mass Change       [kg/day]
ILFlow(:,4) = dMdy;

dNErr       = (P.*1E3)./(R.*(T+273.16)).*V.*(ILErr(:,2)./1E6);                                   % Mole Change       [Mol/min]
dMmn        = (dNErr.*M_CO2)./1000; % Mass Change       [kg/min]
dMhr        = dMmn.*60;             % Mass Change       [kg/hr]
dMdy        = dMhr.*24;             % Mass Change       [kg/day]
ILErr(:,4)  = dMdy;

%% Convert Model Results
dN          = (P.*1E3)./(R.*(T+273.16)).*HFC_Gas_M(:,1).*(HFC_Gas_M(:,2)./1E6);
                                    % Mole Change       [Mol/min]
dMmn        = (dN.*M_CO2)./1000;    % Mass Change       [kg/min]
dMhr        = dMmn.*60;             % Mass Change       [kg/hr]
dMdy        = dMhr.*24;             % Mass Change       [kg/day]
HFC_Gas_M(:,3)  = dMdy;

%% Fit Gas and IL Data (Outdated)
% [gF,gG,gO]  = fit(GasFlow(:,1),GasFlow(:,4),'a*x^(-1) + b','StartPoint',[0 0]);
% dgF         = diff(confint(gF))/2;
% [iF,iG,iO]  = fit(ILFlow(:,1),ILFlow(:,4),'a*x^(-1) + b','StartPoint',[0 0]);
% diF         = diff(confint(iF))/2;

end

%% Plot All CO2 Data
if(doPlotData)
fprintf('Plotting Figures: \n')
PlotMax     = 6000;
PlotMin     = -500;

%% Plot Experiment Time Record
h1 = figure('units','normalized','position',[0 0 1 1]);
title('COZIR Sensor Measurements for HFC Characterization - Gas Flow')
axis off

a1 = axes('Position',[0.1,0.1,0.4,0.8]);
grid on
hold on
plot(Time_C,UpCO2_C,'b')
plot(Time_C,DnCO2_C,'r')
plot(Time_C,Delta_C,'g')
plot([Time_C(iEvent1) Time_C(iEvent1)],[PlotMin PlotMax],'--k')
plot([Time_C(iEvent2) Time_C(iEvent2)],[PlotMin PlotMax],'--k')
plot([Time_C(iEvent3) Time_C(iEvent3)],[PlotMin PlotMax],'--k')
plot([Time_C(iEvent4) Time_C(iEvent4)],[PlotMin PlotMax],'--k')
set(a1,'XLim',datenum([datetime(2017,4,4,13,00,0) max([DnTime_2;UpTime_2])]));
set(a1,'YLim',[PlotMin PlotMax],'YTick',PlotMin:500:PlotMax);

a2 = axes('Position',[0.5,0.1,0.4,0.8]);
grid on
hold on
plot(Time_C,UpCO2_C,'b')
plot(Time_C,DnCO2_C,'r')
plot(Time_C,Delta_C,'g')
plot([Time_C(iEvent5) Time_C(iEvent5)],[PlotMin PlotMax],'--k')
plot([Time_C(iEvent6) Time_C(iEvent6)],[PlotMin PlotMax],'--k')
plot([Time_C(iEvent7) Time_C(iEvent7)],[PlotMin PlotMax],'--k')
plot([Time_C(iEvent8) Time_C(iEvent8)],[PlotMin PlotMax],'--k')
plot([Time_C(iEvent9) Time_C(iEvent9)],[PlotMin PlotMax],'--k')
plot([Time_C(iEvent10) Time_C(iEvent10)],[PlotMin PlotMax],'--k')
set(a2,'XLim',datenum([min([DnTime_1;UpTime_1]) max([DnTime_1;UpTime_1])]));
set(a2,'YLim',[PlotMin PlotMax],'YTick',PlotMin:500:PlotMax,'YTickLabel', []);

legend(a2,'Upstream','Downstream','\Deltappm across contactor')
xlabel(a2,'Time')
xlabel(a1,'Time')
ylabel(a1,'CO2 Content [PPM]')

%% Plot Gas Flow Trials
h2 = figure('units','normalized','position',[0 0 0.6 0.6]);
hold on
errorbar(GasFlow(:,1),GasFlow(:,2),GasErr(:,2),'.k','MarkerSize',15)
% set(gca,'XLim',[0 0.8],'YLim',[0 2])
plot(HFC_Gas_M(:,1),HFC_Gas_M(:,2),'r')
grid on
title('HFC CO_2 Uptake vs. Gas Flow Rate')
ylabel('CO_2 Uptake [\Delta PPM]')
xlabel('Gas Flow Rate [SLPM]')
legend('Experiment','Model') 
% legend off
% text(0.6,1.6,sprintf(['Fit:  f(x) = a/x + b \n',...
%                       'a:   %5.3f +/- %5.3f\n',...
%                       'b:   %5.3f +/- %5.3f\n',...
%                       'RMSE: %5.3f'],gF.a,dgF(1),gF.b,dgF(2),gG.rmse),...
%                       'FontSize',16)

%% Plot IL Flow Trials
h3 = figure('units','normalized','position',[0 0 0.6 0.6]);
hold on
errorbar(ILFlow(:,1),ILFlow(:,4),ILErr(:,4),'.k','MarkerSize',15)
set(gca,'YLim',[0 2]) % 'XLim',[0 5]
% plot(iF)
grid on
title('HFC CO_2 Uptake vs. IL Flow Rate')
ylabel('CO_2 Uptake [g/day]')
xlabel('IL Flow Rate [mL/min]')
legend off % legend('Experiment','Exp Fit')
% text(350,1.6,sprintf(['Fit: f(x) = a/x + b \n',...
%                       'a:   %5.3f +/- %5.3f\n',...
%                       'b:   %5.3f +/- %5.3f\n',...
%                       'RMSE: %5.3f'],iF.a,diF(1),iF.b,diF(2),iG.rmse),...
%                       'FontSize',16)
end

%% Save Data
% HFC_Time    = Time_C;
% HFC_Delta   = Delta_C;
% HFC_Delta_E = Delta_E;
% HFC_Up      = UpCO2_C;
% HFC_Up_E    = UpCO2_E;
% HFC_Dn      = DnCO2_C;
% HFC_Dn_E    = DnCO2_E;
% HFC_Gas     = GasFlow;
% HFC_Gas_E   = GasErr;
% HFC_IL      = ILFlow;
% HFC_IL_E    = ILErr;
% 
% save('..\..\03 Analysis\Matlab Code\AllCharData.mat','HFC_Time',...
%      'HFC_Delta','HFC_Delta_E','HFC_Up','HFC_Up_E','HFC_Dn',...
%      'HFC_Dn_E','HFC_Gas','HFC_Gas_E','HFC_IL','HFC_IL_E','-append');

% Delete Variable With this:
% tmp=rmfield(load('AllCharData.mat'),'test');
% save('AllCharData.mat','-struct','tmp')

% Old Save Script
% HFC_Gas_M   = gF;
% HFC_Gas_GOF = gG;
% HFC_IL_M    = iF;
% HFC_IL_GOF  = iG;
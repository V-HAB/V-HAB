%Import COZIR data
[UpTime_2,UpCO2_2] = hojo.ILCO2.importCO2file('April-04-2017-upstrm2.csv',3,1220);
[UpTime_1,UpCO2_1] = hojo.ILCO2.importCO2file('April-05-2017 - upstrm.csv',3,2060);
[DnTime_2,DnCO2_2] = hojo.ILCO2.importCO2file('April-04-2017-dwnstrm2.csv',3,1217);
[DnTime_1,DnCO2_1] = hojo.ILCO2.importCO2file('April-05-2017 - dwnstrm.csv',3,2098);
UpTime = [UpTime_2;UpTime_1];
UpCO2  = [UpCO2_2;UpCO2_1];
DnTime = [DnTime_2;DnTime_1];
DnCO2  = [DnCO2_2;DnCO2_1];

%Initialize Common Time Array
Time_C  = linspace(min([DnTime;UpTime]),max([DnTime;UpTime]),600)';
Time_C(end) = [];
dt      = Time_C(2)-Time_C(1);      % Bin Width

% Initialize Data Arrays to size of Common Time
UpCO2_C = nan(size(Time_C));
DnCO2_C = nan(size(Time_C));

for i = 1:length(Time_C)-1
    % Find all indices for Upstream measurements with times in the bin
    iFindUp    = find(and(Time_C(i)<=UpTime,UpTime<=Time_C(i+1)));
    % Average those measurements and assign to data array
    UpCO2_C(i) = mean(UpCO2(iFindUp));
   
    % Find all indices for Downstream measurements with times in the bin
    iFindDn    = find(and(Time_C(i)<=DnTime,DnTime<=Time_C(i+1)));
    % Average those measurements and assign to data array
    DnCO2_C(i) = mean(DnCO2(iFindDn));
end

Delta = UpCO2_C - DnCO2_C;

% Plot All CO2 Data
fprintf('Plotting Figures: \n')
%Use this to manually set event times for plotting: Example at 11:10 AM
[~,iEvent1] = min(abs(Time_C-datetime(2017,4,4,13,34,0)));
[~,iEvent2] = min(abs(Time_C-datetime(2017,4,4,14,00,0)));
[~,iEvent3] = min(abs(Time_C-datetime(2017,4,4,14,16,0)));
[~,iEvent4] = min(abs(Time_C-datetime(2017,4,4,14,29,0)));

[~,iEvent5] = min(abs(Time_C-datetime(2017,4,5,10,27,0)));
[~,iEvent6] = min(abs(Time_C-datetime(2017,4,5,11,03,0)));
[~,iEvent7] = min(abs(Time_C-datetime(2017,4,5,11,45,0)));
[~,iEvent8] = min(abs(Time_C-datetime(2017,4,5,12,00,0)));
[~,iEvent9] = min(abs(Time_C-datetime(2017,4,5,12,15,0)));
[~,iEvent10]= min(abs(Time_C-datetime(2017,4,5,12,45,0)));

PlotMax     = 6000;
PlotMin     = -500;

% Plot
set(0,'DefaultLineLineWidth', 1.6);
h1 = figure('units','normalized','position',[0 0 1 1]);
title('COZIR Sensor Measurements for HFC Characterization - Gas Flow')
axis off

a1 = axes('Position',[0.1,0.1,0.4,0.8]);
grid on
hold on
plot(Time_C,UpCO2_C,'b')
plot(Time_C,DnCO2_C,'r')
plot(Time_C,Delta,'g')
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
plot(Time_C,Delta,'g')
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

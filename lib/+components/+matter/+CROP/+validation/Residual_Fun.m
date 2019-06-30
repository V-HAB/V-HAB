function [ f ] = Residual_Fun( afPmr_Estimate )
%This function is used to create the residual function for the data fitting
%process as is described in section 4.3.2 in the thesis. 

% Load the experimental data from the data file "Data_Experiment.mat"
sFullpath = mfilename('fullpath');
[sFile,~,~] = fileparts(sFullpath);
load([sFile '\Data_Experiment.mat']);

% Execute the simulation for each data series (from 3.5% to 100%) and
% calculate the residuals for each data series
for sSeries = ['C' 'H' 'I' 'D' 'E' 'F']
    % Set parameter in each data series
    suyi.CROP.tools.Set_Parameter_in_Fitting(afPmr_Estimate, sSeries);
    
    % Execute the simulation for each data series
    oLastSimObj = vhab.exec('suyi.CROP.setup');
    
    % Get the simulation results from the log object "oLogger"
    oLogger = oLastSimObj.toMonitors.oLogger;
    
    % The molar mass array, the volume of the sequences of reactants in the
    % matter table
    afMolMass  = oLastSimObj.oSimulationContainer.oMT.afMolarMass;
    fVolume_Tank = 30;
    tiN2I      = oLastSimObj.oSimulationContainer.oMT.tiN2I;
    
    % The time array in day
    afTime_Series = oLogger.afTime./(3600*24);
    
    [~, aiNr_DataSet] = suyi.CROP.tools.Settings_DataSeries_in_Fitting(sSeries);
    tTestData = Data_Modified.(sSeries);
    
    % The experimental data of NH4OH, HNO2, HNO3 and the pH value
    afTestData_NH4OH = suyi.CROP.tools.data_zero_filter(tTestData.b(:,aiNr_DataSet)./1000);
    afTestData_HNO2 = suyi.CROP.tools.data_zero_filter(tTestData.c(:,aiNr_DataSet)./1000);
    afTestData_HNO3 = suyi.CROP.tools.data_zero_filter(tTestData.d(:,aiNr_DataSet)./1000);
    afTestData_pH = suyi.CROP.tools.data_zero_filter(tTestData.PH(:,aiNr_DataSet));
    
    % Get the simulation results of NH4OH, HNO2, HNO3 and the pH value from
    % the log object
    afSimData_NH4OH = suyi.CROP.tools.Pick_Sim_Data(tTestData.b(:,1),...
        afTime_Series, oLogger.mfLog(:,13)./(afMolMass(tiN2I.NH4OH)*fVolume_Tank),afTestData_NH4OH);
    afSimData_HNO2 = suyi.CROP.tools.Pick_Sim_Data(tTestData.c(:,1),...
        afTime_Series, oLogger.mfLog(:,16)./(afMolMass(tiN2I.HNO2)*fVolume_Tank),afTestData_HNO2);
    afSimData_HNO3 = suyi.CROP.tools.Pick_Sim_Data(tTestData.d(:,1),...
        afTime_Series, oLogger.mfLog(:,17)./(afMolMass(tiN2I.HNO3)*fVolume_Tank),afTestData_HNO3);
    afSimData_pH = suyi.CROP.tools.Pick_Sim_Data(tTestData.PH(:,1),...
        afTime_Series, oLogger.mfLog(:,18),afTestData_pH);
    
    % Residuals of NH4OH, HNO2, HNO3 and the pH value
    afDiff_NH4OH = afSimData_NH4OH - afTestData_NH4OH;
    afDiff_HNO2 = afSimData_HNO2 - afTestData_HNO2;
    afDiff_HNO3 = afSimData_HNO3 - afTestData_HNO3;
    afDiff_pH = 0.01.*(afSimData_pH - afTestData_pH); % The residual of pH value is weighted by 0.01   
    
    % Integration of the residuals of a data series
    afResiduals.(sSeries)= [afDiff_NH4OH; afDiff_HNO2; afDiff_HNO3; afDiff_pH];
end

% Integration of the residuals of all data series
f = [afResiduals.C; afResiduals.H; afResiduals.I; afResiduals.D; afResiduals.E; afResiduals.F];
end


classdef setup < simulation.infrastructure
    %SETUP This class is used to setup a simulation
    %   There should always be a setup file present for each project. It is
    %   used for the following:
    %   - instantiate the root object
    %   - register branches to their appropriate solvers
    %   - determine which items are logged
    %   - set the simulation duration
    %   - provide methods for plotting the results
    %
    % if you want to change the cell numbers for the model use:
    % containers.Map({'tInitialization'},{struct('Zeolite13x', struct('iCellNumber', 10), 'Sylobead', struct('iCellNumber', 10), 'Zeolite5A', struct('iCellNumber', 10))})
    
    properties
    end
    
    methods
        function this = setup(ptConfigParams, tSolverParams, ttMonitorConfig, fSimTime) % Constructor function
            
            ttMonitorConfig.oTimeStepObserver = struct('sClass', 'simulation.monitors.timestepObserver', 'cParams', {{ 0 }});
            
            this@simulation.infrastructure('Test_CDRA', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            % Creating the root object
            examples.CDRA.systems.Example(this.oSimulationContainer, 'Example');

            %% Simulation length
            % Stop when specific time in simulation is reached or after 
            % specific amount of ticks (bUseTime true/false).
            if nargin < 4 || isempty(fSimTime)
                this.fSimTime = 20000;
            else 
                this.fSimTime = fSimTime;
            end
        end
        
        function configureMonitors(this)
            
            %% Logging
            oLog = this.toMonitors.oLogger;
            
            oLog.addValue('Example:s:Cabin.toPhases.CabinAir', 'rRelHumidity',              '-',    'Relative Humidity Cabin');
            oLog.addValue('Example:s:Cabin.toPhases.CabinAir', 'afPP(this.oMT.tiN2I.CO2)',  'Pa',   'Partial Pressure CO2');
            oLog.addValue('Example:s:Cabin.toPhases.CabinAir', 'fTemperature',              'K',    'Temperature Atmosphere');
            
            oLog.addValue('Example:c:CCAA:s:CHX.toPhases.CHX_PhaseIn',      'fTemperature',                             'K',    'Temperature CHX');
            oLog.addValue('Example:c:CCAA:s:CHX.toPhases.CHX_PhaseIn',      'this.fMass * this.fMassToPressure',        'Pa',   'Pressure CHX');
            oLog.addValue('Example:c:CCAA:s:TCCV.toPhases.TCCV_PhaseGas',  	'fTemperature',                             'K',    'Temperature TCCV');
            oLog.addValue('Example:c:CCAA:s:TCCV.toPhases.TCCV_PhaseGas',  	'this.fMass * this.fMassToPressure',    	'Pa',   'Pressure TCCV');
            oLog.addValue('Example:c:CCAA:s:TCCV.toPhases.TCCV_PhaseGas',  	'afPP(this.oMT.tiN2I.H2O)',                 'Pa',   'Partial Pressure H2O TCCV');
            oLog.addValue('Example:c:CCAA:s:TCCV.toPhases.TCCV_PhaseGas',  	'afPP(this.oMT.tiN2I.CO2)',                 'Pa',   'Partial Pressure CO2 TCCV');
            oLog.addValue('Example:c:CCAA:s:CHX.toProcsP2P.CondensingHX',   'fFlowRate',                                'kg/s', 'Condensate Flowrate CHX');
            
            iCellNumber13x = this.oSimulationContainer.toChildren.Example.toChildren.CDRA.tGeometry.Zeolite13x.iCellNumber;
            iCellNumberSylobead = this.oSimulationContainer.toChildren.Example.toChildren.CDRA.tGeometry.Sylobead.iCellNumber;
            iCellNumber5A = this.oSimulationContainer.toChildren.Example.toChildren.CDRA.tGeometry.Zeolite5A.iCellNumber;
            miCellNumber = [iCellNumberSylobead, iCellNumber13x, iCellNumber5A];
            csType = {'Sylobead_', 'Zeolite13x_', 'Zeolite5A_'};
            for iType = 1:3
                for iBed = 1:2
                    for iCell = 1:miCellNumber(iType)
                        oLog.addValue(['Example:c:CDRA:s:',csType{iType}, num2str(iBed),'.toPhases.Absorber_',num2str(iCell)],  'afMass(this.oMT.tiN2I.CO2)',   'kg',   ['Partial Mass CO2 ', csType{iType}, num2str(iBed),' Cell ',num2str(iCell)]);
                        oLog.addValue(['Example:c:CDRA:s:',csType{iType}, num2str(iBed),'.toPhases.Absorber_',num2str(iCell)],  'afMass(this.oMT.tiN2I.H2O)',   'kg',   ['Partial Mass H2O ', csType{iType}, num2str(iBed),' Cell ',num2str(iCell)]);
                    end   
                end
            end
            
            oLog.addValue('Example.toStores.Cabin.toProcsP2P.CrewCO2',       'fFlowRate',  'kg/s', 'CO2 Production');
            
            % CDRA In
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_Air_In_1.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)', 'kg/s', 'CDRA CO2 Inlet Flow 1');
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_Air_In_2.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)', 'kg/s', 'CDRA CO2 Inlet Flow 2');
            
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_Air_In_1.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)', 'kg/s', 'CDRA H2O Inlet Flow 1');
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_Air_In_2.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)', 'kg/s', 'CDRA H2O Inlet Flow 2');
            
            % CDRA Out
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_Air_Out_1.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)', 'kg/s', 'CDRA CO2 Outlet Flow 1');
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_Air_Out_2.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)', 'kg/s', 'CDRA CO2 Outlet Flow 2');
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_AirSafe_1.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)', 'kg/s', 'CDRA CO2 Outlet Flow AirSafe 1');
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_AirSafe_2.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)', 'kg/s', 'CDRA CO2 Outlet Flow AirSafe 2');
            
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_Air_Out_1.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)', 'kg/s', 'CDRA H2O Outlet Flow 1');
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_Air_Out_2.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)', 'kg/s', 'CDRA H2O Outlet Flow 2');
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_AirSafe_1.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)', 'kg/s', 'CDRA H2O Outlet Flow AirSafe 1');
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_AirSafe_2.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)', 'kg/s', 'CDRA H2O Outlet Flow AirSafe 2');
            
            oLog.addVirtualValue('-1 .*("CDRA CO2 Inlet Flow 1" + "CDRA CO2 Inlet Flow 2")', 'kg/s', 'CDRA CO2 InletFlow');
            oLog.addVirtualValue('-1 .*("CDRA H2O Inlet Flow 1" + "CDRA H2O Inlet Flow 2")', 'kg/s', 'CDRA H2O InletFlow');
            
            oLog.addVirtualValue('"CDRA CO2 Outlet Flow 1" + "CDRA CO2 Outlet Flow 2" + "CDRA CO2 Outlet Flow AirSafe 1" + "CDRA CO2 Outlet Flow AirSafe 2"', 'kg/s', 'CDRA CO2 OutletFlow');
            oLog.addVirtualValue('"CDRA H2O Outlet Flow 1" + "CDRA H2O Outlet Flow 2" + "CDRA H2O Outlet Flow AirSafe 1" + "CDRA H2O Outlet Flow AirSafe 2"', 'kg/s', 'CDRA H2O OutletFlow');
            
            oLog.addVirtualValue('-1 .*("CDRA CO2 Inlet Flow 1" + "CDRA CO2 Inlet Flow 2") - ("CDRA CO2 Outlet Flow 1" + "CDRA CO2 Outlet Flow 2" + "CDRA CO2 Outlet Flow AirSafe 1" + "CDRA CO2 Outlet Flow AirSafe 2")', 'kg/s', 'CDRA effective CO2 Flow');
            oLog.addVirtualValue('-1 .*("CDRA H2O Inlet Flow 1" + "CDRA H2O Inlet Flow 2") - ("CDRA H2O Outlet Flow 1" + "CDRA H2O Outlet Flow 2" + "CDRA H2O Outlet Flow AirSafe 1" + "CDRA H2O Outlet Flow AirSafe 2")', 'kg/s', 'CDRA effective H2O Flow');
            
            oLog.addVirtualValue('"Partial Pressure CO2" ./ 133.322', 'torr', 'Partial Pressure CO2 Torr');
            
            
            for iType = 1:3
                for iBed = 1:2
                    sTotalCO2Mass = ['"Partial Mass CO2 ', csType{iType}, num2str(iBed),' Cell ',num2str(1),'"'];
                    sTotalH2OMass = ['"Partial Mass H2O ', csType{iType}, num2str(iBed),' Cell ',num2str(1),'"'];
                    for iCell = 2:miCellNumber(iType)
                         sTotalCO2Mass	= [sTotalCO2Mass, ' + "Partial Mass CO2 ',     csType{iType}, num2str(iBed),' Cell ',num2str(iCell),'"'];
                         sTotalH2OMass = [sTotalH2OMass, ' + "Partial Mass H2O ',     csType{iType}, num2str(iBed),' Cell ',num2str(iCell),'"'];
                    end
                    
                    oLog.addVirtualValue(sTotalCO2Mass, 'kg', ['Total Mass CO2 ', csType{iType}, ' ', num2str(iBed)]);
                    oLog.addVirtualValue(sTotalH2OMass, 'kg', ['Total Mass H2O ', csType{iType}, ' ', num2str(iBed)]);
            
                end
            end
        end
        
        function plot(this) % Plotting the results
            % See http://www.mathworks.de/de/help/matlab/ref/plot.html for
            % further information
            close all
          
            try
                this.toMonitors.oLogger.readFromMat;
            catch
                disp('no data outputted yet')
            end
            
            oPlotter = plot@simulation.infrastructure(this);
            oLogger = oPlotter.oSimulationInfrastructure.toMonitors.oLogger;
            
            % Calculate and display convergence parameters:
            
            for iCO2OutletIndex = 1:length(oLogger.tVirtualValues)
                strcmp(oLogger.tVirtualValues(iCO2OutletIndex).sLabel, 'CDRA CO2 OutletFlow');
                break
            end
            mfCO2OutletFlow = oLogger.tVirtualValues(iCO2OutletIndex).calculationHandle(oLogger.mfLog);
            mfCO2OutletFlow(isnan(mfCO2OutletFlow)) = [];
            mfCO2OutletFlow(end) = [];
            
            afTimeSteps = oLogger.afTime(2:end) - oLogger.afTime(1:end-1);
            fAveragedCO2Outlet = sum(mfCO2OutletFlow .* afTimeSteps') ./ sum(afTimeSteps);
            
            disp(' ')
            disp(['Averaged CO2 Outlet Flow:       ', num2str(fAveragedCO2Outlet)])
            disp(' ')
            
            %% Define plots
            tPlotOptions.sTimeUnit  = 'hours';
            tPlotOptions.bLegend    = false;
            
            csType = {'Sylobead_', 'Zeolite13x_', 'Zeolite5A_'};
            
            csTotalMassCO2 = cell(3,2);
            csTotalMassH2O = cell(3,2);
                    
            for iType = 1:3
                for iBed = 1:2
                    csTotalMassCO2{iType,iBed} = ['"Total Mass CO2 ', csType{iType}, ' ', num2str(iBed), '"'];
                    csTotalMassH2O{iType,iBed} = ['"Total Mass H2O ', csType{iType}, ' ', num2str(iBed), '"'];
                end
            end
            
            coPlot = cell(3,2);
            for iType = 1:3
                for iBed = 1:2
                     coPlot{iType,iBed} = oPlotter.definePlot(csTotalMassCO2(iType,iBed), [csType{iType}, num2str(iBed), ' Adsorbed CO2 Mass'], tPlotOptions);     
                end
            end
            oPlotter.defineFigure(coPlot,  'Total CO2 Adsorbed Masses');
            
            coPlot = cell(3,2);
            for iType = 1:3
                for iBed = 1:2
                     coPlot{iType,iBed} = oPlotter.definePlot(csTotalMassH2O(iType,iBed), [csType{iType}, num2str(iBed), ' Adsorbed H2O Mass'], tPlotOptions);     
                end
            end
            oPlotter.defineFigure(coPlot,  'Total H2O Adsorbed Masses');
            
            oPlotter.plot();
            
            %% Get Test Data:
            iFileID = fopen(strrep('+examples/+CDRA/+TestData/CDRA_Test_Data.csv','/',filesep), 'r');
            
            [FilePath,~,~,~] = fopen(iFileID);
            
            mfTestData = csvread(FilePath);
            % at hour 50 of the test data the CO2 input is reduced to 4 CM,
            % this corresponds to hour 19.3 in the simulation. Therefore
            % Test data is timeshifted by 30.7 hours to fit the simulation
            % and ease plotting:
            mfTestData(:,1) = mfTestData(:,1) - 30.7;
            % We do not need the negative values (the test data had a
            % period where an error occur, we start comparing after that)
            mfTestData(mfTestData(:,1) < 0,:) = [];
            
            % Plot overlay with test data:
            figure()
            plot(mfTestData(:,1), mfTestData(:,2));
            grid on
            xlabel('Time in h');
            ylabel('Partial Pressure CO_2 in Torr');
            hold on
            
            for iVirtualLog = 1:length(oLogger.tVirtualValues)
                if strcmp(oLogger.tVirtualValues(iVirtualLog).sLabel, 'Partial Pressure CO2 Torr')
                    calculationHandle = oLogger.tVirtualValues(iVirtualLog).calculationHandle;
                end
            end
            mfCO2PartialPressure = calculationHandle(oLogger.mfLog);
            mfCO2PartialPressure(isnan(mfCO2PartialPressure)) = [];
            
            afTime = (oLogger.afTime./3600)';
            afTime(isnan(afTime)) = [];
            
            plot(afTime, mfCO2PartialPressure);
            legend('Test Data','Simulation');
            
            [afTimeDataUnique, ia, ~] = unique(mfTestData(:,1));
            afCO2DataUnique = mfTestData(ia,2);
            
            InterpolatedTestData = interp1(afTimeDataUnique, afCO2DataUnique, afTime);
            
            % There will be some nan values because the simulation has data
            % before the simulation data, these are removed here
            mfCO2PartialPressure(isnan(InterpolatedTestData)) = [];
            afTime(isnan(InterpolatedTestData)) = [];
            InterpolatedTestData(isnan(InterpolatedTestData)) = [];
            
            % We only look at the differen from hour 11 onward as before
            % the test data is not accurate because CDRA was turned off
            % since it had a water carry over event
            mfCO2PartialPressure(afTime < 11) = [];
            InterpolatedTestData(afTime < 11) = [];
            
            fMaxDiff  = max(abs(mfCO2PartialPressure - InterpolatedTestData));
            fMinDiff  = min(abs(mfCO2PartialPressure - InterpolatedTestData));
            fMeanDiff = mean(mfCO2PartialPressure - InterpolatedTestData);
            rPercentualError = 100 * fMeanDiff / mean(InterpolatedTestData);
            
            disp(['Maximum   Difference between Simulation and Test:     ', num2str(fMaxDiff), ' Torr'])
            disp(['Minimum   Difference between Simulation and Test:     ', num2str(fMinDiff), ' Torr'])
            disp(['Mean      Difference between Simulation and Test:     ', num2str(fMeanDiff), ' Torr'])
            disp(['Percent   Difference between Simulation and Test:     ', num2str(rPercentualError), ' %'])
            
        end
    end
end
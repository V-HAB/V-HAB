classdef setup < simulation.infrastructure
    %SETUP This class is used as setup for CDRA example (which also serves
    % as verification).
    % The CDRA model is programmed to allow a variable number of cells
    % larger than 2 cells per bed. You can run this simulation with
    % different cell numbers by using the following exec call:
    % vhab.exec('examples.CDRA.setup', containers.Map({'tInitialization'},{struct('Zeolite13x', struct('iCellNumber', 10), 'Sylobead', struct('iCellNumber', 10), 'Zeolite5A', struct('iCellNumber', 10))}));
    
    properties
    end
    
    methods
        function this = setup(ptConfigParams, tSolverParams)
            
            ttMonitorConfig = struct();
            this@simulation.infrastructure('Example_CDRA', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            % Creating the root object
            examples.CDRA.systems.Example(this.oSimulationContainer, 'Example');

            %% Simulation length
            % Stop when specific time in simulation is reached or after 
            % specific amount of ticks (bUseTime true/false).
            this.fSimTime = 3600 * 50; % In seconds
            this.bUseTime = true;
        end
        
        function configureMonitors(this)
            
            %% Logging
            oLog = this.toMonitors.oLogger;
            
            oLog.addValue('Example:s:Cabin.toPhases.CabinAir', 'rRelHumidity',              '-',    'Relative Humidity Cabin');
            oLog.addValue('Example:s:Cabin.toPhases.CabinAir', 'afPP(this.oMT.tiN2I.CO2)',  'Pa',   'Partial Pressure CO2');
            oLog.addValue('Example:s:Cabin.toPhases.CabinAir', 'fTemperature',              'K',    'Temperature Atmosphere');
            
            oLog.addValue('Example.oTimer',                                 'fTimeStepFinal',                 's',   'Timestep');
            
            oLog.addValue('Example:c:CCAA:s:CHX.toPhases.CHX_PhaseIn',      'fTemperature',                             'K',    'Temperature CHX');
            oLog.addValue('Example:c:CCAA:s:CHX.toPhases.CHX_PhaseIn',      'this.fMass * this.fMassToPressure',        'Pa',   'Pressure CHX');
            oLog.addValue('Example:c:CCAA:s:TCCV.toPhases.TCCV_PhaseGas',  	'fTemperature',                             'K',    'Temperature TCCV');
            oLog.addValue('Example:c:CCAA:s:TCCV.toPhases.TCCV_PhaseGas',  	'this.fMass * this.fMassToPressure',    	'Pa',   'Pressure TCCV');
            oLog.addValue('Example:c:CCAA:s:TCCV.toPhases.TCCV_PhaseGas',  	'afPP(this.oMT.tiN2I.H2O)',                 'Pa',   'Partial Pressure H2O TCCV');
            oLog.addValue('Example:c:CCAA:s:TCCV.toPhases.TCCV_PhaseGas',  	'afPP(this.oMT.tiN2I.CO2)',                 'Pa',   'Partial Pressure CO2 TCCV');
            oLog.addValue('Example:c:CCAA:s:CHX.toProcsP2P.CondensingHX',   'fFlowRate',                                'kg/s', 'Condensate Flowrate CHX');
            oLog.addValue('Example:c:CCAA',                                 'fTCCV_Angle',                               '°',   'TCCV Angle');
            
            iCellNumber13x = this.oSimulationContainer.toChildren.Example.toChildren.CDRA.tGeometry.Zeolite13x.iCellNumber;
            iCellNumberSylobead = this.oSimulationContainer.toChildren.Example.toChildren.CDRA.tGeometry.Sylobead.iCellNumber;
            iCellNumber5A = this.oSimulationContainer.toChildren.Example.toChildren.CDRA.tGeometry.Zeolite5A.iCellNumber;
            miCellNumber = [iCellNumberSylobead, iCellNumber13x, iCellNumber5A];
            csType = {'Sylobead_', 'Zeolite13x_', 'Zeolite5A_'};
            for iType = 1:3
                for iBed = 1:2
                    for iCell = 1:miCellNumber(iType)
                        oLog.addValue(['Example:c:CDRA:s:',csType{iType}, num2str(iBed),'.toPhases.Flow_',num2str(iCell)],      'fPressure',                    'Pa',   ['Flow Pressure', csType{iType}, num2str(iBed),' Cell ',num2str(iCell)]);
                        oLog.addValue(['Example:c:CDRA:s:',csType{iType}, num2str(iBed),'.toPhases.Flow_',num2str(iCell)],      'afPP(this.oMT.tiN2I.H2O)',     'Pa',   ['Flow Pressure H2O ', csType{iType}, num2str(iBed),' Cell ',num2str(iCell)]);
                        oLog.addValue(['Example:c:CDRA:s:',csType{iType}, num2str(iBed),'.toPhases.Flow_',num2str(iCell)],      'afPP(this.oMT.tiN2I.CO2)',     'Pa',   ['Flow Pressure CO2 ', csType{iType}, num2str(iBed),' Cell ',num2str(iCell)]);
                        oLog.addValue(['Example:c:CDRA:s:',csType{iType}, num2str(iBed),'.toPhases.Flow_',num2str(iCell)],      'fTemperature',                 'K',    ['Flow Temperature ', csType{iType}, num2str(iBed),' Cell ',num2str(iCell)]);
                        oLog.addValue(['Example:c:CDRA:s:',csType{iType}, num2str(iBed),'.toPhases.Absorber_',num2str(iCell)],  'fTemperature',                 'K',    ['Absorber Temperature ', csType{iType}, num2str(iBed),' Cell ',num2str(iCell)]);

                        oLog.addValue(['Example:c:CDRA:s:',csType{iType}, num2str(iBed),'.toPhases.Absorber_',num2str(iCell)],  'afMass(this.oMT.tiN2I.CO2)',   'kg',   ['Partial Mass CO2 ', csType{iType}, num2str(iBed),' Cell ',num2str(iCell)]);
                        oLog.addValue(['Example:c:CDRA:s:',csType{iType}, num2str(iBed),'.toPhases.Absorber_',num2str(iCell)],  'afMass(this.oMT.tiN2I.H2O)',   'kg',   ['Partial Mass H2O ', csType{iType}, num2str(iBed),' Cell ',num2str(iCell)]);
                        
                        oLog.addValue(['Example:c:CDRA:s:',csType{iType}, num2str(iBed),'.toProcsP2P.AdsorptionProcessor_',num2str(iCell)],  'mfFlowRates(this.oMT.tiN2I.CO2)',   'kg/s',   ['Absorber Flowrate CO2 ', csType{iType}, num2str(iBed),' Cell ',num2str(iCell)]);
                        oLog.addValue(['Example:c:CDRA:s:',csType{iType}, num2str(iBed),'.toProcsP2P.AdsorptionProcessor_',num2str(iCell)],  'mfFlowRates(this.oMT.tiN2I.H2O)',   'kg/s',   ['Absorber Flowrate H2O ', csType{iType}, num2str(iBed),' Cell ',num2str(iCell)]);
                        
                    end
                    
                    for iCell = 1:miCellNumber(iType)-1
                        oLog.addValue(['Example:c:CDRA.tMassNetwork.InternalBranches_',csType{iType}, num2str(iBed), '(', num2str(iCell), ')'],  'fFlowRate',   'kg/s',   ['Flowrate ', csType{iType}, num2str(iBed),' Cell ',num2str(iCell)]);
                    end     
                end
            end
            
            csInterfaceBranches = fieldnames(this.oSimulationContainer.toChildren.Example.toChildren.CDRA.tMassNetwork.InterfaceBranches);
            iInterfaceBranches = length(csInterfaceBranches);
            for iIB = 1:iInterfaceBranches
                oLog.addValue(['Example:c:CDRA.tMassNetwork.InterfaceBranches.', csInterfaceBranches{iIB}],  'fFlowRate',   'kg/s',   csInterfaceBranches{iIB});
            end
            
            oLog.addValue('Example.toStores.CCAA_CDRA_Connection.aoPhases',      'fPressure',  'Pa',   'Connection Pressure CCAA to CDRA');
            
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
            
            iLabel = 1;
            csHeaterLabel = cell(1,2*iCellNumber5A);
            for iBed = 1:2
                for iCell = 1:iCellNumber5A
                    csHeaterLabel{iLabel} = ['Absorber Heater Power Bed ', num2str(iBed),' Cell ',num2str(iCell)];
                    oLog.addValue(['Example:c:CDRA:s:Zeolite5A_',num2str(iBed),'.toPhases.Absorber_',num2str(iCell),'.oCapacity.toHeatSources.AbsorberHeater_',num2str(iCell)],  'fHeatFlow',	'W',    csHeaterLabel{iLabel});
                    
                    iLabel = iLabel + 1;
                end
            end
            sLogSum = '';
            for iHeater = 1:iLabel-1
                sLogSum = [sLogSum, '"', csHeaterLabel{iHeater}, '" + '];
            end
            sLogSum(end-2 : end) = '';
            
            oLog.addVirtualValue(sLogSum, 'W', 'CDRA Heater Power');
            
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
            
            csLogVariableNames = {'Timestep'};
            [aiLogIndices, ~] = tools.findLogIndices(oLogger, csLogVariableNames);
            try
                afTimeSteps =  oLogger.mfLog(:,aiLogIndices(1));
                afTimeSteps(isnan(afTimeSteps)) = [];
                fAveragedCO2Outlet = sum(mfCO2OutletFlow .* afTimeSteps(1:length(mfCO2OutletFlow))) ./ sum(afTimeSteps);
            catch
                afTimeSteps = oLogger.afTime(2:end) - oLogger.afTime(1:end-1);
                fAveragedCO2Outlet = sum(mfCO2OutletFlow .* afTimeSteps') ./ sum(afTimeSteps);
            end
            
            
            disp(' ')
            disp(['Averaged CO2 Outlet Flow:       ', num2str(fAveragedCO2Outlet)])
            disp(' ')
            
            %% Define plots
            tPlotOptions.sTimeUnit  = 'hours';
            tPlotOptions.bLegend    = false;
            
            iCellNumber13x = this.oSimulationContainer.toChildren.Example.toChildren.CDRA.tGeometry.Zeolite13x.iCellNumber;
            iCellNumberSylobead = this.oSimulationContainer.toChildren.Example.toChildren.CDRA.tGeometry.Sylobead.iCellNumber;
            iCellNumber5A = this.oSimulationContainer.toChildren.Example.toChildren.CDRA.tGeometry.Zeolite5A.iCellNumber;
            miCellNumber = [iCellNumberSylobead, iCellNumber13x, iCellNumber5A];
            csType = {'Sylobead_', 'Zeolite13x_', 'Zeolite5A_'};
            
            csCDRA_CO2_Mass             = cell(3,2,max(miCellNumber));
            csCDRA_H2O_Mass             = cell(3,2,max(miCellNumber));
            csCDRA_Pressure             = cell(3,2,max(miCellNumber));
            csCDRA_CO2_Pressure         = cell(3,2,max(miCellNumber));
            csCDRA_H2O_Pressure         = cell(3,2,max(miCellNumber));
            csCDRA_Flow_Temperature     = cell(3,2,max(miCellNumber));
            csCDRA_Absorber_Temperature = cell(3,2,max(miCellNumber));
            csCDRA_Absorber_FlowrateCO2 = cell(3,2,max(miCellNumber));
            csCDRA_Absorber_FlowrateH2O = cell(3,2,max(miCellNumber));
            
            csTotalMassCO2 = cell(3,2);
            csTotalMassH2O = cell(3,2);
                    
            csCDRA_FlowRate = cell(3,2,max(miCellNumber));
            
            for iType = 1:3
                for iBed = 1:2
                    for iCell = 1:miCellNumber(iType)
                         csCDRA_Pressure{iType,iBed,iCell}              =  ['"Flow Pressure', csType{iType}, num2str(iBed),' Cell ',num2str(iCell), '"'];
                         
                         csCDRA_CO2_Mass{iType,iBed,iCell}              = ['"Partial Mass CO2 ',     csType{iType}, num2str(iBed),' Cell ',num2str(iCell) ,'"'];
                         csCDRA_H2O_Mass{iType,iBed,iCell}              = ['"Partial Mass H2O ',     csType{iType}, num2str(iBed),' Cell ',num2str(iCell),'"'];

                         csCDRA_CO2_Pressure{iType,iBed,iCell}          = ['"Flow Pressure CO2 ',    csType{iType}, num2str(iBed),' Cell ',num2str(iCell),'"'];
                         csCDRA_H2O_Pressure{iType,iBed,iCell}          = ['"Flow Pressure H2O ',    csType{iType}, num2str(iBed),' Cell ',num2str(iCell),'"'];

                         csCDRA_Flow_Temperature{iType,iBed,iCell}      = ['"Flow Temperature ',     csType{iType}, num2str(iBed),' Cell ',num2str(iCell),'"'];
                         csCDRA_Absorber_Temperature{iType,iBed,iCell}  = ['"Absorber Temperature ', csType{iType}, num2str(iBed),' Cell ',num2str(iCell),'"'];
                         
                         csCDRA_Absorber_FlowrateCO2{iType,iBed,iCell}  = ['"Absorber Flowrate CO2 ', csType{iType}, num2str(iBed),' Cell ',num2str(iCell),'"'];
                         csCDRA_Absorber_FlowrateH2O{iType,iBed,iCell}  = ['"Absorber Flowrate H2O ', csType{iType}, num2str(iBed),' Cell ',num2str(iCell),'"'];
                         
                    end
                    
                    for iCell = 1:miCellNumber(iType)-1
                         csCDRA_FlowRate{iType,iBed,iCell}              = ['"Flowrate ', csType{iType}, num2str(iBed),' Cell ',num2str(iCell), '"'];
                    end
                    
                    csTotalMassCO2{iType,iBed} = ['"Total Mass CO2 ', csType{iType}, ' ', num2str(iBed), '"'];
                    csTotalMassH2O{iType,iBed} = ['"Total Mass H2O ', csType{iType}, ' ', num2str(iBed), '"'];
                end
            end
            
            coPlot = cell(3,2);
            for iType = 1:3
                for iBed = 1:2
                     coPlot{iType,iBed} = oPlotter.definePlot(csCDRA_Pressure(iType,iBed,1:miCellNumber(iType)), [csType{iType}, num2str(iBed), ' Pressure'], tPlotOptions);
                end
            end
            oPlotter.defineFigure(coPlot,  'CDRA Pressure');
            
            
            coPlot = cell(3,2);
            for iType = 1:3
                for iBed = 1:2
                     coPlot{iType,iBed} = oPlotter.definePlot(csCDRA_CO2_Mass(iType,iBed,1:miCellNumber(iType)), [csType{iType}, num2str(iBed), ' Adsorbed CO2 Mass'], tPlotOptions);     
                end
            end
            oPlotter.defineFigure(coPlot,  'CO2 Adsorbed Masses');
            
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
                     coPlot{iType,iBed} = oPlotter.definePlot(csCDRA_H2O_Mass(iType,iBed,1:miCellNumber(iType)), [csType{iType}, num2str(iBed), ' Adsorbed H2O Mass'], tPlotOptions);
                end
            end
            oPlotter.defineFigure(coPlot,  'H2O Adsorbed Masses');
            
            coPlot = cell(3,2);
            for iType = 1:3
                for iBed = 1:2
                     coPlot{iType,iBed} = oPlotter.definePlot(csTotalMassH2O(iType,iBed), [csType{iType}, num2str(iBed), ' Adsorbed H2O Mass'], tPlotOptions);     
                end
            end
            oPlotter.defineFigure(coPlot,  'Total H2O Adsorbed Masses');
            
            
            coPlot = cell(3,2);
            for iType = 1:3
                for iBed = 1:2
                     coPlot{iType,iBed} = oPlotter.definePlot(csCDRA_CO2_Pressure(iType,iBed,1:miCellNumber(iType)), [csType{iType}, num2str(iBed), ' CO2 Pressure Flow'], tPlotOptions);
                end
            end
            oPlotter.defineFigure(coPlot,  'CO2 Partial Pressures in Flow');
            
            coPlot = cell(3,2);
            for iType = 1:3
                for iBed = 1:2
                    coPlot{iType,iBed} = oPlotter.definePlot(csCDRA_H2O_Pressure(iType,iBed,1:miCellNumber(iType)), [csType{iType}, num2str(iBed), ' H2O Pressure Flow'], tPlotOptions);
                end
            end
            oPlotter.defineFigure(coPlot,  'H2O Partial Pressures in Flow');
            
%             coPlot = cell(3,2);
%             for iType = 1:3
%                 for iBed = 1:2
%                      coPlot{iType,iBed} = oPlotter.definePlot(csCDRA_Absorber_FlowrateCO2(iType,iBed,1:miCellNumber(iType)), [csType{iType}, num2str(iBed), ' CO2 Adsorption Flowrate'], tPlotOptions);
%                 end
%             end
%             oPlotter.defineFigure(coPlot,  'CO2 Adsorption Flow Rates');
%             
%             coPlot = cell(3,2);
%             for iType = 1:3
%                 for iBed = 1:2
%                     coPlot{iType,iBed} = oPlotter.definePlot(csCDRA_Absorber_FlowrateH2O(iType,iBed,1:miCellNumber(iType)), [csType{iType}, num2str(iBed), ' H2O Adsorption Flowrate'], tPlotOptions);
%                 end
%             end
%             oPlotter.defineFigure(coPlot,  'H2O Adsorption Flow Rates');
            
            coPlot = cell(3,2);
            for iType = 1:3
                for iBed = 1:2
                     coPlot{iType,iBed} = oPlotter.definePlot(csCDRA_Flow_Temperature(iType,iBed,1:miCellNumber(iType)), [csType{iType}, num2str(iBed), ' Flow Temperature'], tPlotOptions);
                     coPlot{iType,iBed} = oPlotter.definePlot(csCDRA_Absorber_Temperature(iType,iBed,1:miCellNumber(iType)), [csType{iType}, num2str(iBed), ' Adsorber Temperature'], tPlotOptions);
                end
            end
            oPlotter.defineFigure(coPlot,  'Temperatures');
            
            % csType = {'Sylobead_', 'Zeolite13x_', 'Zeolite5A_'};
            csCDRA_FlowRate{1,1,iCellNumberSylobead} = '"CDRA_Air_In_1"';
            csCDRA_FlowRate{1,1,iCellNumberSylobead+1} = '"CDRA_Air_Out_2"';
            
            csCDRA_FlowRate{1,2,iCellNumberSylobead} = '"CDRA_Air_In_2"';
            csCDRA_FlowRate{1,2,iCellNumberSylobead+1} = '"CDRA_Air_Out_1"';
            
            csCDRA_FlowRate{2,1,iCellNumber13x} = '"Zeolite5A2_to_13x1"';
            csCDRA_FlowRate{2,1,iCellNumber13x+1} = '"Zeolite5A2_to_13x1"';
            csCDRA_FlowRate{2,2,iCellNumber13x} = '"Zeolite5A1_to_13x2"';
            csCDRA_FlowRate{2,2,iCellNumber13x+1} = '"Zeolite5A1_to_13x2"';
            
            csCDRA_FlowRate{3,1,iCellNumber5A} = '"CDRA_Vent_2"';
            csCDRA_FlowRate{3,1,iCellNumber5A+1} = '"CDRA_AirSafe_2"';
            
            csCDRA_FlowRate{3,2,iCellNumber5A} = '"CDRA_Vent_1"';
            csCDRA_FlowRate{3,2,iCellNumber5A+1} = '"CDRA_AirSafe_1"';
            
            miCellNumber(1) = miCellNumber(1) + 1;
            miCellNumber(2) = miCellNumber(2) + 1;
            miCellNumber(3) = miCellNumber(3) + 1;
            
            coPlot = cell(3,2);
            for iType = 1:3
                for iBed = 1:2
                     coPlot{iType,iBed} = oPlotter.definePlot(csCDRA_FlowRate(iType,iBed,1:miCellNumber(iType)), [csType{iType}, num2str(iBed), ' Flowrate'], tPlotOptions);
                end
            end
            oPlotter.defineFigure(coPlot,  'FlowRates');
            
            clear tPlotOptions
            tPlotOptions.sTimeUnit  = 'hours';
            
            coPlot = cell(4,3);
            coPlot{1,1} = oPlotter.definePlot({'"CDRA CO2 InletFlow"', '"CDRA H2O InletFlow"', '"CDRA CO2 OutletFlow"', '"CDRA H2O OutletFlow"'}, 'CDRA In- and Outlet Flows', tPlotOptions);
            coPlot{1,2} = oPlotter.definePlot({'"Condensate Flowrate CHX"'},                                    'CHX Condensate Flowrate', tPlotOptions);
            coPlot{1,3} = oPlotter.definePlot({'"Partial Pressure CO2"'},                                       'Partial Pressure CO2 Habitat',tPlotOptions);
            coPlot{2,1} = oPlotter.definePlot({'"Partial Pressure CO2 Torr"'},                                  'Partial Pressure CO2 Habitat in Torr',tPlotOptions);
            coPlot{2,2} = oPlotter.definePlot({'"Relative Humidity Cabin"'},                                    'Relative Humidity Cabin',tPlotOptions);
            coPlot{2,3} = oPlotter.definePlot({'"CO2 Production"', '"CDRA effective CO2 Flow"'},                'Effective CO2 FlowRates',tPlotOptions);
            coPlot{3,1} = oPlotter.definePlot({'"Temperature CHX"', '"Temperature TCCV"'},                      'Temperatures in CHX',tPlotOptions);
            coPlot{3,2} = oPlotter.definePlot({'"Pressure CHX"', '"Pressure TCCV"'},                            'Pressure in CHX', tPlotOptions);
            coPlot{3,3} = oPlotter.definePlot({'"Partial Pressure H2O TCCV"', '"Partial Pressure CO2 TCCV"'},   'Partial Pressure H2O and CO2 TCCV', tPlotOptions);
            coPlot{4,3} = oPlotter.definePlot({'"CDRA Heater Power"'},                                          'CDRA Heater Power', tPlotOptions);
            coPlot{4,2} = oPlotter.definePlot({'"TCCV Angle"'},                                                 'CCAA TCCV Angle', tPlotOptions);
            coPlot{4,1} = oPlotter.definePlot({'"Temperature Atmosphere"'},                                     'Cabin Temperature', tPlotOptions);
            
            
            oPlotter.defineFigure(coPlot,  'Plots');
            
            oPlotter.plot();
            
            %% Plot energy demand over timer
            oLogger = this.toMonitors.oLogger;
            
            for iVirtualLog = 1:length(oLogger.tVirtualValues)
                if strcmp(oLogger.tVirtualValues(iVirtualLog).sLabel, 'CDRA Heater Power')
                    
                    mfCDRA_HeaterPower = oLogger.tVirtualValues(iVirtualLog).calculationHandle(oLogger.mfLog);
                    
                end
            end
            afTimeSteps = (oLogger.afTime(2:end) - oLogger.afTime(1:end-1));
            
            iLogs = length(oLogger.afTime);
            
            mfCDRA_EnergyDemand = zeros(iLogs,1);
            for iLog = 2:iLogs
                mfCDRA_EnergyDemand(iLog) = sum(afTimeSteps(1:iLog-1)' .* mfCDRA_HeaterPower(2:iLog));
            end
            
            figure()
            plot(oLogger.afTime./3600, mfCDRA_EnergyDemand)
            xlabel('Time in h')
            ylabel('Energy in J')
            title('CDRA Energy Demand')
            grid on
            
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
            xlabel('Time / h');
            ylabel('Partial Pressure CO_2 / Torr');
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
            
            plot(afTime(1:length(mfCO2PartialPressure)), mfCO2PartialPressure);
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
            fMeanSquaredError = mean((mfCO2PartialPressure - InterpolatedTestData).^2);
            
            disp(['Maximum   Difference between Simulation and Test:     ', num2str(fMaxDiff), ' Torr'])
            disp(['Minimum   Difference between Simulation and Test:     ', num2str(fMinDiff), ' Torr'])
            disp(['Mean      Difference between Simulation and Test:     ', num2str(fMeanDiff), ' Torr'])
            disp(['MSE       Difference between Simulation and Test:     ', num2str(fMeanSquaredError), ' Torr'])
            disp(['Percent   Difference between Simulation and Test:     ', num2str(rPercentualError), ' %'])
            
        end
    end
end
classdef setup < simulation.infrastructure
    %SETUP This class is used to setup a simulation
    %   There should always be a setup file present for each project. It is
    %   used for the following:
    %   - instantiate the root object
    %   - register branches to their appropriate solvers
    %   - determine which items are logged
    %   - set the simulation duration
    %   - provide methods for plotting the results
    
    properties
    end
    
    methods
        function this = setup(ptConfigParams, tSolverParams, bSimpleCDRA) % Constructor function
            
            % Possible to change the constructor paths and params for the
            % monitors
            ttMonitorConfig = struct();
            warning( 'off', 'all')
            
            this@simulation.infrastructure('Tutorial_CCAA', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            if nargin < 3
                bSimpleCDRA = false;
            end
            % Creating the root object
            tutorials.CDRA.systems.Example(this.oSimulationContainer, 'Example', bSimpleCDRA);

            %% Simulation length
            % Stop when specific time in simulation is reached or after 
            % specific amount of ticks (bUseTime true/false).
            this.fSimTime = 3600 * 50; % In seconds
            this.bUseTime = true;
        end
        
        function configureMonitors(this)
            
            %% Logging
            oLog = this.toMonitors.oLogger;
            
            oLog.add('Example', 'flow_props');
            
            oLog.addValue('Example:s:Cabin.toPhases.CabinAir', 'rRelHumidity', '-', 'Relative Humidity Cabin');
            oLog.addValue('Example:s:Cabin.toPhases.CabinAir', 'afPP(this.oMT.tiN2I.CO2)', 'Pa', 'Partial Pressure CO2');
            oLog.addValue('Example:s:Cabin.toPhases.CabinAir', 'fTemperature', 'K', 'Temperature Atmosphere');
            
            oLog.addValue('Example:c:CCAA:s:CHX.toPhases.CHX_PhaseIn', 'fTemperature', 'K', 'Temperature CHX');
            oLog.addValue('Example:c:CCAA:s:CHX.toPhases.CHX_PhaseIn', 'fPressure', 'Pa', 'Pressure CHX');
            oLog.addValue('Example:c:CCAA:s:CHX.toProcsP2P.CondensingHX', 'fFlowRate', 'kg/s', 'Condensate Flowrate CHX');
            
            for iBed = 1:2
                for iCell = 1:5
                    oLog.addValue(['Example:c:CDRA:s:Zeolite13x_',num2str(iBed),'.toPhases.Flow_',num2str(iCell)], 'fPressure', 'Pa', ['Flow Pressure Zeolite13x_',num2str(iBed),' Cell ',num2str(iCell)]);
                    oLog.addValue(['Example:c:CDRA:s:Zeolite13x_',num2str(iBed),'.toPhases.Flow_',num2str(iCell)], 'afPP(this.oMT.tiN2I.H2O)', 'Pa', ['Flow Pressure H2O Zeolite13x_',num2str(iBed),' Cell ',num2str(iCell)]);
                    oLog.addValue(['Example:c:CDRA:s:Zeolite13x_',num2str(iBed),'.toPhases.Flow_',num2str(iCell)], 'afPP(this.oMT.tiN2I.CO2)', 'Pa', ['Flow Pressure CO2 Zeolite13x_',num2str(iBed),' Cell ',num2str(iCell)]);
                    oLog.addValue(['Example:c:CDRA:s:Zeolite13x_',num2str(iBed),'.toPhases.Flow_',num2str(iCell)], 'fTemperature', 'K', ['Flow Temperature Zeolite13x_',num2str(iBed),' Cell ',num2str(iCell)]);
                    oLog.addValue(['Example:c:CDRA:s:Zeolite13x_',num2str(iBed),'.toPhases.Absorber_',num2str(iCell)], 'fTemperature', 'K', ['Absorber Temperature Zeolite13x_',num2str(iBed),' Cell ',num2str(iCell)]);
                    
                    oLog.addValue(['Example:c:CDRA:s:Zeolite13x_',num2str(iBed),'.toPhases.Absorber_',num2str(iCell)], 'afMass(this.oMT.tiN2I.CO2)', 'kg', ['Partial Mass CO2 Zeolite13x_',num2str(iBed),' Cell ',num2str(iCell)]);
                    oLog.addValue(['Example:c:CDRA:s:Zeolite13x_',num2str(iBed),'.toPhases.Absorber_',num2str(iCell)], 'afMass(this.oMT.tiN2I.H2O)', 'kg', ['Partial Mass H2O Zeolite13x_',num2str(iBed),' Cell ',num2str(iCell)]);
                end
            end
            
            for iBed = 1:2
                for iCell = 1:5
                    oLog.addValue(['Example:c:CDRA:s:Sylobead_',num2str(iBed),'.toPhases.Flow_',num2str(iCell)], 'fPressure', 'Pa', ['Flow Pressure Sylobead_',num2str(iBed),' Cell ',num2str(iCell)]);
                    oLog.addValue(['Example:c:CDRA:s:Sylobead_',num2str(iBed),'.toPhases.Flow_',num2str(iCell)], 'afPP(this.oMT.tiN2I.H2O)', 'Pa', ['Flow Pressure H2O Sylobead_',num2str(iBed),' Cell ',num2str(iCell)]);
                    oLog.addValue(['Example:c:CDRA:s:Sylobead_',num2str(iBed),'.toPhases.Flow_',num2str(iCell)], 'afPP(this.oMT.tiN2I.CO2)', 'Pa', ['Flow Pressure CO2 Sylobead_',num2str(iBed),' Cell ',num2str(iCell)]);
                    oLog.addValue(['Example:c:CDRA:s:Sylobead_',num2str(iBed),'.toPhases.Flow_',num2str(iCell)], 'fTemperature', 'K', ['Flow Temperature Sylobead_',num2str(iBed),' Cell ',num2str(iCell)]);
                    oLog.addValue(['Example:c:CDRA:s:Sylobead_',num2str(iBed),'.toPhases.Absorber_',num2str(iCell)], 'fTemperature', 'K', ['Absorber Temperature Sylobead_',num2str(iBed),' Cell ',num2str(iCell)]);
                    
                    oLog.addValue(['Example:c:CDRA:s:Sylobead_',num2str(iBed),'.toPhases.Absorber_',num2str(iCell)], 'afMass(this.oMT.tiN2I.CO2)', 'kg', ['Partial Mass CO2 Sylobead_',num2str(iBed),' Cell ',num2str(iCell)]);
                    oLog.addValue(['Example:c:CDRA:s:Sylobead_',num2str(iBed),'.toPhases.Absorber_',num2str(iCell)], 'afMass(this.oMT.tiN2I.H2O)', 'kg', ['Partial Mass H2O Sylobead_',num2str(iBed),' Cell ',num2str(iCell)]);
                end
            end
            
            for iBed = 1:2
                for iCell = 1:5
                    oLog.addValue(['Example:c:CDRA:s:Zeolite5A_',num2str(iBed),'.toPhases.Flow_',num2str(iCell)], 'fPressure', 'Pa', ['Flow Pressure Zeolite5A_',num2str(iBed),' Cell ',num2str(iCell)]);
                    oLog.addValue(['Example:c:CDRA:s:Zeolite5A_',num2str(iBed),'.toPhases.Flow_',num2str(iCell)], 'afPP(this.oMT.tiN2I.H2O)', 'Pa', ['Flow Pressure H2O Zeolite5A_',num2str(iBed),' Cell ',num2str(iCell)]);
                    oLog.addValue(['Example:c:CDRA:s:Zeolite5A_',num2str(iBed),'.toPhases.Flow_',num2str(iCell)], 'afPP(this.oMT.tiN2I.CO2)', 'Pa', ['Flow Pressure CO2 Zeolite5A_',num2str(iBed),' Cell ',num2str(iCell)]);
                    oLog.addValue(['Example:c:CDRA:s:Zeolite5A_',num2str(iBed),'.toPhases.Flow_',num2str(iCell)], 'fTemperature', 'K', ['Flow Temperature Zeolite5A_',num2str(iBed),' Cell ',num2str(iCell)]);
                    oLog.addValue(['Example:c:CDRA:s:Zeolite5A_',num2str(iBed),'.toPhases.Absorber_',num2str(iCell)], 'fTemperature', 'K', ['Absorber Temperature Zeolite5A_',num2str(iBed),' Cell ',num2str(iCell)]);
                    
                    oLog.addValue(['Example:c:CDRA:s:Zeolite5A_',num2str(iBed),'.toPhases.Absorber_',num2str(iCell)], 'afMass(this.oMT.tiN2I.CO2)', 'kg', ['Partial Mass CO2 Zeolite5A_',num2str(iBed),' Cell ',num2str(iCell)]);
                    oLog.addValue(['Example:c:CDRA:s:Zeolite5A_',num2str(iBed),'.toPhases.Absorber_',num2str(iCell)], 'afMass(this.oMT.tiN2I.H2O)', 'kg', ['Partial Mass H2O Zeolite5A_',num2str(iBed),' Cell ',num2str(iCell)]);
                end
            end
            
            % CDRA In
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_Air_In_1.aoFlows(1)', 'fFlowRate', 'kg/s', 'CDRA Air Inlet Flow 1');
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_Air_In_2.aoFlows(1)', 'fFlowRate', 'kg/s', 'CDRA Air Inlet Flow 2');
            
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_Air_In_1.aoFlows(1)', 'arPartialMass(this.oMT.tiN2I.CO2)', 'kg/s', 'CDRA CO2 Inlet Partialratio 1');
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_Air_In_1.aoFlows(1)', 'arPartialMass(this.oMT.tiN2I.H2O)', 'kg/s', 'CDRA H2O Inlet Partialratio 1');
            
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_Air_In_2.aoFlows(1)', 'arPartialMass(this.oMT.tiN2I.CO2)', 'kg/s', 'CDRA CO2 Inlet Partialratio 2');
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_Air_In_2.aoFlows(1)', 'arPartialMass(this.oMT.tiN2I.H2O)', 'kg/s', 'CDRA H2O Inlet Partialratio 2');
            
            % CDRA Out
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_Air_Out_1.aoFlows(1)', 'fFlowRate', 'kg/s', 'CDRA Air Outlet Flow 1');
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_Air_Out_2.aoFlows(1)', 'fFlowRate', 'kg/s', 'CDRA Air Outlet Flow 2');
            
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_Air_Out_1.aoFlows(1)', 'arPartialMass(this.oMT.tiN2I.CO2)', 'kg/s', 'CDRA CO2 Outlet Partialratio 1');
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_Air_Out_1.aoFlows(1)', 'arPartialMass(this.oMT.tiN2I.H2O)', 'kg/s', 'CDRA H2O Outlet Partialratio 1');
            
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_Air_Out_2.aoFlows(1)', 'arPartialMass(this.oMT.tiN2I.CO2)', 'kg/s', 'CDRA CO2 Outlet Partialratio 2');
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_Air_Out_2.aoFlows(1)', 'arPartialMass(this.oMT.tiN2I.H2O)', 'kg/s', 'CDRA H2O Outlet Partialratio 2');
            
            %% Define plots
            
            oPlot = this.toMonitors.oPlotter;
            
            oPlot.definePlotAllWithFilter('K', 'Tank Temperatures');
            oPlot.definePlotAllWithFilter('Pa', 'Tank Pressures');
            oPlot.definePlotAllWithFilter('kg', 'Tank Masses');
            
            csZeolite13x_CO2_Mass = cell(2,5);
            csZeolite13x_H2O_Mass = cell(2,5);
            csZeolite13x_CO2_Pressure = cell(2,5);
            csZeolite13x_H2O_Pressure = cell(2,5);
            
            for iBed = 1:2
                for iCell = 1:5
                     csZeolite13x_CO2_Mass{iBed,iCell} = ['Partial Mass CO2 Zeolite13x_',num2str(iBed),' Cell ',num2str(iCell)];
                     csZeolite13x_H2O_Mass{iBed,iCell} = ['Partial Mass H2O Zeolite13x_',num2str(iBed),' Cell ',num2str(iCell)];
                    
                     csZeolite13x_H2O_Pressure{iBed,iCell} = ['Flow Pressure H2O Zeolite13x_',num2str(iBed),' Cell ',num2str(iCell)];
                     csZeolite13x_CO2_Pressure{iBed,iCell} = ['Flow Pressure CO2 Zeolite13x_',num2str(iBed),' Cell ',num2str(iCell)];
                end
            end
            
            csSylobead_CO2_Mass = cell(2,5);
            csSylobead_H2O_Mass = cell(2,5);
            csSylobead_CO2_Pressure = cell(2,5);
            csSylobead_H2O_Pressure = cell(2,5);
            
            for iBed = 1:2
                for iCell = 1:5
                     csSylobead_CO2_Mass{iBed,iCell} = ['Partial Mass CO2 Sylobead_',num2str(iBed),' Cell ',num2str(iCell)];
                     csSylobead_H2O_Mass{iBed,iCell} = ['Partial Mass H2O Sylobead_',num2str(iBed),' Cell ',num2str(iCell)];
                    
                     csSylobead_H2O_Pressure{iBed,iCell} = ['Flow Pressure H2O Sylobead_',num2str(iBed),' Cell ',num2str(iCell)];
                     csSylobead_CO2_Pressure{iBed,iCell} = ['Flow Pressure CO2 Sylobead_',num2str(iBed),' Cell ',num2str(iCell)];
                end
            end
            
            csZeolite5A_CO2_Mass = cell(2,5);
            csZeolite5A_H2O_Mass = cell(2,5);
            csZeolite5A_CO2_Pressure = cell(2,5);
            csZeolite5A_H2O_Pressure = cell(2,5);
            for iBed = 1:2
                for iCell = 1:5
                    csZeolite5A_CO2_Mass{iBed,iCell} = ['Partial Mass CO2 Zeolite5A_',num2str(iBed),' Cell ',num2str(iCell)];
                    csZeolite5A_H2O_Mass{iBed,iCell} = ['Partial Mass H2O Zeolite5A_',num2str(iBed),' Cell ',num2str(iCell)];
                    
                    csZeolite5A_H2O_Pressure{iBed,iCell} = ['Flow Pressure H2O Zeolite5A_',num2str(iBed),' Cell ',num2str(iCell)];
                    csZeolite5A_CO2_Pressure{iBed,iCell} = ['Flow Pressure CO2 Zeolite5A_',num2str(iBed),' Cell ',num2str(iCell)];
                end
            end
            
            
%             csCO2_Total = {csZeolite13x_CO2{1,:}, csZeolite13x_CO2{2,:}, csSylobead_CO2{1,:}, csSylobead_CO2{2,:}, csZeolite5A_CO2{1,:}, csZeolite5A_CO2{2,:}};
%             
%             csH2O_Total = {csZeolite13x_H2O{1,:}, csZeolite13x_H2O{2,:}, csSylobead_H2O{1,:}, csSylobead_H2O{2,:}, csZeolite5A_H2O{1,:}, csZeolite5A_H2O{2,:}};
            
            sTitle = 'Partial Mass CO2 CDRA'; 
            yLabel = 'Partial Mass CO2 in kg';
            sTimeUnit = 'h';
            
            mbPosition = [true,false;false,false;false,false];
            oPlot.definePlotByName(csSylobead_CO2_Mass(1,:), sTitle, yLabel, sTimeUnit, mbPosition);
            
            mbPosition = [false,true;false,false;false,false];
            oPlot.definePlotByName(csSylobead_CO2_Mass(2,:), sTitle, yLabel, sTimeUnit, mbPosition);
            
            mbPosition = [false,false;true,false;false,false];
            oPlot.definePlotByName(csZeolite13x_CO2_Mass(1,:), sTitle, yLabel, sTimeUnit, mbPosition);
            
            mbPosition = [false,false;false,true;false,false];
            oPlot.definePlotByName(csZeolite13x_CO2_Mass(2,:), sTitle, yLabel, sTimeUnit, mbPosition);
            
            mbPosition = [false,false;false,false;true,false];
            oPlot.definePlotByName(csZeolite5A_CO2_Mass(1,:), sTitle, yLabel, sTimeUnit, mbPosition);
            
            mbPosition = [false,false;false,false;false,true];
            oPlot.definePlotByName(csZeolite5A_CO2_Mass(2,:), sTitle, yLabel, sTimeUnit, mbPosition);
            
            
            sTitle = 'Partial Mass H2O CDRA'; 
            yLabel = 'Partial Mass H2O in kg';
            
            mbPosition = [true,false;false,false;false,false];
            oPlot.definePlotByName(csSylobead_H2O_Mass(1,:), sTitle, yLabel, sTimeUnit, mbPosition);
            
            mbPosition = [false,true;false,false;false,false];
            oPlot.definePlotByName(csSylobead_H2O_Mass(2,:), sTitle, yLabel, sTimeUnit, mbPosition);
            
            mbPosition = [false,false;true,false;false,false];
            oPlot.definePlotByName(csZeolite13x_H2O_Mass(1,:), sTitle, yLabel, sTimeUnit, mbPosition);
            
            mbPosition = [false,false;false,true;false,false];
            oPlot.definePlotByName(csZeolite13x_H2O_Mass(2,:), sTitle, yLabel, sTimeUnit, mbPosition);
            
            mbPosition = [false,false;false,false;true,false];
            oPlot.definePlotByName(csZeolite5A_H2O_Mass(1,:), sTitle, yLabel, sTimeUnit, mbPosition);
            
            mbPosition = [false,false;false,false;false,true];
            oPlot.definePlotByName(csZeolite5A_H2O_Mass(2,:), sTitle, yLabel, sTimeUnit, mbPosition);
            
            
            
            sTitle = 'Partial Pressure H2O CDRA'; 
            yLabel = 'Partial Pressure H2O in Pa';
            
            mbPosition = [true,false;false,false;false,false];
            oPlot.definePlotByName(csSylobead_H2O_Pressure(1,:), sTitle, yLabel, sTimeUnit, mbPosition);
            
            mbPosition = [false,true;false,false;false,false];
            oPlot.definePlotByName(csSylobead_H2O_Pressure(2,:), sTitle, yLabel, sTimeUnit, mbPosition);
            
            mbPosition = [false,false;true,false;false,false];
            oPlot.definePlotByName(csZeolite13x_H2O_Pressure(1,:), sTitle, yLabel, sTimeUnit, mbPosition);
            
            mbPosition = [false,false;false,true;false,false];
            oPlot.definePlotByName(csZeolite13x_H2O_Pressure(2,:), sTitle, yLabel, sTimeUnit, mbPosition);
            
            mbPosition = [false,false;false,false;true,false];
            oPlot.definePlotByName(csZeolite5A_H2O_Pressure(1,:), sTitle, yLabel, sTimeUnit, mbPosition);
            
            mbPosition = [false,false;false,false;false,true];
            oPlot.definePlotByName(csZeolite5A_H2O_Pressure(2,:), sTitle, yLabel, sTimeUnit, mbPosition);
            
            
            sTitle = 'Partial Pressure CO2 CDRA'; 
            yLabel = 'Partial Pressure CO2 in Pa';
            
            mbPosition = [true,false;false,false;false,false];
            oPlot.definePlotByName(csSylobead_CO2_Pressure(1,:), sTitle, yLabel, sTimeUnit, mbPosition);
            
            mbPosition = [false,true;false,false;false,false];
            oPlot.definePlotByName(csSylobead_CO2_Pressure(2,:), sTitle, yLabel, sTimeUnit, mbPosition);
            
            mbPosition = [false,false;true,false;false,false];
            oPlot.definePlotByName(csZeolite13x_CO2_Pressure(1,:), sTitle, yLabel, sTimeUnit, mbPosition);
            
            mbPosition = [false,false;false,true;false,false];
            oPlot.definePlotByName(csZeolite13x_CO2_Pressure(2,:), sTitle, yLabel, sTimeUnit, mbPosition);
            
            mbPosition = [false,false;false,false;true,false];
            oPlot.definePlotByName(csZeolite5A_CO2_Pressure(1,:), sTitle, yLabel, sTimeUnit, mbPosition);
            
            mbPosition = [false,false;false,false;false,true];
            oPlot.definePlotByName(csZeolite5A_CO2_Pressure(2,:), sTitle, yLabel, sTimeUnit, mbPosition);
            
            
            
            csNames = {'CDRA CO2 Inlet Flow', 'CDRA CO2 Outlet Flow'};
            sTitle = 'CDRA CO2 Flowrates'; 
            yLabel = 'FlowRate CO_2 in kg/s';
            oPlot.definePlotByName(csNames, sTitle, yLabel, sTimeUnit);
            
            csNames = {'CDRA H2O Inlet Flow', 'CDRA H2O Outlet Flow'};
            sTitle = 'CDRA H2O Flowrates'; 
            yLabel = 'FlowRate H_2O in kg/s';
            oPlot.definePlotByName(csNames, sTitle, yLabel, sTimeUnit);
            
            csNames = {'Condensate Flowrate CHX'};
            sTitle = 'CHX Condensate Flowrate'; 
            yLabel = 'FlowRate H_2O in kg/s';
            oPlot.definePlotByName(csNames, sTitle, yLabel, sTimeUnit);
            
            csNames = {'Partial Pressure CO2'};
            sTitle = 'Partial Pressure CO2 Habitat'; 
            yLabel = 'Partial Pressure CO_2 in Pa';
            oPlot.definePlotByName(csNames, sTitle, yLabel, sTimeUnit);
            
            csNames = {'Relative Humidity Cabin'};
            sTitle = 'Relative Humidity Habitat'; 
            yLabel = 'Relative Humidity';
            oPlot.definePlotByName(csNames, sTitle, yLabel, sTimeUnit);
        end
        
        function plot(this) % Plotting the results
            % See http://www.mathworks.de/de/help/matlab/ref/plot.html for
            % further information
            close all
            
            this.toMonitors.oPlotter.plot();
            
            hCDRA_InletCalc = @(x1,x2,x3,x4)(-(x1 .* x2 + x3 .* x4));
            csLogVariables =  {'CDRA Air Inlet Flow 1','CDRA CO2 Inlet Partialratio 1','CDRA Air Inlet Flow 2','CDRA CO2 Inlet Partialratio 2'};
            sNewLogName = 'CDRA CO2 Inlet Flow';
            this.toMonitors.oPlotter.MathematicOperationOnLog(csLogVariables, hCDRA_InletCalc, sNewLogName, 'kg/s');
            
            hCDRA_OutletCalc = @(x1,x2,x3,x4)((x1 .* x2 + x3 .* x4));
            csLogVariables =  {'CDRA Air Outlet Flow 1','CDRA CO2 Outlet Partialratio 1','CDRA Air Outlet Flow 2','CDRA CO2 Outlet Partialratio 2'};
            sNewLogName = 'CDRA CO2 Outlet Flow';
            this.toMonitors.oPlotter.MathematicOperationOnLog(csLogVariables, hCDRA_OutletCalc, sNewLogName, 'kg/s');
            
            csLogVariables =  {'CDRA Air Inlet Flow 1','CDRA H2O Inlet Partialratio 1','CDRA Air Inlet Flow 2','CDRA H2O Inlet Partialratio 2'};
            sNewLogName = 'CDRA H2O Inlet Flow';
            this.toMonitors.oPlotter.MathematicOperationOnLog(csLogVariables, hCDRA_InletCalc, sNewLogName, 'kg/s');
            
            csLogVariables =  {'CDRA Air Outlet Flow 1','CDRA H2O Outlet Partialratio 1','CDRA Air Outlet Flow 2','CDRA H2O Outlet Partialratio 2'};
            sNewLogName = 'CDRA H2O Outlet Flow';
            this.toMonitors.oPlotter.MathematicOperationOnLog(csLogVariables, hCDRA_OutletCalc, sNewLogName, 'kg/s');
            
            this.toMonitors.oPlotter.plotByName();
            
            return
            
        end
    end
end
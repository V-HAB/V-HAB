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
        function this = setup(ptConfigParams, tSolverParams) % Constructor function
            
            % Possible to change the constructor paths and params for the
            % monitors
            ttMonitorConfig = struct('oLogger', struct('cParams', {{ true }}));
            warning( 'off', 'all')
            
            this@simulation.infrastructure('Tutorial_CDRA', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            this.bPlayFinishSound = true;
            
            % Creating the root object
            tutorials.CDRA.systems.Example(this.oSimulationContainer, 'Example');

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
            
            oLog.addValue('Example:s:Cabin.toPhases.CabinAir', 'rRelHumidity',              '-',    'Relative Humidity Cabin');
            oLog.addValue('Example:s:Cabin.toPhases.CabinAir', 'afPP(this.oMT.tiN2I.CO2)',  'Pa',   'Partial Pressure CO2');
            oLog.addValue('Example:s:Cabin.toPhases.CabinAir', 'fTemperature',              'K',    'Temperature Atmosphere');
            
            oLog.addValue('Example:c:CCAA:s:CHX.toPhases.CHX_PhaseIn', 'fTemperature',      'K',    'Temperature CHX');
            oLog.addValue('Example:c:CCAA:s:CHX.toPhases.CHX_PhaseIn', 'fPressure',         'Pa',   'Pressure CHX');
            oLog.addValue('Example:c:CCAA:s:CHX.toProcsP2P.CondensingHX', 'fFlowRate',      'kg/s', 'Condensate Flowrate CHX');
            
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
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_Air_In_1.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)', 'kg/s', 'CDRA CO2 Inlet Flow 1');
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_Air_In_2.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)', 'kg/s', 'CDRA CO2 Inlet Flow 2');
            
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_Air_In_1.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)', 'kg/s', 'CDRA H2O Inlet Flow 1');
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_Air_In_2.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)', 'kg/s', 'CDRA H2O Inlet Flow 2');
            
            % CDRA Out
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_Air_Out_1.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)', 'kg/s', 'CDRA CO2 Outlet Flow 1');
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_Air_Out_2.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)', 'kg/s', 'CDRA CO2 Outlet Flow 2');
            
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_Air_Out_1.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)', 'kg/s', 'CDRA H2O Outlet Flow 1');
            oLog.addValue('Example:c:CDRA.toBranches.CDRA_Air_Out_2.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)', 'kg/s', 'CDRA H2O Outlet Flow 2');
            
            %% Define plots
            
            oPlot = this.toMonitors.oPlotter;
            
            oPlot.definePlot('K', 'Tank Temperatures');
            oPlot.definePlot('Pa', 'Tank Pressures');
            oPlot.definePlot('kg', 'Tank Masses');
            
            csCDRA_CO2_Mass             = cell(3,2,5);
            csCDRA_H2O_Mass             = cell(3,2,5);
            csCDRA_CO2_Pressure         = cell(3,2,5);
            csCDRA_H2O_Pressure         = cell(3,2,5);
            csCDRA_Flow_Temperature     = cell(3,2,5);
            csCDRA_Absorber_Temperature = cell(3,2,5);
            
            csType = {'Sylobead_', 'Zeolite13x_', 'Zeolite5A_'};
            for iType = 1:3
                for iBed = 1:2
                    for iCell = 1:5
                         csCDRA_CO2_Mass{iType,iBed,iCell}              = ['Partial Mass CO2 ',     csType{iType}, num2str(iBed),' Cell ',num2str(iCell)];
                         csCDRA_H2O_Mass{iType,iBed,iCell}              = ['Partial Mass H2O ',     csType{iType}, num2str(iBed),' Cell ',num2str(iCell)];

                         csCDRA_CO2_Pressure{iType,iBed,iCell}          = ['Flow Pressure CO2 ',    csType{iType}, num2str(iBed),' Cell ',num2str(iCell)];
                         csCDRA_H2O_Pressure{iType,iBed,iCell}          = ['Flow Pressure H2O ',    csType{iType}, num2str(iBed),' Cell ',num2str(iCell)];

                         csCDRA_Flow_Temperature{iType,iBed,iCell}      = ['Flow Temperature ',     csType{iType}, num2str(iBed),' Cell ',num2str(iCell)];
                         csCDRA_Absorber_Temperature{iType,iBed,iCell}  = ['Absorber Temperature ', csType{iType}, num2str(iBed),' Cell ',num2str(iCell)];
                    end
                end
            end
            
            oPlot.definePlot(csCDRA_CO2_Mass,               'Partial Mass CO2 CDRA');
            oPlot.definePlot(csCDRA_H2O_Mass,               'Partial Mass H2O CDRA');
            oPlot.definePlot(csCDRA_CO2_Pressure,           'Partial Pressure CO2 CDRA');
            oPlot.definePlot(csCDRA_H2O_Pressure,           'Partial Pressure H2O CDRA');
            oPlot.definePlot(csCDRA_Flow_Temperature,       'Flow Temperature CDRA');
            oPlot.definePlot(csCDRA_Absorber_Temperature,   'Absorber Temperature CDRA');
            
            csNames = {'- 1 * ( CDRA CO2 Inlet Flow 1 + CDRA CO2 Inlet Flow 2 )', 'CDRA CO2 Outlet Flow 1 + CDRA CO2 Outlet Flow 2'};
            oPlot.definePlot(csNames,  'CDRA CO2 Flowrates');
            
            csNames = {'- 1 * ( CDRA H2O Inlet Flow 1 + CDRA H2O Inlet Flow 2 )', 'CDRA H2O Outlet Flow 1 + CDRA H2O Outlet Flow 2'};
            oPlot.definePlot(csNames, 'CDRA H2O Flowrates');
            
            csNames = {'Condensate Flowrate CHX'};
            oPlot.definePlot(csNames, 'CHX Condensate Flowrate');
            
            csNames = {'Partial Pressure CO2'};
            oPlot.definePlot(csNames, 'Partial Pressure CO2 Habitat');
            
            csNames = {'Partial Pressure CO2 / 133.322'};
            oPlot.definePlot(csNames, 'Partial Pressure CO2 Habitat Torr');
            
            csNames = {'Relative Humidity Cabin * 100'};
            oPlot.definePlot(csNames, 'Relative Humidity Habitat');
            
        end
        
        function plot(this) % Plotting the results
            % See http://www.mathworks.de/de/help/matlab/ref/plot.html for
            % further information
            close all
            
%             hCDRA_InletCalc = @(x1,x2,x3,x4)(-(x1 .* x2 + x3 .* x4));
%             csLogVariables =  {'CDRA Air Inlet Flow 1','CDRA CO2 Inlet Partialratio 1','CDRA Air Inlet Flow 2','CDRA CO2 Inlet Partialratio 2'};
%             sNewLogName = 'CDRA CO2 Inlet Flow';
%             this.toMonitors.oPlotter.MathematicOperationOnLog(csLogVariables, hCDRA_InletCalc, sNewLogName, 'kg/s');
%             
%             hCDRA_OutletCalc = @(x1,x2,x3,x4)((x1 .* x2 + x3 .* x4));
%             csLogVariables =  {'CDRA Air Outlet Flow 1','CDRA CO2 Outlet Partialratio 1','CDRA Air Outlet Flow 2','CDRA CO2 Outlet Partialratio 2'};
%             sNewLogName = 'CDRA CO2 Outlet Flow';
%             this.toMonitors.oPlotter.MathematicOperationOnLog(csLogVariables, hCDRA_OutletCalc, sNewLogName, 'kg/s');
%             
%             csLogVariables =  {'CDRA Air Inlet Flow 1','CDRA H2O Inlet Partialratio 1','CDRA Air Inlet Flow 2','CDRA H2O Inlet Partialratio 2'};
%             sNewLogName = 'CDRA H2O Inlet Flow';
%             this.toMonitors.oPlotter.MathematicOperationOnLog(csLogVariables, hCDRA_InletCalc, sNewLogName, 'kg/s');
%             
%             csLogVariables =  {'CDRA Air Outlet Flow 1','CDRA H2O Outlet Partialratio 1','CDRA Air Outlet Flow 2','CDRA H2O Outlet Partialratio 2'};
%             sNewLogName = 'CDRA H2O Outlet Flow';
%             this.toMonitors.oPlotter.MathematicOperationOnLog(csLogVariables, hCDRA_OutletCalc, sNewLogName, 'kg/s');
%             
%             hPascalToTorr = @(x1)(x1./133.322368);
%             csLogVariables =  {'Partial Pressure CO2'};
%             sNewLogName = 'Partial Pressure CO2 in Torr';
%             this.toMonitors.oPlotter.MathematicOperationOnLog(csLogVariables, hPascalToTorr, sNewLogName, 'Torr');
%             
            tParameters.sTimeUnit = 'h';
            
            this.toMonitors.oPlotter.plot(tParameters);
            
            return
            
        end
    end
end
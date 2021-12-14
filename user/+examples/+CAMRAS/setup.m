classdef setup < simulation.infrastructure
    %SETUP Setup file for the Greenhouse system
    
    properties
        tmCultureParametersValues = struct();
        tiCultureParametersIndex = struct();
    end
    
    methods
        function this = setup(ptConfigParams, tSolverParams)
            % Possible to change the constructor paths and params for the
            % monitors
            ttMonitorConfig = struct('oLogger', struct('cParams', {{ true }}));
            
            % call superconstructor (with possible altered monitor configs)
            this@simulation.infrastructure('CAMRAS_Test_Rig', ptConfigParams, tSolverParams, ttMonitorConfig);
            
%             warning('off', 'all');
            
            % Create Root Object - Initializing system 'Greenhouse'
            examples.CAMRAS.systems.Example(this.oSimulationContainer, 'CAMRAS_Test_Rig');
            
            % set simulation time
            this.fSimTime  = 1 * 9 * 3600 ;
            
            % if true, use fSimTime for simulation duration, if false use
            % iSimTicks below
            this.bUseTime  = true;
        end
        
        function configureMonitors(this)
            %% Logging Setup
            oLog = this.toMonitors.oLogger;
            
            
            %% Atmosphere Store
            oLog.addValue('CAMRAS_Test_Rig.toStores.Atmosphere.toPhases.Atmosphere_Phase_1', 'fPressure', 'Pa',  'Atmosphere Total Pressure');
            oLog.addValue('CAMRAS_Test_Rig.toStores.Atmosphere.toPhases.Atmosphere_Phase_1', 'afPP(this.oMT.tiN2I.H2O)', 'Pa',  'Atmosphere Partial Pressure H2O');
            oLog.addValue('CAMRAS_Test_Rig.toStores.Atmosphere.toPhases.Atmosphere_Phase_1', 'afPP(this.oMT.tiN2I.CO2)', 'Pa',  'Atmosphere Partial Pressure CO2');
            
            oLog.addValue('CAMRAS_Test_Rig.toStores.Atmosphere.toPhases.Atmosphere_Phase_1', 'fMass', 'kg',  'Atmosphere Total Mass');
            
            %% Camras 1
            
            % Filter A
            oLog.addValue('CAMRAS_Test_Rig.toChildren.CAMRAS.toStores.Filter_A.toPhases.PhaseIn',           'fMass',                        'kg',  'Mass Filter A Phase');
            oLog.addValue('CAMRAS_Test_Rig.toChildren.CAMRAS.toStores.Filter_A.toPhases.FilteredPhaseH2O',  'afMass(this.oMT.tiN2I.H2O)',   'kg',  'Mass H2O Absorbed in Filter A');
            oLog.addValue('CAMRAS_Test_Rig.toChildren.CAMRAS.toStores.Filter_A.toPhases.FilteredPhaseCO2',  'afMass(this.oMT.tiN2I.CO2)',   'kg',  'Mass CO2 Absorbed in Filter A');
            
            oLog.addValue('CAMRAS_Test_Rig.toChildren.CAMRAS.toStores.Filter_A.toPhases.PhaseIn', 'fPressure', 'Pa',  'Pressure Filter A Phase');

                       
            % Filter B
            oLog.addValue('CAMRAS_Test_Rig.toChildren.CAMRAS.toStores.Filter_B.toPhases.PhaseIn', 'fMass', 'kg',  'Mass Filter B Phase');
            oLog.addValue('CAMRAS_Test_Rig.toChildren.CAMRAS.toStores.Filter_B.toPhases.FilteredPhaseH2O', 'afMass(this.oMT.tiN2I.H2O)', 'kg',  'Mass H2O Absorbed in Filter B');
            oLog.addValue('CAMRAS_Test_Rig.toChildren.CAMRAS.toStores.Filter_B.toPhases.FilteredPhaseCO2', 'afMass(this.oMT.tiN2I.CO2)', 'kg',  'Mass CO2 Absorbed in Filter B');
            
            oLog.addValue('CAMRAS_Test_Rig.toChildren.CAMRAS.toStores.Filter_B.toPhases.PhaseIn', 'fPressure', 'Pa',  'Pressure Filter B Phase');
            
            % FlowRates
            oLog.addValue('CAMRAS_Test_Rig.toChildren.CAMRAS.aoBranches(9, 1).aoFlows', 'fFlowRate', 'kg/s',  'FlowRate Pressure Equalization'); 
            
            % Filter A
            oLog.addValue('CAMRAS_Test_Rig.toChildren.CAMRAS.aoBranches(7, 1).aoFlows', 'fFlowRate', 'kg/s',  'Filter A to Vacuum');
            oLog.addValue('CAMRAS_Test_Rig.toChildren.CAMRAS.aoBranches(6, 1).aoFlows', 'fFlowRate', 'kg/s',  'Filter A Desorb');     
            
             % Filter B
            oLog.addValue('CAMRAS_Test_Rig.toChildren.CAMRAS.aoBranches(3, 1).aoFlows', 'fFlowRate', 'kg/s',  'Filter B to Vacuum');
            oLog.addValue('CAMRAS_Test_Rig.toChildren.CAMRAS.aoBranches(2, 1).aoFlows', 'fFlowRate', 'kg/s',  'Filter B Desorb');
            

            
            % Inlet and Outlet CO2 and H2O FlowRate

            
            oLog.addValue('CAMRAS_Test_Rig:c:CAMRAS.toBranches.CAMRAS_Air_In_C1.aoFlows(1)', 'fFlowRate', 'kg/s', 'CAMRAS Inlet Flow 1');
            oLog.addValue('CAMRAS_Test_Rig:c:CAMRAS.toBranches.CAMRAS_Air_In_C2.aoFlows(1)', 'fFlowRate', 'kg/s', 'CAMRAS Inlet Flow 2');
            
            
            % CAMRAS Out
            oLog.addValue('CAMRAS_Test_Rig:c:CAMRAS.toBranches.CAMRAS_Air_Out_C1.aoFlows(1)', 'fFlowRate', 'kg/s', 'CAMRAS Outlet Flow 1');
            oLog.addValue('CAMRAS_Test_Rig:c:CAMRAS.toBranches.CAMRAS_Air_Out_C2.aoFlows(1)', 'fFlowRate', 'kg/s', 'CAMRAS Outlet Flow 2');
            

            % Inlet and Outlet CO2 and H2O PartialFlows
            
            % CAMRAS In
            oLog.addValue('CAMRAS_Test_Rig:c:CAMRAS.toBranches.CAMRAS_Air_In_C1.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)', 'kg/s', 'CAMRAS CO2 Inlet Flow 1');
            oLog.addValue('CAMRAS_Test_Rig:c:CAMRAS.toBranches.CAMRAS_Air_In_C2.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)', 'kg/s', 'CAMRAS CO2 Inlet Flow 2');
            
            oLog.addValue('CAMRAS_Test_Rig:c:CAMRAS.toBranches.CAMRAS_Air_In_C1.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)', 'kg/s', 'CAMRAS H2O Inlet Flow 1');
            oLog.addValue('CAMRAS_Test_Rig:c:CAMRAS.toBranches.CAMRAS_Air_In_C2.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)', 'kg/s', 'CAMRAS H2O Inlet Flow 2');
            
            
            % CAMRAS Out
            oLog.addValue('CAMRAS_Test_Rig:c:CAMRAS.toBranches.CAMRAS_Air_Out_C1.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)', 'kg/s', 'CAMRAS CO2 Outlet Flow 1');
            oLog.addValue('CAMRAS_Test_Rig:c:CAMRAS.toBranches.CAMRAS_Air_Out_C2.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)', 'kg/s', 'CAMRAS CO2 Outlet Flow 2');
            
            oLog.addValue('CAMRAS_Test_Rig:c:CAMRAS.toBranches.CAMRAS_Air_Out_C1.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)', 'kg/s', 'CAMRAS H2O Outlet Flow 1');
            oLog.addValue('CAMRAS_Test_Rig:c:CAMRAS.toBranches.CAMRAS_Air_Out_C2.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)', 'kg/s', 'CAMRAS H2O Outlet Flow 2');
            
             % Efficiencies Filter A
            oLog.addValue('CAMRAS_Test_Rig.toChildren.CAMRAS.toStores.Filter_A.toProcsP2P.FilterAH2O', 'fEfficiencyAveraged', '-',  'Averaged Efficiency Filter A H2O');
            oLog.addValue('CAMRAS_Test_Rig.toChildren.CAMRAS.toStores.Filter_A.toProcsP2P.FilterACO2', 'fEfficiencyAveraged', '-',  'Averaged Efficiency Filter A CO2');
            
            oLog.addValue('CAMRAS_Test_Rig.toChildren.CAMRAS.toStores.Filter_A.toProcsP2P.FilterAH2O', 'fEfficiency', '-',  'Efficiency Filter A H2O');
            oLog.addValue('CAMRAS_Test_Rig.toChildren.CAMRAS.toStores.Filter_A.toProcsP2P.FilterACO2', 'fEfficiency', '-',  'Efficiency Filter A CO2');
            
            % Efficiencies Filter B
            oLog.addValue('CAMRAS_Test_Rig.toChildren.CAMRAS.toStores.Filter_B.toProcsP2P.FilterBH2O', 'fEfficiencyAveraged', '-',  'Averaged Efficiency Filter B H2O');
            oLog.addValue('CAMRAS_Test_Rig.toChildren.CAMRAS.toStores.Filter_B.toProcsP2P.FilterBCO2', 'fEfficiencyAveraged', '-',  'Averaged Efficiency Filter B CO2');
            
            oLog.addValue('CAMRAS_Test_Rig.toChildren.CAMRAS.toStores.Filter_B.toProcsP2P.FilterBH2O', 'fEfficiency', '-',  'Efficiency Filter B H2O');
            oLog.addValue('CAMRAS_Test_Rig.toChildren.CAMRAS.toStores.Filter_B.toProcsP2P.FilterBCO2', 'fEfficiency', '-',  'Efficiency Filter B CO2');
            
            oLog.addValue('CAMRAS_Test_Rig.toChildren.CAMRAS.toStores.Filter_A.toPhases.PhaseIn', 'afMass(this.oMT.tiN2I.H2O)', 'kg',  'Partial Mass H2O PhaseIn Filter A');
            oLog.addValue('CAMRAS_Test_Rig.toChildren.CAMRAS.toStores.Filter_A.toPhases.PhaseIn', 'afMass(this.oMT.tiN2I.CO2)', 'kg',  'Partial Mass CO2 PhaseIn Filter A');
            oLog.addValue('CAMRAS_Test_Rig.toChildren.CAMRAS.toStores.Filter_B.toPhases.PhaseIn', 'afMass(this.oMT.tiN2I.H2O)', 'kg',  'Partial Mass H2O PhaseIn Filter B');
            oLog.addValue('CAMRAS_Test_Rig.toChildren.CAMRAS.toStores.Filter_B.toPhases.PhaseIn', 'afMass(this.oMT.tiN2I.CO2)', 'kg',  'Partial Mass CO2 PhaseIn Filter B');
            
            
             %% Camras 2
            
            % Filter A
            oLog.addValue('CAMRAS_Test_Rig.toChildren.CAMRAS_2.toStores.Filter_A.toPhases.PhaseIn', 'fMass', 'kg',  'Mass Filter A Phase Camras 2');
            oLog.addValue('CAMRAS_Test_Rig.toChildren.CAMRAS_2.toStores.Filter_A.toPhases.FilteredPhaseH2O', 'afMass(this.oMT.tiN2I.H2O)', 'kg',  'Mass H2O Absorbed in Filter A Camras 2');
            oLog.addValue('CAMRAS_Test_Rig.toChildren.CAMRAS_2.toStores.Filter_A.toPhases.FilteredPhaseCO2', 'afMass(this.oMT.tiN2I.CO2)', 'kg',  'Mass CO2 Absorbed in Filter A Camras 2');
            
            oLog.addValue('CAMRAS_Test_Rig.toChildren.CAMRAS_2.toStores.Filter_A.toPhases.PhaseIn', 'fPressure', 'Pa',  'Pressure Filter A Phase Camras 2');

                       
            % Filter B
            oLog.addValue('CAMRAS_Test_Rig.toChildren.CAMRAS_2.toStores.Filter_B.toPhases.PhaseIn', 'fMass', 'kg',  'Mass Filter B Phase Camras 2');
            oLog.addValue('CAMRAS_Test_Rig.toChildren.CAMRAS_2.toStores.Filter_B.toPhases.FilteredPhaseH2O', 'afMass(this.oMT.tiN2I.H2O)', 'kg',  'Mass H2O Absorbed in Filter B Camras 2');
            oLog.addValue('CAMRAS_Test_Rig.toChildren.CAMRAS_2.toStores.Filter_B.toPhases.FilteredPhaseCO2', 'afMass(this.oMT.tiN2I.CO2)', 'kg',  'Mass CO2 Absorbed in Filter B Camras 2');
            
            oLog.addValue('CAMRAS_Test_Rig.toChildren.CAMRAS_2.toStores.Filter_B.toPhases.PhaseIn', 'fPressure', 'Pa',  'Pressure Filter B Phase Camras 2');
            
            % FlowRates
            oLog.addValue('CAMRAS_Test_Rig.toChildren.CAMRAS_2.aoBranches(9, 1).aoFlows', 'fFlowRate', 'kg/s',  'FlowRate Pressure Equalization Camras 2'); 
            
            % Filter A
            oLog.addValue('CAMRAS_Test_Rig.toChildren.CAMRAS_2.aoBranches(7, 1).aoFlows', 'fFlowRate', 'kg/s',  'Filter A to Vacuum Camras 2');
            oLog.addValue('CAMRAS_Test_Rig.toChildren.CAMRAS_2.aoBranches(6, 1).aoFlows', 'fFlowRate', 'kg/s',  'Filter A Desorb Camras 2');     
            
             % Filter B
            oLog.addValue('CAMRAS_Test_Rig.toChildren.CAMRAS_2.aoBranches(3, 1).aoFlows', 'fFlowRate', 'kg/s',  'Filter B to Vacuum Camras 2');
            oLog.addValue('CAMRAS_Test_Rig.toChildren.CAMRAS_2.aoBranches(2, 1).aoFlows', 'fFlowRate', 'kg/s',  'Filter B Desorb Camras 2');
            
            
            % Inlet and Outlet CO2 and H2O FlowRate

            
            oLog.addValue('CAMRAS_Test_Rig:c:CAMRAS_2.toBranches.CAMRAS_Air_In_C1.aoFlows(1)', 'fFlowRate', 'kg/s', 'CAMRAS Inlet Flow 1 Camras 2');
            oLog.addValue('CAMRAS_Test_Rig:c:CAMRAS_2.toBranches.CAMRAS_Air_In_C2.aoFlows(1)', 'fFlowRate', 'kg/s', 'CAMRAS Inlet Flow 2 Camras 2');
            
            
            % CAMRAS Out
            oLog.addValue('CAMRAS_Test_Rig:c:CAMRAS_2.toBranches.CAMRAS_Air_Out_C1.aoFlows(1)', 'fFlowRate', 'kg/s', 'CAMRAS Outlet Flow 1 Camras 2');
            oLog.addValue('CAMRAS_Test_Rig:c:CAMRAS_2.toBranches.CAMRAS_Air_Out_C2.aoFlows(1)', 'fFlowRate', 'kg/s', 'CAMRAS Outlet Flow 2 Camras 2');
            

            % Inlet and Outlet CO2 and H2O PartialFlows
            
            % CAMRAS In
            oLog.addValue('CAMRAS_Test_Rig:c:CAMRAS_2.toBranches.CAMRAS_Air_In_C1.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)', 'kg/s', 'CAMRAS CO2 Inlet Flow 1 Camras 2');
            oLog.addValue('CAMRAS_Test_Rig:c:CAMRAS_2.toBranches.CAMRAS_Air_In_C2.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)', 'kg/s', 'CAMRAS CO2 Inlet Flow 2 Camras 2');
            
            oLog.addValue('CAMRAS_Test_Rig:c:CAMRAS_2.toBranches.CAMRAS_Air_In_C1.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)', 'kg/s', 'CAMRAS H2O Inlet Flow 1 Camras 2');
            oLog.addValue('CAMRAS_Test_Rig:c:CAMRAS_2.toBranches.CAMRAS_Air_In_C2.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)', 'kg/s', 'CAMRAS H2O Inlet Flow 2 Camras 2');
            
            
            % CAMRAS Out
            oLog.addValue('CAMRAS_Test_Rig:c:CAMRAS_2.toBranches.CAMRAS_Air_Out_C1.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)', 'kg/s', 'CAMRAS CO2 Outlet Flow 1 Camras 2');
            oLog.addValue('CAMRAS_Test_Rig:c:CAMRAS_2.toBranches.CAMRAS_Air_Out_C2.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)', 'kg/s', 'CAMRAS CO2 Outlet Flow 2 Camras 2');
            
            oLog.addValue('CAMRAS_Test_Rig:c:CAMRAS_2.toBranches.CAMRAS_Air_Out_C1.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)', 'kg/s', 'CAMRAS H2O Outlet Flow 1 Camras 2');
            oLog.addValue('CAMRAS_Test_Rig:c:CAMRAS_2.toBranches.CAMRAS_Air_Out_C2.aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)', 'kg/s', 'CAMRAS H2O Outlet Flow 2 Camras 2');
            
             % Efficiencies Filter A
            oLog.addValue('CAMRAS_Test_Rig.toChildren.CAMRAS_2.toStores.Filter_A.toProcsP2P.FilterAH2O', 'fEfficiencyAveraged', '-',  'Averaged Efficiency Filter A H2O Camras 2');
            oLog.addValue('CAMRAS_Test_Rig.toChildren.CAMRAS_2.toStores.Filter_A.toProcsP2P.FilterACO2', 'fEfficiencyAveraged', '-',  'Averaged Efficiency Filter A CO2 Camras 2');
            
            oLog.addValue('CAMRAS_Test_Rig.toChildren.CAMRAS_2.toStores.Filter_A.toProcsP2P.FilterAH2O', 'fEfficiency', '-',  'Efficiency Filter A H2O Camras 2');
            oLog.addValue('CAMRAS_Test_Rig.toChildren.CAMRAS_2.toStores.Filter_A.toProcsP2P.FilterACO2', 'fEfficiency', '-',  'Efficiency Filter A CO2 Camras 2');
            
            % Efficiencies Filter B
            oLog.addValue('CAMRAS_Test_Rig.toChildren.CAMRAS_2.toStores.Filter_B.toProcsP2P.FilterBH2O', 'fEfficiencyAveraged', '-',  'Averaged Efficiency Filter B H2O Camras 2');
            oLog.addValue('CAMRAS_Test_Rig.toChildren.CAMRAS_2.toStores.Filter_B.toProcsP2P.FilterBCO2', 'fEfficiencyAveraged', '-',  'Averaged Efficiency Filter B CO2 Camras 2');
            
            oLog.addValue('CAMRAS_Test_Rig.toChildren.CAMRAS_2.toStores.Filter_B.toProcsP2P.FilterBH2O', 'fEfficiency', '-',  'Efficiency Filter B H2O Camras 2');
            oLog.addValue('CAMRAS_Test_Rig.toChildren.CAMRAS_2.toStores.Filter_B.toProcsP2P.FilterBCO2', 'fEfficiency', '-',  'Efficiency Filter B CO2 Camras 2');
            
            oLog.addValue('CAMRAS_Test_Rig.toChildren.CAMRAS_2.toStores.Filter_A.toPhases.PhaseIn', 'afMass(this.oMT.tiN2I.H2O)', 'kg',  'Partial Mass H2O PhaseIn Filter A Camras 2');
            oLog.addValue('CAMRAS_Test_Rig.toChildren.CAMRAS_2.toStores.Filter_A.toPhases.PhaseIn', 'afMass(this.oMT.tiN2I.CO2)', 'kg',  'Partial Mass CO2 PhaseIn Filter A Camras 2');
            oLog.addValue('CAMRAS_Test_Rig.toChildren.CAMRAS_2.toStores.Filter_B.toPhases.PhaseIn', 'afMass(this.oMT.tiN2I.H2O)', 'kg',  'Partial Mass H2O PhaseIn Filter B Camras 2');
            oLog.addValue('CAMRAS_Test_Rig.toChildren.CAMRAS_2.toStores.Filter_B.toPhases.PhaseIn', 'afMass(this.oMT.tiN2I.CO2)', 'kg',  'Partial Mass CO2 PhaseIn Filter B Camras 2');
            
            
            
            %% Vacuum Mass
            oLog.addValue('CAMRAS_Test_Rig.toStores.Vacuum.toPhases.Vacuum_Phase', 'fMass', 'kg',  'Vacuum Mass');
           
            %% H2O and CO2 Supply
            oLog.addValue('CAMRAS_Test_Rig.toBranches.CO2BufferSupply.aoFlows', 'fFlowRate', 'kg/s',  'CO2 Human Simulator Flowrate');
            oLog.addValue('CAMRAS_Test_Rig.toBranches.H2OBufferSupply.aoFlows', 'fFlowRate', 'kg/s',  'H2O Human Simulator Flowrate');
            oLog.addValue('CAMRAS_Test_Rig.toBranches.N2BufferSupply.aoFlows', 'fFlowRate', 'kg/s',  'N2 Buffer Flowrate');
            oLog.addValue('CAMRAS_Test_Rig.toBranches.O2BufferSupply.aoFlows', 'fFlowRate', 'kg/s',  'O2 Buffer Flowrate');
            
            oLog.addVirtualValue('"Averaged Efficiency Filter A CO2" + "Averaged Efficiency Filter B CO2"',                     '-', 'Averaged Efficiency CO2 CAMRAS 1');
            oLog.addVirtualValue('"Efficiency Filter A CO2" + "Efficiency Filter B CO2"',                                       '-', 'Efficiency CO2 CAMRAS 1');
            oLog.addVirtualValue('"Averaged Efficiency Filter A H2O" + "Averaged Efficiency Filter B H2O"',                     '-', 'Averaged Efficiency H2O CAMRAS 1');
            oLog.addVirtualValue('"Efficiency Filter A H2O" + "Efficiency Filter B H2O"',                                       '-', 'Efficiency H2O CAMRAS 1');
            
            oLog.addVirtualValue('"Averaged Efficiency Filter A CO2 Camras 2" + "Averaged Efficiency Filter B CO2 Camras 2"',  	'-', 'Averaged Efficiency CO2 CAMRAS 2');
            oLog.addVirtualValue('"Efficiency Filter A CO2 Camras 2" + "Efficiency Filter B CO2 Camras 2"',                    	'-', 'Efficiency CO2 CAMRAS 2');
            oLog.addVirtualValue('"Averaged Efficiency Filter A H2O Camras 2" + "Averaged Efficiency Filter B H2O Camras 2"',  	'-', 'Averaged Efficiency H2O CAMRAS 2');
            oLog.addVirtualValue('"Efficiency Filter A H2O Camras 2" + "Efficiency Filter B H2O Camras 2"',                    	'-', 'Efficiency H2O CAMRAS 2');
            
            oLog.addVirtualValue('( "CAMRAS CO2 Inlet Flow 1" + "CAMRAS CO2 Inlet Flow 2" ) ./ ( "CAMRAS Inlet Flow 1" + "CAMRAS Inlet Flow 2" )',	'-', 'Inlet Mass Ratio CO2');
            oLog.addVirtualValue('( "CAMRAS H2O Inlet Flow 1" + "CAMRAS H2O Inlet Flow 2" ) ./ ( "CAMRAS Inlet Flow 1" + "CAMRAS Inlet Flow 2" )',	'-', 'Inlet Mass Ratio H2O');
            
            oLog.addVirtualValue('( "CO2 Human Simulator Flowrate" ) .* 60000',	'g/min', 'Human CO2 Flowrate');
            oLog.addVirtualValue('( "H2O Human Simulator Flowrate" ) .* 60000',	'g/min', 'Human H2O Flowrate');
            oLog.addVirtualValue('( "N2 Buffer Flowrate" ) .* 60000',            'g/min', 'N2 Buffer Flowrate');
            oLog.addVirtualValue('( "O2 Buffer Flowrate" ) .* 60000',            'g/min', 'O2 Buffer Flowrate');
            
        end
        function plot(this) % Plotting the results
            %% Define Plot
            
            oPlotter = plot@simulation.infrastructure(this);
            
            close all
            try
                this.toMonitors.oLogger.readDataFromMat;
            catch
                disp('no data outputted yet')
            end
            
            tPlotOptions.sTimeUnit = 'minutes';
            
            %% Atmosphere
            
            cNames = {'"Atmosphere Total Pressure"'};
            coPlots{1,1} = oPlotter.definePlot(cNames, 'Atmosphere Total Pressure', tPlotOptions);
            
            
            cNames = {'"Atmosphere Partial Pressure H2O"','"Atmosphere Partial Pressure CO2"'};
            coPlots{1,2} = oPlotter.definePlot(cNames, 'Atmosphere Pressures', tPlotOptions);
            
            cNames = {'"Atmosphere Total Mass"'};
            coPlots{2,1} = oPlotter.definePlot(cNames, 'Atmosphere Total Mass', tPlotOptions);
            
            oPlotter.defineFigure(coPlots,  'Atmosphere');
            %% Camras 1
            
            % Filter A
            coPlots = cell(0);
            cNames = {'"Mass Filter A Phase"','"Mass H2O Absorbed in Filter A"','"Mass CO2 Absorbed in Filter A"'};
            coPlots{1,1} = oPlotter.definePlot(cNames, 'Masses in Filter A', tPlotOptions);
                   
            % Filter B
            cNames = {'"Mass Filter B Phase"','"Mass H2O Absorbed in Filter B"','"Mass CO2 Absorbed in Filter B"'};
            coPlots{1,2} = oPlotter.definePlot(cNames, 'Masses', tPlotOptions);                  
            
            % Filter A and B 
            cNames = {'"Pressure Filter A Phase"','"Pressure Filter B Phase"'};
            coPlots{2,1} = oPlotter.definePlot(cNames, 'Pressure Filter A and B', tPlotOptions);

            cNames = {'"Mass Filter A Phase"','"Mass Filter B Phase"'};
            coPlots{2,2} = oPlotter.definePlot(cNames, 'Mass Filter A and B', tPlotOptions);
            
            oPlotter.defineFigure(coPlots,  'CAMRAS 1 Masses and Pressures');
            
            coPlots = cell(0);
            cNames = {'"Filter A to Vacuum"','"Filter A Desorb"','"Filter B to Vacuum"','"Filter B Desorb"'};
            coPlots{1,1} = oPlotter.definePlot(cNames, 'Flow Rate Desorb and Vacuum', tPlotOptions);
            
            
            % CAMRAS Inlet and Outlet CO2 and H2O Flows
            csNames = {'"CAMRAS Inlet Flow 1"' , '"CAMRAS Inlet Flow 2"', '"CAMRAS Outlet Flow 1"' , '"CAMRAS Outlet Flow 2"'};
            sTitle = 'CAMRAS Flowrates'; 
            coPlots{1,2} = oPlotter.definePlot(csNames, sTitle, tPlotOptions);
             
            % CAMRAS Inlet and Outlet CO2 and H2O Flows
            csNames = {'"CAMRAS CO2 Inlet Flow 1"' , '"CAMRAS CO2 Inlet Flow 2"', '"CAMRAS CO2 Outlet Flow 1"' , '"CAMRAS CO2 Outlet Flow 2"'};
            sTitle = 'CAMRAS CO2 Flowrates'; 
            coPlots{2,1} = oPlotter.definePlot(csNames, sTitle, tPlotOptions);
            
            csNames = {'"CAMRAS H2O Inlet Flow 1"',  '"CAMRAS H2O Inlet Flow 2"', '"CAMRAS H2O Outlet Flow 1"' ,  '"CAMRAS H2O Outlet Flow 2"'};
            sTitle = 'CAMRAS H2O Flowrates'; 
            coPlots{2,2} = oPlotter.definePlot(csNames, sTitle, tPlotOptions);
            
            oPlotter.defineFigure(coPlots,  'CAMRAS 1 Flows');
            
            % Efficiencies  
            coPlots = cell(0);
            csNames = {'"Averaged Efficiency CO2 CAMRAS 1"', '"Efficiency CO2 CAMRAS 1"'};
            sTitle = 'Removal Efficiencies CO2'; 
            coPlots{1,1} = oPlotter.definePlot(csNames, sTitle, tPlotOptions);
            
            csNames = {'"Averaged Efficiency H2O CAMRAS 1"', '"Efficiency H2O CAMRAS 1"'};
            sTitle = 'Removal Efficiencies H2O'; 
            coPlots{1,2} = oPlotter.definePlot(csNames, sTitle, tPlotOptions);
            
            % Partial Mass in FilterIn Phase
            csNames = {'"Partial Mass H2O PhaseIn Filter A"', '"Partial Mass CO2 PhaseIn Filter A"'};
            sTitle = 'Partial Mass in Phase In Filter A'; 
            coPlots{2,1} = oPlotter.definePlot(csNames, sTitle, tPlotOptions);
            
            csNames = {'"Partial Mass H2O PhaseIn Filter B"', '"Partial Mass CO2 PhaseIn Filter B"'};
            sTitle = 'Partial Mass in Phase In Filter B'; 
            coPlots{2,2} = oPlotter.definePlot(csNames, sTitle, tPlotOptions);
            
            oPlotter.defineFigure(coPlots,  'CAMRAS 1 Efficiencies and Partila Masses');
            
            %% Camras 2
            
            coPlots = cell(0);
            % Filter A
            cNames = {'"Mass Filter A Phase Camras 2"','"Mass H2O Absorbed in Filter A Camras 2"','"Mass CO2 Absorbed in Filter A Camras 2"'};
            coPlots{1,1} = oPlotter.definePlot(cNames, 'Masses in Filter A Camras 2');
                   
            % Filter B
            cNames = {'"Mass Filter B Phase Camras 2"','"Mass H2O Absorbed in Filter B Camras 2"','"Mass CO2 Absorbed in Filter B Camras 2"'};
            coPlots{1,2} = oPlotter.definePlot(cNames, 'Masses Camras 2');                  
            
            % Filter A and B 
            cNames = {'"Pressure Filter A Phase Camras 2"','"Pressure Filter B Phase Camras 2"'};
            coPlots{2,1} = oPlotter.definePlot(cNames, 'Pressure Filter A and B Camras 2');

            cNames = {'"Mass Filter A Phase Camras 2"','"Mass Filter B Phase Camras 2"'};
            coPlots{2,2} = oPlotter.definePlot(cNames, 'Mass Filter A and B Camras 2');
            
            oPlotter.defineFigure(coPlots,  'CAMRAS 2 Masses and Pressures');
            
            coPlots = cell(0);
            cNames = {'"Filter A to Vacuum Camras 2"','"Filter A Desorb Camras 2"','"Filter B to Vacuum Camras 2"','"Filter B Desorb Camras 2"'};
            coPlots{1,1} = oPlotter.definePlot(cNames, 'Flow Rate Desorb and Vacuum');
            
            
            % CAMRAS Inlet and Outlet CO2 and H2O Flows
            csNames = {'"CAMRAS Inlet Flow 1 Camras 2"' , '"CAMRAS Inlet Flow 2 Camras 2"', '"CAMRAS Outlet Flow 1 Camras 2"' , '"CAMRAS Outlet Flow 2 Camras 2"'};
            sTitle = 'CAMRAS Flowrates Camras 2'; 
            coPlots{1,2} = oPlotter.definePlot(csNames, sTitle, tPlotOptions);
             
            % CAMRAS Inlet and Outlet CO2 and H2O Flows
            csNames = {'"CAMRAS CO2 Inlet Flow 1 Camras 2"' , '"CAMRAS CO2 Inlet Flow 2 Camras 2"', '"CAMRAS CO2 Outlet Flow 1 Camras 2"' , '"CAMRAS CO2 Outlet Flow 2 Camras 2"'};
            sTitle = 'CAMRAS CO2 Flowrates Camras 2'; 
            coPlots{2,1} = oPlotter.definePlot(csNames, sTitle, tPlotOptions);
            
            csNames = {'"CAMRAS H2O Inlet Flow 1 Camras 2"',  '"CAMRAS H2O Inlet Flow 2 Camras 2"', '"CAMRAS H2O Outlet Flow 1 Camras 2"' ,  '"CAMRAS H2O Outlet Flow 2 Camras 2"'};
            sTitle = 'CAMRAS H2O Flowrates Camras 2'; 
            coPlots{2,2} = oPlotter.definePlot(csNames, sTitle, tPlotOptions);
            
            oPlotter.defineFigure(coPlots,  'CAMRAS 2 Flows');
            
            coPlots = cell(0);
            % Efficiencies  
            csNames = {'"Averaged Efficiency CO2 CAMRAS 2"', '"Efficiency CO2 CAMRAS 2"'};
            sTitle = 'Removal Efficiencies CO2 Camras 2'; 
            coPlots{1,1} = oPlotter.definePlot(csNames, sTitle, tPlotOptions);
             
            csNames = {'"Averaged Efficiency H2O CAMRAS 2"', '"Efficiency H2O CAMRAS 2"'};
            sTitle = 'Removal Efficiencies H2O Camras 2'; 
            coPlots{1,2} = oPlotter.definePlot(csNames, sTitle, tPlotOptions);
            
            % Partial Mass in FilterIn Phase
            csNames = {'"Partial Mass H2O PhaseIn Filter A Camras 2"', '"Partial Mass CO2 PhaseIn Filter A Camras 2"'};
            sTitle = 'Partial Mass in Phase In Filter A Camras 2'; 
            coPlots{2,1} = oPlotter.definePlot(csNames, sTitle, tPlotOptions);
            
            csNames = {'"Partial Mass H2O PhaseIn Filter B Camras 2"', '"Partial Mass CO2 PhaseIn Filter B Camras 2"'};
            sTitle = 'Partial Mass in Phase In Filter B Camras 2'; 
            coPlots{2,2} = oPlotter.definePlot(csNames, sTitle, tPlotOptions);
            
            oPlotter.defineFigure(coPlots,  'CAMRAS 2 Efficiencies and Partila Masses');
            
            coPlots = cell(0);
            % CO2 Mass Ratio inlet FLow
            csNames = {'"Inlet Mass Ratio CO2"'};
            sTitle = 'Mass Ratio CO2 Camras 1 Inlet Flow'; 
            coPlots{1,1} = oPlotter.definePlot(csNames, sTitle, tPlotOptions);
            
            % H2O Mass Ratio
            csNames = {'"Inlet Mass Ratio H2O"'};
            sTitle = 'Mass Ratio H2O Camras 1 Inlet Flow'; 
            coPlots{1,2} = oPlotter.definePlot(csNames, sTitle, tPlotOptions);
            
            oPlotter.defineFigure(coPlots,  'CAMRAS Inlet Mass Ratios');
  
            %% Vacuum Mass
            coPlots = cell(0);
            csNames = {'"Vacuum Mass"'};
            sTitle = 'Vacuum Mass'; 
            coPlots{1,1} = oPlotter.definePlot(csNames, sTitle, tPlotOptions);
            
            %% FlowRates
            
            cNames = {'"FlowRate Pressure Equalization"'};
            coPlots{1,2} = oPlotter.definePlot(cNames, 'Flow Rate Pressure Equalization', tPlotOptions);
            
            cNames = {'"Human CO2 Flowrate"', '"Human H2O Flowrate"', '"N2 Buffer Flowrate"', '"O2 Buffer Flowrate"'};
            coPlots{2,1} = oPlotter.definePlot(cNames, 'Human Simulator', tPlotOptions);

            oPlotter.defineFigure(coPlots,  'Other Plots');
            
            oPlotter.plot();
            
            oLogger = this.toMonitors.oLogger;
            
            for iLog = 1:oLogger.iNumberOfLogItems
                if strcmp(oLogger.tLogValues(iLog).sLabel, 'Atmosphere Partial Pressure H2O')
                    iH2OIndex = iLog;
                elseif strcmp(oLogger.tLogValues(iLog).sLabel, 'Atmosphere Partial Pressure CO2')
                    iCO2Index = iLog;
                end
            end
            
            TestData = readtable('+examples/+CAMRAS/Test_Data.xlsx');
            
            afTestTime = table2array(TestData(2:end,4));
            afTestCO2  = table2array(TestData(2:end,5));
            afTestH2O  = table2array(TestData(2:end,6));
            
            iFirstRelevantEntry = find(afTestTime > 136 * 60, 1);
            afTestTime(1:iFirstRelevantEntry) = [];
            afTestCO2(1:iFirstRelevantEntry) = [];
            afTestH2O(1:iFirstRelevantEntry) = [];
            
            afTestTime = afTestTime - afTestTime(1);
            
            figure()
            plot(afTestTime ./ 60       , afTestCO2, '--r');
            grid on
            xlabel('Time in min');
            ylabel('Partial Pressure in Pa');
            hold on
            plot(afTestTime ./ 60       , afTestH2O, '--b');
            plot(oLogger.afTime ./ 60   , oLogger.mfLog(:, iCO2Index), '-r')
            plot(oLogger.afTime ./ 60   , oLogger.mfLog(:, iH2OIndex), '-b')
            legend('Test Data CO2', 'Test Data H2O', 'Simulation CO2', 'Simulation H2O');
            
            afTime = (oLogger.afTime./3600)';
            afTime(isnan(afTime)) = [];
            
            InterpolatedTestDataCO2 = interp1(afTestTime, afTestCO2, afTime);
            InterpolatedTestDataH2O = interp1(afTestTime, afTestH2O, afTime);
            
            mfCO2 = oLogger.mfLog(:, iCO2Index);
            mfCO2(isnan(mfCO2)) = [];
            mfH2O = oLogger.mfLog(:, iH2OIndex);
            mfH2O(isnan(mfH2O)) = [];
            
            fMaxDiff  = max(abs(mfCO2 - InterpolatedTestDataCO2));
            fMinDiff  = min(abs(mfCO2 - InterpolatedTestDataCO2));
            fMeanDiff = mean(mfCO2    - InterpolatedTestDataCO2);
            rPercentualError = 100 * fMeanDiff / mean(InterpolatedTestDataCO2);
            
            disp(['Maximum   Difference for CO2 between Simulation and Test:     ', num2str(fMaxDiff), ' Pa'])
            disp(['Minimum   Difference for CO2 between Simulation and Test:     ', num2str(fMinDiff), ' Pa'])
            disp(['Mean      Difference for CO2 between Simulation and Test:     ', num2str(fMeanDiff), ' Pa'])
            disp(['Percent   Difference for CO2 between Simulation and Test:     ', num2str(rPercentualError), ' %'])
            
            fMaxDiff  = max(abs(mfH2O - InterpolatedTestDataH2O));
            fMinDiff  = min(abs(mfH2O - InterpolatedTestDataH2O));
            fMeanDiff = mean(mfH2O    - InterpolatedTestDataH2O);
            rPercentualError = 100 * fMeanDiff / mean(InterpolatedTestDataH2O);
            
            disp(['Maximum   Difference for H2O between Simulation and Test:     ', num2str(fMaxDiff), ' Pa'])
            disp(['Minimum   Difference for H2O between Simulation and Test:     ', num2str(fMinDiff), ' Pa'])
            disp(['Mean      Difference for H2O between Simulation and Test:     ', num2str(fMeanDiff), ' Pa'])
            disp(['Percent   Difference for H2O between Simulation and Test:     ', num2str(rPercentualError), ' %'])
        end
    end
end
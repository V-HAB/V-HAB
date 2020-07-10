classdef setup < simulation.infrastructure
    %SETUP This class is used to setup a simulation
    %   There should always be a setup file present for each project. It is
    %   used for the following:
    %   - instantiate the root object
    %   - determine which items are logged
    %   - set the simulation duration
    %   - provide methods for plotting the results
    
    properties
        % This class does not have any properties.
    end
    
    methods
        % Constructor function
        function this = setup(ptConfigParams, tSolverParams) 
            % First we call the parent constructor and tell it the name of
            % this simulation we are creating.
            ttMonitorConfig = struct('oLogger', struct('cParams', {{true, 10000}}));
            
            % use the following two lines if really small time steps appear
            ttMonitorConfig.oTimeStepObserver.sClass = 'simulation.monitors.timestepObserver';
            ttMonitorConfig.oTimeStepObserver.cParams = { 0 };
            
            this@simulation.infrastructure('HFC_System', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            % Creating the 'Example' system as a child of the root system
            % of this simulation. 
            examples.HFC.systems.Example(this.oSimulationContainer, 'Example');          
            
            % Load experimental data from the X-Hab 2017 project
            sFileID = strrep('+examples/+HFC/+data/April-04-2017-upstrm2.csv','/',filesep);
            [afUpTime, afUpCO2]  = examples.HFC.importCO2file(sFileID,3,1220);
            sFileID = strrep('+examples/+HFC/+data/April-04-2017-dwnstrm2.csv','/',filesep);
            [afDnTime, afDnCO2] = examples.HFC.importCO2file(sFileID,3,1217);
            
            % remove the pre-test setup data points
            afUpTime(1:106) = [];
            afDnTime(1:102) = [];
            
            dStartTime = min([afDnTime;afUpTime]);
            dEndTime = max([afDnTime;afUpTime]);
            fSimTime = seconds(dEndTime - dStartTime);
           
            % Setting the simulation duration to one hour. Time is always
            % in units of seconds in V-HAB.
            this.fSimTime = fSimTime;
            this.bUseTime = true;
            
        end
        
        % Logging function
        function configureMonitors(this)
            % To make the code more legible, we create a local variable for
            % the logger object.
            oLogger = this.toMonitors.oLogger;

            % Input and output CO2 partial pressure in the stores
            oLogger.addValue('Example.toStores.Aether.toPhases.Air', 'afPP(this.oMT.tiN2I.CO2)', 'Pa', 'Partial Pressure CO2 IN');
            oLogger.addValue('Example.toStores.Exhaust.toPhases.Air', 'afPP(this.oMT.tiN2I.CO2)', 'Pa', 'Partial Pressure CO2 OUT');
  
            % Input and output CO2 & H2O partial pressure in the flows    
            oLogger.addValue('Example.toChildren.HFC.toBranches.HFC_Air_In_1.aoFlows(1,1)', 'afPartialPressure(this.oMT.tiN2I.CO2)', 'Pa', 'Partial Pressure CO2 IN FLOW');
            oLogger.addValue('Example.toChildren.HFC.toBranches.HFC_Air_Out_1.aoFlows(1,1)', 'afPartialPressure(this.oMT.tiN2I.CO2)', 'Pa', 'Partial Pressure CO2 OUT FLOW');
%             oLogger.addValue('Example.toChildren.HFC.toBranches.HFC_Air_In_1.aoFlows(1,1)', 'afPartialPressure(this.oMT.tiN2I.H2O)', 'Pa', 'Partial Pressure H2O IN FLOW');
%             oLogger.addValue('Example.toChildren.HFC.toBranches.HFC_Air_Out_1.aoFlows(1,1)', 'afPartialPressure(this.oMT.tiN2I.H2O)', 'Pa', 'Partial Pressure H2O OUT FLOW');
                        
            % ionic liquid loggers for CO2 and H2O (as well as IL)
            oLogger.addValue('Example.toChildren.HFC.toBranches.Reservoir_IL_Out.aoFlows(1,1)',     'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)', 'kg/s', 'Partial Mass CO2 in IL OUT FLOW');
            oLogger.addValue('Example.toChildren.HFC.toBranches.IL_Recirculation.aoFlows(1,1)',     'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)', 'kg/s', 'Partial Mass CO2 in IL RECIRC FLOW');
            oLogger.addValue('Example.toChildren.HFC.toBranches.Reservoir_IL_Return.aoFlows(1,1)',  'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)', 'kg/s', 'Partial Mass CO2 in IL RETURN FLOW');
            oLogger.addValue('Example.toChildren.HFC.toBranches.Reservoir_IL_Out.aoFlows(1,1)',     'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)', 'kg/s', 'Partial Mass H2O in IL OUT FLOW');
            oLogger.addValue('Example.toChildren.HFC.toBranches.IL_Recirculation.aoFlows(1,1)',     'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)', 'kg/s', 'Partial Mass H2O in IL RECIRC FLOW');
            oLogger.addValue('Example.toChildren.HFC.toBranches.Reservoir_IL_Return.aoFlows(1,1)',  'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)', 'kg/s', 'Partial Mass H2O in IL RETURN FLOW');
            oLogger.addValue('Example.toChildren.HFC.toBranches.Reservoir_IL_Out.aoFlows(1,1)',     'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.BMIMAc)',   'kg/s', 'Partial Mass IL in IL OUT FLOW');
            oLogger.addValue('Example.toChildren.HFC.toBranches.IL_Recirculation.aoFlows(1,1)',     'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.BMIMAc)',   'kg/s', 'Partial Mass IL in IL RECIRC FLOW');
            oLogger.addValue('Example.toChildren.HFC.toBranches.Reservoir_IL_Return.aoFlows(1,1)',  'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.BMIMAc)',   'kg/s', 'Partial Mass IL in IL RETURN FLOW');
            
            % logger for IL reservoir
            oLogger.addValue('Example.toChildren.HFC.toStores.Reservoir.toPhases.IonicLiquid', 'this.fMass * this.arPartialMass(this.oMT.tiN2I.CO2)', 'kg', 'CO2 Mass in IL in Reservoir');
            oLogger.addValue('Example.toChildren.HFC.toStores.Reservoir.toPhases.IonicLiquid', 'this.fMass * this.arPartialMass(this.oMT.tiN2I.H2O)', 'kg', 'H2O Mass in IL in Reservoir');
            oLogger.addValue('Example.toChildren.HFC.toStores.Reservoir.toPhases.IonicLiquid', 'this.fMass * this.arPartialMass(this.oMT.tiN2I.BMIMAc)', 'kg', 'IL Mass in IL in Reservoir');
            
            % logger for vacuum flow removal
            % TODO: this is not reporting the correct values
            oLogger.addValue('Example.toChildren.HFC.toBranches.VacuumSupply.aoFlows(1,1)', 'afPartialPressure(this.oMT.tiN2I.CO2)', 'Pa', 'Partial Pressure CO2 IN VACUUM');
            oLogger.addValue('Example.toChildren.HFC.toBranches.VacuumRemoval.aoFlows(1,1)', 'afPartialPressure(this.oMT.tiN2I.CO2)', 'Pa', 'Partial Pressure CO2 OUT VACUUM');
            oLogger.addValue('Example.toStores.VacuumSupply.toPhases.vacuum', 'afMassChange(this.oMT.tiN2I.CO2)', 'kg', 'Cumulative Mass of provided CO2 in VACUUM Supply');
            oLogger.addValue('Example.toStores.VacuumRemoval.toPhases.vacuum', 'afMassChange(this.oMT.tiN2I.CO2)', 'kg', 'Cumulative Mass of collected CO2 in VACUUM Removal');
            
            % logger for residence time and mass flow rate in the
            % Adsorption Processor for one cell
            oLogger.addValue('Example.toChildren.HFC.toStores.Tube_1.toProcsP2P.AdsorptionProcessor_1', 'fLumenResidenceTime', 's', 'Residence Time');
            oLogger.addValue('Example.toChildren.HFC.toStores.Tube_1.toProcsP2P.AdsorptionProcessor_1', 'tGeometry.mfMassTransferCoefficient(this.oMT.tiN2I.CO2)', 'm/s', 'Mass transfer coefficient of CO2');
            oLogger.addValue('Example.toChildren.HFC.toStores.Tube_1.toProcsP2P.AdsorptionProcessor_1', 'fHenrysConstant', 'Pa', 'Henrys Constant');
            oLogger.addValue('Example', 'fEstimatedMassTransferCoefficient', 'm/s', 'Experimental mass transfer coefficient of CO2');
            
            % Adding the branch flow rate to the log
%             oLogger.addValue('Example.toBranches.Branch', 'fFlowRate', 'kg/s', 'Branch Flow Rate');
            
        end
        
        % Plotting function
        function plot(this) 
            % First we get a handle to the plotter object associated with
            % this simulation.

            oPlotter = plot@simulation.infrastructure(this);
            
            % Creating three plots arranged in a 2x2 matrix. The first
            % contains the two temperatures, the second contains the two
            % pressures and the third contains the branch flow rate. 
            coPlots{1,1} = oPlotter.definePlot({'"Partial Pressure CO2 IN"', '"Partial Pressure CO2 OUT"'}, 'Partial Pressures CO2');
%             coPlots{1,2} = oPlotter.definePlot({'"Partial Pressure CO2 IN FLOW"', '"Partial Pressure CO2 OUT FLOW"', '"Partial Pressure H2O IN FLOW"', '"Partial Pressure H2O OUT FLOW"'}, 'Partial Pressures CO2 and H2O FLOW');
            coPlots{1,2} = oPlotter.definePlot({'"Partial Pressure CO2 IN FLOW"', '"Partial Pressure CO2 OUT FLOW"'}, 'Partial Pressures CO2 in FLOW');
            
            coPlots2{1,1} = oPlotter.definePlot({'"Residence Time"'}, 'Residence Time');
            coPlots2{1,2} = oPlotter.definePlot({'"Mass transfer coefficient of CO2"','"Experimental mass transfer coefficient of CO2"', '"Henrys Constant"'}, 'Mass transfer coefficient of CO2');            
            coPlots2{1,3} = oPlotter.definePlot({'"Henrys Constant"'}, 'Henrys Constant');
            
            coPlots3{1,1} = oPlotter.definePlot({'"Partial Mass CO2 in IL OUT FLOW"'} , 'CO2 in IL from Reservoir');
            coPlots3{2,1} = oPlotter.definePlot({'"Partial Mass CO2 in IL RECIRC FLOW"'}, 'CO2 in IL after Absorption Tube');
            coPlots3{3,1} = oPlotter.definePlot({'"Partial Mass CO2 in IL RETURN FLOW"'}, 'CO2 in IL after Desorption Tube');
            coPlots3{1,2} = oPlotter.definePlot({'"Partial Mass H2O in IL OUT FLOW"'}, 'H2O in IL from Reservoir');
            coPlots3{2,2} = oPlotter.definePlot({'"Partial Mass H2O in IL RECIRC FLOW"'}, 'H2O in IL after Absorption Tube');
            coPlots3{3,2} = oPlotter.definePlot({'"Partial Mass H2O in IL RETURN FLOW"'}, 'H2O in IL after Desorption Tube');
            coPlots3{1,3} = oPlotter.definePlot({'"Partial Mass IL in IL OUT FLOW"'}, 'IL in IL from Reservoir');
            coPlots3{2,3} = oPlotter.definePlot({'"Partial Mass IL in IL RECIRC FLOW"'}, 'IL in IL after Absorption Tube');
            coPlots3{3,3} = oPlotter.definePlot({'"Partial Mass IL in IL RETURN FLOW"'}, 'IL in IL after Desorption Tube');
            
            coPlots4{1,1} = oPlotter.definePlot({'"CO2 Mass in IL in Reservoir"'}, 'CO2 Mass in IL in Reservoir');
            coPlots4{1,2} = oPlotter.definePlot({'"H2O Mass in IL in Reservoir"'}, 'H2O Mass in IL in Reservoir');
            coPlots4{1,3} = oPlotter.definePlot({'"IL Mass in IL in Reservoir"'}, 'IL Mass in IL in Reservoir');
            
            coPlots5{1,1} = oPlotter.definePlot({'"Partial Pressure CO2 IN VACUUM"', '"Partial Pressure CO2 OUT VACUUM"'}, 'Partial Pressures CO2 Flow in VACUUM');
            coPlots5{1,2} = oPlotter.definePlot({'"Cumulative Mass of provided CO2 in VACUUM Supply"', '"Cumulative Mass of collected CO2 in VACUUM Removal"'}, 'Cumulative Mass of collected CO2 in VACUUM');
            
            coPlots6{1,1} = oPlotter.definePlot({'"Experimental mass transfer coefficient of CO2"','"Henrys Constant"','"Mass transfer coefficient of CO2"'}, 'Mass Transfor Factors');
            
            % Creating a figure containing the three plots. By passing in a
            % struct with the 'bTimePlot' field set to true, we create an
            % additional plot showing the relationship between simulation
            % steps and simulated time.
            oPlotter.defineFigure(coPlots, 'Partial Pressures CO2 and FLOWS', struct('bTimePlot', false));
            oPlotter.defineFigure(coPlots2, 'Residence Time & Mass Xfer Coeff of Gas in HFC per Tick', struct('bTimePlot', false));
            oPlotter.defineFigure(coPlots3, 'CO2 and H2O in IL Flow', struct('bTimePlot', false));
            oPlotter.defineFigure(coPlots4, 'CO2 and H2O in IL Reservoir', struct('bTimePlot', false));
            oPlotter.defineFigure(coPlots5, 'CO2 in Vacuum Supply and Removal', struct('bTimePlot', false));
            oPlotter.defineFigure(coPlots6, 'Coefficient Analysis',struct('bTimePlot',false));
            
            % Plotting all figures (in this case just one). 
            oPlotter.plot();
%           plot(oLastSimObj.oSimulationContainer.toChildren.Example.tTestData.afTime,oLastSimObj.oSimulationContainer.toChildren.Example.tTestData.afDnCO2)
            
        end
        
%         NOTE: select the figure with CO2 input and output data, then
%         copy + paste these last two lines to add the experimental
%         data to the plot of input and output CO2. oLastSimObj must be
%         created before these values can be plotted.
%
%         pCO2Up = oLastSimObj.oSimulationContainer.toChildren.Example.tTestData.afUpCO2./1000000 .* 84100;
%         pCO2Dn = oLastSimObj.oSimulationContainer.toChildren.Example.tTestData.afDnCO2./1000000 .* 84100;
%         hold on
%         plot(oLastSimObj.oSimulationContainer.toChildren.Example.tTestData.afTime,pCO2Up,'r',oLastSimObj.oSimulationContainer.toChildren.Example.tTestData.afTime,pCO2Dn,'k')
%         legend('SIM Partial Pressure CO2 IN FLOW [Pa]','SIM Partial Pressure CO2 OUT FLOW [Pa]', 'EXP Partial Pressure CO2 IN FLOW [Pa]', 'EXP Partial Pressure CO2 OUT FLOW [Pa]');
%         hold off
    end
    
end


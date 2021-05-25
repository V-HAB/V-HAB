classdef setup < simulation.infrastructure
    %The setup file for the simulation of the CROP model
    %   The simulation length and the plots for analysis are included in
    %   this class file.
    
    properties
        % Property where indices of logs can be stored
        tiLogIndexes = struct();
    end
    
    methods
        function this = setup(ptConfigParams, tSolverParams)
            
            ttMonitorCfg = struct();
            
            
            % First we call the parent constructor and tell it the name of
            % this simulation we are creating.
            this@simulation.infrastructure('CROP_Example', ptConfigParams, tSolverParams, ttMonitorCfg);
            
            
            % Creating the CROP system as a child of the root system
            % of this simulation.
            examples.CROP.system.Example(this.oSimulationContainer, 'Example');

  %% Simulation length
            % Simulation length - stop when specific time in sim is reached
            % or after specific amount of ticks (bUseTime true/false).
            this.fSimTime = 100 * 24 * 3600;
            this.iSimTicks = 200;
            this.bUseTime = true;
        end
        
        function configureMonitors(this)
            oLogger = this.toMonitors.oLogger;
            
            % The logged values from the simulation results. The detailed
            % information is included in the name as an argument of the
            % function "oLogger.addValue".
            
            oLogger.addValue('Example.oTimer',	'fTimeStepFinal',	's',   'Timestep');
            
            for iCROP = 1:1
                sCROP = ['CROP_', num2str(iCROP)];
                
                oLogger.addValue(['Example:c:',sCROP,':s:CROP_Tank.toPhases.TankSolution'], 'fMass', 'kg', [sCROP, ' CROP Tank Mass']);
                
                oLogger.addValue(['Example:c:',sCROP,'.toBranches.CROP_Calcite_Inlet'], 'fFlowRate', 'kg/s', [sCROP, ' CROP Calcite Inlet']);
                
                
                
                this.tiLogIndexes.mfPH{iCROP} = oLogger.addValue(['Example:c:',sCROP,':s:CROP_BioFilter.toPhases.BioPhase.toManips.substance'], 'fpH', '-',              [sCROP ,' BioFilter pH']);
                
                this.tiLogIndexes.mfCH4N2O{iCROP}     	= oLogger.addValue(['Example:c:',sCROP,':s:CROP_Tank.toPhases.TankSolution'], 'afMass(this.oMT.tiN2I.CH4N2O)',  'kg',    [sCROP, ' Tank CH4N2O Mass']);
                this.tiLogIndexes.mfNH3{iCROP}        	= oLogger.addValue(['Example:c:',sCROP,':s:CROP_Tank.toPhases.TankSolution'], 'afMass(this.oMT.tiN2I.NH3)',     'kg',    [sCROP, ' Tank NH3 Mass']);
                this.tiLogIndexes.mfNH4{iCROP}       	= oLogger.addValue(['Example:c:',sCROP,':s:CROP_Tank.toPhases.TankSolution'], 'afMass(this.oMT.tiN2I.NH4)',     'kg',    [sCROP, ' Tank NH4 Mass']);
                this.tiLogIndexes.mfNO3{iCROP}          = oLogger.addValue(['Example:c:',sCROP,':s:CROP_Tank.toPhases.TankSolution'], 'afMass(this.oMT.tiN2I.NO3)',     'kg',    [sCROP, ' Tank NO3 Mass']);
                this.tiLogIndexes.mfNO2{iCROP}          = oLogger.addValue(['Example:c:',sCROP,':s:CROP_Tank.toPhases.TankSolution'], 'afMass(this.oMT.tiN2I.NO2)',     'kg',    [sCROP, ' Tank NO2 Mass']);
                this.tiLogIndexes.mfCO2{iCROP}          = oLogger.addValue(['Example:c:',sCROP,':s:CROP_Tank.toPhases.TankSolution'], 'afMass(this.oMT.tiN2I.CO2)',     'kg',    [sCROP, ' Tank CO2 Mass']);
                this.tiLogIndexes.mfCa{iCROP}           = oLogger.addValue(['Example:c:',sCROP,':s:CROP_Tank.toPhases.TankSolution'], 'afMass(this.oMT.tiN2I.Ca2plus)', 'kg',    [sCROP, ' Tank Ca Mass']);
                this.tiLogIndexes.mfCO3{iCROP}          = oLogger.addValue(['Example:c:',sCROP,':s:CROP_Tank.toPhases.TankSolution'], 'afMass(this.oMT.tiN2I.CO3)',     'kg',    [sCROP, ' Tank CO3 Mass']);
                
                this.tiLogIndexes.mfCaCO3{iCROP}     	= oLogger.addValue(['Example:c:',sCROP,':s:CROP_Tank.toPhases.Calcite'], 'afMass(this.oMT.tiN2I.CaCO3)',        'kg',    [sCROP, ' Tank CaCO3 Mass']);
                
                this.tiLogIndexes.mfCH4N2Oflow{iCROP}     	= oLogger.addValue(['Example:c:',sCROP,':s:CROP_BioFilter.toPhases.BioPhase.toManips.substance'], 'afPartialFlows(this.oMT.tiN2I.CH4N2O)', 'kg/s',    [sCROP, ' Enzyme Reaction CH4N2O']);
                this.tiLogIndexes.mfNH3flow{iCROP}        	= oLogger.addValue(['Example:c:',sCROP,':s:CROP_BioFilter.toPhases.BioPhase.toManips.substance'], 'afPartialFlows(this.oMT.tiN2I.NH3)',    'kg/s',    [sCROP, ' Enzyme Reaction NH3']);
                this.tiLogIndexes.mfNH4flow{iCROP}       	= oLogger.addValue(['Example:c:',sCROP,':s:CROP_BioFilter.toPhases.BioPhase.toManips.substance'], 'afPartialFlows(this.oMT.tiN2I.NH4)',    'kg/s',    [sCROP, ' Enzyme Reaction NH4']);
                this.tiLogIndexes.mfNO3flow{iCROP}          = oLogger.addValue(['Example:c:',sCROP,':s:CROP_BioFilter.toPhases.BioPhase.toManips.substance'], 'afPartialFlows(this.oMT.tiN2I.NO3)',    'kg/s',    [sCROP, ' Enzyme Reaction NO3']);
                this.tiLogIndexes.mfNO2flow{iCROP}          = oLogger.addValue(['Example:c:',sCROP,':s:CROP_BioFilter.toPhases.BioPhase.toManips.substance'], 'afPartialFlows(this.oMT.tiN2I.NO2)',    'kg/s',    [sCROP, ' Enzyme Reaction NO2']);
                this.tiLogIndexes.mfO2flow{iCROP}           = oLogger.addValue(['Example:c:',sCROP,':s:CROP_BioFilter.toPhases.BioPhase.toManips.substance'], 'afPartialFlows(this.oMT.tiN2I.O2)',     'kg/s',     [sCROP, ' Enzyme Reaction O2']);
                this.tiLogIndexes.mfH2Oflow{iCROP}          = oLogger.addValue(['Example:c:',sCROP,':s:CROP_BioFilter.toPhases.BioPhase.toManips.substance'], 'afPartialFlows(this.oMT.tiN2I.H2O)',    'kg/s',    [sCROP, ' Enzyme Reaction H2O']);
                this.tiLogIndexes.mfCO2flow{iCROP}          = oLogger.addValue(['Example:c:',sCROP,':s:CROP_BioFilter.toPhases.BioPhase.toManips.substance'], 'afPartialFlows(this.oMT.tiN2I.CO2)',    'kg/s',    [sCROP, ' Enzyme Reaction CO2']);
                
                this.tiLogIndexes.mfNH3gasex{iCROP}   	= oLogger.addValue(['Example:c:',sCROP,':s:CROP_Tank.toProcsP2P.NH3_Outgassing_Tank'], 'fFlowRate',    'kg/s',    [sCROP, ' NH3 gas exchange']);
                this.tiLogIndexes.mfCO2gasex{iCROP}   	= oLogger.addValue(['Example:c:',sCROP,':s:CROP_Tank.toProcsP2P.CO2_Outgassing_Tank'], 'fFlowRate',    'kg/s',    [sCROP, ' CO2 gas exchange']);
                this.tiLogIndexes.mfO2gasex{iCROP}   	= oLogger.addValue(['Example:c:',sCROP,':s:CROP_Tank.toProcsP2P.O2_to_TankSolution'],  'fFlowRate',    'kg/s',    [sCROP, ' O2 gas exchange']);
                this.tiLogIndexes.mfO2gasex{iCROP}   	= oLogger.addValue(['Example:c:',sCROP,':s:CROP_Tank.toProcsP2P.Calcite_to_TankSolution'],  'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO3)',      'kg/s',    [sCROP, ' CO3 dissolve']);
                this.tiLogIndexes.mfO2gasex{iCROP}   	= oLogger.addValue(['Example:c:',sCROP,':s:CROP_Tank.toProcsP2P.Calcite_to_TankSolution'],  'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.Ca2plus)', 	'kg/s',    [sCROP, ' Ca2plus dissolve']);
                
                this.tiLogIndexes.mfNH3gascum{iCROP}   	= oLogger.addVirtualValue(['cumsum("', sCROP, ' NH3 gas exchange"   .* "Timestep")'], 'kg', [sCROP, ' exchanged NH3 Mass']);
                this.tiLogIndexes.mfCO2gascum{iCROP}   	= oLogger.addVirtualValue(['cumsum("', sCROP, ' CO2 gas exchange"   .* "Timestep")'], 'kg', [sCROP, ' exchanged CO2 Mass']);
                this.tiLogIndexes.mfO2gascum{iCROP}   	= oLogger.addVirtualValue(['cumsum("', sCROP, ' O2 gas exchange"    .* "Timestep")'], 'kg', [sCROP, ' exchanged O2 Mass']);
                this.tiLogIndexes.mfCalcitecum{iCROP}  	= oLogger.addVirtualValue(['cumsum("', sCROP, ' CROP Calcite Inlet" .* "Timestep")'], 'kg', [sCROP, ' consumed Calcite Mass']);
                this.tiLogIndexes.mfCalciumcum{iCROP}  	= oLogger.addVirtualValue(['cumsum("', sCROP, ' CO3 dissolve"       .* "Timestep")'], 'kg', [sCROP, ' dissolved Calcium Mass']);
                this.tiLogIndexes.mfCarbonatecum{iCROP} = oLogger.addVirtualValue(['cumsum("', sCROP, ' Ca2plus dissolve"   .* "Timestep")'], 'kg', [sCROP, ' dissolved Carbonate Mass']);
                
                this.tiLogIndexes.mfCH4N2OEnzymeCum{iCROP}	= oLogger.addVirtualValue(['cumsum("', sCROP, ' Enzyme Reaction CH4N2O" .* "Timestep")'], 'kg', [sCROP, ' enzyme reacted CH4N2O Mass']);
                this.tiLogIndexes.mfNH3EnzymeCum{iCROP}  	= oLogger.addVirtualValue(['cumsum("', sCROP, ' Enzyme Reaction NH3"    .* "Timestep")'], 'kg', [sCROP, ' enzyme reacted NH3 Mass']);
                this.tiLogIndexes.mfNH4EnzymeCum{iCROP}  	= oLogger.addVirtualValue(['cumsum("', sCROP, ' Enzyme Reaction NH4"    .* "Timestep")'], 'kg', [sCROP, ' enzyme reacted NH4 Mass']);
                this.tiLogIndexes.mfNO3EnzymeCum{iCROP}  	= oLogger.addVirtualValue(['cumsum("', sCROP, ' Enzyme Reaction NO3"    .* "Timestep")'], 'kg', [sCROP, ' enzyme reacted NO3 Mass']);
                this.tiLogIndexes.mfNO2EnzymeCum{iCROP}  	= oLogger.addVirtualValue(['cumsum("', sCROP, ' Enzyme Reaction NO2"    .* "Timestep")'], 'kg', [sCROP, ' enzyme reacted NO2 Mass']);
                this.tiLogIndexes.mfO2EnzymeCum{iCROP}  	= oLogger.addVirtualValue(['cumsum("', sCROP, ' Enzyme Reaction O2"     .* "Timestep")'], 'kg', [sCROP, ' enzyme reacted O2 Mass']);
                this.tiLogIndexes.mfH2OEnzymeCum{iCROP}  	= oLogger.addVirtualValue(['cumsum("', sCROP, ' Enzyme Reaction H2O"    .* "Timestep")'], 'kg', [sCROP, ' enzyme reacted H2O Mass']);
                this.tiLogIndexes.mfCO2EnzymeCum{iCROP}  	= oLogger.addVirtualValue(['cumsum("', sCROP, ' Enzyme Reaction CO2"    .* "Timestep")'], 'kg', [sCROP, ' enzyme reacted CO2 Mass']);
                
            end
            
            this.tiLogIndexes.mfCalciumcumAlt{iCROP}= oLogger.addValue('Example:s:CalciteSupply.toPhases.CalciteSupply',  'this.afMassChange(this.oMT.tiN2I.CaCO3)', 	'kg',    'Total consumed Calcite Mass');
        end
        
         function plot(this)
            % The plots are defined in this function. The detailed informations 
            % are included in the figure name.
                       
            try
                this.toMonitors.oLogger.readFromMat;
            catch
                disp('no data outputted yet')
            end
            
            oPlotter = plot@simulation.infrastructure(this);
            oLogger = oPlotter.oSimulationInfrastructure.toMonitors.oLogger;
            
            tPlotOptions.sTimeUnit = 'hours';
            
            coPlots{1,1} = oPlotter.definePlot(this.tiLogIndexes.mfPH,                	'pH Value',  	tPlotOptions);
            coPlots{1,2} = oPlotter.definePlot(this.tiLogIndexes.mfCH4N2O,          	'Urea',       	tPlotOptions);
            coPlots{1,3} = oPlotter.definePlot(this.tiLogIndexes.mfNH3,              	'NH3',       	tPlotOptions);
            coPlots{1,4} = oPlotter.definePlot(this.tiLogIndexes.mfNH4,              	'NH4',       	tPlotOptions);
            coPlots{1,5} = oPlotter.definePlot(this.tiLogIndexes.mfCaCO3,              	'CaCO3',       	tPlotOptions);
            coPlots{2,1} = oPlotter.definePlot(this.tiLogIndexes.mfNO3,                 'NO3',         	tPlotOptions);
            coPlots{2,2} = oPlotter.definePlot(this.tiLogIndexes.mfNO2,                 'NO2',        	tPlotOptions);
            coPlots{2,3} = oPlotter.definePlot(this.tiLogIndexes.mfCO2,                 'CO2',        	tPlotOptions);
            coPlots{2,4} = oPlotter.definePlot(this.tiLogIndexes.mfCa,                  'Ca',        	tPlotOptions);
            coPlots{2,5} = oPlotter.definePlot(this.tiLogIndexes.mfCO3,                 'CO3',        	tPlotOptions);
            
            oPlotter.defineFigure(coPlots, 'CROP Masses and pH');
            
            clear coPlots
            coPlots{1,1} = oPlotter.definePlot(this.tiLogIndexes.mfNH3gascum,       	'NH3 Gas Exchange',    	tPlotOptions);
            coPlots{1,2} = oPlotter.definePlot(this.tiLogIndexes.mfCO2gascum,          	'CO2 Gas Exchange',   	tPlotOptions);
            coPlots{1,3} = oPlotter.definePlot(this.tiLogIndexes.mfO2gascum,           	'O2 Gas Exchange',     	tPlotOptions);
            coPlots{2,1} = oPlotter.definePlot(this.tiLogIndexes.mfCalcitecum,       	'Consumed Calcite', 	tPlotOptions);
            coPlots{2,2} = oPlotter.definePlot(this.tiLogIndexes.mfCalciumcum,       	'Dissolved Calcium', 	tPlotOptions);
            coPlots{2,3} = oPlotter.definePlot(this.tiLogIndexes.mfCarbonatecum,       	'Dissolved Carbonate', 	tPlotOptions);
            
            oPlotter.defineFigure(coPlots, 'CROP gas Exchange');
            
            clear coPlots
            coPlots{1,1} = oPlotter.definePlot(this.tiLogIndexes.mfCH4N2Oflow,       	'CH4N2O Enzyme Reaction', 	tPlotOptions);
            coPlots{1,2} = oPlotter.definePlot(this.tiLogIndexes.mfNH3flow,          	'NH3 Enzyme Reaction',  	tPlotOptions);
            coPlots{1,3} = oPlotter.definePlot(this.tiLogIndexes.mfNH4flow,           	'NH4 Enzyme Reaction',     	tPlotOptions);
            coPlots{1,4} = oPlotter.definePlot(this.tiLogIndexes.mfNO3flow,             'NO3 Enzyme Reaction',    	tPlotOptions);
            coPlots{2,1} = oPlotter.definePlot(this.tiLogIndexes.mfNO2flow,             'NO2 Enzyme Reaction',     	tPlotOptions);
            coPlots{2,2} = oPlotter.definePlot(this.tiLogIndexes.mfO2flow,              'O2 Enzyme Reaction',     	tPlotOptions);
            coPlots{2,3} = oPlotter.definePlot(this.tiLogIndexes.mfH2Oflow,             'H2O Enzyme Reaction',    	tPlotOptions);
            coPlots{2,4} = oPlotter.definePlot(this.tiLogIndexes.mfCO2flow,             'CO2 Enzyme Reaction',    	tPlotOptions);
                
            oPlotter.defineFigure(coPlots, 'CROP Enzyme Flowrates');
            oPlotter.plot();
            
            TestData = load('+examples\+CROP\+TestData\Data_Experiment.mat');
            % Value b is NH4OH, c is HNO2 and d is HNO3 
         end
    end
    
end


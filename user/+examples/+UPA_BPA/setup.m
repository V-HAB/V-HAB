classdef setup < simulation.infrastructure
    %The setup file for the simulation of the CROP model
    %   The simulation length and the plots for analysis are included in
    %   this class file.
    
    properties
        tiLog = struct();
    end
    
    methods
        function this = setup(ptConfigParams, tSolverParams)
            
            ttMonitorCfg = struct();
            
            
            % First we call the parent constructor and tell it the name of
            % this simulation we are creating.
            this@simulation.infrastructure('UPA_BPA_Example', ptConfigParams, tSolverParams, ttMonitorCfg);
            
            % Water content of Urine and Feces is based on BVAD, not all
            % possible components of both substances defined here
            trBaseCompositionUrine.H2O      = 0.9644;
            trBaseCompositionUrine.CH4N2O   = 0.0356;
            this.oSimulationContainer.oMT.defineCompoundMass(this, 'Urine', trBaseCompositionUrine)
            
            trBaseCompositionFeces.H2O          = 0.7576;
            trBaseCompositionFeces.DietaryFiber = 0.2424;
            this.oSimulationContainer.oMT.defineCompoundMass(this, 'Feces', trBaseCompositionFeces)
            
            trBaseCompositionBrine.H2O      = 0.8;
            trBaseCompositionBrine.C2H6O2N2 = 0.2;
            this.oSimulationContainer.oMT.defineCompoundMass(this, 'Brine', trBaseCompositionBrine);
            
            trBaseCompositionBrine.H2O      = 0.44;
            trBaseCompositionBrine.C2H6O2N2 = 0.56;
            this.oSimulationContainer.oMT.defineCompoundMass(this, 'ConcentratedBrine', trBaseCompositionBrine);

            
            % Creating the CROP system as a child of the root system
            % of this simulation.
            examples.UPA_BPA.system.Example(this.oSimulationContainer, 'Example');

  %% Simulation length
            % Simulation length - stop when specific time in sim is reached
            % or after specific amount of ticks (bUseTime true/false).
            this.fSimTime = 60 * 24 * 3600;
            this.iSimTicks = 200;
            this.bUseTime = true;
        end
        
        function configureMonitors(this)
            oLogger = this.toMonitors.oLogger;
            
            %% UPA + BPA Logging
            oLogger.addValue('Example.toChildren.UPA.toBranches.Outlet',                    'fFlowRate',        'kg/s', 'UPA Water Flow');
            oLogger.addValue('Example.toChildren.UPA.toBranches.BrineOutlet',               'fFlowRate',        'kg/s', 'UPA Brine Flow');
            oLogger.addValue('Example.toChildren.UPA.toStores.WSTA.toPhases.Urine',         'fMass',            'kg',   'UPA WSTA Mass');
            oLogger.addValue('Example.toChildren.UPA.toStores.ARTFA.toPhases.Brine',        'fMass',            'kg',   'UPA ARTFA Mass');
            
            oLogger.addValue('Example.toStores.BrineStorage.toPhases.Brine',                'fMass',            'kg',   'Brine Storage Mass');
            
            oLogger.addValue('Example.oTimer',                                            	'fTimeStepFinal',        's',   'Timestep');
            
            oLogger.addValue('Example.toChildren.BPA.toStores.Bladder.toProcsP2P.WaterP2P',                             'fFlowRate',	'kg/s', 'BPA Water Flow');
            oLogger.addValue('Example.toChildren.BPA.toStores.Bladder.toPhases.Brine',                                  'fMass',        'kg',   'BPA Bladder Mass');
            oLogger.addValue('Example.toChildren.BPA.toStores.ConcentratedBrineDisposal.toPhases.ConcentratedBrine',  	'fMass',        'kg',   'BPA Concentrated Brine Mass');
            
            oLogger.addValue('Example.toChildren.UPA',   	'fPower',   	'W',   'UPA Power Consumption');
            oLogger.addValue('Example.toChildren.BPA',  	'fPower',     	'W',   'BPA Power Consumption');
            
            oLogger.addVirtualValue('cumsum("UPA Water Flow"    .* "Timestep")', 'kg', 'UPA Produced Water');
            oLogger.addVirtualValue('cumsum("UPA Brine Flow"    .* "Timestep")', 'kg', 'UPA Produced Brine');
            oLogger.addVirtualValue('cumsum("BPA Water Flow"    .* "Timestep")', 'kg', 'BPA Produced Water');
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
            
            tPlotOptions.sTimeUnit = 'hours';
            tFigureOptions = struct('bTimePlot', false, 'bPlotTools', false);
            coPlots = cell.empty();
            coPlots{1,1} = oPlotter.definePlot({'"UPA WSTA Mass"', '"UPA ARTFA Mass"', '"Brine Storage Mass"', '"BPA Bladder Mass"', '"BPA Concentrated Brine Mass"'},	'Store Masses',  	tPlotOptions);
            coPlots{1,2} = oPlotter.definePlot({'"UPA Power Consumption"', '"BPA Power Consumption"'},      'Power',                 	tPlotOptions);
            coPlots{2,1} = oPlotter.definePlot({'"UPA Produced Water"', '"UPA Produced Brine"'},            'UPA',                      tPlotOptions);
            coPlots{2,2} = oPlotter.definePlot({'"BPA Produced Water"'},                                    'BPA',                      tPlotOptions);
            
            oPlotter.defineFigure(coPlots,         'UPA + BPA',          tFigureOptions);
            
            oPlotter.plot();
         end
    end
    
end


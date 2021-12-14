classdef setup < simulation.infrastructure
    
    properties
    end
    
    methods
        function this = setup(ptConfigParams, tSolverParams)
            
            ttMonitorConfig = struct();
            this@simulation.infrastructure('Example', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            % Creating the root object
            examples.Bosch.systems.Example(this.oSimulationContainer, 'Example');
        end
        
        function configureMonitors(this)
            oLog = this.toMonitors.oLogger;
            
            
            oLog.addValue('Example:c:BoschReactor:s:RWGSr.toPhases.CO2_H2_CO_H2O.toManips.substance',  'fMolarFluxInCO2',                              'mol/s',	'RWGS Molar Inflow CO2');
            oLog.addValue('Example:c:BoschReactor:s:RWGSr.toPhases.CO2_H2_CO_H2O.toManips.substance',  'fMolarFluxOutCO',                              'mol/s',	'RWGS Molar Outflow CO2');
            oLog.addValue('Example:c:BoschReactor:s:RWGSr.toPhases.CO2_H2_CO_H2O.toManips.substance',  'fConversionCO2',                               '-',        'RWGS CO2 Conversion Ratio');
            oLog.addValue('Example:c:BoschReactor:s:RWGSr.toPhases.CO2_H2_CO_H2O.toManips.substance',  'fReactionRate',                                '-',        'RWGS CO2 Reaction Rate'); % should be umol/(gCat*s)
            oLog.addValue('Example:c:BoschReactor:s:RWGSr.toPhases.CO2_H2_CO_H2O.toManips.substance',  'fVelocityConstant',                            '-',        'RWGS Velocity Constant');
            
            oLog.addValue('Example:c:BoschReactor:s:RWGSr.toPhases.CO2_H2_CO_H2O.toManips.substance', 	'this.afPartialFlows(this.oMT.tiN2I.H2)',     	'kg/s',    	'RWGS Manip H2 Flow');
            oLog.addValue('Example:c:BoschReactor:s:RWGSr.toPhases.CO2_H2_CO_H2O.toManips.substance', 	'this.afPartialFlows(this.oMT.tiN2I.CO2)',     	'kg/s',    	'RWGS Manip CO2 Flow');
            oLog.addValue('Example:c:BoschReactor:s:RWGSr.toPhases.CO2_H2_CO_H2O.toManips.substance', 	'this.afPartialFlows(this.oMT.tiN2I.H2O)',     	'kg/s',    	'RWGS Manip H2O Flow');
            oLog.addValue('Example:c:BoschReactor:s:RWGSr.toPhases.CO2_H2_CO_H2O.toManips.substance', 	'this.afPartialFlows(this.oMT.tiN2I.CO)',     	'kg/s',    	'RWGS Manip CO Flow');
           
            oLog.addValue('Example:c:BoschReactor:s:CFR.toPhases.CO2_H2_CO_H2O.toManips.substance', 	'fMolarFluxInH2',                               'mol/s',  	'Carbon Formation Manip H2 Molar Flow');
            oLog.addValue('Example:c:BoschReactor:s:CFR.toPhases.CO2_H2_CO_H2O.toManips.substance', 	'fMolarFluxInCO2',                              'mol/s',  	'Carbon Formation Manip H2 Molar Flow');
            oLog.addValue('Example:c:BoschReactor:s:CFR.toPhases.CO2_H2_CO_H2O.toManips.substance', 	'fMolarFluxInCO',                               'mol/s',  	'Carbon Formation Manip H2 Molar Flow');
            
            oLog.addValue('Example:c:BoschReactor:s:CFR.toPhases.CO2_H2_CO_H2O.toManips.substance', 	'this.afPartialFlows(this.oMT.tiN2I.H2)',     	'kg/s',    	'Carbon Formation Manip H2 Flow');
            oLog.addValue('Example:c:BoschReactor:s:CFR.toPhases.CO2_H2_CO_H2O.toManips.substance', 	'this.afPartialFlows(this.oMT.tiN2I.CO2)',     	'kg/s',    	'Carbon Formation Manip CO2 Flow');
            oLog.addValue('Example:c:BoschReactor:s:CFR.toPhases.CO2_H2_CO_H2O.toManips.substance', 	'this.afPartialFlows(this.oMT.tiN2I.CO)',     	'kg/s',    	'Carbon Formation Manip CO Flow');
            oLog.addValue('Example:c:BoschReactor:s:CFR.toPhases.CO2_H2_CO_H2O.toManips.substance', 	'this.afPartialFlows(this.oMT.tiN2I.H2O)',     	'kg/s',    	'Carbon Formation Manip H2O Flow');
            oLog.addValue('Example:c:BoschReactor:s:CFR.toPhases.CO2_H2_CO_H2O.toManips.substance', 	'this.afPartialFlows(this.oMT.tiN2I.C)',     	'kg/s',    	'Carbon Formation Manip C Flow');
            
            oLog.addValue('Example:s:TankH2.aoPhases(1, 1)',                                    'fPressure',	'Pa',       'Pressure H2 Tank');
            oLog.addValue('Example:s:TankCO2.aoPhases(1, 1)',                                   'fPressure',	'Pa',       'Pressure CO2 Tank');
            oLog.addValue('Example:c:BoschReactor:s:Compressor.aoPhases(1, 1)',                                'fPressure',	'Pa',       'Pressure Compressor');
            oLog.addValue('Example:c:BoschReactor:s:Condensator.toPhases.Condensator',                         'fPressure',	'Pa',       'Pressure Condensator');
            oLog.addValue('Example:c:BoschReactor:s:Condensator.toPhases.Condensate',                          'fPressure',	'Pa',       'Pressure Condensate');
            oLog.addValue('Example:c:BoschReactor:s:RWGSr.aoPhases(1, 1)',                                     'fPressure',	'Pa',       'Pressure RWGS');
            oLog.addValue('Example:c:BoschReactor:s:MembraneReactorCO2.toPhases.Membrane_Reactor1_Input',      'fPressure',	'Pa',       'Pressure CO2 Membrane Reactor Input');
            oLog.addValue('Example:c:BoschReactor:s:MembraneReactorCO2.toPhases.Membrane_Reactor1_Output2',    'fPressure',	'Pa',       'Pressure CO2 Membrane Reactor Output');
            oLog.addValue('Example:c:BoschReactor:s:MembraneReactorH2.toPhases.Membrane_Reactor2_Input',       'fPressure',	'Pa',       'Pressure H2 Membrane Reactor Input');
            oLog.addValue('Example:c:BoschReactor:s:MembraneReactorH2.toPhases.Membrane_Reactor2_Output2',     'fPressure',	'Pa',       'Pressure H2 Membrane Reactor Output');
            oLog.addValue('Example:c:BoschReactor:s:CFR.toPhases.CO2_H2_CO_H2O',                               'fPressure',	'Pa',       'Pressure CFR Flow');
            oLog.addValue('Example:c:BoschReactor:s:CFR.toPhases.C',                                           'fPressure', 'Pa',       'Pressure CFR Carbon');
            oLog.addValue('Example:c:BoschReactor:s:PostFan.toPhases.PostFan',                                 'fPressure', 'Pa',       'Pressure Fan');
            
            
            oLog.addValue('Example:s:TankH2.aoPhases(1, 1)',                                    'fMass',    	'kg',       'Mass H2 Tank');
            oLog.addValue('Example:s:TankCO2.aoPhases(1, 1)',                                   'fMass',        'kg',       'Mass CO2 Tank');
            oLog.addValue('Example:c:BoschReactor:s:Compressor.aoPhases(1, 1)',                                'fMass',     	'kg',       'Mass Compressor');
            oLog.addValue('Example:c:BoschReactor:s:Condensator.toPhases.Condensator',                         'fMass',      	'kg',       'Mass Condensator');
            oLog.addValue('Example:c:BoschReactor:s:Condensator.toPhases.Condensate',                          'fMass',      	'kg',       'Mass Condensate');
            oLog.addValue('Example:c:BoschReactor:s:RWGSr.aoPhases(1, 1)',                                     'fMass',     	'kg',       'Mass RWGS');
            oLog.addValue('Example:c:BoschReactor:s:MembraneReactorCO2.toPhases.Membrane_Reactor1_Input',      'fMass',        'kg',       'Mass CO2 Membrane Reactor Input');
            oLog.addValue('Example:c:BoschReactor:s:MembraneReactorCO2.toPhases.Membrane_Reactor1_Output2',    'fMass',        'kg',       'Mass CO2 Membrane Reactor Output');
            oLog.addValue('Example:c:BoschReactor:s:MembraneReactorH2.toPhases.Membrane_Reactor2_Input',       'fMass',        'kg',       'Mass H2 Membrane Reactor Input');
            oLog.addValue('Example:c:BoschReactor:s:MembraneReactorH2.toPhases.Membrane_Reactor2_Output2',     'fMass',        'kg',       'Mass H2 Membrane Reactor Output');
            oLog.addValue('Example:c:BoschReactor:s:CFR.toPhases.CO2_H2_CO_H2O',                               'fMass',        'kg',       'Mass CFR Flow');
            oLog.addValue('Example:c:BoschReactor:s:CFR.toPhases.C',                                           'fMass',        'kg',       'Mass CFR Carbon');
            oLog.addValue('Example:c:BoschReactor:s:PostFan.toPhases.PostFan',                                 'fMass',        'kg',       'Mass Fan');
            
            oLog.addValue('Example:c:BoschReactor.toBranches.H2_Inlet',                 'fFlowRate',        	'kg/s',    	'H2 to RGWS');
            oLog.addValue('Example:c:BoschReactor.toBranches.CO2_Inlet',                'fFlowRate',        	'kg/s',    	'CO2 to RGWS');
            oLog.addValue('Example:c:BoschReactor.toBranches.RWGS_Compressor',        	'fFlowRate',          	'kg/s',    	'RGWS to Compresor');
            oLog.addValue('Example:c:BoschReactor.toBranches.Compressor_Condensator', 	'fFlowRate',           	'kg/s',    	'Compressor to Condensator');
            oLog.addValue('Example:c:BoschReactor.toBranches.Condensator_Membrane_CO2', 'fFlowRate',            'kg/s',    	'Condensator to Membrane CO2');
            oLog.addValue('Example:c:BoschReactor.toBranches.Condensator_Membrane_H2',	'fFlowRate',        	'kg/s',    	'Condensator to Membrane H2');
            oLog.addValue('Example:c:BoschReactor.toBranches.Membrane_CFR',           	'fFlowRate',           	'kg/s',    	'Membrane to CFR');
            oLog.addValue('Example:c:BoschReactor.toBranches.CFR_Fan',                  'fFlowRate',           	'kg/s',    	'CFR to Fan');
            oLog.addValue('Example:c:BoschReactor.toBranches.Fan_Compressor',        	'fFlowRate',           	'kg/s',    	'Fan to Compressor');
            
            oLog.addValue('Example:c:BoschReactor:s:Condensator.toProcsP2P.WSAProc',                'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2O)',     	'kg/s',    	'Condensator Water Flow');
            oLog.addValue('Example:c:BoschReactor:s:MembraneReactorCO2.toProcsP2P.CO2FilterProc', 	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)',     	'kg/s',    	'Membrane Reactor CO2 Flow');
            oLog.addValue('Example:c:BoschReactor:s:MembraneReactorH2.toProcsP2P.H2FilterProc', 	'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.H2)',     	'kg/s',    	'Membrane Reactor H2 Flow');
            oLog.addValue('Example:c:BoschReactor:s:CFR.toProcsP2P.CFRFilterProc',                  'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.C)',     	'kg/s',    	'CFR C Flow');
            
            this.fSimTime = 1 * 300;
            
        end
        
        function plot(this)
            close all
            oPlotter = plot@simulation.infrastructure(this);
            
            % you can specify additional parameters for the plots, for
            % example you can define the unit for the time axis that should
            % be used (s, min, h, d, weeks possible)
            tPlotOptions.sTimeUnit = 'hours';
            tFigureOptions = struct('bTimePlot', false, 'bPlotTools', false);
            
            coPlots = [];
            csNames = {'"RWGS Molar Inflow CO2"', '"RWGS Molar Outflow CO2"'};
            coPlots{1,1} = oPlotter.definePlot(csNames,     'Molar Flows CO2 RWGS', tPlotOptions);
            csNames = {'"RWGS CO2 Conversion Ratio"', '"RWGS CO2 Reaction Rate"'};
            coPlots{1,2} = oPlotter.definePlot(csNames,     'Conversion and Reaction Rates CO2 RWGS', tPlotOptions);
            csNames = {'"RWGS Velocity Constant"'};
            coPlots{2,1} = oPlotter.definePlot(csNames,     'Velocity Constant RWGS', tPlotOptions);
            csNames = {'"RWGS Manip H2 Flow"', '"RWGS Manip CO2 Flow"', '"RWGS Manip H2O Flow"', '"RWGS Manip CO Flow"'};
            coPlots{2,2} = oPlotter.definePlot(csNames,     'Velocity Constant RWGS', tPlotOptions);
            
            oPlotter.defineFigure(coPlots,  'RWGS', tFigureOptions);
            
            
            coPlots = [];
            csNames = {'"Pressure H2 Tank"', '"Pressure CO2 Tank"', '"Pressure Compressor"', '"Pressure Condensator"', '"Pressure Condensate"',...
                       '"Pressure CO2 Membrane Reactor Input"', '"Pressure CO2 Membrane Reactor Output"', '"Pressure H2 Membrane Reactor Input"',...
                       '"Pressure H2 Membrane Reactor Output"', '"Pressure CFR Flow"', '"Pressure CFR Carbon"', '"Pressure RWGS"', '"Pressure Fan"'};
            coPlots{1,1} = oPlotter.definePlot(csNames,     'System Pressures', tPlotOptions);
            csNames = {'"H2 to RGWS"', '"CO2 to RGWS"', '"RGWS to Compresor"', '"Compressor to Condensator"', '"Condensator to Membrane CO2"',...
                       '"Condensator to Membrane H2"', '"Membrane to CFR"', '"CFR to Fan"', '"Fan to Compressor"'};
            coPlots{1,2} = oPlotter.definePlot(csNames,     'System Flowrates', tPlotOptions);
            csNames = {'"Mass H2 Tank"', '"Mass CO2 Tank"', '"Mass Compressor"', '"Mass Condensator"', '"Mass Condensate"',...
                       '"Mass CO2 Membrane Reactor Input"', '"Mass CO2 Membrane Reactor Output"', '"Mass H2 Membrane Reactor Input"',...
                       '"Mass H2 Membrane Reactor Output"', '"Mass CFR Flow"', '"Mass CFR Carbon"', '"Mass RWGS"', '"Mass Fan"'};
            coPlots{2,1} = oPlotter.definePlot(csNames,     'System Masses', tPlotOptions);
            csNames = {'"Carbon Formation Manip H2 Flow"', '"Carbon Formation Manip CO2 Flow"', '"Carbon Formation Manip CO Flow"', '"Carbon Formation Manip H2O Flow"', '"Carbon Formation Manip C Flow"'};
            coPlots{2,2} = oPlotter.definePlot(csNames,     'CFR Flowrates', tPlotOptions);
            csNames = {'"Condensator Water Flow"', '"Membrane Reactor CO2 Flow"', '"Membrane Reactor H2 Flow"', '"CFR C Flow"'};
            coPlots{3,1} = oPlotter.definePlot(csNames,     'Product Flowrates', tPlotOptions);
            
            oPlotter.defineFigure(coPlots,  'System Pressures and Flowrates', tFigureOptions);
            
            
            oPlotter.plot()
            
        end
    end
end
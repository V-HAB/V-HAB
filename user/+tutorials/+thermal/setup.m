classdef setup < simulation.infrastructure
    
    properties
        tiLogIndexes = struct();
    end
    
    methods
        function this = setup(ptConfigParams, tSolverParams) 
            ttMonitorConfig = struct();
            this@simulation.infrastructure('Tutorial_Thermal_Test', ptConfigParams, tSolverParams, ttMonitorConfig);
            
            tutorials.thermal.systems.Example(this.oSimulationContainer, 'Example');
            
            this.fSimTime = 3600 * 1;
            this.bUseTime = true;
        end
        
        function configureMonitors(this)
            
            oLog = this.toMonitors.oLogger;
            this.tiLogIndexes.iTempIdx1 = oLog.addValue('Example.toProcsF2F.Pipe.aoFlows(1)', 'fTemperature', 'K', 'Flow Temperature - Left', 'flow_temp_left');
            this.tiLogIndexes.iTempIdx2 = oLog.addValue('Example.toProcsF2F.Pipe.aoFlows(2)', 'fTemperature', 'K', 'Flow Temperature - Right', 'flow_temp_right');
            
            oLog.addValue('Example:s:Tank_1.toPhases.Tank1Air',                   'afPP(this.oMT.tiN2I.CO2)',     'Pa',   'Partial Pressure CO_2 Tank 1', 'ppCO2_Tank1');
            oLog.addValue('Example:s:Tank_2.toPhases.Tank2Air',                   'afPP(this.oMT.tiN2I.CO2)',     'Pa',   'Partial Pressure CO_2 Tank 2', 'ppCO2_Tank2');
            
            oLog.addValue('Example.aoBranches(1).aoFlows(1)', 'this.fFlowRate * this.arPartialMass(this.oMT.tiN2I.CO2)', 'kg/s', 'Flowrate of CO2', 'fr_co2');
            
            oLog.addValue('Example:s:Tank_1.toPhases.Tank1Air', 'afMass(this.oMT.tiN2I.CO2)', 'kg');
            oLog.addValue('Example:s:Tank_2.toPhases.Tank2Air', 'afMass(this.oMT.tiN2I.CO2)', 'kg', 'Partial Mass CO_2 Tank 2');
            
            oLog.addValue('Example:s:Tank_1.toPhases.Tank1Air',         'fTemperature', 'K', 'Temperature Air 1');
            oLog.addValue('Example:s:Tank_2.toPhases.Tank2Air',         'fTemperature', 'K', 'Temperature Air 2');
            oLog.addValue('Example:s:Space.toPhases.VacuumPhase',       'fTemperature', 'K', 'Temperature Space');
            
            oLog.addValue('Example:c:SubSystem:s:Filter.toPhases.FlowPhase',        'fTemperature', 'K', 'Temperature Filter Flow');
            oLog.addValue('Example:c:SubSystem:s:Filter.toPhases.FlowPhase',        'fPressure',    'Pa','Pressure Filter Flow');
            oLog.addValue('Example:c:SubSystem:s:Filter.toPhases.FilteredPhase',    'fTemperature', 'K', 'Temperature Filter Absorbed');
            
            oLog.addValue('Example:s:Tank_1.toPhases.Tank1Air', 'this.fMass * this.fMassToPressure', 'Pa', 'Pressure Phase 1');
            oLog.addValue('Example:s:Tank_2.toPhases.Tank2Air', 'this.fMass * this.fMassToPressure', 'Pa', 'Pressure Phase 2');
            
            oLog.addValue('Example.toBranches.Branch',              'fFlowRate', 'kg/s', 'Branch Flow Rate', 'branch_FR');
            oLog.addValue('Example:c:SubSystem.toBranches.Inlet',   'fFlowRate', 'kg/s', 'Subsystem Inlet Flow Rate');
            oLog.addValue('Example:c:SubSystem.toBranches.Outlet',  'fFlowRate', 'kg/s', 'Subsystem Outlet Flow Rate');
            
            oLog.addValue('Example.toThermalBranches.Branch',                   'fHeatFlow', 'W', 'Branch Heat Flow');
            oLog.addValue('Example.toThermalBranches.Radiator',                 'fHeatFlow', 'W', 'Radiator Heat Flow');
            oLog.addValue('Example.toThermalBranches.Pipe_Material_Conductor',	'fHeatFlow', 'W', 'Pipe Conductor Heat Flow');
            oLog.addValue('Example:c:SubSystem.toThermalBranches.Inlet',        'fHeatFlow', 'W', 'Subsystem Inlet Heat Flow');
            oLog.addValue('Example:c:SubSystem.toThermalBranches.Outlet',       'fHeatFlow', 'W', 'Subsystem Outlet Heat Flow');
            
            oLog.addValue('Example:c:SubSystem.toThermalBranches.filterproc',                   'fHeatFlow', 'W', 'Subsystem Adsorption Mass Heat Flow');
            oLog.addValue('Example:c:SubSystem.toThermalBranches.Pipe_Material_Conductor_In',   'fHeatFlow', 'W', 'Subsystem Conduction Inlet Heat Flow');
            oLog.addValue('Example:c:SubSystem.toThermalBranches.Pipe_Material_Conductor_Out',	'fHeatFlow', 'W', 'Subsystem Conduction Outlet Heat Flow');
            oLog.addValue('Example:c:SubSystem.toThermalBranches.Convective_Branch',            'fHeatFlow', 'W', 'Subsystem Convective Heat Flow');
            
            oLog.addValue('Example:s:Tank_1.toPhases.Tank1Air.oCapacity.toHeatSources.Heater', 'fHeatFlow', 'W', 'Phase 1 Heat Source Heat Flow');
            
        end
        
        function plot(this) 
            
            oPlotter = plot@simulation.infrastructure(this);
            
            tPlotOptions = struct('sTimeUnit','hours');
            coPlots = [];
            coPlots{1,1} = oPlotter.definePlot({'"Temperature Air 1"', '"Temperature Air 2"', '"Temperature Space"', '"Temperature Filter Flow"', '"Temperature Filter Absorbed"'}, 'Temperatures', tPlotOptions);
            coPlots{1,2} = oPlotter.definePlot({'"Pressure Phase 1"', '"Pressure Phase 2"', '"Pressure Filter Flow"'}, 'Pressure', tPlotOptions);
            coPlots{2,1} = oPlotter.definePlot({'"Branch Flow Rate"', '"Subsystem Inlet Flow Rate"', '"Subsystem Outlet Flow Rate"'}, 'Flowrate', tPlotOptions);
            coPlots{2,2} = oPlotter.definePlot({'"Branch Heat Flow"', '"Radiator Heat Flow"', '"Pipe Conductor Heat Flow"', '"Subsystem Inlet Heat Flow"',...
                '"Subsystem Outlet Heat Flow"', '"Subsystem Conduction Inlet Heat Flow"', '"Subsystem Conduction Outlet Heat Flow"',...
                '"Subsystem Convective Heat Flow"', '"Phase 1 Heat Source Heat Flow"', '"Subsystem Adsorption Mass Heat Flow"'}, 'Heat Flows', tPlotOptions);
            oPlotter.defineFigure(coPlots, 'Thermal Values and Flowrates');
            
            oPlotter.plot();
        end
    end
end
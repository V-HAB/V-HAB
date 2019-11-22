
classdef setup < simulation.infrastructure
    
    properties
        
    end
    
    methods
        
        function this = setup(ptConfigParams, tSolverParams)
            
            ttMonitorConfig = struct();
            this@simulation.infrastructure('RFCS', ptConfigParams, tSolverParams, ttMonitorConfig);
            examples.RFCS.system.big_system(this.oSimulationContainer,'big_system');
            
            %simulation length
            this.fSimTime = 60*60; % In seconds (8.3 hours)
            this.bUseTime = true;
        end
        
        function configureMonitors(this)
            %logging
            oLog = this.toMonitors.oLogger;
            oLog.add('big_system', 'flow_props');
            oLog.add('big_system', 'thermal_properties');
            
            oLog.add('big_system/Subsystem_Fuelcell', 'thermal_properties');
            oLog.add('big_system/Subsystem_Electrolyseur', 'thermal_properties');
            %
            %
            oLog.add('big_system/Subsystem_Fuelcell', 'flow_props');
            oLog.add('big_system/Subsystem_Electrolyseur', 'flow_props');
            
            oLog.addValue('big_system', 'this.toChildren.Subsystem_Fuelcell.fVoltage', 'V', 'ohneKondensator');
            oLog.addValue('big_system', 'this.toChildren.Subsystem_Fuelcell.Uc', 'V', 'Spannung_Brennstoffzelle');
            oLog.addValue('big_system', 'this.toChildren.Subsystem_Fuelcell.fI', 'A', 'Strom_Brennstoffzelle');
            oLog.addValue('big_system', 'this.toChildren.Subsystem_Fuelcell.toStores.gaschanal_in_h2.toProcsP2P.H2_Absorber_gaschanal.y', 'F', 'FFF');
            oLog.addValue('big_system', 'this.toChildren.Subsystem_Fuelcell.toStores.gaschanal_in_h2.toProcsP2P.H2_Absorber_gaschanal.u', 'F', 'FFF1');
            oLog.addValue('big_system', 'this.toChildren.Subsystem_Fuelcell.toStores.gaschanal_in_o2.toPhases.O2_H2O.rRelHumidity', '%', 'Humidity');
            oLog.addValue('big_system', 'this.toChildren.Subsystem_Fuelcell.toStores.gaschanal_in_h2.toPhases.fuel.rRelHumidity', '%', 'Humidity');
            
            oLog.addValue('big_system', 'this.toChildren.Subsystem_Fuelcell.eta', 'r', ' eta_Fuelcell');
            oLog.addValue('big_system', 'this.toChildren.Subsystem_Fuelcell.heat', 'W', ' Heat_Fuelcell');
            oLog.addValue('big_system', 'this.toChildren.Subsystem_Electrolyseur.heat', 'W', ' Heat_Elektrolyser');
            oLog.addValue('big_system', 'this.toChildren.Subsystem_Electrolyseur.fPower', 'W', ' Power');
            oLog.addValue('big_system', 'this.toChildren.Subsystem_Electrolyseur.fI', 'A', 'Strom_Elektrolyseur');
            oLog.addValue('big_system', 'this.toChildren.Subsystem_Electrolyseur.uz', 'V', 'Spannung_Elektrolyseur');
            oLog.addValue('big_system', 'this.toProcsF2F.Radiator.fHeatFlow', 'W', 'Heat Flow_Radiator');
            oLog.addValue('big_system', 'this.toProcsF2F.HeatExchanger_Electrolyseur_1.fHeatFlow', 'W', 'Heat Flow_Elektrolyseur_XC');
            oLog.addValue('big_system', 'this.toProcsF2F.HeatExchanger_Fuelcell_1.fHeatFlow', 'W', 'Heat Flow_Brennstoffzelle_XC');
            %
            
            
            oPlot = this.toMonitors.oPlotter;
            
            
            oPlot.definePlotAllWithFilter('V',  'Voltage');
            oPlot.definePlotAllWithFilter('A',  'Current');
            
            oPlot.definePlotAllWithFilter('Pa',  'Tank Pressures');
            oPlot.definePlotAllWithFilter('kg',  'Masses');
            oPlot.definePlotAllWithFilter('K',   'Temperatures');
            oPlot.definePlotAllWithFilter('kg/s',   'Flowrate');
            oPlot.definePlotAllWithFilter('F',   'FFF');
            oPlot.definePlotAllWithFilter('%',   'Humidity');
            oPlot.definePlotAllWithFilter('W',   'Heat');
            oPlot.definePlotAllWithFilter('r',   'Wirkungsgrad');
            
            
            
            
        end
        function plot(this)
            
            close all % closes all currently open figures
            this.toMonitors.oPlotter.plot();
        end
    end
end
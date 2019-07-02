classdef Example < vsys
    %EXAMPLE Example simulation for a simple flow in V-HAB 2.0
    %   Two tanks filled with gas at different temperatures and pressures
    %   with a pipe in between
    
    properties
        % This system does not have any properties
    end
    
    methods
        function this = Example(oParent, sName)
            % Calling the parent constructor. This has to be done for any
            % class that has a parent. The third parameter defines how
            % often the .exec() method of this subsystem is called. 
            % Values can be: 0-inf for interval in [s] (zero means with
            % lowest time step set for the timer). -1 means with every TICK
            % of the timer, which is determined by the smallest time step
            % of any of the systems. Providing a logical 'false' means the
            % .exec() method is called when the oParent.exec() is executed
            % (see this .exec() method - always call exec@vsys as well!).
            this@vsys(oParent, sName, 30);
            
        end
        
        
        function createMatterStructure(this)
            % This function creates all simulation objects in the matter
            % domain. 
            
            % First we always need to call the createMatterStructure()
            % method of the parent class.
            createMatterStructure@vsys(this);
            
            % Creating a store, volume 1 m^3
            matter.store(this, 'Tank_1', 1);
            
            % Adding a phase to the store 'Tank_1', 1 m^3 air at 20 deg C
            oGasPhase = this.toStores.Tank_1.createPhase('air', 1, 293.15);
            
            % Creating a second store, volume 1 m^3
            matter.store(this, 'Tank_2', 1);
            
            % Adding a phase to the store 'Tank_2', 2 m^3 air at 50 deg C
            % Note that we are creating a phase that is twice as voluminous
            % as the store it is in. This means that the pressure of this
            % phase will be higher than that of 'Tank_1'
            oAirPhase = this.toStores.Tank_2.createPhase('air', 1, 293.15, 0.5, 5e5);
            
            % Adding a pipe to connect the tanks, 1.5 m long, 5 mm in
            % diameter. The pipe is in the components library and is
            % derived from the flow-to-flow (f2f) processor class
            examples.HeatOfExpansion.components.ThermallyActivePipe(this, 'Pipe', 1.5, 0.005, 2e-3);
            
            % Creating the flowpath, called a branch in V-HAB, between the
            % components. 
            % The input parameter format is always:
            % system object, phase object, {name(s) of f2f-processor(s)}, phase object
            matter.branch(this, oGasPhase, {'Pipe'}, oAirPhase, 'Branch');
            
        end
        
        
        function createThermalStructure(this)
            % This function creates all simulation objects in the thermal
            % domain. 
            
            % First we always need to call the createThermalStructure()
            % method of the parent class.
            createThermalStructure@vsys(this);
            
            
            oHeatSource1 = components.thermal.heatsources.JouleThomson('JouleThomsonSource_1');
            oHeatSource2 = components.thermal.heatsources.JouleThomson('JouleThomsonSource_2');
            this.toStores.Tank_1.aoPhases(1).oCapacity.addHeatSource(oHeatSource1);
            this.toStores.Tank_2.aoPhases(1).oCapacity.addHeatSource(oHeatSource2);
            
        end
        
        
        function createSolverStructure(this)
            % This function creates all of the solver objects required for
            % a simulation. 
            
            % First we always need to call the createSolverStructure()
            % method of the parent class.
            createSolverStructure@vsys(this);
            
            % Creating an interval solver object that will solve for the
            % flow rate of the one branch in this system.
            solver.matter.interval.branch(this.toBranches.Branch);

            % Since we want V-HAB to calculate the temperature changes in
            % this system we call the setThermalSolvers() method of the
            % thermal.container class. 
            this.setThermalSolvers();
            
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            % exec(ute) function for this system 
            % This function can be used to change the system state, e.g.
            % close valves or switch on/off components.
            
            % Here it only calls its parent's exec() method
            exec@vsys(this);
            
        end
        
     end
    
end


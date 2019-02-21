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
            this.toStores.Tank_1.createPhase('air', 'Cold', 1, 293.15);
            
            % Creating a second store, volume 1 m^3
            matter.store(this, 'Tank_2', 1);
            
            % Adding a phase to the store 'Tank_1', 1 m^3 air at 220 deg C
            this.toStores.Tank_2.createPhase('air', 'Hot', 1, 493.15);
        end
        
        
        function createThermalStructure(this)
            % This function creates all simulation objects in the thermal
            % domain. 
            
            % First we always need to call the createThermalStructure()
            % method of the parent class.
            createThermalStructure@vsys(this);
            
            % Creating a thermal conductor between the two tanks, the
            % resistance is 1 K/W.
            thermal.procs.conductors.conductive(this, 'Thermal_Connection', 1)
            
            % Getting a reference to both phases
            oPhaseCold = this.toStores.Tank_1.toPhases.Cold;
            oPhaseHot  = this.toStores.Tank_2.toPhases.Hot;
            
            % Addding a thermal branch between the two phases.
            thermal.branch(this, oPhaseCold, {'Thermal_Connection'}, oPhaseHot)
        end
        
        
        function createSolverStructure(this)
            % This function creates all of the solver objects required for
            % a simulation. 
            
            % First we always need to call the createSolverStructure()
            % method of the parent class.
            createSolverStructure@vsys(this);
            
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


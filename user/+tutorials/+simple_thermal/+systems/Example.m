classdef Example < vsys
    %EXAMPLE Example simulation for a simple thermal problem in V-HAB 2
    %   Two tanks filled with gas at different temperatures with a
    %   conductive thermal interface (metal bar) connecting them
    
    properties
    end
    
    methods
        function this = Example(oParent, sName)
            this@vsys(oParent, sName, 30);
        end
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            matter.store(this, 'Tank_1', 1);
            this.toStores.Tank_1.createPhase('air', 'Cold', 1, 293.15);
            
            matter.store(this, 'Tank_2', 1);
            this.toStores.Tank_2.createPhase('air', 'Hot', 1, 493.15);
        end
        
        
        function createThermalStructure(this)
            % This function creates all simulation objects in the thermal
            % domain. It is similar to the createMatterStructure but only
            % exists in systems which do define thermal components.
            
            % First we always need to call the createThermalStructure()
            % method of the parent class.
            createThermalStructure@vsys(this);
            
            % Creating a thermal conductor between the two tanks, the
            % resistance is 1 K/W. The thermal domain uses the electrical
            % analog and is therefore completly based on thermal
            % resistances! A thermal resistance of 1 K/W means, that for
            % each K temperature difference, 1 W of thermal energy is
            % transfered.
            thermal.procs.conductors.conductive(this, 'Thermal_Connection', 1);
            
            % Getting a reference to both capacities
            oCapacityCold = this.toStores.Tank_1.toPhases.Cold.oCapacity;
            oCapacityHot  = this.toStores.Tank_2.toPhases.Hot.oCapacity;
            
            % Addding a thermal branch between the two phases.
            thermal.branch(this, oCapacityCold, {'Thermal_Connection'}, oCapacityHot);
        end
        
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            % If you only want to use the standard thermal solvers, you can
            % simply use the "setThermalSolvers" function, which assigns
            % the basic thermal solver to all thermal branches with
            % conductors, the basic_fluidic solver to all thermal branches
            % for mass bound energy transfer and the infinite conduction
            % solver for all thermal branches without conductors (assumed
            % to be at 0 resistance). If you define any thermal solvers
            % before this call, you can still use it to assign these basic
            % solvers to the remaining thermal branches!
            this.setThermalSolvers();
            
        end
    end
    
    methods (Access = protected)
        
        function exec(this, ~)
            exec@vsys(this);
            
        end
    end
end
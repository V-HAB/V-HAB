classdef Example < vsys
    %EXAMPLE Example simulation for a simple flow solved by the equalizer
    %   solver in V-HAB 2.0. Two tanks filled with gas at different
    %   temperatures and pressures with a pipe in between
    
    methods
        function this = Example(oParent, sName)
            this@vsys(oParent, sName, 30);
            
        end
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            matter.store(this, 'Tank_1', 1);
            oGasPhase = this.toStores.Tank_1.createPhase('air', 1, 293.15);
            
            matter.store(this, 'Tank_2', 1);
            oAirPhase = this.toStores.Tank_2.createPhase('air', 'boundary', 1, 323.15, 0.5, 2e5);
            
            components.matter.pipe(this, 'Pipe', 1.5, 0.005);
            matter.branch(this, oGasPhase, {'Pipe'}, oAirPhase, 'Branch');
            
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            % The equalizer solver can be assigned to the branch like any
            % other solver. For information regarding the input parameters,
            % view the description in the equalizer solver!
            solver.matter.equalizer.branch(this.toBranches.Branch, 0.1, 2*10^5);

            this.setThermalSolvers();
            
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            exec@vsys(this);
            
        end
     end
end
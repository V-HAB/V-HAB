classdef Example < vsys
    %EXAMPLE A system that contains variable volumes
    % And example for this would be the bladder in a space suit, which is
    % flexible and therefore changes its volume.
    
    properties
    end
    
    methods
        function this = Example(oParent, sName)
            this@vsys(oParent, sName, 30);
            
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            matter.store(this, 'Tank_1', 1);
            oTank1Phase = this.toStores.Tank_1.createPhase('air', 1, 293.15);
            
            matter.store(this, 'Tank_2', 1);
            oTank2Phase = this.toStores.Tank_2.createPhase('air', 1, 323.15, 0.5, 1e5);
            
            % Here we add the volume manipulator to the phase inside tank
            % 1. It basically works the same way a substance manipulator
            % could be used, you use the path of the manipulator you want
            % to add and provide the required inputs. The inputs are always
            % a name and a phase, but can depend on the specific manip,
            % therefore go to the file for this manip to learn more about
            % it.
            tutorials.volume_manipulator.components.volumeChanger('Compressor', oTank1Phase);
            
            components.matter.pipe(this, 'Pipe', 1.5, 0.005);
            matter.branch(this, oTank1Phase, {'Pipe'}, oTank2Phase, 'Branch');
            
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            solver.matter.interval.branch(this.toBranches.Branch);
            
            this.setThermalSolvers();
            
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            exec@vsys(this);
            
        end
     end
end
classdef ExampleSubsystem < vsys
    %EXAMPLESUBSYSTEM A subsystem containing a filter and a pipe
    %   This example shows a vsys child representing a subsystem of a 
    %   larger system. It has a filter which removes O2 from the mass flow 
    %   through the subsystem and it provides the neccessary setIfFlows 
    %   function so the subsystem branches can be connected to the system 
    %   level branches.
    
    properties
    end
    
    methods
        function this = ExampleSubsystem(oParent, sName)
            
            this@vsys(oParent, sName);
            
            eval(this.oRoot.oCfgParams.configCode(this));
            
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            % Creating a filter as shown in the p2p Example
            tutorials.subsubsystems.components.Filter(this, 'Filter', 10);
            
            % Creating the branch from the parent system into this subsystem
            % Input parameter format is always: 
            % 'store.exme', {'f2f-processor, 'f2fprocessor'}, 'Interface port name'
            matter.branch(this, 'Filter.FilterIn', {}, 'Inlet');
            
            % Creating the branch out of this subsystem into the parent system 
            % Input parameter format is always: 
            % 'store.exme', {'f2f-processor, 'f2fprocessor'}, 'Interface port name'
            matter.branch(this, 'Filter.FilterOut', {}, 'Outlet');
            
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            % Create the solver instances. Generally, this can be done here
            % or directly within the vsys (after the .seal() command).
            solver.matter.interval.branch(this.aoBranches(1));
            solver.matter.interval.branch(this.aoBranches(2));
            
            
            
            % Phases
            
            oFilterFlowPhase = this.toStores.Filter.aoPhases(1);
            oFilterBedPhase  = this.toStores.Filter.aoPhases(2);
            
            % We are not really interested in the pressure, heat capacity
            % etc. of the filtered phase, so we don't need to re-calculate
            % it often. So we set a large maximum change. 
            
            tTimeStepProperties.rMaxChange = 0.5;
            oFilterBedPhase.setTimeStepProperties(tTimeStepProperties);
            
            this.setThermalSolvers();

        end
        
        function setIfFlows(this, sInlet, sOutlet)
            % This function connects the system and subsystem level branches with each other. It
            % uses the connectIF function provided by the matter.container class
            
            this.connectIF('Inlet',  sInlet);
            this.connectIF('Outlet', sOutlet);
            
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            exec@vsys(this);
            
            % See above - time step of this .exec() method is set above,
            % can be used to update some stuff (e.g. apply external
            % disturbances as closing a valve).
  
        end
        
     end
    
end


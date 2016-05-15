classdef MiddleSystem < vsys
    %EXAMPLESUBSYSTEM A subsystem containing a filter and a pipe
    
    
    properties
    end
    
    methods
        function this = MiddleSystem(oParent, sName)
            
            this@vsys(oParent, sName);
            
            eval(this.oRoot.oCfgParams.configCode(this));
            
            % Adding the subsystem
            tutorials.subsubsystems.subsystems.ExampleSubsystem(this, 'SubSystem');
            
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            components.pipe(this, 'Pipe3', 1, 0.005);
            components.pipe(this, 'Pipe4', 1, 0.005);
            
            matter.branch(this, 'FromSubOut', {}, 'ToSupIn');
            
            matter.branch(this, 'FromSubIn', {}, 'ToSupOut');
            
            this.toChildren.SubSystem.setIfFlows('FromSubIn', 'FromSubOut');
            
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
        end
        
        function setIfFlows(this, sToSupIn, sToSupOut)
            % This function connects the system and subsystem level branches with each other. It
            % uses the connectIF function provided by the matter.container class
            
            this.connectIF('ToSupIn',  sToSupIn);
            this.connectIF('ToSupOut', sToSupOut);
            
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


classdef ExampleSubsystem < vsys
    %EXAMPLESUBSYSTEM A subsystem containing a filter and a pipe
    %   This example shows a vsys child representing a subsystem of a larger system. It has a Filter
    %   which removes O2 from the mass flow through the subsystem and it provides the neccessary
    %   setIfFlows function so the subsystem branches can be connected to the system level branches.
    %   The pipe is only added for demonstration purposes.
    
    properties
    end
    
    methods
        function this = ExampleSubsystem(oParent, sName)
            
            this@vsys(oParent, sName, 60);
            
            % Creating a filter as shown in the p2p Example
            this.addStore(tutorials.subsystems.components.Filter(this.oData.oMT, 'Filter', 10));
            
            % Creating the branch from the parent system into this subsystem
            % Input parameter format is always: 
            % 'store.exme', {'f2f-processor, 'f2fprocessor'}, 'System level port name'
            oBranch1 = this.createBranch('Filter.FilterIn', {}, 'Inlet');
            
            % Adding a pipe for fun
            this.addProcF2F(components.pipe(this.oData.oMT, 'Pipe3', 1, 0.1));
            
            % Creating the branch out of this subsystem into the parent system 
            % Input parameter format is always: 
            % 'store.exme', {'f2f-processor, 'f2fprocessor'}, 'System level port name'
            oBranch2 = this.createBranch('Filter.FilterOut', {'Pipe3'}, 'Outlet');
                                      
            % Seal - systems always have to do that!
            this.seal();
            
            % Adding the branches to the linear solver
            solver.matter.linear.branch(oBranch1);
            solver.matter.linear.branch(oBranch2);
            
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


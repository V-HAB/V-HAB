classdef ExampleSubsystem < vsys
    %EXAMPLESUBSYSTEM A subsystem containing a filter and a pipe
    %   This example shows a vsys child representing a subsystem of a 
    %   larger system. It has a filter which removes O2 from the mass flow 
    %   through the subsystem and it provides the neccessary setIfFlows() 
    %   method so the subsystem branches can be connected to the system 
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
            
            fFilterVolume = 1;
            matter.store(this, 'Filter', fFilterVolume);
            oFlow = this.toStores.Filter.createPhase(	'gas',  'flow',	'FlowPhase',	1e-6,   struct('N2', 8e4, 'O2', 2e4, 'CO2', 500),       293,	0.5);
            oFiltered = matter.phases.mixture(this.toStores.Filter, 'FilteredPhase', 'solid', struct('Zeolite13x', 1), 293, 1e5);
            
            tutorials.p2p.flow.components.AbsorberExampleFlow(this.toStores.Filter, 'filterproc', oFlow, oFiltered);
            
            % For the F2F components you must be carefull to use different
            % names for all F2F components in interface branches. E.g.
            % since the parent system uses Pipe1 and Pipe2 we cannot use
            % these names here. Instead we use SubsystemPipe1. In your case
            % try to use well defined names, which e.g. reflect the
            % system to which the interface F2Fs belong. (e.g. CCAA_Pipe1)
            components.matter.pipe(this, 'SubsystemPipe1', 1, 0.005);
            components.matter.pipe(this, 'SubsystemPipe2', 1, 0.005);
            
            
            %% Define Interfaces to parent system
            % The definition in the subsystem also adheres to the logic,
            % that positive flowrates leave the subsystem and enter the
            % parent system. Therefore, the interfaces for the subsystem
            % are defined on the "right" side of the branches!
            matter.branch(this, oFlow, {'SubsystemPipe1'}, 'Inlet');
            matter.branch(this, oFlow, {'SubsystemPipe2'}, 'Outlet');
            
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            solver.matter_multibranch.iterative.branch(this.aoBranches, 'complex');
            
            this.setThermalSolvers();
        end
        
        function setIfFlows(this, varargin)
            % This function connects the parent system and subsystem level
            % branches. The interfaces of the parent side are provided as
            % strings and each individual call of "connectIF" defines to
            % which interface the first second or third interface are
            % connected. It is possible to use varargin for a variable
            % number of inputs (e.g. if the subsystem has different states,
            % for example the Common Cabin Air Assembly, CCAA, can be used
            % with or without a CDRA and has a variable number of
            % interfaces). However, if you use varargin you should check if
            % a valid number of interfaces was provided to prevent erronous
            % definitions.
            % As alternative to varargin you could define multiple inputs,
            % e.g. in this case you could define:
            % setIfFlows(this, sInlet, sOutlet)
            % And then use sInlet and sOutlet for the connectIF functions.
            
            if length(varargin) ~= 2
                error('wrong number of interfaces provided to ExampleSubsystem')
            end
            
            this.connectIF('Inlet',  varargin{1});
            this.connectIF('Outlet', varargin{2});
            
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            exec@vsys(this);
  
        end
     end
end
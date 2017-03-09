classdef Example < vsys
    %EXAMPLE Example simulation for a simple flow in V-HAB 2.0
    %   Two tanks filled with gas at different pressures and a pipe in between
    
    properties (SetAccess = protected, GetAccess = public)
        fPipeLength   = 1.5;
        fPipeDiameter = 0.005;
        
        % Pressure difference in bar
        fPressureDifference = 1;
    end
    
    methods
        function this = Example(oParent, sName)
            % Call parent constructor. Third parameter defined how often
            % the .exec() method of this subsystem is called. This can be
            % used to change the system state, e.g. close valves or switch
            % on/off components.
            % Values can be: 0-inf for interval in [s] (zero means with
            % lowest time step set for the timer). -1 means with every TICK
            % of the timer, which is determined by the smallest time step
            % of any of the systems. Providing a logical false (def) means
            % the .exec method is called when the oParent.exec() is
            % executed (see this .exec() method - always call exec@vsys as
            % well!).
            this@vsys(oParent, sName, 30);
            
            % Make the system configurable
%             disp(this);
%             disp('------------');
%             disp(this.oRoot.oCfgParams.configCode(this));
%             disp('------------');
%             disp(this.oRoot.oCfgParams.get(this));
%             disp('------------');
            eval(this.oRoot.oCfgParams.configCode(this));
            
            %disp(this);
            
            
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            % Creating a store, volume 1 m^3
            matter.store(this, 'Tank_1', 1);
            
            tfPartialPressure = struct('N2', 8e4, 'CO2', 2e4);
            tfMasses = matter.helper.phase.create;
            %Adding a phase to the store 'Tank_1', 1 m^3 air at 20 deg C
            oGasPhase = matter.phases.gas(this.toStores.Tank_1, 'FilteredPhase', tfMasses, 10, 293);
            
            %oGasPhase = this.toStores.Tank_1.createPhase('air', 1, 293.15);
            oGasPhase = this.toStores.Tank_1.createPhase('gas', 10, tfPartialPressure, 293, 0.5);
            
            % Creating a second store, volume 1 m^3
            matter.store(this, 'Tank_2', 1);
            
            tfMasses = struct('N2', 10, 'CO2', 2, 'H2O', 4);
            % Adding a phase to the store 'Tank_2', 2 m^3 air at 50 deg C
            oAirPhase = matter.phases.gas(this.toStores.Tank_2, 'FilteredPhase', tfMasses, 10, 293);
%             oAirPhase = this.toStores.Tank_2.createPhase('air', this.fPressureDifference + 1, 323.15);
            
            % Adding extract/merge processors to the phase
            matter.procs.exmes.gas(oGasPhase, 'Port_1');
            matter.procs.exmes.gas(oAirPhase, 'Port_2');
             
            % Adding a pipe to connect the tanks, 1.5 m long, 5 mm in
            % diameter.
            components.pipe(this, 'Pipe', this.fPipeLength, this.fPipeDiameter);
            
            % Creating the flowpath (=branch) between the components
            % Input parameter format is always: 
            % 'store.exme', {'f2f-processor, 'f2fprocessor'}, 'store.exme'
            matter.branch(this, 'Tank_1.Port_1', {'Pipe'}, 'Tank_2.Port_2');
            
        end
        
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            % Now that the system is sealed, we can add the branch to a
            % specific solver. In this case we will use the iterative
            % solver. 
            %oIt1 = solver.matter.iterative.branch(this.aoBranches(1));
            oBranch = solver.matter.manual.branch(this.aoBranches(1));
             oBranch.setFlowRate(0.1);
             
            %oIt1.iDampFR = 5;
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            % exec(ute) function for this system
            % Here it only calls its parent's exec function
            exec@vsys(this);
            
        end
        
     end
    
end


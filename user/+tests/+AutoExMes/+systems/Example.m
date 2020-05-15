classdef Example < vsys
    %EXAMPLE Example simulation using automatically generated ExMe processors
    %   Two tanks filled with gas at different pressures and a pipe in
    %   between. This is the same setup as for the simple_flow tutorial,
    %   only the ExMe processors on both phases are created automatically,
    %   reducing the number of lines of code. 
    
    properties (SetAccess = protected, GetAccess = public)
        % Pressure difference in Pa
        fPressureDifference = 10^5;
    end
    
    methods
        function this = Example(oParent, sName)
            % Call parent constructor
            this@vsys(oParent, sName, 30);
            
            % Make the system configurable
            eval(this.oRoot.oCfgParams.configCode(this));
            
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            % Creating a store, volume 1 m^3
            matter.store(this, 'Tank_1', 1);
            
            % Adding a phase to the store 'Tank_1', 1 m^3 air at 20 deg C
            oGasPhase = this.toStores.Tank_1.createPhase('air', 1, 293.15);
            
            % Creating a second store, volume 1 m^3
            matter.store(this, 'Tank_2', 1);
            
            % Adding a phase to the store 'Tank_2', 1 m^3 air at 50 deg C
            % and 200 kPa
            oAirPhase = this.toStores.Tank_2.createPhase('air', 1, 323.15, [], this.fPressureDifference + 10^5);
            
            % Adding a pipe to connect the tanks, 1.5 m long, 5 mm in
            % diameter.
            components.matter.pipe(this, 'Pipe', 1.5, 0.005);
            
            % Creating the flowpath (=branch) between the components. Note
            % that here we are using the matter.phase objects as the left
            % and right sides of the branch directly, instead of defining
            % specific ExMes and then passing in a string containing
            % <StoreName>.<ExMeName>. The ExMes are then automatically
            % created in both the matter and thermal domain. 
            matter.branch(this, oGasPhase, {'Pipe'}, oAirPhase, 'Branch');
            
        end
        
        
        function createThermalStructure(this)
            createThermalStructure@vsys(this);
            
        end
        
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            % Now that the system is sealed, we can add the branch to a
            % specific solver. In this case we will use the iterative
            % solver. 
            solver.matter.interval.branch(this.toBranches.Branch);
            
            this.setThermalSolvers();
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            % exec(ute) function for this system
            % Here it only calls its parent's exec function
            exec@vsys(this);
            
            if ~base.oDebug.bOff, this.out(2, 1, 'exec', 'Exec vsys %s', { this.sName }); end
        end
        
     end
    
end


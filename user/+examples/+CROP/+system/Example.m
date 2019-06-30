classdef Example < vsys
    %EXAMPLE Example simulation for a CROP filter in V-HAB 2.0
    
    properties (SetAccess = protected, GetAccess = public)
        
        
    end
    
    methods
        function this = Example(oParent, sName)
            this@vsys(oParent, sName, 60);
            
            components.matter.CROP.CROP(this, 'CROP');
            
            eval(this.oRoot.oCfgParams.configCode(this));
            
        end
        
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            % Creates a store for the potable water reserve
            % Potable Water Store
            matter.store(this, 'CROP_Solution_Storage', 100);
            
            oSolutionPhase = matter.phases.liquid(this.toStores.CROP_Solution_Storage, 'Solution', struct('H2O', 0.1), 295, 101325);
            
            matter.procs.exmes.liquid(oSolutionPhase, 'Solution_In');
            
            % Creates a store for the urine
            matter.store(this, 'UrineStorage', 100);
            
            oUrinePhase = matter.phases.mixture(this.toStores.UrineStorage, 'Urine', 'liquid', struct('C2H6O2N2', 100*0.059, 'H2O', 100*1.6), 295, 101325); 
            
            matter.procs.exmes.mixture(oUrinePhase, 'Urine_Out');
            
            matter.branch(this, 'CROP_Urine_Inlet',        { }, 'UrineStorage.Urine_Out',               'CROP_Urine_Inlet');
            matter.branch(this, 'CROP_Solution_Outlet',    { }, 'CROP_Solution_Storage.Solution_In',    'CROP_Solution_Outlet');
            
            this.toChildren.CROP.setIfFlows('CROP_Urine_Inlet', 'CROP_Solution_Outlet');
        end
        
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
            this.setThermalSolvers();
        end
    end
    
     methods (Access = protected)
        
        function exec(this, ~)
            % exec(ute) function for this system
            % Here it only calls its parent's exec function
            exec@vsys(this);
            
            this.oTimer.synchronizeCallBacks();
        end
     end
    
end


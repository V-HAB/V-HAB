classdef Example < vsys
    
    properties (SetAccess = protected, GetAccess = public)
        
    end
    methods
        function this = Example(oParent, sName)
            this@vsys(oParent, sName, 30);
            eval(this.oRoot.oCfgParams.configCode(this));
            %connecting subystems
        end
        
        function createMatterStructure(this)
            createMatterStructure@vsys(this);
            
            %% stores
            matter.store(this, 'Inflow_Tank',     1500);
            matter.store(this, 'Node_3',     1000000);      %gas part 
            
            matter.store(this, 'WW_Tank', 45.3592/1000);    % Waster water tank 150lb water tank= 0,068m^3
            matter.store(this, 'WT_Tank', 100);             % stores processed water
            
            %% phases
            % Watermodel
            %WW_Tank & WT_Tank
            matter.phases.mixture(this.toStores.WW_Tank,    'Ersatz',   'liquid',   struct('H2O', 2), 45.3592/1000, 293, 1e5 );            
            matter.phases.mixture(this.toStores.WT_Tank,	'Water' ,   'liquid',   struct('H2O', 1 ),100, 293, 1e5 );
           
            
        end
        
        function createSolverStructure(this)
            createSolverStructure@vsys(this);
            
        end
    end
    
    methods (Access = protected)
        function exec(this, ~)
            
            exec@vsys(this);
            
        end
    end
end
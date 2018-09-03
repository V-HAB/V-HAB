classdef gas_flow_node < matter.phases.gas
    %% gas_flow_node
    % A phase that is modelled as containing no matter. For implementation
    % purposes the phase does have a mass, but the calculations enforce
    % zero mass change for the phase and calculate all values based on the
    % inflows. The pressure is calculated and set by the multi branch
    % solver, therefore this phase can only be used in a network of
    % branches that is solved by the multi branch solver!
    
    
    properties (SetAccess = protected, GetAccess = public)
        % Pressure is adjusted ('virtual', not a real pressure) to minimize
        % the total flow rate
        fVirtualPressure = 1e5;
        
        % Informative
        fVirtualMassToPressure;
        
        
        % Actual pressure - just informative
        fActualPressure;
        
        % Actual mass to pressure - just informative
        fActualMassToPressure;
        
        % Initial mass?
        fInitialMass;
        
        
        fLastPartialsUpdate = -1;
    end
    
    methods
        function this = gas_flow_node(oStore, sName, varargin)
            this@matter.phases.gas(oStore, sName, varargin{:});
            
            this.fInitialMass = this.fMass;
            
            tTimeStepProperties.rMaxChange = 0;
            this.setTimeStepProperties(tTimeStepProperties)
            
        end
        
        function setPressure(this, fPressure)
            if fPressure < 0
                fPressure = 0;
            end
            this.fVirtualPressure = fPressure;
        end
        
        
        function massupdate(this, varargin)
            
            massupdate@matter.phases.gas(this, varargin{:});
            
            this.updatePressure();
        end
        
        function update(this, varargin)
            update@matter.phases.gas(this, varargin{:});
            
            this.updatePressure();
        end
        
        
        function seal(this)
            seal@matter.phases.gas(this);
            
            this.bSynced    = true;
            this.bFlow      = true;
        end
    end
    
    methods (Access = protected)
        function updatePressure(this)
            
            if isempty(this.fVirtualPressure)
                this.fVirtualPressure = 0;
            end
            
            this.fActualMassToPressure = this.fMassToPressure;
            this.fActualPressure       = this.fPressure;

            this.fVirtualMassToPressure = this.fVirtualPressure / this.fMass;

            this.fPressure       = this.fVirtualPressure;
            this.fMassToPressure = this.fVirtualMassToPressure;
        end
    end
end


classdef gas_pressure_manual < matter.phases.gas
    %GAS_VIRTUAL Summary of this class goes here
    %   Detailed explanation goes here
    
    
    properties (SetAccess = protected, GetAccess = public)
        % Pressure is adjusted ('virtual', not a real pressure) to minimize
        % the total flow rate
        fVirtualPressure;
        
        % Informative
        fVirtualMassToPressure;
        
        
        % Actual pressure - just informative
        fActualPressure;
        
        % Actual mass to pressure - just informative
        fActualMassToPressure;
        
        % Initial mass?
        fInitialMass;
    end
    
    methods
        function this = gas_pressure_manual(varargin)
            this@matter.phases.gas(varargin{:});
            
            this.fInitialMass = this.fMass;
        end
        
        function setPressure(this, fPressure)
            this.fVirtualPressure = fPressure;
            
            % Don't need to do that, phases are synced anyways
            %this.update();
        end
        
        
        function massupdate(this, varargin)
            massupdate@matter.phases.gas(this, varargin{:});
            
            if ~isempty(this.fVirtualPressure)
                this.updatePressure();
            end
        end
        
        
        
        
        function update(this, varargin)
            update@matter.phases.gas(this, varargin{:});
            
            if ~isempty(this.fVirtualPressure)
                this.updatePressure();
            end
        end
        
        
        function seal(this)
            seal@matter.phase(this);
            
            
            %this.rMaxChange = 0.01;%0.00001;%inf;
            this.rMaxChange = 0.00001;
            %this.rMaxChange = inf;
            
            this.bSynced    = true;
            
            % If a p2p is registered, set an rMaxChange value - the partial
            % pressures might change, to branches need to be updated!
            %TODO check if initially and after p2p updates, the FOLLOWING
            %     branches get an updated value, also if there's e.g.
            %     another Valve/VPP downstream (does the partials update
            %     pass through the VPP?)
            if this.iProcsP2Pflow > 0
                %this.rMaxChange = 0.01;
            end
        end
    end
    
    methods (Access = protected)
        function updatePressure(this)
            this.fActualMassToPressure = this.fMassToPressure;
            this.fActualPressure       = this.fPressure;
            
            this.fVirtualMassToPressure = this.fVirtualPressure / this.fMass;
            
            this.fPressure       = this.fVirtualPressure;
            this.fMassToPressure = this.fVirtualMassToPressure;
        end
    end
end


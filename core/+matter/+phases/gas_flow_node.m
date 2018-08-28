classdef gas_flow_node < matter.phases.gas
    %GAS_VIRTUAL Summary of this class goes here
    %   Detailed explanation goes here
    
    
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
            %this@matter.phases.gas(oStore, sName, struct(), [], 0);%varargin{:});
            
            this.fInitialMass = this.fMass;
            
            tTimeStepProperties.rMaxChange = 0;
            this.setTimeStepProperties(tTimeStepProperties)
            
            if this.fMass > 0
                %this.throw('gas_pressure_manual', 'cannot have mass!');
            end
        end
        
        function setPressure(this, fPressure)
            this.fVirtualPressure = fPressure;
            
            % Don't need to do that, phases are synced anyways
            %this.update();
        end
        
        
        function massupdate(this, varargin)
            fLastStep = this.oTimer.fTime - this.fLastMassUpdate;
            
            massupdate@matter.phases.gas(this, varargin{:});
            
            %if ~isempty(this.fVirtualPressure)
                this.updatePressure();
                
%                 %TODO WROONG ... no 'true' here!! SEE BELOW, .warn()!
%                 this.updatePartials();
%                         
%             if fLastStep ~= 0 % so only happens once each time step!
%                 this.oTimer.bindPostTick(@() this.updatePartials(true), 1);
%             end
        end
        
        function update(this, varargin)
            update@matter.phases.gas(this, varargin{:});
            
            %if ~isempty(this.fVirtualPressure)
                this.updatePressure();
            %end
        end
        
        
        function seal(this)
            seal@matter.phases.gas(this);
            
            
            %this.rMaxChange = 0.01;%0.00001;%inf;
            
            %this.rMaxChange = 0.1 ^ this.oTimer.iPrecision;
            %this.rMaxChange = 0.0000001;
            %this.rMaxChange = inf;
            this.bSynced    = true;
            this.bFlow      = true;
            
            
            %this.rMaxChange = 0.5;
            %%this.rMaxChange = this.rMaxChange * 1000;
            %this.bSynced    = false;
            
            
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
            
            if ~isempty(this.fVirtualPressure)
                this.fActualMassToPressure = this.fMassToPressure;
                this.fActualPressure       = this.fPressure;

                this.fVirtualMassToPressure = this.fVirtualPressure / this.fMass;

                this.fPressure       = this.fVirtualPressure;
                this.fMassToPressure = this.fVirtualMassToPressure;
            end
        end
        
       
        
        
%         function updateProcessorsAndManipulators(this, varargin)
%             updateProcessorsAndManipulators@matter.phases.gas(this, varargin{:});
%             
%             
%             this.updatePartials(true);
%         end
    end
end


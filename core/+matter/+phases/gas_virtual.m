classdef gas_virtual < matter.phases.gas
    %GAS_VIRTUAL Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        % Maximum sum of total flow rates divided by contained mass, i.e.
        % maximum mass change rate in percent (ratio) per second. If change
        % is equal or larger, time step is set to miniumum
        rMaxChangeRate = 0.01;
    end
    
    properties (SetAccess = protected, GetAccess = public)
        % Pressure is adjusted ('virtual', not a real pressure) to minimize
        % the total flow rate
        fVirtualPressure;
        
        % Informative
        fVirtualMassToPressure;
        
        
        % Previous time step - virtual pressure
        fPreviousStepVirtualPressure;
        
        % Previous time step - total mass flow rates (sum of all inwards
        % and outwards flow rates)
        fPreviousStepTotalFlowRate;
        
        
        % Actual pressure - just informative
        fActualPressure;
        
        % Actual mass to pressure - just informative
        fActualMassToPressure;
    end
    
    methods
        function this = gas_virtual(varargin)
            this@matter.phases.gas(varargin{:});
            
            this.bSynced = true;
        end
        
        
        function this = update(this)
            
            % Preserve current total mass in/out
            fCurrentTotalFlowRate = this.fCurrentTotalMassInOut;
            
            
            update@matter.phases.gas(this);
            
            if isempty(this.fVirtualPressure)
                % Initialize
                this.fVirtualMassToPressure = this.fMassToPressure;
                this.fVirtualPressure       = this.fPressure;
                this.fActualMassToPressure  = this.fMassToPressure;
                this.fActualPressure        = this.fPressure;
                
                % For next step interpolation
                this.fPreviousStepVirtualPressure = this.fPressure;
                this.fPreviousStepTotalFlowRate   = sum(this.getTotalMassChange());
                
                
                return;
            end
            
            % Nothing to inteprolate, total flow rate between last and this
            % step is equal.
            if this.fPreviousStepTotalFlowRate == this.fCurrentTotalMassInOut
                return;
            end
            
            
            % Preseve actual, real properties
            this.fActualMassToPressure  = this.fMassToPressure;
            this.fActualPressure        = this.fPressure;
            
            
            % INTERP new fVirtualPressure with 
            
            afTotalFlowRates   = [ this.fPreviousStepTotalFlowRate   this.fCurrentTotalMassInOut ];
            afVirtualPressures = [ this.fPreviousStepVirtualPressure this.fVirtualPressure ];
            % this.fCurrentTotalMassInOut
            fNewVirtualPressure = interp1(afTotalFlowRates, afVirtualPressures, 0, 'linear', 'extrap');
            
            % Use virtual props to interp
            % set virtual properties
            
            fprintf('OLD VIRT PRESS: %f, NEW VIRT PRESS %f\n', this.fVirtualPressure, fNewVirtualPressure);
            
            
            % Store old properties for interpolation
            this.fPreviousStepTotalFlowRate   = fCurrentTotalFlowRate;
            this.fPreviousStepVirtualPressure = this.fVirtualPressure;
            
            
            % Set virtual properties
            this.fPressure        = fNewVirtualPressure;
            this.fVirtualPressure = fNewVirtualPressure;
            
            this.fMassToPressure         = fNewVirtualPressure / this.fMass;
            this.fVirtualMassToPressure  = fNewVirtualPressure / this.fMass;
        end
    end
    
    
    methods (Access = protected)
        function calculateTimeStep(this)
            % Overload time step calulcation
            
            % EXP curve
            % Interp - minTS = timer min ts
            % Interp - maxTS = from phase
            % For MaxTS if Sum lt precision (1e-8)
            % MinTS if sum >= maxChangeRate
            
            % Don't really need ZERO ... min time step ok? Doesn't work out
            % with units, but need some lower bound ...?
            fTotalInOut = this.fCurrentTotalMassInOut - this.oTimer.fTimeStep;
            rTotalInOut = fTotalInOut / this.fMass;
            %TODO better set maxTotalFr instead of ratio?
            
            
            fInt = interp1([ this.oTimer.fTimeStep this.rMaxChangeRate ], [ 1 0 ], rTotalInOut, 'linear', 'extrap');
            iI = 5;
            fNewStep = fInt.^iI * this.fMaxStep + this.oTimer.fTimeStep;
            
            fprintf('OLD TS: %f, NEW TS %f, CHANGE %f\n', this.fTimeStep, fNewStep, rTotalInOut);
            
            
            % To reset e.g. bOutdatedTS
            calculateTimeStep@matter.phases.gas(this);
            
            
            this.oStore.setNextUpdateTime(this.fLastMassUpdate + fNewStep);
            
            
            % Now up to date!
            %this.bOutdatedTS = false;
            
            
            %TODO
            % MAKE SURE - if virt. pressure > actual pressure, we require a
            %     POSITIVE total flow rate, and vice versa.
            % This means if wrong sign of total flow rate --> immediately
            % set to minTS?
            % In .update(), try to interpolate to iSign * 1e-8, not 0?
        end
    end
end


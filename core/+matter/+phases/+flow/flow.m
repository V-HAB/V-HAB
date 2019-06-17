classdef (Abstract) flow < matter.phase
    %% flow
    % A phase that is modelled as containing no matter. For implementation
    % purposes the phase does have a mass, but the calculations enforce
    % zero mass change for the phase and calculate all values based on the
    % inflows.
    
    
    properties (SetAccess = protected, GetAccess = public)
        % flow_nodes can be used within multi branch solvers to allow the
        % solver to handle the pressure of the flow nodes, since they are
        % basically considered as flows (but allow the user to attach
        % multiple branches and P2Ps).
        fVirtualPressure;
        % If the virtual pressure property remains empty it means that no
        % solver handles the pressure and the flow_node mass averages the
        % exme pressures to calculate its pressure. Otherwise fPressure is
        % identical to fVirtualPressure
        
        % Coefficient for pressure = COEFF * mass,  depends on current 
        % matter properties
        fMassToPressure = 0;  
        
        % Initial mass for information and debugging purposes. If
        % everything works correctly the phase should not change its mass!
        fInitialMass;
        
        fLastPartialsUpdate = -1;
    end
    
    methods
        function this = flow(oStore, sName, tfMass, fVolume, fTemperature)
            this@matter.phase(oStore, sName, tfMass, fTemperature);
            
            this.fVolume = fVolume;
            
            this.fInitialMass = this.fMass;
            
            this.fDensity = this.fMass / this.fVolume;
            
            % Mass change must be zero for flow nodes, if that is not the
            % case, this enforces V-HAB to make a minimum size time step to
            % keep the error small
            tTimeStepProperties.rMaxChange = 0.01;
            this.setTimeStepProperties(tTimeStepProperties)
            
            % Set flags to identify this as flow phase and sync all solvers
            % attached to it (boolean flag is faster than isa query)
            this.bFlow   = true;
            
            this.bind('update_partials',@(~)this.updatePartials());
        end
        
        function setVolume(~, ~)
            % Must be here because the store tries to overwrite the volume,
            % but for flow_nodes we want the small volumes and the volume
            % is not relevant for the calculations anyway
        end
        
        function setPressure(this, fPressure)
            % Allows the solver to set the pressure
            if fPressure < 0
                error(['a negative pressure occured in the flow phase ', this.sName, ' in store ', this.oStore.sName, '. This can happen if e.g. the f2f have a too large pressure drops for a constant flowrate boundary forcing the solver to converge to a solution with negative pressures. Please check your system']);
            end
            this.fVirtualPressure = fPressure;
            this.fPressure = fPressure;
            this.fMassToPressure = fPressure / this.fMass;
        end
        
        function updatePartials(this, afPartialInFlows)
            
            if isempty(this.fPressure)
                
                this.out(1, 1, 'skip-partials', '%s-%s: skip at %i (%f) - no pressure (i.e. before multi solver executed at least once)!', { this.oStore.sName, this.sName, this.oTimer.iTick, this.oTimer.fTime });
                
                return;
            end
            
            
            % Store needs to be sealed (else problems with initial
            % conditions). Last partials update needs to be in the past,
            % except forced, in case this method is called e.g. from
            % .update() or .updateProcessorsAndManipulators()
            if ~this.oStore.bSealed %|| (this.fLastPartialsUpdate >= this.oTimer.fTime && ~bForce)
                
                this.out(1, 1, 'skip-partials', '%s-%s: skip at %i (%f) - already executed!', { this.oStore.sName, this.sName, this.oTimer.iTick, this.oTimer.fTime });
                
                return;
            end
            if nargin < 2
                %NOTE these should probably be named e.g. afRelevantFlows
                %     because e.g. p2ps both in and out used!
                mrInPartials  = zeros(this.iProcsEXME, this.oMT.iSubstances);
                afInFlowrates = zeros(this.iProcsEXME, 1);
                
                % Creating an array to log which of the flows are not in-flows
                % This will include only real matter, no p2ps - they will
                % all be included, no matter the direction.
                aiOutFlows = ones(this.iProcsEXME, 1);
                
                
                % Need to make sure a flow rate exists. Because p2ps depend
                % on the normal branch inflows (at least outflowing p2ps),
                % don't include those in the check for an existing flow
                % rate - only return the 'inflow' based partials if there
                % is actually a real flow rate.
                fInwardsFlowRates = 0;
                
                % Get flow rates and partials from EXMEs
                for iI = 1:this.iProcsEXME
                    [ fFlowRate, arFlowPartials, ~ ] = this.coProcsEXME{iI}.getFlowData();
                    
                    % Include if EITHER an (real) inflow, OR a p2p (but not
                    % ourselves!) in either direction (p2ps can change
                    % matter composition, therefore include both in and
                    % outflowing)
                    if fFlowRate > 0 || (this.coProcsEXME{iI} ~= this && this.coProcsEXME{iI}.bFlowIsAProcP2P)
                        mrInPartials(iI,:) = arFlowPartials;
                        afInFlowrates(iI)  = fFlowRate;
                        aiOutFlows(iI)     = 0;
                        
                        %if ~this.coProcsEXME{iI}.bFlowIsAProcP2P
                        if fFlowRate > 0
                            fInwardsFlowRates = fInwardsFlowRates + fFlowRate;
                        end
                    end
                end

                % Now we delete all of the rows in the mfInflowDetails matrix
                % that belong to out-flows.
                if any(aiOutFlows)
                    mrInPartials(logical(aiOutFlows),:)  = [];
                    afInFlowrates(logical(aiOutFlows),:) = [];
                end

                
                for iF = 1:length(afInFlowrates)
                    mrInPartials(iF, :) = mrInPartials(iF, :) .* afInFlowrates(iF);
                end
                
                % Include possible manipulator, which uses an array of
                % absolute flow-rates for the different substances
                % Also depends on normal inflow branches, so do not include
                % with the fInwardsFlowRates check.
                if ~isempty(this.toManips.substance) && ~isempty(this.toManips.substance.afPartialFlows)
                    % The sum() of the flow rates of a substance manip
                    % should always be zero. Therefore, split positive and
                    % negative rates and see as two flows.
                    afManipPartialsIn  = this.toManips.substance.afPartialFlows;
                    afManipPartialsOut = this.toManips.substance.afPartialFlows;
                    
                    afManipPartialsIn (afManipPartialsIn  < 0) = 0;
                    afManipPartialsOut(afManipPartialsOut > 0) = 0;
                    
                    afInFlowrates(end + 1) = sum(afManipPartialsIn);
                    afInFlowrates(end + 1) = sum(afManipPartialsOut);
                    
                    mrInPartials(end + 1, :) = afManipPartialsIn;
                    mrInPartials(end + 1, :) = afManipPartialsOut;
                end
                
                afPartialInFlows = sum(mrInPartials, 1); %note we did multiply mrInPartials with flow rates above, so actually total partial flows!
                
            else
                afPartialInFlows = sum(afPartialInFlows, 1);
            end
            
            if any(afPartialInFlows < 0)
                afPartialInFlows(afPartialInFlows < 0) = 0;
                this.out(2, 1, 'partials-error', 'NEGATIVE PARTIALS');
                % TO DO: Make a lower level debugging output
                % this.warn('updatePartials', 'negative partials');
            end
            
            fTotalInFlow       = sum(afPartialInFlows);
            this.arPartialMass = afPartialInFlows / fTotalInFlow;
            
            if fTotalInFlow == 0
                this.arPartialMass = zeros(1, this.oMT.iSubstances);
            end
        end
    end
    
    methods  (Access = protected)
        function massupdate(this, varargin)
            % We call the massupdate together with the function to update
            % the pressure
            massupdate@matter.phase(this, varargin{:});
            
            this.updatePressure();
            
        end
        
        function updatePressure(this)
            % if a multi branch solver is used the virtual pressure
            % property is set and the phase pressure is handled by the
            % solver. However, a flow node can also be used individually.
            % For that case a seperate pressure calculation is necessary,
            % which is used in case the virtual pressure is empty
            if isempty(this.fVirtualPressure)
                fTotalFlowRate = 0;
                fTotalPressure = 0;
                for iExme = 1:this.iProcsEXME
                    oExme = this.coProcsEXME{iExme};
                    if ~oExme.bFlowIsAProcP2P
                        fTotalFlowRate = fTotalFlowRate + abs(oExme.oFlow.fFlowRate);
                        fTotalPressure = fTotalPressure + oExme.oFlow.fPressure * abs(oExme.oFlow.fFlowRate);
                    end
                end
                if fTotalFlowRate == 0
                    this.fPressure       = 0;
                    this.fMassToPressure = 0;
                else
                    fTotalPressure = fTotalPressure / fTotalFlowRate;
                    this.fPressure       = fTotalPressure;
                    this.fMassToPressure = fTotalPressure / this.fMass;
                end
            else
                this.fMassToPressure = this.fVirtualPressure / this.fMass;

                this.fPressure       = this.fVirtualPressure;
            end
        end
    end
end


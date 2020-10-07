classdef ConstantMassP2P < matter.procs.p2ps.stationary
    % This p2p is designed to keep the mass of the specified substances on
    % its input side constant with regard to the mass value that is
    % present initially. The value for the constant mass can also be
    % overwritten by using the setSubstances function which will set the
    % constant mass to the current values in the In phase again, for the
    % newly defined substances.
    properties (SetAccess = protected, GetAccess = public)
        % Allows the user to define if mass is only allowed to flow in
        % positive direction (value of 1) , only in negative direction
        % (value of -1) or in both directions (value of 0)
        % TO DO: the case where two directions would have to be used at the
        % same time is not possible yet!
        iDirection; 
        afFlowRates;
    end
    properties (SetAccess = protected, GetAccess = public)
        aiSubstances;
        
        afConstantMass;
        
        fLastExec = 0;
    end
    
    properties (SetAccess = private, GetAccess = protected)
        
        hBindPostTickInternalUpdate;
        
        bInternalUpdateRegistered = false;
        
        iPhaseExmeNumber;
    end
    
    methods
        function this = ConstantMassP2P(oStore, sName, sPhaseAndPortIn, sPhaseAndPortOut, csSubstances, iDirection)
            this@matter.procs.p2ps.stationary(oStore, sName, sPhaseAndPortIn, sPhaseAndPortOut);

            % the substances that shall be kept constant are transformed
            % into their respective indices and stored as indices in the
            % P2P to improve speed.
            this.aiSubstances = zeros(1,length(csSubstances));
            for iSubstance = 1:length(csSubstances)
                this.aiSubstances(iSubstance) = this.oMT.tiN2I.(csSubstances{iSubstance});
            end
            this.afConstantMass = zeros(1,this.oMT.iSubstances);
            this.afConstantMass(this.aiSubstances) = this.oIn.oPhase.afMass(this.aiSubstances);
            
            this.iDirection = iDirection;
            
            this.hBindPostTickInternalUpdate  = this.oTimer.registerPostTick(@this.calculateFlowRates,   'matter',        'pre_multibranch_solver');
            
            if this.iDirection == 1
                 this.oIn.oPhase.bind(	'massupdate_post', @this.bindInternalUpdate);
            else
                 this.oOut.oPhase.bind(	'massupdate_post', @this.bindInternalUpdate);
            end
            
            if this.iDirection == 1
                oPhase = this.oIn.oPhase;
            else
                oPhase = this.oOut.oPhase;
            end
            for iExme = 1:oPhase.iProcsEXME
                if oPhase.coProcsEXME{iExme}.oFlow == this
                    this.iPhaseExmeNumber = iExme;
                end
            end
            
        end
        
        function setSubstances(this, csSubstances)
            % the substances that shall be kept constant are transformed
            % into their respective indices and stored as indices in the
            % P2P to improve speed.
            this.aiSubstances = zeros(1,length(csSubstances));
            for iSubstance = 1:length(csSubstances)
                this.aiSubstances(iSubstance) = this.oMT.tiN2I.(csSubstances{iSubstance});
            end
            
            this.afConstantMass = this.oIn.oPhase.afMass(this.aiSubstances);
        end
        
        function bindInternalUpdate(this, ~)
            if ~this.bInternalUpdateRegistered
                this.hBindPostTickInternalUpdate()
                this.bInternalUpdateRegistered = true;
            end
        end
    end
        
    methods (Access = protected)
        function calculateFlowRates(this)
            
            if this.iDirection == 1
                oPhase = this.oIn.oPhase;
            else
                oPhase = this.oOut.oPhase;
            end
            afCurrentFlowRates = zeros(1, this.oMT.iSubstances);
            for iExme = 1:oPhase.iProcsEXME
                if this.iPhaseExmeNumber ~= iExme
                    afCurrentFlowRates = afCurrentFlowRates + oPhase.coProcsEXME{iExme}.iSign .* oPhase.coProcsEXME{iExme}.oFlow.fFlowRate .* oPhase.coProcsEXME{iExme}.oFlow.arPartialMass;
                end
            end
            
            this.afFlowRates = zeros(1, this.oMT.iSubstances);
            this.afFlowRates(this.aiSubstances) = -afCurrentFlowRates(this.aiSubstances);
            
            % Connected phases have to do a massupdate before we set the
            % new flow rate - so the mass for the LAST time step, with the
            % old flow rate, is actually moved from tank to tank. In the
            % massupdate the update for the P2P will be triggered, which is
            % then executed in the post tick after the phase massupdates
            if this.oIn.oPhase.fLastMassUpdate == this.oTimer.fTime && this.oOut.oPhase.fLastMassUpdate == this.oTimer.fTime
                this.update();
            else
                this.oIn.oPhase.registerMassupdate();
                this.oOut.oPhase.registerMassupdate();
            end
            
            this.bInternalUpdateRegistered = false;
        end
        function update(this, ~) 
            
            fFlowRate = sum(this.afFlowRates);
            if fFlowRate == 0
                arPartialFlowRates = zeros(1,this.oMT.iSubstances);
            else
                arPartialFlowRates = this.afFlowRates/fFlowRate;
            end
            
            update@matter.procs.p2p(this, fFlowRate, arPartialFlowRates);
        end
    end
end
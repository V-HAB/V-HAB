classdef ConstantMassP2P < matter.procs.p2ps.flow
    % This p2p is designed to keep the mass of the specified substances on
    % its input side constant with regard to the mass value that is
    % present initially. The value for the constant mass can also be
    % overwritten by using the setSubstances function which will set the
    % constant mass to the current values in the In phase again, for the
    % newly defined substances.
    properties (SetAccess = public, GetAccess = public)
        % Allows the user to define if mass is only allowed to flow in
        % positive direction (value of 1) , only in negative direction
        % (value of -1) or in both directions (value of 0)
        % TO DO: the case where two directions would have to be used at the
        % same time is not possible yet!
        iDirection; 
    end
    properties (SetAccess = protected, GetAccess = public)
        % parent system reference
        oParent;
        
        aiSubstances;
        
        afConstantMass;
        
        fLastExec = 0;
        
    end
    
    methods
        function this = ConstantMassP2P(oParent, oStore, sName, sPhaseAndPortIn, sPhaseAndPortOut, csSubstances, iDirection)
            this@matter.procs.p2ps.flow(oStore, sName, sPhaseAndPortIn, sPhaseAndPortOut);

            this.oParent = oParent;
            
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
        end
        
        function update(this) 
            
            fTimeStep = this.oTimer.fTime - this.fLastExec;
            if fTimeStep <= 1
                return
            end
            
            % calculate the difference between the current mass and the
            % constant mass. The calculation results in a higher current
            % mass to have a positive flowrate as outflows are defined as
            % positive for the P2P!
            afMassChange = zeros(1,this.oMT.iSubstances);
            afMassChange(this.aiSubstances) =  this.oIn.oPhase.afMass(this.aiSubstances) - this.afConstantMass(this.aiSubstances);
            
            switch this.iDirection
                case -1
                    afMassChange(afMassChange > 0) = 0;
                case 1
                    afMassChange(afMassChange < 0) = 0;
            end
            % calculates the overall flowrate of the P2P and the partial
            % mass ratios based on the partial mass flows for each
            % substances. Warning for the case where one substance has a
            % negative flowrate and another has a positive flowrate the
            % calculation will not work correctly!
            % TO DO: Mabye create a bidirectional p2p
            afPartialFlowRates = afMassChange./fTimeStep;
            fFlowRate = sum(afPartialFlowRates);
            if fFlowRate == 0
                arPartialFlowRates = zeros(1,this.oMT.iSubstances);
            else
                arPartialFlowRates = afPartialFlowRates/fFlowRate;
            end
            
            % extract specified substance with desired flow rate
            if any(isnan(arPartialFlowRates)) || isnan(fFlowRate) || fFlowRate > 1e5 || arPartialFlowRates(29) ~= 0
                keyboard()
            end
            this.setMatterProperties(fFlowRate, arPartialFlowRates);
            
            this.fLastExec = this.oTimer.fTime;
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
    end
end
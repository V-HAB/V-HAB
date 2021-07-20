classdef Substance_Constant < matter.procs.p2ps.flow
    %The P2P processor to hold the nominal mass level in a phase which is described in section 4.2.2.2 in the thesis
    
    properties (SetAccess = protected, GetAccess = public)
        % The Substance whose nominal mass level is to be held
        csSubstance;
        
        % The nominal mass level
        afLimit_Level;
        
        % Mass difference between current mass and nominal mass level
        afMassDifference;
        
        % The simulated time in the last loop
        fLastExecp2p = 0;
        
        % Define how much substance is to be extracted (it is set to 1 in the constructor function)
        arExtractPartials;
        
        
    end
    
    
    methods
        function this = Substance_Constant(oStore, sName, sPhaseIn, sPhaseOut, csSubstance, afLimit_Level)
            this@matter.procs.p2ps.flow(oStore, sName, sPhaseIn, sPhaseOut);
            
            %cell of substance strings, instead of one substance at a time
            this.csSubstance  = csSubstance;
            
            %array with limit level for all substances in csSubstance
            this.afLimit_Level = afLimit_Level;
            
            %array with oMT indices of the substances in csSubstances
            for iSubstance = 1:length(this.csSubstance)
                aiIndices(iSubstance) = this.oMT.tiN2I.(this.csSubstances{iSubstance});
            end
          
            % The extracting percentage of the substance is set to 1 since
            % it is the only substance to be extracted.
            this.arExtractPartials = zeros(1, this.oMT.iSubstances);
            
            for iSubstance = 1:length(this.csSubstance)
                this.arExtractPartials(this.oMT.tiN2I.(this.csSubstance{iSubstance})) = 1/length(this.csSubstance);
            end
        end
        
        function update(this)
            % The time step of the P2P in each loop
            fTimeStep = this.oTimer.fTime - this.fLastExecp2p;
            
            % To avoid numerical oscillation
            if fTimeStep <= 0.1
                return
            end
            
            %simultaneous mass comparison for all substances
            this.afMassDifference = this.oOut.oPhase.afMass(aiIndices) - this.afLimit_Level;
            
            % Calculate the mass flow rate of the substance according to
            % the nominal mass level of the substance in the "this.oOut.oPhase" which
            % is described in section 4.2.2.2 in the thesis
            if this.oOut.oPhase.afMass(this.oMT.tiN2I.(this.sSubstance)) ~= this.fLimit_Level
                fFlowRate = (this.fLimit_Level - ...
                    this.oOut.oPhase.afMass(this.oMT.tiN2I.(this.sSubstance)))/fTimeStep;
            else
                fFlowRate = 0;
            end
            
            % Hold the nominal mass level by extracting the substance out
            % of the "this.oOut.oPhase" according to the mass flow rate
            this.setMatterProperties(fFlowRate, this.arExtractPartials);
            
            this.fLastExecp2p = this.oTimer.fTime;
            
        end
    end
    
end
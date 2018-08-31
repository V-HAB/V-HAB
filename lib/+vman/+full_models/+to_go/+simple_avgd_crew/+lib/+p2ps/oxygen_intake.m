classdef oxygen_intake < matter.procs.p2ps.flow
    
    properties (SetAccess = protected, GetAccess = public)
        % Defines which species are extracted
        arExtractPartials;
        
        % Requested intake rate in kg/s
        fRequestedOxygenIntake = 0;
        
        % Intake factor. If requested o2 intake is X kg/s, the inflowing
        % partial o2 flow rate must be four times that, ignoring any
        % partial pressure issues etc, just assuming that normally, the
        % human exhales air with 16% o2 and inhales air with 21% o2.
        % So assuming 20%/15%, lung extracts around a fourth of the oxygen.
        fIntakeFactor = 4;
    end
    
    
    methods
        function this = oxygen_intake(oStore, sName, sPhaseIn, sPhaseOut)
            this@matter.procs.p2ps.flow(oStore, sName, sPhaseIn, sPhaseOut);
            
            % Preparation, see tutorials
            this.arExtractPartials = zeros(1, this.oMT.iSubstances);
            this.arExtractPartials(this.oMT.tiN2I.O2) = 1;
        end
        
        function setRequestedOxygen(this, fRequestedOxygenIntake)
            %TODO need to do something ...! Outdated or so ...!
            this.fRequestedOxygenIntake = fRequestedOxygenIntake;
        end
        
        function update(this)
            % Get flow rate for all incoming flows
            [ afFlowRate, mrPartials ] = this.getInFlows();
            
            % Nothing flows in, so nothing absorbed ...
            if isempty(afFlowRate)
                this.setMatterProperties(0, this.arExtractPartials);
                
                if this.fRequestedOxygenIntake > 0, this.warn('update', 'Cannot breathe ... no flow!'); end
                
                return;
            end
            
            
            % Total mass of o2 inflow
            fFlowRate = sum(afFlowRate .* mrPartials(:, this.oMT.tiN2I.O2));
            
            % Check if a sufficient amount of o2 is flowing into the lung,
            % not taking any partial pressure issues into account
            if fFlowRate < (this.fIntakeFactor * this.fRequestedOxygenIntake)
                %this.warn('update', 'Too little oxygen is inflowing!');
            end
            
            %disp('---');
            %disp(fFlowRate);
            %disp(this.fRequestedOxygenIntake);
            this.setMatterProperties(this.fRequestedOxygenIntake, this.arExtractPartials);
        end
    end
    
end

